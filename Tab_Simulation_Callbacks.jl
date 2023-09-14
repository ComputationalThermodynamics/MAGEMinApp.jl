
# callback function to update overview graph
callback!(
    app,
    Output("diagram-bar","figure"),
    Output("active-css",  "href"),
    Output("banner-img",  "src"),
    Input("mode-display", "value"),

) do bool

    if bool == false
        layout  = AppData.default_diagram_layout
        css     = href="/assets/css/default.css"
        src     = src="assets/static/images/Logos_MAGEMin_light_noERC.jpg"
    else
        layout = AppData.dark_diagram_layout
        css = href="/assets/css/dark.css"
        src     = src="assets/static/images/Logos_MAGEMin_dark_noERC.jpg"
    end

    fig_hours = plot( db, layout)
                        
    return fig_hours, css, src
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