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
    mageres_apply_event!(st::MAGEResState, ΔT::Float64; mode::Symbol, injected_density = mageres_injected_density(st),
                         internal = false)

    Change the chamber opening by `ΔT`, rebuild the grid refined at material interfaces, remap the conserved
    quantities, cumulate and thermodynamic state and update the ledger (`internal` skips the injected budget).
    Returns the remap ledger.
"""
function mageres_apply_event!(st::MAGEResState, ΔT::Float64; mode::Symbol,
                              injected_density::Vector{Float64} = mageres_injected_density(st), internal::Bool = false)
    o     = st.opts
    c     = st.chamber
    nc    = deepcopy(c)
    nc.T += ΔT
    g         = mageres_build_grid(o, nc; targets = mageres_interface_targets(st))
    total_old = vec(sum(st.Q; dims = 2))
    nf        = size(st.Q, 1)
    ca        = st.cum_frac .* st.grid.area
    Qx        = vcat(st.Q, ca', (ca .* replace(st.cum_time, NaN => 0.0))', (st.restite_frac .* st.grid.area)')
    Qn, ledx  = mageres_remap(st.grid, Qx, c, ΔT, g;
                              mode             = mode,
                              injected_density = vcat(injected_density, 0.0, 0.0, 0.0),
                              inflow_density   = y -> vcat(mageres_host_density_at(st, y), 0.0, 0.0, 0.0))
    led  = MAGEResRemapLedger(ledx.pulled[1:nf], ledx.inflow[1:nf], ledx.injected[1:nf], ledx.extracted[1:nf],
                              ledx.A_inflow, ledx.source, ledx.injected_area)
    Aold = max.(g.area .- led.injected_area, 0.0)
    st.cum_frac = [Aold[n] > 0 ? clamp(Qn[nf+1, n] / Aold[n], 0.0, 1.0) : 0.0 for n in 1:mageres_ncells(g)]
    st.cum_time = [Qn[nf+1, n] > 0 ? Qn[nf+2, n] / Qn[nf+1, n] : NaN for n in 1:mageres_ncells(g)]
    st.restite_frac = [Aold[n] > 0 ? clamp(Qn[nf+3, n] / Aold[n], 0.0, 1.0) : 0.0 for n in 1:mageres_ncells(g)]
    Qn = Qn[1:nf, :]
    L  = st.ledger
    L.outflow .+= total_old .- led.pulled
    L.inflow  .+= led.inflow
    internal || (L.injected .+= led.injected)
    L.extracted .+= led.extracted
    st.outflow_area += ΔT * c.I / MAGERES_SYMMETRY
    st.chamber = nc
    st.grid    = g
    st.Q       = Qn
    st.conn    = nothing
    mageres_update_cumulate_tag!(st)
    st.donor    = BitVector([s > 0 && st.donor[s] for s in led.source])
    st.melt_out = [s > 0 ? st.melt_out[s] : 0.0 for s in led.source]
    st.body     = falses(mageres_ncells(g))
    if st.thermo !== nothing
        mageres_remap_thermo!(st, led.source)
        mageres_volume_rebaseline!(st)
        st.body = mageres_mobile_body(st)
    end
    mageres_conductivity!(st)
    return led
end

"""
    mageres_interface_cells(st::MAGEResState)

    Cells with a face neighbour of a different material class; empty without thermodynamics.
"""
function mageres_interface_cells(st::MAGEResState)
    st.thermo === nothing && return Int[]
    g   = st.grid
    cls = mageres_material_class(st; split_cumulate = false)
    return [c for c in 1:mageres_ncells(g)
            if any(m -> cls[m] != cls[c], (m for d in 1:4 for m in mageres_face_neighbors(g, c, d)[2]))]
end

"""
    mageres_interface_targets(st::MAGEResState)

    Bounds of the interface cells, used as grid refinement targets.
"""
mageres_interface_targets(st::MAGEResState) =
    NTuple{4,Float64}[mageres_cell_bounds(st.grid, st.grid.leaves[c]) for c in mageres_interface_cells(st)]

"""
    mageres_remesh_if_needed!(st::MAGEResState)

    Rebuild the grid when an interface cell is coarser than the finest level; returns true when remeshed.
