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

const MAGERES_GAS_CONSTANT = 8.314462618
const MAGERES_K_MELT_GPA   = 15.0
const MAGERES_K_SOLID_GPA  = 80.0

"""
    mageres_overpressure_on(st::MAGEResState)

    True when eruptions are triggered by chamber overpressure.
"""
mageres_overpressure_on(st::MAGEResState) = st.thermo !== nothing && mageres_has_volume_row(st.opts)

"""
    mageres_phase_density(p::MAGEResThermoPoint, kind::Symbol)

    Density [kg/m³] of the melt, solid or fluid (`kind`) of point `p`, the system density when it is not available.
"""
function mageres_phase_density(p::MAGEResThermoPoint, kind::Symbol)
    kind == :melt  && p.rho_M > 0 && return p.rho_M
    kind == :solid && p.rho_S > 0 && return p.rho_S
    if kind == :fluid && p.frac_F_vol > 0
        wF = sum((p.ph_frac_wt[i] for i in eachindex(p.ph) if p.ph[i] in ("fl", "H2O")); init = 0.0)
        wF > 0 && return p.rho * wF / p.frac_F_vol
    end
    return p.rho
end

"""
    mageres_volume_refresh!(st::MAGEResState, cells)

    Reset the material volume of `cells`, whose thermodynamic points were just computed, to their mass over their
    density, and add the change of the magma volume (cells weighted by magma fraction, full section) [m²] to the
    phase-change volume source. Returns that change.
"""
function mageres_volume_refresh!(st::MAGEResState, cells)
    mageres_overpressure_on(st) || return 0.0
    th = st.thermo
    rv = mageres_volume_row(st)
    dV = 0.0
    for c in cells
        p = th.points[c]
        p.rho > 0 || continue
        V  = mageres_cell_mass(st, c) / p.rho
        dV += st.grid.frac[c] * (V - st.Q[rv, c])
        st.Q[rv, c] = V
    end
    dV *= MAGERES_SYMMETRY
    st.pressure.dV_phase_pending += dV
    return dV
end

"""
    mageres_volume_rebaseline!(st::MAGEResState)

    After a remap, reset the material volume of the cells whose thermodynamic point is still valid to their mass
    over their density, without counting it as a volume change. Returns `st`.
"""
function mageres_volume_rebaseline!(st::MAGEResState)
    mageres_overpressure_on(st) || return st
    th = st.thermo
    rv = mageres_volume_row(st)
    for c in 1:mageres_ncells(st.grid)
        (th.needs_remin[c] || th.points[c].rho <= 0) && continue
        st.Q[rv, c] = mageres_cell_mass(st, c) / th.points[c].rho
    end
    return st
end

"""
    mageres_add_recharge!(st::MAGEResState, V::Float64)

    Book an injection of full-section area `V` [m²]: its volume pressurises the chamber at a constant rate over the
    recharge time (the injection period when `recharge_time_yr` is 0), and the phase changes caused by mixing it in
    are counted when the mixed cells are equilibrated. Returns `st`.
"""
function mageres_add_recharge!(st::MAGEResState, V::Float64)
    o  = st.opts
    tr = o.recharge_time_yr > 0 ? o.recharge_time_yr : o.injection_period_yr
    pr = st.pressure
    tr > 0 ? push!(pr.inflow, (V / tr, st.t, st.t + tr)) : (pr.dV_pending += V)
    return st
end

"""
    mageres_recharge_volume!(st::MAGEResState, dt_yr::Float64)

    Recharge volume [m²] entering the chamber during the step of `dt_yr` ending at `st.t`, dropping finished inflows.
"""
function mageres_recharge_volume!(st::MAGEResState, dt_yr::Float64)
    pr = st.pressure
    t0 = st.t - dt_yr
    V  = sum((r * max(0.0, min(st.t, t1) - max(t0, ts)) for (r, ts, t1) in pr.inflow); init = 0.0)
    filter!(f -> f[3] > st.t + 1e-9, pr.inflow)
    return V
end

