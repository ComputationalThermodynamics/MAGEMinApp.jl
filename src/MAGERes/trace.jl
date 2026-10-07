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

const MAGERES_TE_INJECTION_TEST = 0
const MAGERES_TE_HOST_TEST      = 1
const MAGERES_ZRC_SOLID_MIN     = 1e-3

"""
    mageres_te_defaults(test::Int)

    Element names and concentrations [µg/g] of the predefined trace-element composition `test` of the app.
"""
function mageres_te_defaults(test::Int)
    dbte = AppData.dbte
    i    = something(findfirst(==(test), dbte.test), 1)
    return String.(dbte.elements[i]), Float64.(dbte.μg_g[i])
end

"""
    mageres_te_inputs(o::MAGEResOptions)

    Element names and injected and host concentrations [µg/g] of `o`; predefined compositions (tonalite injection,
    basalt host) replace empty entries.
"""
function mageres_te_inputs(o::MAGEResOptions)
    if isempty(o.te_elements)
        el, C_inj = mageres_te_defaults(MAGERES_TE_INJECTION_TEST)
        _, C_host = mageres_te_defaults(MAGERES_TE_HOST_TEST)
        return el, C_inj, C_host
    end
    el     = copy(o.te_elements)
    C_inj  = isempty(o.te_injection_ppm) ? mageres_te_lookup(MAGERES_TE_INJECTION_TEST, el) : copy(o.te_injection_ppm)
    C_host = isempty(o.te_host_ppm)      ? mageres_te_lookup(MAGERES_TE_HOST_TEST, el)      : copy(o.te_host_ppm)
    return el, C_inj, C_host
end

"""
    mageres_te_lookup(test::Int, elements::Vector{String})

    Concentrations [µg/g] of `elements` in the predefined trace-element composition `test`, 0 where absent.
"""
function mageres_te_lookup(test::Int, elements::Vector{String})
    el, C = mageres_te_defaults(test)
    return [(i = findfirst(==(e), el); i === nothing ? 0.0 : C[i]) for e in elements]
end

"""
    mageres_build_te(o::MAGEResOptions)

    Trace-element setup of `o` (KD database, element order, Zr index, zircon age bins and compositions on the KD
    element list); `nothing` when trace elements are disabled.
"""
function mageres_build_te(o::MAGEResOptions)
    o.te_enabled || return nothing
    kds        = build_kds_database(o.kds_mod)
    el, Ci, Ch = mageres_te_inputs(o)
    elements   = String.(kds.element_name)
    i_zr       = something(findfirst(==("Zr"), elements), 0)
    zircon     = i_zr > 0 && o.zrsat_mod != "none"
    n_bins     = zircon ? max(1, ceil(Int, o.run_time_yr / o.zircon_age_bin_yr - 1e-9)) : 0
    n_fam      = zircon ? o.zircon_families : 0
    fam_yr     = o.run_time_yr / max(o.zircon_families - 1, 1)
    return MAGEResTE(elements, kds, o.database, o.zrsat_mod, i_zr, zircon, n_bins, o.zircon_age_bin_yr, n_fam, fam_yr,
                     MAGEMin_C.adjust_chemical_system(kds, Ci, el), MAGEMin_C.adjust_chemical_system(kds, Ch, el),
                     copy(o.oxides))
end

"""
    mageres_te(st::MAGEResState)

    Trace-element setup of `st`, `nothing` when trace elements are disabled.
"""
mageres_te(st::MAGEResState) = st.thermo === nothing ? nothing : st.thermo.te

"""
    mageres_ox_rows(st::MAGEResState)

    Rows of `st.Q` holding the oxide moles.
"""
mageres_ox_rows(st::MAGEResState) = MAGERES_IN0:(MAGERES_IN0 + length(st.opts.oxides) - 1)

"""
    mageres_has_volume_row(o::MAGEResOptions)

    True when the conserved quantities end with a material-volume row (overpressure eruption trigger).
"""
mageres_has_volume_row(o::MAGEResOptions) = o.eruption_trigger == "overpressure"

"""
    mageres_volume_row(st::MAGEResState)

    Row of `st.Q` holding the material volume [m²] of every cell (last row, overpressure trigger only).
"""
mageres_volume_row(st::MAGEResState) = size(st.Q, 1)

