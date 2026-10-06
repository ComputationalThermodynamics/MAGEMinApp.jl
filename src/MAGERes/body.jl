#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMinApp
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

const MAGERES_MIX_MAX_ITER      = 8
const MAGERES_MIX_TOL_C         = 0.05
const MAGERES_MIX_MAX_STEP_C    = 200.0
const MAGERES_CELL_MIX_MAX_ITER = 3
const MAGERES_CELL_MIX_TOL_C    = 1.0
const MAGERES_ROUTE_MAX_SWAP    = 0.5
const MAGERES_BODY_MIN_FRAC     = 0.5
const MAGERES_KC_CONSTANT       = 270.0
const MAGERES_UNLOCK_MARGIN     = 0.05

"""
    mageres_flood(g::MAGEResGrid, seed::AbstractVector{Bool}, ok::Function)

    Flood-fill over face neighbours of the quadtree grid, starting from the seed cells that satisfy `ok`
    and spreading only into cells for which `ok(c)` is true. Returns the reached cells as a BitVector.
"""
function mageres_flood(g::MAGEResGrid, seed::AbstractVector{Bool}, ok::Function)
    mask  = falses(mageres_ncells(g))
    stack = Int[]
    for c in eachindex(seed)
        if seed[c] && ok(c)
            mask[c] = true
            push!(stack, c)
        end
    end
    while !isempty(stack)
        c = pop!(stack)
        for d in 1:4
            _, nb = mageres_face_neighbors(g, c, d)
            for m in nb
                (mask[m] || !ok(m)) && continue
                mask[m] = true
                push!(stack, m)
            end
        end
    end
    return mask
end

"""
    mageres_largest_component(g::MAGEResGrid, mask::BitVector)

    Return the face-connected component of `mask` with the largest total cell area, as a BitVector.
"""
function mageres_largest_component(g::MAGEResGrid, mask::BitVector)
    best   = falses(length(mask))
    seen   = falses(length(mask))
    A_best = 0.0
    for c in findall(mask)
        seen[c] && continue
        seed    = falses(length(mask))
        seed[c] = true
        m       = mageres_flood(g, seed, k -> mask[k])
        seen  .|= m
        A       = sum(g.area[m])
        if A > A_best
            A_best = A
            best   = m
        end
    end
    return best
end

"""
    mageres_fill_holes(g::MAGEResGrid, body::BitVector)

    Add to `body` every chamber cell (frac >= MAGERES_BODY_MIN_FRAC) that cannot be reached from the
    outside without crossing `body`. Returns the filled BitVector.
"""
function mageres_fill_holes(g::MAGEResGrid, body::BitVector)
    any(body) || return body
    outside = mageres_flood(g, g.frac .< MAGERES_BODY_MIN_FRAC, c -> !body[c])
    return body .| (.!outside .& (g.frac .>= MAGERES_BODY_MIN_FRAC))
end

"""
    mageres_unlock_cumulate!(st::MAGEResState)

    Clear the cumulate tag of body cells whose melt fraction exceeds `phi_lock + MAGERES_UNLOCK_MARGIN`.
    Returns `st`.
"""
function mageres_unlock_cumulate!(st::MAGEResState)
    st.thermo === nothing && return st
    melt = mageres_melt_fraction(st)
    for c in findall(st.body)
        (st.cum_frac[c] > 0 && melt[c] > st.opts.phi_lock + MAGERES_UNLOCK_MARGIN) || continue
        st.cum_frac[c]   = 0.0
        st.cum_time[c]   = NaN
        st.cumulate_t[c] = NaN
    end
    return st
end

"""
    mageres_mobile_body(st::MAGEResState; exclude = nothing)

    Return the mobile magma body as a BitVector: the largest connected set of chamber cells with melt
    fraction above `phi_lock` (optionally excluding the cells flagged in `exclude`), with holes filled.
"""
function mageres_mobile_body(st::MAGEResState; exclude::Union{Nothing,AbstractVector{Bool}} = nothing)
    st.thermo === nothing && return falses(mageres_ncells(st.grid))
    melt = mageres_melt_fraction(st)
    g    = st.grid
    inside(c) = g.frac[c] >= MAGERES_BODY_MIN_FRAC && melt[c] > st.opts.phi_lock
    ok        = exclude === nothing ? inside : (c -> !exclude[c] && inside(c))
    return mageres_fill_holes(g, mageres_largest_component(g, mageres_flood(g, g.frac .> 0, ok)))
