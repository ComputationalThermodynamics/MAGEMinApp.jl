function Tab_Simulation_Callbacks(app)



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
        State(  "verbose-dropdown",                 "value"       ),
        State(  "scp-dropdown",                     "value"       ),

        State(  "test-dropdown",                    "value"       ),
        State(  "test-2-dropdown",                  "value"       ),
        State(  "buffer-1-mul-id",                  "value"       ),
        State(  "buffer-2-mul-id",                  "value"       ),

        State(  "test-te-dropdown",                 "value"       ),
        State(  "test-2-te-dropdown",               "value"       ),

        State("watsat-dropdown",                    "value"       ),
        
        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do click, filename,

        database, diagram_type, mb_cpx, limit_ca_opx, ca_opx_val,
        tepm, kds_dtb, zrsat_dtb,
        ptx_table, 
        pmin, pmax, tmin, tmax, pfix, tfix,
        grid_sub, refinement, refinement_level,
        buffer, solver, verbose, scp,
        test, test2,
        buffer1, buffer2,
        te_test, te_test2,
        watsat

        global db, dbte

        file = String(filename)*".jld2"

        @save file db dbte database diagram_type mb_cpx limit_ca_opx ca_opx_val tepm kds_dtb zrsat_dtb ptx_table pmin pmax tmin tmax pfix tfix grid_sub refinement refinement_level buffer solver verbose scp test test2 buffer1 buffer2 te_test te_test2 watsat

        status = "success"
        print("saving phase diagram state in: $(pwd()) ...")

        return status
    end



    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output( "load-options-diagram-success",     "is_open"      ),
        Output( "load-options-diagram-failed",     "is_open"      ),

        Output(  "database-dropdown",                "value"       ),
        
        Output(  "diagram-dropdown",                 "value"       ),
        Output(  "mb-cpx-switch",                    "value"       ),
        Output(  "limit-ca-opx-id",                  "value"       ),
        Output(  "ca-opx-val-id",                    "value"       ),

        Output(  "tepm-dropdown",                    "value"       ),
        Output(  "kds-dropdown",                     "value"       ),
        Output(  "zrsat-dropdown",                   "value"       ),

        # Output(  "pt-x-table",                       "data"        ),
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
        Output(  "solver-dropdown",                  "value"       ),
        Output(  "verbose-dropdown",                 "value"       ),
        Output(  "scp-dropdown",                     "value"       ),

        Output(  "buffer-1-mul-id",                  "value"       ),
        Output(  "buffer-2-mul-id",                  "value"       ),

        Output("watsat-dropdown",                    "value"       ),

        Input(  "load-state-diagram-button",        "n_clicks"     ),
        State(  "save-state-filename-id",           "value"        ),
        
        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do click, filename

        global db, dbte

        file = String(filename)*".jld2"
        try 
            # using JSON3, JLD2
            @load file db dbte database diagram_type mb_cpx limit_ca_opx ca_opx_val tepm kds_dtb zrsat_dtb pmin pmax tmin tmax pfix tfix grid_sub refinement refinement_level buffer solver verbose scp buffer1 buffer2 watsat

            success, failed = "success", ""
            return success, failed, database, diagram_type, mb_cpx, limit_ca_opx, ca_opx_val, tepm, kds_dtb, zrsat_dtb, pmin, pmax, tmin, tmax, pfix, tfix, grid_sub, refinement, refinement_level, buffer, solver, verbose, scp, buffer1, buffer2, watsat
        catch e
            success, failed = "", "failed"
            return success, failed, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing
    
        end

    end



    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output("ss-dropdown","options"),
        Output("ss-dropdown","value"),
        Output("em-1-id","style"),
        Output("ss-1-id","style"),
        Output("of-1-id","style"),
        Output("phase-selection","options"),
        Output("phase-selection","value"),
        Input("database-dropdown","value"),
        Input("phase-dropdown","value"),

        prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do dtb, phase

        db_in       = retrieve_solution_phase_information(dtb)
        n_ss        = length(db_in.data_ss)
        n_pp        = length(db_in.data_pp)

        if phase == "of"
            style_ph    = Dict("display" => "none")
            style_em    = Dict("display" => "none")
            style_of    = Dict("display" => "block")
            opts_ph     = []
            val         = nothing

        elseif phase == "ss"
            opts_ph     =  [Dict(   "label" => db_in.data_ss[i].ss_name,
                                    "value" => db_in.data_ss[i].ss_name )
                                        for i=1:n_ss ]
            style_em    = Dict("display" => "block")
            style_ph    = Dict("display" => "block")
            style_of    = Dict("display" => "none")

            val         = db_in.data_ss[1].ss_name

        else
            opts_ph     =  [Dict(   "label" => db_in.data_pp[i],
                                    "value" => db_in.data_pp[i]  )
                                        for i=1:n_pp ]

            style_em    = Dict("display" => "none")
            style_ph    = Dict("display" => "block")
            style_of    = Dict("display" => "none")

            val         = db_in.data_pp[1]
        end

        phase_selection_options = [Dict(    "label"     => " "*i,
                                            "value"     => i )
                                                for i in db_in.ss_name ]
        phase_selection_value   = db_in.ss_name

        return opts_ph, val, style_em, style_ph, style_of, phase_selection_options, phase_selection_value
    end


    # update the dictionary of the solution phases and end-members for isopleth
    callback!(
        app,
        Output("em-dropdown","options"),
        Output("em-dropdown","value"),
        Input("database-dropdown","value"),
        Input("ss-dropdown","value"),
        State("phase-dropdown","value"),
        prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do dtb, id, ph
        # bid  = pushed_button( callback_context() ) 
        if ph == "ss"
            db_in          = retrieve_solution_phase_information(dtb)

            if id == 0
                id = db_in.ss_name[1]
            end

            ssid = findall(db_in.ss_name .== id)[1]

            n_em        = length(db_in.data_ss[ssid].ss_em)

            val         = "none"
            opts_em     =  [Dict(   "label" => db_in.data_ss[ssid].ss_em[i],
                                    "value" => db_in.data_ss[ssid].ss_em[i] )
                                        for i=1:n_em ]
                
            return opts_em, val
        else
            return "", ""
        end
    end




    # # save phase diagram data callback
    # callback!(
    #     app,
    #     Output("data-save", "children"),
    #     Input("save-button", "n_clicks"),
    #     State("Filename-id", "value"),
    # ) do value, filename

    #     ctx = callback_context()
    #     if length(ctx.triggered) == 0
    #         bid = ""
    #     else
    #         bid = split(ctx.triggered[1].prop_id, ".")[1]
    #     end

    #     # if we compute a new phase diagram
    #     if bid == "save-button"

    #         if filename == "..."
    #             return html_div([
    #                 "Provide a valid filename!"
    #             ], style = Dict("textAlign" => "center","font-size" => "100%"))
    #         else
    #             try
    #                 file = filename*".jld2"
    #                 save_object(file, AppData.PseudosectionData)
    #             catch e 
    #                 print("File could not be saved: $e\n")
    #             end

    #             return html_div([
    #                 "Phase diagram data saved"
    #             ], style = Dict("textAlign" => "center","font-size" => "100%"))
    #         end
    #     else
    #         return ""
    #     end
    # end


    # callback to display trace element predictive model options
    callback!(
        app,
        Output("tepm-options-id",   "style"),
        Output("te-panel-id",       "style"),
        Input("tepm-dropdown",      "value"),
    ) do value

        if value == "false"
            opt     = Dict("display" => "none")
            panel   = Dict("display" => "none")
        elseif value == "true"
            opt     = Dict("display" => "block")    
            panel   = Dict("display" => "block")
        end

        return opt, panel
    end


    # callback to display ca-orthopyroxene limiter
    callback!(
        app,
        Output("switch-opx-id", "style"),
        Input("database-dropdown", "value"),
    ) do value
        # global db
        if value == "ig"
            style  = Dict("display" => "block")
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
            file = String(filename)*".jld2"

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
                return "success", ""
            else
                return "", "failed"
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
        Output("table-bulk-rock","data"),
        Output("test-dropdown","options"),
        Output("test-dropdown","value"),
        Output("database-caption","value"),
        
        Input("test-dropdown","value"),
        Input("database-dropdown","value"),
        Input("output-data-uploadn", "is_open"),  
        
        Input( "load-state-diagram-button","n_clicks"  ),
        State(  "save-state-filename-id",   "value"    ),

        State("table-bulk-rock","data"),
        State("test-dropdown","options"),
        State("database-caption","value"),

        prevent_initial_call=true,

    ) do    test, dtb, update,
            n_clicks_load, filename,
            tb_data, test_opts, db_cap

        bid  = pushed_button( callback_context() )  

        if bid ==  "load-state-diagram-button"
            file = String(filename)*".jld2"

            @load file test

            val = test
            # return tb_data, test_opts, test, db_cap
        else
            # catching up some special cases
            if test > length(db[(db.db .== dtb), :].test) - 1 
                val = 0
            else
                val = test
            end
        end

            data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                    "mol_fraction"  => db[(db.db .== dtb) .& (db.test .== val), :].frac[1][i])
                                        for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]


            opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                    "value" => db[(db.db .== dtb), :].test[i]  )
                                        for i=1:length(db[(db.db .== dtb), :].test)]

            cap         = dba[(dba.acronym .== dtb) , :].database[1]  

            return data, opts, val, cap    
        # end

               
    end



    callback!(
        app,
        Output("table-2-bulk-rock","data"),
        Output("test-2-dropdown","options"),
        Output("test-2-dropdown","value"),
        # Input("output-data-uploadn", "is_open"),
        Input("test-2-dropdown","value"),
        Input("database-dropdown","value"),

        Input(  "load-state-diagram-button","n_clicks"  ),
        State(  "save-state-filename-id",   "value"     ),

        State("table-2-bulk-rock","data"),
        State("test-2-dropdown","options"),

        prevent_initial_call=true,

    ) do    test, dtb, 
            n_clicks_load, filename,
            tb2_data, test2_opts

         bid  = pushed_button( callback_context() )     

         if bid == "load-state-diagram-button"
            file = String(filename)*".jld2"

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
                data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                        "mol_fraction"  => db[(db.db .== dtb) .& (db.test .== val), :].frac2[1][i])
                                            for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
            else
                data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== val), :].oxide[1][i],
                                        "mol_fraction"  => db[(db.db .== dtb) .& (db.test .== val), :].frac[1][i])
                                            for i=1:length(db[(db.db .== dtb) .& (db.test .== val), :].oxide[1]) ]
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
            file = String(filename)*".jld2"

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
            file = String(filename)*".jld2"

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