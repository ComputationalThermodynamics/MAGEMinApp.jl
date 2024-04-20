function Tab_isoSpaths_Callbacks(app)

    callback!(app,
        Output("collapse-config-isoS", "is_open"),
        [Input("button-config-isoS", "n_clicks")],
        [State("collapse-config-isoS", "is_open")], ) do  n, is_open
            
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
        Output("collapse-bulk-isoS", "is_open"),
        [Input("button-bulk-isoS", "n_clicks")],
        [State("collapse-bulk-isoS", "is_open")], ) do  n, is_open
            
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