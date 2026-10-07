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

const MAGERES_SCP_MIN            = 300.0
const MAGERES_SCP_MAX            = 50_000.0
const MAGERES_FLUID_MIN_FRAC     = 1e-6
const MAGERES_P_FLOOR_KBAR       = 1e-3
const MAGERES_DEGAS_ROUNDS       = 3
const MAGERES_T_CORRECTION_MAX_C = 200.0
const MAGERES_CP_CONDUCTION_MAX  = 3000.0

"""
    mageres_conduction_cp(s_cp::Float64)

    Specific heat capacity used for heat conduction: `s_cp` capped at `MAGERES_CP_CONDUCTION_MAX`.
"""
mageres_conduction_cp(s_cp::Float64) = min(s_cp, MAGERES_CP_CONDUCTION_MAX)

const MAGERES_BOOST_MAX_SHIFT = 0.02
const MAGEResmSS              = Vector{MAGEMin_C.LibMAGEMin.mSS_data}

"""
    MAGEResTEPoint

    Trace-element data of one thermodynamic point: solid/melt concentration ratio of every element, melt and solid
    weight fractions, Zr saturation [ppm] at the point temperature with its 1/T slope [K], and the coefficients of the
    Zr diffusivity ln D = lnD_A - lnD_B/T [m²/s, K].
"""
struct MAGEResTEPoint
    D     :: Vector{Float64}
    w_M   :: Float64
    w_S   :: Float64
    C_sat :: Float64
    b_sat :: Float64
    lnD_A :: Float64
    lnD_B :: Float64
end

const MAGERES_NO_TE = MAGEResTEPoint(Float64[], 0.0, 0.0, NaN, 0.0, NaN, NaN)

"""
    MAGEResTE

    Trace-element setup of a run: element names, KD database, thermodynamic database, Zr saturation model, index of Zr,
    zircon switch, number and width [yr] of the zircon age bins, number of zircon families and length [yr] of a
    nucleation epoch, the injected and host compositions [µg/g] and the oxides of the run.
"""
struct MAGEResTE
    elements    :: Vector{String}
    kds         :: Any
    dtb         :: String
    zrsat       :: String
    i_zr        :: Int
    zircon      :: Bool
    n_bins      :: Int
    bin_yr      :: Float64
    n_fam       :: Int
    fam_yr      :: Float64
    C_injection :: Vector{Float64}
    C_host      :: Vector{Float64}
    oxides      :: Vector{String}
end

"""
    MAGEResThermoPoint

    Thermodynamic state of one cell from a MAGEMin minimization: temperature [°C], pressure [kbar], bulk,
    system and melt/solid/fluid properties, specific enthalpies, phase fractions, optional mSS guess, trace-element
    data and melt and solid bulk moduli [GPa].
"""
struct MAGEResThermoPoint
    T_last      :: Float64
    P           :: Float64
    bulk_last   :: Vector{Float64}
    rho         :: Float64
    s_cp        :: Float64
    alpha       :: Float64
    eta_M       :: Float64
    frac_M_vol  :: Float64
    frac_S_vol  :: Float64
    frac_F_vol  :: Float64
    frac_F      :: Float64
    bulk_M      :: Vector{Float64}
    bulk_F      :: Vector{Float64}
    M_sys       :: Float64
    h           :: Float64
    h_M         :: Float64
    h_S         :: Float64
    h_F         :: Float64
    frac_M      :: Float64
    rho_M       :: Float64
    alpha_M     :: Float64
    rho_S       :: Float64
    frac_S      :: Float64
    bulk_S      :: Vector{Float64}
    solid_ph    :: Vector{String}
    solid_frac  :: Vector{Float64}
    ph          :: Vector{String}
    ph_frac     :: Vector{Float64}
    ph_frac_wt  :: Vector{Float64}
    ph_frac_vol :: Vector{Float64}
    mSS         :: MAGEResmSS
    te          :: MAGEResTEPoint
    K_M         :: Float64
    K_S         :: Float64
end

"""
    MAGEResHostProfile

    Host rock equilibrated along the geotherm: node heights `y` [m], conserved-quantity densities
    (one column per node) and the thermodynamic point of each node.
"""
struct MAGEResHostProfile
    y       :: Vector{Float64}
    density :: Matrix{Float64}
    points  :: Vector{MAGEResThermoPoint}
