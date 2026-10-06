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

const MAGERES_LIVE_RUNS = Dict{String,MAGEResLiveRun}()

const MAGERES_POLL_MS = 2000

const MAGERES_RUN_OUTPUTS = [
    ("run-id-store-mageres",            "data"),
    ("run-poll-interval-mageres",       "disabled"),
    ("run-status-text-mageres",         "children"),
    ("mageres-results-temperature-fig", "figure"),
    ("mageres-results-material-fig",    "figure"),
    ("mageres-results-melt-fig",        "figure"),
    ("mageres-results-calc-fig",        "figure"),
    ("mageres-eruption-fig",            "figure"),
    ("mageres-eruption-te-fig",         "figure"),
    ("mageres-zircon-rank-fig",         "figure"),
    ("mageres-zircon-ages-fig",         "figure"),
    ("mageres-zircon-spots-fig",        "figure"),
    ("mageres-zircon-families-fig",     "figure"),
    ("mageres-vital-signs-fig",         "figure"),
    ("mageres-energy-budget-fig",       "figure"),
    ("mageres-diagnostics-fig",         "figure"),
    ("mageres-melt-in-fig",             "figure"),
    ("mageres-melt-chamber-fig",        "figure"),
    ("mageres-melt-out-fig",            "figure"),
    ("mageres-tas-fig",                 "figure"),
    ("mageres-cumulate-fig",            "figure"),
    ("mageres-convection-fig",          "figure"),
    ("mageres-progress-off",            "data"),
    ("run-poll-interval-mageres",       "interval"),
    ("mageres-timestep-select",         "options"),
]

"""
    mageres_outputs(d::AbstractDict)

    Tuple of values for `MAGERES_RUN_OUTPUTS`, taken from `d` and `no_update()` for every missing output.
"""
mageres_outputs(d::AbstractDict) = Tuple(get(d, k, no_update()) for k in MAGERES_RUN_OUTPUTS)

const MAGERES_MAP_GRAPHS = ["mageres-results-temperature-fig", "mageres-results-material-fig",
                            "mageres-results-melt-fig", "mageres-results-calc-fig"]

const MAGERES_OPTION_LABELS = Dict(f => l for (_, fs) in MAGERES_OPTION_GROUPS for (f, l) in fs)

"""
    mageres_option_states()

    States of all option inputs, followed by the database, the magma, host and injection bulk-rock tables,
    the "Same as magma" switch and the magma, host and injection trace-element tables.
"""
mageres_option_states() = vcat([State(mageres_input_id(f), "value") for f in mageres_ui_fields()],
                               [State("database-dropdown-mageres",         "value"),
                                State("table-bulk-rock-mageres-magma",     "data"),
                                State("table-bulk-rock-mageres-host",      "data"),
                                State("table-bulk-rock-mageres-injection", "data"),
                                State("injection-use-magma-mageres",       "value"),
                                State("table-te-mageres-magma",            "data"),
                                State("table-te-mageres-host",             "data"),
                                State("table-te-mageres-injection",        "data")])

"""
    mageres_bulk_table_composition(table_data)

    Oxide names and fractions of the rows of a bulk-rock table.
"""
function mageres_bulk_table_composition(table_data)
    oxides = String[String(row["oxide"]) for row in table_data]
    frac   = Float64[row["fraction"] isa AbstractString ? parse(Float64, row["fraction"]) : Float64(row["fraction"])
                     for row in table_data]
    return oxides, frac
end

"""
    mageres_align_tables(tables)

    Union of the oxides of all bulk-rock `tables` and each table's fractions on that oxide list,
    zero for oxides a table does not contain.
"""
function mageres_align_tables(tables)
    parsed = [mageres_bulk_table_composition(t) for t in tables]
    oxides = String[]
    for (ox, _) in parsed, o in ox
        o in oxides || push!(oxides, o)
    end
    bulks  = [[(i = findfirst(==(o), ox); i === nothing ? 0.0 : fr[i]) for o in oxides] for (ox, fr) in parsed]
    return oxides, bulks
end

"""
    mageres_te_table_composition(table_data)

    Element names and concentrations [µg/g] of the rows of a trace-element table.
"""
function mageres_te_table_composition(table_data)
    el = String[String(row["elements"]) for row in table_data]
    C  = Float64[(v = row["μg_g"]; v isa AbstractString ? parse(Float64, v) : Float64(v)) for row in table_data]
    return el, C
end

"""
    mageres_collect_options(vals)

    Build the run options from the values of `mageres_option_states()`. Throws an `ArgumentError` naming the
    first empty option field.
"""
function mageres_collect_options(vals)
    fields = mageres_ui_fields()
    nf     = length(fields)
    d      = Dict{String,Any}()
    for (f, v) in zip(fields, vals[1:nf])
        v === nothing && throw(ArgumentError("please fill in \"$(MAGERES_OPTION_LABELS[f])\""))
        d[string(f)] = v
    end
    database, magma_table, host_table, inj_table, use_magma = vals[nf+1:nf+5]
    te_magma_table, te_host_table, te_inj_table             = vals[nf+6:nf+8]
    same_as_magma = use_magma !== nothing && 1 in use_magma
    oxides, bulks = mageres_align_tables([magma_table, host_table, inj_table])
    d["database"]       = database === nothing ? "ig" : String(database)
    d["oxides"]         = oxides
    d["magma_bulk"]     = bulks[1]
    d["host_bulk"]      = bulks[2]
    d["injection_bulk"] = same_as_magma ? Float64[] : bulks[3]
    if te_magma_table !== nothing && te_host_table !== nothing && te_inj_table !== nothing
        el_m, C_m = mageres_te_table_composition(te_magma_table)
        align(t)  = ((el, C) = mageres_te_table_composition(t);
                     [(k = findfirst(==(e), el); k === nothing ? 0.0 : C[k]) for e in el_m])
        d["te_elements"]      = el_m
        d["te_magma_ppm"]     = C_m
        d["te_host_ppm"]      = align(te_host_table)
        d["te_injection_ppm"] = same_as_magma ? C_m : align(te_inj_table)
    end
    return mageres_options_from_dict(d)
end

"""
    mageres_progress_stage!(label::AbstractString, npoints::Int)

    Reset the global progress bar to stage `label` with `npoints` points.
"""
function mageres_progress_stage!(label::AbstractString, npoints::Int)
    global CompProgress
    CompProgress.title            = "MAGEMin Reservoir progress"
    CompProgress.stage            = label
    CompProgress.refinement_level = 0
    CompProgress.total_levels     = 0
    CompProgress.tinit            = time()
    CompProgress.current_point    = 0
    CompProgress.total_points     = npoints
    return nothing
end