end

"""
    mageres_permeability(o::MAGEResOptions, phi::Float64)

    Kozeny-Carman permeability [m^2] of a crystal mush with melt fraction `phi` and crystal size
    `o.crystal_size_mm`.
"""
mageres_permeability(o::MAGEResOptions, phi::Float64) = (1e-3 * o.crystal_size_mm)^2 * phi^3 / MAGERES_KC_CONSTANT

"""
    mageres_darcy_flux(o::MAGEResOptions, p::MAGEResThermoPoint, phi::Float64)

    Buoyancy-driven Darcy melt flux [m/s] through a mush of melt fraction `phi`, from the solid-melt
    density contrast and melt viscosity of `p`. Returns 0 when any of these is non-positive.
"""
function mageres_darcy_flux(o::MAGEResOptions, p::MAGEResThermoPoint, phi::Float64)
    drho = p.rho_S - p.rho_M
    (drho > 0 && p.eta_M > 0 && phi > 0) || return 0.0
    return mageres_permeability(o, phi) * drho * o.g / p.eta_M
end

"""
    mageres_drainage_length(g::MAGEResGrid, c::Int, ok::Function)

    Vertical extent [m] of the column through cell `c` made of contiguous cells satisfying `ok`,
    at least the height of `c` itself.
"""
function mageres_drainage_length(g::MAGEResGrid, c::Int, ok::Function)
    x   = g.xc[c]
    top = mageres_column_walk(g, c, x, 3, ok)
    bot = mageres_column_walk(g, c, x, 4, ok)
    return max(g.h[c], (g.yc[top] + g.h[top] / 2) - (g.yc[bot] - g.h[bot] / 2))
end

"""
    mageres_einstein_roscoe(p::MAGEResThermoPoint, phi_lock::Float64)

    Einstein-Roscoe effective magma viscosity [Pa s] of `p`, with maximum packing `1 - phi_lock`.
    Returns Inf at or beyond maximum packing, or when the melt viscosity is non-positive.
"""
function mageres_einstein_roscoe(p::MAGEResThermoPoint, phi_lock::Float64)
    phi_x    = 1 - mageres_melt_ratio(p)
    phi_pack = 1 - phi_lock
    (p.eta_M > 0 && phi_x < phi_pack) || return Inf
    return p.eta_M * (1 - phi_x / phi_pack)^(-2.5)
end

"""
    mageres_update_convection!(st::MAGEResState)

    Compute the Rayleigh number `st.Ra` and Nusselt number `st.Nu` of the mobile body from its
    area-weighted properties, then update the thermal conductivity. Returns `st`.
"""
function mageres_update_convection!(st::MAGEResState)
    st.Nu, st.Ra = 1.0, 0.0
    if st.thermo !== nothing && any(st.body)
        o     = st.opts
        g     = st.grid
        b     = findall(st.body)
        T     = mageres_temperature(st)
        w     = g.area[b]
        ws    = sum(w)
        pts   = st.thermo.points[b]
        dT    = maximum(T[b]) - minimum(T[b])
        L     = maximum(g.yc[b] .+ g.h[b] ./ 2) - minimum(g.yc[b] .- g.h[b] ./ 2)
        alpha = sum(w .* [p.alpha_M for p in pts]) / ws
        rho   = sum(w .* [p.rho for p in pts]) / ws
        cp    = sum(w .* [p.s_cp for p in pts]) / ws
        eta   = sum(w .* [mageres_einstein_roscoe(p, o.phi_lock) for p in pts]) / ws
        if isfinite(eta) && eta > 0 && dT > 0
            kappa = o.k_magma / (rho * cp)
            st.Ra = o.g * alpha * dT * L^3 * rho / (kappa * eta)
            st.Nu = st.Ra > o.Ra_crit ? (st.Ra / o.Ra_crit)^o.Nu_exponent : 1.0
        end
    end
    mageres_conductivity!(st)
    return st
end

