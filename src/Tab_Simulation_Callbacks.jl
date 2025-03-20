function Tab_Simulation_Callbacks(app)

    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output( "grid-subdivision",     "value"     ),
        Input(  "gsub-id",              "value"     ),

    prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do n_ref

        n_ref_info = "$(2^n_ref) × $(2^n_ref) grid"

        return n_ref_info
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

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do click, filename,

        database, diagram_type, mb_cpx, limit_ca_opx, ca_opx_val,
        tepm, kds_dtb, zrsat_dtb,
        ptx_table, 
        pmin, pmax, tmin, tmax, pfix, tfix,
        grid_sub, refinement, refinement_level,
        buffer, solver, boost, verbose, scp,
        test, test2,
        buffer1, buffer2,
        te_test, te_test2,
        watsat, watsat_val

        global db, dbte

        global infos, layout, data, data_plot, data_reaction, iso_show, n_lbl, data_isopleth, data_isopleth_out, Out_XY, Hash_XY, Out_TE_XY, all_TE_ph, n_phase_XY, addedRefinementLvl, pChip_wat, pChip_T;

        global file_pd  = "saved_states/"*String(filename)*"_phase_diagram.jld2"
        file_pd_data    = "saved_states/"*String(filename)*"_phase_diagram_data.jld2"
        file            = "saved_states/"*String(filename)*"_options.jld2"

        println("Saving phase diagram options..."); t0 = time()
        @save file db dbte database diagram_type mb_cpx limit_ca_opx ca_opx_val tepm kds_dtb zrsat_dtb ptx_table pmin pmax tmin tmax pfix tfix grid_sub refinement refinement_level buffer solver boost verbose scp test test2 buffer1 buffer2 te_test te_test2 watsat watsat_val
        println("Saved phase diagram options in $(round(time()-t0, digits=3)) seconds"); 

        gv_names    = ["infos","layout","data", "data_plot", "data_reaction","iso_show", "n_lbl","data_isopleth", "data_isopleth_out","Out_XY", "Hash_XY", "Out_TE_XY", "all_TE_ph", "n_phase_XY", "addedRefinementLvl", "pChip_wat", "pChip_T"]
  
        save_cmd    = "@save file_pd"
        field_list  = []
        for i in gv_names
            if isdefined(MAGEMinApp, Symbol(i))
                save_cmd *= " $i"
                push!(field_list, i)
            end 
        end

        if !isempty(field_list)
            println("Saving phase diagram data (can take a while 1-5 Go)..."); t0 = time()
            @save file_pd_data field_list
            eval(Meta.parse(save_cmd))
            println("Saved phase diagram data in $(round(time()-t0, digits=3)) seconds"); 
        end

        status = "success"
        println("saved in: $(pwd())/")

        return status
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
        Output(  "kds-dropdown",                     "value"       ),
        Output(  "zrsat-dropdown",                   "value"       ),

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
        Input(   "load-state-diagram-button",        "n_clicks"    ),
        State(   "save-state-filename-id",           "value"       ),
        State(   "load-state-id",                    "value"       ),
        
        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do click, filename, state_id

        state_id *=  -1.0

        # load the phase diagram if saved
        global infos, layout, data, data_plot, data_reaction, iso_show, n_lbl, data_isopleth, data_isopleth_out, Out_XY, Hash_XY, Out_TE_XY, all_TE_ph, n_phase_XY, addedRefinementLvl, pChip_wat, pChip_T;

        file_pd_data    = "saved_states/"*String(filename)*"_phase_diagram_data.jld2"
        global file_pdr = "saved_states/"*String(filename)*"_phase_diagram.jld2"
        load_cmd        = "@load file_pdr" 
        try
            field_list = []
            @load file_pd_data field_list
            for i in field_list
                load_cmd *= " $i"
            end
            if !isempty(field_list)
                println("Loading phase diagram..."); t0 = time()
                eval(Meta.parse(load_cmd))
                println("Loaded phase diagram in $(round(time()-t0, digits=3)) seconds"); 
            end
        catch
            println("failed to load the phase diagram data")
        end
        
        # load option of the phase diagram tab
        global db, dbte
        file = "saved_states/"*String(filename)*"_options.jld2"
        try 
            @load file db dbte database diagram_type mb_cpx limit_ca_opx ca_opx_val tepm kds_dtb zrsat_dtb pmin pmax tmin tmax pfix tfix grid_sub refinement refinement_level buffer boost verbose scp buffer1 buffer2 watsat watsat_val

            success, failed = "success", ""
            return success, failed, database, diagram_type, mb_cpx, limit_ca_opx, ca_opx_val, tepm, kds_dtb, zrsat_dtb, pmin, pmax, tmin, tmax, pfix, tfix, grid_sub, refinement, refinement_level, buffer, boost, verbose, scp, buffer1, buffer2, watsat, watsat_val, state_id
        catch e
            success, failed = "", "failed"
            return success, failed, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, state_id
        end
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
        Input("database-dropdown","value"),

        prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do dtb
    
        db_in       = retrieve_solution_phase_information(dtb)

        # this is the phase selection part for the database when compute a diagram
        phase_selection_options = [Dict(    "label"     => " "*i,
                                            "value"     => i )
                                                for i in db_in.ss_name ]
        phase_selection_value   = db_in.ss_name


        # this is the phase selection part for the database when compute a diagram
        pp_all  = db_in.data_pp
        pp_disp = setdiff(pp_all, AppData.hidden_pp)

        pure_phase_selection_options = [Dict(    "label"     => " "*i,
                                                 "value"     => i )
                                                for i in pp_disp ]
        pure_phase_selection_value   = pp_disp


        dataset_options = [Dict(    "label"     => "ds$(db_in.dataset_opt[i])",
                                    "value"     => db_in.dataset_opt[i] )
                                for i = 1:length(db_in.dataset_opt) ]
        dataset_value    = db_in.db_dataset


        return phase_selection_options, phase_selection_value, pure_phase_selection_options, pure_phase_selection_value, dataset_options, dataset_value
    end

    


    # update available options
    callback!(
        app,
        Output("solver-dropdown",       "value"),
        Input("boost-mode-dropdown",    "value"),
        Input("scp-dropdown",           "value"),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do boost, scp
    
        bid         = pushed_button( callback_context() ) 

        if bid == "boost-mode-dropdown"
            if boost == true
                solver_opt    = "lp"
            else
                if scp == "G_system"
                    solver_opt    = "lp"
                else
                    solver_opt    = "hyb"
                end
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
        Output("em-1-id",           "style"),
        Output("ox-1-id",           "style"),
        Output("ss-1-id",           "style"),
        Output("of-1-id",           "style"),
        Output("other-1-id",        "style"),
        Output("sys-unit-isopleth-id","style"),

        Input("trigger-update-ss-list","value"),
        Input("phase-dropdown",     "value"),
        Input("other-dropdown",     "value"),
        State("ss-dropdown",        "value"),
        State("database-dropdown",  "value"),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do pd_update, phase, other, ph, dtb
    
        bid         = pushed_button( callback_context() ) 

        pp          = phase_infos.act_pp
        ss          = phase_infos.act_ss
        n_pp        = length(pp)
        n_ss        = length(ss)

        if phase == "of"
            style_ph    = Dict("display" => "none")
            style_em    = Dict("display" => "none")
            style_ox    = Dict("display" => "none")
            style_calc  = Dict("display" => "none")
            style_calc_sf = Dict("display" => "none")
            style_ot    = Dict("display" => "none")
            style_of    = Dict("display" => "block")
            style_sys   = Dict("display" => "none")
            opts_ph     = []
            val         = nothing
        elseif phase == "ss"
            
            opts_ph     =  [Dict(   "label" => ss[i],
                                    "value" => ss[i] )
                                        for i=1:n_ss ]
            style_ot    = Dict("display" => "block")
            style_ph    = Dict("display" => "block")
            style_of    = Dict("display" => "none")
            style_sys   = Dict("display" => "block")
            
            if other == "emMode"
                style_em    = Dict("display" => "block")
            else
                style_em    = Dict("display" => "none")
            end

            if other == "oxComp"
                style_ox    = Dict("display" => "block")
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
                style_calc_sf  = Dict("display" => "block")
                style_sys   = Dict("display" => "none")
            else
                style_calc_sf  = Dict("display" => "none")
            end

            if other == "MgNum"
                style_sys   = Dict("display" => "none")
            end

            if bid != "other-dropdown"
                val         = ss[1]
            else
                val         = ph
            end

        else

            opts_ph     =  [Dict(   "label" => pp[i],
                                    "value" => pp[i]  )
                                        for i=1:n_pp ]

            style_em    = Dict("display" => "none")
            style_ox    = Dict("display" => "none")
            style_ot    = Dict("display" => "none")
            style_calc  = Dict("display" => "none")
            style_calc_sf  = Dict("display" => "none")
            style_ph    = Dict("display" => "block")
            style_of    = Dict("display" => "none")
            style_sys   = Dict("display" => "block")

            if n_pp > 0
                val         = pp[1]
            else 
                val = ""
            end

        end

        return opts_ph, val, style_calc, style_calc_sf, style_em, style_ox, style_ph, style_of, style_ot, style_sys
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
        State("phase-dropdown","value"),
        State("mb-cpx-switch","value"),

        prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do dtb, ph_name, ph, mbCpx
        bid  = pushed_button( callback_context() ) 
        if mbCpx == true
            aug = 1
        else
            aug = 0
        end

        if ph == "ss"

            ph_name         = get_ss_from_mineral(dtb, ph_name, aug)
            db_in           = retrieve_solution_phase_information(dtb)
            ph_id           = findfirst(db_in.ss_name .== ph_name)
            sf_names        = join(db_in.data_ss[ph_id].ss_sf[2:end], " ")

            if ph_name in db_in.ss_name
                # id = get_ss_from_mineral(dtb, id, aug)
            else
                ph_name = db_in.ss_name[1]
            end

            ssid        = findall(db_in.ss_name .== ph_name)[1]
            n_em        = length(db_in.data_ss[ssid].ss_em)

            val         = "none"
            opts_em     =  [Dict(   "label" => db_in.data_ss[ssid].ss_em[i],
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
        Output("eodc-options-id",   "style"),
        Output("eodc-ratio-display-id",   "style"),
        Output("display-show-norm-id",   "style"),
        
        Input("tepm-dropdown",      "value"),
        Input("kds-dropdown",       "value"),
        Input("eodc-options-dropdown",       "value"),
    ) do tepm, kds, eodc_opt

        type_eodc   = Dict("display" => "none" )

        if tepm == "false"
            opt     = Dict("display" => "none")
            panel   = Dict("display" => "none")
            zr      = Dict("display" => "none")
            opeodc  = Dict("display" => "none")
            show_norm = Dict("display" => "none")

        elseif tepm == "true" 
            if kds == "OL"
                opt     = Dict("display" => "block" )    
                panel   = Dict("display" => "block" )
                zr      = Dict("display" => "block" )
                opeodc  = Dict("display" => "none"  )
                show_norm = Dict("display" => "block")

            elseif kds == "EODC"
                opt     = Dict("display" => "block" )    
                panel   = Dict("display" => "block" )
                zr      = Dict("display" => "none"  )
                opeodc  = Dict("display" => "block" )
                show_norm = Dict("display" => "none")
                if eodc_opt == "NAT"
                    type_eodc   = Dict("display" => "block" )
                end
            end
        end

        return opt, panel, zr, opeodc, type_eodc, show_norm
    end


    # callback to display ca-orthopyroxene limiter
    callback!(
        app,
        Output("switch-opx-id", "style"),
        Input("database-dropdown", "value"),
    ) do value
        # global db
        if value == "ig"
            style  = Dict("display" => "none")
        elseif value == "igd"
            style  = Dict("display" => "block")    
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
    ) do value
        # global db
        if value == "mb"
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
    ) do value
        # global db
        if value == "true"
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
    ) do reset, test, dtb
    
            title = db[(db.db .== dtb), :].title[test+1]
        return title
    end

    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("buffer-1-id", "style"),
        Output("buffer-2-id", "style"),
        Input("buffer-dropdown", "value"),
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
        Input(  "add-ptx-row-button",       "n_clicks"  ),
        Input(  "load-state-diagram-button","n_clicks"  ),
        State(  "save-state-filename-id",   "value"     ),
        State(  "pt-x-table",               "data"      ),
        State(  "pt-x-table",               "columns"   ),

        prevent_initial_call = true,

        ) do n_clicks, n_clicks_load, filename, data, columns

        bid  = pushed_button( callback_context() )     

        if bid == "add-ptx-row-button"
            dataout = copy(data)

            if n_clicks > 0
                add = Dict(Symbol("col-1") => 7.5, Symbol("col-2") => 1000)
                push!(dataout,add)
            end

            return dataout

        elseif bid ==  "load-state-diagram-button"
            file = "saved_states/"*String(filename)*"_options.jld2"

            @load file ptx_table

            return ptx_table
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
        Input("diagram-dropdown", "value"),
    ) do value

        if value == "px"
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
        elseif value == "tx"
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
        elseif value == "pt"
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
        end

        return Tstyle, Pstyle, Ts, Ps, test2, table2, PTx, testte2, tabte2, watsat
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
        Output("output-data-uploadn", "is_open"),
        Output("output-data-uploadn-failed", "is_open"),
        Input("upload-bulk", "contents"),
        State("upload-bulk", "filename"),
        prevent_initial_call=true,
    ) do contents, filename

        if !(contents isa Nothing)
            status = parse_bulk_rock(contents, filename)
            if status == 1
                return "success", ""
            else
                return "", "failed"
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
        State( "save-state-filename-id",   "value"    ),
        State( "test-dropdown","options"),
        State( "database-caption","value"),

        prevent_initial_call=true,

    ) do    test, dtb, update,
            n_clicks_load, sys_unit, 
            tb_data, filename, test_opts, db_cap

        bid  = pushed_button( callback_context() )  

        if bid ==  "load-state-diagram-button"
            file = "saved_states/"*String(filename)*"_options.jld2"

            @load file test

            val = test
        else
            # catching up some special cases
            if test > length(db[(db.db .== dtb), :].test) - 1 
                val = 0
            else
                val = test
            end
        end

        if sys_unit == 1
            data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                    "fraction"           => db[(db.db .== dtb) .& (db.test .== val), :].frac[1][i])
                                        for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
        elseif sys_unit == 2
            data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                    "fraction"            => db[(db.db .== dtb) .& (db.test .== val), :].frac_wt[1][i])
                                        for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
        end



        opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                "value" => db[(db.db .== dtb), :].test[i]  )
                                    for i=1:length(db[(db.db .== dtb), :].test)]

        cap         = dba[(dba.acronym .== dtb) , :].database[1]  

        return data, opts, val, cap    
    
    end



    callback!(
        app,
        Output("table-2-bulk-rock","data"),
        Output("test-2-dropdown","options"),
        Output("test-2-dropdown","value"),
        # Input("output-data-uploadn", "is_open"),
        Input("test-2-dropdown","value"),
        Input("database-dropdown","value"),

        Input( "load-state-diagram-button","n_clicks"  ),
        Input( "select-bulk-unit","value"),
        State( "table-2-bulk-rock","data"),

        State( "save-state-filename-id",   "value"     ),
        State( "test-2-dropdown","options"),

        prevent_initial_call=true,

    ) do    test, dtb, 
            n_clicks_load, sys_unit,
            tb2_data, filename,
            test2_opts

         bid  = pushed_button( callback_context() )     

         if bid == "load-state-diagram-button"
            file = "saved_states/"*String(filename)*"_options.jld2"

            @load file test2
            val = test2
            # return tb2_data, test2_opts, test2

         else

            # catching up some special cases
            if test > length(db[(db.db .== dtb), :].test) - 1 
                val = 0
            else
                val = test
            end
        end

            if (~isempty(db[(db.db .== dtb) .& (db.test .== val), :].frac2[1]))

                if sys_unit == 1
                    data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                            "fraction"  => db[(db.db .== dtb) .& (db.test .== val), :].frac2[1][i])
                                                for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
                elseif sys_unit == 2
                    data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                            "fraction"  => db[(db.db .== dtb) .& (db.test .== val), :].frac2_wt[1][i])
                                                for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
                end

            else
                if sys_unit == 1
                    data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                            "fraction"  => db[(db.db .== dtb) .& (db.test .== val), :].frac[1][i])
                                                for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
                elseif sys_unit == 2
                    data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                            "fraction"  => db[(db.db .== dtb) .& (db.test .== val), :].frac_wt[1][i])
                                                for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
                end

            end

            opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                    "value" => db[(db.db .== dtb), :].test[i]  )
                                        for i=1:length(db[(db.db .== dtb), :].test)]

            # cap         = dba[(dba.acronym .== dtb) , :].database[1]      
            
            return data, opts, val 
        # end                 
    end


    callback!(
        app,
        Output("table-te-rock","data"),
        Output("test-te-dropdown","options"),
        Output("test-te-dropdown","value"),
        Input("test-te-dropdown","value"),
        Input("output-te-uploadn", "is_open"),        # this listens for changes and updated the list
        Input(  "load-state-diagram-button","n_clicks"  ),
        State(  "save-state-filename-id",   "value"     ),    prevent_initial_call=true,
    ) do test, update,
        n_clicks_load, filename

        bid  = pushed_button( callback_context() )  

        # catching up some special cases
        if bid ==  "load-state-diagram-button"
            file = "saved_states/"*String(filename)*"_options.jld2"

            @load file te_test
            t = te_test
        else
            if test > length(dbte.test) - 1 
                t = 0
            else
                t = test
            end
        end 

        data        =   [Dict(  "elements"  => dbte[(dbte.test .== t), :].elements[1][i],
                                "μg_g"       => dbte[(dbte.test .== t), :].μg_g[1][i])
                                    for i=1:length(dbte[(dbte.test .== t), :].elements[1]) ]

        opts        =  [Dict(   "label" => dbte.title[i],
                                "value" => dbte.test[i]  )
                                    for i=1:length(dbte.test)]

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
        State(  "save-state-filename-id",   "value"     ),        prevent_initial_call=true,
    ) do test, update,
        n_clicks_load, filename
        
        bid  = pushed_button( callback_context() )  

        # catching up some special cases
        if bid ==  "load-state-diagram-button"
            file = "saved_states/"*String(filename)*"_options.jld2"

            @load file te_test2
            t = te_test2
        else
            if test > length(dbte.test) - 1 
                t = 0
            else
                t = test
            end
        end 


        data        =   [Dict(  "elements"  => dbte[(dbte.test .== t), :].elements[1][i],
                                "μg_g"       => dbte[(dbte.test .== t), :].μg_g2[1][i])
                                    for i=1:length(dbte[(dbte.test .== t), :].elements[1]) ]

        opts        =  [Dict(   "label" => dbte.title[i],
                                "value" => dbte.test[i]  )
                                    for i=1:length(dbte.test)]

        val         = t
        return data, opts, val                  
    end


    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-phase-selection", "is_open"),
        [Input("button-phase-selection", "n_clicks")],
        [State("collapse-phase-selection", "is_open")], ) do  n, is_open
        
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
        [State("collapse-pure-phase-selection", "is_open")], ) do  n, is_open
        
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
        [State("collapse-general-parameters", "is_open")], ) do  n, is_open
        
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
        Output("collapse-contributors", "is_open"),
        [Input("button-contributors", "n_clicks")],
        [State("collapse-contributors", "is_open")], ) do  n, is_open
        
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
        [State("collapse-contact", "is_open")], ) do  n, is_open
        
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
        [State("collapse-export-magemin_c", "is_open")], ) do  n, is_open
        
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
        [State("collapse-code-avail", "is_open")], ) do  n, is_open
        
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
        [State("collapse-PT-conditions", "is_open")], ) do  n, is_open
        
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
        [State("collapse-bulk", "is_open")], ) do  n, is_open
        
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
        [State("collapse-te", "is_open")], ) do  n, is_open
        
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
        [State("collapse-isopleths", "is_open")], ) do  n, is_open
        
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



    return app
end