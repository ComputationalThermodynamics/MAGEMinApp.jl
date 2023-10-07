"""
Callbacks for the simulation Tab
"""
function Tab_Simulation_Callbacks(app)
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
        Input("test-dropdown", "value"),
        Input("database-dropdown","value"),
    ) do test, dtb
        # global db

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
        Output("output-data-uploadn", "children"),
        Input("upload-bulk", "contents"),
        State("upload-bulk", "filename"),
    ) do contents, filename
        if !(contents isa Nothing)
            children = parse_bulk_rock(contents, filename)
            return children
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
        Input("output-data-uploadn", "children"),
        prevent_initial_call=true,
    ) do test, dtb, bulkin

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                "mol fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac[1][i])
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
        # Output("database-caption","value"),
        Input("test-2-dropdown","value"),
        Input("database-dropdown","value"),
        Input("output-data-uploadn", "children"),
        prevent_initial_call=true,
    ) do test, dtb, bulkin

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                "mol fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac[1][i])
                                    for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]


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


    return app
end