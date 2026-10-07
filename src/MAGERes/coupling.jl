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
    mageres_cell_bulk(st::MAGEResState, c::Int)

    Oxide moles of cell `c` normalized to sum 1 (returned as is when the sum is not positive).
"""
function mageres_cell_bulk(st::MAGEResState, c::Int)
    v = st.Q[mageres_ox_rows(st), c]
    s = sum(v)
    return s > 0 ? v ./ s : v
end

"""
    mageres_cell_mass(st::MAGEResState, c::Int)

    Mass of cell `c` from its oxide moles and the oxide molar masses.
"""
mageres_cell_mass(st::MAGEResState, c::Int) =
    sum(st.Q[MAGERES_IN0+k-1, c] * st.thermo.Mox[k] for k in eachindex(st.thermo.Mox))

"""
    mageres_set_capacity!(st::MAGEResState, c::Int, s_cp::Float64, T::Float64)

    Set the heat capacity and energy of cell `c` for specific heat `s_cp` and temperature `T` [°C],
    adding the energy change to the ledger's `remin_energy`.
"""
function mageres_set_capacity!(st::MAGEResState, c::Int, s_cp::Float64, T::Float64)
    C = mageres_cell_mass(st, c) * mageres_conduction_cp(s_cp)
    E = C * (T + MAGERES_T0_K)
    st.ledger.remin_energy += E - st.Q[MAGERES_IE, c]
    st.Q[MAGERES_IC, c] = C
    st.Q[MAGERES_IE, c] = E
    return st
end

"""
    mageres_phase_enthalpy_now(st::MAGEResState, c::Int, h_phase::Float64)

    Phase specific enthalpy `h_phase` of cell `c` shifted to the current cell temperature with s_cp;
    the cell specific enthalpy when `h_phase` is not finite.
"""
function mageres_phase_enthalpy_now(st::MAGEResState, c::Int, h_phase::Float64)
    p = st.thermo.points[c]
    isfinite(h_phase) || return mageres_specific_enthalpy(st, c)
    T = st.Q[MAGERES_IE, c] / st.Q[MAGERES_IC, c] - MAGERES_T0_K
    return h_phase + p.s_cp * (T - p.T_last)
end

"""
    mageres_parcel(st::MAGEResState, c::Int, n::Vector{Float64}, h_phase::Float64, kind::Symbol)

    Conserved-quantity vector of a parcel of oxide moles `n` of phase group `kind` (:melt, :solid or :fluid) taken
    from cell `c`: energy and heat capacity scaled by its mass fraction, enthalpy from the phase specific enthalpy
    `h_phase`, its trace elements and zircon, and its phase volume with the overpressure trigger.
"""
function mageres_parcel(st::MAGEResState, c::Int, n::Vector{Float64}, h_phase::Float64, kind::Symbol)
    m = sum(n .* st.thermo.Mox)
    r = m / mageres_cell_mass(st, c)
    x = vcat(r * st.Q[MAGERES_IE, c], r * st.Q[MAGERES_IC, c], m * mageres_phase_enthalpy_now(st, c, h_phase), n,
             mageres_parcel_tracers(st, c, m, kind))
    mageres_has_volume_row(st.opts) || return x
    return vcat(x, min(m / mageres_phase_density(st.thermo.points[c], kind), st.Q[mageres_volume_row(st), c]))
end

"""
    mageres_remove_fluid!(st::MAGEResState, c::Int, f::Float64, bF::Vector{Float64})

    Remove the fluid fraction `f` of composition `bF` from cell `c` (limited to the available moles),
    add it to the ledger's `fluid` and return the removed parcel.
"""
function mageres_remove_fluid!(st::MAGEResState, c::Int, f::Float64, bF::Vector{Float64})
    N       = sum(@view st.Q[mageres_ox_rows(st), c])
    s       = sum(bF)
    gone    = [min(f * N * bF[k] / s, st.Q[MAGERES_IN0+k-1, c]) for k in eachindex(bF)]
    removed = mageres_parcel(st, c, gone, st.thermo.points[c].h_F, :fluid)
    @views st.Q[:, c] .-= removed
    st.ledger.fluid .+= removed
    return removed
end

const MAGERES_CP_GATE = MAGERES_CP_CONDUCTION_MAX

"""
    mageres_thermo_active(st::MAGEResState, T::Vector{Float64})

    Cells to re-minimize: flagged cells, and cells above the subsolidus temperature or with melt whose
    temperature or specific enthalpy drifted beyond tolerance.
