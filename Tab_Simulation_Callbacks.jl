
# callback function to update overview graph
callback!(
    app,
    Output("diagram-bar","figure"),
    Output("active-css",  "href"),
    Output("banner-img",  "src"),
    Output("moon-img",  "src"),
    Input("mode-display", "value"),

) do bool

    if bool == false
        layout  = AppData.default_diagram_layout
        css     = "/assets/css/default.css"
        src     = "assets/static/images/Logos_MAGEMin_light_noERC.jpg"
        srcm    = "assets/static/images/moon.png"
    else
        layout = AppData.dark_diagram_layout
        css     = "/assets/css/dark.css"
        src     = "assets/static/images/Logos_MAGEMin_dark_noERC.jpg"
        srcm    = "assets/static/images/moondark.png"
    end

    fig_hours = plot( db, layout)
                        
    return fig_hours, css, src, srcm
end

# open/close screenshot box
callback!(app,
    Output("collapse-timeperiod", "is_open"),
    [Input("button-timeperiod", "n_clicks")],
    [State("collapse-timeperiod", "is_open")], ) do  n, is_open
    
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
    Output("collapse", "is_open"),
    [Input("button-display-options", "n_clicks")],
    [State("collapse", "is_open")], ) do  n, is_open
    
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



# open/close tomography box
callback!(app,
    Output("collapse-refinement", "is_open"),
    [Input("button-refinement", "n_clicks")],
    [State("collapse-refinement", "is_open")], ) do  n, is_open
    
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