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
    mageres_save_state(path::AbstractString, st::MAGEResState)

    Save the run state `st` to the JLD2 file `path` under the key "state", leaving out the MAGEMin
    handle `st.thermo.mm` during the write. Returns `path`.
"""
function mageres_save_state(path::AbstractString, st::MAGEResState)
    th = st.thermo
    mm = th === nothing ? nothing : th.mm
    th === nothing || (th.mm = nothing)
    try
        jldsave(path; state = st)
    finally
        th === nothing || (th.mm = mm)
    end
    return path
end

"""
    mageres_load_state(path::AbstractString)

    Load the `MAGEResState` saved by `mageres_save_state` from the JLD2 file `path`.
"""
mageres_load_state(path::AbstractString) = JLD2.load(path, "state")::MAGEResState

const MAGERES_RUN_FORMAT = 2

"""
    mageres_runs_dir()

    Folder of the saved MAGEMin Reservoir simulations (inside the app's saved-state folder).
"""
mageres_runs_dir() = joinpath(state_dir(), "mageres_runs")

"""
    mageres_run_file(name)

    JLD2 file of the saved simulation `name`; `nothing` for an empty or unsafe name.
"""
function mageres_run_file(name)
    name isa AbstractString || return nothing
    n = strip(name)
    (isempty(n) || n in (".", "..") || occursin(r"[/\\\\:\\x00]", n)) && return nothing
    return joinpath(mageres_runs_dir(), String(n) * ".jld2")
end

"""
    mageres_list_runs()

    Names of the saved simulations, sorted.
"""
function mageres_list_runs()
    dir = mageres_runs_dir()
    isdir(dir) || return String[]
    return sort([f[1:end-5] for f in readdir(dir) if endswith(f, ".jld2")])
end

"""
    mageres_with_fields(x, changes::Pair...)

    Copy of the struct `x` with the fields named in `changes` replaced.
"""
function mageres_with_fields(x, changes::Pair...)
    d = Dict(changes)
    return typeof(x)((haskey(d, f) ? d[f] : getfield(x, f) for f in fieldnames(typeof(x)))...)
end

"""
    mageres_portable_point(p::MAGEResThermoPoint)

    Thermodynamic point `p` without its MAGEMin initial-guess data.
"""
mageres_portable_point(p::MAGEResThermoPoint) = isempty(p.mSS) ? p : mageres_with_fields(p, :mSS => MAGEResmSS())

"""
    mageres_portable_state(st::MAGEResState)

    Copy of the stored output state `st` that can be written to file: thermodynamic points without MAGEMin
    initial-guess data and the trace-element setup without its compiled KD functions.
"""
function mageres_portable_state(st::MAGEResState)
    th = st.thermo
    th === nothing && return st
    te = th.te === nothing ? nothing : mageres_with_fields(th.te, :kds => nothing)
    pr = th.profile
    pt = mageres_with_fields(th, :points    => [mageres_portable_point(p) for p in th.points],
                                 :profile   => MAGEResHostProfile(pr.y, pr.density, [mageres_portable_point(p) for p in pr.points]),
                                 :injection => mageres_portable_point(th.injection),
                                 :te        => te)
    return mageres_with_fields(st, :thermo => pt)
end

"""
    mageres_save_simulation(path::AbstractString, snap)

    Write the live-run snapshot `snap` (stored outputs, series, oxides, times, counters and the full state to resume
    from) and the run options to the JLD2 file `path`. Returns `path`.
"""
function mageres_save_simulation(path::AbstractString, snap)
    isempty(snap.outputs) && throw(ArgumentError("the run has no stored output yet"))
    jldsave(path; format          = MAGERES_RUN_FORMAT,
                  options         = mageres_options_to_dict(snap.outputs[end].state.opts),
                  outputs         = [MAGEResOutput(o.t, o.label, mageres_portable_state(o.state)) for o in snap.outputs],
                  series          = snap.series,
                  oxides          = snap.oxides,
                  t               = snap.t,
                  t_end           = snap.t_end,
                  wall_time       = snap.wall_time,
                  n_thermal_steps = snap.n_thermal_steps,
                  n_events        = snap.n_events,
                  resume          = snap.resume === nothing ? nothing : mageres_portable_state(snap.resume),
                  resume_ns       = snap.resume_ns)
    return path
end

"""
    mageres_load_simulation(path::AbstractString)

    Read a simulation saved by `mageres_save_simulation` (any format up to `MAGERES_RUN_FORMAT`). Returns a finished
    `MAGEResLiveRun` holding its outputs, series and resume state (none before format 2), and the run options.
"""
function mageres_load_simulation(path::AbstractString)
    d    = JLD2.load(path)
    get(d, "format", 0) in 1:MAGERES_RUN_FORMAT || throw(ArgumentError("unsupported simulation file format"))
    live = MAGEResLiveRun()
    live.phase           = "done"
    live.outputs         = d["outputs"]
    live.series          = d["series"]
    live.oxides          = d["oxides"]
    live.t               = d["t"]
    live.t_end           = d["t_end"]
    live.wall_time       = d["wall_time"]
    live.n_thermal_steps = d["n_thermal_steps"]
    live.n_events        = d["n_events"]
    live.resume          = get(d, "resume", nothing)
    live.resume_ns       = get(d, "resume_ns", 0)
    return live, mageres_options_from_dict(Dict{String,Any}(string(k) => v for (k, v) in d["options"]))
end