"""
    mageres_tracer_rows(st::MAGEResState)

    Rows of `st.Q` after the oxides: trace-element masses, then one block per zircon family (grain number,
    inherited zircon mass, zircon mass per age bin), before the material-volume row. Empty without trace elements.
"""
mageres_tracer_rows(st::MAGEResState) =
    (MAGERES_IN0 + length(st.opts.oxides)):(size(st.Q, 1) - (mageres_has_volume_row(st.opts) ? 1 : 0))

"""
    mageres_te_rows(st::MAGEResState)

    Rows of `st.Q` holding the mass of each trace element outside zircon [kg/m].
"""
function mageres_te_rows(st::MAGEResState)
    n0 = MAGERES_IN0 + length(st.opts.oxides)
    te = mageres_te(st)
    return te === nothing ? (n0:n0-1) : (n0:n0+length(te.elements)-1)
end

"""
    mageres_zrc_N_index(te::MAGEResTE, f::Int)

    Position, within the tracer rows, of the grain number of zircon family `f`.
"""
mageres_zrc_N_index(te::MAGEResTE, f::Int) = length(te.elements) + (f - 1) * (2 + te.n_bins) + 1

"""
    mageres_zrc_mass_index(te::MAGEResTE, f::Int)

    Positions, within the tracer rows, of the zircon mass of family `f`: inherited zircon first, then one per age bin.
"""
mageres_zrc_mass_index(te::MAGEResTE, f::Int) = (i = mageres_zrc_N_index(te, f); (i+1):(i+1+te.n_bins))

"""
    mageres_zrc_all_mass_index(te::MAGEResTE)

    Positions, within the tracer rows, of the zircon mass of all families.
"""
mageres_zrc_all_mass_index(te::MAGEResTE) =
    reduce(vcat, (collect(mageres_zrc_mass_index(te, f)) for f in 1:te.n_fam); init = Int[])

"""
    mageres_zrc_N_row(st::MAGEResState, f::Int)

    Row of `st.Q` holding the number of grains [1/m] of zircon family `f`.
"""
mageres_zrc_N_row(st::MAGEResState, f::Int) =
    first(mageres_tracer_rows(st)) - 1 + mageres_zrc_N_index(mageres_te(st), f)

"""
    mageres_zrc_mass_rows(st::MAGEResState, f::Int)

    Rows of `st.Q` holding the zircon mass [kg/m] of family `f`: inherited zircon first, then one row per age bin.
"""
mageres_zrc_mass_rows(st::MAGEResState, f::Int) =
    (first(mageres_tracer_rows(st)) - 1) .+ mageres_zrc_mass_index(mageres_te(st), f)

"""
    mageres_te_point(te::MAGEResTE, out, bM::Vector{Float64}, P::Float64)

    Trace-element data of MAGEMin output `out` with melt composition `bM` at `P` [kbar]: solid/melt ratios from
    `TE_prediction`, melt and solid weight fractions, and the Zr saturation and diffusivity coefficients when the
    point has melt and zircon is modelled.
"""
function mageres_te_point(te::MAGEResTE, out, bM::Vector{Float64}, P::Float64)
    n  = length(te.elements)
    wM = mageres_finite_or_zero(out.frac_M_wt)
    wS = mageres_finite_or_zero(out.frac_S_wt)
    D  = ones(n)
    if wM > 0 && wS > 0
        r = MAGEMin_C.TE_prediction(out, ones(n), te.kds, te.dtb)
        for e in 1:n
            (isfinite(r.Cliq[e]) && isfinite(r.Csol[e]) && r.Cliq[e] > 0) && (D[e] = max(r.Csol[e] / r.Cliq[e], 0.0))
        end
    end
    (te.zircon && wM > 0) || return MAGEResTEPoint(D, wM, wS, NaN, 0.0, NaN, NaN)
    C_sat = Float64(MAGEMin_C.zirconium_saturation(out; model = te.zrsat))
    A, B  = mageres_zr_diffusivity_coefficients(te.oxides, bM, P)
    return MAGEResTEPoint(D, wM, wS, C_sat > 0 ? C_sat : NaN, MAGERES_ZRSAT_SLOPE[te.zrsat], A, B)
end

"""
    mageres_te_melt_concentration(p::MAGEResThermoPoint, C::Vector{Float64})

    Melt concentrations [µg/g] of the bulk concentrations `C` partitioned at point `p`.
"""
mageres_te_melt_concentration(p::MAGEResThermoPoint, C::Vector{Float64}) =
    [(d = p.te.w_M + p.te.D[e] * p.te.w_S; d > 0 ? C[e] / d : C[e]) for e in eachindex(C)]

