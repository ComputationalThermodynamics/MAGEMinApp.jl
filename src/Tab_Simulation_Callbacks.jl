function Tab_Simulation_Callbacks(app)

    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output("ss-dropdown","options"),
        Output("ss-dropdown","value"),
        Output("em-1-id","style"),
        Output("ss-1-id","style"),
        Output("of-1-id","style"),
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

        return opts_ph, val, style_em, style_ph, style_of
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




    # save phase diagram data callback
    callback!(
        app,
        Output("data-save", "children"),
        Input("save-button", "n_clicks"),
        State("Filename-id", "value"),
    ) do value, filename

        ctx = callback_context()
        if length(ctx.triggered) == 0
            bid = ""
        else
            bid = split(ctx.triggered[1].prop_id, ".")[1]
        end

        # if we compute a new phase diagram
        if bid == "save-button"

            if filename == "..."
                return html_div([
                    "Provide a valid filename!"
                ], style = Dict("textAlign" => "center","font-size" => "100%"))
            else
                try
                    file = filename*".jld2"
                    save_object(file, AppData.PseudosectionData)
                catch e 
                    print("File could not be saved: $e\n")
                end

                return html_div([
                    "Phase diagram data saved"
                ], style = Dict("textAlign" => "center","font-size" => "100%"))
            end
        else
            return ""
        end
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



    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("fixed-temperature-id", "style"),
        Output("fixed-pressure-id", "style"),
        Output("temperature-id", "style"),
        Output("pressure-id", "style"),
        Output("test-2-id", "style"),
        Output("table-2-id", "style"),
        Input("diagram-dropdown", "value"),
    ) do value

        if value == "px"
            Tstyle  = Dict("display" => "block")
            Pstyle  = Dict("display" => "none")
            Ts      = Dict("display" => "none")
            Ps      = Dict("display" => "block")
            test2   = Dict("display" => "block")  
            table2  = Dict("display" => "block")  
        elseif value == "tx"
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "block")
            Ts      = Dict("display" => "block")
            Ps      = Dict("display" => "none")
            test2   = Dict("display" => "block")  
            table2  = Dict("display" => "block")  
        else
            Tstyle  = Dict("display" => "none")
            Pstyle  = Dict("display" => "none")
            Ts      = Dict("display" => "block")
            Ps      = Dict("display" => "block")
            test2   = Dict("display" => "none")  
            table2  = Dict("display" => "none")  
        end

        return Tstyle, Pstyle, Ts, Ps, test2, table2
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
        Input("output-data-uploadn", "is_open"),        # this listens for changes and updated the list
        prevent_initial_call=true,
    ) do test, dtb, update

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                "mol_fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac[1][i])
                                    for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]


        opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                "value" => db[(db.db .== dtb), :].test[i]  )
                                    for i=1:length(db[(db.db .== dtb), :].test)]

        cap         = dba[(dba.acronym .== dtb) , :].database[1]      
        
        val         = t
        return data, opts, val, cap                  
    end



    callback!(
        app,
        Output("table-2-bulk-rock","data"),
        Output("test-2-dropdown","options"),
        Output("test-2-dropdown","value"),
        Input("test-2-dropdown","value"),
        Input("database-dropdown","value"),
        Input("output-data-uploadn", "is_open"),        # this listens for changes and updated the list
        prevent_initial_call=true,
    ) do test, dtb, update

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        if (~isempty(db[(db.db .== dtb) .& (db.test .== t), :].frac2[1]))
            data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                    "mol_fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac2[1][i])
                                        for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
        else
            data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                    "mol_fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac[1][i])
                                        for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
        end

        opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                "value" => db[(db.db .== dtb), :].test[i]  )
                                    for i=1:length(db[(db.db .== dtb), :].test)]

        # cap         = dba[(dba.acronym .== dtb) , :].database[1]      
        
        val         = t
        return data, opts, val                  
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