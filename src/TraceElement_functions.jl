"""
    Retrieve layout for rare earth elements figure
"""
function get_layout_ree(customTitle)

    layout_ree      =  Layout(
        title= attr(
            text    = customTitle,
            x       = 0.4,
            xanchor = "center",
            yanchor = "top"
        ),
        font        = attr(size = 10),
        height      = 240,
        margin      = attr(autoexpand = false, l=16, r=16, b=10, t=16),
        autosize    = false,
        xaxis_title = "Rare Earth Element",
        yaxis_title = "Concentration [μg/g]",
        # xaxis_range = [Xmin,Xmax], 
        # yaxis_range = [Ymin,Ymax],
        # annotations = annotations,
        showlegend  = false,
    )

    return layout_ree
end


"""
    update_colormap_phaseDiagram(      xtitle,     ytitle,     
                                                Xrange,     Yrange,     fieldname,
                                                dtb,        diagType,
                                                smooth,     colorm,     reverseColorMap,
                                                test                                  )
    Updates the colormap configuration of the phase diagram
"""
function update_colormap_phaseDiagram_te(       xtitle,     ytitle,     type,       varBuilder,
                                                Xrange,     Yrange,     fieldname, 
                                                dtb,        diagType,
                                                smooth,     colorm,     reverseColorMap)
    global PT_infos_te, layout_te

    if type == "te"
        fieldname = varBuilder
    end

    data_plot_te[1] = heatmap(  x               =  X_te,
                                y               =  Y_te,
                                z               =  gridded_te,
                                zsmooth         =  smooth,
                                connectgaps     =  true,
                                type            = "heatmap",
                                colorscale      =  colorm,
                                colorbar_title  =  fieldname,
                                reversescale    =  reverseColorMap,
                                hoverinfo       = "skip",
                                colorbar        = attr(     lenmode         = "fraction",
                                                            len             =  0.75,
                                                            thicknessmode   = "fraction",
                                                            tickness        =  0.5,
                                                            x               =  1.005,
                                                            y               =  0.5         ),)

    return data_plot_te, layout_te
end


"""
    update_diplayed_field_phaseDiagram(   xtitle,     ytitle,     
                                                    Xrange,     Yrange,     fieldname,
                                                    dtb,        oxi,
                                                    sub,        refLvl,
                                                    smooth,     colorm,     reverseColorMap,
                                                    test                                  )
    Updates the field displayed
"""
function  update_diplayed_field_phaseDiagram_te(    xtitle,     ytitle,     type,                  varBuilder,
                                                    Xrange,     Yrange,     fieldname,
                                                    dtb,        oxi,
                                                    sub,        refLvl,
                                                    smooth,     colorm,     reverseColorMap,       refType )

    global data, Out_XY, Out_TE_XY, data_plot_te, gridded_te, gridded_info_te, X_te, Y_te, PhasesLabels, addedRefinementLvl, PT_infos_te, layout_te

    gridded_te, X_te, Y_te, npoints, meant = get_gridded_map_no_lbl(    fieldname,
                                                                        type,
                                                                        varBuilder,
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
                                                                        Yrange )

    if type == "te"
        fieldname = varBuilder
    end
    
    data_plot_te[1] = heatmap(  x               = X_te,
                                y               = Y_te,
                                z               = gridded_te,
                                zsmooth         = smooth,
                                connectgaps     = true,
                                type            = "heatmap",
                                colorscale      = colorm,
                                colorbar_title  = fieldname,
                                reversescale    = reverseColorMap,
                                hoverinfo       = "skip",
                                # hoverinfo       = "text",
                                # text            = gridded_info,
                                colorbar        = attr(     lenmode         = "fraction",
                                                            len             =  0.75,
                                                            thicknessmode   = "fraction",
                                                            tickness        =  0.5,
                                                            x               =  1.005,
                                                            y               =  0.5         ),)

    return data_plot_te, layout_te
end