end

"""
    MAGEResThermo

    Thermodynamic coupling state: per-cell points and re-minimization flags, host profile, injected magma
    point and density, oxide molar masses [kg/mol], MAGEMin data, counters, callbacks, boost flag and
    trace-element setup.
"""
mutable struct MAGEResThermo
    points            :: Vector{MAGEResThermoPoint}
    needs_remin       :: BitVector
    profile           :: MAGEResHostProfile
    injection         :: MAGEResThermoPoint
    injection_density :: Vector{Float64}
    Mox               :: Vector{Float64}
    mm                :: Any
    n_minimizations   :: Int
    calc_count        :: Vector{Int}
    n_min_reset       :: Int
    n_cell_calc       :: Int
    n_calls           :: Int
    n_rejected        :: Int
    n_clamped         :: Int
    progressbar       :: Bool
    callback_fn       :: Any
    stage_fn          :: Any
    boost             :: Bool
    te                :: Union{Nothing,MAGEResTE}
end

"""
    mageres_oxide_mass_kg(oxides::Vector{String})

    Molar masses [kg/mol] of `oxides`, from `MAGERES_OXIDE_MOLAR_MASS`.
"""
mageres_oxide_mass_kg(oxides::Vector{String}) = [MAGERES_OXIDE_MOLAR_MASS[o] / 1000 for o in oxides]

"""
    mageres_lithostatic_kbar(o::MAGEResOptions, y::Real)

    Lithostatic pressure [kbar] at height `y` [m] (negative below the surface), floored at `MAGERES_P_FLOOR_KBAR`.
"""
mageres_lithostatic_kbar(o::MAGEResOptions, y::Real) = max(MAGERES_P_FLOOR_KBAR, o.rho_host * o.g * max(-y, 0.0) / 1e8)

"""
    mageres_melt_ratio(p::MAGEResThermoPoint)

    Melt volume fraction of `p` relative to melt + solid, 0.0 when both are zero.
"""
mageres_melt_ratio(p::MAGEResThermoPoint) = (s = p.frac_M_vol + p.frac_S_vol; s > 0 ? p.frac_M_vol / s : 0.0)

"""
    mageres_finite_or_zero(x::Real)

    `x` as Float64 when finite, 0.0 otherwise.
"""
mageres_finite_or_zero(x::Real) = isfinite(x) ? Float64(x) : 0.0

"""
    mageres_bulk_shift(x::Vector{Float64}, ref::Vector{Float64})

    L1 distance between the normalized compositions `x` and `ref`; `Inf` when lengths differ,
    `x` is empty or either sum is not positive.
"""
function mageres_bulk_shift(x::Vector{Float64}, ref::Vector{Float64})
    (length(x) == length(ref) && !isempty(x)) || return Inf
    s1, s2 = sum(x), sum(ref)
    (s1 > 0 && s2 > 0) || return Inf
    return sum(abs(x[k] / s1 - ref[k] / s2) for k in eachindex(x))
end

"""
    mageres_solid_assemblage(out)

    Names and renormalized volume fractions of the solid phases (all but liq, fl, H2O) with a positive
    finite fraction in MAGEMin output `out`.
"""
function mageres_solid_assemblage(out)
    names = String[]
    fracs = Float64[]
    for i in 1:min(length(out.ph), length(out.ph_frac_vol))
        ph = out.ph[i]
        ph in ("liq", "fl", "H2O") && continue
        f = out.ph_frac_vol[i]
        (isfinite(f) && f > 0) || continue
        push!(names, ph)
        push!(fracs, f)
    end
    s = sum(fracs; init = 0.0)
    s > 0 && (fracs ./= s)
    return names, fracs
end

"""
    mageres_oxide_map(from::AbstractVector{<:AbstractString}, to::Vector{String})

    Index in `from` of each oxide of `to`, 0 where absent.
"""
mageres_oxide_map(from::AbstractVector{<:AbstractString}, to::Vector{String}) =
    [something(findfirst(==(o), from), 0) for o in to]

