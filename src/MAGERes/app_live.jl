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
    MAGEResSeries

    Time series of reservoir diagnostics, one entry per recorded output or event (temperatures, areas,
    cumulative energies, conservation errors, chamber composition, convection numbers). `MAGEResSeries()` is empty.
"""
mutable struct MAGEResSeries
    t               :: Vector{Float64}
    T_mean          :: Vector{Float64}
    T_max           :: Vector{Float64}
    thickness       :: Vector{Float64}
    area            :: Vector{Float64}
    ncells          :: Vector{Int}
    V_injected      :: Vector{Float64}
    V_erupted       :: Vector{Float64}
    E_boundary      :: Vector{Float64}
    E_injected      :: Vector{Float64}
    E_extracted     :: Vector{Float64}
    E_net_outflow   :: Vector{Float64}
    energy_error    :: Vector{Float64}
    mass_error      :: Vector{Float64}
    host_error      :: Vector{Float64}
    budget_error    :: Vector{Float64}
    chamber_comp    :: Vector{Vector{Float64}}
    melt_mean       :: Vector{Float64}
    E_remin         :: Vector{Float64}
    E_fluid         :: Vector{Float64}
    n_minimizations :: Vector{Int}
    Nu              :: Vector{Float64}
    Ra              :: Vector{Float64}
    body_area       :: Vector{Float64}
    percolated_area :: Vector{Float64}
    enthalpy_error  :: Vector{Float64}
    cumulate_area   :: Vector{Float64}
    settled_area    :: Vector{Float64}
    te_error        :: Vector{Float64}
    overpressure    :: Vector{Float64}
    tau_relax       :: Vector{Float64}
end

MAGEResSeries() = MAGEResSeries(Float64[], Float64[], Float64[], Float64[], Float64[], Int[], Float64[], Float64[],
                                Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[],
                                Vector{Float64}[], Float64[], Float64[], Float64[], Int[], Float64[], Float64[],
                                Float64[], Float64[], Float64[], Float64[], Float64[], Float64[], Float64[],
                                Float64[])

"""
    MAGEResOutput

    One stored output of a run: time [yr], label and state snapshot.
"""
struct MAGEResOutput
    t     :: Float64
    label :: String
    state :: MAGEResState
end

"""
    MAGEResLiveRun

    Lock-protected progress of a running simulation: phase, time, counters, error message, cancel flag,
    stored outputs, series, oxide names, the full state to resume from and the series length when it was taken, the
    event count before the last resume and a note on the last resume.
    `MAGEResLiveRun()` starts in phase `"launching"`.
"""
mutable struct MAGEResLiveRun
    lock             :: ReentrantLock
    phase            :: String
    t                :: Float64
    t_end            :: Float64
    wall_time        :: Float64
    n_thermal_steps  :: Int
    n_events         :: Int
    error_message    :: Union{Nothing,String}
    cancel_requested :: Bool
    outputs          :: Vector{MAGEResOutput}
    series           :: MAGEResSeries
    oxides           :: Vector{String}
    resume           :: Union{Nothing,MAGEResState}
    resume_ns        :: Int
    n_events0        :: Int
    note             :: String
end

MAGEResLiveRun() = MAGEResLiveRun(ReentrantLock(), "launching", 0.0, 0.0, 0.0, 0, 0, nothing, false, MAGEResOutput[],
                                  MAGEResSeries(), String[], nothing, 0, 0, "")

"""
    mageres_snapshot_state(st::MAGEResState; full = false)

    Copy of `st` for storage as an output: mutable arrays, chamber, ledger and thermodynamic data are copied,
    options and grid shared, the event history left empty. Unless `full`, the per-cell zircon rows are not stored
    (the zircon figures use the eruption layers).
"""
function mageres_snapshot_state(st::MAGEResState; full::Bool = false)
    te = mageres_te(st)
    nq = (full || te === nothing || !te.zircon) ? size(st.Q, 1) : last(mageres_te_rows(st))
    return MAGEResState(st.t, st.opts, st.z_top, st.magma, st.host, st.injection, deepcopy(st.chamber), st.grid,
                        st.Q[1:nq, :], copy(st.k), MAGEResColumn(copy(st.source.layers)),
                        MAGEResColumn(copy(st.pluton.layers)), st.host_area0, st.outflow_area,
                        mageres_copy_ledger(st.ledger), st.next_injection, st.n_thermal_steps, MAGEResEventRecord[],
                        nothing, mageres_snapshot_thermo(st.thermo), copy(st.body), st.Nu, st.Ra, st.percolated_area,
                        copy(st.cumulate_t), copy(st.cum_frac), copy(st.cum_time),
                        copy(st.restite_frac), st.settled_area, copy(st.donor),
                        st.erupt_armed, copy(st.melt_out), deepcopy(st.pressure))
end

"""
    mageres_chamber_composition(st::MAGEResState)

    Oxide mole fractions of the chamber (cell moles weighted by magma fraction); empty when there is no magma.
