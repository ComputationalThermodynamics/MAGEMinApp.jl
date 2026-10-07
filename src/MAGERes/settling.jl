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

"""
    mageres_column_step(g::MAGEResGrid, c::Int, x::Float64, d::Int)

    Return the leaf cell directly below (`d == 4`) or above (otherwise) cell `c` at abscissa `x`,
    or 0 when that position lies outside the domain.
"""
function mageres_column_step(g::MAGEResGrid, c::Int, x::Float64, d::Int)
    y = d == 4 ? g.yc[c] - g.h[c] / 2 - 1e-6 * g.h[c] : g.yc[c] + g.h[c] / 2 + 1e-6 * g.h[c]
    (g.y0 < y < g.y0 + g.ny * g.h0) || return 0
    return mageres_leaf_at(g, x, y)
end

"""
    mageres_column_walk(g::MAGEResGrid, c::Int, x::Float64, d::Int, ok::Function)

    Step from cell `c` along the vertical line at `x` in direction `d` while the next cell satisfies `ok`.
    Returns the last cell reached.
"""
function mageres_column_walk(g::MAGEResGrid, c::Int, x::Float64, d::Int, ok::Function)
    e = c
    while true
        m = mageres_column_step(g, e, x, d)
        (m > 0 && ok(m)) || return e
        e = m
    end
end

const MAGERES_SLUMP_MAX_PASSES = 50
const MAGERES_FULL_TOL         = 1e-6

"""
    mageres_melt_molar_mass_kg(p::MAGEResThermoPoint, Mox::Vector{Float64})

    Mean molar mass of the melt of `p`, from its oxide composition and the oxide molar masses `Mox`.
    Returns NaN when the melt composition is empty.
"""
mageres_melt_molar_mass_kg(p::MAGEResThermoPoint, Mox::Vector{Float64}) =
    (s = sum(p.bulk_M); s > 0 ? sum(p.bulk_M .* Mox) / s : NaN)

"""
    mageres_phase_moles(st::MAGEResState, c::Int, frac::Float64, comp::Vector{Float64})

    Oxide moles in cell `c` of a phase with molar fraction `frac` and composition `comp`,
    each capped at the cell's stored oxide moles.
"""
function mageres_phase_moles(st::MAGEResState, c::Int, frac::Float64, comp::Vector{Float64})
    s = sum(comp)
    (frac > 0 && s > 0) || return zeros(length(comp))
    N = sum(@view st.Q[mageres_ox_rows(st), c])
    return [min(frac * N * comp[k] / s, st.Q[MAGERES_IN0+k-1, c]) for k in eachindex(comp)]
end

"""
    mageres_settle_capacity(st::MAGEResState, f::Int)

    Area [m^2] of melt in cell `f` that settling crystals can still displace, down to `phi_lock`
    inside the body or `phi_perc` outside it.
"""
function mageres_settle_capacity(st::MAGEResState, f::Int)
    p       = st.thermo.points[f]
    phi_min = st.body[f] ? st.opts.phi_lock : st.opts.phi_perc
    return max(0.0, (p.frac_M_vol - phi_min * (p.frac_M_vol + p.frac_S_vol)) * st.grid.area[f])
end

"""
    mageres_sub_column_count(g::MAGEResGrid, c::Int, hmin::Float64)

    Number of finest-level sub-columns of width `hmin` spanning cell `c`, at least 1.
"""
mageres_sub_column_count(g::MAGEResGrid, c::Int, hmin::Float64) = max(1, round(Int, g.h[c] / hmin))

"""
    mageres_sub_columns(g::MAGEResGrid, c::Int, hmin::Float64)

    Abscissae of the centres of the sub-columns spanning cell `c`.
"""
mageres_sub_columns(g::MAGEResGrid, c::Int, hmin::Float64) =
    (n = mageres_sub_column_count(g, c, hmin); [g.xc[c] - g.h[c] / 2 + (j - 0.5) * g.h[c] / n for j in 1:n])