"""
function mageres_thermo_active(st::MAGEResState, T::Vector{Float64})
    th     = st.thermo
    o      = st.opts
    dH_tol = MAGERES_CP_GATE * o.dT_tol
    active = Int[]
    for c in eachindex(T)
        p = th.points[c]
        if th.needs_remin[c]
            push!(active, c)
        elseif T[c] >= o.subsolidus_T_C || p.frac_M_vol > 0
            (abs(T[c] - p.T_last) > o.dT_tol ||
             abs(mageres_specific_enthalpy(st, c) - p.h) > dH_tol) && push!(active, c)
        end
    end
    return active
end

"""
    mageres_planned_steps(o::MAGEResOptions)

    Number of thermal timesteps of the run, at least 1.
"""
mageres_planned_steps(o::MAGEResOptions) = max(1, ceil(Int, o.run_time_yr / o.thermal_dt_yr - 1e-9))

"""
    mageres_update_thermo!(st::MAGEResState; t_yr = st.t)

    Re-minimize the active cells, store their points, correct their temperature to the cell enthalpy and
    degas them when fluids are removed. Returns the number of cells computed.
"""
function mageres_update_thermo!(st::MAGEResState; t_yr::Float64 = st.t)
    th = st.thermo
    th === nothing && return 0
    o    = st.opts
    T    = mageres_temperature(st)
    todo = mageres_thermo_active(st, T)
    isempty(todo) && return 0
    xs    = [mageres_cell_bulk(st, c) for c in todo]
    P     = [mageres_lithostatic_kbar(o, st.grid.yc[c]) for c in todo]
    host  = [mageres_is_host_cell(st, c) for c in todo]
    guess = o.boost_mode ? [mageres_guess_eligible(st, c) ? mageres_initial_guess(st, c, xs[k]) : MAGEResmSS()
                            for (k, c) in enumerate(todo)] :
            nothing
    res = mageres_minimize!(th, o.oxides, xs, P, T[todo];
                            stage    = @sprintf("t = %.0f yr", t_yr),
                            keep_mss = o.boost_mode .& host,
                            step     = st.n_thermal_steps + 1,
                            nsteps   = mageres_planned_steps(o),
                            guess    = guess)
    th.calc_count[todo] .+= 1
    th.n_cell_calc       += length(todo)
    done = Int[]
    for (k, c) in enumerate(todo)
        p = res[k]
        p === nothing && continue
        th.points[c]      = p
        th.needs_remin[c] = false
        push!(done, c)
    end
    mageres_volume_refresh!(st, done)
    for c in done
        p  = th.points[c]
        dT = clamp((mageres_specific_enthalpy(st, c) - p.h) / p.s_cp, -MAGERES_T_CORRECTION_MAX_C,
                   MAGERES_T_CORRECTION_MAX_C)
        mageres_set_capacity!(st, c, p.s_cp, T[c] + dT)
        if o.fluid_treatment == "removed"
            f, _ = mageres_degas(mageres_cell_bulk(st, c), p)
            if f > 0
                mageres_remove_fluid!(st, c, f, p.bulk_F)
                th.needs_remin[c] = true
            end
        end
    end
    return length(todo)
end

"""
    mageres_is_host_cell(st::MAGEResState, c::Int)

    True when cell `c` contains no magma.
"""
mageres_is_host_cell(st::MAGEResState, c::Int) = st.grid.frac[c] <= 0

"""
    mageres_guess_eligible(st::MAGEResState, c::Int)

    True when cell `c` and all its face neighbours are host cells.
"""
mageres_guess_eligible(st::MAGEResState, c::Int) =
    mageres_is_host_cell(st, c) && all(m -> mageres_is_host_cell(st, m),
                                       (m for d in 1:4 for m in mageres_face_neighbors(st.grid, c, d)[2]))

"""
    mageres_initial_guess(st::MAGEResState, c::Int, x::Vector{Float64})

    MAGEMin initial guess (mSS list) for cell `c` with bulk `x`, from its own and neighbouring host points sorted by
    decreasing phase count; empty when it has no stored guess or `x` shifted beyond `MAGERES_BOOST_MAX_SHIFT`.
