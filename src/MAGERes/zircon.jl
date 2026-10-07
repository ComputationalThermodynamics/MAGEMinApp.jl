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

const MAGERES_ZRC_RHO           = 4650.0
const MAGERES_ZRC_ZR_FRAC       = 0.497644
const MAGERES_ZRC_NUC_RADIUS    = 1e-6
const MAGERES_ZRC_MAX_SUBSTEPS  = 1000
const MAGERES_ZRC_MAX_CHANGE    = 0.3
const MAGERES_ZRC_DISSOLVED_TOL = 1e-12
const MAGERES_ZRSAT_SLOPE       = Dict("WH" => 12900.0, "B" => 10108.0, "CB" => 5790.0 * log(10.0))
const MAGERES_ZR_CATIONS        = Dict("SiO2"  => ("Si", 1), "TiO2"  => ("Ti", 1), "Al2O3" => ("Al", 2),
                                       "FeO"   => ("Fe", 1), "Fe2O3" => ("Fe", 2), "MgO"   => ("Mg", 1),
                                       "CaO"   => ("Ca", 1), "Na2O"  => ("Na", 2), "K2O"   => ("K", 2),
                                       "H2O"   => ("H", 2),  "Cr2O3" => ("Cr", 2), "MnO"   => ("Mn", 1),
                                       "P2O5"  => ("P", 2))

"""
    mageres_zr_diffusivity_coefficients(oxides::Vector{String}, bM::Vector{Float64}, P_kbar::Float64)

    Coefficients (A, B) of the Zr diffusivity ln D = A - B/T [m²/s, T in K] of a melt of molar composition `bM` at
    `P_kbar`, from the cation mole fractions on a wet basis (Zhang & Xu 2016, Eq. 9). NaN when the melt is empty.
"""
function mageres_zr_diffusivity_coefficients(oxides::Vector{String}, bM::Vector{Float64}, P_kbar::Float64)
    cat = Dict("Si" => 0.0, "Al" => 0.0, "Fe" => 0.0, "Mg" => 0.0, "Ca" => 0.0, "H" => 0.0)
    tot = 0.0
    for (k, ox) in enumerate(oxides)
        haskey(MAGERES_ZR_CATIONS, ox) || continue
        name, n = MAGERES_ZR_CATIONS[ox]
        x       = n * bM[k]
        tot    += x
        haskey(cat, name) && (cat[name] += x)
    end
    tot > 0 || return NaN, NaN
    f(name) = cat[name] / tot
    P       = P_kbar / 10
    A       = -13.95 + 5.15 * (f("H") + 4.1 * f("Ca") - f("Mg"))
    B       = 36457 * (f("Si") + f("Al") - 1.8 * f("Fe")) - 11008 * P * (f("Si") + f("Al") - 2 / 3)
    return A, B
end

"""
    mageres_zr_diffusivity(p::MAGEResThermoPoint, T_C::Real)

    Zr diffusivity [m²/s] in the melt of point `p` at `T_C` [°C].
"""
mageres_zr_diffusivity(p::MAGEResThermoPoint, T_C::Real) = exp(p.te.lnD_A - p.te.lnD_B / (T_C + MAGERES_T0_K))

"""
    mageres_zr_saturation(p::MAGEResThermoPoint, T_C::Real)

    Zr concentration [µg/g] of the melt of point `p` at zircon saturation, shifted from the point temperature to
    `T_C` [°C] along the 1/T dependence of the saturation model.
"""
mageres_zr_saturation(p::MAGEResThermoPoint, T_C::Real) =
    p.te.C_sat * exp(p.te.b_sat * (1 / (p.T_last + MAGERES_T0_K) - 1 / (T_C + MAGERES_T0_K)))

"""
    mageres_zircon_bin(te::MAGEResTE, t_yr::Real)

    Position, within the zircon mass rows (inherited first), of the age bin containing model time `t_yr`.
"""
mageres_zircon_bin(te::MAGEResTE, t_yr::Real) = 1 + clamp(floor(Int, t_yr / te.bin_yr) + 1, 1, te.n_bins)

