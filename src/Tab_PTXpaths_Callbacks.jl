function Tab_PTXpaths_Callbacks(app)

    """
        Callback to update preview of PT path
    """
    callback!(
        app,
        Output("path-plot", "figure"),
        Input("ptx-table", "data"),
        # prevent_initial_call = true,
        ) do data

        dataout = copy(data)
        np      = length(dataout)
        x       = zeros(np)
        y       = zeros(np)

        annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,np)

        for i=1:np
            x[i] = dataout[i][Symbol("col-2")]
            y[i] = dataout[i][Symbol("col-1")]
            annotations[i] =   attr(    xref        = "x",
                                        yref        = "y",
                                        x           = x[i],
                                        y           = y[i],
                                        xshift      = -10,
                                        yshift      = +10,
                                        text        = "#$i",
                                        showarrow   = false,
                                        visible     = true,
                                        font        = attr( size = 10, color = "#212121"),
                                    )  
        end

        Xmin    = maximum([0.0,minimum(x) - 50.0])
        Xmax    = maximum(x) + 50.0
        Ymin    = maximum([0.0,minimum(y) - 2.0])
        Ymax    = maximum(y) + 2.0

        df = DataFrame(
            x=x,
            y=y,
        )
    
        layout  = Layout(

            height      = 240,
            margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
            autosize    = false,
            xaxis_title = "Temperature [°C]",
            yaxis_title = "Pressure [kbar]",
            xaxis_range = [Xmin,Xmax], 
            yaxis_range = [Ymin,Ymax],
            annotations = annotations,
            showlegend  = false,
        )

        fig = plot(df, x=:x, y=:y, layout)
    
        return fig
    end



    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("buffer-1-id-ptx", "style"),
        Input("buffer-dropdown-ptx", "value"),
    ) do value

        if value != "none"
            b1  = Dict("display" => "block")
        else
            b1  = Dict("display" => "none")
        end

        return b1
    end



    callback!(
        app,
        Output("table-bulk-rock-ptx","data"),
        Output("test-dropdown-ptx","options"),
        Output("test-dropdown-ptx","value"),
        Output("database-caption-ptx","value"),
        Input("test-dropdown-ptx","value"),
        Input("database-dropdown-ptx","value"),
        Input("output-data-uploadn-ptx", "is_open"),        # this listens for changes and updated the list
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


    callback!(app,
        Output("collapse-path", "is_open"),
        [Input("button-path", "n_clicks")],
        [State("collapse-path", "is_open")], ) do  n, is_open
        
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
        Output("collapse-path-preview", "is_open"),
        [Input("button-path-preview", "n_clicks")],
        [State("collapse-path-preview", "is_open")], ) do  n, is_open
            
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
        Output("collapse-config", "is_open"),
        [Input("button-config", "n_clicks")],
        [State("collapse-config", "is_open")], ) do  n, is_open
            
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
        Output("collapse-bulk-ptx", "is_open"),
        [Input("button-bulk-ptx", "n_clicks")],
        [State("collapse-bulk-ptx", "is_open")], ) do  n, is_open
            
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
        Output("ptx-table", "data"),
        Input("add-row-button", "n_clicks"),
        State("ptx-table", "data"),
        State("ptx-table", "columns"),
        prevent_initial_call = true,
        ) do n_clicks, data, columns

        dataout = copy(data)

        if n_clicks > 0
            add = Dict(Symbol("col-1") => 5, Symbol("col-2") => 500)
            push!(dataout,add)
        end

        return dataout
    end

    return app
end