"""
    mageres_density_mass(d::Vector{Float64}, Mox::Vector{Float64})

    Mass per unit volume [kg/m³] of the conserved-quantity density `d`.
"""
mageres_density_mass(d::Vector{Float64}, Mox::Vector{Float64}) =
    sum(d[MAGERES_IN0+k-1] * Mox[k] for k in eachindex(Mox))

"""
    mageres_tracer_density(te, p::MAGEResThermoPoint, rho::Float64, C::Vector{Float64}; inherited, radius)

    Tracer rows per unit volume of a material of density `rho` [kg/m³] and trace elements `C` [µg/g] at point `p`.
    With `inherited`, the Zr above what the melt and solids hold at saturation forms zircon of grain `radius` [m].
"""
mageres_tracer_density(te::Nothing, p::MAGEResThermoPoint, rho::Float64, C::Vector{Float64}; inherited::Bool,
                       radius::Float64) = Float64[]

function mageres_tracer_density(te::MAGEResTE, p::MAGEResThermoPoint, rho::Float64, C::Vector{Float64};
                                inherited::Bool, radius::Float64)
    x = rho .* C .* 1e-6
    te.zircon || return x
    z = zeros(te.n_fam * (2 + te.n_bins))
    if inherited
        C0   = C[te.i_zr]
        q    = p.te
        free = q.w_M > 0 && isfinite(q.C_sat) ? min(C0, q.C_sat * (q.w_M + q.D[te.i_zr] * q.w_S)) : 0.0
        Mz   = rho * (C0 - free) * 1e-6 / MAGERES_ZRC_ZR_FRAC
        x[te.i_zr] = rho * free * 1e-6
        z[2]       = Mz
        z[1]       = Mz / (MAGERES_ZRC_RHO * 4 / 3 * π * radius^3)
    end
    return vcat(x, z)
end

"""
    mageres_host_node_density(th::MAGEResThermo, o::MAGEResOptions, p::MAGEResThermoPoint, x, T::Float64)

    Conserved-quantity density of a host-profile node with point `p`, bulk `x` and temperature `T` [°C], with the
    host trace elements and inherited zircon when enabled, and the material volume (1 m³/m³) with the overpressure
    trigger.
"""
function mageres_host_node_density(th::MAGEResThermo, o::MAGEResOptions, p::MAGEResThermoPoint, x::Vector{Float64},
                                   T::Float64)
    d = mageres_point_density(p, x, T, th.Mox)
    v = mageres_has_volume_row(o) ? [1.0] : Float64[]
    th.te === nothing && return isempty(v) ? d : vcat(d, v)
    return vcat(d, mageres_tracer_density(th.te, p, mageres_density_mass(d, th.Mox), th.te.C_host;
                                          inherited = true,
                                          radius    = 1e-6 * o.zircon_host_radius_um), v)
end

"""
    mageres_injection_node_density(th::MAGEResThermo, o::MAGEResOptions, p::MAGEResThermoPoint, x, T::Float64,
                                   C::Vector{Float64})

    Conserved-quantity density of the injected magma with point `p`, bulk `x`, temperature `T` [°C], trace elements
    `C` [µg/g] when enabled, and the material volume (1 m³/m³) with the overpressure trigger.
"""
function mageres_injection_node_density(th::MAGEResThermo, o::MAGEResOptions, p::MAGEResThermoPoint,
                                        x::Vector{Float64}, T::Float64, C::Vector{Float64})
    d = mageres_point_density(p, x, T, th.Mox)
    v = mageres_has_volume_row(o) ? [1.0] : Float64[]
    th.te === nothing && return isempty(v) ? d : vcat(d, v)
    return vcat(d, mageres_tracer_density(th.te, p, mageres_density_mass(d, th.Mox), C;
                                          inherited = false,
                                          radius    = 0.0), v)
end

"""
    mageres_phase_concentration(p::MAGEResThermoPoint, e::Int, X::Float64, m::Float64, kind::Symbol)

    Concentration (mass fraction) of element `e` in phase group `kind` (:melt or :solid) of a cell of mass `m` holding
    the element mass `X`, from the partitioning of point `p`; the bulk concentration when it cannot be partitioned.
"""
function mageres_phase_concentration(p::MAGEResThermoPoint, e::Int, X::Float64, m::Float64, kind::Symbol)
    q = p.te
    isempty(q.D) && return X / m
    d = m * (q.w_M + q.D[e] * q.w_S)
    d > 0 || return X / m
    return kind == :melt ? X / d : q.D[e] * X / d