"""
    mageres_settle!(st::MAGEResState, dt::Float64)

    Settle crystals of the mobile body over `dt` [s] by hindered Stokes settling, exchanging them with
    melt from the lowest cell of each sub-column that still has capacity. Returns the settled crystal area [m^2].
"""
function mageres_settle!(st::MAGEResState, dt::Float64)
    th = st.thermo
    (th === nothing || !any(st.body)) && return 0.0
    o     = st.opts
    g     = st.grid
    body  = st.body
    r     = 0.5e-3 * o.crystal_size_mm
    cap   = Dict{Tuple{Int,Int},Float64}()
    moved = 0.0
    hmin  = g.h0 / 2^g.Lmax
    for c in findall(body), x in mageres_sub_columns(g, c, hmin)
        w      = 1 / mageres_sub_column_count(g, c, hmin)
        dx     = g.h[c] * w
        bottom = mageres_column_walk(g, c, x, 4, m -> body[m])
        top    = mageres_column_walk(g, c, x, 3, m -> body[m])
        H      = (g.yc[top] + g.h[top] / 2) - (g.yc[bottom] - g.h[bottom] / 2)
        j      = round(Int, x / hmin)
        f      = bottom
        while f > 0 && f != c && (get(cap, (f, j), 1.0) <= 0 || mageres_settle_capacity(st, f) <= 0)
            f = mageres_column_step(g, f, x, 3)
        end
        if f == c
            bottom == c || continue
            f = mageres_column_step(g, bottom, x, 4)
            (f > 0 && !body[f] && get(cap, (f, j), 1.0) > 0) || continue
        end
        (f > 0 && f != c && g.frac[f] >= 0.5) || continue
        p    = th.points[c]
        pf   = th.points[f]
        drho = p.rho_S - p.rho_M
        (drho > 0 && p.eta_M > 0 && p.frac_S > 0 && p.rho_S > 0 && pf.rho_M > 0 && H > 0) || continue
        phi_x = 1 - mageres_melt_ratio(p)
        v     = 2 * drho * o.g * r^2 / (9 * p.eta_M) * (1 - phi_x)^o.hindered_exponent
        fs    = 1 - exp(-v * dt / H)
        fs > 0 || continue
        cf = get!(() -> mageres_settle_capacity(st, f) / g.area[f] * g.h[f] * min(dx, g.h[f]), cap, (f, j))
        cf > 0 || continue
        nx = mageres_phase_moles(st, c, w * fs * p.frac_S, p.bulk_S)
        mx = sum(nx .* th.Mox)
        mx > 0 || continue
        Vx = mx / p.rho_S
        if Vx > cf
            nx .*= cf / Vx
            Vx   = cf
        end
        MMf = mageres_melt_molar_mass_kg(pf, th.Mox)
        isfinite(MMf) || continue
        n_melt_f = sum(@view st.Q[mageres_ox_rows(st), f]) * pf.frac_M
        nm       = mageres_phase_moles(st, f, min(pf.rho_M * Vx / MMf / max(n_melt_f, eps()), 1.0) * pf.frac_M,
                                       pf.bulk_M)
        xs       = mageres_parcel(st, c, nx, p.h_S, :solid)
        xm       = mageres_parcel(st, f, nm, pf.h_M, :melt)
        @views st.Q[:, c] .+= xm .- xs
        @views st.Q[:, f] .+= xs .- xm
        th.needs_remin[c]  = true
        th.needs_remin[f]  = true
        st.melt_out[f]    += Vx / g.area[f]
        cap[(f, j)]        = cf - Vx
        moved             += Vx
        (!body[f] || cf - Vx <= MAGERES_FULL_TOL * cf) && mageres_tag_cumulate!(st, f)
    end
    return moved
end

"""
    mageres_swap_cells!(st::MAGEResState, a::Int, b::Int)

    Exchange the full content and per-cell state of cells `a` and `b`, flagging both for re-minimization.
    Returns `st`.
"""
function mageres_swap_cells!(st::MAGEResState, a::Int, b::Int)
    th = st.thermo
    qa = st.Q[:, a]
    st.Q[:, a] .= @view st.Q[:, b]
    st.Q[:, b] .= qa
    th.points[a], th.points[b] = th.points[b], th.points[a]
    th.needs_remin[a] = th.needs_remin[b] = true
    for v in (st.cum_frac, st.cum_time, st.cumulate_t, st.melt_out, st.restite_frac)
        v[a], v[b] = v[b], v[a]
    end
    st.donor[a], st.donor[b] = st.donor[b], st.donor[a]
    st.body[a], st.body[b]   = st.body[b], st.body[a]
    return st
end

"""
    mageres_pile_surface(st::MAGEResState, hmin::Float64)

    For each finest-level column, find the lowest body cell (`low`) and, when the cell beneath it is
    cumulate, the (cumulate, body) cell pair (`top`). Returns `(low, top)` keyed by column index.
"""
function mageres_pile_surface(st::MAGEResState, hmin::Float64)
    g   = st.grid
    low = Dict{Int,Int}()
    for c in findall(st.body)
        abs(g.h[c] - hmin) < 1e-6 * hmin || continue
        j = round(Int, (g.xc[c] - hmin / 2) / hmin)
        b = get(low, j, 0)
        (b == 0 || g.yc[c] < g.yc[b]) && (low[j] = c)
    end
    cum = mageres_cumulate(st)
    top = Dict{Int,Tuple{Int,Int}}()
    for (j, b) in low
        a = mageres_column_step(g, b, g.xc[b], 4)
        (a > 0 && cum[a] && abs(g.h[a] - hmin) < 1e-6 * hmin) && (top[j] = (a, b))
    end
    return low, top
end

"""
    mageres_slump_pile!(st::MAGEResState)

    Let the cumulate pile slump sideways: swap a top cumulate cell with the body cell at the base of a
    neighbouring column lying at least two cells lower, repeatedly until stable. Returns the number of swaps.
"""
function mageres_slump_pile!(st::MAGEResState)
    (st.thermo === nothing || !any(st.body)) && return 0
    g    = st.grid
    hmin = g.h0 / 2^g.Lmax
    n    = 0
    for _ in 1:MAGERES_SLUMP_MAX_PASSES
        low, top = mageres_pile_surface(st, hmin)
        moved    = false
        used     = Set{Int}()
        for j in sort(collect(keys(low)))
            for k in (j - 1, j + 1)
                haskey(top, j) && haskey(low, k) || continue
                a, b = top[j]
                b2   = low[k]
                (a in used || b2 in used) && continue
                g.yc[b] - g.yc[b2] >= 2hmin - 1e-6 * hmin || continue
                mageres_swap_cells!(st, a, b2)
                push!(used, a, b2, b)
                n     += 1
                moved  = true
                break
            end
        end
        moved || break
    end
    return n
end