"""
function mageres_chamber_composition(st::MAGEResState)
    w = st.grid.frac .* 1.0
    sum(w) > 0 || return Float64[]
    n = mageres_cell_moles(st) * w
    s = sum(n)
    return s > 0 ? n ./ s : Float64[]
end

"""
    mageres_record_series!(S::MAGEResSeries, st::MAGEResState)

    Append the current time, budget, ledger, chamber and convection diagnostics of `st` to `S`. Returns `S`.
"""
function mageres_record_series!(S::MAGEResSeries, st::MAGEResState)
    b = mageres_budget(st)
    L = st.ledger
    push!(S.t, st.t)
    push!(S.T_mean, b.T_mean_chamber)
    push!(S.T_max, b.T_max)
    push!(S.thickness, b.thickness)
    push!(S.area, b.A_chamber)
    push!(S.ncells, mageres_ncells(st.grid))
    push!(S.V_injected, b.A_source)
    push!(S.V_erupted, b.A_pluton)
    push!(S.E_boundary, L.boundary_energy)
    push!(S.E_injected, L.injected[MAGERES_IE])
    push!(S.E_extracted, L.extracted[MAGERES_IE])
    push!(S.E_net_outflow, L.outflow[MAGERES_IE] - L.inflow[MAGERES_IE])
    push!(S.energy_error, b.energy_error)
    push!(S.mass_error, b.mass_error)
    push!(S.host_error, b.host_error)
    push!(S.budget_error, b.budget_error)
    push!(S.chamber_comp, mageres_chamber_composition(st))
    push!(S.melt_mean, mageres_chamber_melt(st))
    push!(S.E_remin, L.remin_energy)
    push!(S.E_fluid, L.fluid[MAGERES_IE])
    push!(S.n_minimizations, st.thermo === nothing ? 0 : st.thermo.n_minimizations)
    push!(S.Nu, st.Nu)
    push!(S.Ra, st.Ra)
    push!(S.body_area, MAGERES_SYMMETRY * sum(st.grid.area[st.body]; init = 0.0))
    push!(S.percolated_area, st.percolated_area)
    push!(S.enthalpy_error, b.enthalpy_error)
    push!(S.cumulate_area, MAGERES_SYMMETRY * sum(st.grid.area[mageres_cumulate(st)]; init = 0.0))
    push!(S.settled_area, MAGERES_SYMMETRY * st.settled_area)
    push!(S.te_error, b.te_error)
    push!(S.overpressure, st.pressure.dP / 1e6)
    push!(S.tau_relax, st.pressure.tau / MAGERES_SECONDS_PER_YEAR)
    return S
end

"""
    mageres_publish!(live::MAGEResLiveRun, st::MAGEResState, label::AbstractString, t0::Float64)

    Store a snapshot of `st` as an output labelled `label` and as the state to resume from, reset the per-cell
    calculation counts, record the series and update the progress fields of `live` (`t0` = wall-clock start time).
    Returns `live`.
"""
function mageres_publish!(live::MAGEResLiveRun, st::MAGEResState, label::AbstractString, t0::Float64)
    full = mageres_snapshot_state(st; full = true)
    te   = mageres_te(st)
    snap = (te === nothing || !te.zircon) ? full : mageres_with_fields(full, :Q => full.Q[1:last(mageres_te_rows(st)), :])
    mageres_reset_calc_counts!(st)
    lock(live.lock) do
        push!(live.outputs, MAGEResOutput(st.t, String(label), snap))
        mageres_record_series!(live.series, st)
        live.resume          = full
        live.resume_ns       = length(live.series.t)
        live.t               = st.t
        live.wall_time       = time() - t0
        live.n_thermal_steps = st.n_thermal_steps
        live.n_events        = live.n_events0 + length(st.history)
    end
    return live
end

"""
    mageres_record_event!(live::MAGEResLiveRun, st::MAGEResState, t0::Float64)

    Record the series and update the progress fields of `live` after an event, without storing an output.
    Returns `live`.
