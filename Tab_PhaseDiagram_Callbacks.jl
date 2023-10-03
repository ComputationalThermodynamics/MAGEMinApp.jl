# Callback function to create compute the phase diagram using T8code for Adaptive Mesh Refinement
callback!(
    app,
    Output("phase-diagram","figure"),
    Input("compute-button","n_clicks"),
    Input("colormaps_cross","value"),
    Input("fields-dropdown","value"),
    Input("hide-grid","value"),              # show edges checkbox

    State("diagram-dropdown","value"),          # pt,px,tx
    State("database-dropdown","value"),         # mp,mb,ig,igd,um,alk
    State("mb-cpx-switch","value"),             # false,true -> 0,1
    State("limit-ca-opx-id","value"),           # ON,OFF -> 0,1
    State("ca-opx-val-id","value"),             # 0.0-1.0 -> 0,1

    State("tmin-id","value"),                   # tmin
    State("tmax-id","value"),                   # tmax
    State("pmin-id","value"),                   # pmin
    State("pmax-id","value"),                   # pmax

    State("fixed-temperature-val-id","value"),  # fix T
    State("fixed-pressure-val-id","value"),     # fix P

    State("gsub-id","value"),                   # n subdivision
    State("refinement-dropdown","value"),       # ph,em
    State("refinement-levels","value"),         # level

    State("buffer-dropdown","value"),           # none,qfm,mw,qif,cco,hm,nno
    State("solver-dropdown","value"),           # pge,lp
    State("verbose-dropdown","value"),          # none,light,full -> -1,0,1

    State("table-bulk-rock","data"),            # bulk-rock 1
    State("table-2-bulk-rock","data"),          # bulk-rock 2
     
    State("buffer-1-mul-id","value"),           # buffer n 1
    State("buffer-2-mul-id","value"),           # buffer n 2

    State("test-dropdown", "value"),            # test number


    prevent_initial_call = true,

) do    n_clicks_mesh, colorm,  fieldname, grid,
        diagType,   dtb,        cpx,    limOpx, limOpxVal,
        tmin,       tmax,       pmin,   pmax,
        fixT,       fixP,
        sub,        refType,    refLvl,
        bufferType, solver,     verbose,
        bulk1,      bulk2,
        bufferN1,   bufferN2,
        test

    #________________________________________________________________________________________#
    # Diagram type dependent parameters
    if diagType == "pt"
        xtitle = "Temperature [Celsius]"
        ytitle = "Pressure [kbar]"
        Xrange          = (tmin,tmax)
        Yrange          = (pmin,pmax)
    elseif diagType == "px"
        Xrange          = (0.0,1.0)
        Yrange          = (pmin,pmax)
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Pressure [kbar]"
    else # diagType == "tx"
        Xrange          = (0.0,1.0) 
        Yrange          = (tmin,tmax)
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Temperature [Celsius]"
    end

    #________________________________________________________________________________________#
    # The next lines capture the identity of the button that has been pushed
    ctx = callback_context()
    if length(ctx.triggered) == 0
        bid = ""
    else
        bid = split(ctx.triggered[1].prop_id, ".")[1]
    end

    # if we compute a new phase diagram
    if bid == "compute-button"
        n_ox    = length(bulk1);
        bulk_L  = zeros(n_ox); 
        bulk_R  = zeros(n_ox);
        oxi     = Vector{String}(undef, n_ox)
        for i=1:n_ox
            bulk_L[i]   = bulk1[i][:mol_fraction];
            bulk_R[i]   = bulk2[i][:mol_fraction];
            oxi[i]      = bulk1[i][:oxide];
        end
        #________________________________________________________________________________________#
        # Create coarse mesh
        cmesh           = t8_cmesh_quad_2d(COMM, Xrange, Yrange)

        # Refine coarse mesh (in a regular manner)
        level           = sub
        forest          = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, COMM)
        data            = get_element_data(forest)

        #________________________________________________________________________________________#
        # initialize database
        MAGEMin_data    =   Initialize_MAGEMin(dtb, verbose=false);
    
        nt = length(MAGEMin_data.gv);
        for i=1:nt
            if cpx == true && dtb =="mb"
                MAGEMin_data.gv[i].mbCpx = 1;
            end
            if limOpx == "CAOPX" && (db =="mb" || db =="ig" || db =="igd" || db =="alk")
                MAGEMin_data.gv[i].limitCaOpx   = 1;
                MAGEMin_data.gv[i].CaOpxLim     = limOpxVal;
            end
            MAGEMin_data.gv[i].verbose = -1;
        end

        #________________________________________________________________________________________#                      
        # initial optimization on regular grid
        Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  data, 
                                                        MAGEMin_data,
                                                        diagType,
                                                        Float64(fixT),
                                                        Float64(fixP),
                                                        oxi,
                                                        bulk_L,
                                                        bulk_R,    )
                     
        #________________________________________________________________________________________#     
        # Refine the mesh along phase boundaries
        global forest, data, Hash_XY, Out_XY, n_phase_XY
        for irefine = 1:refLvl
            # global forest, data, Hash_XY, Out_XY, n_phase_XY

            refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
            forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
            t = @elapsed Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(  data_new,
                                                                        MAGEMin_data,
                                                                        diagType,
                                                                        Float64(fixT),
                                                                        Float64(fixP),
                                                                        oxi,
                                                                        bulk_L,
                                                                        bulk_R,
                                                                        ind_map         = ind_map,
                                                                        Out_XY_old      = Out_XY,
                                                                        n_phase_XY_old  = n_phase_XY) # recompute points that have not been computed before

            println("Computed $(length(ind_map.<0)) new points in $t seconds")
            data    = data_new
            forest  = forest_new
        end

        #________________________________________________________________________________________#                   
        # Scatter plotly of the grid

        global field, idx, data_plot;

        np          = length(data.x)
        len_ox      = length(oxi)
        field       = Vector{Float64}(undef,np);
        idx         = Vector{Int64}(undef,length(field));
        for i=1:np
            field[i] = Float64(len_ox - n_phase_XY[i] + 2);
        end

        idx         = ((field.-minimum(field))./(maximum(field).-minimum(field)).*255.0).+ 1.0;
        idx         = [floor(Int,x) for x in idx];
        data_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, length(data.x));

        layout = Layout(
                    title=attr(
                        text = db[(db.db .== dtb), :].title[test+1],
                        x=0.5,
                        xanchor= "center",
                        yanchor= "top"
                    ),

                    xaxis_title = xtitle,
                    yaxis_title = ytitle,
                    yaxis_range = [Yrange...],
                    xaxis_range = [Xrange...],
                    xaxis_showgrid=false, yaxis_showgrid=false,
                    width       = 800,
                    height      = 800
                )

        for i = 1:length(data.x)
                data_plot[i] = scatter( x           = data.x[i],
                                        y           = data.y[i],
                                        mode        = "lines",
                                        fill        = "toself",
                                        fillcolor   = colormaps[:roma][idx[i]][2],
                                        line_color  = "#000000",
                                        line_width  = 1,

                # customize what is shown upon hover:
                text        = "Stable phases $(Out_XY[i].ph) ",
                hoverinfo   = "text",
                showlegend  = false     )
        end

        fig = plot(data_plot,layout)

    #if we want to modify the colomap
    elseif bid == "colormaps_cross"

        layout = Layout(
                    title=attr(
                        text = db[(db.db .== dtb), :].title[test+1],
                        x=0.5,
                        xanchor= "center",
                        yanchor= "top"
                    ),

                    xaxis_title = xtitle,
                    yaxis_title = ytitle,
                    yaxis_range = [Yrange...],
                    xaxis_range = [Xrange...],
                    xaxis_showgrid=false, yaxis_showgrid=false,
                    width       = 800,
                    height      = 800
                )

        for i = 1:length(data.x)
                data_plot[i] = scatter( x           = data.x[i],
                                        y           = data.y[i],
                                        mode        = "lines",
                                        fill        = "toself",
                                        fillcolor   = colormaps[Symbol(colorm)][idx[i]][2],
                                        line_color  = "#000000",
                                        line_width  = 1,

                # customize what is shown upon hover:
                text        = "Stable phases $(Out_XY[i].ph) ",
                hoverinfo   = "text",
                showlegend  = false     )
        end
        fig = plot(data_plot,layout)
    elseif bid == "fields-dropdown"

        np          = length(data.x)
        len_ox      = length(bulk1);

        if fieldname == "nsp"
            for i=1:np
                field[i] = Float64(length(Out_XY[i].ph));
            end
        elseif fieldname == "nvar"
            for i=1:np
                field[i] = Float64(len_ox - n_phase_XY[i] + 2.0);
            end
        else
            for i=1:np
                field[i] = Float64(get_property(Out_XY[i], fieldname));
            end
        end

        # idx         = Vector{Int64}(undef,length(field));
        idx         = ((field.-minimum(field))./(maximum(field).-minimum(field)).*255.0).+ 1.0;
        idx         = [floor(Int,x) for x in idx];
        data_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, length(data.x));

        layout = Layout(
                    title=attr(
                        text = db[(db.db .== dtb), :].title[test+1],
                        x=0.5,
                        xanchor= "center",
                        yanchor= "top"
                    ),

                    xaxis_title     = xtitle,
                    yaxis_title     = ytitle,
                    yaxis_range     = [Yrange...],
                    xaxis_range     = [Xrange...],
                    xaxis_showgrid  = false, 
                    yaxis_showgrid  = false,
                    width           = 800,
                    height          = 800
                )

        for i = 1:length(data.x)
                data_plot[i] = scatter( x           = data.x[i],
                                        y           = data.y[i],
                                        mode        = "lines",
                                        fill        = "toself",
                                        fillcolor   = colormaps[Symbol(colorm)][idx[i]][2],
                                        line_color  = "#000000",
                                        line_width  = 1,

                # customize what is shown upon hover:
                text        = "Stable phases $(Out_XY[i].ph) ",
                hoverinfo   = "text",
                showlegend  = false     )
        end
        fig = plot(data_plot,layout)
    elseif bid == "hide-grid"

        if length(grid) == 1
            layout = Layout(
                title=attr(
                    text = db[(db.db .== dtb), :].title[test+1],
                    x=0.5,
                    xanchor= "center",
                    yanchor= "top"
                ),

                xaxis_title     = xtitle,
                yaxis_title     = ytitle,
                yaxis_range     = [Yrange...],
                xaxis_range     = [Xrange...],
                xaxis_showgrid  = false, 
                yaxis_showgrid  = false,
                width           = 800,
                height          = 800
            )

            for i = 1:length(data.x)
                    data_plot[i] = scatter( x           = data.x[i],
                                            y           = data.y[i],
                                            mode        = "lines",
                                            fill        = "toself",
                                            fillcolor   = colormaps[Symbol(colorm)][idx[i]][2],
                                            line_color  = "#000000",
                                            line_width  = 1,

                    # customize what is shown upon hover:
                    text        = "Stable phases $(Out_XY[i].ph) ",
                    hoverinfo   = "text",
                    showlegend  = false     )
            end
            fig = plot(data_plot,layout)
        else
            layout = Layout(
                title=attr(
                    text = db[(db.db .== dtb), :].title[test+1],
                    x=0.5,
                    xanchor= "center",
                    yanchor= "top"
                ),

                xaxis_title     = xtitle,
                yaxis_title     = ytitle,
                yaxis_range     = [Yrange...],
                xaxis_range     = [Xrange...],
                xaxis_showgrid  = false, 
                yaxis_showgrid  = false,
                width           = 800,
                height          = 800
            )

            for i = 1:length(data.x)
                    data_plot[i] = scatter( x           = data.x[i],
                                            y           = data.y[i],
                                            mode        = "lines",
                                            fill        = "toself",
                                            fillcolor   = colormaps[Symbol(colorm)][idx[i]][2],
                                            line_color  = colormaps[Symbol(colorm)][idx[i]][2],
                                            line_width  = 2,

                    # customize what is shown upon hover:
                    text        = "Stable phases $(Out_XY[i].ph) ",
                    hoverinfo   = "text",
                    showlegend  = false     )
            end
            fig = plot(data_plot,layout)
        end
    else
        fig = plot()
    end

    return fig        
end


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