"""
    mageres_pick(v::AbstractVector, map::Vector{Int})

    Entries of `v` at the indices `map` as Float64; 0.0 for index 0, out-of-range indices and non-finite values.
"""
mageres_pick(v::AbstractVector, map::Vector{Int}) =
    Float64[(j == 0 || j > length(v)) ? 0.0 : mageres_finite_or_zero(v[j]) for j in map]

"""
    mageres_phase_H(o, i::Int)

    Molar enthalpy [kJ/mol] of phase `i` of MAGEMin output `o` (solution or pure phase).
"""
mageres_phase_H(o, i::Int) = o.ph_type[i] == 1 ? o.SS_vec[i].enthalpy : o.PP_vec[i-o.n_SS].enthalpy

"""
    mageres_phase_comp(o, i::Int)

    Composition of phase `i` of MAGEMin output `o` (solution or pure phase).
"""
mageres_phase_comp(o, i::Int) = o.ph_type[i] == 1 ? o.SS_vec[i].Comp : o.PP_vec[i-o.n_SS].Comp

"""
    mageres_phase_kind(ph::AbstractString)

    Phase group of `ph`: 1 for melt (liq), 3 for fluid (fl, H2O), 2 for solid.
"""
mageres_phase_kind(ph::AbstractString) = ph == "liq" ? 1 : ph in ("fl", "H2O") ? 3 : 2

"""
    mageres_phase_enthalpies(o, Mg::Vector{Float64})

    Specific enthalpies [J/kg] of the melt, solid and fluid of MAGEMin output `o`, from the phase enthalpies reported by
    MAGEMin; `Mg` are oxide molar masses. NaN for an absent group.
"""
function mageres_phase_enthalpies(o, Mg::Vector{Float64})
    H = zeros(3)
    M = zeros(3)
    for i in eachindex(o.ph)
        f = o.ph_frac[i]
        (isfinite(f) && f > 0) || continue
        Hi = mageres_phase_H(o, i)
        isfinite(Hi) || return (NaN, NaN, NaN)
        j     = mageres_phase_kind(o.ph[i])
        H[j] += f * Hi
        M[j] += f * sum(mageres_phase_comp(o, i) .* Mg)
    end
    return Tuple(M[j] > 0 ? H[j] * 1e6 / M[j] : NaN for j in 1:3)
end

"""
    mageres_thermo_point(th, out, T, P, x, map, hph = (NaN, NaN, NaN), keep_mss = false)

    MAGEResThermoPoint from MAGEMin output `out` for bulk `x`, with s_cp clamped to
    [`MAGERES_SCP_MIN`, `MAGERES_SCP_MAX`] and melt rho/alpha from the liquid when available; `nothing` (counted as
    rejected) for an invalid density.
"""
function mageres_thermo_point(th::MAGEResThermo, out, T::Float64, P::Float64, x::Vector{Float64}, map::Vector{Int},
                              hph::NTuple{3,Float64} = (NaN, NaN, NaN), keep_mss::Bool = false)
    (isfinite(out.rho) && out.rho > 0) || (th.n_rejected += 1; return nothing)
    cp = out.s_cp[1]
    if !(isfinite(cp) && MAGERES_SCP_MIN <= cp <= MAGERES_SCP_MAX)
        th.n_clamped += 1
        cp = clamp(isfinite(cp) ? cp : MAGERES_SCP_MIN, MAGERES_SCP_MIN, MAGERES_SCP_MAX)
    end
    sph, sfr       = mageres_solid_assemblage(out)
    h              = out.enthalpy[1] * 1e6 / out.M_sys
    bM             = mageres_pick(out.bulk_M, map)
    rho_M, alpha_M = out.rho, mageres_finite_or_zero(out.alpha[1])
    bS             = mageres_pick(out.bulk_S, map)
    li             = findfirst(==("liq"), out.ph)
    if li !== nothing && li <= out.n_SS && li <= length(out.SS_vec)
        isfinite(out.rho_M) && out.rho_M > 0 && (rho_M = out.rho_M)
        isfinite(out.SS_vec[li].alpha) && (alpha_M = out.SS_vec[li].alpha)
    end
    return MAGEResThermoPoint(T, P, copy(x), out.rho, cp, mageres_finite_or_zero(out.alpha[1]),
                              mageres_finite_or_zero(out.eta_M), mageres_finite_or_zero(out.frac_M_vol),
                              mageres_finite_or_zero(out.frac_S_vol), mageres_finite_or_zero(out.frac_F_vol),
                              mageres_finite_or_zero(out.frac_F), bM, mageres_pick(out.bulk_F, map), out.M_sys, h,
                              hph..., mageres_finite_or_zero(out.frac_M), rho_M, alpha_M,
                              mageres_finite_or_zero(out.rho_S), mageres_finite_or_zero(out.frac_S), bS, sph, sfr,
                              String.(out.ph), mageres_finite_or_zero.(out.ph_frac),
                              mageres_finite_or_zero.(out.ph_frac_wt), mageres_finite_or_zero.(out.ph_frac_vol),
                              keep_mss ? copy(out.mSS_vec) : MAGEResmSS(),
                              th.te === nothing ? MAGERES_NO_TE : mageres_te_point(th.te, out, bM, P),
                              Float64(out.bulkModulus_M), Float64(out.bulkModulus_S))