"""
    mageres_zircon_radius(Mz::Float64, N::Float64)

    Mean radius [m] of `N` zircon grains of total mass `Mz` [kg]; 0 without grains.
"""
mageres_zircon_radius(Mz::Float64, N::Float64) = (N > 0 && Mz > 0) ? cbrt(3 * Mz / (4π * MAGERES_ZRC_RHO * N)) : 0.0

"""
    mageres_zircon_rate_constant(a, N, D, Pe, rho_M, Cs, m_eff)

    Relaxation rate [1/s] of the melt Zr concentration toward saturation for `N` grains of radius `a` [m] in a Zr
    reservoir of mass `m_eff` [kg]: diffusive or convective boundary-layer exchange (Zhang & Xu 2016, Eqs. 14-18).
"""
mageres_zircon_rate_constant(a::Float64, N::Float64, D::Float64, Pe::Float64, rho_M::Float64, Cs::Float64,
                             m_eff::Float64) =
    4π * a * N * rho_M * D * (1 + cbrt(1 + Pe)) / 2 * MAGERES_ZRC_ZR_FRAC / ((MAGERES_ZRC_ZR_FRAC - Cs) * m_eff)

"""
    mageres_remove_zircon!(Q::Matrix{Float64}, rz::AbstractVector{Int}, jb::Int, c::Int, dM::Float64)

    Dissolve the zircon mass `dM` [kg] of cell `c`, from the youngest age bin `jb` down to the inherited row.
"""
function mageres_remove_zircon!(Q::Matrix{Float64}, rz::AbstractVector{Int}, jb::Int, c::Int, dM::Float64)
    left = dM
    for j in jb:-1:1
        take         = min(left, Q[rz[j], c])
        Q[rz[j], c] -= take
        left        -= take
        left <= 0 && break
    end
    return Q
end

"""
    mageres_zircon_family(te::MAGEResTE, t_yr::Real)

    Zircon family of grains nucleated at model time `t_yr`: 2 for the first nucleation epoch up to `te.n_fam` for the
    last (family 1 holds the inherited zircon).
"""
mageres_zircon_family(te::MAGEResTE, t_yr::Real) = 1 + clamp(floor(Int, t_yr / te.fam_yr) + 1, 1, te.n_fam - 1)

"""
    mageres_zircon_family_label(te::MAGEResTE, f::Int)

    Name of zircon family `f`: inherited, or the nucleation epoch [kyr].
"""
function mageres_zircon_family_label(te::MAGEResTE, f::Int)
    f == 1 && return "Inherited"
    t0  = (f - 2) * te.fam_yr / 1e3
    t1  = t0 + te.fam_yr / 1e3
    fmt = te.fam_yr < 1e4 ? (x -> @sprintf("%.1f", x)) : (x -> @sprintf("%.0f", x))
    f == te.n_fam && return "Born after $(fmt(t0)) kyr"
    return "Born $(fmt(t0))–$(fmt(t1)) kyr"
end