"""
    mageres_magma_compressibility(st::MAGEResState)

    Compressibility [1/Pa] of the chamber magma, weighted by magma fraction and volume: melt and solid from their
    bulk moduli, fluid as an ideal gas at lithostatic pressure.
"""
function mageres_magma_compressibility(st::MAGEResState)
    th = st.thermo
    rv = mageres_volume_row(st)
    num, den = 0.0, 0.0
    for c in 1:mageres_ncells(st.grid)
        st.grid.frac[c] > 0 || continue
        p  = th.points[c]
        KM = isfinite(p.K_M) && p.K_M > 0 ? p.K_M : MAGERES_K_MELT_GPA
        KS = isfinite(p.K_S) && p.K_S > 0 ? p.K_S : MAGERES_K_SOLID_GPA
        P  = 1e8 * mageres_lithostatic_kbar(st.opts, st.grid.yc[c])
        b  = p.frac_M_vol / (1e9 * KM) + p.frac_S_vol / (1e9 * KS) + p.frac_F_vol / P
        V  = st.grid.frac[c] * st.Q[rv, c]
        num += V * b
        den += V
    end
    return den > 0 ? num / den : 1 / (1e9 * MAGERES_K_MELT_GPA)
end

"""
    mageres_host_viscosity(o::MAGEResOptions, T_C::Real)

    Arrhenius viscosity [Pa s] of the wall rock at `T_C` [°C].
"""
mageres_host_viscosity(o::MAGEResOptions, T_C::Real) =
    o.host_visc_A_Pas * exp(1e3 * o.host_visc_G_kJ / (MAGERES_GAS_CONSTANT * (T_C + MAGERES_T0_K)))

"""
    mageres_shell_viscosity(st::MAGEResState)

    Effective viscosity [Pa s] and mean temperature [°C] of the wall-rock shell around the chamber: the host cells
    (no magma) within `shell_thickness_m` (0: the equivalent chamber radius a = √(V/π)) of the magma, weighted by
    area and (a/(a+d))³, d being the distance to the nearest magma cell (viscous shell around a cylindrical cavity,
    ΔP ∝ ∫ η r⁻³ dr). Returns `(Inf, NaN)` when there is no shell.
"""
function mageres_shell_viscosity(st::MAGEResState)
    g  = st.grid
    o  = st.opts
    T  = mageres_temperature(st)
    a  = sqrt(mageres_chamber_area(st.chamber) / π)
    L  = o.shell_thickness_m > 0 ? o.shell_thickness_m : a
    edge = [c for c in 1:mageres_ncells(g) if g.frac[c] > 0 &&
            any(m -> g.frac[m] <= 0, (m for d in 1:4 for m in mageres_face_neighbors(g, c, d)[2]))]
    (isempty(edge) || a <= 0) && return Inf, NaN
    sw, se, sT = 0.0, 0.0, 0.0
    for c in 1:mageres_ncells(g)
        g.frac[c] <= 0 || continue
        d = minimum(hypot(g.xc[c] - g.xc[e], g.yc[c] - g.yc[e]) for e in edge)
        d <= L + g.h[c] / 2 || continue
        w   = g.area[c] * (a / (a + d))^3
        sw += w
        se += w * mageres_host_viscosity(o, T[c])
        sT += w * T[c]
    end
    return sw > 0 ? (se / sw, sT / sw) : (Inf, NaN)
end

"""
    mageres_overpressure_step!(st::MAGEResState, dt::Float64)

    Advance the chamber overpressure over `dt` [s]: the volume changes of the step (phase changes and fluid
    exsolution in the magma, the recharge inflow and the percolated volume) act as a constant source against the
    elastic compressibility of magma and wall rock, while the viscous wall rock relaxes the overpressure (Degruyter &
    Huber 2014). An overpressure above the critical value in a magma that cannot erupt is capped at that value.
    Returns `st`.
"""
function mageres_overpressure_step!(st::MAGEResState, dt::Float64)
    mageres_overpressure_on(st) || return st
    o  = st.opts
    pr = st.pressure
    pr.dV_phase         = pr.dV_phase_pending
    pr.dV_in            = pr.dV_pending + mageres_recharge_volume!(st, dt / MAGERES_SECONDS_PER_YEAR)
    dV                  = pr.dV_phase + pr.dV_in
    pr.dV_pending       = 0.0
    pr.dV_phase_pending = 0.0
    V  = mageres_chamber_area(st.chamber)
    V > 0 || return st
    mu                 = 1e9 * o.host_shear_modulus_GPa
    pr.beta            = mageres_magma_compressibility(st) + 1 / mu
    pr.eta, pr.T_shell = mageres_shell_viscosity(st)
    pr.tau             = pr.eta * pr.beta
    x          = dt / pr.tau
    rise       = dV / (V * pr.beta)
    pr.dP      = x > 0 ? pr.dP * exp(-x) + rise * (-expm1(-x)) / x : pr.dP + rise
    dP_crit    = 1e6 * o.dP_crit_MPa
    (pr.dP > dP_crit && !mageres_eruptible(st)) && (pr.dP = dP_crit)
    return st
end
