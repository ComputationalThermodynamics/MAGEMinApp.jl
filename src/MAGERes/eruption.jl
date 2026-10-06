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

const MAGERES_ERUPT_MAX_CHAMBER_FRACTION = 0.5
const MAGERES_ERUPT_MAX_MELT_FRACTION    = 0.95

"""
    mageres_body_mean_melt(st::MAGEResState)

    Area-weighted mean melt fraction of the mobile body, or 0 when there is no body.
"""
function mageres_body_mean_melt(st::MAGEResState)
    b = findall(st.body)
    isempty(b) && return 0.0
    A = st.grid.area[b]
    return sum(A .* [mageres_melt_ratio(st.thermo.points[c]) for c in b]) / sum(A)
end

"""
    mageres_eruptible(st::MAGEResState)

    True when the chamber is open and its mobile body has a mean melt fraction above `phi_erupt`.
"""
mageres_eruptible(st::MAGEResState) =
    any(st.body) && mageres_is_open(st.chamber) && mageres_body_mean_melt(st) > st.opts.phi_erupt

"""
    mageres_erupt_parcels(st::MAGEResState, b::Vector{Int}, V_target::Float64)

    Build the parcels (melt, fluid and the eruptible crystal fraction) withdrawn from each cell of `b`
    to remove the volume `V_target`. Returns `(parcels, V)` with `parcels` as `(cell, Q-vector)` pairs
    and `V` the extracted volume.
"""
function mageres_erupt_parcels(st::MAGEResState, b::Vector{Int}, V_target::Float64)
    th  = st.thermo
    chi = st.opts.erupt_crystal_frac
    A   = st.grid.area
    vol(p) = p.frac_M_vol + p.frac_F_vol + chi * p.frac_S_vol
    V_all  = sum(A[c] * vol(th.points[c]) for c in b)
    V_all > 0 || return Tuple{Int,Vector{Float64}}[], 0.0
    f       = min(V_target / V_all, MAGERES_ERUPT_MAX_MELT_FRACTION)
    parcels = Tuple{Int,Vector{Float64}}[]
    for c in b
        p = th.points[c]
        x = zeros(size(st.Q, 1))
        for (frac, comp, h, kind) in ((f * p.frac_M, p.bulk_M, p.h_M, :melt), (f * p.frac_F, p.bulk_F, p.h_F, :fluid),
                                      (f * chi * p.frac_S, p.bulk_S, p.h_S, :solid))
            n = mageres_phase_moles(st, c, frac, comp)
            any(>(0), n) && (x .+= mageres_parcel(st, c, n, h, kind))
        end
        any(!iszero, x) && push!(parcels, (c, x))
    end
    return parcels, f * V_all
end

"""
    mageres_erupt!(st::MAGEResState)

    Erupt from an open chamber whose mobile body mean melt fraction exceeds `phi_erupt`, when armed by an injection
    (melt trigger, erupting `erupt_frac` of the body) or when the overpressure exceeds `dP_crit_MPa` (overpressure
    trigger, erupting the volume that releases the overpressure): remove the eruptible parcels, deflate the chamber,
    record the extracted layer and event. With the overpressure trigger, an overpressure above the critical value in
    a magma that cannot erupt is capped at the critical value (wall-rock failure without eruption). Returns the
    erupted full-section area [m^2], or 0.
"""
function mageres_erupt!(st::MAGEResState)
    th = st.thermo
    op = mageres_overpressure_on(st)
    th === nothing && return 0.0
    o       = st.opts
    dP_crit = 1e6 * o.dP_crit_MPa
    op && st.pressure.dP <= dP_crit && return 0.0
    if !mageres_eruptible(st) || !(st.erupt_armed || op)
        op && (st.pressure.dP = dP_crit)
        return 0.0
    end
    b        = findall(st.body)
    V_ch     = mageres_chamber_area(st.chamber)
    V_want   = op ? V_ch * st.pressure.beta * st.pressure.dP / MAGERES_SYMMETRY : o.erupt_frac * sum(st.grid.area[b])
    V_target = min(V_want, MAGERES_ERUPT_MAX_CHAMBER_FRACTION * V_ch / MAGERES_SYMMETRY)
    parcels, V = mageres_erupt_parcels(st, b, V_target)
    V > 0 || return 0.0
    out = zeros(size(st.Q, 1))
    for (c, x) in parcels
        @views st.Q[:, c] .-= x
        out .+= x
        th.needs_remin[c] = true
    end
    st.ledger.extracted .+= out
    st.erupt_armed        = false
    V_full                = MAGERES_SYMMETRY * V
    op && (st.pressure.dP -= V_full / (V_ch * st.pressure.beta))
    mageres_apply_event!(st, -V_full / st.chamber.I; mode = :compact)
    st.chamber.n_extractions += 1
    push!(st.pluton.layers, MAGEResLayer(st.t, V_full, out[MAGERES_IE] / out[MAGERES_IC] - MAGERES_T0_K,
                                         MAGERES_SYMMETRY .* out[mageres_ox_rows(st)],
                                         MAGERES_SYMMETRY .* out[mageres_tracer_rows(st)]))
    mageres_record!(st, :eruption, V_full)
    return V_full
end