"""
    mageres_zircon_cell!(st::MAGEResState, c::Int, T_C::Float64, dt::Float64, jb::Int, fn::Int, convecting::Bool)

    Grow, nucleate or dissolve the zircon families of cell `c` over `dt` [s] at `T_C` [°C], exchanging Zr with the
    melt (and the solids in equilibrium with it) by rate-limited relaxation toward saturation, shared between the
    families by their exchange rates. Growth goes to age bin `jb`, nucleation to family `fn`, and dissolution removes
    the youngest zircon of each family first. Returns the zircon mass change [kg].
"""
function mageres_zircon_cell!(st::MAGEResState, c::Int, T_C::Float64, dt::Float64, jb::Int, fn::Int,
                              convecting::Bool)
    th = st.thermo
    te = th.te
    p  = th.points[c]
    q  = p.te
    (q.w_M > 0 && isfinite(q.C_sat) && isfinite(q.lnD_A) && p.rho_M > 0) || return 0.0
    Q     = st.Q
    o     = st.opts
    K     = te.n_fam
    iz    = mageres_te_rows(st)[te.i_zr]
    rN    = [mageres_zrc_N_row(st, f) for f in 1:K]
    rz    = [mageres_zrc_mass_rows(st, f) for f in 1:K]
    mc    = mageres_cell_mass(st, c)
    mM    = mc * q.w_M
    m_eff = mM + q.D[te.i_zr] * mc * q.w_S
    Cs    = 1e-6 * mageres_zr_saturation(p, T_C)
    Cz    = MAGERES_ZRC_ZR_FRAC
    (mM > 0 && m_eff > 0 && 0 < Cs < Cz) || return 0.0
    D     = mageres_zr_diffusivity(p, T_C)
    VM    = mM / p.rho_M
    Mf    = zeros(K)
    kf    = zeros(K)
    dMf   = zeros(K)
    t     = 0.0
    total = 0.0
    for _ in 1:MAGERES_ZRC_MAX_SUBSTEPS
        t < dt || break
        Z = Q[iz, c]
        C = Z / m_eff
        for f in 1:K
            Mf[f] = sum(@view Q[rz[f], c])
            N     = Q[rN[f], c]
            a     = mageres_zircon_radius(Mf[f], N)
            Pe    = convecting && p.eta_M > 0 && a > 0 ?
                    4 * o.g * a^3 * max(MAGERES_ZRC_RHO - p.rho_M, 0.0) / (9 * p.eta_M * D) : 0.0
            kf[f] = a > 0 ? mageres_zircon_rate_constant(a, N, D, Pe, p.rho_M, Cs, m_eff) : 0.0
        end
        k = sum(kf)
        if C > Cs && k <= 0
            Nn = o.zircon_nucleation_density * VM
            ms = Nn * MAGERES_ZRC_RHO * 4 / 3 * π * MAGERES_ZRC_NUC_RADIUS^3
            Cz * ms < Z - Cs * m_eff || break
            Q[rN[fn], c]      = Nn
            Q[rz[fn][jb], c] += ms
            Q[iz, c]         -= Cz * ms
            total            += ms
            continue
        end
        k > 0 || break
        h     = dt - t
        dM    = m_eff * (C - Cs) * (1 - exp(-k * h)) / Cz
        ratio = 0.0
        for f in 1:K
            kf[f] > 0 || continue
            dMf[f] = dM * kf[f] / k
            (dMf[f] < 0 && Cz * Mf[f] < MAGERES_ZRC_DISSOLVED_TOL * Z) && continue
            ratio = max(ratio, abs(dMf[f]) / (MAGERES_ZRC_MAX_CHANGE * Mf[f]))
        end
        if ratio > 1
            h  /= ratio
            dM  = m_eff * (C - Cs) * (1 - exp(-k * h)) / Cz
        end
        for f in 1:K
            kf[f] > 0 || continue
            d = dM * kf[f] / k
            if d <= -Mf[f] || (d < 0 && Cz * Mf[f] < MAGERES_ZRC_DISSOLVED_TOL * Z)
                Q[iz, c]    += Cz * Mf[f]
                Q[rz[f], c] .= 0.0
                Q[rN[f], c]  = 0.0
                total       -= Mf[f]
            elseif d >= 0
                Q[rz[f][jb], c] += d
                Q[iz, c]        -= Cz * d
                total           += d
            else
                mageres_remove_zircon!(Q, rz[f], jb, c, -d)
                Q[iz, c] -= Cz * d
                total    += d
            end
        end
        t += h
    end
    return total
end

