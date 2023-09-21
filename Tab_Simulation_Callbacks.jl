
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