end

"""
    mageres_minimize!(th, oxides, xs, P, T; stage = "", step = 0, nsteps = 0, guess = nothing, keep_mss = th.boost)

    Minimize the molar bulks `xs` at `P` [kbar], `T` [°C] with MAGEMin, add the phase-group enthalpies and return
    one MAGEResThermoPoint (or `nothing` when rejected) per bulk; updates the counters and reports progress.
"""
function mageres_minimize!(th::MAGEResThermo, oxides::Vector{String}, xs::Vector{Vector{Float64}}, P::Vector{Float64},
                           T::Vector{Float64}; stage::AbstractString = "", step::Int = 0, nsteps::Int = 0,
                           guess::Union{Nothing,Vector{MAGEResmSS}} = nothing,
                           keep_mss::Union{Bool,AbstractVector{Bool}} = th.boost)
    isempty(xs) && return Union{Nothing,MAGEResThermoPoint}[]
    n = length(xs)
    th.stage_fn === nothing || th.stage_fn(stage, step, nsteps, n)
    th.progressbar && (println(step > 0 ? "Timestep $step/$nsteps ($stage): $n points to compute" :
                                          "$stage: $n points to compute"); flush(stdout))
    G  = guess === nothing ? nothing : guess
    ig = guess === nothing ? false : Bool[!isempty(g) for g in guess]
    t  = @elapsed out = multi_point_minimization(P, T, th.mm;
                                                 X           = [copy(x) for x in xs],
                                                 Xoxides     = oxides,
                                                 sys_in      = "mol",
                                                 scp         = 1,
                                                 progressbar = th.progressbar,
                                                 callback_fn = th.callback_fn,
                                                 G           = G,
                                                 iguess      = ig)
    th.progressbar && (println("Computed $n points in $(round(t, digits = 3)) seconds"); flush(stdout))
    map = mageres_oxide_map(out[1].oxides, oxides)
    Mg  = [MAGERES_OXIDE_MOLAR_MASS[o] for o in out[1].oxides]
    hph = [isfinite(out[k].rho) && out[k].rho > 0 ? mageres_phase_enthalpies(out[k], Mg) : (NaN, NaN, NaN) for k in 1:n]
    pts = Union{Nothing,MAGEResThermoPoint}[mageres_thermo_point(th, out[k], T[k], P[k], xs[k], map, hph[k],
                                                                 keep_mss isa Bool ? keep_mss : keep_mss[k])
                                            for k in eachindex(xs)]
    th.n_minimizations += length(xs)
    th.n_calls         += 1
    return pts
end

"""
    mageres_degas(x::Vector{Float64}, p::MAGEResThermoPoint)

    Removable fluid fraction of bulk `x` given the fluid of `p`, and the renormalized residual bulk;
    `(0.0, x)` when no fluid can be removed.
"""
function mageres_degas(x::Vector{Float64}, p::MAGEResThermoPoint)
    fF = p.frac_F
    fF > MAGERES_FLUID_MIN_FRAC || return 0.0, x
    bF = p.bulk_F
    s  = sum(bF)
    s > 0 || return 0.0, x
    xs = sum(x)
    f  = min(fF, 1.0)
    for k in eachindex(bF)
        bF[k] > 0 && (f = min(f, (x[k] / xs) / (bF[k] / s)))
    end
    f > 0 || return 0.0, x
    r  = max.(x ./ xs .- f .* bF ./ s, 0.0)
    rs = sum(r)
    rs > 0 || return 0.0, x
    return f, r ./ rs
