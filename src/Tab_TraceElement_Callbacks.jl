function Tab_TraceElement_Callbacks(app)


    callback!(
        app,
        Output("show-zircon-id",            "style"),
        Output("show-trace-element-id",     "style"),
        Input("field-type-dropdown-te",     "value"),
    ) do value
  
        if value == "zircon"
            style   = Dict("display" => "block")
            style2  = Dict("display" => "none")
        else 
            style   = Dict("display" => "none")
            style2  = Dict("display" => "block")
        end
        return style, style2
    end


    callback!(app,
        Output("show-grid-te",              "value"     ), 
        Output("show-full-grid-te",         "value"     ), 
        Output("phase-diagram-te",          "figure"    ),
        Output("phase-diagram-te",          "config"    ),
        Input("load-button-te",             "n_clicks"  ),
        Input("fields-dropdown-te",         "value"     ),

        Input("show-grid-te",               "value"     ), 
        Input("show-full-grid-te",          "value"     ), 
        Input("show-lbl-id-te",             "value"     ),

        Input("colormaps_cross-te",         "value"     ),
        Input("smooth-colormap-te",         "value"     ),
        Input("range-slider-color-te",      "value"     ),
        Input("reverse-colormap-te",        "value"     ),
        Input("update-title-button",        "n_clicks"  ),
        State("title-id",                   "value"     ),

        State("tepm-dropdown",              "value"     ),

        State("database-dropdown",      "value"),           # mp, mb, ig ,igd, um, alk
        State("diagram-dropdown",       "value"),           # pt, px, tx
        State("tmin-id",                "value"),           # tmin
        State("tmax-id",                "value"),           # tmax
        State("pmin-id",                "value"),           # pmin
        State("pmax-id",                "value"),           # pmax

        State("table-bulk-rock",        "data"),            # bulk-rock 1
        State("table-2-bulk-rock",      "data"),            # bulk-rock 2

        State("gsub-id",                "value"),           # n subdivision
        State("refinement-dropdown",    "value"),           # ph,em
        State("refinement-levels",      "value"),           # level

        State("fixed-temperature-val-id","value"),          # fix T
        State("fixed-pressure-val-id",  "value"),           # fix P
        State("solver-dropdown",        "value"),           # pge,lp
        State("buffer-dropdown",        "value"),           # none,qfm,mw,qif,cco,hm,nno
        State("buffer-1-mul-id",        "value"),           # buffer n 1
        State("buffer-2-mul-id",        "value"),           # buffer n 2
        State("pt-x-table",             "data"),

        prevent_initial_call = true,

        ) do    n,          fieldname,  
                grid,       full_grid,  lbl, 
                colorMap,   smooth,     rangeColor, reverse,
                updateTitle,customTitle,tepm,
                dtb,        diagType,   tmin,       tmax,       pmin,       pmax,
                bulk1,      bulk2,
                sub,        refType,    refLvl,
                fixT,       fixP,       solver,     bufferType, bufferN1,   bufferN2,   PTpath

        xtitle, ytitle, Xrange, Yrange  = diagram_type(diagType, tmin, tmax, pmin, pmax) 
        bulk_L, bulk_R, oxi             = get_bulkrock_prop(bulk1, bulk2) 
        colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)              # get colormap information
        bid                             = pushed_button( callback_context() )                           # get the ID of the last pushed button
        fieldNames                      = ["data_plot_te","data_reaction","data_grid"]
        field2plot                      = zeros(Int64,3)

        field2plot[1]    = 1
        if bid == "load-button-te"
            global gridded_te, gridded_info_te, X_te, Y_te, npoints_te, meant_te
            global layout_te, n_lbl, addedRefinementLvl
            global data_plot_te,  data_reaction_te, data_grid_te, PT_infos_te 

            gridded_te, gridded_info_te, X_te, Y_te, npoints_te, meant_te = get_gridded_map(    fieldname,
                                                                                                "te",
                                                                                                oxi,
                                                                                                Out_XY,
                                                                                                Out_TE_XY,
                                                                                                Hash_XY,
                                                                                                sub,
                                                                                                refLvl + addedRefinementLvl,
                                                                                                refType,
                                                                                                data.xc,
                                                                                                data.yc,
                                                                                                data.x,
                                                                                                data.y,
                                                                                                Xrange,
                                                                                                Yrange)


            PT_infos_te  = get_phase_diagram_information(   npoints_te,
                                                            dtb,
                                                            diagType,
                                                            solver,
                                                            bulk_L,
                                                            bulk_R,
                                                            oxi,
                                                            fixT,
                                                            fixP,
                                                            bufferType,
                                                            bufferN1,
                                                            bufferN2,
                                                            PTpath)

            data_plot_te, annotations = get_diagram_labels(     fieldname,
                                                                oxi,
                                                                Out_XY,
                                                                Hash_XY,
                                                                sub,
                                                                refLvl,
                                                                refType,
                                                                data.xc,
                                                                data.yc,
                                                                PT_infos_te )
            ticks       = 4
            frame       = get_plot_frame(Xrange,Yrange, ticks)                                  
            layout_te   = Layout(
                            images=frame,
                            title= attr(
                                text    = customTitle,
                                x       = 0.4,
                                xanchor = "center",
                                yanchor = "top"
                            ),
                            hoverlabel = attr(
                                bgcolor     = "#566573",
                                bordercolor = "#f8f9f9",
                            ),
                            plot_bgcolor = "#FFF",
                            paper_bgcolor = "#FFF",
                            xaxis_title = xtitle,
                            yaxis_title = ytitle,
                            annotations = annotations,
                            width       = 900,
                            height      = 900,
                            autosize    = false,
                            margin      = attr(autoexpand = false, l=50, r=280, b=260, t=70, pad=4),
                            xaxis_range = Xrange, 
                            yaxis_range = Yrange,
                            xaxis       = attr(     tickmode    = "linear",
                                                    tick0       = Xrange[1],
                                                    dtick       = (Xrange[2]-Xrange[1])/(ticks+1)
                                                ),
                            yaxis       = attr(     tickmode    = "linear",
                                                    tick0       = Yrange[1],
                                                    dtick       = (Yrange[2]-Yrange[1])/(ticks+1)
                                            ),
                        )
                            
            heat_map = heatmap( x               = X_te,
                                y               = Y_te,
                                z               = gridded_te,
                                zsmooth         = smooth,
                                connectgaps     = true,
                                type            = "heatmap",
                                colorscale      = colorm,
                                reversescale    = reverseColorMap,
                                colorbar_title  = fieldname,
                                hoverinfo       = "skip",
                                showlegend      = false,
                                colorbar        = attr(     lenmode         = "fraction",
                                                            len             =  0.75,
                                                            thicknessmode   = "fraction",
                                                            tickness        =  0.5,
                                                            x               =  1.005,
                                                            y               =  0.5         ),)

            hover_lbl = heatmap(    x               = X_te,
                                    y               = Y_te,
                                    z               = X_te,
                                    type            = "heatmap",
                                    showscale       = false,
                                    opacity         = 0.0,
                                    hoverinfo       = "text",
                                    showlegend      = false,
                                    text            = gridded_info_te )


            data_plot_te[1]    = heat_map

            data_reaction_te   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid_te       = show_hide_mesh_grid()

            data_plot_te       = vcat(data_plot_te,hover_lbl)

        elseif bid == "colormaps_cross-te" || bid == "smooth-colormap-te" || bid == "range-slider-color-te" || bid == "reverse-colormap-te"

            data_plot_te, layout_te =  update_colormap_phaseDiagram_te(     xtitle,     ytitle,     
                                                                            Xrange,     Yrange,     fieldname,
                                                                            dtb,        diagType,
                                                                            smooth,     colorm,     reverseColorMap                                                   )

        elseif bid == "fields-dropdown-te"

            data_plot_te, layout_te =  update_diplayed_field_phaseDiagram_te(   xtitle,     ytitle,     
                                                                                Xrange,     Yrange,     fieldname,
                                                                                dtb,        oxi,
                                                                                sub,        refLvl,
                                                                                smooth,     colorm,     reverseColorMap,       refType                                 )

        elseif bid == "show-grid-te"

            if grid == "true"
                field2plot[2] = 1
            end

        elseif bid == "show-full-grid-te"

            if full_grid == "true"
                field2plot[3] = 1
            end
        elseif bid == "show-lbl-id-te"

            if lbl == "true"
                for i=1:n_lbl+1
                    layout_te[:annotations][i][:visible] = true
                end
            else
                for i=1:n_lbl+1
                    layout_te[:annotations][i][:visible] = false
                end
            end         
        else
            fig_te = plot()
            print("Compute a phase diagram with activated trace-element in the Setup tab first!\n")
        end

        # check state of unchanged variables ["data_plot","data_reaction","data_grid","data_isopleth_out"]
        if grid == "true"
            field2plot[2] = 1
        end
        if full_grid == "true"
            field2plot[3] = 1
        end

        # Fetch the fields to display
        if sum(field2plot) == 0
            fig = plot()
        else
            data_all = eval(Symbol(fieldNames[1]))
            np       = length(field2plot)

            for i=2:np
                if field2plot[i] == 1
                    data_all = vcat( data_all, eval(Symbol(fieldNames[i])) )
                end
            end

            fig_te = plot_diagram(data_all,layout_te)
        end


        config   = PlotConfig(    toImageButtonOptions  = attr(     name     = "Download as svg",
                                                                    format   = "svg", # one of png, svg, jpeg, webp
                                                                    filename =  replace(customTitle, " " => "_"),
                                                                    height   =  900,
                                                                    width    =  900,
                                                                    scale    =  2.0,       ).fields)

        
        return grid, full_grid, fig_te, config
            
    end



    callback!(app,
        Output("collapse-opt-te", "is_open"),
        [Input("button-display-options-te", "n_clicks")],
        [State("collapse-opt-te", "is_open")], ) do  n, is_open
        
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
        Output("collapse-display-options-te", "is_open"),
        [Input("display-options-te-button", "n_clicks")],
        [State("collapse-display-options-te", "is_open")], ) do  n, is_open
        
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