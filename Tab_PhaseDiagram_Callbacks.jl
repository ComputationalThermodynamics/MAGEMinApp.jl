
# callback function to update overview graph
callback!(
    app,
    Output("phase-diagram","figure"),
    Input("mesh-button","n_clicks"),
    # Input("compute-button","n_clicks"),
    State("tsub-id","value"),
    State("psub-id","value"),
    State("tmin-id","value"),
    State("tmax-id","value"),
    State("pmin-id","value"),
    State("pmax-id","value"),
    State("refinement-levels","value"),

) do n_clicks_mesh, Xsub, Ysub, tmin, tmax, pmin, pmax, n_ref

    layout = Layout(
        title           = attr(
            text        = "Phase diagram",
            y           = 0.95,
            x           = 0.5,
            xanchor     = "center",
            yanchor     = "top",
            font_color  = "#000000",
            font_size   = 18.0),

        showlegend  = false,
        xaxis_title = "Temperature [°C]",
        yaxis_title = "Pressure [kbar]",
    )

    ctx = callback_context()
    if length(ctx.triggered) == 0
        bid = "mesh-button"
    else
        bid = split(ctx.triggered[1].prop_id, ".")[1]
    end

    if bid == "mesh-button"

        empty!(AppData.vertice_list)
        empty!(AppData.mesh)
        empty!(AppData.field)

        vert    = get_initial_vertices(Xsub,Ysub,tmin,tmax,pmin,pmax);              # generate initial set of points
        field   = get_field_from_vert(vert,tmin,tmax,pmin,pmax)                     # attach a field to it (will be phase id)

        push!(AppData.field,field)                                                  # push to Appdata
        push!(AppData.vertice_list,vert)
        db, mesh = generator_scatter_traces(tmin,tmax,pmin,pmax);                   # create scatter tracers

        push!(AppData.mesh,mesh)                                                    # push mesh to AppData

        fig_phase_diagram = plot(db, layout)                                        # plot results
    end

    # if bid == "compute-button"

    # end

    return fig_phase_diagram                     
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