end

"""
    mageres_equilibrate!(th::MAGEResThermo, o::MAGEResOptions, xs, P, T; stage = "")

    Minimize the bulks `xs` at `P` [kbar], `T` [°C], degassing and re-minimizing up to `MAGERES_DEGAS_ROUNDS` times
    when fluids are removed. Returns the points and final bulks; throws if MAGEMin fails.
"""
function mageres_equilibrate!(th::MAGEResThermo, o::MAGEResOptions, xs::Vector{Vector{Float64}}, P::Vector{Float64},
                              T::Vector{Float64}; stage::AbstractString = "")
    xs   = [copy(x) for x in xs]
    pts  = Vector{MAGEResThermoPoint}(undef, length(xs))
    todo = collect(eachindex(xs))
    for round in 1:MAGERES_DEGAS_ROUNDS
        isempty(todo) && break
        res  = mageres_minimize!(th, o.oxides, xs[todo], P[todo], T[todo];
                                 stage = round == 1 ? stage : "$stage, after degassing")
        next = Int[]
        for (k, i) in enumerate(todo)
            p = res[k]
            p === nothing && throw(ErrorException(@sprintf("MAGEMin failed at T = %.1f °C, P = %.3f kbar",
                                                           T[i], P[i])))
            pts[i] = p
            if o.fluid_treatment == "removed" && round < MAGERES_DEGAS_ROUNDS
                f, r = mageres_degas(xs[i], p)
                f > 0 && (xs[i] = r; push!(next, i))
            end
        end
        todo = next
    end
    return pts, xs
end

"""
    mageres_point_density(p::MAGEResThermoPoint, x::Vector{Float64}, T::Float64, Mox::Vector{Float64})

    Conserved quantities per unit volume for point `p` with bulk `x` at `T` [°C]:
    [energy, heat capacity, enthalpy, oxide moles...].
"""
function mageres_point_density(p::MAGEResThermoPoint, x::Vector{Float64}, T::Float64, Mox::Vector{Float64})
    n = p.rho / (p.M_sys / 1000) .* (x ./ sum(x))
    m = sum(n .* Mox)
    C = m * mageres_conduction_cp(p.s_cp)
    return vcat(C * (T + MAGERES_T0_K), C, m * p.h, n)
end

"""
    mageres_host_profile(th::MAGEResThermo, o::MAGEResOptions)

    Equilibrate the host bulk along the geotherm over the domain thickness and return the MAGEResHostProfile.
"""
function mageres_host_profile(th::MAGEResThermo, o::MAGEResOptions)
    H       = 1e3 * o.domain_thickness_km
    dT      = o.geotherm_gradient_C_km * o.domain_thickness_km
    nn      = max(2, ceil(Int, dT / (0.5 * o.dT_tol)) + 1)
    y       = collect(range(-H, 0.0; length = nn))
    T       = [o.T_surface_C - o.geotherm_gradient_C_km / 1e3 * yy for yy in y]
    P       = [mageres_lithostatic_kbar(o, yy) for yy in y]
    x0      = mageres_normalized(o.host_bulk)
    pts, xs = mageres_equilibrate!(th, o, [x0 for _ in 1:nn], P, T; stage = "Initial host-rock profile")
    dens    = reduce(hcat, [mageres_host_node_density(th, o, pts[j], xs[j], T[j]) for j in 1:nn])
    return MAGEResHostProfile(y, dens, pts)
end

"""
    mageres_profile_bracket(pr::MAGEResHostProfile, y::Real)

    Lower node index and linear interpolation weight of `y` (clamped to the profile) in the profile heights.
"""
function mageres_profile_bracket(pr::MAGEResHostProfile, y::Real)
    ys = pr.y
    yy = clamp(Float64(y), ys[1], ys[end])
    j  = clamp(searchsortedlast(ys, yy), 1, length(ys) - 1)
    return j, (yy - ys[j]) / (ys[j+1] - ys[j])
end