"""
    mageres_progress_batch!(stage::AbstractString, step::Int, nsteps::Int, npoints::Int)

    Set the global progress bar to a batch of `npoints` points of `stage` at timestep `step` of `nsteps`.
"""
function mageres_progress_batch!(stage::AbstractString, step::Int, nsteps::Int, npoints::Int)
    global CompProgress
    CompProgress.title            = "MAGEMin Reservoir progress"
    CompProgress.stage            = step > 0 ? "$(stage), timestep" : stage
    CompProgress.refinement_level = step
    CompProgress.total_levels     = nsteps
    CompProgress.tinit            = time()
    CompProgress.tlast            = time()
    CompProgress.current_point    = 0
    CompProgress.total_points     = npoints
    return nothing
end

"""
    mageres_progress_step!(step::Int, nsteps::Int)

    Advance the global progress bar to timestep `step` of `nsteps`.
"""
function mageres_progress_step!(step::Int, nsteps::Int)
    global CompProgress
    CompProgress.stage            = "timestep"
    CompProgress.refinement_level = step
    CompProgress.total_levels     = nsteps
    update_progress(step, nsteps, time())
    return nothing
end

"""
    mageres_progress_clear!()

    Reset the point counters of the global progress bar.
"""
function mageres_progress_clear!()
    global CompProgress
    CompProgress.total_points  = 0
    CompProgress.current_point = 0
    return nothing
end

"""
    mageres_run_status_text(snap)

    Run status panel of live-run snapshot `snap`: phase, model time, event counts, resume note, chamber state,
    conservation errors, wall time and error message.
"""
function mageres_run_status_text(snap)
    lines = [   "Phase: $(snap.phase)",
                @sprintf("Model time: %.0f / %.0f yr", snap.t, snap.t_end),
                "Events: $(snap.n_events), thermal steps: $(snap.n_thermal_steps)"]
    isempty(snap.note) || push!(lines, snap.note)
    if !isempty(snap.outputs)
        st_last = snap.outputs[end].state
        push!(lines, "Injections: $(length(st_last.source.layers)), eruptions: $(length(st_last.pluton.layers))")
        cum     = mageres_cumulate(st_last)
        any(cum) && push!(lines, @sprintf("Cumulate: %.3f km²", MAGERES_SYMMETRY * sum(st_last.grid.area[cum]) / 1e6))
    end
    S = snap.series
    if !isempty(S.t)
        isnan(S.T_mean[end]) || push!(lines, @sprintf("Chamber mean T: %.0f °C", S.T_mean[end]))
        push!(lines, @sprintf("Chamber max thickness: %.0f m", S.thickness[end]))
        push!(lines, @sprintf("Injected: %.3f km², erupted: %.3f km²", S.V_injected[end] / 1e6,
                              S.V_erupted[end] / 1e6))
        push!(lines, "Cells: $(S.ncells[end])")
        isnan(S.melt_mean[end]) || push!(lines, @sprintf("Chamber mean melt fraction: %.2f", S.melt_mean[end]))
        S.n_minimizations[end] > 0 && push!(lines, "MAGEMin minimizations: $(S.n_minimizations[end])")
        S.body_area[end] > 0 &&
            push!(lines, @sprintf("Mobile body: %.3f km², Nu = %.3g", S.body_area[end] / 1e6, S.Nu[end]))
        S.percolated_area[end] > 0 &&
            push!(lines, @sprintf("Percolated melt: %.4f km²", S.percolated_area[end] / 1e6))
        S.n_minimizations[end] > 0 &&
            push!(lines, @sprintf("Enthalpy conservation error: %.1e", S.enthalpy_error[end]))
        push!(lines, @sprintf("Energy conservation error: %.1e", S.energy_error[end]))
        push!(lines, @sprintf("Oxide mass conservation error: %.1e", S.mass_error[end]))
        (!isempty(snap.outputs) && mageres_te(snap.outputs[end].state) !== nothing) &&
            push!(lines, @sprintf("Trace-element mass conservation error: %.1e", S.te_error[end]))
    end
    push!(lines, @sprintf("Wall time: %.1f s", snap.wall_time))
    snap.error_message === nothing || push!(lines, "Error: $(snap.error_message)")
    return html_div([html_div(l) for l in lines])
end

"""
    mageres_timestep_options(snap)

    Dropdown options of the stored outputs of `snap`, "Latest" first, then newest to oldest.
"""
mageres_timestep_options(snap) =
    vcat([Dict("label" => "Latest", "value" => -1)],
         [Dict("label" => @sprintf("t = %.0f yr — %s", snap.outputs[i].t, snap.outputs[i].label), "value" => i)
          for i in reverse(eachindex(snap.outputs))])

"""
    mageres_selected_index(snap, sel)

    Index of the output of `snap` selected by `sel`, the last output for "Latest" or an invalid selection,
    0 when there is no output.
"""
function mageres_selected_index(snap, sel)
    isempty(snap.outputs) && return 0
    (sel === nothing || sel == -1 || !(1 <= sel <= length(snap.outputs))) && return length(snap.outputs)
    return sel
end

const MAGERES_FRAME_FIGURES = ["mageres-results-temperature-fig", "mageres-results-material-fig",
                               "mageres-results-melt-fig", "mageres-results-calc-fig", "mageres-tas-fig",
                               "mageres-cumulate-fig"]

"""
    mageres_frame_figure(id, snap, i; probe = nothing, pie_unit = 1, show_grid = true, show_outline = true,
                         show_isotherms = true)

    Figure of graph `id` (one of `MAGERES_FRAME_FIGURES`: the four maps, the TAS diagram and the cumulate log) for
    output `i` of `snap` with the given display options.
"""
function mageres_frame_figure(id::AbstractString, snap, i::Int; probe = nothing, pie_unit = 1, show_grid = true,
                              show_outline = true, show_isotherms = true)
    out      = snap.outputs[i]
    st       = out.state
    nsteps   = st.n_thermal_steps - (i > 1 ? snap.outputs[i-1].state.n_thermal_steps : 0)
    probe    = probe === nothing ? mageres_default_probe(st) : probe
    pie_unit = pie_unit === nothing ? 1 : Int(pie_unit)
    pk       = (probe = probe, pie_unit = pie_unit, show_grid = show_grid !== false,
                show_outline = show_outline !== false)
    tag      = @sprintf("t = %.0f yr (%s)", out.t, out.label)
    id == "mageres-results-temperature-fig" &&
        return mageres_field_figure(st, :T; title = "Temperature — $tag", pk...,
                                    show_isotherms = show_isotherms !== false)
    id == "mageres-results-material-fig" &&
        return st.thermo === nothing ?
               mageres_field_figure(st, :frac; title = "Material (magma fraction) — $tag", pk...) :
               mageres_field_figure(st, :material; title = "Material — $tag", pk...)
    id == "mageres-results-melt-fig" &&
        return st.thermo === nothing ? mageres_placeholder_figure("Melt fraction requires MAGEMin thermodynamics") :
                                       mageres_field_figure(st, :melt; title = "Melt fraction — $tag", pk...)
    id == "mageres-results-calc-fig" &&
        return mageres_calc_figure(st, nsteps; title = "Thermodynamic calculations per cell — $tag", pk...)
    S  = snap.series
    ox = snap.oxides
    id == "mageres-tas-fig" &&
        return mageres_tas_figure([("Injected", mageres_layer_times(st.source), mageres_layer_comps(st.source),
                                    "square", "rgb(49,104,164)", false),
                                   ("Chamber", S.t, S.chamber_comp, "circle", nothing, true),
                                   ("Erupted", mageres_layer_times(st.pluton), mageres_layer_comps(st.pluton),
                                    "triangle-up", "rgb(204,102,20)", false)], ox)
    id == "mageres-cumulate-fig" &&
        return st.thermo === nothing ?
               mageres_placeholder_figure("Cumulate assemblage requires MAGEMin thermodynamics"; height = 360) :
               mageres_cumulate_figure(st)
    throw(ArgumentError("no frame figure for $id"))
