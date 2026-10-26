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

const STATE_DIAGRAM_FIELDS = [  "infos", "layout", "data", "data_plot", "data_reaction", "iso_show", "n_lbl", "data_isopleth", "data_isopleth_out",
                                "Out_XY", "Hash_XY", "Out_TE_XY", "all_TE_ph", "Out_O18_XY", "all_O18_ph", "n_phase_XY", "addedRefinementLvl", "pChip_wat", "pChip_T",
                                "assemblage_rows", "list_compacted_idx", "raw_field_id", "PT_infos", "Sec_status_XY", "Sec_seed_grid", "Sec_seed_X" ]

const STATE_EXTRA_FIELDS = [ "dataset", "sas", "wf", "seismic_cor", "aspect_ratio", "seismic_water", "shallow_cor", "fluid_as_melt", "anelastic_cor",
                             "mumu_oxide1", "mumu_oxide2", "mumu_ox1_min", "mumu_ox1_max", "mumu_ox2_min", "mumu_ox2_max",
                             "mumu_mu1_min", "mumu_mu1_max", "mumu_mu2_min", "mumu_mu2_max",
                             "fields", "colormap", "reverse_cmap", "set_min_white",
                             "o18", "o18_delta", "o18_delta2", "o18_anchor", "o18_anchor_delta", "o18_melt", "o18_unmapped", "o18_tmax" ]

global loaded_state_has_diagram = false
global state_pending_dataset = Ref{Any}(nothing)

state_dir() = joinpath(@__DIR__, "..", "saved_states")

function state_base_path(filename)
    filename isa AbstractString || return nothing
    name = strip(filename)
    if isempty(name) || name in (".", "..") || occursin(r"[/\\:\x00]", name)
        return nothing
    end
    return joinpath(state_dir(), String(name))
end

function state_options_file(filename)
    base = state_base_path(filename)
    isnothing(base) && return nothing
    file = base * "_options.jld2"
    return isfile(file) ? file : nothing
end

function state_read(file, keys::AbstractString...; optional = keys)
    return jldopen(file, "r") do f
        for k in keys
            haskey(f, k) || k in optional || throw(KeyError(k))
        end
        Tuple(haskey(f, k) ? f[k] : nothing for k in keys)
    end
end

state_plain_rows(rows) = isnothing(rows) ? nothing : [Dict{String,Any}(String(k) => v for (k, v) in pairs(r)) for r in rows]

state_load_triggered() = any(t -> startswith(String(t.prop_id), "load-state-diagram-button."), callback_context().triggered)

state_pressure_kbar(v, saved_unit) =saved_unit == "gpa" ? Float64(v) * 10.0 : Float64(v)

function state_convert_bulk_table(rows, from_unit, to_unit)
    isnothing(rows) && return nothing
    (isnothing(from_unit) || isnothing(to_unit)) && return nothing
    from_unit == to_unit && return rows
    oxi   = [String(r["oxide"]) for r in rows]
    frac  = [r["fraction"] isa String ? parse(Float64, r["fraction"]) : Float64(r["fraction"]) for r in rows]
    total = sum(frac)
    total > 0 || return nothing
    conv  = to_unit == 2 ? mol2wt(frac ./ total, oxi) : wt2mol(frac ./ total, oxi)
    conv  = conv ./ sum(conv) .* total
    return [Dict{String,Any}("oxide" => o, "fraction" => round(c, digits=10)) for (o, c) in zip(oxi, conv)]
end