"""
    mageres_enthalpy_equilibrate!(st::MAGEResState, cells::Vector{Int})

    Iteratively find, for each cell in `cells`, the temperature whose equilibrium enthalpy matches the
    cell's stored enthalpy, then store the resulting thermodynamic points and conduction energy. Returns `st`.
"""
function mageres_enthalpy_equilibrate!(st::MAGEResState, cells::Vector{Int})
    th = st.thermo
    (th === nothing || isempty(cells)) && return st
    o      = st.opts
    n      = length(cells)
    m      = [mageres_cell_mass(st, c) for c in cells]
    H      = st.Q[MAGERES_IH, cells]
    T      = mageres_temperature(st)[cells]
    xs     = [mageres_cell_bulk(st, c) for c in cells]
    P      = [mageres_lithostatic_kbar(o, st.grid.yc[c]) for c in cells]
    pts    = Vector{Union{Nothing,MAGEResThermoPoint}}(nothing, n)
    active = collect(1:n)
    for it in 1:MAGERES_CELL_MIX_MAX_ITER
        res = mageres_minimize!(th, o.oxides, xs[active], P[active], T[active];
                                stage    = "Injection enthalpy equilibration, iteration $it",
                                keep_mss = [o.boost_mode && mageres_is_host_cell(st, c) for c in cells[active]])
        th.calc_count[cells[active]] .+= 1
        th.n_cell_calc                += length(active)
        next = Int[]
        for (k, i) in enumerate(active)
            q = res[k]
            q === nothing && continue
            pts[i] = q
            dT     = clamp((H[i] - m[i] * q.h) / (m[i] * q.s_cp), -MAGERES_MIX_MAX_STEP_C, MAGERES_MIX_MAX_STEP_C)
            if abs(dT) > MAGERES_CELL_MIX_TOL_C && it < MAGERES_CELL_MIX_MAX_ITER
                T[i] += dT
                push!(next, i)
            end
        end
        active = next
        isempty(active) && break
    end
    for (i, c) in enumerate(cells)
        q = pts[i]
        if q === nothing
            th.needs_remin[c] = true
            continue
        end
        th.points[c]      = q
        th.needs_remin[c] = o.fluid_treatment == "removed" && q.frac_F > MAGERES_FLUID_MIN_FRAC
        C                 = m[i] * mageres_conduction_cp(q.s_cp)
        E                 = C * (q.T_last + MAGERES_T0_K)
        st.ledger.remin_energy += E - st.Q[MAGERES_IE, c]
        st.Q[MAGERES_IC, c] = C
        st.Q[MAGERES_IE, c] = E
    end
    mageres_volume_refresh!(st, [c for (i, c) in enumerate(cells) if pts[i] !== nothing])
    return st
end

"""
    mageres_mix_body_enthalpy!(st::MAGEResState)

    Homogenise the mobile body: spread its total composition uniformly by area, find the common
    temperature matching its total enthalpy, and assign the resulting point to every body cell. Returns `st`.
"""
function mageres_mix_body_enthalpy!(st::MAGEResState)
    th = st.thermo
    (th === nothing || !any(st.body)) && return st
    o  = st.opts
    g  = st.grid
    b  = findall(st.body)
    A  = g.area[b]
    AB = sum(A)
    N  = vec(sum(st.Q[MAGERES_IN0:end, b]; dims = 2))
    H  = sum(st.Q[MAGERES_IH, b])
    E0 = sum(st.Q[MAGERES_IE, b])
    No = N[1:length(o.oxides)]
    X  = No ./ sum(No)
    Pm = sum(A .* [mageres_lithostatic_kbar(o, y) for y in g.yc[b]]) / AB
    for (k, c) in enumerate(b)
        st.Q[MAGERES_IN0:end, c] .= N .* (A[k] / AB)
    end
    m  = [mageres_cell_mass(st, c) for c in b]
    MB = sum(m)
    T  = E0 / sum(st.Q[MAGERES_IC, b]) - MAGERES_T0_K
    p  = nothing
    for it in 1:MAGERES_MIX_MAX_ITER
        q = mageres_minimize!(th, o.oxides, [X], [Pm], [T];
                              stage    = "Chamber enthalpy mixing, iteration $it",
                              keep_mss = false)[1]
        q === nothing && break
        p  = q
        dT = clamp((H - MB * q.h) / (MB * q.s_cp), -MAGERES_MIX_MAX_STEP_C, MAGERES_MIX_MAX_STEP_C)
        abs(dT) < MAGERES_MIX_TOL_C && break
        T += dT
    end
    if p === nothing
        th.needs_remin[b] .= true
        return st
    end
    T     = p.T_last
    degas = o.fluid_treatment == "removed" && p.frac_F > MAGERES_FLUID_MIN_FRAC
    for (k, c) in enumerate(b)
        th.points[c]        = p
        th.needs_remin[c]   = degas
        C                   = m[k] * mageres_conduction_cp(p.s_cp)
        st.Q[MAGERES_IC, c] = C
        st.Q[MAGERES_IE, c] = C * (T + MAGERES_T0_K)
        st.Q[MAGERES_IH, c] = H * m[k] / MB
    end
    st.ledger.remin_energy += sum(st.Q[MAGERES_IE, b]) - E0
    mageres_volume_refresh!(st, b)
    return st