end

"""
    mageres_save_gif(path::AbstractString, snap, id::AbstractString; frame_ms = 250, kwargs...)

    Animated GIF of graph `id` over every stored output of `snap` (series cut at each output time), rendered with the
    display options `kwargs` at a common size, `frame_ms` milliseconds per frame. Returns the number of frames.
"""
function mageres_save_gif(path::AbstractString, snap, id::AbstractString; frame_ms::Real = 250, kwargs...)
    n = length(snap.outputs)
    n >= 1 || throw(ArgumentError("the run has no stored output yet"))
    figs = [mageres_frame_figure(id, merge(snap, (series = mageres_series_upto(snap.series, snap.outputs[i].t),)), i;
                                 kwargs...) for i in 1:n]
    H    = maximum(Int(get(f.plot.layout.fields, :height, 450)) for f in figs)
    W    = 1000
    dir  = mktempdir()
    try
        frames = Matrix{RGB{N0f8}}[]
        for (i, f) in enumerate(figs)
            png = joinpath(dir, "frame_$(i).png")
            mageres_kaleido_savefig(f, png; width = W, height = H)
            push!(frames, RGB{N0f8}.(load(png)))
        end
        save(path, cat(frames...; dims = 3); fps = 1000 / frame_ms)
    finally
        rm(dir; recursive = true, force = true)
    end
    return n
end

"""
    mageres_results_figures(snap, sel; probe = nothing, pie_unit = 1, show_grid = true, show_outline = true,
                            show_isotherms = true, te_show = "ree", te_norm = "chondrite")

    Dict mapping (id, "figure") of every results graph to its figure for the output of `snap` selected
    by `sel`; empty when there is no output.
"""
function mageres_results_figures(snap, sel; probe = nothing, pie_unit = 1, show_grid = true, show_outline = true,
                                 show_isotherms = true, te_show = "ree", te_norm = "chondrite")
    d        = Dict{Tuple{String,String},Any}()
    i        = mageres_selected_index(snap, sel)
    i == 0 && return d
    out      = snap.outputs[i]
    st       = out.state
    nsteps   = st.n_thermal_steps - (i > 1 ? snap.outputs[i-1].state.n_thermal_steps : 0)
    probe    = probe === nothing ? mageres_default_probe(st) : probe
    pie_unit = pie_unit === nothing ? 1 : Int(pie_unit)
    pk       = (probe = probe, pie_unit = pie_unit, show_grid = show_grid !== false,
                show_outline = show_outline !== false)
    for id in MAGERES_FRAME_FIGURES
        d[(id, "figure")] = mageres_frame_figure(id, snap, i; probe = probe, pie_unit = pie_unit, show_grid = show_grid,
                                                 show_outline = show_outline, show_isotherms = show_isotherms)
    end
    S = snap.series
    d[("mageres-eruption-fig",      "figure")] =
        mageres_volume_figure(S; dP_crit = mageres_overpressure_on(st) ? st.opts.dP_crit_MPa : nothing)
    d[("mageres-vital-signs-fig",   "figure")] = mageres_vital_signs_figure(S)
    d[("mageres-convection-fig",    "figure")] = mageres_convection_figure(S)
    d[("mageres-energy-budget-fig", "figure")] = mageres_energy_figure(S)
    d[("mageres-diagnostics-fig",   "figure")] = mageres_diagnostics_figure(S; te = mageres_te(st) !== nothing)
    t_prev = i > 1 ? snap.outputs[i-1].t : -Inf
    d[("mageres-eruption-te-fig",   "figure")] = mageres_eruption_te_figure(st; t_from = t_prev,
                                                                            show   = something(te_show, "ree"),
                                                                            norm   = something(te_norm, "chondrite"))
    t_ref  = snap.outputs[end].t
    d[("mageres-zircon-rank-fig",     "figure")] = mageres_zircon_rank_figure(st; t_from = t_prev, t_ref = t_ref)
    d[("mageres-zircon-ages-fig",     "figure")] = mageres_zircon_age_figure(st; t_from = t_prev, t_ref = t_ref)
    d[("mageres-zircon-spots-fig",    "figure")] = mageres_zircon_spot_figure(st; t_from = t_prev, t_ref = t_ref)
    d[("mageres-zircon-families-fig", "figure")] = mageres_zircon_family_figure(st; t_from = t_prev, t_ref = t_ref)
    ox = snap.oxides
    d[("mageres-melt-in-fig",      "figure")] = mageres_composition_figure(mageres_layer_times(st.source),
                                                                           mageres_layer_comps(st.source),
                                                                           ox; title = "Injected magma")
    d[("mageres-melt-chamber-fig", "figure")] = mageres_composition_figure(S.t, S.chamber_comp,
                                                                           ox; title = "Chamber (bulk)")
    d[("mageres-melt-out-fig",     "figure")] = mageres_composition_figure(mageres_layer_times(st.pluton),
                                                                           mageres_layer_comps(st.pluton),
                                                                           ox; title     = "Erupted (anhydrous)",
                                                                               anhydrous = true)
    return d
end

"""
    mageres_toggle_collapse(app, button_id::AbstractString, collapse_id::AbstractString)

    Register a callback that opens/closes collapse `collapse_id` on clicks of button `button_id`.
"""
function mageres_toggle_collapse(app, button_id::AbstractString, collapse_id::AbstractString)
    callback!(
        app,
        Output(collapse_id, "is_open"),

        Input(button_id,    "n_clicks"),

        State(collapse_id,  "is_open"),

        prevent_initial_call = true,
    ) do n, is_open
        isnothing(n) && (n = 0)
        n <= 0 && return is_open
        return is_open == true ? false : true
    end
    return app