"""
    mageres_profile_density(pr::MAGEResHostProfile, y::Real)

    Host-profile conserved-quantity densities linearly interpolated at height `y`.
"""
function mageres_profile_density(pr::MAGEResHostProfile, y::Real)
    j, w = mageres_profile_bracket(pr, y)
    return (1 - w) .* pr.density[:, j] .+ w .* pr.density[:, j+1]
end

"""
    mageres_profile_point(pr::MAGEResHostProfile, y::Real)

    Host-profile thermodynamic point of the node nearest to height `y`.
"""
mageres_profile_point(pr::MAGEResHostProfile, y::Real) =
    ((j, w) = mageres_profile_bracket(pr, y); pr.points[w < 0.5 ? j : j + 1])

"""
    mageres_build_thermo(o::MAGEResOptions, mm; progressbar = true, callback_fn = nothing, stage_fn = nothing,
                         boost = o.boost_mode)

    Create the MAGEResThermo for `o`: host profile, and the injected magma equilibrated at the lens depth and
    `o.T_injection_C` with its conserved-quantity density (trace elements included when enabled). With
    `o.injection_melt_only`, only the melt of that equilibrium is injected.
"""
function mageres_build_thermo(o::MAGEResOptions, mm; progressbar::Bool = true, callback_fn = nothing,
                              stage_fn = nothing, boost::Bool = o.boost_mode)
    Mox   = mageres_oxide_mass_kg(o.oxides)
    x_inj = mageres_normalized(isempty(o.injection_bulk) ? o.magma_bulk : o.injection_bulk)
    y_c   = -1e3 * o.lens_depth_km
    dummy = MAGEResThermoPoint(NaN, NaN, Float64[], NaN, NaN, NaN, NaN, 0.0, 0.0, 0.0, 0.0, Float64[], Float64[], NaN,
                               NaN, NaN, NaN, NaN, 0.0, NaN, NaN, 0.0, 0.0, Float64[], String[], Float64[],
                               String[], Float64[], Float64[], Float64[], MAGEResmSS(), MAGERES_NO_TE, NaN, NaN)
    th    = MAGEResThermo(MAGEResThermoPoint[], falses(0),
                          MAGEResHostProfile(Float64[], zeros(0, 0), MAGEResThermoPoint[]), dummy, Float64[], Mox, mm,
                          0, Int[], 0, 0, 0, 0, 0, progressbar, callback_fn, stage_fn, boost, mageres_build_te(o))
    th.profile = mageres_host_profile(th, o)
    pts, xs    = mageres_equilibrate!(th, o, [x_inj], [mageres_lithostatic_kbar(o, y_c)], [o.T_injection_C];
                                      stage = "Injected magma")
    C_inj      = th.te === nothing ? Float64[] : th.te.C_injection
    if o.injection_melt_only
        pts_bulk = pts[1]
        (pts[1].frac_M > 0 && sum(pts[1].bulk_M) > 0) ||
            throw(ArgumentError(@sprintf("the injected composition has no melt at %.0f °C and %.2f kbar",
                                         o.T_injection_C, mageres_lithostatic_kbar(o, y_c))))
        pts, xs = mageres_equilibrate!(th, o, [mageres_normalized(pts[1].bulk_M)], [mageres_lithostatic_kbar(o, y_c)],
                                       [o.T_injection_C]; stage = "Injected melt")
        th.te === nothing || (C_inj = mageres_te_melt_concentration(pts_bulk, C_inj))
    end
    th.injection         = pts[1]
    th.injection_density = mageres_injection_node_density(th, o, pts[1], xs[1], o.T_injection_C, C_inj)
    return th
end

"""
    mageres_snapshot_thermo(th)

    Copy of `th` without the MAGEMin data and callbacks (per-cell arrays copied); `nothing` for `nothing`.
"""
mageres_snapshot_thermo(th::Nothing) = nothing
mageres_snapshot_thermo(th::MAGEResThermo) =
    MAGEResThermo(copy(th.points), copy(th.needs_remin), th.profile, th.injection, th.injection_density, th.Mox,
                  nothing, th.n_minimizations, copy(th.calc_count), th.n_min_reset, th.n_cell_calc, th.n_calls,
                  th.n_rejected, th.n_clamped, false, nothing, nothing, th.boost, th.te)