end

"""
    mageres_effective_melt(st::MAGEResState, c::Int, melt::Vector{Float64})

    Melt fraction of cell `c` remaining after subtracting the melt already extracted this step
    (`st.melt_out`), floored at 0.
"""
mageres_effective_melt(st::MAGEResState, c::Int, melt::Vector{Float64}) =
    (p = st.thermo.points[c]; ms = p.frac_M_vol + p.frac_S_vol; ms > 0 ? max(melt[c] - st.melt_out[c] / ms, 0.0) : 0.0)

"""
    mageres_excess_melt_area(st::MAGEResState, c::Int, melt::Vector{Float64})

    Area [m^2] of melt in cell `c` above the percolation threshold `phi_perc`.
"""
function mageres_excess_melt_area(st::MAGEResState, c::Int, melt::Vector{Float64})
    p = st.thermo.points[c]
    return max(0.0, mageres_effective_melt(st, c, melt) - st.opts.phi_perc) * (p.frac_M_vol + p.frac_S_vol) *
           st.grid.area[c]
end

"""
    mageres_volume_moles(st::MAGEResState, c::Int, V::Float64, frac::Float64, comp::Vector{Float64}, rho::Float64)

    Oxide moles of a phase of composition `comp` and density `rho` occupying volume `V` in cell `c`,
    capped at the phase fraction `frac`. Returns zeros when any input is non-positive.
"""
function mageres_volume_moles(st::MAGEResState, c::Int, V::Float64, frac::Float64, comp::Vector{Float64}, rho::Float64)
    th = st.thermo
    s  = sum(comp)
    (V > 0 && frac > 0 && s > 0 && rho > 0) || return zeros(length(comp))
    MM = sum(comp .* th.Mox) / s
    N  = sum(@view st.Q[mageres_ox_rows(st), c])
    return mageres_phase_moles(st, c, min(rho * V / MM / N, frac), comp)
end

"""
    mageres_compact_piles!(st::MAGEResState, dt::Float64, melt::Vector{Float64}, internal::Vector{Float64})

    Compact the crystal piles below the mobile body over `dt` [s]: expel melt upward by Darcy flow,
    swapping it with solid from the cell above or adding it to `internal`. Returns the pile cells as a BitVector.
"""
function mageres_compact_piles!(st::MAGEResState, dt::Float64, melt::Vector{Float64}, internal::Vector{Float64})
    th         = st.thermo
    o          = st.opts
    g          = st.grid
    body       = st.body
    hmin       = g.h0 / 2^g.Lmax
    pile       = falses(mageres_ncells(g))
    melt_left  = Dict{Int,Float64}()
    solid_left = Dict{Int,Float64}()
    melt_budget(c)  = get!(() -> mageres_excess_melt_area(st, c, melt), melt_left, c)
    solid_budget(c) = get!(() -> th.points[c].frac_S_vol * g.area[c], solid_left, c)
    for b in findall(body), x in mageres_sub_columns(g, b, hmin)
        m = mageres_column_step(g, b, x, 4)
        (m > 0 && !body[m]) || continue
        dx  = g.h[b] / mageres_sub_column_count(g, b, hmin)
        col = Int[]
        while m > 0 && !body[m] && g.frac[m] >= 0.5
            push!(col, m)
            m = mageres_column_step(g, m, x, 4)
        end
        (isempty(col) || (m > 0 && body[m])) && continue
        pile[col] .= true
        for i in length(col):-1:1
            lo       = col[i]
            up       = i > 1 ? col[i-1] : 0
            plo      = th.points[lo]
            share_lo = min(1.0, dx / g.h[lo])
            V        = min(mageres_darcy_flux(o, plo, mageres_effective_melt(st, lo, melt)) * dt * dx,
                           melt_budget(lo) * share_lo)
            up > 0 && (V = min(V, solid_budget(up) * min(1.0, dx / g.h[up])))
            V > 0 || continue
            nm = mageres_volume_moles(st, lo, V, plo.frac_M, plo.bulk_M, plo.rho_M)
            any(>(0), nm) || continue
            xm = mageres_parcel(st, lo, nm, plo.h_M, :melt)
            if up > 0
                pup = th.points[up]
                ns  = mageres_volume_moles(st, up, V, pup.frac_S, pup.bulk_S, pup.rho_S)
                any(>(0), ns) || continue
                xs = mageres_parcel(st, up, ns, pup.h_S, :solid)
                @views st.Q[:, lo] .+= xs .- xm
                @views st.Q[:, up] .+= xm .- xs
                th.needs_remin[up]  = true
                solid_left[up]     -= V
            else
                @views st.Q[:, lo] .-= xm
                internal .+= xm
            end
            melt_left[lo]      -= V
            st.melt_out[lo]    += V / g.area[lo]
            th.needs_remin[lo]  = true
        end
    end
    return pile