"""
    mageres_zircon_step!(st::MAGEResState, dt::Float64)

    Advance the zircon of every cell with melt over `dt` [s] at the current cell temperatures; the age bin and the
    nucleation family are taken at the middle of the step. Returns `st`.
"""
function mageres_zircon_step!(st::MAGEResState, dt::Float64)
    te = mageres_te(st)
    (te === nothing || !te.zircon) && return st
    T  = mageres_temperature(st)
    tm = st.t - 0.5 * dt / MAGERES_SECONDS_PER_YEAR
    jb = mageres_zircon_bin(te, tm)
    fn = mageres_zircon_family(te, tm)
    for c in 1:mageres_ncells(st.grid)
        mageres_zircon_cell!(st, c, T[c], dt, jb, fn, st.body[c])
    end
    return st
end

"""
    mageres_zircon_bin_ages(te::MAGEResTE, t_erupt::Float64)

    Age [kyr] before the reference time `t_ref` [yr] of the middle of every zircon age bin of an eruption at
    `t_erupt` [yr] (the filled part of the bin containing the eruption).
"""
mageres_zircon_bin_ages(te::MAGEResTE, t_erupt::Float64, t_ref::Float64 = t_erupt) =
    [(t0 = (j - 1) * te.bin_yr; (t_ref - (t0 + min(te.bin_yr, max(t_erupt - t0, 0.0)) / 2)) / 1e3)
     for j in 1:te.n_bins]

"""
    MAGEResZirconGrain

    One synthetic zoned grain: family, radius [µm], spot centres [µm from the core, core spot first], measured spot
    ages [kyr before eruption, NaN for spots dominated by inherited zircon], their 1σ analytical uncertainties [kyr]
    and the radii [µm] of its growth zones.
"""
struct MAGEResZirconGrain
    family :: Int
    radius :: Float64
    spot_r :: Vector{Float64}
    ages   :: Vector{Float64}
    sigma  :: Vector{Float64}
    zones  :: Vector{Float64}
end

const MAGERES_ZIRCON_REL_SIGMA = Dict("LA_UPb" => 0.01, "TIMS_UPb" => 0.0005)

"""
    mageres_spot_sigma(o::MAGEResOptions, age_kyr::Real)

    1σ analytical uncertainty [kyr] of a spot age `age_kyr` [kyr before the reference time]: absolute for SIMS U-Th,
    relative to the absolute age (absolute age of the reference time + `age_kyr`) for the U-Pb methods.
"""
mageres_spot_sigma(o::MAGEResOptions, age_kyr::Real) =
    o.zircon_method == "SIMS_UTh" ? o.zircon_sigma_kyr :
    MAGERES_ZIRCON_REL_SIGMA[o.zircon_method] * (1e3 * o.zircon_eruption_age_Ma + age_kyr)

"""
    mageres_measure(o::MAGEResOptions, age_kyr::Float64, rng)

    Synthetic measurement of the true age `age_kyr` [kyr]: the age plus Gaussian analytical noise, and its 1σ [kyr].
"""
function mageres_measure(o::MAGEResOptions, age_kyr::Float64, rng)
    s = mageres_spot_sigma(o, age_kyr)
    return age_kyr + s * randn(rng), s
end

"""
    MAGEResZirconSample

    Zircon erupted by one eruption: time [yr], age-bin mass [kg] with bin ages [kyr before eruption], inherited mass,
    grain number, synthetic single-spot measured ages [kyr] with their 1σ [kyr] and number of them that are inherited,
    grain number and mass
    (inherited, then per age bin) of every family, synthetic zoned grains analysed by spot traverses, and the time
    of the first eruption and number of eruptions merged into the sample.
"""
struct MAGEResZirconSample
    t           :: Float64
    mass        :: Vector{Float64}
    ages        :: Vector{Float64}
    inherited   :: Float64
    N           :: Float64
    grains      :: Vector{Float64}
    sigma       :: Vector{Float64}
    n_inherited :: Int
    fam_N       :: Vector{Float64}
    fam_mass    :: Vector{Vector{Float64}}
    zoned       :: Vector{MAGEResZirconGrain}
    t_first     :: Float64
    n_eruptions :: Int
end

const MAGERES_SPOT_INHERITED_FRAC = 0.05

