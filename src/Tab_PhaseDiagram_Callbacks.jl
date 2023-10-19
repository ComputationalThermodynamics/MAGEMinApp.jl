function Tab_PhaseDiagram_Callbacks(app)

    #save all to file
    callback!(
        app,
        Output("download-all-text", "data"),
        Output("data-all-save", "children"),
        Input("save-all-button", "n_clicks"),
        State("Filename-all-id", "value"),
        State("database-dropdown","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "... filename ..."
            datab   = "_"*dtb
            fileout = fname*datab*".txt"
            file    = save_all_to_file(dtb)            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "Successfully saved all points information"
        else
            return nothing, "Provide a valid filename (without extension)"
        end
    end

    # save to file
    callback!(
        app,
        Output("download-text", "data"),
        Output("data-eq-save", "children"),
        Input("save-eq-button", "n_clicks"),
        State("Filename-eq-id", "value"),
        State("database-dropdown","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "... filename ..."
            P       = "_Pkbar_"*string(Out_XY[point_id].P_kbar)
            T       = "_TC_"*string(Out_XY[point_id].T_C)
            datab   = "_"*dtb
            fileout = fname*datab*P*T*".txt"
            file    = save_equilibrium_to_file(Out_XY[point_id])            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "Successfully saved equilibrium point information"
        else
            return nothing, "Provide a valid filename (without extension)"
        end
    end

    # clickData callback
    callback!(
        app,
        Output("click-data", "value"),
        Input("phase-diagram", "clickData"),
        State("diagram-dropdown","value"),          # pt,px,tx
        prevent_initial_call = true,
    ) do click_info, diagType

        global point_id

        sp  = click_info[:points][][:text]
        tmp = match(r"#([^# ]+)#", sp)
        if tmp !== nothing
            point_id = tmp.match
            point_id = parse(Int64,replace.(point_id,r"#"=>""))

            X       = "Composition\t[mol]\t: "*string(round.(Out_XY[point_id].bulk; digits = 3))*"\n"
            P       = "Pressure\t\t[°C]\t\t: "*string(round(Out_XY[point_id].P_kbar; digits = 3))*"\n"
            T       = "Temperature\t[kbar]\t: "*string(round(Out_XY[point_id].T_C; digits = 3))*"\n"
            Gsys    = "Gibbs energy\t[kJ]\t\t: "*string(round(Out_XY[point_id].G_system; digits = 3))*"\n"
            StPhase = "Stable phases\t[str]\t: "*string(Out_XY[point_id].ph)*"\n"
            PhFrac  = "Phases fraction\t[mol]\t: "*string(round.(Out_XY[point_id].ph_frac; digits = 3))*"\n"
            RhoSys  = "ρ_system\t\t[kg/m^3]: "*string(round(Out_XY[point_id].rho; digits = 3))*"\n"

            p       = X*P*T*Gsys*StPhase*PhFrac*RhoSys
        else
            p       = "there is a problem with the point information, the id has not been found\n"
        end

        return p
    end

    # Callback function to create compute the phase diagram using T8code for Adaptive Mesh Refinement
    callback!(
        app,
        Output("phase-diagram","figure"),
        Output("show-grid","value"),
        Output("npoints-id","value"),
        Output("meant-id","value"),

        Input("compute-button","n_clicks"),
        Input("refine-pb-button","n_clicks"),

        Input("colormaps_cross","value"),
        Input("smooth-colormap","value"),
        Input("range-slider-color","value"),
        Input("reverse-colormap","value"),
        Input("fields-dropdown","value"),
        Input("show-grid","value"),                 # show edges checkbox

        State("npoints-id","value"),                # total number of computed points
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

    ) do    n_clicks_mesh, n_clicks_refine, 
            colorMap,   smooth,     rangeColor,     reverse,    fieldname,  grid,
            npoints,    diagType,   dtb,    cpx,    limOpx,     limOpxVal,
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
            Xrange          = (Float64(tmin),Float64(tmax))
            Yrange          = (Float64(pmin),Float64(pmax))
        elseif diagType == "px"
            Xrange          = (Float64(0.0),Float64(1.0))
            Yrange          = (Float64(pmin),Float64(pmax))
            xtitle = "Composition [X0 -> X1]"
            ytitle = "Pressure [kbar]"
        else # diagType == "tx"
            Xrange          = (Float64(0.0),Float64(1.0) )
            Yrange          = (Float64(tmin),Float64(tmax))
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


        #________________________________________________________________________________________#
        # Set some values

        # Here we change the range of the color map.
        if rangeColor == [1,9]
            colorm = colors[Symbol(colorMap)]
        else
            colorm = restrict_colorMapRange(colorMap,rangeColor)
        end

        if reverse == "false"
            reverseColorMap = false
        else
            reverseColorMap = true
        end

        n_ox    = length(bulk1);
        bulk_L  = zeros(n_ox); 
        bulk_R  = zeros(n_ox);
        oxi     = Vector{String}(undef, n_ox)
        for i=1:n_ox
            tmp = bulk1[i][:mol_fraction]
            if typeof(tmp) == String
                tmp = parse(Float64,tmp)
            end
            tmp2 = bulk2[i][:mol_fraction]
            if typeof(tmp2) == String
                tmp2 = parse(Float64,tmp2)
            end
            bulk_L[i]   = tmp;
            bulk_R[i]   = tmp2;
            oxi[i]      = bulk1[i][:oxide];
        end


        # if we compute a new phase diagram
        if bid == "compute-button"

            empty!(AppData.PseudosectionData);              #this empty the data from previous pseudosection computation


            #________________________________________________________________________________________#
            # Create coarse mesh
            cmesh           = t8_cmesh_quad_2d(MPI.COMM_WORLD, Xrange, Yrange)

            # Refine coarse mesh (in a regular manner)
            level           = sub
            forest          = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, MPI.COMM_WORLD)
            data            = get_element_data(forest)

            #________________________________________________________________________________________#
            # initialize database
            global MAGEMin_data
            global addedRefinementLvl  = 0;


            # set clinopyroxene for the metabasite database
            mbCpx = 0
            if cpx == true && dtb =="mb"
                mbCpx = 1;
            end
            limitCaOpx  = 0
            CaOpxLim    = 1.0
            if limOpx == "ON" && (dtb =="mb" || dtb =="ig" || dtb =="igd" || dtb =="alk")
                limitCaOpx   = 1
                CaOpxLim     = limOpxVal
            end

            MAGEMin_data    =   Initialize_MAGEMin( dtb;
                                                    verbose     = false,
                                                    limitCaOpx  = limitCaOpx,
                                                    CaOpxLim    = CaOpxLim,
                                                    mbCpx       = mbCpx);
        
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
            global field, data_plot, gridded, gridded_info, X, Y, meant, PhasesLabels

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
                                                                            n_phase_XY_old  = n_phase_XY    ) # recompute points that have not been computed before

                println("Computed $(length(ind_map.<0)) new points in $t seconds")
                data    = data_new
                forest  = forest_new
                
            end

            push!(AppData.PseudosectionData,Out_XY);

            #________________________________________________________________________________________#                   
            # Scatter plotly of the grid

            gridded, gridded_info, X, Y, npoints, meant, PhasesLabels = get_gridded_map(    fieldname,
                                                                                            oxi,
                                                                                            Out_XY,
                                                                                            sub,
                                                                                            refLvl,
                                                                                            data.xc,
                                                                                            data.yc,
                                                                                            data.x,
                                                                                            data.y,
                                                                                            Xrange,
                                                                                            Yrange )

            # print("PhasesLabels $PhasesLabels\n")
            layout = Layout(
                        title=attr(
                            text    = db[(db.db .== dtb), :].title[test+1],
                            x       = 0.5,
                            xanchor = "center",
                            yanchor = "top"
                        ),
                        plot_bgcolor = "#FFF",
                        paper_bgcolor = "#FFF",
                        xaxis_title = xtitle,
                        yaxis_title = ytitle,
                        annotations = PhasesLabels,
                        width       = 800,
                        height      = 800
                    )


            data_plot = heatmap(x               = X,
                                y               = Y,
                                z               = gridded,
                                zsmooth         = smooth,
                                type            = "heatmap",
                                colorscale      = colorm,
                                reversescale    = reverseColorMap,
                                colorbar_title  = fieldname,
                                hoverinfo       = "text",
                                text            = gridded_info   )

            fig         = plot(data_plot,layout)
            grid_out    = [""]

        # if we want to modify the colomap
        elseif bid == "refine-pb-button"

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
            addedRefinementLvl += 1;

            empty!(AppData.PseudosectionData)
            push!(AppData.PseudosectionData,Out_XY);
    
            #________________________________________________________________________________________#                   
            # Scatter plotly of the grid

            gridded, gridded_info, X, Y, npoints, meant, PhasesLabels = get_gridded_map(      fieldname,
                                                                                oxi,
                                                                                Out_XY,
                                                                                sub,
                                                                                refLvl + addedRefinementLvl,
                                                                                data.xc,
                                                                                data.yc,
                                                                                data.x,
                                                                                data.y,
                                                                                Xrange,
                                                                                Yrange )


            layout = Layout(
                        title=attr(
                            text    = db[(db.db .== dtb), :].title[test+1],
                            x       = 0.5,
                            xanchor = "center",
                            yanchor = "top"
                        ),

                        hoverlabel=attr(
                            bgcolor = "#FFF",
                        ),
                        plot_bgcolor = "#FFF",
                        paper_bgcolor = "#FFF",
                        xaxis_title = xtitle,
                        yaxis_title = ytitle,
                        annotations = PhasesLabels,
                        width       = 800,
                        height      = 800
                    )


            data_plot = heatmap(x               = X,
                                y               = Y,
                                z               = gridded,
                                zsmooth         =  smooth,
                                type            = "heatmap",
                                colorscale      = colorm,
                                colorbar_title  = fieldname,
                                reversescale    = reverseColorMap,
                                hoverinfo       = "text",
                                text            = gridded_info     )

            fig         = plot(data_plot,layout)
            grid_out    = [""]

        elseif bid == "colormaps_cross" || bid == "smooth-colormap" || bid == "range-slider-color" || bid == "reverse-colormap"

            layout = Layout(
                        title=attr(
                            text    = db[(db.db .== dtb), :].title[test+1],
                            x       = 0.5,
                            xanchor = "center",
                            yanchor = "top"
                        ),
                        plot_bgcolor = "#FFF",
                        paper_bgcolor = "#FFF",
                        xaxis_title = xtitle,
                        yaxis_title = ytitle,
                        annotations = PhasesLabels,
                        width       = 800,
                        height      = 800
                    )


            data_plot = heatmap(x               =  X,
                                y               =  Y,
                                z               =  gridded,
                                zsmooth         =  smooth,
                                type            = "heatmap",
                                colorscale      =  colorm,
                                colorbar_title  =  fieldname,
                                reversescale    = reverseColorMap,
                                hoverinfo       = "text",
                                text            = gridded_info     )

            fig         = plot(data_plot,layout)
            grid_out    = [""]
        elseif bid == "fields-dropdown"

            gridded, gridded_info, X, Y, npoints, meant, PhasesLabels = get_gridded_map(  fieldname,
                                                                            oxi,
                                                                            Out_XY,
                                                                            sub,
                                                                            refLvl + addedRefinementLvl,
                                                                            data.xc,
                                                                            data.yc,
                                                                            data.x,
                                                                            data.y,
                                                                            Xrange,
                                                                            Yrange )

            layout = Layout(
                        title=attr(
                            text    = db[(db.db .== dtb), :].title[test+1],
                            x       = 0.5,
                            xanchor = "center",
                            yanchor = "top"
                        ),
                        plot_bgcolor = "#FFF",
                        paper_bgcolor = "#FFF",
                        xaxis_title = xtitle,
                        yaxis_title = ytitle,
                        annotations = PhasesLabels,
                        width       = 800,
                        height      = 800
                    )


            data_plot = heatmap(x               = X,
                                y               = Y,
                                z               = gridded,
                                zsmooth         =  smooth,
                                type            = "heatmap",
                                colorscale      = colorm,
                                colorbar_title  = fieldname,
                                reversescale    = reverseColorMap,
                                hoverinfo       = "text",
                                text            = gridded_info     )

            fig         = plot(data_plot,layout)
            grid_out    = [""]
        elseif bid == "show-grid"
            layout = Layout(
                title=attr(
                    text    = db[(db.db .== dtb), :].title[test+1],
                    x       = 0.5,
                    xanchor = "center",
                    yanchor = "top"
                ),
                plot_bgcolor = "#FFF",
                paper_bgcolor = "#FFF",
                xaxis_title = xtitle,
                yaxis_title = ytitle,
                annotations = PhasesLabels,
                width       = 800,
                height      = 800
            )
            if length(grid) == 2
                data_plot_grid      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, length(data.x)+1);
                for i = 1:length(data.x)
                    data_plot_grid[i] = scatter(x           = data.x[i],
                                                y           = data.y[i],
                                                mode        = "lines",
                                                line_color  = "#000000",
                                                line_width  = 1,
                        showlegend  = false     )
                end

                data_plot_grid[length(data.x)+1] = heatmap( x               = X,
                                                            y               = Y,
                                                            z               = gridded,
                                                            zsmooth         =  smooth,
                                                            type            = "heatmap",
                                                            colorscale      = colorm,
                                                            colorbar_title  = fieldname,
                                                            reversescale    = reverseColorMap,
                                                            hoverinfo       = "text",
                                                            text            = gridded_info     )

                fig         = plot(data_plot_grid,layout)
                grid_out    = ["","GRID"]
            else
                data_plot = heatmap(x               = X,
                                    y               = Y,
                                    z               = gridded,
                                    zsmooth         =  smooth,
                                    type            = "heatmap",
                                    colorscale      = colorm,
                                    colorbar_title  = fieldname,
                                    reversescale    = reverseColorMap,
                                    hoverinfo       = "text",
                                    text            = gridded_info     )

                fig         = plot(data_plot,layout)
                grid_out    = [""]
            end
        else
            fig = plot()
        end

        return fig, grid_out, npoints, meant
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


    callback!(app,
        Output("collapse-infos-phase-diagram", "is_open"),
        [Input("infos-phase-diagram", "n_clicks")],
        [State("collapse-infos-phase-diagram", "is_open")], ) do  n, is_open
        
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