function Tab_Simulation_Callbacks(app)

    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output( "grid-subdivision",     "value"     ),
        Input(  "gsub-id",              "value"     ),

    prevent_initial_call = true,
    ) do n_ref

        n_ref_info = "$(2^n_ref) × $(2^n_ref) grid"

        return n_ref_info
    end




    callback!(
        app,
        Output( "kds-dropdown",                 "options"),
        Output( "kds-dropdown",                 "value"   ),
        Input(  "upload-TE-data",               "contents"),
        Input(  "kds-dropdown-trigger",         "value"   ),
        State(  "upload-TE-data",               "filename"),
        State(  "kds-dropdown",                 "options"),
        State(  "kds-dropdown",                 "value"   ),
        prevent_initial_call = true,  
    ) do contents, KDs_dtb, filename, KDs_options, KDs_value

        bid = pushed_button( callback_context() ) 

        if bid == "upload-TE-data"
            if isnothing(contents)
                return ""
            end

            KDs_new     = parse_contents(contents, filename)
            KDs_old     = AppData.KDs

            push!(KDs_old, KDs_new)
            # KDs_update  = (KDs_new, KDs_old)

            global AppData = merge(AppData, (KDs = KDs_old,))

            np              = length(KDs_old)
            KDs_options     = [Dict(     "label"     => KDs_old[i][5],
                                         "value"     => KDs_old[i][4] )
                                for i=1:np ];
        elseif bid == "kds-dropdown-trigger"
            KDs_value    = KDs_dtb;
        end

        return KDs_options, KDs_value
    end

    # ── helper: list existing saves ────────────────────────────────────────────
    function _list_saves()
        dir = state_dir()
        isdir(dir) || return String[]
        files = readdir(dir)
        names = [replace(f, r"_options\.jld2$" => "") for f in files if endswith(f, "_options.jld2")]
        return sort(names)
    end

    # Open/close save modal + populate existing saves dropdown
    callback!(app,
        Output("save-state-modal",             "is_open"),
        Output("save-modal-existing-dropdown", "options"),
        Input("open-save-modal-button",        "n_clicks"),
        Input("close-save-modal-button",       "n_clicks"),
        Input("save-state-diagram-button",     "n_clicks"),
        prevent_initial_call=true,
    ) do _, _, _
        bid = pushed_button(callback_context())
        if bid == "open-save-modal-button"
            names = _list_saves()
            opts  = [Dict("label"=>n, "value"=>n) for n in names]
            return true, opts
        end
        return false, no_update()
    end

    # Existing save selected → fill filename input
    callback!(app,
        Output("save-state-filename-id",       "value"),
        Input("save-modal-existing-dropdown",  "value"),
        prevent_initial_call=true,
    ) do selected
        isnothing(selected) && return no_update()
        return selected
    end

    # Open/close load modal + populate file dropdown
    callback!(app,
        Output("load-state-modal",        "is_open"),
        Output("load-modal-file-dropdown","options"),
        Input("open-load-modal-button",   "n_clicks"),
        Input("close-load-modal-button",  "n_clicks"),
        Input("load-state-diagram-button","n_clicks"),
        prevent_initial_call=true,
    ) do _, _, _
        bid = pushed_button(callback_context())
        if bid == "open-load-modal-button"
            names = _list_saves()
            opts  = [Dict("label"=>n, "value"=>n) for n in names]
            return true, opts
        end
        return false, no_update()
    end

    # File selected in load dropdown → fill manual input
    callback!(app,
        Output("load-state-filename-id",  "value"),
        Input("load-modal-file-dropdown", "value"),
        prevent_initial_call=true,
    ) do selected
        isnothing(selected) && return no_update()
        return selected
    end

    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output( "save-options-diagram-success",     "is_open"     ),
        Input(  "save-state-diagram-button",        "n_clicks"    ),

        State(  "save-state-filename-id",           "value"       ),
        State(  "database-dropdown",                "value"       ),
        
        State(  "diagram-dropdown",                 "value"       ),
        State(  "mb-cpx-switch",                    "value"       ),
        State(  "limit-ca-opx-id",                  "value"       ),
        State(  "ca-opx-val-id",                    "value"       ),

        State(  "tepm-dropdown",                    "value"       ),
        State(  "kds-dropdown",                     "value"       ),
        State(  "zrsat-dropdown",                   "value"       ),
        State(  "ssat-dropdown",                    "value"       ),
        State(  "P2O5sat-dropdown",                 "value"       ),

        State(  "pt-x-table",                       "data"        ),
        State(  "pmin-id",                          "value"       ),
        State(  "pmax-id",                          "value"       ),
        State(  "tmin-id",                          "value"       ),
        State(  "tmax-id",                          "value"       ),
        State(  "fixed-pressure-val-id",            "value"       ),
        State(  "fixed-temperature-val-id",         "value"       ),

        State(  "gsub-id",                          "value"       ),
        State(  "refinement-dropdown",              "value"       ),
        State(  "refinement-levels",                "value"       ),

        State(  "buffer-dropdown",                  "value"       ),
        State(  "solver-dropdown",                  "value"       ),
        State(  "optimizer-dropdown",               "value"       ),
        State(  "boost-mode-dropdown",              "value"       ),
        State(  "verbose-dropdown",                 "value"       ),
        State(  "scp-dropdown",                     "value"       ),

        State(  "test-dropdown",                    "value"       ),
        State(  "test-2-dropdown",                  "value"       ),
        State(  "buffer-1-mul-id",                  "value"       ),
        State(  "buffer-2-mul-id",                  "value"       ),

        State(  "test-te-dropdown",                 "value"       ),
        State(  "test-2-te-dropdown",               "value"       ),

        State(  "watsat-dropdown",                  "value"       ),
        State(  "watsat-val-id",                    "value"       ),

        State(  "phase-selection",                  "value"       ),
        State(  "pure-phase-selection",              "value"       ),
        State(  "preset-dropdown",                  "value"       ),
        State(  "pressure-unit-dropdown",           "value"       ),
        State(  "select-bulk-unit",                 "value"       ),
        State(  "table-bulk-rock",                  "data"        ),
        State(  "table-2-bulk-rock",                "data"        ),
        State(  "table-te-rock",                    "data"        ),
        State(  "table-te-2-rock",                  "data"        ),

        State(  "dataset-dropdown",                 "value"       ),
        State(  "sas-dropdown",                     "value"       ),
        State(  "wf-id",                            "value"       ),
        State(  "seismic-cor-dropdown",             "value"       ),
        State(  "aspect-ratio-id",                  "value"       ),
        State(  "seismic-water-dropdown",           "value"       ),
        State(  "shallow-cor-dropdown",             "value"       ),
        State(  "fluid-as-melt-dropdown",           "value"       ),
        State(  "anelastic-cor-dropdown",           "value"       ),
        State(  "mumu-oxide1-dropdown",             "value"       ),
        State(  "mumu-oxide2-dropdown",             "value"       ),
        State(  "mumu-oxide1-min-id",               "value"       ),
        State(  "mumu-oxide1-max-id",               "value"       ),
        State(  "mumu-oxide2-min-id",               "value"       ),
        State(  "mumu-oxide2-max-id",               "value"       ),
        State(  "mumu-mu1-min-id",                  "value"       ),
        State(  "mumu-mu1-max-id",                  "value"       ),
        State(  "mumu-mu2-min-id",                  "value"       ),
        State(  "mumu-mu2-max-id",                  "value"       ),
        State(  "sec-p1-id",                        "value"       ),
        State(  "sec-t1-id",                        "value"       ),
        State(  "sec-p2-id",                        "value"       ),
        State(  "sec-t2-id",                        "value"       ),
        State(  "sec-search-pmin-id",               "value"       ),
        State(  "sec-search-pmax-id",               "value"       ),
        State(  "sec-search-tmin-id",               "value"       ),
        State(  "sec-search-tmax-id",               "value"       ),
        State(  "sec-range-mode-id",                "value"       ),
        State(  "sec-xmin-id",                      "value"       ),
        State(  "sec-xmax-id",                      "value"       ),
        State(  "sec-ymin-id",                      "value"       ),
        State(  "sec-ymax-id",                      "value"       ),
        State(  "fields-dropdown",                  "value"       ),
        State(  "colormaps_cross",                  "value"       ),
        State(  "reverse-colormap",                 "value"       ),
        State(  "set-min-white",                    "value"       ),
        State(  "o18-dropdown",                     "value"       ),
        State(  "o18-delta-id",                     "value"       ),
        State(  "o18-delta2-id",                    "value"       ),
        State(  "o18-anchor-id",                    "value"       ),
        State(  "o18-anchor-delta-id",              "value"       ),
        State(  "o18-melt-dropdown",                "value"       ),
        State(  "o18-unmapped-dropdown",            "value"       ),
        State(  "o18-tmax-id",                      "value"       ),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do click, filename,

        database, diagram_type, mb_cpx, limit_ca_opx, ca_opx_val,
        tepm, kds_dtb, zrsat_dtb, ssat_dtb, P2O5sat_dtb,
        ptx_table,
        pmin, pmax, tmin, tmax, pfix, tfix,
        grid_sub, refinement, refinement_level,
        buffer, solver, optimizer, boost, verbose, scp,
        test, test2,
        buffer1, buffer2,
        te_test, te_test2,
        watsat, watsat_val,
        ss_selection, pp_selection, preset,
        pressure_unit, bulk_unit, bulk_table, bulk_table2, te_table, te_table2,
        dataset, sas, wf, seismic_cor, aspect_ratio, seismic_water, shallow_cor, fluid_as_melt, anelastic_cor,
        mumu_oxide1, mumu_oxide2, mumu_ox1_min, mumu_ox1_max, mumu_ox2_min, mumu_ox2_max,
        mumu_mu1_min, mumu_mu1_max, mumu_mu2_min, mumu_mu2_max,
        sec_p1, sec_t1, sec_p2, sec_t2,
        sec_search_pmin, sec_search_pmax, sec_search_tmin, sec_search_tmax,
        sec_range_mode, sec_xmin, sec_xmax, sec_ymin, sec_ymax,
        fields, colormap, reverse_cmap, set_min_white,
        o18, o18_delta, o18_delta2, o18_anchor, o18_anchor_delta, o18_melt, o18_unmapped, o18_tmax

        global db, dbte

        base_path = state_base_path(filename)
        if isnothing(base_path)
            println("Cannot save state: invalid file name \"$(filename)\" (must be non-empty, without path separators)")
            return false
        end
        mkpath(state_dir())

        file_pd         = base_path * "_phase_diagram.jld2"
        file_pd_data    = base_path * "_phase_diagram_data.jld2"
        file            = base_path * "_options.jld2"

        ss_selection    = to_str_vec(ss_selection)
        pp_selection    = to_str_vec(pp_selection)
        ptx_table       = state_plain_rows(ptx_table)
        bulk_table      = state_plain_rows(bulk_table)
        bulk_table2     = state_plain_rows(bulk_table2)
        te_table        = state_plain_rows(te_table)
        te_table2       = state_plain_rows(te_table2)
        pressure_unit   = pressure_unit == "gpa" ? "gpa" : "kbar"

        println("Saving phase diagram options..."); t0 = time()
        @save file db dbte database diagram_type mb_cpx limit_ca_opx ca_opx_val tepm kds_dtb zrsat_dtb ssat_dtb P2O5sat_dtb ptx_table pmin pmax tmin tmax pfix tfix grid_sub refinement refinement_level buffer solver optimizer boost verbose scp test test2 buffer1 buffer2 te_test te_test2 watsat watsat_val ss_selection pp_selection preset pressure_unit bulk_unit bulk_table bulk_table2 te_table te_table2 dataset sas wf seismic_cor aspect_ratio seismic_water shallow_cor fluid_as_melt anelastic_cor mumu_oxide1 mumu_oxide2 mumu_ox1_min mumu_ox1_max mumu_ox2_min mumu_ox2_max mumu_mu1_min mumu_mu1_max mumu_mu2_min mumu_mu2_max sec_p1 sec_t1 sec_p2 sec_t2 sec_search_pmin sec_search_pmax sec_search_tmin sec_search_tmax sec_range_mode sec_xmin sec_xmax sec_ymin sec_ymax fields colormap reverse_cmap set_min_white o18 o18_delta o18_delta2 o18_anchor o18_anchor_delta o18_melt o18_unmapped o18_tmax
        println("Saved phase diagram options in $(round(time()-t0, digits=3)) seconds");

        field_list = [n for n in STATE_DIAGRAM_FIELDS if isdefined(MAGEMinApp, Symbol(n))]

        if isempty(field_list)
            rm(file_pd;      force = true)
            rm(file_pd_data; force = true)
        else
            println("Saving phase diagram data (can take a while 1-5 Go)..."); t0 = time()
            jldopen(file_pd, "w") do f
                for n in field_list
                    f[n] = getfield(MAGEMinApp, Symbol(n))
                end
            end
            @save file_pd_data field_list
            println("Saved phase diagram data in $(round(time()-t0, digits=3)) seconds");
        end

        println("saved in: $(abspath(state_dir()))/")

        return "success"
    end

    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output( "load-options-diagram-success",     "is_open"      ),
        Output( "load-options-diagram-failed",      "is_open"      ),

        Output(  "database-dropdown",                "value"       ),
        
        Output(  "diagram-dropdown",                 "value"       ),
        Output(  "mb-cpx-switch",                    "value"       ),
        Output(  "limit-ca-opx-id",                  "value"       ),
        Output(  "ca-opx-val-id",                    "value"       ),

        Output(  "tepm-dropdown",                    "value"       ),
        Output(  "kds-dropdown-trigger",             "value"       ),
        Output(  "zrsat-dropdown",                   "value"       ),
        Output(  "ssat-dropdown",                    "value"       ),
        Output(  "P2O5sat-dropdown",                 "value"       ),

        Output(  "pmin-id",                          "value"       ),
        Output(  "pmax-id",                          "value"       ),
        Output(  "tmin-id",                          "value"       ),
        Output(  "tmax-id",                          "value"       ),
        Output(  "fixed-pressure-val-id",            "value"       ),
        Output(  "fixed-temperature-val-id",         "value"       ),

        Output(  "gsub-id",                          "value"       ),
        Output(  "refinement-dropdown",              "value"       ),
        Output(  "refinement-levels",                "value"       ),

        Output(  "buffer-dropdown",                  "value"       ),
        Output(  "boost-mode-dropdown",              "value"       ),
        Output(  "verbose-dropdown",                 "value"       ),
        Output(  "scp-dropdown",                     "value"       ),

        Output(  "buffer-1-mul-id",                  "value"       ),
        Output(  "buffer-2-mul-id",                  "value"       ),

        Output(  "watsat-dropdown",                  "value"       ),
        Output(  "watsat-val-id",                    "value"       ),
        Output(  "load-state-id",                    "value"       ),

        Output(  "pressure-range-label-id",          "children"    ),
        Output(  "fixed-pressure-label-id",          "children"    ),
        Output(  "optimizer-dropdown",               "value"       ),

        Input(   "load-state-diagram-button",        "n_clicks"    ),
        Input(   "pressure-unit-dropdown",           "value"       ),
        State(   "load-state-filename-id",           "value"       ),
        State(   "load-state-id",                    "value"       ),
        State(   "pmin-id",                          "value"       ),
        State(   "pmax-id",                          "value"       ),
        State(   "fixed-pressure-val-id",            "value"       ),
        State(   "pressure-unit-prev",               "children"    ),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do click, pressure_unit, filename, state_id, pmin_cur, pmax_cur, fixp_cur, pressure_unit_prev

        bid = pushed_button( callback_context() )

        if bid == "pressure-unit-dropdown"
            # rescale the pressure-related input fields when the display unit toggles, leaving
            # everything else (and the underlying kbar values used for computation) untouched
            global use_GPa
            was_gpa     = (pressure_unit_prev == "gpa")
            use_GPa[1]  = (pressure_unit == "gpa")

            out = Any[no_update() for _ = 1:33]
            if was_gpa != use_GPa[1]
                factor   = use_GPa[1] ? (1.0/10.0) : 10.0
                pmin_cur isa Number && (out[13] = round(pmin_cur * factor, digits=10))
                pmax_cur isa Number && (out[14] = round(pmax_cur * factor, digits=10))
                fixp_cur isa Number && (out[17] = round(fixp_cur * factor, digits=10))
            end

            unit    = pressure_unit_label()
            out[31] = "Pressure [$unit]"
            out[32] = "Fixed pressure [$unit]"

            return Tuple(out)
        end

        failed_out    = Any[no_update() for _ = 1:33]
        failed_out[1] = ""
        failed_out[2] = "failed"

        file = state_options_file(filename)
        if isnothing(file)
            println("Cannot load state: no saved state named \"$(filename)\" in $(abspath(state_dir()))")
            return Tuple(failed_out)
        end

        global db, dbte
        local opts
        try
            opts = state_read(file, "db", "dbte", "database", "diagram_type", "mb_cpx", "limit_ca_opx", "ca_opx_val", "tepm", "kds_dtb", "zrsat_dtb", "ssat_dtb", "P2O5sat_dtb",
                                    "pmin", "pmax", "tmin", "tmax", "pfix", "tfix", "grid_sub", "refinement", "refinement_level", "buffer", "boost", "verbose", "scp",
                                    "buffer1", "buffer2", "watsat", "watsat_val", "ss_selection", "pp_selection", "preset", "pressure_unit", "optimizer";
                                    optional = ("ss_selection", "pp_selection", "preset", "pressure_unit", "optimizer"))
        catch e
            println("Failed to read saved state options from $file: ", sprint(showerror, e))
            return Tuple(failed_out)
        end

        db_s, dbte_s, database, diagram_type, mb_cpx, limit_ca_opx, ca_opx_val, tepm, kds_dtb, zrsat_dtb, ssat_dtb, P2O5sat_dtb,
        pmin, pmax, tmin, tmax, pfix, tfix, grid_sub, refinement, refinement_level, buffer, boost, verbose, scp,
        buffer1, buffer2, watsat, watsat_val, ss_selection, pp_selection, preset, saved_unit, optimizer = opts

        state_pending_dataset[] = (database = database, dataset = first(state_read(file, "dataset"; optional = ("dataset",))))

        global infos, layout, data, data_plot, data_reaction, iso_show, n_lbl, data_isopleth, data_isopleth_out, Out_XY, Hash_XY, Out_TE_XY, all_TE_ph, Out_O18_XY, all_O18_ph, n_phase_XY, addedRefinementLvl, pChip_wat, pChip_T, loaded_state_has_diagram

        base_path       = state_base_path(filename)
        file_pd         = base_path * "_phase_diagram.jld2"
        file_pd_data    = base_path * "_phase_diagram_data.jld2"
        loaded          = Dict{String,Any}()
        if isfile(file_pd) && isfile(file_pd_data)
            try
                println("Loading phase diagram..."); t0 = time()
                field_list = filter(in(STATE_DIAGRAM_FIELDS), String.(something(state_read(file_pd_data, "field_list")[1], String[])))
                jldopen(file_pd, "r") do f
                    for n in field_list
                        haskey(f, n) && (loaded[n] = f[n])
                    end
                end
                println("Loaded phase diagram in $(round(time()-t0, digits=3)) seconds")
            catch e
                println("failed to load the phase diagram data: ", sprint(showerror, e))
                empty!(loaded)
            end
        end

        for (n, v) in loaded
            Core.eval(MAGEMinApp, Expr(:(=), Symbol(n), QuoteNode(v)))
        end
        loaded_state_has_diagram = all(k -> haskey(loaded, k), ("data", "Out_XY", "Hash_XY", "data_plot", "layout", "data_isopleth", "n_phase_XY", "addedRefinementLvl"))

        db, dbte = db_s, dbte_s

        if !isnothing(ss_selection)
            AppData.phase_selection_cache[1][database] = Dict{String,Any}("ss" => to_str_vec(ss_selection), "pp" => to_str_vec(pp_selection))
        end
        if !isnothing(preset) && haskey(AppData.phase_selection_cache[1], database)
            AppData.phase_selection_cache[1][database]["preset"] = preset
        end

        global use_GPa
        use_GPa[1] = (pressure_unit == "gpa")
        to_disp(v) = v isa Number ? display_pressure(state_pressure_kbar(v, saved_unit)) : v

        state_id *= -1.0
        return "success", "", database, diagram_type, mb_cpx, limit_ca_opx, ca_opx_val, tepm, kds_dtb, zrsat_dtb, ssat_dtb, P2O5sat_dtb, to_disp(pmin), to_disp(pmax), tmin, tmax, to_disp(pfix), tfix, grid_sub, refinement, refinement_level, buffer, boost, verbose, scp, buffer1, buffer2, watsat, watsat_val, state_id, no_update(), no_update(), optimizer == "ns" ? "ns" : "nlopt"
    end

    callback!(
        app,
        Output("sas-dropdown",                  "value"),
        Output("wf-id",                         "value"),
        Output("seismic-cor-dropdown",          "value"),
        Output("aspect-ratio-id",               "value"),
        Output("seismic-water-dropdown",        "value"),
        Output("shallow-cor-dropdown",          "value"),
        Output("fluid-as-melt-dropdown",        "value"),
        Output("anelastic-cor-dropdown",        "value"),
        Output("mumu-oxide1-dropdown",          "value"),
        Output("mumu-oxide2-dropdown",          "value"),
        Output("mumu-oxide1-min-id",            "value"),
        Output("mumu-oxide1-max-id",            "value"),
        Output("mumu-oxide2-min-id",            "value"),
        Output("mumu-oxide2-max-id",            "value"),
        Output("fields-dropdown",               "value"),
        Output("colormaps_cross",               "value"),
        Output("reverse-colormap",              "value"),
        Output("set-min-white",                 "value"),
        Output("o18-dropdown",                  "value"),
        Output("o18-delta-id",                  "value"),
        Output("o18-delta2-id",                 "value"),
        Output("o18-anchor-id",                 "value"),
        Output("o18-anchor-delta-id",           "value"),
        Output("o18-melt-dropdown",             "value"),
        Output("o18-unmapped-dropdown",         "value"),
        Output("o18-tmax-id",                   "value"),

        Input(  "load-state-diagram-button",    "n_clicks"),
        State(  "load-state-filename-id",       "value"),

        prevent_initial_call = true,
    ) do n_clicks, filename

        file = state_options_file(filename)
        isnothing(file) && return ntuple(_ -> no_update(), 26)

        extra = Dict(zip(STATE_EXTRA_FIELDS, state_read(file, STATE_EXTRA_FIELDS...; optional = STATE_EXTRA_FIELDS)))
        pick(k) = isnothing(extra[k]) ? no_update() : extra[k]

        return pick("sas"), pick("wf"), pick("seismic_cor"), pick("aspect_ratio"), pick("seismic_water"), pick("shallow_cor"),
               pick("fluid_as_melt"), pick("anelastic_cor"), pick("mumu_oxide1"), pick("mumu_oxide2"),
               pick("mumu_ox1_min"), pick("mumu_ox1_max"), pick("mumu_ox2_min"), pick("mumu_ox2_max"),
               pick("fields"), pick("colormap"), pick("reverse_cmap"), pick("set_min_white"),
               pick("o18"), pick("o18_delta"), pick("o18_delta2"), pick("o18_anchor"), pick("o18_anchor_delta"), pick("o18_melt"), pick("o18_unmapped"), pick("o18_tmax")
    end

    # update the dictionary of phase_selection_options
    callback!(
        app,
        Output("phase-selection","options"),
        Output("phase-selection","value"),
        Output("pure-phase-selection","options"),
        Output("pure-phase-selection","value"),
        Output("dataset-dropdown","options"),
        Output("dataset-dropdown","value"),
        Output("dataset-display-id", "style"),
        Output("preset-dropdown-container", "style"),
        Output("preset-dropdown",           "value"),

        Input("database-dropdown","value"),
        Input("mineral-naming-dropdown","value"),
        Input("load-state-id","value"),
        Input("preset-dropdown","value"),

        State("phase-selection","value"),
        State("pure-phase-selection","value"),
        State("dataset-dropdown","value"),

        prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do dtb, warr_naming, _load_state_id, preset, current_ss_selection, current_pp_selection, current_dataset
        global use_warr_names
        use_warr_names[1] = (warr_naming == "warr")

        bid = pushed_button( callback_context() )

        if has_dataset_choice(dtb)
            style   = Dict("display" => "block")
        else
            style  = Dict("display" => "none")
        end
        db_in       = retrieve_solution_phase_information(dtb)
        ss_fname_lu = Dict(s.ss_name => s.ss_fName for s in db_in.data_ss)

        # this is the phase selection part for the database when compute a diagram
        phase_selection_options = [Dict(    "label"     => " "*display_ph_name_tagged(i, ss_fname_lu),
                                            "value"     => i )
                                                for i in db_in.ss_name ]

        # this is the phase selection part for the database when compute a diagram
        pp_all  = db_in.data_pp
        pp_disp = setdiff(pp_all, AppData.hidden_pp)

        pure_phase_selection_options = [Dict(    "label"     => " "*display_ph_name(i),
                                                 "value"     => i )
                                                for i in pp_disp ]

        # remember the (de)activated phases per database, so switching databases (or
        # reloading the page) restores the last selection made for that database
        cache = AppData.phase_selection_cache[1]

        preset_style = dtb == "all" ? Dict("display" => "block") : Dict("display" => "none")

        if bid == "database-dropdown" || bid == "" || bid == "load-state-id"
            # bid == "" happens on initial load / page reload, and "load-state-id" fires
            # right after a saved state is loaded: restore from cache in both cases too,
            # instead of always falling back to "all phases"
            if haskey(cache, dtb)
                saved                       = cache[dtb]
                phase_selection_value       = intersect(saved["ss"], db_in.ss_name)
                pure_phase_selection_value  = intersect(saved["pp"], pp_disp)
                isempty(phase_selection_value)      && (phase_selection_value      = db_in.ss_name)
                isempty(pure_phase_selection_value) && (pure_phase_selection_value = pp_disp)
            else
                phase_selection_value       = db_in.ss_name
                pure_phase_selection_value  = pp_disp
            end
            if bid == "load-state-id" && haskey(cache, dtb) && haskey(cache[dtb], "preset")
                preset_value_out = cache[dtb]["preset"]
            else
                preset_value_out = "none"
            end
        elseif bid == "preset-dropdown"
            if isnothing(preset) || preset == "none"
                phase_selection_value       = db_in.ss_name
                pure_phase_selection_value  = pp_disp
            else
                phase_selection_value       = preset_ss_selection(preset, db_in.ss_name)
                pure_phase_selection_value  = preset_pp_selection(preset, pp_disp)
                isempty(pure_phase_selection_value) && (pure_phase_selection_value = pp_disp)
            end
            preset_value_out = no_update()
        else
            # unrelated trigger (e.g. mineral naming convention): leave the current
            # phase selection untouched instead of resetting it to "all phases"
            phase_selection_value       = intersect(to_str_vec(current_ss_selection), db_in.ss_name)
            pure_phase_selection_value  = intersect(to_str_vec(current_pp_selection), pp_disp)
            isempty(phase_selection_value)      && (phase_selection_value      = db_in.ss_name)
            isempty(pure_phase_selection_value) && (pure_phase_selection_value = pp_disp)
            preset_value_out = no_update()
        end


        dataset_options = [Dict(    "label"     => "ds$(d)",
                                    "value"     => d )
                                for d in unique(db_in.dataset_opt) ]
        pend = state_pending_dataset[]
        if !isnothing(pend) && bid == "database-dropdown" && pend.database != dtb
            state_pending_dataset[] = nothing
            pend = nothing
        end
        if !isnothing(pend) && pend.database == dtb && bid in ("database-dropdown", "load-state-id") &&
           !isnothing(pend.dataset) && pend.dataset in db_in.dataset_opt
            dataset_value = pend.dataset
        else
            dataset_value = keep_dataset(bid in ("database-dropdown", ""), current_dataset, db_in)
        end


        return phase_selection_options, phase_selection_value, pure_phase_selection_options, pure_phase_selection_value, dataset_options, dataset_value, style, preset_style, preset_value_out
    end

    callback!(
        app,
        Output("alert-bulk-oxide-coverage", "is_open"),
        Output("alert-bulk-oxide-coverage", "color"),
        Output("alert-bulk-oxide-coverage", "children"),

        Input("database-dropdown","value"),
        Input("phase-selection","value"),
        Input("pure-phase-selection","value"),
        Input("table-bulk-rock","data"),

        prevent_initial_call = false,
    ) do dtb, ss_selected, pp_selected, bulk_data
        dtb != "all" && return false, "success", ""
        color, msg = bulk_oxide_coverage_status(bulk_data, ss_selected, pp_selected)
        return true, color, msg
    end

    callback!(
        app,
        Output("alert-ds62-placeholder", "is_open"),
        Output("alert-ds62-placeholder", "children"),

        Input("database-dropdown","value"),
        Input("dataset-dropdown","value"),
        Input("phase-selection","value"),

        prevent_initial_call = false,
    ) do dtb, dataset, ss_selected
        return ds62_placeholder_alert(dtb, dataset, ss_selected)
    end

    # persist phase (de)selection into the per-database cache as soon as the user
    # (de)activates a phase, so a page reload can restore it (not only a database switch)
    callback!(
        app,
        Output("phase-selection-cache-store", "data"),
        Input("phase-selection","value"),
        Input("pure-phase-selection","value"),
        State("database-dropdown","value"),
        prevent_initial_call = true,
    ) do ss_val, pp_val, dtb
        AppData.phase_selection_cache[1][dtb] = Dict{String,Any}("ss" => to_str_vec(ss_val), "pp" => to_str_vec(pp_val))
        return no_update()
    end

    


    # show the optimizer choice for the legacy solver with the databases that have a nullspace optimizer
    callback!(
        app,
        Output("display-optimizer-id",  "style"),
        Input("solver-dropdown",        "value"),
        Input("database-dropdown",      "value"),
        prevent_initial_call = true,
    ) do solver, dtb

        if solver == "lp" && has_ns_optimizer(dtb)
            return Dict("display" => "block")
        end
        return Dict("display" => "none")
    end

    # update available options
    callback!(
        app,
        Output("solver-dropdown",       "value"),
        Input("boost-mode-dropdown",    "value"),
        Input("scp-dropdown",           "value"),
        Input("load-state-diagram-button", "n_clicks"),
        State("load-state-filename-id", "value"),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do boost, scp, n_clicks_load, filename

        bid         = pushed_button( callback_context() )

        if bid == "load-state-diagram-button"
            file = state_options_file(filename)
            isnothing(file) && return no_update()
            solver_s = state_read(file, "solver"; optional = ("solver",))[1]
            return solver_s in ("pge", "lp", "hyb") ? solver_s : no_update()
        end

        if bid == "boost-mode-dropdown"
            if boost == true
                solver_opt    = "lp"
            else
                return no_update()
            end
        elseif bid == "scp-dropdown"
            if scp == 1
                solver_opt    = "lp"
            else
                if boost == true
                    solver_opt    = "lp"
                else
                    solver_opt    = "hyb"
                end
            end
        end
      
        return solver_opt
    end


    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output("ss-dropdown",       "options"),
        Output("ss-dropdown",       "value"),
        Output("calc-1-id",         "style"),
        Output("calc-1-sf-id",      "style"),
        Output("calc-1-ox-id",      "style"),
        Output("em-1-id",           "style"),
        Output("ox-1-id",           "style"),
        Output("ss-1-id",           "style"),
        Output("of-1-id",           "style"),
        Output("other-1-id",        "style"),
        Output("sys-unit-isopleth-id","style"),
        Output("rm-exfluid-isopleth-id","style"),

        Input("trigger-update-ss-list",    "value"),
        Input("phase-dropdown",            "value"),
        Input("other-dropdown",            "value"),
        Input("mineral-naming-dropdown",   "value"),
        State("ss-dropdown",               "value"),
        State("database-dropdown",         "value"),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do pd_update, phase, other, warr_naming, ph, dtb
        global use_warr_names
        use_warr_names[1] = (warr_naming == "warr")

        if !@isdefined(phase_infos)
            return no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
        end

        bid         = pushed_button( callback_context() )

        pp          = phase_infos.act_pp
        ss          = phase_infos.act_ss
        n_pp        = length(pp)
        n_ss        = length(ss)

        if phase == "of" || phase == "o18"
            style_ph    = Dict("display" => "none")
            style_em    = Dict("display" => "none")
            style_ox    = Dict("display" => "none")
            style_calc  = Dict("display" => "none")
            style_calc_sf = Dict("display" => "none")
            style_calc_ox = Dict("display" => "none")
            style_ot    = Dict("display" => "none")
            style_of    = Dict("display" => phase == "of" ? "block" : "none")
            style_sys   = Dict("display" => "none")
            style_rmf   = Dict("display" => "none")
            opts_ph     = []
            val         = nothing
        elseif phase == "ss"
            
            opts_ph     =  [Dict(   "label" => display_ph_name(ss[i]),
                                    "value" => ss[i] )
                                        for i=1:n_ss ]
            style_ot    = Dict("display" => "block")
            style_ph    = Dict("display" => "block")
            style_of    = Dict("display" => "none")
            style_sys   = Dict("display" => "block")
            style_rmf   = Dict("display" => "block")

            if other == "emMode"
                style_em    = Dict("display" => "block")
                style_rmf   = Dict("display" => "none")
            else
                style_em    = Dict("display" => "none")
            end

            if other == "oxComp"
                style_ox    = Dict("display" => "block")
                style_rmf   = Dict("display" => "none")
            else
                style_ox    = Dict("display" => "none")
            end

            if other == "calc"
                style_calc  = Dict("display" => "block")
                style_sys   = Dict("display" => "none")
            else
                style_calc  = Dict("display" => "none")
            end

            if other == "calc_sf"
                style_calc_sf   = Dict("display" => "block")
                style_sys       = Dict("display" => "none")
                style_rmf       = Dict("display" => "none")
                style_calc_ox   = Dict("display" => "none")
            else
                style_calc_sf   = Dict("display" => "none")
            end

            if other == "calc_ox"
                style_calc_ox   = Dict("display" => "block")
                style_sys       = Dict("display" => "block")
                style_rmf       = Dict("display" => "none")
                style_calc_sf   = Dict("display" => "none")
            else
                style_calc_ox   = Dict("display" => "none")
            end

            if other == "MgNum"
                style_sys   = Dict("display" => "none")
                style_rmf   = Dict("display" => "none")
            end

            if bid != "other-dropdown"
                val         = ss[1]
            else
                val         = ph
            end

        else

            opts_ph     =  [Dict(   "label" => display_ph_name(pp[i]),
                                    "value" => pp[i]  )
                                        for i=1:n_pp ]

            style_em    = Dict("display" => "none")
            style_ox    = Dict("display" => "none")
            style_ot    = Dict("display" => "none")
            style_calc  = Dict("display" => "none")
            style_calc_sf  = Dict("display" => "none")
            style_calc_ox  = Dict("display" => "none")
            style_ph    = Dict("display" => "block")
            style_of    = Dict("display" => "none")
            style_sys   = Dict("display" => "block")
            style_rmf   = Dict("display" => "block")

            if n_pp > 0
                val         = pp[1]
            else 
                val = ""
            end

        end

        return opts_ph, val, style_calc, style_calc_sf, style_calc_ox, style_em, style_ox, style_ph, style_of, style_ot, style_sys, style_rmf
    end



    # update the dictionary of the solution phases and end-members for isopleth
    callback!(
        app,
        Output("em-dropdown","options"),
        Output("em-dropdown","value"),
        Output("ox-dropdown","options"),
        Output("ox-dropdown","value"),
        Output("display-sites-id",  "value"),
       
        Input("database-dropdown","value"),
        Input("ss-dropdown","value"),
        Input("mineral-naming-dropdown","value"),
        State("phase-dropdown","value"),
        State("mb-cpx-switch","value"),

        prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do dtb, ph_name, warr_naming, ph, mbCpx
        global use_warr_names
        use_warr_names[1] = (warr_naming == "warr")
        bid  = pushed_button( callback_context() ) 
        if mbCpx == true
            aug = 1
        else
            aug = 0
        end

        if ph == "ss"

            db_in           = retrieve_solution_phase_information(dtb)
            ph_name         = get_ss_from_mineral(dtb, ph_name, aug, db_in.ss_name)
            ph_id           = findfirst(db_in.ss_name .== ph_name)
            if isnothing(ph_id)
                return "", "none", "", "SiO2", ""
            end
            sf_names        = join(db_in.data_ss[ph_id].ss_sf[2:end], " ")

            if ph_name in db_in.ss_name
                # id = get_ss_from_mineral(dtb, id, aug)
            else
                ph_name = db_in.ss_name[1]
            end

            ssid        = findall(db_in.ss_name .== ph_name)[1]
            n_em        = length(db_in.data_ss[ssid].ss_em)

            val         = "none"
            opts_em     =  [Dict(   "label" => display_ph_name(db_in.data_ss[ssid].ss_em[i]),
                                    "value" => db_in.data_ss[ssid].ss_em[i] )
                                        for i=1:n_em ]


            opts_ox     =   [Dict(  "label"     => db[(db.db .== dtb), :].oxide[1][i],
                                    "value"     => db[(db.db .== dtb), :].oxide[1][i])
                                        for i=1:length(db[(db.db .== dtb), :].oxide[1]) ]

            return opts_em, val, opts_ox, "SiO2", sf_names
        else
            return "", "", "", "", ""
        end

    end


    # callback to display trace element predictive model options
    callback!(
        app,
        Output("tepm-options-id",   "style"),
        Output("te-panel-id",       "style"),
        Output("zr-options-id",     "style"),
        Output("display-show-norm-id",   "style"),
        
        Input("tepm-dropdown",      "value"),
        Input("kds-dropdown",       "value"),
        Input("diagram-dropdown",   "value"),
        prevent_initial_call = true,
    ) do tepm, kds, diagType

        if tepm == "false" || diagType == "ptx3d"
            opt     = Dict("display" => "none")
            panel   = Dict("display" => "none")
            zr      = Dict("display" => "none")
            show_norm = Dict("display" => "none")

        elseif tepm == "true" 
            opt     = Dict("display" => "block" )    
            panel   = Dict("display" => "block" )
            zr      = Dict("display" => "block" )
            show_norm = Dict("display" => "block")
        end

        return opt, panel, zr, show_norm
    end

    callback!(
        app,
        Output("o18-options-id",    "style"),
        Output("o18-bulk-1-id",     "style"),
        Output("o18-bulk-2-id",     "style"),
        Input("o18-dropdown",       "value"),
        prevent_initial_call = false,
    ) do o18
        style = o18 == "true" ? Dict("display" => "block") : Dict("display" => "none")
        return style, style, style
    end

    callback!(
        app,
        Output("o18-anchor-delta-row",  "style"),
        Input("o18-anchor-id",          "value"),
        prevent_initial_call = false,
    ) do anchor
        return isempty(strip(something(anchor, ""))) ? Dict("display" => "none") : Dict("display" => "block")
    end


    # callback to display ca-orthopyroxene limiter
    callback!(
        app,
        Output("switch-opx-id", "style"),
        Input("database-dropdown", "value"),

        prevent_initial_call = true,
    ) do value
        # global db
        if value == "ig"
            style  = Dict("display" => "none")
        elseif value == "alk"
            style  = Dict("display" => "block")  
        else 
            style  = Dict("display" => "none")
        end
        return style
    end


    # callback to display clinopyroxene choice for the metabasite database
    callback!(
        app,
        Output("switch-cpx-id", "style"),
        Input("database-dropdown", "value"),

        prevent_initial_call = true,
    ) do value
        # global db
        if value == "mb" || value == "mbe"
            style  = Dict("display" => "block")
        else 
            style  = Dict("display" => "none")
        end
        return style
    end

    # callback to display clinopyroxene choice for the metabasite database
    callback!(
        app,
        Output("watsat-display-id", "style"),
        Input("watsat-dropdown", "value"),

        prevent_initial_call = true,
    ) do value
        # global db
        if value == "true"
            style  = Dict("display" => "block")
        else 
            style  = Dict("display" => "none")
        end
        return style
    end

    # callback to display the seismic-correction-dependent options (aspect ratio, anelastic correction, shallow correction, fluid as melt)
    callback!(
        app,
        Output("aspect-ratio-row-id",      "style"),
        Output("anelastic-toggle-row-id",  "style"),
        Output("shallow-cor-row-id",       "style"),
        Output("fluid-as-melt-row-id",     "style"),
        Input("seismic-cor-dropdown", "value"),

        prevent_initial_call = true,
    ) do seismic_cor
        if seismic_cor == true
            style  = Dict("display" => "block")
        else
            style  = Dict("display" => "none")
        end
        return style, style, style, style
    end

    # callback to display the anelastic model dropdown, only when both seismic correction and anelastic correction are enabled
    callback!(
        app,
        Output("anelastic-cor-row-id", "style"),
        Input("seismic-cor-dropdown",   "value"),
        Input("anelastic-cor-dropdown", "value"),

        prevent_initial_call = true,
    ) do seismic_cor, anelastic_cor
        if seismic_cor == true && anelastic_cor == true
            style  = Dict("display" => "block")
        else
            style  = Dict("display" => "none")
        end
        return style
    end

    # callback to display initial title of the pseudosections
    callback!(
        app,
        Output("title-id", "value"),
        Input("reset-title-button", "n_clicks"),
        Input("test-dropdown", "value"),
        Input("database-dropdown","value"),

        prevent_initial_call = true,
    ) do reset, test, dtb
        titles = db[(db.db .== dtb), :].title
        return (test isa Integer && 0 <= test < length(titles)) ? titles[test+1] : titles[1]
    end

    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("buffer-1-id", "style"),
        Output("buffer-2-id", "style"),
        Input("buffer-dropdown", "value"),

        prevent_initial_call = true,
    ) do value

        if value != "none"
            b1  = Dict("display" => "block")
            b2  = Dict("display" => "block")
        else
            b1  = Dict("display" => "none")
            b2  = Dict("display" => "none")
        end

        return b1, b2
    end

    # add new entry to the PT-X path definition
    callback!(app,
        Output( "pt-x-table",               "data"      ),
        Output( "pt-x-table",               "columns"   ),
        Output( "pressure-unit-dummy",      "children"  ),
        Output( "pressure-unit-prev",       "children"  ),
        Output( "upload-pt-path-success",   "is_open"   ),
        Output( "upload-pt-path-failed",    "is_open"   ),
        Output( "upload-pt-path-failed",    "children"  ),
        Input(  "add-ptx-row-button",       "n_clicks"  ),
        Input(  "load-state-diagram-button","n_clicks"  ),
        Input(  "pressure-unit-dropdown",   "value"     ),
        Input(  "upload-pt-path",           "contents"  ),
        State(  "upload-pt-path",           "filename"  ),
        State(  "load-state-filename-id",   "value"     ),
        State(  "pt-x-table",               "data"      ),
        State(  "pt-x-table",               "columns"   ),
        State(  "pressure-unit-prev",       "children"  ),

        prevent_initial_call = true,

        ) do n_clicks, n_clicks_load, pressure_unit, path_contents, path_filename, filename, data, columns, pressure_unit_prev

        bid  = pushed_button( callback_context() )

        if bid == "add-ptx-row-button"
            dataout = copy(data)

            if n_clicks > 0
                add = Dict(Symbol("col-1") => 7.5, Symbol("col-2") => 1000)
                push!(dataout,add)
            end

            return dataout, no_update(), no_update(), no_update(), no_update(), no_update(), no_update()

        elseif bid ==  "load-state-diagram-button"
            file = state_options_file(filename)
            isnothing(file) && return ntuple(_ -> no_update(), 7)

            rows, saved_unit = try
                ptx_table, saved_unit = state_read(file, "ptx_table", "pressure_unit"; optional = ("pressure_unit",))
                state_plain_rows(ptx_table), saved_unit
            catch
                return ntuple(_ -> no_update(), 7)
            end
            isnothing(rows) && return ntuple(_ -> no_update(), 7)

            cur_unit = pressure_unit == "gpa" ? "gpa" : "kbar"
            if something(saved_unit, "kbar") != cur_unit
                factor = cur_unit == "gpa" ? (1.0/10.0) : 10.0
                for row in rows
                    p = get(row, "col-1", nothing)
                    p isa Number && (row["col-1"] = round(p * factor, digits=10))
                end
            end

            return rows, no_update(), no_update(), no_update(), no_update(), no_update(), no_update()

        elseif bid == "pressure-unit-dropdown"
            global use_GPa
            was_gpa    = (pressure_unit_prev == "gpa")
            use_GPa[1] = (pressure_unit == "gpa")

            dataout    = copy(data)
            colsout    = copy(columns)

            if was_gpa != use_GPa[1]
                factor = use_GPa[1] ? (1.0/10.0) : 10.0
                for row in dataout
                    row[Symbol("col-1")] = round(row[Symbol("col-1")] * factor, digits=10)
                end
            end

            colsout[1][:name] = "P [$(pressure_unit_label())]"

            return dataout, colsout, pressure_unit, pressure_unit, no_update(), no_update(), no_update()

        elseif bid == "upload-pt-path"
            if !(path_contents isa Nothing)
                status, msg, rows = parse_path_csv(path_contents, path_filename,
                                                    Dict("P"=>"col-1", "T"=>"col-2"),
                                                    ["col-1", "col-2"])
                if status == 1
                    return rows, no_update(), no_update(), no_update(), true, false, ""
                else
                    return no_update(), no_update(), no_update(), no_update(), false, true, msg
                end
            end
        end
    end

    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("fixed-temperature-id", "style"),
        Output("fixed-pressure-id", "style"),
        Output("temperature-id", "style"),
        Output("pressure-id", "style"),
        Output("test-2-id", "style"),
        Output("table-2-id", "style"),
        Output("pt-x-id", "style"),
        Output("test-2-te-id", "style"),
        Output("table-2-te-id", "style"),
        Output("subsolsat-id", "style"),
        Output("event1-temperature-id", "style"),
        Output("event2-temperature-id", "style"),
        Output("display-refine-option-id", "style"),
        Output("display-refine-option-2-id", "style"),
        Output("mumu-setup-id", "style"),
        Output("mumu-oxide2-row-id", "style"),
        Output("mumu-mu2-row-id", "style"),
        Output("section-setup-id", "style"),
        Output("sec-corners-id", "style"),
        Output("gsub-row-id", "style"),
        Output("tepm-row-id", "style"),
        Output("pd3d-resolution-id", "style"),
        Output("display-boost-option-id", "style"),
        Input("diagram-dropdown", "value"),

        prevent_initial_call = true,
    ) do value

        if value == "px" || value == "vx"
            Tstyle  = Dict("display" => "block")
            Pstyle  = Dict("display" => "none")
            Ts      = Dict("display" => "none")
            Ps      = Dict("display" => "block")
            test2   = Dict("display" => "block")  
            table2  = Dict("display" => "block")  
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "block")  
            tabte2  = Dict("display" => "block")  
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "block")
            refine2 = Dict("display" => "block")
            mumu    = Dict("display" => "none")
        elseif value == "tx" || section_x_fixed_P(value)
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "block")
            Ts      = Dict("display" => "block")
            Ps      = Dict("display" => "none")
            test2   = Dict("display" => "block")  
            table2  = Dict("display" => "block") 
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "block")  
            tabte2  = Dict("display" => "block") 
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "block")
            refine2 = Dict("display" => "block")
            mumu    = Dict("display" => "none")
        elseif value == "pt" || value in SECTION_TYPES
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "none")
            Ts      = Dict("display" => "block")
            Ps      = Dict("display" => "block")
            test2   = Dict("display" => "none")  
            table2  = Dict("display" => "none")  
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "none")  
            tabte2  = Dict("display" => "none") 
            watsat  = Dict("display" => "block")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "block")
            refine2 = Dict("display" => "block")
            mumu    = Dict("display" => "none")
        elseif value == "ptx"
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "none")
            Ts      = Dict("display" => "none")
            Ps      = Dict("display" => "none")
            test2   = Dict("display" => "block")  
            table2  = Dict("display" => "block") 
            PTx     = Dict("display" => "block")
            testte2 = Dict("display" => "block")  
            tabte2  = Dict("display" => "block") 
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "block")
            refine2 = Dict("display" => "block")
            mumu    = Dict("display" => "none")
        elseif value == "tt"
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "block")
            Ts      = Dict("display" => "none")
            Ps      = Dict("display" => "none")
            test2   = Dict("display" => "none")  
            table2  = Dict("display" => "none") 
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "none")  
            tabte2  = Dict("display" => "none") 
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "block")
            T2      = Dict("display" => "block")
            refine  = Dict("display" => "block")  #was none, trying to refine TT diagrams now
            refine2 = Dict("display" => "block")  #was none, trying to refine TT diagrams now
            mumu    = Dict("display" => "none")
        elseif value == "mumu"
            Tstyle  = Dict("display" => "block")
            Pstyle  = Dict("display" => "block")
            Ts      = Dict("display" => "none")
            Ps      = Dict("display" => "none")
            test2   = Dict("display" => "none")
            table2  = Dict("display" => "none")
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "none")
            tabte2  = Dict("display" => "none")
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "block")
            refine2 = Dict("display" => "block")
            mumu    = Dict("display" => "block")
        elseif value == "pmu" || value == "tmu"
            Tstyle  = Dict("display" => value == "pmu" ? "block" : "none")
            Pstyle  = Dict("display" => value == "tmu" ? "block" : "none")
            Ts      = Dict("display" => value == "tmu" ? "block" : "none")
            Ps      = Dict("display" => value == "pmu" ? "block" : "none")
            test2   = Dict("display" => "none")
            table2  = Dict("display" => "none")
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "none")
            tabte2  = Dict("display" => "none")
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "block")
            refine2 = Dict("display" => "block")
            mumu    = Dict("display" => "block")
        elseif value == "ptx3d"
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "none")
            Ts      = Dict("display" => "block")
            Ps      = Dict("display" => "block")
            test2   = Dict("display" => "block")
            table2  = Dict("display" => "block")
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "none")
            tabte2  = Dict("display" => "none")
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "none")
            refine2 = Dict("display" => "none")
            mumu    = Dict("display" => "none")
        else
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "none")
            Ts      = Dict("display" => "none")
            Ps      = Dict("display" => "none")
            test2   = Dict("display" => "none")
            table2  = Dict("display" => "none")
            PTx     = Dict("display" => "none")
            testte2 = Dict("display" => "none")
            tabte2  = Dict("display" => "none")
            watsat  = Dict("display" => "none")
            T1      = Dict("display" => "none")
            T2      = Dict("display" => "none")
            refine  = Dict("display" => "none")
            refine2 = Dict("display" => "none")
            mumu    = Dict("display" => "none")
        end

        mumu2   = Dict("display" => value == "mumu" ? "block" : "none")
        section = Dict("display" => (value in SECTION_TYPES || value in SECTION_X_TYPES) ? "block" : "none")
        corners = Dict("display" => value in SECTION_TYPES ? "block" : "none")
        if value in SECTION_TYPES
            watsat  = Dict("display" => "none")
            Ts      = Dict("display" => "none")
            Ps      = Dict("display" => "none")
        end

        is3d    = value == "ptx3d"
        gsub    = Dict("display" => is3d ? "none"  : "block")
        tepmrow = Dict("display" => is3d ? "none"  : "block")
        res3d   = Dict("display" => is3d ? "block" : "none")

        return Tstyle, Pstyle, Ts, Ps, test2, table2, PTx, testte2, tabte2, watsat, T1, T2, refine, refine2, mumu, mumu2, mumu2, section, corners, gsub, tepmrow, res3d, refine
    end


    callback!(
        app,
        Output("mumu-oxide1-dropdown",     "options"),
        Output("mumu-oxide2-dropdown",     "options"),
        Output("table-bulk-rock",          "style_data_conditional"),

        Input("table-bulk-rock",           "data"),
        Input("mumu-oxide1-dropdown",      "value"),
        Input("mumu-oxide2-dropdown",      "value"),
        Input("diagram-dropdown",          "value"),

        prevent_initial_call = true,

    ) do bulk_data, ox1, ox2, diagType

        oxides  = [row["oxide"] for row in bulk_data]
        opts1   = [Dict("label" => ox, "value" => ox) for ox in oxides if ox != ox2 || diagType != "mumu"]
        opts2   = [Dict("label" => ox, "value" => ox) for ox in oxides if ox != ox1]

        style_cond = []
        if diagType in MU_TYPES
            for (i, row) in enumerate(bulk_data)
                if row["oxide"] == ox1 || (row["oxide"] == ox2 && diagType == "mumu")
                    push!(style_cond, Dict(
                        "if"                => Dict("row_index" => i-1, "column_id" => "fraction"),
                        "backgroundColor"   => "#e9ecef",
                        "color"             => "#6c757d",
                        "pointerEvents"     => "none",
                    ))
                end
            end
        end

        return opts1, opts2, style_cond
    end


    callback!(
        app,
        Output("mumu-mu1-min-id",              "value"),
        Output("mumu-mu1-max-id",              "value"),
        Output("mumu-mu2-min-id",              "value"),
        Output("mumu-mu2-max-id",              "value"),
        Output("mumu-bounds-warning",          "children"),
        Output("mumu-bounds-warning",          "is_open"),

        Input("compute-mumu-bounds-button",    "n_clicks"),
        Input("load-state-diagram-button",     "n_clicks"),

        State("load-state-filename-id",        "value"),
        State("table-bulk-rock",               "data"),
        State("mumu-oxide1-dropdown",          "value"),
        State("mumu-oxide2-dropdown",          "value"),
        State("mumu-oxide1-min-id",            "value"),
        State("mumu-oxide1-max-id",            "value"),
        State("mumu-oxide2-min-id",            "value"),
        State("mumu-oxide2-max-id",            "value"),
        State("fixed-pressure-val-id",         "value"),
        State("fixed-temperature-val-id",      "value"),
        State("database-dropdown",             "value"),
        State("buffer-dropdown",               "value"),
        State("solver-dropdown",               "value"),
        State("optimizer-dropdown",            "value"),
        State("select-bulk-unit",              "value"),
        State("diagram-dropdown",              "value"),
        State("pmin-id",                       "value"),
        State("pmax-id",                       "value"),
        State("tmin-id",                       "value"),
        State("tmax-id",                       "value"),

        prevent_initial_call = true,

    ) do n_clicks, n_clicks_load, filename, bulk_data, ox1, ox2, ox1_min, ox1_max, ox2_min, ox2_max, fixP, fixT, dtb, bufferType, solver, optimizer, sys_unit, diagType, pmin, pmax, tmin, tmax

        if state_load_triggered()
            file = state_options_file(filename)
            isnothing(file) && return ntuple(_ -> no_update(), 6)
            mu = state_read(file, "mumu_mu1_min", "mumu_mu1_max", "mumu_mu2_min", "mumu_mu2_max";
                            optional = ("mumu_mu1_min", "mumu_mu1_max", "mumu_mu2_min", "mumu_mu2_max"))
            return (Tuple(isnothing(v) ? no_update() : v for v in mu)..., no_update(), no_update())
        end

        oxi     = [row["oxide"] for row in bulk_data]
        bulk    = [Float64(row["fraction"] isa String ? parse(Float64, row["fraction"]) : row["fraction"]) for row in bulk_data]
        bulk  ./= sum(bulk)
        if sys_unit == 2
            bulk    = wt2mol(bulk, oxi)
            bulk  ./= sum(bulk)
        end

        idx1    = findfirst(oxi .== ox1)
        idx2    = findfirst(oxi .== ox2)
        fixP_kbar = to_kbar_pressure(Float64(fixP))

        if diagType == "pmu" || diagType == "tmu"
            n_s     = 5
            Pvec    = diagType == "pmu" ? collect(range(to_kbar_pressure(Float64(pmin)), to_kbar_pressure(Float64(pmax)), length = n_s)) : fill(fixP_kbar, n_s)
            Tvec    = diagType == "tmu" ? collect(range(Float64(tmin), Float64(tmax), length = n_s)) : fill(Float64(fixT), n_s)
            mu_bounds, statuses, ok = compute_mu_bounds_path(
                Pvec,               Tvec,
                bulk,               oxi,
                idx1,               Float64(ox1_min)/100.0,    Float64(ox1_max)/100.0,
                dtb,    bufferType, solver,
                -1,  0.0,        nothing,
                false,  "OFF",      0.0;
                optimizer = optimizer   )
            warn_msg, warn_open = ok ? ("", false) : ("$(count(!=(0), statuses)) / $(length(statuses)) pre-pass minimizations did not converge — bounds use the converged ones only and may be unreliable. Try narrower content bounds.", true)
            return round(mu_bounds[1],digits=2), round(mu_bounds[2],digits=2), no_update(), no_update(), warn_msg, warn_open
        end

        mu1_bounds, mu2_bounds, statuses, ok = compute_mumu_bounds(
            fixP_kbar,          Float64(fixT),
            bulk,               oxi,
            idx1,               idx2,
            Float64(ox1_min)/100.0,    Float64(ox1_max)/100.0,
            Float64(ox2_min)/100.0,    Float64(ox2_max)/100.0,
            dtb,    bufferType, solver,
            -1,  0.0,        nothing,
            false,  "OFF",      0.0;
            optimizer = optimizer   )

        if ok
            warn_msg, warn_open = "", false
        else
            warn_msg  = "One or more pre-pass minimizations did not converge (status=$(statuses)) — bounds shown may be unreliable. Try narrower content bounds."
            warn_open = true
        end

        return round(mu1_bounds[1],digits=2), round(mu1_bounds[2],digits=2), round(mu2_bounds[1],digits=2), round(mu2_bounds[2],digits=2), warn_msg, warn_open
    end


    callback!(
        app,
        Output("sec-p1-id",                     "value"),
        Output("sec-t1-id",                     "value"),
        Output("sec-p2-id",                     "value"),
        Output("sec-t2-id",                     "value"),
        Output("sec-p-unit-label-id",           "children"),
        Output("sec-search-pmin-id",            "value"),
        Output("sec-search-pmax-id",            "value"),
        Output("sec-search-tmin-id",            "value"),
        Output("sec-search-tmax-id",            "value"),
        Output("sec-search-p-label-id",         "children"),
        Output("sec-range-mode-id",             "value"),
        Output("sec-xmin-id",                   "value"),
        Output("sec-xmax-id",                   "value"),
        Output("sec-ymin-id",                   "value"),
        Output("sec-ymax-id",                   "value"),

        Input("load-state-diagram-button",      "n_clicks"),
        Input("pressure-unit-dropdown",         "value"),

        State("load-state-filename-id",         "value"),
        State("sec-p1-id",                      "value"),
        State("sec-p2-id",                      "value"),
        State("sec-search-pmin-id",             "value"),
        State("sec-search-pmax-id",             "value"),
        State("sec-xmin-id",                    "value"),
        State("sec-xmax-id",                    "value"),
        State("sec-ymin-id",                    "value"),
        State("sec-ymax-id",                    "value"),
        State("diagram-dropdown",               "value"),
        State("pressure-unit-prev",             "children"),

        prevent_initial_call = true,

    ) do n_clicks_load, pressure_unit, filename, p1_cur, p2_cur, spmin_cur, spmax_cur, xmin_cur, xmax_cur, ymin_cur, ymax_cur, diagType, pressure_unit_prev

        if state_load_triggered()
            file = state_options_file(filename)
            isnothing(file) && return ntuple(_ -> no_update(), 15)
            keys_sec = ("sec_p1", "sec_t1", "sec_p2", "sec_t2", "sec_search_pmin", "sec_search_pmax", "sec_search_tmin", "sec_search_tmax", "pressure_unit",
                        "sec_range_mode", "sec_xmin", "sec_xmax", "sec_ymin", "sec_ymax", "diagram_type")
            v = state_read(file, keys_sec...; optional = keys_sec)
            unit  = something(v[9], "kbar")
            pc(x) = isnothing(x) ? no_update() : round(display_pressure(state_pressure_kbar(x, unit)), digits = 10)
            tc(x) = isnothing(x) ? no_update() : x
            box   = (v[1], v[3], v[2], v[4])
            if all(x -> x isa Number, box)
                plo, phi = extrema(Float64.(box[1:2]))
                tlo, thi = extrema(Float64.(box[3:4]))
                box      = (plo, phi, tlo, thi)
            end
            ax    = string(something(v[15], "")) in SECTION_TYPES ? MAGEMin_C.SECTION_XY[Symbol(v[15])] : (:S, :V)
            mc(x, c) = c === :P ? pc(x) : tc(x)
            ul    = pressure_unit_label()
            mode  = isnothing(v[10]) ? "inscribed" : section_range_mode(v[10])
            return pc(box[1]), tc(box[3]), pc(box[2]), tc(box[4]), "Pressure [$ul]", pc(v[5]), pc(v[6]), tc(v[7]), tc(v[8]), "Pressure [$ul]",
                   mode, mc(v[11], ax[1]), mc(v[12], ax[1]), mc(v[13], ax[2]), mc(v[14], ax[2])
        end

        was_gpa = (pressure_unit_prev == "gpa")
        is_gpa  = (pressure_unit == "gpa")
        ax      = diagType in SECTION_TYPES ? MAGEMin_C.SECTION_XY[Symbol(diagType)] : (:S, :V)
        cur     = Any[p1_cur, p2_cur, spmin_cur, spmax_cur, xmin_cur, xmax_cur, ymin_cur, ymax_cur]
        isP     = Bool[true, true, true, true, ax[1] === :P, ax[1] === :P, ax[2] === :P, ax[2] === :P]
        out     = Any[no_update() for _ in 1:8]
        if was_gpa != is_gpa
            factor = is_gpa ? (1.0/10.0) : 10.0
            for k in 1:8
                isP[k] && cur[k] isa Number && (out[k] = round(cur[k] * factor, digits = 10))
            end
        end
        ul = is_gpa ? "GPa" : "kbar"
        return out[1], no_update(), out[2], no_update(), "Pressure [$ul]", out[3], out[4], no_update(), no_update(), "Pressure [$ul]",
               no_update(), out[5], out[6], out[7], out[8]
    end

    callback!(
        app,
        Output("sec-manual-id",         "style"),
        Output("sec-xaxis-label-id",    "children"),
        Output("sec-yaxis-label-id",    "children"),
        Input("sec-range-mode-id",      "value"),
        Input("diagram-dropdown",       "value"),
        Input("pressure-unit-dropdown", "value"),
    ) do mode, diagType, pressure_unit
        diagType in SECTION_TYPES || return Dict("display" => "none"), no_update(), no_update()
        ax      = MAGEMin_C.SECTION_XY[Symbol(diagType)]
        lbl(c)  = c === :P ? "Pressure [$(pressure_unit == "gpa" ? "GPa" : "kbar")]" : section_axis_title(c)
        return Dict("display" => section_range_mode(mode) == "manual" ? "block" : "none"), lbl(ax[1]), lbl(ax[2])
    end

    callback!(
        app,
        Output("sec-search-pmin-id",    "placeholder"),
        Output("sec-search-pmax-id",    "placeholder"),
        Output("sec-search-tmin-id",    "placeholder"),
        Output("sec-search-tmax-id",    "placeholder"),
        Input("sec-p1-id",              "value"),
        Input("sec-t1-id",              "value"),
        Input("sec-p2-id",              "value"),
        Input("sec-t2-id",              "value"),
        Input("pressure-unit-dropdown", "value"),
        Input("diagram-dropdown",       "value"),
        Input("pmin-id",                "value"),
        Input("pmax-id",                "value"),
        Input("tmin-id",                "value"),
        Input("tmax-id",                "value"),
        Input("fixed-pressure-val-id",  "value"),
        Input("fixed-temperature-val-id", "value"),
        Input("sec-range-mode-id",      "value"),
    ) do p1, t1, p2, t2, pressure_unit, diagType, pmin, pmax, tmin, tmax, fixP, fixT, mode
        tokbar(x) = pressure_unit == "gpa" ? Float64(x)*10.0 : Float64(x)
        todisp(x) = pressure_unit == "gpa" ? x/10.0 : x
        if section_x_fixed_P(diagType)
            any(x -> !(x isa Number), (fixP, tmin, tmax)) && return ntuple(_ -> no_update(), 4)
            Pc, Tc = (tokbar(fixP), tokbar(fixP)), (Float64(tmin), Float64(tmax))
        elseif diagType == "vx"
            any(x -> !(x isa Number), (fixT, pmin, pmax)) && return ntuple(_ -> no_update(), 4)
            Pc, Tc = (tokbar(pmin), tokbar(pmax)), (Float64(fixT), Float64(fixT))
        else
            any(x -> !(x isa Number), (p1, t1, p2, t2)) && return ntuple(_ -> no_update(), 4)
            Pc, Tc = (tokbar(p1), tokbar(p2)), (Float64(t1), Float64(t2))
        end
        sP, sT    = section_search_box(Pc, Tc; widen = diagType in SECTION_TYPES ? section_widen(mode) : 3.0)
        fmt(x)    = string(round(x, sigdigits = 4))
        return fmt(todisp(sP[1])), fmt(todisp(sP[2])), fmt(sT[1]), fmt(sT[2])
    end

    callback!(
        app,
        Output("sec-adv-collapse",  "is_open"),
        Input("sec-adv-btn",        "n_clicks"),
        State("sec-adv-collapse",   "is_open"),
        prevent_initial_call = true,
    ) do n, is_open
        return n > 0 ? (is_open == 0) : is_open
    end

    callback!(
        app,
        Output("section-ranges-text-id",        "children"),
        Output("section-ranges-warning",        "children"),
        Output("section-ranges-warning",        "is_open"),
        Output("section-image-graph-id",        "figure"),
        Output("section-image-wrap-id",         "style"),

        Input("compute-section-ranges-button",  "n_clicks"),
        Input("diagram-dropdown",               "value"),
        Input("sec-range-mode-id",              "value"),

        State("table-bulk-rock",                "data"),
        State("select-bulk-unit",               "value"),
        State("sec-p1-id",                      "value"),
        State("sec-t1-id",                      "value"),
        State("sec-p2-id",                      "value"),
        State("sec-t2-id",                      "value"),
        State("database-dropdown",              "value"),
        State("dataset-dropdown",               "value"),
        State("buffer-dropdown",                "value"),
        State("buffer-1-mul-id",                "value"),
        State("solver-dropdown",                "value"),
        State("optimizer-dropdown",             "value"),
        State("phase-selection",                "value"),
        State("pure-phase-selection",           "value"),
        State("mb-cpx-switch",                  "value"),
        State("limit-ca-opx-id",                "value"),
        State("ca-opx-val-id",                  "value"),
        State("table-2-bulk-rock",              "data"),
        State("buffer-2-mul-id",                "value"),
        State("fixed-pressure-val-id",          "value"),
        State("fixed-temperature-val-id",       "value"),
        State("pmin-id",                        "value"),
        State("pmax-id",                        "value"),
        State("tmin-id",                        "value"),
        State("tmax-id",                        "value"),
        State("sec-xmin-id",                    "value"),
        State("sec-xmax-id",                    "value"),
        State("sec-ymin-id",                    "value"),
        State("sec-ymax-id",                    "value"),
        State("sec-search-pmin-id",             "value"),
        State("sec-search-pmax-id",             "value"),
        State("sec-search-tmin-id",             "value"),
        State("sec-search-tmax-id",             "value"),

        prevent_initial_call = true,

    ) do n_clicks, diagType, mode, bulk_data, sys_unit, p1, t1, p2, t2, dtb, dataset, bufferType, bufferN, solver, optimizer, ph_selection, pure_ph_selection, cpx, limOpx, limOpxVal,
         bulk_data2, bufferN2, fixP, fixT, pmin, pmax, tmin, tmax, xmin, xmax, ymin, ymax, spmin, spmax, stmin, stmax

        hidden = Dict("display" => "none", "position" => "relative", "clear" => "both", "marginBottom" => 10)
        bid    = pushed_button(callback_context())
        bid == "diagram-dropdown" && return "", "", false, Dict(), hidden
        bid == "sec-range-mode-id" && (isnothing(n_clicks) || n_clicks == 0 || !(diagType in SECTION_TYPES)) && return ntuple(_ -> no_update(), 5)

        if diagType in SECTION_X_TYPES
            bulk_L, bulk_R, oxi = get_bulkrock_prop(bulk_data, bulk_data2; sys_unit = sys_unit)
            phase_selection = remove_phases(string_vec_diff(to_str_vec(ph_selection), to_str_vec(pure_ph_selection), dtb), dtb)
            bN1     = isnothing(bufferN)  ? 0.0 : Float64(bufferN)
            bN2     = isnothing(bufferN2) ? 0.0 : Float64(bufferN2)
            fixv    = section_x_fixed_P(diagType) ? to_kbar_pressure(Float64(fixP)) : Float64(fixT)
            bnd     = section_x_fixed_P(diagType) ? (Float64(tmin), Float64(tmax)) : (to_kbar_pressure(Float64(pmin)), to_kbar_pressure(Float64(pmax)))
            yr, ok  = section_x_ranges(diagType, fixv, bnd, bulk_L, bulk_R, bN1, bN2, oxi, dtb, bufferType, solver, phase_selection,
                                       cpx, limOpx, Float64(limOpxVal); optimizer = optimizer, dataset = dataset)
            ok || return "", "The bounds do not span a range (a corner minimization failed or equal values).", true, Dict(), hidden
            yt      = section_axis_title(section_x_prop(diagType))
            return "Composition [X0 -> X1]: 0 - 1;  $(yt): $(round(yr[1], sigdigits = 5)) - $(round(yr[2], sigdigits = 5))", "", false, Dict(), hidden
        end
        diagType in SECTION_TYPES || return "", "Select a section diagram (P-S, P-V, T-S, T-V, S-V, P-H, S-H, V-H, S-X, H-X or V-X) first.", true, Dict(), hidden
        any(x -> !(x isa Number), (p1, t1, p2, t2)) && return "", "Provide the pressure and temperature bounds of the box.", true, Dict(), hidden

        bulk_L, _, oxi  = get_bulkrock_prop(bulk_data, bulk_data; sys_unit = sys_unit)
        phase_selection = remove_phases(string_vec_diff(to_str_vec(ph_selection), to_str_vec(pure_ph_selection), dtb), dtb)
        Pc              = (to_kbar_pressure(Float64(p1)), to_kbar_pressure(Float64(p2)))
        Tc              = (Float64(t1), Float64(t2))
        bN              = isnothing(bufferN) ? 0.0 : Float64(bufferN)

        (Pc[2] > Pc[1] && Tc[2] > Tc[1]) || return "", "The box needs P max > P min and T max > T min.", true, Dict(), hidden
        mode            = section_range_mode(mode)

        numP(v)      = v isa Number ? to_kbar_pressure(Float64(v)) : nothing
        numT(v)      = v isa Number ? Float64(v) : nothing
        rx, ry, poly, ok = section_box_ranges(  diagType, Pc, Tc, bulk_L, oxi, dtb, bufferType, solver, bN, phase_selection,
                                                cpx, limOpx, Float64(limOpxVal); mode = mode, optimizer = optimizer, dataset = dataset,
                                                limits = (numP(spmin), numP(spmax), numT(stmin), numT(stmax)) )
        if mode == "manual"
            rx, ry, ok = section_manual_ranges(diagType, xmin, xmax, ymin, ymax)
            ok || return "", "Provide the manual ranges (min < max on both axes).", true, Dict(), hidden
        end
        ok || return "", "The image of the box is degenerate (boundary minimizations failed or the box is too small).", true, Dict(), hidden

        lim          = section_limits(Pc, Tc, (numP(spmin), numP(spmax), numT(stmin), numT(stmax)), mode)
        sxs, sys     = section_box_image(diagType, (lim[1], lim[2]), (lim[3], lim[4]), bulk_L, oxi, dtb, bufferType, solver, bN, phase_selection,
                                         cpx, limOpx, Float64(limOpxVal); optimizer = optimizer, dataset = dataset)

        xt, yt, _, _ = diagram_type(diagType, 0.0, 1.0, 0.0, 1.0, 0, 0, 0, 0)
        ax           = MAGEMin_C.SECTION_XY[Symbol(diagType)]
        dsp(v, c)    = c === :P ? display_pressure(v) : v
        fmt(r, c)    = "$(round(dsp(r[1], c), sigdigits = 5)) - $(round(dsp(r[2], c), sigdigits = 5))"
        px           = [dsp.(poly[1], ax[1]); dsp(poly[1][1], ax[1])]
        py           = [dsp.(poly[2], ax[2]); dsp(poly[2][1], ax[2])]
        bx           = dsp.([rx[1], rx[2], rx[2], rx[1], rx[1]], ax[1])
        by           = dsp.([ry[1], ry[1], ry[2], ry[2], ry[1]], ax[2])
        has_s        = length(sxs) >= 3
        qx           = has_s ? [dsp.(sxs, ax[1]); dsp(sxs[1], ax[1])] : Float64[]
        qy           = has_s ? [dsp.(sys, ax[2]); dsp(sys[1], ax[2])] : Float64[]
        function view(inner, outer)
            lo, hi = extrema(inner)
            sp     = hi - lo
            if !isempty(outer)
                olo, ohi = extrema(outer)
                lo, hi   = min(lo, max(olo, lo - 0.5*sp)), max(hi, min(ohi, hi + 0.5*sp))
            end
            d = 0.04*(hi - lo)
            return [lo - d, hi + d]
        end
        traces       = has_s ? [ scatter(x = qx, y = qy, mode = "lines", name = "reachable (search box)",
                                         line = attr(color = "#7f8c8d", width = 1.2, dash = "dot"), fill = "toself", fillcolor = "rgba(127,140,141,0.08)") ] : []
        fig          = plot([ traces...,
                              scatter(x = px, y = py, mode = "lines+markers", name = "image of the P-T box",
                                      line = attr(color = "#4a6fa5", width = 1.5), marker = attr(size = 4), fill = "toself", fillcolor = "rgba(74,111,165,0.12)"),
                              scatter(x = bx, y = by, mode = "lines", name = "diagram ($(mode))", line = attr(color = "#c0392b", width = 2.5, dash = "dash"),
                                      fill = "toself", fillcolor = "rgba(192,57,43,0.10)") ],
                            Layout( height = 340, autosize = true, margin = attr(l = 60, r = 10, t = 10, b = 50),
                                    xaxis = attr(title = xt, range = view([px; bx], qx), autorange = false, showline = true, linecolor = "#888", mirror = true),
                                    yaxis = attr(title = yt, range = view([py; by], qy), autorange = false, showline = true, linecolor = "#888", mirror = true),
                                    legend = attr(orientation = "h", y = -0.3), plot_bgcolor = "white",
                                    paper_bgcolor = "white" ))
        return "$(xt): $(fmt(rx, ax[1]));  $(yt): $(fmt(ry, ax[2]))", "", false, fig, Dict("display" => "block", "position" => "relative", "clear" => "both", "marginBottom" => 10)
    end

    callback!(
        app,
        Output("output-te-uploadn",         "is_open"),
        Output("output-te-uploadn-failed",  "is_open"),
        Input("upload-te",                  "contents"),
        State("upload-te",                  "filename"),
        State("kds-dropdown",               "value"),
        prevent_initial_call=true,
    ) do contents, filename, kdsDB

        if !(contents isa Nothing)
            status = parse_bulk_te(contents, filename, kdsDB)
            if status == 1
                return "success", nothing
            else
                return nothing, "failed"
            end
        end
    end

    callback!(
        app,
        Output("output-data-uploadn",        "is_open" ),
        Output("output-data-uploadn-failed", "is_open" ),
        Output("output-data-uploadn-failed", "children"),
        Input("upload-bulk", "contents"),
        State("upload-bulk", "filename"),
        State("optimizer-dropdown", "value"),
        prevent_initial_call=true,
    ) do contents, filename, optimizer

        if !(contents isa Nothing)
            status, msg = parse_bulk_rock(contents, filename; ns = optimizer == "ns")
            if status == 1
                return "success", false, ""
            else
                return false, true, msg
            end
        end
    end

    callback!(
        app,
        Output( "table-bulk-rock","data"),
        Output( "test-dropdown","options"),
        Output( "test-dropdown","value"),
        Output( "database-caption","value"),
        
        Input( "test-dropdown","value"),
        Input( "database-dropdown","value"),
        Input( "output-data-uploadn", "is_open"),  
        
        Input( "load-state-diagram-button","n_clicks"  ),
        Input( "select-bulk-unit","value"),

        State( "table-bulk-rock","data"),
        State( "load-state-filename-id",   "value"    ),
        State( "test-dropdown","options"),
        State( "database-caption","value"),

        prevent_initial_call=true,

    ) do    test, dtb, update,
            n_clicks_load, sys_unit, 
            tb_data, filename, test_opts, db_cap

        saved_table = nothing
        if state_load_triggered()
            file = state_options_file(filename)
            isnothing(file) && return ntuple(_ -> no_update(), 4)
            val, saved_table, saved_unit = try
                state_read(file, "test", "bulk_table", "bulk_unit"; optional = ("bulk_table", "bulk_unit"))
            catch
                return ntuple(_ -> no_update(), 4)
            end
            saved_table = state_convert_bulk_table(saved_table, saved_unit, sys_unit)
        else
            # catching up some special cases
            if test > length(db[(db.db .== dtb), :].test) - 1
                val = 0
            else
                val = test
            end
        end

        db_dtb      = db[(db.db .== dtb), :]
        row         = db_dtb[(db_dtb.test .== val), :]

        if !isnothing(saved_table)
            data    = saved_table
        elseif sys_unit == 1
            data    = [Dict("oxide" => row.oxide[1][i], "fraction" => row.frac[1][i])    for i=1:length(row.oxide[1]) ]
        elseif sys_unit == 2
            data    = [Dict("oxide" => row.oxide[1][i], "fraction" => row.frac_wt[1][i]) for i=1:length(row.oxide[1]) ]
        end

        opts        =  [Dict(   "label" => db_dtb.title[i],
                                "value" => db_dtb.test[i]  )
                                    for i=1:length(db_dtb.test)]

        cap         = dba[(dba.acronym .== dtb) , :].database[1]

        return data, opts, val, cap

    end



    callback!(
        app,
        Output("table-2-bulk-rock","data"),
        Output("test-2-dropdown","options"),
        Output("test-2-dropdown","value"),
        Input("test-2-dropdown","value"),
        Input("database-dropdown","value"),

        Input( "load-state-diagram-button","n_clicks"  ),
        Input( "select-bulk-unit","value"),
        State( "table-2-bulk-rock","data"),

        State( "load-state-filename-id",   "value"     ),
        State( "test-2-dropdown","options"),

        prevent_initial_call=true,

    ) do    test, dtb, 
            n_clicks_load, sys_unit,
            tb2_data, filename,
            test2_opts

        saved_table = nothing
        if state_load_triggered()
            file = state_options_file(filename)
            isnothing(file) && return ntuple(_ -> no_update(), 3)
            val, saved_table, saved_unit = try
                state_read(file, "test2", "bulk_table2", "bulk_unit"; optional = ("bulk_table2", "bulk_unit"))
            catch
                return ntuple(_ -> no_update(), 3)
            end
            saved_table = state_convert_bulk_table(saved_table, saved_unit, sys_unit)
        else
            # catching up some special cases
            if test > length(db[(db.db .== dtb), :].test) - 1
                val = 0
            else
                val = test
            end
        end

        db_dtb  = db[(db.db .== dtb), :]
        row     = db_dtb[(db_dtb.test .== val), :]
        has_2   = !isempty(row.frac2[1])

        if !isnothing(saved_table)
            data    = saved_table
        elseif sys_unit == 1
            frac    = has_2 ? row.frac2[1]    : row.frac[1]
            data    = [Dict("oxide" => row.oxide[1][i], "fraction" => frac[i]) for i=1:length(row.oxide[1]) ]
        elseif sys_unit == 2
            frac    = has_2 ? row.frac2_wt[1] : row.frac_wt[1]
            data    = [Dict("oxide" => row.oxide[1][i], "fraction" => frac[i]) for i=1:length(row.oxide[1]) ]
        end

        opts        =  [Dict(   "label" => db_dtb.title[i],
                                "value" => db_dtb.test[i]  )
                                    for i=1:length(db_dtb.test)]

        return data, opts, val
    end


    callback!(
        app,
        Output("table-te-rock","data"),
        Output("test-te-dropdown","options"),
        Output("test-te-dropdown","value"),
        Input("test-te-dropdown","value"),
        Input("output-te-uploadn", "is_open"),        # this listens for changes and updated the list
        Input(  "load-state-diagram-button","n_clicks"  ),
        State(  "load-state-filename-id",   "value"     ),
        prevent_initial_call=true,
    ) do test, update,
        n_clicks_load, filename

        te_db       = dbte
        saved_table = nothing
        if state_load_triggered()
            file = state_options_file(filename)
            isnothing(file) && return ntuple(_ -> no_update(), 3)
            t, te_db, saved_table = try
                state_read(file, "te_test", "dbte", "te_table"; optional = ("te_table",))
            catch
                return ntuple(_ -> no_update(), 3)
            end
        else
            if test > length(dbte.test) - 1
                t = 0
            else
                t = test
            end
        end

        row         = te_db[(te_db.test .== t), :]
        data        = !isnothing(saved_table) ? saved_table :
                      [Dict("elements" => row.elements[1][i], "μg_g" => row.μg_g[1][i]) for i=1:length(row.elements[1]) ]

        opts        =  [Dict(   "label" => te_db.title[i],
                                "value" => te_db.test[i]  )
                                    for i=1:length(te_db.test)]

        val         = t
        return data, opts, val
    end


    callback!(
        app,
        Output("table-te-2-rock","data"),
        Output("test-2-te-dropdown","options"),
        Output("test-2-te-dropdown","value"),

        Input("test-2-te-dropdown","value"),
        Input("output-te-uploadn", "is_open"),        # this listens for changes and updated the list
        Input(  "load-state-diagram-button","n_clicks"  ),
        State(  "load-state-filename-id",   "value"     ),
        prevent_initial_call=true,
    ) do test, update,
        n_clicks_load, filename
        
        te_db       = dbte
        saved_table = nothing
        if state_load_triggered()
            file = state_options_file(filename)
            isnothing(file) && return ntuple(_ -> no_update(), 3)
            t, te_db, saved_table = try
                state_read(file, "te_test2", "dbte", "te_table2"; optional = ("te_table2",))
            catch
                return ntuple(_ -> no_update(), 3)
            end
        else
            if test > length(dbte.test) - 1
                t = 0
            else
                t = test
            end
        end

        row         = te_db[(te_db.test .== t), :]
        data        = !isnothing(saved_table) ? saved_table :
                      [Dict("elements" => row.elements[1][i], "μg_g" => row.μg_g2[1][i]) for i=1:length(row.elements[1]) ]

        opts        =  [Dict(   "label" => te_db.title[i],
                                "value" => te_db.test[i]  )
                                    for i=1:length(te_db.test)]

        val         = t
        return data, opts, val                  
    end


    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-phase-selection", "is_open"),
        [Input("button-phase-selection", "n_clicks")],
        [State("collapse-phase-selection", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end
    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-pure-phase-selection", "is_open"),
        [Input("button-pure-phase-selection", "n_clicks")],
        [State("collapse-pure-phase-selection", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end
    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-general-parameters", "is_open"),
        [Input("button-general-parameters", "n_clicks")],
        [State("collapse-general-parameters", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close General parameters box (General setup tab)
    callback!(app,
        Output("collapse-general-setup-parameters", "is_open"),
        [Input("button-general-setup-parameters", "n_clicks")],
        [State("collapse-general-setup-parameters", "is_open")],

        prevent_initial_call = true, ) do  n, is_open

        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open

    end

    # set global Warr naming flag when the mineral-naming dropdown changes
    callback!(app,
        Output("warr-naming-dummy", "children"),
        Input("mineral-naming-dropdown", "value"),
        prevent_initial_call = true,
    ) do val
        global use_warr_names
        use_warr_names[1] = (val == "warr")
        return val
    end


    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-contributors", "is_open"),
        [Input("button-contributors", "n_clicks")],
        [State("collapse-contributors", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close External libraries box
    callback!(app,
        Output("collapse-external-libraries", "is_open"),
        [Input("button-external-libraries", "n_clicks")],
        [State("collapse-external-libraries", "is_open")],

        prevent_initial_call = true, ) do  n, is_open

        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open

    end

    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-contact", "is_open"),
        [Input("button-contact", "n_clicks")],
        [State("collapse-contact", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-export-magemin_c", "is_open"),
        [Input("button-export-magemin_c", "n_clicks")],
        [State("collapse-export-magemin_c", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-code-avail", "is_open"),
        [Input("button-code-avail", "n_clicks")],
        [State("collapse-code-avail", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end
    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-PT-conditions", "is_open"),
        [Input("button-PT-conditions", "n_clicks")],
        [State("collapse-PT-conditions", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end


    callback!(app,
        Output("collapse-advanced", "is_open"),
        [Input("button-advanced", "n_clicks")],
        [State("collapse-advanced", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-bulk", "is_open"),
        [Input("button-bulk", "n_clicks")],
        [State("collapse-bulk", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-te", "is_open"),
        [Input("button-te", "n_clicks")],
        [State("collapse-te", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close isopleth box
    callback!(app,
        Output("collapse-isopleths", "is_open"),
        [Input("button-isopleths", "n_clicks")],
        [State("collapse-isopleths", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end



    # Hide buffers unsupported by sb24
    callback!(
        app,
        Output("buffer-dropdown", "options"),
        Input("database-dropdown", "value" ),
        prevent_initial_call = true,
    ) do dtb

        all_opts = [
            (label = "no buffer", value = "none"   ),
            (label = "QFM",       value = "qfm"    ),
            (label = "MW",        value = "mw"     ),
            (label = "IW",        value = "iw"     ),
            (label = "QIF",       value = "qif"    ),
            (label = "CCO",       value = "cco"    ),
            (label = "HM",        value = "hm"     ),
            (label = "NNO",       value = "nno"    ),
            (label = "aH2O",      value = "aH2O"   ),
            (label = "aO2",       value = "aO2"    ),
            (label = "aFeO",      value = "aFeO"   ),
            (label = "aMgO",      value = "aMgO"   ),
            (label = "aAl2O3",    value = "aAl2O3" ),
            (label = "aTiO2",     value = "aTiO2"  ),
        ]

        hidden = ["cco", "nno", "aTiO2", "aH2O"]
        return dtb == "sb24" ? filter(o -> !(o.value in hidden), all_opts) : all_opts
    end

    return app
end