"""
function mageres_remesh_if_needed!(st::MAGEResState)
    g    = st.grid
    hmin = g.h0 / 2^g.Lmax
    any(c -> g.h[c] > hmin * (1 + 1e-9), mageres_interface_cells(st)) || return false
    mageres_apply_event!(st, 0.0; mode = :inject, injected_density = zeros(size(st.Q, 1)), internal = true)
    mageres_update_convection!(st)
    return true
end

"""
    mageres_route_injection_to_body!(st::MAGEResState, led::MAGEResRemapLedger)

    Swap part of the newly injected magma in the lens (up to `MAGERES_ROUTE_MAX_SWAP` of the body area) with the
    mobile body content and flag the affected cells for re-minimization.
"""
function mageres_route_injection_to_body!(st::MAGEResState, led::MAGEResRemapLedger)
    th   = st.thermo
    g    = st.grid
    host = mageres_mobile_body(st; exclude = led.source .== 0)
    b    = findall(host)
    isempty(b) && return st
    lens = [c for c in 1:mageres_ncells(g) if !host[c] && led.injected_area[c] > 0]
    isempty(lens) && return st
    A      = g.area[b]
    AB     = sum(A)
    Vr     = sum(led.injected_area[lens])
    r      = min(1.0, MAGERES_ROUTE_MAX_SWAP * AB / Vr)
    phi    = r * Vr / AB
    dens   = mageres_injected_density(st)
    pooled = zeros(size(st.Q, 1))
    for c in lens
        x = dens .* (r * led.injected_area[c])
        x[MAGERES_IN0:end] .= min.(x[MAGERES_IN0:end], st.Q[MAGERES_IN0:end, c])
        @views st.Q[:, c] .-= x
        pooled .+= x
    end
    back = vec(sum(st.Q[:, b]; dims = 2)) .* phi
    for (k, c) in enumerate(b)
        @views st.Q[:, c] .= st.Q[:, c] .* (1 - phi) .+ pooled .* (A[k] / AB)
        th.needs_remin[c] = true
    end
    for c in lens
        @views st.Q[:, c] .+= back .* (r * led.injected_area[c] / (phi * AB))
        th.needs_remin[c] = true
    end
    return st
end

"""
    mageres_inject!(st::MAGEResState)

    Inject one magma batch: open the chamber, route it to the body if selected, re-equilibrate, update
    convection, and record the source layer and event. Returns the injected volume.
"""
function mageres_inject!(st::MAGEResState)
    o   = st.opts
    V   = mageres_injection_volume(o)
    led = mageres_apply_event!(st, V / st.chamber.I; mode = :inject)
    if st.thermo !== nothing
        th = st.thermo
        o.injection_target == "body" && mageres_route_injection_to_body!(st, led)
        fed = [c for c in 1:mageres_ncells(st.grid) if st.grid.frac[c] > 0 && (th.needs_remin[c] || led.source[c] == 0)]
        mageres_enthalpy_equilibrate!(st, fed)
        st.body = mageres_mobile_body(st)
        mageres_update_convection!(st)
        mageres_mix_body_enthalpy!(st)
        st.body = mageres_mobile_body(st)
        mageres_unlock_cumulate!(st)
        mageres_conductivity!(st)
        mageres_overpressure_on(st) && mageres_add_recharge!(st, V)
    end
    st.chamber.n_injections += 1
    st.erupt_armed           = true
    push!(st.source.layers, MAGEResLayer(st.t, V, o.T_injection_C, MAGERES_SYMMETRY .* led.injected[mageres_ox_rows(st)],
                                         MAGERES_SYMMETRY .* led.injected[mageres_tracer_rows(st)]))
    mageres_record!(st, :injection, V)
    return V
end

"""
    mageres_extract!(st::MAGEResState, V::Float64; mode = :remove)

    Extract up to `V` (at most 99.9 % of the chamber area) from the chamber, recording a pluton layer and the
    event. Returns the extracted volume.