"""
function mageres_record_event!(live::MAGEResLiveRun, st::MAGEResState, t0::Float64)
    lock(live.lock) do
        mageres_record_series!(live.series, st)
        live.t               = st.t
        live.wall_time       = time() - t0
        live.n_thermal_steps = st.n_thermal_steps
        live.n_events        = live.n_events0 + length(st.history)
    end
    return live
end

"""
    mageres_cancelled(live::MAGEResLiveRun)

    True when cancellation of the run was requested.
"""
mageres_cancelled(live::MAGEResLiveRun) = lock(() -> live.cancel_requested, live.lock)

"""
    mageres_is_active(live::MAGEResLiveRun)

    True while the run is not in phase `"done"`, `"cancelled"` or `"error"`.
"""
mageres_is_active(live::MAGEResLiveRun) = lock(() -> !(live.phase in ("done", "cancelled", "error")), live.lock)

"""
    mageres_set_phase!(live::MAGEResLiveRun, phase::AbstractString; error_message = nothing)

    Set the run phase and, when given, the error message. Returns `live`.
"""
function mageres_set_phase!(live::MAGEResLiveRun, phase::AbstractString; error_message = nothing)
    lock(live.lock) do
        live.phase = String(phase)
        error_message === nothing || (live.error_message = String(error_message))
    end
    return live
end

"""
    mageres_run_live!(live::MAGEResLiveRun, opts::MAGEResOptions; progress = nothing, progressbar = true,
                      callback_fn = nothing, stage_fn = nothing)

    Initialise and run a simulation for `opts` up to `opts.run_time_yr`, publishing an output every
    `opts.output_every_yr` and recording every event into `live`; ends in phase done, cancelled or error.
    Returns `live`.
"""
function mageres_run_live!(live::MAGEResLiveRun, opts::MAGEResOptions; progress = nothing, progressbar::Bool = true,
                           callback_fn = nothing, stage_fn = nothing)
    t0 = time()
    st = nothing
    try
        opts.thermodynamics == "magemin" && mageres_set_phase!(live, "initialising MAGEMin")
        st = mageres_init_state(opts; progressbar = progressbar, callback_fn = callback_fn, stage_fn = stage_fn)
        lock(live.lock) do
            live.t_end  = opts.run_time_yr
            live.oxides = copy(opts.oxides)
        end
        mageres_set_phase!(live, "running")
        mageres_publish!(live, st, "initial state", t0)
        mageres_continue_live!(live, st, t0; progress = progress)
    catch e
        mageres_set_phase!(live, "error"; error_message = sprint(showerror, e))
    finally
        st === nothing || mageres_release_thermo!(st)
    end
    lock(() -> (live.wall_time = time() - t0), live.lock)
    return live
end

"""
    mageres_resume_live!(live::MAGEResLiveRun, t_end::Real; progress = nothing, progressbar = true,
                         callback_fn = nothing, stage_fn = nothing)

    Continue the finished, cancelled or loaded run `live` from its resume state up to `t_end` [yr], with the options
    of the run; ends in phase done, cancelled or error. Returns `live`.
"""
function mageres_resume_live!(live::MAGEResLiveRun, t_end::Real; progress = nothing, progressbar::Bool = true,
                              callback_fn = nothing, stage_fn = nothing)
    t0 = time() - lock(() -> live.wall_time, live.lock)
    st = nothing
    try
        mageres_set_phase!(live, "resuming")
        st = mageres_resume_state(live, t_end; progressbar = progressbar, callback_fn = callback_fn,
                                  stage_fn = stage_fn)
        mageres_set_phase!(live, "running")
        mageres_continue_live!(live, st, t0; progress = progress)
    catch e
        mageres_set_phase!(live, "error"; error_message = sprint(showerror, e))
    finally
        st === nothing || mageres_release_thermo!(st)
    end
    lock(() -> (live.wall_time = time() - t0), live.lock)
    return live
end

"""
    mageres_continue_live!(live::MAGEResLiveRun, st::MAGEResState, t0::Float64; progress = nothing)

    Advance `st` up to `st.opts.run_time_yr`, publishing an output at every multiple of `output_every_yr` and at the
    end, and recording every event into `live`; stores the final state to resume from and ends in phase done or
    cancelled. Returns `live`.