end

"""
    mageres_bulk_sync_callback!(app, suffix::AbstractString)

    Register a callback that refills the bulk-rock table and test dropdown of panel `suffix` on a test,
    database or upload change, or with the table of a loaded configuration.
"""
function mageres_bulk_sync_callback!(app, suffix::AbstractString)
    dropdown_id = "test-dropdown-mageres-$(suffix)"
    table_id    = "table-bulk-rock-mageres-$(suffix)"
    ok_id       = "upload-ok-mageres-$(suffix)"
    callback!(
        app,
        Output(table_id,                   "data"),
        Output(dropdown_id,                "options"),
        Output(dropdown_id,                "value"),

        Input(dropdown_id,                 "value"),
        Input("database-dropdown-mageres", "value"),
        Input(ok_id,                       "is_open"),
        Input("mageres-config-store",      "data"),

        prevent_initial_call = true,
    ) do test, dtb, _upload_ok, loaded
        if any(t -> startswith(String(t.prop_id), "mageres-config-store."), callback_context().triggered)
            loaded === nothing && return no_update(), no_update(), no_update()
            return loaded["bulk"][suffix], no_update(), no_update()
        end
        sub  = db[(db.db .== dtb), :]
        isempty(sub) && return no_update(), no_update(), no_update()
        val  = (test === nothing || !(test in sub.test)) ? sub.test[1] : test
        row  = sub[(sub.test .== val), :]
        data = [ Dict("oxide" => row.oxide[1][i], "fraction" => row.frac[1][i]) for i = 1:length(row.oxide[1]) ]
        opts = [ Dict("label" => sub.title[i], "value" => sub.test[i]) for i = 1:size(sub, 1) ]
        return data, opts, val
    end
    return app
end

"""
    mageres_bulk_upload_callback!(app, suffix::AbstractString)

    Register a callback that parses a bulk-rock file uploaded to panel `suffix` and shows the success
    or failure alert.
"""
function mageres_bulk_upload_callback!(app, suffix::AbstractString)
    callback!(
        app,
        Output("upload-ok-mageres-$(suffix)",     "is_open"),
        Output("upload-failed-mageres-$(suffix)", "is_open"),
        Output("upload-failed-mageres-$(suffix)", "children"),

        Input("upload-bulk-mageres-$(suffix)",    "contents"),

        State("upload-bulk-mageres-$(suffix)",    "filename"),

        prevent_initial_call = true,
    ) do contents, filename
        contents === nothing && return no_update(), no_update(), no_update()
        status, msg = parse_bulk_rock(contents, filename)
        return status == 1 ? (true, false, "") : (false, true, msg)
    end
    return app
end

"""
    mageres_te_sync_callback!(app, suffix::AbstractString)

    Register a callback that refills the trace-element table of panel `suffix` with the selected predefined
    composition, or with the table of a loaded configuration.
"""
function mageres_te_sync_callback!(app, suffix::AbstractString)
    callback!(
        app,
        Output("table-te-mageres-$(suffix)",        "data"),

        Input("test-te-dropdown-mageres-$(suffix)", "value"),
        Input("mageres-config-store",               "data"),

        prevent_initial_call = true,
    ) do test, loaded
        if any(t -> startswith(String(t.prop_id), "mageres-config-store."), callback_context().triggered)
            return loaded === nothing ? no_update() : loaded["te"][suffix]
        end
        dbte = AppData.dbte
        i    = test === nothing ? nothing : findfirst(==(test), dbte.test)
        i === nothing && return no_update()
        return [ Dict("elements" => dbte.elements[i][k], "μg_g" => dbte.μg_g[i][k])
                 for k = 1:length(dbte.elements[i]) ]
    end
    return app
end

"""
    mageres_config_dir()

    Folder of the saved MAGEMin Reservoir configurations (inside the app's saved-state folder).
"""
mageres_config_dir() = joinpath(state_dir(), "mageres")

"""
    mageres_config_file(name)

    JSON file of the configuration `name`; `nothing` for an empty or unsafe name.
"""
function mageres_config_file(name)
    name isa AbstractString || return nothing
    n = strip(name)
    (isempty(n) || n in (".", "..") || occursin(r"[/\\:\x00]", n)) && return nothing
    return joinpath(mageres_config_dir(), String(n) * ".json")
end

"""
    mageres_list_configs()

    Names of the saved configurations, sorted.
"""
function mageres_list_configs()
    dir = mageres_config_dir()
    isdir(dir) || return String[]
    return sort([f[1:end-5] for f in readdir(dir) if endswith(f, ".json")])
end

"""
    mageres_config_tables(o::MAGEResOptions)

    Bulk-rock tables (magma, host, injection) and trace-element tables (magma, host, injection) of the options `o`,
    as stored for the composition panels.
"""
function mageres_config_tables(o::MAGEResOptions)
    bulk(x)  = [Dict("oxide" => o.oxides[k], "fraction" => x[k]) for k in eachindex(o.oxides)]
    inj      = isempty(o.injection_bulk) ? o.magma_bulk : o.injection_bulk
    el, Ci, Ch = mageres_te_inputs(o)
    Cm       = isempty(o.te_magma_ppm) ? Ci : o.te_magma_ppm
    te(C)    = [Dict("elements" => el[k], "μg_g" => C[k]) for k in eachindex(el)]
    return Dict("bulk" => Dict("magma" => bulk(o.magma_bulk), "host" => bulk(o.host_bulk), "injection" => bulk(inj)),
                "te"   => Dict("magma" => te(Cm), "host" => te(Ch), "injection" => te(Ci)),
                "id"   => string(rand(UInt64); base = 16))
end