end

"""
    mageres_zircon_share(p::MAGEResThermoPoint, m::Float64, mc::Float64, kind::Symbol)

    Fraction of the zircon of a cell of mass `mc` carried by a parcel of mass `m` of phase group `kind`: zircon
    follows the solids, or the melt when the cell has (almost) no solid.
"""
function mageres_zircon_share(p::MAGEResThermoPoint, m::Float64, mc::Float64, kind::Symbol)
    q = p.te
    kind == :fluid && return 0.0
    if q.w_S > MAGERES_ZRC_SOLID_MIN
        return kind == :solid ? min(1.0, m / (mc * q.w_S)) : 0.0
    end
    return kind == :melt && q.w_M > 0 ? min(1.0, m / (mc * q.w_M)) : 0.0
end

"""
    mageres_parcel_tracers(st::MAGEResState, c::Int, m::Float64, kind::Symbol)

    Tracer rows of a parcel of mass `m` [kg/m] of phase group `kind` (:melt, :solid or :fluid) taken from cell `c`:
    partitioned trace elements (none in fluid) and the zircon share. Empty without trace elements.
"""
function mageres_parcel_tracers(st::MAGEResState, c::Int, m::Float64, kind::Symbol)
    r = mageres_tracer_rows(st)
    isempty(r) && return Float64[]
    x  = zeros(length(r))
    mc = mageres_cell_mass(st, c)
    (m > 0 && mc > 0 && kind != :fluid) || return x
    p  = st.thermo.points[c]
    ne = length(mageres_te_rows(st))
    for e in 1:ne
        X = st.Q[r[e], c]
        X > 0 && (x[e] = min(mageres_phase_concentration(p, e, X, mc, kind) * m, X))
    end
    s = isempty(p.te.D) ? m / mc : mageres_zircon_share(p, m, mc, kind)
    if s > 0
        for k in ne+1:length(r)
            x[k] = s * st.Q[r[k], c]
        end
    end
    return x
end

"""
    mageres_te_totals(st::MAGEResState, v::AbstractVector{Float64})

    Total mass of each trace element in the conserved-quantity vector `v`, Zr in zircon included.
"""
function mageres_te_totals(st::MAGEResState, v::AbstractVector{Float64})
    te = mageres_te(st)
    te === nothing && return Float64[]
    x = v[mageres_te_rows(st)]
    te.zircon && (x[te.i_zr] += MAGERES_ZRC_ZR_FRAC * sum(v[(first(mageres_tracer_rows(st)) - 1) .+
                                                             mageres_zrc_all_mass_index(te)]))
    return x
end

"""
    mageres_te_error(st::MAGEResState, total::Vector{Float64}, expct::Vector{Float64})

    Largest relative trace-element mass error between the content `total` and the ledger expectation `expct`;
    0 without trace elements.
"""
function mageres_te_error(st::MAGEResState, total::Vector{Float64}, expct::Vector{Float64})
    te = mageres_te(st)
    te === nothing && return 0.0
    L  = st.ledger
    tt = mageres_te_totals(st, total)
    tx = mageres_te_totals(st, expct)
    ti = mageres_te_totals(st, L.initial)
    tj = mageres_te_totals(st, L.injected)
    tf = mageres_te_totals(st, L.inflow)
    return maximum((abs(tt[e] - tx[e]) / max(abs(ti[e]), abs(tj[e]), abs(tf[e]), abs(tt[e]), 1e-300)
                    for e in eachindex(tt)); init = 0.0)
end

"""
    mageres_layer_te(layer::MAGEResLayer, te::MAGEResTE, Mox::Vector{Float64})

    Concentrations [µg/g] of every trace element (Zr in zircon included) in the source or pluton `layer`.
"""
function mageres_layer_te(layer::MAGEResLayer, te::MAGEResTE, Mox::Vector{Float64})
    ne = length(te.elements)
    m  = sum(layer.moles .* Mox)
    (m > 0 && length(layer.tracers) >= ne) || return fill(NaN, ne)
    x  = layer.tracers[1:ne]
    te.zircon && (x[te.i_zr] += MAGERES_ZRC_ZR_FRAC * sum(layer.tracers[mageres_zrc_all_mass_index(te)]))
    return x ./ m .* 1e6
end
