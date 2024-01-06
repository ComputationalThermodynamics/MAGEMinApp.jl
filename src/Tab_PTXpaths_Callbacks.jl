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

        for i=1:np
            x[i] = dataout[i][Symbol("col-2")]
            y[i] = dataout[i][Symbol("col-1")]
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
            title= attr(
                text    = "P-T path preview",
                x       = 0.5,
                xanchor = "center",
                yanchor = "top"
            ),
            height      = 320,
            autosize    = false,
            xaxis_title = "Temperature [°C]",
            yaxis_title = "Pressure [kbar]",
            xaxis_range = [Xmin,Xmax], 
            yaxis_range = [Ymin,Ymax],
            showlegend  = false,
        )

        fig = plot(df, x=:x, y=:y, layout)
    
        return fig
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