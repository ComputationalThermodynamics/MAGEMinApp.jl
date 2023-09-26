
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