"""
    mageres_config_callbacks!(app)

    Register the callbacks of the save/load configuration and simulation dialogs: open and close them with the list of
    saved files, write the current options (with all compositions) to JSON or the current run to JLD2, and restore
    every option, the database, the "Same as magma" switch and the composition tables from a saved configuration or
    from the configuration of a loaded simulation.
"""
function mageres_config_callbacks!(app)
    for (what, lister) in (("config", mageres_list_configs), ("sim", mageres_list_runs)), kind in ("save", "load")
        list_id = "$(kind)-$(what)-existing-mageres"
        callback!(
            app,
            Output("$(kind)-$(what)-modal-mageres", "is_open"),
            Output(list_id,                         "options"),

            Input("open-$(kind)-$(what)-mageres",   "n_clicks"),
            Input("close-$(kind)-$(what)-mageres",  "n_clicks"),
            Input("$(kind)-$(what)-button-mageres", "n_clicks"),

            prevent_initial_call = true,
        ) do _o, _c, _b
            pushed_button(callback_context()) == "open-$(kind)-$(what)-mageres" || return false, no_update()
            return true, [Dict("label" => n, "value" => n) for n in lister()]
        end

        callback!(
            app,
            Output("$(kind)-$(what)-filename-mageres", "value"),

            Input(list_id,                             "value"),

            prevent_initial_call = true,
        ) do selected
            return selected === nothing ? no_update() : selected
        end
    end

    callback!(
        app,
        Output("mageres-loaded-run-store",  "data"),
        Output("mageres-sim-config-store",  "data"),
        Output("load-sim-alert-mageres",    "children"),
        Output("load-sim-alert-mageres",    "color"),
        Output("load-sim-alert-mageres",    "is_open"),

        Input("load-sim-button-mageres",    "n_clicks"),

        State("load-sim-filename-mageres",  "value"),

        prevent_initial_call = true,
    ) do _n, sim_name
        fail(msg) = (no_update(), no_update(), msg, "danger", true)
        file = mageres_run_file(sim_name)
        (file === nothing || !isfile(file)) && return fail("Simulation not found: $(sim_name)")
        any(mageres_is_active, values(MAGERES_LIVE_RUNS)) &&
            return fail("Cannot load while a MAGEMin Reservoir run is in progress.")
        loaded = try
            mageres_load_simulation(file)
        catch e
            return fail("Cannot load $(strip(sim_name)): $(sprint(showerror, e))")
        end
        live, o = loaded
        for k in collect(keys(MAGERES_LIVE_RUNS))
            mageres_is_active(MAGERES_LIVE_RUNS[k]) || delete!(MAGERES_LIVE_RUNS, k)
        end
        new_id                    = string(rand(UInt64); base = 16)
        MAGERES_LIVE_RUNS[new_id] = live
        msg = @sprintf("Simulation loaded: %s (%d outputs, t = %.0f yr)", strip(sim_name), length(live.outputs), live.t)
        return new_id, mageres_options_to_dict(o), msg, "success", true
    end

    callback!(
        app,
        Output("save-sim-alert-mageres",   "children"),
        Output("save-sim-alert-mageres",   "color"),
        Output("save-sim-alert-mageres",   "is_open"),

        Input("save-sim-button-mageres",   "n_clicks"),

        State("save-sim-filename-mageres", "value"),
        State("run-id-store-mageres",      "data"),

        prevent_initial_call = true,
    ) do _n, name, run_id
        file = mageres_run_file(name)
        file === nothing && return "Invalid simulation name", "danger", true
        (run_id isa AbstractString && haskey(MAGERES_LIVE_RUNS, run_id)) ||
            return "No simulation to save yet", "danger", true
        snap = mageres_live_snapshot(MAGERES_LIVE_RUNS[run_id])
        try
            mkpath(mageres_runs_dir())
            t = @elapsed mageres_save_simulation(file, snap)
            msg = @sprintf("Simulation saved: %s (%d outputs up to t = %.0f yr, %s, %.1f MB, %.1f s)", strip(name),
                           length(snap.outputs), snap.outputs[end].t, snap.phase, filesize(file) / 1e6, t)
            return msg, "success", true
        catch e
            return "Cannot save: $(sprint(showerror, e))", "danger", true
        end
    end

    callback!(
        app,
        Output("save-config-alert-mageres",    "children"),
        Output("save-config-alert-mageres",    "color"),
        Output("save-config-alert-mageres",    "is_open"),

        Input("save-config-button-mageres",    "n_clicks"),

        State("save-config-filename-mageres",  "value"),
        mageres_option_states()...;

        prevent_initial_call = true,
    ) do _n, name, vals...
        file = mageres_config_file(name)
        file === nothing && return "Invalid configuration name", "danger", true
        o = try
            mageres_collect_options(collect(vals))
        catch e
            e isa ArgumentError || rethrow()
            return "Cannot save: $(e.msg)", "danger", true
        end
        mkpath(mageres_config_dir())
        mageres_save_options(file, o)
        return "Configuration saved: $(strip(name)) (eruption trigger: $(o.eruption_trigger))", "success", true
    end

    callback!(
        app,
        [Output(mageres_input_id(f), "value") for f in mageres_ui_fields()]...,
        Output("database-dropdown-mageres",    "value"),
        Output("injection-use-magma-mageres",  "value"),
        Output("mageres-config-store",         "data"),
        Output("load-config-alert-mageres",    "children"),
        Output("load-config-alert-mageres",    "color"),
        Output("load-config-alert-mageres",    "is_open"),

        Input("load-config-button-mageres",    "n_clicks"),
        Input("mageres-sim-config-store",      "data"),

        State("load-config-filename-mageres",  "value"),

        prevent_initial_call = true,
    ) do _n, sim_options, name
        nf   = length(mageres_ui_fields())
        fail(msg) = (fill(no_update(), nf + 3)..., msg, "danger", true)
        if pushed_button(callback_context()) == "mageres-sim-config-store"
            sim_options === nothing && return (fill(no_update(), nf + 3)..., no_update(), no_update(), no_update())
            o = mageres_options_from_dict(Dict{String,Any}(string(k) => v for (k, v) in sim_options))
            return ([getfield(o, f) for f in mageres_ui_fields()]..., o.database,
                    isempty(o.injection_bulk) ? [1] : Int[], mageres_config_tables(o),
                    "Configuration of the loaded simulation restored", "success", true)
        end
        file = mageres_config_file(name)
        (file === nothing || !isfile(file)) && return fail("Configuration not found: $(name)")
        o = try
            mageres_load_options(file)
        catch e
            return fail("Cannot load $(strip(name)): $(sprint(showerror, e))")
        end
        return ([getfield(o, f) for f in mageres_ui_fields()]..., o.database,
                isempty(o.injection_bulk) ? [1] : Int[], mageres_config_tables(o),
                "Configuration loaded: $(strip(name)) (eruption trigger: $(o.eruption_trigger))", "success", true)
    end
    return app
end

const MAGERES_SVG_RESULT_MAPS  = [("mageres-results-temperature-fig", "MAGERes_temperature",   :T),
                                  ("mageres-results-material-fig",    "MAGERes_material",      :material),
                                  ("mageres-results-melt-fig",        "MAGERes_melt_fraction", :melt),
                                  ("mageres-results-calc-fig",        "MAGERes_calculations",  :calc)]
