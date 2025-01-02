function Tab_TraceElement_Callbacks(app)

    # clickData callback
    callback!(
        app,
        Output("ree-spectrum-te",           "figure"    ),
        Output("ree-spectrum-te",           "config"    ),
        Output("click-data-left-spectrum",  "children"  ),
        Input("phase-diagram-te",           "clickData" ),
        Input("normalization-te",           "n_clicks"  ),
        Input("normalization-te",           "value"     ),
        Input("show-spectrum-te",           "n_clicks"  ),
        Input("show-spectrum-te",           "value"     ),
        
        prevent_initial_call = true,

    ) do click_info, norn_click, norm, show_click, show_type

        global point_id_te

        sp  = click_info[:points][][:text]
        tmp = match(r"#([^# ]+)#", sp)

        customTitle = "Rare Earth Elements spectrum"

        layout_ree = get_layout_ree(norm, show_type)
           
        if tmp !== nothing
            point_id_te = tmp.match
            point_id_te = parse(Int64,replace.(point_id_te,r"#"=>""))

            data_ree_plot = get_data_ree_plot(point_id_te, norm, show_type)
            fig_ree = plot(data_ree_plot,layout_ree)

            config   = PlotConfig(    toImageButtonOptions  = attr(     name     = "Download as svg",
                                                                        format   = "svg",
                                                                        filename =  replace(customTitle, " " => "_"),
                                                                        height   =  220,
                                                                        width    =  900,
                                                                        scale    =  2.0,       ).fields)

            infos = "\n"
            infos *= "| Variable &nbsp;|Value &nbsp; &nbsp; &nbsp; &nbsp;| Unit &nbsp; &nbsp; &nbsp; &nbsp;|\n"
            infos *= "|----------|-------|------|\n"
            infos *= "| P |"*string(round(Out_XY[point_id_te].P_kbar; digits = 3))*"| kbar |\n"
            infos *= "| T |"*string(round(Out_XY[point_id_te].T_C; digits = 3))*"| °C |\n"
            infos *= "| X |"*string(round(Out_XY[point_id_te].X[1]; digits = 3))*"| -  |\n"
            infos *= "| G |"*string(round(Out_XY[point_id_te].G_system; digits = 3))*"| kJ |\n"
            infos *= "| ρ_sys |"*string(round(Out_XY[point_id_te].rho; digits = 1))*"| kg/m³   |\n"
        end

        return fig_ree, config, infos
    end



    callback!(
        app,
        Output("show-zircon-id",            "style"),
        Output("show-trace-element-id",     "style"),
        Output("phase-te-info-id",          "children"), 
        Input("field-type-dropdown-te",     "value"),
    ) do value
    
        if @isdefined(all_TE_ph)
             tmp = join(all_TE_ph, " ")

             phase_te_list = "**"*"M S "*tmp*"**"
        else
            phase_te_list = " "
        end

        if value == "zr"
            style   = Dict("display" => "block")
            style2  = Dict("display" => "none")
        else 
            style   = Dict("display" => "none")
            style2  = Dict("display" => "block")
        end
        return style, style2, phase_te_list
    end




    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output("calc-1-id-te",              "style"   ),
        Output("fields-dropdown-zr-id-te",  "style"   ),
        Input("field-type-te-dropdown", "value"   ),

        prevent_initial_call = false,         # we have to load at startup, so one minimzation is achieved
    ) do field
        bid         = pushed_button( callback_context() ) 

        if field == "te"
            style_te    = Dict("display" => "block")
            style_zr    = Dict("display" => "none")
        else
            style_te    = Dict("display" => "none")
            style_zr    = Dict("display" => "block")
        end

        return style_te, style_zr
    end



    callback!(app,
        Output("show-grid-te",              "value"     ), 
        Output("show-full-grid-te",         "value"     ), 
        Output("pd-legend-te",              "figure"    ),
        Output("pd-legend-te",              "config"    ),
        Output("phase-diagram-te",          "figure"    ),
        Output("phase-diagram-te",          "config"    ),
        Output("field-type-dropdown-te",    "value"     ),
        Output("min-color-id-te",           "value"     ),
        Output("max-color-id-te",           "value"     ),
        Output("isopleth-dropdown-te",      "options"   ),
        Output("hidden-isopleth-dropdown-te",     "options"),
        Output("stable-assemblage-id-te",   "children"),   
        Output("show-text-list-id-te",         "style"),
        Output("output-loading-id-te",         "children"),

        Input("load-button-te",             "n_clicks"  ),
        Input("compute-display-te",         "n_clicks"  ),
        Input("fields-dropdown-zr",         "value"     ),

        Input("show-grid-te",               "value"     ), 
        Input("show-full-grid-te",          "value"     ), 
        Input("show-lbl-id-te",             "value"     ),

        Input("button-add-isopleth-te",        "n_clicks"),
        Input("button-remove-isopleth-te",     "n_clicks"),
        Input("button-remove-all-isopleth-te", "n_clicks"),
        Input("button-hide-isopleth-te",       "n_clicks"),
        Input("button-show-isopleth-te",       "n_clicks"),
        Input("button-show-all-isopleth-te",   "n_clicks"),
        Input("button-hide-all-isopleth-te",   "n_clicks"),

        Input("colormaps_cross-te",         "value"     ),
        Input("smooth-colormap-te",         "value"     ),
        Input("range-slider-color-te",      "value"     ),
        Input("set-min-white-te",           "value"     ),
        Input("reverse-colormap-te",        "value"     ),

  
        Input("min-color-id-te",            "value"     ),
        Input("max-color-id-te",            "value"     ),

        Input("update-title-button",        "n_clicks"  ),
        State("title-id",                   "value"     ),
        State("tepm-dropdown",              "value"     ),
        State("input-te-id",                "value"     ),
        State("field-norm-te-id",           "value"     ),
        State("field-type-dropdown-te",     "value"     ),
        State("normalization-iso-te",       "value"     ),
        
        State("database-dropdown",      "value"         ),           # mp, mb, ig ,igd, um, alk
        State("diagram-dropdown",       "value"         ),           # pt, px, tx
        State("tmin-id",                "value"         ),           # tmin
        State("tmax-id",                "value"         ),           # tmax
        State("pmin-id",                "value"         ),           # pmin
        State("pmax-id",                "value"         ),           # pmax

        State("table-bulk-rock",        "data"          ),           # bulk-rock 1
        State("table-2-bulk-rock",      "data"          ),           # bulk-rock 2

        State("gsub-id",                "value"         ),           # n subdivision
        State("refinement-dropdown",    "value"         ),           # ph,em
        State("refinement-levels",      "value"         ),           # level

        State("fixed-temperature-val-id","value"        ),           # fix T
        State("fixed-pressure-val-id",  "value"         ),           # fix P
        State("solver-dropdown",        "value"         ),           # pge,lp
        State("buffer-dropdown",        "value"         ),           # none,qfm,mw,qif,cco,hm,nno
        State("buffer-1-mul-id",        "value"         ),           # buffer n 1
        State("buffer-2-mul-id",        "value"         ),           # buffer n 2
        State("pt-x-table",             "data"          ),

        State("isopleth-dropdown-te",   "options"       ),
        State("isopleth-dropdown-te",   "value"         ),
        State("hidden-isopleth-dropdown-te",      "options"),
        State("hidden-isopleth-dropdown-te",      "value"),
        State("field-type-te-dropdown", "value"         ),
        State("fields-dropdown-zr-te",   "value"        ),
        State("input-calc-id-te",       "value"         ),
        State("input-cust-id-te",       "value"         ),

        State("line-style-dropdown-te",    "value"),
        State("iso-line-width-id-te",      "value"),
        State("colorpicker_isoL-te",       "value"),
        State("iso-text-size-id-te",       "value"),
        State("iso-min-id-te",             "value"),
        State("iso-step-id-te",            "value"),
        State("iso-max-id-te",             "value"),
        State("stable-assemblage-id-te",   "children"), 

        prevent_initial_call = true,

        ) do    n,          n2,         fieldname,  
                grid,       full_grid,  lbl, 

                addIso,     removeIso,  removeAllIso,           isoShow,    isoHide, isoShowAll,    isoHideAll,

                colorMap,   smooth,     rangeColor, set_white, reverse,    minColor, maxColor,
                updateTitle,customTitle,tepm,       varBuilder, norm, type, norm_te,
                dtb,        diagType,   tmin,       tmax,       pmin,       pmax,
                bulk1,      bulk2,
                sub,        refType,    refLvl,
                fixT,       fixP,       solver,     bufferType, bufferN1,   bufferN2,   PTpath,
                isopleths_te,  isoplethsID_te, isoplethsHid_te,  isoplethsHidID_te, field, field_zr, calc, cust,

                isoLineStyle, isoLineWidth, isoColorLine, isoLabelSize,   
                minIso,     stepIso,    maxIso, txt_list

        xtitle, ytitle, Xrange, Yrange  = diagram_type(diagType, tmin, tmax, pmin, pmax) 
        bulk_L, bulk_R, oxi             = get_bulkrock_prop(bulk1, bulk2) 
        colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)              # get colormap information
        bid                             = pushed_button( callback_context() )                           # get the ID of the last pushed button
        fieldNames                      = ["data_plot_te","data_reaction","data_grid","data_isopleth_out_te"]
        field2plot                      = zeros(Int64,4)
        fieldType                       = type
        loading                         = ""
        field2plot[1]    = 1

        if @isdefined(Out_TE_XY) && length(Out_XY) == length(Out_TE_XY)
            if bid == "load-button-te"
                fieldType = "zr"
                global gridded_te, gridded_info_te, gridded_fields_te, X_te, Y_te, npoints_te, meant_te
                global layout_te, n_lbl, addedRefinementLvl
                global data_plot_te,  data_reaction_te, data_grid_te, PT_infos_te, data_isopleth_te, data_isopleth_out_te

                global iso_show_te             = 1;
                data_isopleth_te = initialize_g_isopleth_te(; n_iso_max = 32)

                gridded_te, gridded_info_te, gridded_fields_te, X_te, Y_te, npoints_te, meant_te = get_gridded_map(    fieldname,
                                                                                                    "zr",
                                                                                                    oxi,
                                                                                                    Out_XY,
                                                                                                    Out_TE_XY,
                                                                                                    Hash_XY,
                                                                                                    sub,
                                                                                                    refLvl + addedRefinementLvl,
                                                                                                    refType,
                                                                                                    data,
                                                                                                    Xrange,
                                                                                                    Yrange )

                minColor     = round(minimum(skipmissing(gridded_te)),digits=2); 
                maxColor     = round(maximum(skipmissing(gridded_te)),digits=2);  

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
                                                                PTpath,
                                                                "false")

                data_plot_te, annotations, txt_list = get_diagram_labels(   Out_XY,
                                                                            Hash_XY,
                                                                            refType,
                                                                            data,
                                                                            PT_infos_te )
                ticks       = 4
                frame       = get_plot_frame(Xrange,Yrange, ticks)                                  
                layout_te   = Layout(
                                images=frame,
                                title= attr(
                                    text    = customTitle,
                                    x       = 0.5,
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
                                width       = 720,
                                height      = 900,
                                autosize    = false,
                                margin      = attr(autoexpand = false, l=0, r=0, b=260, t=50, pad=1),
                                xaxis_range = Xrange, 
                                yaxis_range = Yrange,
                                xaxis       = attr(     tickmode    = "linear",
                                                        tick0       = Xrange[1],
                                                        dtick       = (Xrange[2]-Xrange[1])/(ticks+1),
                                                        fixedrange    = true,
                                                    ),
                                yaxis       = attr(     tickmode    = "linear",
                                                        tick0       = Yrange[1],
                                                        dtick       = (Yrange[2]-Yrange[1])/(ticks+1),
                                                        fixedrange    = true,
                                                ),
                            )
                                
                heat_map = heatmap( x               =  X_te,
                                    y               =  Y_te,
                                    z               =  gridded_te,
                                    zmin            =  minColor,
                                    zmax            =  maxColor,
                                    zsmooth         =  smooth,
                                    connectgaps     =  true,
                                    type            = "heatmap",
                                    colorscale      =  colorm,
                                    reversescale    =  reverseColorMap,
                                    colorbar_title  =  fieldname,
                                    hoverinfo       = "skip",
                                    showlegend      =  false,
                                    colorbar        =  attr(    lenmode         = "fraction",
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

            elseif bid == "set-min-white-te" || bid == "min-color-id-te" || bid == "max-color-id-te" || bid == "colormaps_cross-te" || bid == "smooth-colormap-te" || bid == "range-slider-color-te" || bid == "reverse-colormap-te"

                data_plot_te, layout_te =  update_colormap_phaseDiagram_te(     xtitle,     ytitle,     type,               varBuilder,   
                                                                                Xrange,     Yrange,     fieldname,
                                                                                dtb,        diagType,
                                                                                minColor,   maxColor,
                                                                                smooth,     colorm,     reverseColorMap, set_white                                                   )
            elseif bid == "compute-display-te"

                data_plot_te, layout_te =  update_diplayed_field_phaseDiagram_te(   xtitle,     ytitle,     "te",                  varBuilder, norm,
                                                                                    Xrange,     Yrange,     fieldname,
                                                                                    dtb,        oxi,
                                                                                    sub,        refLvl,
                                                                                    smooth,     colorm,     reverseColorMap, set_white,       refType                                 )
                                                                                    
                minColor     = round(minimum(skipmissing(gridded_te)),digits=2); 
                maxColor     = round(maximum(skipmissing(gridded_te)),digits=2);  

            elseif bid == "fields-dropdown-zr"

                data_plot_te, layout_te =  update_diplayed_field_phaseDiagram_te(   xtitle,     ytitle,     "zr",                  varBuilder, norm,
                                                                                    Xrange,     Yrange,     fieldname,
                                                                                    dtb,        oxi,
                                                                                    sub,        refLvl,
                                                                                    smooth,     colorm,     reverseColorMap, set_white,       refType                                 )
                minColor     = round(minimum(skipmissing(gridded_te)),digits=2); 
                maxColor     = round(maximum(skipmissing(gridded_te)),digits=2);  

            elseif bid == "show-grid-te"

                if grid == "true"
                    field2plot[2] = 1
                end

            elseif bid == "show-full-grid-te"

                if full_grid == "true"
                    field2plot[3] = 1
                end
            elseif bid == "button-add-isopleth-te"

                data_isopleth_te, isopleths_te = add_isopleth_phaseDiagram_te(  Xrange,         Yrange,
                                                                                sub,            refLvl,
                                                                                dtb,            oxi,
                                                                                isopleths_te,   field, field_zr, calc, cust, norm_te,
                                                                                isoLineStyle,   isoLineWidth, isoColorLine,           isoLabelSize,   
                                                                                minIso,     stepIso,    maxIso                      )
                data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                field2plot[4] = 1
                iso_show_te   = 1

            elseif bid == "button-hide-isopleth-te"

                if (isoplethsID_te) in data_isopleth_te.active
                    data_isopleth_te, isopleths_te, isoplethsHid_te = hide_single_isopleth_phaseDiagram_te(isoplethsID_te)
                    data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                    field2plot[4] = 1
                else
                    println("Cannot hide isopleth, did you select one?")
                    data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                    field2plot[4] = 1
                end
            elseif bid == "button-show-isopleth-te"
    
                if (isoplethsHidID_te) in data_isopleth_te.hidden
                    data_isopleth_te, isopleths_te, isoplethsHid_te = show_single_isopleth_phaseDiagram_te(isoplethsHidID_te)
                    data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                    field2plot[4] = 1
                else
                    println("Cannot show isopleth, did you select one?")
                    data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                    field2plot[4] = 1
                end
            elseif bid == "button-remove-isopleth-te"

                if (isoplethsID_te) in data_isopleth_te.active
                    if data_isopleth_te.n_iso > 1
                        data_isopleth_te, isopleths_te = remove_single_isopleth_phaseDiagram_te(isoplethsID_te)
                        data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                        field2plot[4] = 1
                    else
                        data_isopleth_te, isopleths_te, data_plot_te = remove_all_isopleth_phaseDiagram_te()
                    end

                else
                    print("cannot remove isopleth, did you select one?")
                    data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                    field2plot[4] = 1
                end
    
            elseif bid == "button-remove-all-isopleth-te"
    
                data_isopleth_te, isopleths_te, isoplethsHid_te, data_plot_te = remove_all_isopleth_phaseDiagram_te()
    
            elseif bid == "button-show-all-isopleth-te"
    
                iso_show_te          = 1
                data_isopleth_out_te = data_isopleth_te.isoP[data_isopleth_te.active]
                field2plot[4] = 1
    
            elseif bid == "button-hide-all-isopleth-te"
    
                iso_show_te          = 0
            elseif bid == "update-title-button"
                    layout_te[:title] = attr(
                        text    = customTitle,
                        x       = 0.4,
                        xanchor = "center",
                        yanchor = "top"
                    )
            else
                fig_te = plot()
                print("Compute a phase diagram with activated trace-element in the Setup tab first!\n")
            end


            if lbl == "true"
                for i=1:n_lbl+1
                    layout_te[:annotations][i][:visible] = true
                end
                show_text_list  = Dict("display" => "block")  
            else
                for i=1:n_lbl+1
                    layout_te[:annotations][i][:visible] = false
                end
                show_text_list  = Dict("display" => "none")  
            end  
    
            # check state of unchanged variables ["data_plot","data_reaction","data_grid","data_isopleth_out_te"]
            if grid == "true"
                field2plot[2] = 1
            end
            if full_grid == "true"
                field2plot[3] = 1
            end
            if data_isopleth_te.n_iso > 0 && iso_show_te == 1
                field2plot[4] = 1
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
                                                                        format   = "svg",
                                                                        filename =  replace(customTitle, " " => "_"),
                                                                        height   =  900,
                                                                        width    =  720,
                                                                        scale    =  2.0,       ).fields)
    
            layoutCap = Layout(     height          =  30,        
                                    plot_bgcolor    = "white", 
                                    paper_bgcolor   = "white", 
                                    title           = "",
                                    xaxis           = attr(showticklabels=false),
                                    yaxis           = attr(showticklabels=false),
                                    legend=attr(
                                        x           =  0.05,             
                                        xanchor     = "left",
                                        orientation = "h"
                                    ))
                                    
            if field2plot[4] == 0
                fig_cap = plot(layoutCap)
            else
                fig_cap = plot(data_isopleth_te.isoCap[data_isopleth_te.active],layoutCap)
            end
            config_cap  = PlotConfig(    toImageButtonOptions  = attr(      name     = "Download as svg",
                                                                            format   = "svg",
                                                                            filename =  (replace(customTitle, " " => "_"))*"_TE_label",
                                                                            height   =  30,
                                                                            width    =  900,
                                                                            scale    =  2.0,       ).fields)
    
            return grid, full_grid, fig_cap, config_cap, fig_te, config, fieldType, minColor, maxColor, isopleths_te, isoplethsHid_te, txt_list, show_text_list, loading
        else
            return no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
            print("Compute a phase diagram with activated trace-element in the Setup tab first!\n")
        end

        # if lbl == "true"
        #     for i=1:n_lbl+1
        #         layout_te[:annotations][i][:visible] = true
        #     end
        #     show_text_list  = Dict("display" => "block")  
        # else
        #     for i=1:n_lbl+1
        #         layout_te[:annotations][i][:visible] = false
        #     end
        #     show_text_list  = Dict("display" => "none")  
        # end  

        # # check state of unchanged variables ["data_plot","data_reaction","data_grid","data_isopleth_out_te"]
        # if grid == "true"
        #     field2plot[2] = 1
        # end
        # if full_grid == "true"
        #     field2plot[3] = 1
        # end
        # if data_isopleth_te.n_iso > 0 && iso_show_te == 1
        #     field2plot[4] = 1
        # end

        # # Fetch the fields to display
        # if sum(field2plot) == 0
        #     fig = plot()
        # else
        #     data_all = eval(Symbol(fieldNames[1]))
        #     np       = length(field2plot)

        #     for i=2:np
        #         if field2plot[i] == 1
        #             data_all = vcat( data_all, eval(Symbol(fieldNames[i])) )
        #         end
        #     end

        #     fig_te = plot_diagram(data_all,layout_te)
        # end


        # config   = PlotConfig(    toImageButtonOptions  = attr(     name     = "Download as svg",
        #                                                             format   = "svg",
        #                                                             filename =  replace(customTitle, " " => "_"),
        #                                                             height   =  900,
        #                                                             width    =  720,
        #                                                             scale    =  2.0,       ).fields)

        # layoutCap = Layout(     height          =  30,        
        #                         plot_bgcolor    = "white", 
        #                         paper_bgcolor   = "white", 
        #                         title           = "",
        #                         xaxis           = attr(showticklabels=false),
        #                         yaxis           = attr(showticklabels=false),
        #                         legend=attr(
        #                             x           =  0.05,             
        #                             xanchor     = "left",
        #                             orientation = "h"
        #                         ))
                                
        # if field2plot[4] == 0
        #     fig_cap = plot(layoutCap)
        # else
        #     fig_cap = plot(data_isopleth_te.isoCap[data_isopleth_te.active],layoutCap)
        # end
        # config_cap  = PlotConfig(    toImageButtonOptions  = attr(      name     = "Download as svg",
        #                                                                 format   = "svg",
        #                                                                 filename =  (replace(customTitle, " " => "_"))*"_TE_label",
        #                                                                 height   =  30,
        #                                                                 width    =  900,
        #                                                                 scale    =  2.0,       ).fields)


        # return grid, full_grid, fig_cap, config_cap, fig_te, config, fieldType, minColor, maxColor, isopleths_te, isoplethsHid_te, txt_list, show_text_list, loading
            
    end


    #save all table to file
    callback!(
        app,
        # Output("download-all-table-text", "data"),
        Output("data-all-table-save-te", "is_open"),
        Output("data-all-save-table-failed-te", "is_open"),
        Input("save-all-table-button-te", "n_clicks"),
        State("Filename-all-id-te", "value"),
        State("database-dropdown","value"),
        State("kds-dropdown","value"),
        State("zrsat-dropdown","value"),
    
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb, kds, zrsat

        if fname != "filename"
            datab   = "_"*dtb*"_"*kds*"_"*zrsat
            fileout = fname*datab

            MAGEMin_dataTE2dataframe(Out_XY,Out_TE_XY,dtb,fileout)
            return "success", ""
        else
            return  "", "failed"
        end
    end


    #save all table to file
    callback!(
        app,
        # Output("download-all-table-text", "data"),
        Output("data-point-table-save-te", "is_open"),
        Output("data-point-save-table-failed-te", "is_open"),
        Input("save-point-table-button-te", "n_clicks"),
        State("Filename-point-id-te", "value"),
        State("database-dropdown","value"),
        State("kds-dropdown","value"),
        State("zrsat-dropdown","value"),
    
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb, kds, zrsat

        if fname != "filename"
            P       = "_Pkbar_"*string(Out_XY[point_id_te].P_kbar)
            T       = "_TC_"*string(Out_XY[point_id_te].T_C)
            datab   = "_"*dtb*P*T*"_"*kds*"_"*zrsat
            fileout = fname*datab

            MAGEMin_dataTE2dataframe(Out_XY[point_id_te],Out_TE_XY[point_id_te],dtb,fileout)
            return "success", ""
        else
            return  "", "failed"
        end
    end

    #save references to bibtex
    callback!(
        app,
        Output("export-citation-save-te", "is_open"),
        Output("export-citation-failed-te", "is_open"),
        Input("export-citation-button-te", "n_clicks"),
        State("export-citation-id-te", "value"),
        State("kds-dropdown","value"),
        State("zrsat-dropdown","value"),

        prevent_initial_call=true,

    ) do n_clicks, fname, kds, zrc

        if fname != "filename"
            output_bib      = "_"*kds*".bib"
            fileout         = fname*output_bib
            magemin         = "MAGEMin"
            bib             = import_bibtex("./references/references.bib")
            
            print("\nSaving references for computed trace-element diagram\n")
            print("output path: $(pwd())\n")

            n_ref           = length(bib.keys)

            selection       = String[]

            id_zrc          = findfirst(bib[bib.keys[i]].fields["info"] .== zrc for i=1:n_ref)
            id_kds          = findfirst(bib[bib.keys[i]].fields["info"] .== kds for i=1:n_ref)
            id_magemin      = findfirst(bib[bib.keys[i]].fields["info"] .== magemin for i=1:n_ref)
            
            push!(selection, String(bib.keys[id_kds]))
            push!(selection, String(bib.keys[id_zrc]))
            push!(selection, String(bib.keys[id_magemin]))

            selected_bib    = Bibliography.select(bib, selection)
            
            export_bibtex(fileout, selected_bib)

            return "success", ""
        else
            return  "", "failed"
        end
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

    callback!(app,
        Output("collapse-spectrum", "is_open"),
        [Input("button-spectrum", "n_clicks")],
        [State("collapse-spectrum", "is_open")], ) do  n, is_open
        
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