"""
function mageres_continue_live!(live::MAGEResLiveRun, st::MAGEResState, t0::Float64; progress = nothing)
    o        = st.opts
    t_end    = o.run_time_yr
    nsteps   = max(1, ceil(Int, t_end / o.thermal_dt_yr))
    next_out = o.output_every_yr * (floor(st.t / o.output_every_yr + 1e-9) + 1)
    while st.t < t_end - 1e-9 || mageres_next_event_time(st) <= t_end
        mageres_cancelled(live) && break
        te    = mageres_next_event_time(st)
        t_out = min(next_out, t_end)
        if t_out > st.t + 1e-9 && t_out <= te
            mageres_advance!(st, t_out)
            mageres_publish!(live, st, "conduction", t0)
            next_out += o.output_every_yr
        elseif te <= t_end
            mageres_step!(st)
            mageres_record_event!(live, st, t0)
        else
            next_out += o.output_every_yr
        end
        progress === nothing || progress(min(st.n_thermal_steps, nsteps), nsteps)
        any(!isfinite, st.Q) && throw(ErrorException("non-finite state at t = $(st.t) yr"))
    end
    final = mageres_snapshot_state(st; full = true)
    lock(live.lock) do
        live.resume    = final
        live.resume_ns = length(live.series.t)
    end
    mageres_set_phase!(live, mageres_cancelled(live) ? "cancelled" : "done")
    return live
end

"""
    mageres_series_upto(S::MAGEResSeries, t::Real)

    Copy of the series `S` keeping the records up to time `t` [yr].
"""
mageres_series_upto(S::MAGEResSeries, t::Real) = mageres_series_head(S, count(<=(t + 1e-9), S.t))

"""
    mageres_series_head(S::MAGEResSeries, k::Int)

    Copy of the series `S` keeping its first `k` records.
"""
mageres_series_head(S::MAGEResSeries, k::Int) =
    MAGEResSeries((getfield(S, f)[1:min(k, length(S.t))] for f in fieldnames(MAGEResSeries))...)

"""
    mageres_live_snapshot(live::MAGEResLiveRun)

    Named tuple copy of the progress fields, outputs, series and oxides of `live`, with its resume state, taken under
    its lock.
"""
function mageres_live_snapshot(live::MAGEResLiveRun)
    return lock(live.lock) do
        (phase           = live.phase,
         t               = live.t,
         t_end           = live.t_end,
         wall_time       = live.wall_time,
         n_thermal_steps = live.n_thermal_steps,
         n_events        = live.n_events,
         error_message   = live.error_message,
         outputs         = copy(live.outputs),
         series          = deepcopy(live.series),
         oxides          = copy(live.oxides),
         resume          = live.resume,
         resume_ns       = live.resume_ns,
         note            = live.note)
    end
end

"""
    mageres_resume_source(live::MAGEResLiveRun)

    State to resume `live` from: its resume state, else its last stored output; `nothing` when it has neither.
"""
mageres_resume_source(live::MAGEResLiveRun) =
    lock(() -> live.resume !== nothing ? live.resume : (isempty(live.outputs) ? nothing : live.outputs[end].state),
         live.lock)

"""
    mageres_resume_resets_zircon(st::MAGEResState)

    True when the resume source `st` lacks its per-cell zircon rows, which a resume then starts empty.
"""
mageres_resume_resets_zircon(st::MAGEResState) = size(st.Q, 1) < length(st.ledger.initial)

"""
    mageres_restore_rows!(st::MAGEResState)

    Append to `st.Q` the rows a stored output left out (zircon, then material volume), with no zircon and the
    material volume from the cell density, and shift the ledger initial content of these rows, and of the Zr row
    with zircon, so that their budget holds. Returns `st`.
"""
function mageres_restore_rows!(st::MAGEResState)
    nq = size(st.Q, 1)
    nf = length(st.ledger.initial)
    nq < nf || return st
    st.Q = vcat(st.Q, zeros(nf - nq, size(st.Q, 2)))
    if mageres_overpressure_on(st)
        rv = mageres_volume_row(st)
        for c in 1:mageres_ncells(st.grid)
            p = st.thermo.points[c]
            p.rho > 0 && (st.Q[rv, c] = mageres_cell_mass(st, c) / p.rho)
        end
    end
    te    = mageres_te(st)
    rows  = collect(nq+1:nf)
    (te !== nothing && te.zircon) && push!(rows, first(mageres_te_rows(st)) - 1 + te.i_zr)
    expct = mageres_expected_content(st.ledger)
    for r in rows
        st.ledger.initial[r] += sum(@view st.Q[r, :]) - expct[r]
    end
    return st
end

"""
    mageres_extend_zircon_bins!(st::MAGEResState)

    Add zircon age bins (empty) to every family so that they cover `st.opts.run_time_yr`, in the cells, ledger, host
    profile, injected magma and source and erupted layers. Returns `st`.