const MAGERES_SVG_IC_MAPS      = [("mageres-ic-material-fig",    "MAGERes_IC_material",    :frac),
                                  ("mageres-ic-temperature-fig", "MAGERes_IC_temperature", :T),
                                  ("mageres-ic-pressure-fig",    "MAGERes_IC_pressure",    :pressure),
                                  ("mageres-ic-grid-fig",        "MAGERes_IC_grid",        :level)]
const MAGERES_SVG_RESULT_PLOTS = [("mageres-eruption-fig",        "MAGERes_eruption_volumes"),
                                  ("mageres-eruption-te-fig",     "MAGERes_erupted_trace_elements"),
                                  ("mageres-zircon-rank-fig",     "MAGERes_zircon_rank_order"),
                                  ("mageres-zircon-ages-fig",     "MAGERes_zircon_age_distribution"),
                                  ("mageres-zircon-spots-fig",    "MAGERes_zircon_core_to_rim"),
                                  ("mageres-zircon-families-fig", "MAGERes_zircon_families"),
                                  ("mageres-melt-in-fig",         "MAGERes_composition_injected"),
                                  ("mageres-melt-chamber-fig",    "MAGERes_composition_chamber"),
                                  ("mageres-melt-out-fig",        "MAGERes_composition_erupted"),
                                  ("mageres-tas-fig",             "MAGERes_TAS"),
                                  ("mageres-cumulate-fig",        "MAGERes_cumulate_log"),
                                  ("mageres-diagnostics-fig",     "MAGERes_conservation"),
                                  ("mageres-vital-signs-fig",     "MAGERes_vital_signs"),
                                  ("mageres-convection-fig",      "MAGERes_convection"),
                                  ("mageres-energy-budget-fig",   "MAGERes_energy_budget")]

"""
    mageres_export_output(run_id, sel)

    State and time [yr] of the output of run `run_id` selected by `sel`, or `(nothing, NaN)` without one.
"""
function mageres_export_output(run_id, sel)
    (run_id isa AbstractString && haskey(MAGERES_LIVE_RUNS, run_id)) || return nothing, NaN
    snap = mageres_live_snapshot(MAGERES_LIVE_RUNS[run_id])
    i    = mageres_selected_index(snap, sel)
    i == 0 && return nothing, NaN
    return snap.outputs[i].state, snap.outputs[i].t
end

"""
    mageres_export_stem(stem::AbstractString, t::Real)

    Export file name `stem` with the output time `t` [yr] appended when known.
"""
mageres_export_stem(stem::AbstractString, t::Real) = isfinite(t) ? @sprintf("%s_t%dyr", stem, round(Int, t)) : stem

"""
    mageres_ic_state(vals, field::Symbol)

    Initial state rebuilt from the option values `vals` as for the initial-condition figures (constant properties;
    after the first injection for the grid map), or `nothing` when the options are invalid.
"""
function mageres_ic_state(vals, field::Symbol)
    o = try
        mageres_collect_options(collect(vals))
    catch e
        e isa ArgumentError || rethrow()
        return nothing
    end
    oc                  = deepcopy(o)
    oc.thermodynamics   = "constant"
    oc.te_enabled       = false
    oc.eruption_trigger = "melt"
    st                  = mageres_init_state(oc)
    field == :level && mageres_inject!(st)
    return st
end

"""
    mageres_svg_callbacks!(app)

    Register the "Export svg" callbacks of every MAGEMin Reservoir graph: maps are written with their true model cells,
    the other figures as they are displayed, with the selected output time in the file name.
"""
function mageres_svg_callbacks!(app)
    out_states = (("run-id-store-mageres", "data"), ("mageres-timestep-select", "value"))
    out_stem(stem) = (run_id, sel) -> mageres_export_stem(stem, mageres_export_output(run_id, sel)[2])
    for (id, stem, field) in MAGERES_SVG_RESULT_MAPS
        cells = (run_id, sel) -> begin
            st, _ = mageres_export_output(run_id, sel)
            st === nothing && return nothing
            mageres_svg_cells(st, field == :material && st.thermo === nothing ? :frac : field)
        end
        register_figure_svg_export!(app, id, out_stem(stem); extra_states = out_states, underlay_fn = cells)
    end
    option_states = [(s.id, s.property) for s in mageres_option_states()]
    for (id, stem, field) in MAGERES_SVG_IC_MAPS
        cells = (vals...) -> (st = mageres_ic_state(vals, field);
                              st === nothing ? nothing : mageres_svg_cells(st, field))
        register_figure_svg_export!(app, id, (vals...) -> stem; extra_states = option_states, underlay_fn = cells)
    end
    for (id, stem) in MAGERES_SVG_RESULT_PLOTS
        register_figure_svg_export!(app, id, out_stem(stem); extra_states = out_states)
    end
    return app
end

"""
    mageres_gif_callbacks!(app)

    Register the "Save gif" callbacks of the map, TAS and cumulate graphs: the selected run is rendered over all its
    outputs with the active display options and written as an animated GIF to the output folder.
"""
function mageres_gif_callbacks!(app)
    stems = Dict(id => stem for (id, stem) in vcat([(i, s) for (i, s, _) in MAGERES_SVG_RESULT_MAPS],
                                                   MAGERES_SVG_RESULT_PLOTS))
    for id in MAGERES_GIF_GRAPHS
        callback!(
            app,
            Output(id * "-gif-status",                 "children"),

            Input(id * "-gif-button",                  "n_clicks"),

            State("run-id-store-mageres",              "data"),
            State("mageres-probe-store",               "data"),
            State("mageres-pie-unit",                  "data"),
            State(mageres_input_id(:show_grid),        "value"),
            State(mageres_input_id(:show_outline),     "value"),
            State(mageres_input_id(:show_isotherms),   "value"),
            State(mageres_input_id(:gif_frame_ms),     "value"),

            prevent_initial_call = true,
        ) do _n, run_id, probe, pie_unit, show_grid, show_outline, show_isotherms, frame_ms
            global output_dir
            (run_id isa AbstractString && haskey(MAGERES_LIVE_RUNS, run_id)) ||
                return pd_export_status("Nothing to animate yet - run or load a simulation first."; ok = false)
            snap = mageres_live_snapshot(MAGERES_LIVE_RUNS[run_id])
            pv   = probe === nothing ? nothing : (Float64(probe[1]), Float64(probe[2]))
            ms   = frame_ms isa Real && frame_ms > 0 ? frame_ms : 250
            try
                mkpath(output_dir[1])
                path = output_dir[1] * stems[id] * ".gif"
                t    = @elapsed n = mageres_save_gif(path, snap, id; frame_ms = ms, probe = pv, pie_unit = pie_unit,
                                                     show_grid = show_grid, show_outline = show_outline,
                                                     show_isotherms = show_isotherms)
                msg  = @sprintf("Saved %s (%d frames, %.1f MB, %.0f s).", path, n, filesize(path) / 1e6, t)
                return pd_export_status(msg; ok = true)
            catch e
                return pd_export_status("GIF failed: " * sprint(showerror, e); ok = false)
            end
        end
    end
    return app