"""
    mageres_zircon_grain(te::MAGEResTE, o::MAGEResOptions, f::Int, m::Vector{Float64}, N::Float64,
                         t_erupt::Float64, t_ref::Float64, rng)

    Synthetic grain of family `f` with zircon mass `m` (inherited, then per age bin) shared by `N` grains, analysed
    by a core-to-rim traverse of spots of diameter `o.zircon_spot_um`: a core spot, then spots every diameter inward
    from the rim that do not overlap it (one whole-grain spot when the grain is smaller than a spot). Each spot age is
    the mean of the growth zones under it weighted by their radial overlap, plus a uniform offset within one age bin,
    measured with the analytical uncertainty of `o.zircon_method`; spots with at least `MAGERES_SPOT_INHERITED_FRAC`
    inherited zircon are flagged NaN.
"""
function mageres_zircon_grain(te::MAGEResTE, o::MAGEResOptions, f::Int, m::Vector{Float64}, N::Float64,
                              t_erupt::Float64, t_ref::Float64, rng)
    d_um = o.zircon_spot_um
    M  = sum(m)
    a  = 1e6 * mageres_zircon_radius(M, N)
    r  = a .* cbrt.(cumsum(m) ./ M)
    r0 = vcat(0.0, r[1:end-1])
    if 2a <= d_um
        spots = [(0.0, 0.0, a)]
    else
        spots = [(0.0, 0.0, d_um / 2)]
        rc    = a - d_um / 2
        rim   = Tuple{Float64,Float64,Float64}[]
        while rc - d_um / 2 >= d_um / 2 - 1e-9
            push!(rim, (rc, rc - d_um / 2, rc + d_um / 2))
            rc -= d_um
        end
        append!(spots, reverse(rim))
    end
    bin_ages = mageres_zircon_bin_ages(te, t_erupt, t_ref)
    ages     = Float64[]
    sigma    = Float64[]
    for (_, lo, hi) in spots
        w  = [max(0.0, min(hi, r[j]) - max(lo, r0[j])) for j in eachindex(m)]
        ws = sum(w)
        if ws <= 0 || w[1] / ws >= MAGERES_SPOT_INHERITED_FRAC
            push!(ages, NaN)
            push!(sigma, NaN)
        else
            age     = sum(w[j+1] * bin_ages[j] for j in 1:te.n_bins) / sum(w[2:end])
            a_m, sm = mageres_measure(o, max(age + (rand(rng) - 0.5) * te.bin_yr / 1e3, 0.0), rng)
            push!(ages, a_m)
            push!(sigma, sm)
        end
    end
    return MAGEResZirconGrain(f, a, [s[1] for s in spots], ages, sigma, r)
end