"""
function mageres_extend_zircon_bins!(st::MAGEResState)
    te = mageres_te(st)
    (te === nothing || !te.zircon) && return st
    nb = max(1, ceil(Int, st.opts.run_time_yr / te.bin_yr - 1e-9))
    b0 = te.n_bins
    nb > b0 || return st
    ne = length(te.elements)
    n0 = MAGERES_IN0 + length(st.opts.oxides) - 1
    l0 = ne + te.n_fam * (2 + b0)
    l1 = ne + te.n_fam * (2 + nb)
    at(k) = k <= ne ? k : (j = k - ne - 1; ne + (j ÷ (2 + b0)) * (2 + nb) + j % (2 + b0) + 1)
    function tracers(v::AbstractVector{Float64})
        length(v) == l0 || return v
        w = zeros(l1)
        for k in 1:l0
            w[at(k)] = v[k]
        end
        return w
    end
    full(v::AbstractVector{Float64}) = vcat(v[1:n0], tracers(v[n0+1:n0+l0]), v[n0+l0+1:end])
    function full(A::AbstractMatrix{Float64})
        B = zeros(size(A, 1) + l1 - l0, size(A, 2))
        for j in axes(A, 2)
            B[:, j] = full(A[:, j])
        end
        return B
    end
    layers(C::MAGEResColumn) = MAGEResColumn([MAGEResLayer(l.t, l.area, l.T, l.moles, tracers(l.tracers))
                                              for l in C.layers])
    th = st.thermo
    L  = st.ledger
    st.Q                 = full(st.Q)
    L.initial            = full(L.initial)
    L.injected           = full(L.injected)
    L.extracted          = full(L.extracted)
    L.outflow            = full(L.outflow)
    L.inflow             = full(L.inflow)
    L.fluid              = full(L.fluid)
    th.profile           = MAGEResHostProfile(th.profile.y, full(th.profile.density), th.profile.points)
    th.injection_density = full(th.injection_density)
    st.source            = layers(st.source)
    st.pluton            = layers(st.pluton)
    th.te                = mageres_with_fields(te, :n_bins => nb)
    return st
end

"""
    mageres_resume_state(live::MAGEResLiveRun, t_end::Real; progressbar = true, callback_fn = nothing,
                         stage_fn = nothing)

    Working state that continues `live` up to `t_end` [yr]: a copy of its resume source with the run time set to
    `t_end`, missing zircon rows restored empty, zircon age bins extended, the KD database rebuilt and MAGEMin
    initialised. Cuts the outputs, series and event count of `live` back to when the state was taken (the publish
    record for a stored output) and notes the resume in `live.note`.
"""
function mageres_resume_state(live::MAGEResLiveRun, t_end::Real; progressbar::Bool = true, callback_fn = nothing,
                              stage_fn = nothing)
    src  = mageres_resume_source(live)
    kept = lock(() -> live.resume !== nothing, live.lock)
    src === nothing && throw(ArgumentError("the run has no stored state to resume from"))
    t_end > src.t + 1e-9 ||
        throw(ArgumentError(@sprintf("the run time (%.0f yr) must exceed the model time (%.0f yr)", t_end, src.t)))
    st                  = deepcopy(src)
    st.opts.run_time_yr = Float64(t_end)
    st.history          = MAGEResEventRecord[]
    st.conn             = nothing
    th                  = st.thermo
    reset               = th !== nothing && th.te !== nothing && th.te.zircon && mageres_resume_resets_zircon(st)
    if th !== nothing
        mageres_set_phase!(live, "initialising MAGEMin")
        mageres_restore_rows!(st)
        mageres_extend_zircon_bins!(st)
        (th.te === nothing || th.te.kds !== nothing) ||
            (th.te = mageres_with_fields(th.te, :kds => build_kds_database(st.opts.kds_mod)))
        th.mm          = Initialize_MAGEMin(st.opts.database; verbose = false, solver = 0)
        th.progressbar = progressbar
        th.callback_fn = callback_fn
        th.stage_fn    = stage_fn
    end
    lock(live.lock) do
        ns    = kept ? live.resume_ns : count(<(st.t - 1e-9), live.series.t) + 1
        ns    = min(ns, length(live.series.t))
        n_out = count(o -> o.t > st.t + 1e-9, live.outputs)
        filter!(o -> o.t <= st.t + 1e-9, live.outputs)
        live.n_events        -= length(live.series.t) - ns - n_out
        live.series           = mageres_series_head(live.series, ns)
        live.n_events0        = live.n_events
        live.t                = st.t
        live.t_end            = st.opts.run_time_yr
        live.cancel_requested = false
        live.error_message    = nothing
        live.note             = @sprintf("Resumed at t = %.0f yr", st.t) *
                                (reset ? " (no per-cell zircon in the saved file: chamber zircon restarted empty)" : "")
    end
    return st
end