end

"""
    Tab_MAGERes_Callbacks(app)

    Register all callbacks of the MAGEMin Reservoir tab on `app`.
"""
function Tab_MAGERes_Callbacks(app)

    mageres_toggle_collapse(app, "button-config-mageres", "collapse-config-mageres")

    """
        Show or hide the constant-property-only option rows when the thermodynamics option changes.
    """
    callback!(
        app,
        [Output(mageres_row_id(f), "style") for f in MAGERES_CONSTANT_ONLY_FIELDS]...,

        Input(mageres_input_id(:thermodynamics), "value"),
    ) do thermodynamics
        return Tuple(mageres_row_style(f, thermodynamics) for f in MAGERES_CONSTANT_ONLY_FIELDS)
    end

    mageres_toggle_collapse(app, "button-simulation-mageres", "collapse-simulation-mageres")

    """
        Open the bulk-rock composition drawer on "Define material compositions".
    """
    callback!(
        app,
        Output("mageres-bulk-canvas",       "is_open"),

        Input("button-define-bulk-mageres", "n_clicks"),

        prevent_initial_call = true,
    ) do _n
        return true
    end

    """
        Open the injection composition drawer on "Define injection composition".
    """
    callback!(
        app,
        Output("mageres-injection-canvas",       "is_open"),

        Input("button-define-injection-mageres", "n_clicks"),

        prevent_initial_call = true,
    ) do _n
        return true
    end

    for suffix in ("magma", "host", "injection")
        mageres_bulk_sync_callback!(app, suffix)
        mageres_bulk_upload_callback!(app, suffix)
    end

    for suffix in ("magma", "host", "injection")
        mageres_te_sync_callback!(app, suffix)
    end

    mageres_config_callbacks!(app)
    mageres_svg_callbacks!(app)
    mageres_gif_callbacks!(app)

    """
        Compute the initial state on "Compute initial conditions" and update the initial-condition
        figures (material, temperature, pressure, grid after the first injection) and the status alert.
    """
    callback!(
        app,
        Output("mageres-ic-material-fig",    "figure"),
        Output("mageres-ic-temperature-fig", "figure"),
        Output("mageres-ic-pressure-fig",    "figure"),
        Output("mageres-ic-grid-fig",        "figure"),
        Output("ic-status-alert-mageres",    "children"),
        Output("ic-status-alert-mageres",    "color"),
        Output("ic-status-alert-mageres",    "is_open"),

        Input("compute-ic-button-mageres",   "n_clicks"),

        mageres_option_states()...;

        prevent_initial_call = true,
    ) do _n, vals...
        o = try
            mageres_collect_options(collect(vals))
        catch e
            e isa ArgumentError || rethrow()
            return no_update(), no_update(), no_update(), no_update(), e.msg, "danger", true
        end
        oc                = deepcopy(o)
        oc.thermodynamics   = "constant"
        oc.te_enabled       = false
        oc.eruption_trigger = "melt"
        st                = mageres_init_state(oc)
        c1                = deepcopy(st.chamber)
        c1.T              = mageres_injection_volume(o) / c1.I
        preview           = mageres_chamber_polygon(c1)
        st1               = deepcopy(st)
        mageres_inject!(st1)
        note     = "dashed: chamber after the first injection"
        sg       = (show_grid = o.show_grid, show_outline = o.show_outline)
        fig_mat  = mageres_field_figure(st, :frac; preview = preview, sg...,
                                        title = "Material — initial state ($note)")
        fig_T    = mageres_field_figure(st, :T; preview = preview, sg..., show_isotherms = o.show_isotherms,
                                        title = "Temperature — initial geotherm ($note)")
        fig_P    = mageres_field_figure(st, :pressure; preview = preview, sg...,
                                        title = "Pressure — lithostatic ($note)")
        fig_grid = mageres_field_figure(st1, :level; show_grid = true,
                                        title = "Quadtree after the first injection — $(mageres_ncells(st1.grid)) cells")
        box      = mageres_view_box(st1)
        msg      = @sprintf("Initial conditions computed: domain 0–%.1f km depth (shown %.1f–%.1f km), %d cells after the first injection.",
                            o.domain_thickness_km, -box[4] / 1e3, -box[3] / 1e3, mageres_ncells(st1.grid))
        o.thermodynamics == "magemin" && (msg *= " MAGEMin equilibria are computed at launch.")
        return fig_mat, fig_T, fig_P, fig_grid, msg, "success", true
    end

    """
        Store the pie-chart unit selected in the legend of any results map graph (restyle event).
    """
    callback!(
        app,
        Output("mageres-pie-unit", "data"),

        [Input(id, "restyleData") for id in MAGERES_MAP_GRAPHS]...,

        prevent_initial_call = true,
    ) do restyles...
        bid   = pushed_button(callback_context())
        k     = findfirst(==(bid), MAGERES_MAP_GRAPHS)
        (k === nothing || restyles[k] === nothing || isempty(restyles[k])) && return no_update()
        upd   = restyles[k][1]
        label = get(upd, Symbol("title.text"), nothing)
        label isa AbstractVector && (label = isempty(label) ? nothing : first(label))
        u     = findfirst(==(label), [MAGERES_PIE_UNITS[i] for i in 1:3])
        return u === nothing ? no_update() : u
    end

    """
        Store the (x, y) position clicked on any results map graph as the probe location.
    """
    callback!(
        app,
        Output("mageres-probe-store", "data"),

        [Input(id, "clickData") for id in MAGERES_MAP_GRAPHS]...,

        prevent_initial_call = true,
    ) do clicks...
        bid = pushed_button(callback_context())
        k   = findfirst(==(bid), MAGERES_MAP_GRAPHS)
        (k === nothing || clicks[k] === nothing) && return no_update()
        pts = get(clicks[k], :points, nothing)
        (pts === nothing || isempty(pts)) && return no_update()
        pt  = pts[1]
        (haskey(pt, :x) && haskey(pt, :y) && pt[:x] isa Number && pt[:y] isa Number) || return no_update()
        return [Float64(pt[:x]), Float64(pt[:y])]
    end

    """
        Launch a simulation in a background task on "Launch simulation", request its cancellation on
        "Cancel", and on each poll tick, timestep, probe or display-option change update the run status,
        all results figures and the timestep options from the live-run snapshot.
    """
    callback!(
        app,
        [Output(id, prop) for (id, prop) in MAGERES_RUN_OUTPUTS]...,

        Input("launch-run-button-mageres",         "n_clicks"),
        Input("cancel-run-button-mageres",         "n_clicks"),
        Input("resume-run-button-mageres",         "n_clicks"),
        Input("run-poll-interval-mageres",         "n_intervals"),
        Input("mageres-timestep-select",           "value"),
        Input("mageres-probe-store",               "data"),
        Input(mageres_input_id(:show_grid),        "value"),
        Input(mageres_input_id(:show_outline),     "value"),
        Input(mageres_input_id(:show_isotherms),   "value"),
        Input("mageres-te-show",                   "value"),
        Input("mageres-te-norm",                   "value"),
        Input("mageres-loaded-run-store",          "data"),

        State("mageres-pie-unit",                  "data"),
        State("run-id-store-mageres",              "data"),
        mageres_option_states()...;

        prevent_initial_call = true,
    ) do _launch, _cancel, _resume, _n, sel, probe, show_grid, show_outline, show_isotherms, te_show, te_norm, run_id_loaded,
         pie_unit, run_id, vals...
        bid = pushed_button(callback_context())

        if bid == "mageres-loaded-run-store"
            (run_id_loaded isa AbstractString && haskey(MAGERES_LIVE_RUNS, run_id_loaded)) ||
                return mageres_outputs(Dict())
            return mageres_outputs(Dict(("run-id-store-mageres",      "data")     => run_id_loaded,
                                        ("run-poll-interval-mageres", "disabled") => false,
                                        ("run-poll-interval-mageres", "interval") => MAGERES_POLL_MS))
        end

        if bid == "launch-run-button-mageres"
            o = try
                mageres_collect_options(collect(vals))
            catch e
                e isa ArgumentError || rethrow()
                return mageres_outputs(Dict(("run-status-text-mageres", "children") => "Cannot launch: $(e.msg)"))
            end
            any(mageres_is_active, values(MAGERES_LIVE_RUNS)) &&
                return mageres_outputs(Dict(("run-status-text-mageres", "children") =>
                                            "Cannot launch: a MAGEMin Reservoir run is still in progress. Cancel it or wait until it finishes."))
            for k in collect(keys(MAGERES_LIVE_RUNS))
                mageres_is_active(MAGERES_LIVE_RUNS[k]) || delete!(MAGERES_LIVE_RUNS, k)
            end
            new_id                    = string(rand(UInt64); base = 16)
            live                      = MAGEResLiveRun()
            MAGERES_LIVE_RUNS[new_id] = live
            nsteps                    = max(1, ceil(Int, o.run_time_yr / o.thermal_dt_yr))
            o.thermodynamics == "magemin" ? mageres_progress_stage!("initialising MAGEMin", 0) :
                                            mageres_progress_stage!("timestep", nsteps)
            Base.errormonitor(Threads.@spawn begin
                try
                    if o.thermodynamics == "magemin"
                        mageres_run_live!(live, o; stage_fn = mageres_progress_batch!, callback_fn = update_progress)
                    else
                        mageres_run_live!(live, o; progress = mageres_progress_step!)
                    end
                finally
                    mageres_progress_clear!()
                end
            end)
            return mageres_outputs(Dict(("run-id-store-mageres",      "data")     => new_id,
                                        ("run-poll-interval-mageres", "disabled") => false,
                                        ("run-status-text-mageres",   "children") => "Launching...",
                                        ("run-poll-interval-mageres", "interval") => MAGERES_POLL_MS))
        end

        (run_id === nothing || isempty(run_id) || !haskey(MAGERES_LIVE_RUNS, run_id)) && return mageres_outputs(Dict())
        live = MAGERES_LIVE_RUNS[run_id]

        if bid == "cancel-run-button-mageres"
            lock(() -> (live.cancel_requested = true), live.lock)
            return mageres_outputs(Dict(("run-status-text-mageres", "children") => "Cancelling..."))
        end

        if bid == "resume-run-button-mageres"
            status(msg) = mageres_outputs(Dict(("run-status-text-mageres", "children") => msg))
            any(mageres_is_active, values(MAGERES_LIVE_RUNS)) &&
                return status("Cannot resume: a MAGEMin Reservoir run is still in progress. Cancel it or wait until it finishes.")
            src = mageres_resume_source(live)
            src === nothing && return status("Cannot resume: the run has no stored state.")
            o = try
                mageres_collect_options(collect(vals))
            catch e
                e isa ArgumentError || rethrow()
                return status("Cannot resume: $(e.msg)")
            end
            o.run_time_yr > src.t + 1e-9 ||
                return status(@sprintf("Cannot resume: set the run time beyond the model time (%.0f yr).", src.t))
            magemin = src.thermo !== nothing
            nsteps  = max(1, ceil(Int, o.run_time_yr / src.opts.thermal_dt_yr))
            magemin ? mageres_progress_stage!("initialising MAGEMin", 0) : mageres_progress_stage!("timestep", nsteps)
            t_end   = o.run_time_yr
            Base.errormonitor(Threads.@spawn begin
                try
                    if magemin
                        mageres_resume_live!(live, t_end; stage_fn = mageres_progress_batch!,
                                             callback_fn = update_progress)
                    else
                        mageres_resume_live!(live, t_end; progress = mageres_progress_step!)
                    end
                finally
                    mageres_progress_clear!()
                end
            end)
            msg = @sprintf("Resuming at t = %.0f yr up to %.0f yr...", src.t, t_end)
            return mageres_outputs(Dict(("run-poll-interval-mageres", "disabled") => false,
                                        ("run-status-text-mageres",   "children") => msg,
                                        ("run-poll-interval-mageres", "interval") => MAGERES_POLL_MS))
        end

        snap = mageres_live_snapshot(live)
        pv   = probe === nothing ? nothing : (Float64(probe[1]), Float64(probe[2]))
        d    = mageres_results_figures(snap, sel; probe = pv, pie_unit = pie_unit, show_grid = show_grid,
                                       show_outline = show_outline, show_isotherms = show_isotherms,
                                       te_show = te_show, te_norm = te_norm)
        bid in ("mageres-timestep-select", "mageres-probe-store", mageres_input_id(:show_grid),
                mageres_input_id(:show_outline), mageres_input_id(:show_isotherms), "mageres-te-show",
                "mageres-te-norm") &&
            return mageres_outputs(d)

        finished = snap.phase in ("done", "cancelled", "error")
        d[("run-poll-interval-mageres", "disabled")] = finished
        d[("run-status-text-mageres",   "children")] = mageres_run_status_text(snap)
        finished && (d[("mageres-progress-off", "data")] = string(rand(UInt64); base = 16))
        d[("mageres-timestep-select",   "options")]  = mageres_timestep_options(snap)
        return mageres_outputs(d)
    end

    return app
end
