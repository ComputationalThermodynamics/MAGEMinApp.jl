"""
    Retrieve layout for rare earth elements figure
"""
function get_layout_ree()

    layout_ree      =  Layout(
        font        = attr(size = 10),
        height      = 240,
        margin      = attr(autoexpand = false, l=12, r=16, b=8, t=32),
        autosize    = false,
        xaxis_title = "Rare Earth Element",
        yaxis_title = "Concentration log10[μg/g]",
        # xaxis_range = [Xmin,Xmax], 
        # yaxis_range = [Ymin,Ymax],
        # annotations = annotations,
        showlegend  = true,
    )

    return layout_ree
end


function get_data_ree_plot(point_id_te)

    ree     = ["La", "Ce", "Pr", "Nd", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"]
    n_ree   = length(ree)
    n_ph    = length(Out_TE_XY[point_id_te].ph_TE)

    data_ree_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph);

    names           = Vector{Union{String,Missing}}(undef, n_ph)
    compo_matrix    = Matrix{Union{Float64,Missing}}(undef, n_ph, n_ree) .= missing
    colormap        = get_jet_colormap(n_ph)

    ree_idx   = [findfirst(isequal(x), Out_TE_XY[point_id_te].elements) for x in ree];
    for i=1:n_ph
        names[i]            = Out_TE_XY[point_id_te].ph_TE[i]
        compo_matrix[i,:]   = Out_TE_XY[point_id_te].Cmin[i,ree_idx]
    end

    for k=1:n_ph

        data_ree_plot[k] =  scatter(;   x           = ree,
                                        y           = log10.(compo_matrix[k,:]),
                                        name        = names[k],
                                        mode        = "markers+lines",
                                        marker      = attr(     size    = 5.0,
                                                                color   = colormap[k]),

                                        line        = attr(     width   = 1.0,
                                                                color   = colormap[k])  )
    end

    return data_ree_plot
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