"""
function mageres_initial_guess(st::MAGEResState, c::Int, x::Vector{Float64})
    th = st.thermo
    p  = th.points[c]
    (isempty(p.mSS) || mageres_bulk_shift(x, p.bulk_last) > MAGERES_BOOST_MAX_SHIFT) && return MAGEResmSS()
    src = MAGEResThermoPoint[p]
    for d in 1:4, m in mageres_face_neighbors(st.grid, c, d)[2]
        mageres_is_host_cell(st, m) || continue
        q = th.points[m]
        isempty(q.mSS) || any(r -> r === q, src) || push!(src, q)
    end
    sort!(src; by = q -> -length(q.ph))
    return reduce(vcat, (q.mSS for q in src))
end

"""
    mageres_specific_enthalpy(st::MAGEResState, c::Int)

    Specific enthalpy of cell `c`.
"""
mageres_specific_enthalpy(st::MAGEResState, c::Int) = st.Q[MAGERES_IH, c] / mageres_cell_mass(st, c)

const MAGERES_FRONT_DMELT = 0.05

"""
    mageres_remap_thermo!(st::MAGEResState, source::Vector{Int})

    Carry the thermodynamic points onto the new grid from the `source` cells (0: injection, negative: host
    profile) and flag cells for re-minimization on bulk shift or melt-fraction contrast across magma fronts.
"""
function mageres_remap_thermo!(st::MAGEResState, source::Vector{Int})
    th         = st.thermo
    g          = st.grid
    old_points = th.points
    old_flags  = th.needs_remin
    n          = mageres_ncells(g)
    pts        = Vector{MAGEResThermoPoint}(undef, n)
    flags      = falses(n)
    for c in 1:n
        s        = source[c]
        p        = s > 0 ? old_points[s] : s == 0 ? th.injection : mageres_profile_point(th.profile, g.yc[c])
        pts[c]   = p
        flags[c] = (s > 0 && old_flags[s]) || mageres_bulk_shift(mageres_cell_bulk(st, c), p.bulk_last) > st.opts.dX_tol
    end
    for c in 1:n
        s = source[c]
        (flags[c] || s <= 0 || g.frac[c] <= 0) && continue
        ms       = mageres_melt_ratio(old_points[s])
        flags[c] = any(m -> source[m] > 0 && source[m] != s &&
                            abs(mageres_melt_ratio(old_points[source[m]]) - ms) > MAGERES_FRONT_DMELT,
                       (m for d in 1:4 for m in mageres_face_neighbors(g, c, d)[2]))
    end
    th.points      = pts
    th.needs_remin = flags
    th.calc_count  = [s > 0 ? th.calc_count[s] : 0 for s in source]
    return st
end

"""
    mageres_reset_calc_counts!(st::MAGEResState)

    Reset the per-cell minimization counts and the cell/minimization counters of the thermodynamic state.
"""
function mageres_reset_calc_counts!(st::MAGEResState)
    th = st.thermo
    th === nothing && return st
    fill!(th.calc_count, 0)
    th.n_min_reset = th.n_minimizations
    th.n_cell_calc = 0
    return st
end

"""
    mageres_melt_fraction(st::MAGEResState)

    Per-cell melt fraction relative to melt + solid; zeros without thermodynamics.
"""
mageres_melt_fraction(st::MAGEResState) =
    st.thermo === nothing ? zeros(mageres_ncells(st.grid)) : [mageres_melt_ratio(p) for p in st.thermo.points]

"""
    mageres_chamber_melt(st::MAGEResState)

    Magma-area-weighted mean melt fraction of the grid; NaN without thermodynamics or magma.
"""
function mageres_chamber_melt(st::MAGEResState)
    st.thermo === nothing && return NaN
    w = st.grid.frac .* st.grid.area
    s = sum(w)
    s > 0 || return NaN
    return sum(w .* mageres_melt_fraction(st)) / s
end

"""
    mageres_release_thermo!(st::MAGEResState)

    Finalize and drop the MAGEMin data held by the thermodynamic state.
"""
function mageres_release_thermo!(st::MAGEResState)
    th = st.thermo
    (th === nothing || th.mm === nothing) && return st
    Finalize_MAGEMin(th.mm)
    th.mm = nothing
    return st
end