end

"""
    mageres_percolate!(st::MAGEResState, dt::Float64)

    Extract by Darcy percolation, over `dt` [s], the melt above `phi_perc` from cells connected to the
    mobile body through partially molten cells; melt from chamber cells is redistributed into the body, melt from host cells is injected
    as a new event. Returns the injected full-section melt area [m^2].
"""
function mageres_percolate!(st::MAGEResState, dt::Float64)
    th = st.thermo
    fill!(st.donor, false)
    (th === nothing || !any(st.body)) && return 0.0
    o        = st.opts
    g        = st.grid
    body     = st.body
    melt     = mageres_melt_fraction(st)
    conn     = mageres_flood(g, body, c -> body[c] || melt[c] > 0)
    pooled   = zeros(size(st.Q, 1))
    internal = zeros(size(st.Q, 1))
    pile     = mageres_compact_piles!(st, dt, melt, internal)
    V        = 0.0
    for c in 1:mageres_ncells(g)
        (conn[c] && !body[c] && !pile[c]) || continue
        p   = th.points[c]
        ms  = p.frac_M_vol + p.frac_S_vol
        phi = ms > 0 ? max(melt[c] - st.melt_out[c] / ms, 0.0) : 0.0
        phi > o.phi_perc || continue
        L    = mageres_drainage_length(g, c, m -> conn[m] && !body[m])
        dphi = min(phi - o.phi_perc, mageres_darcy_flux(o, p, phi) * dt / L)
        f    = melt[c] > 0 ? p.frac_M * dphi / melt[c] : 0.0
        bM   = p.bulk_M
        s    = sum(bM)
        (f > 0 && s > 0 && p.rho_M > 0) || continue
        x = mageres_cell_bulk(st, c)
        for k in eachindex(bM)
            bM[k] > 0 && (f = min(f, x[k] / (bM[k] / s)))
        end
        N    = sum(@view st.Q[mageres_ox_rows(st), c])
        gone = [min(f * N * bM[k] / s, st.Q[MAGERES_IN0+k-1, c]) for k in eachindex(bM)]
        mg   = sum(gone .* th.Mox)
        mg > 0 || continue
        out = mageres_parcel(st, c, gone, p.h_M, :melt)
        @views st.Q[:, c] .-= out
        if g.frac[c] >= 0.5
            internal .+= out
        else
            pooled .+= out
            V       += mg / p.rho_M
            st.restite_frac[c] = 1.0
        end
        th.needs_remin[c] = true
        st.donor[c]       = true
    end
    if any(!iszero, internal)
        b = findall(body)
        A = g.area[b]
        for (k, c) in enumerate(b)
            @views st.Q[:, c] .+= internal .* (A[k] / sum(A))
            th.needs_remin[c] = true
        end
    end
    V > 0 || return 0.0
    mageres_apply_event!(st, MAGERES_SYMMETRY * V / st.chamber.I;
                         mode             = :inject,
                         injected_density = pooled ./ V,
                         internal         = true)
    st.percolated_area += MAGERES_SYMMETRY * V
    return MAGERES_SYMMETRY * V
end