"""
function mageres_extract!(st::MAGEResState, V::Float64; mode::Symbol = :remove)
    c  = st.chamber
    Vx = min(V, 0.999 * mageres_chamber_area(c))
    Vx > 0 || (mageres_record!(st, :extraction_skipped, 0.0, "chamber not open"); return 0.0)
    led = mageres_apply_event!(st, -Vx / c.I; mode = mode)
    st.chamber.n_extractions += 1
    Tx = led.extracted[MAGERES_IC] > 0 ? led.extracted[MAGERES_IE] / led.extracted[MAGERES_IC] - MAGERES_T0_K : NaN
    push!(st.pluton.layers, MAGEResLayer(st.t, Vx, Tx, MAGERES_SYMMETRY .* led.extracted[mageres_ox_rows(st)],
                                         MAGERES_SYMMETRY .* led.extracted[mageres_tracer_rows(st)]))
    mageres_record!(st, :extraction, Vx)
    return Vx
end

"""
    mageres_advance!(st::MAGEResState, t_target::Real)

    Advance the model to `t_target` [yr] in thermal timesteps: conduction, then with thermodynamics settling,
    slumping, eruption, percolation, re-minimization, zircon growth/dissolution, overpressure, convection and
    remeshing.
"""
function mageres_advance!(st::MAGEResState, t_target::Real)
    o = st.opts
    while st.t < t_target - 1e-9
        dt_yr = min(o.thermal_dt_yr, t_target - st.t)
        dt    = dt_yr * MAGERES_SECONDS_PER_YEAR
        st.conn === nothing && (st.conn = mageres_thermal_connectivity(st.grid))
        C      = st.Q[MAGERES_IC, :]
        T      = mageres_temperature(st)
        Tn, Eb = mageres_conduction_step(st.grid, st.conn, st.k, C, T, dt, st.t * MAGERES_SECONDS_PER_YEAR, o)
        st.Q[MAGERES_IH, :] .+= C .* (Tn .- T)
        st.Q[MAGERES_IE, :]  .= C .* (Tn .+ MAGERES_T0_K)
        st.ledger.boundary_energy += Eb
        st.t                      += dt_yr
        if st.thermo !== nothing
            st.body = mageres_mobile_body(st)
            fill!(st.melt_out, 0.0)
            st.settled_area += mageres_settle!(st, dt)
            mageres_slump_pile!(st)
            st.body = mageres_mobile_body(st)
            mageres_erupt!(st)
            V_perc = mageres_percolate!(st, dt)
            mageres_overpressure_on(st) && (st.pressure.dV_pending += V_perc)
            mageres_update_thermo!(st; t_yr = st.t)
            mageres_zircon_step!(st, dt)
            mageres_overpressure_step!(st, dt)
            st.body = mageres_mobile_body(st)
            mageres_unlock_cumulate!(st)
            mageres_update_convection!(st)
            mageres_remesh_if_needed!(st)
        end
        st.n_thermal_steps += 1
    end
    st.t = max(st.t, Float64(t_target))
    return st
end

"""
    mageres_next_event_time(st::MAGEResState)

    Time [yr] of the next injection.
"""
mageres_next_event_time(st::MAGEResState) = st.next_injection

"""
    mageres_step!(st::MAGEResState)

    Advance to the next injection, inject and schedule the following one; false when there is no next injection.
"""
function mageres_step!(st::MAGEResState)
    tn = mageres_next_event_time(st)
    isfinite(tn) || return false
    mageres_advance!(st, tn)
    mageres_inject!(st)
    st.next_injection += st.opts.injection_period_yr
    return true
end

"""
    mageres_run!(st::MAGEResState, t_end::Real; progress = nothing)

    Run all injections up to `t_end` [yr], calling `progress(st)` after each, then advance to `t_end`.
"""
function mageres_run!(st::MAGEResState, t_end::Real; progress = nothing)
    while mageres_next_event_time(st) <= t_end
        mageres_step!(st) || break
        progress === nothing || progress(st)
    end
    mageres_advance!(st, t_end)
    return st
end