"""
    mageres_zircon_samples(st::MAGEResState; t_ref = st.t)

    One MAGEResZirconSample per eruption of `st` with zircon: `st.opts.zircon_synthetic_grains` synthetic single-spot
    ages drawn from the erupted zircon mass (uniformly inside each age bin), and as many zoned grains drawn from the
    families by grain number, analysed with spots of `st.opts.zircon_spot_um`. Ages are measured before the reference
    time `t_ref` [yr] (the latest output) with the analytical uncertainty of the dating method. Reproducible per
    eruption.
"""
function mageres_zircon_samples(st::MAGEResState; t_ref::Float64 = st.t)
    te = mageres_te(st)
    (te === nothing || !te.zircon) && return MAGEResZirconSample[]
    n   = st.opts.zircon_synthetic_grains
    out = MAGEResZirconSample[]
    for (k, l) in enumerate(st.pluton.layers)
        length(l.tracers) >= mageres_zrc_N_index(te, te.n_fam) + 1 + te.n_bins || continue
        fam_N    = [l.tracers[mageres_zrc_N_index(te, f)] for f in 1:te.n_fam]
        fam_mass = [l.tracers[mageres_zrc_mass_index(te, f)] for f in 1:te.n_fam]
        inh      = sum(m[1] for m in fam_mass)
        mass     = reduce(+, (m[2:end] for m in fam_mass))
        tot      = inh + sum(mass)
        ages     = mageres_zircon_bin_ages(te, l.t, t_ref)
        grains   = Float64[]
        sigma    = Float64[]
        zoned    = MAGEResZirconGrain[]
        n_inh    = 0
        if tot > 0
            rng = MersenneTwister(k)
            w   = cumsum(vcat(inh, mass)) ./ tot
            for _ in 1:n
                j = min(searchsortedfirst(w, rand(rng)), length(w))
                if j == 1
                    n_inh += 1
                else
                    t0 = (j - 2) * te.bin_yr
                    t1 = min(t0 + te.bin_yr, l.t)
                    a_m, sm = mageres_measure(st.opts, (t_ref - (t0 + rand(rng) * max(t1 - t0, 0.0))) / 1e3, rng)
                    push!(grains, a_m)
                    push!(sigma, sm)
                end
            end
            ok = [f for f in 1:te.n_fam if fam_N[f] > 0 && sum(fam_mass[f]) > 0]
            if !isempty(ok)
                wn = cumsum(fam_N[ok]) ./ sum(fam_N[ok])
                for _ in 1:n
                    f = ok[min(searchsortedfirst(wn, rand(rng)), length(ok))]
                    push!(zoned, mageres_zircon_grain(te, st.opts, f, fam_mass[f], fam_N[f], l.t, t_ref, rng))
                end
            end
        end
        push!(out, MAGEResZirconSample(l.t, mass, ages, inh, sum(fam_N), grains, sigma, n_inh, fam_N, fam_mass,
                                       zoned, l.t, 1))
    end
    return out
end

"""
    mageres_combine_zircon_samples(samples::Vector{MAGEResZirconSample}, n::Int)

    One sample merging the eruptions `samples`: summed zircon, and about `n` synthetic single spots and zoned grains
    taken from the eruptions in proportion to their erupted zircon mass and grain number. Ages stay relative to
    each grain's own eruption.
"""
function mageres_combine_zircon_samples(samples::Vector{MAGEResZirconSample}, n::Int)
    length(samples) == 1 && return samples[1]
    M     = [s.inherited + sum(s.mass) for s in samples]
    Ng    = [s.N for s in samples]
    take(v, k) = v[1:min(k, length(v))]
    grains = Float64[]
    sigma  = Float64[]
    n_inh  = 0
    zoned  = MAGEResZirconGrain[]
    for (k, s) in enumerate(samples)
        ns     = sum(M) > 0 ? round(Int, n * M[k] / sum(M)) : 0
        frac   = ns / max(length(s.grains) + s.n_inherited, 1)
        ng     = round(Int, frac * length(s.grains))
        append!(grains, take(s.grains, ng))
        append!(sigma, take(s.sigma, ng))
        n_inh += round(Int, frac * s.n_inherited)
        nz     = sum(Ng) > 0 ? round(Int, n * Ng[k] / sum(Ng)) : 0
        append!(zoned, take(s.zoned, nz))
    end
    last = samples[end]
    return MAGEResZirconSample(last.t, reduce(+, (s.mass for s in samples)), last.ages,
                               sum(s.inherited for s in samples), sum(Ng), grains, sigma, n_inh,
                               reduce(+, (s.fam_N for s in samples)),
                               [reduce(+, (s.fam_mass[f] for s in samples)) for f in eachindex(last.fam_mass)],
                               zoned, samples[1].t_first, sum(s.n_eruptions for s in samples))
end

"""
    mageres_eruption_label(t_first::Float64, t_last::Float64, n::Int)

    Label of one eruption at `t_last` [yr], or of `n` merged eruptions from `t_first` to `t_last`.
"""
mageres_eruption_label(t_first::Float64, t_last::Float64, n::Int) =
    n == 1 ? @sprintf("Eruption at %.1f kyr", t_last / 1e3) :
             @sprintf("%d eruptions, %.1f–%.1f kyr", n, t_first / 1e3, t_last / 1e3)
