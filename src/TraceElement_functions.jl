"""
    Retrieve layout for rare earth elements figure
"""
function get_layout_ree(norm,show_type)

    if show_type == "ree"
        xaxis_title = "Rare Earth Elements"
    elseif show_type == "all"
        xaxis_title = "Trace Elements"
    end
    layout_ree      =  Layout(
        font        = attr(size = 10),
        height      = 240,
        margin      = attr(autoexpand = false, l=12, r=12, b=8, t=32),
        autosize    = false,
        xaxis_title = xaxis_title,
        yaxis_title = "C"*show_type*"/"*norm*" log10[μg/g]",
        yaxis_type  = "log",
        showlegend  = true,
        dragmode    = false,

        xaxis       = attr(     fixedrange    = true,
                            ),
        yaxis       = attr(     fixedrange    = true,
                            ),
    )

    return layout_ree
end


function get_data_ree_plot(point_id_te, norm, show_type)

    ree             = ["La", "Ce", "Pr", "Nd", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"]
    te_chondrite    = ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc"]
    ppm_chondrite   = [2.3, 2.41,0.029,0.0074,0.24,0.0136,0.237,0.613,2.47,0.0928,7.25,0.457,3.82,0.103,0.148,0.0563,0.199,0.0361,0.246,1.57,0.0546,0.160,0.0247,0.161,0.0246,56,5.92]

    # chondrite   = [0.315, 0.813, 0.116, 0.597, 0.192, 0.072, 0.259, 0.049, 0.325, 0.073, 0.213, 0.03, 0.208, 0.032]

    if show_type == "ree"
        te      = ree
        te_idx  = [findfirst(isequal(x), Out_TE_XY[point_id_te].elements) for x in ree];
    elseif show_type == "all"
        te      = Out_TE_XY[point_id_te].elements
        te_idx  = [findfirst(isequal(x), Out_TE_XY[point_id_te].elements) for x in te_chondrite];
    end

    n_ree   = length(te_idx)

    Cph, C0, Csol, Cliq = 0,0,0,0
    n_traces = 0
    if ~isnothing(Out_TE_XY[point_id_te].ph_TE)
        n_ph_TE = length(Out_TE_XY[point_id_te].ph_TE)
        n_traces += n_ph_TE
        Cph    = 1
    end  

    if ~isnothing(Out_TE_XY[point_id_te].C0)
        n_traces += 1
        C0    = 1
    end  
    if ~isnothing(Out_TE_XY[point_id_te].Cliq)
        n_traces += 1
        Cliq  = 1
    end
    if ~isnothing(Out_TE_XY[point_id_te].Csol)
        n_traces += 1
        Csol  = 1
    end

    data_ree_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_traces);
    names           = Vector{Union{String,Missing}}(undef, n_traces)
    compo_matrix    = Matrix{Union{Float64,Missing}}(undef, n_traces, n_ree) .= missing
    colormap        = get_lines_colormap()

    # te_idx   = [findfirst(isequal(x), Out_TE_XY[point_id_te].elements) for x in ree];
    k = 1

    if show_type == "ree"
        if norm == "chondrite"
            C_norm = copy(ppm_chondrite[te_idx])
        elseif norm == "bulk"
            C_norm = copy(Out_TE_XY[point_id_te].C0[te_idx])
        end
    elseif show_type == "all"
        if norm == "chondrite"
            C_norm = copy(ppm_chondrite[te_idx])
        elseif norm == "bulk"
            C_norm = copy(Out_TE_XY[point_id_te].C0[te_idx])
        end
    end


    if Cph == 1 
        for i=1:n_ph_TE
            names[i]            = Out_TE_XY[point_id_te].ph_TE[i]
            compo_matrix[i,:]   = Out_TE_XY[point_id_te].Cmin[i,te_idx]

            data_ree_plot[k] =  scatter(;   x           = te,
                                            y           = compo_matrix[k,:]./C_norm,
                                            name        = names[k],
                                            mode        = "markers+lines",
                                            marker      = attr(     size    = 4.0,
                                                                    color   = colormap[k]),

                                            line        = attr(     width   = 1.0,
                                                                    color   = colormap[k])  )

            k += 1
        end
    end

    if C0 == 1
        names[k]            = "C0"
        compo_matrix[k,:]   = Out_TE_XY[point_id_te].C0[te_idx]

        data_ree_plot[k] =  scatter(;   x           = te,
                                        y           = compo_matrix[k,:]./C_norm,
                                        name        = names[k],
                                        mode        = "lines",
                                        line        = attr( dash    = "dash",
                                                            color   = "black", 
                                                            width   = 2.0)                ) 

        k += 1
    end
    if Cliq == 1
        names[k]            = "Cliq"
        compo_matrix[k,:]   = Out_TE_XY[point_id_te].Cliq[te_idx]

        data_ree_plot[k] =  scatter(;   x           = te,
                                        y           = compo_matrix[k,:]./C_norm,
                                        name        = names[k],
                                        mode        = "markers+lines",

                                        marker          = attr(     size    = 6.0,
                                                                    color   = "RGB(176,0,0)"),
                                        line            = attr( color   = "RGB(176,0,0)", 
                                                                width   = 2.0)                ) 

        k += 1
    end
    if Csol == 1
        names[k]            = "Csol"
        compo_matrix[k,:]   = Out_TE_XY[point_id_te].Csol[te_idx]

        data_ree_plot[k] =  scatter(;   x           = te,
                                        y           = compo_matrix[k,:]./C_norm,
                                        name        = names[k],
                                        mode        = "markers+lines",

                                        marker          = attr(     size    = 6.0,
                                                                    color   = "black"),
                                        line            = attr( color   = "black", 
                                                                width   = 2.0)                ) 

        k += 1
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
                                                minColor,   maxColor,
                                                smooth,     colorm,     reverseColorMap)
    global PT_infos_te, layout_te

    if type == "te"
        fieldname = varBuilder
    end

    data_plot_te[1] = heatmap(  x               =  X_te,
                                y               =  Y_te,
                                z               =  gridded_te,
                                zmin            =  minColor,
                                zmax            =  maxColor,
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
function  update_diplayed_field_phaseDiagram_te(    xtitle,     ytitle,     type,                  varBuilder, norm,
                                                    Xrange,     Yrange,     fieldname,
                                                    dtb,        oxi,
                                                    sub,        refLvl,
                                                    smooth,     colorm,     reverseColorMap,       refType )

    global data, Out_XY, Out_TE_XY, data_plot_te, gridded_te, gridded_info_te, X_te, Y_te, addedRefinementLvl, PT_infos_te, layout_te

    gridded_te, X_te, Y_te, npoints, meant = get_gridded_map_no_lbl(    fieldname,
                                                                        type,
                                                                        varBuilder,
                                                                        norm,
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



"""

    add_isopleth_phaseDiagram
"""
function add_isopleth_phaseDiagram_te(      Xrange,     Yrange, 
                                            sub,        refLvl,
                                            dtb,        oxi,
                                            isopleths_te,  field,  field_zr, calc, cust, norm_tes,
                                            isoLineStyle,   isoLineWidth, isoColorLine,           isoLabelSize,       
                                            minIso,     stepIso,    maxIso      )

    isoLabelSize    = Int64(isoLabelSize)

    if (field == "te")
        mod     = "calc"
        if cust != "none"
            name    = cust
        else
            name    = calc
        end
    elseif (field == "zrc")
        mod     = "zrc"
        name    = field_zr
    else
        println("Wrong combination, needs debugging...")
    end

    global data_isopleth_te, nIsopleths_te, data, Out_TE_XY, data_plot_te, X, Y, addedRefinementLvl

    gridded_te, X, Y = get_isopleth_map_te(     mod, field, field_zr, calc, norm_tes,
                                                oxi,
                                                Out_TE_XY,
                                                sub,
                                                refLvl + addedRefinementLvl,
                                                data.xc,
                                                data.yc,
                                                data.x,
                                                data.y,
                                                Xrange,
                                                Yrange )

    data_isopleth_te.n_iso += 1

    data_isopleth_te.isoP[data_isopleth_te.n_iso]= contour( x                   = X,
                                                            y                   = Y,
                                                            z                   = gridded_te,
                                                            contours_coloring   = "lines",
                                                            colorscale          = [[0, isoColorLine], [1, isoColorLine]],
                                                            # connectgaps         = false,
                                                            contours_start      = minIso,
                                                            contours_end        = maxIso,
                                                            contours_size       = stepIso,
                                                            line_width          = isoLineWidth,
                                                            line_dash           = isoLineStyle,
                                                            showscale           = false,
                                                            hoverinfo           = "skip",
                                                            contours            =  attr(    coloring    = "lines",
                                                                                            showlabels  = true,
                                                                                            labelfont   = attr( size    = isoLabelSize,
                                                                                                                color   = isoColorLine,  )
                                                            )
                                                        );

    data_isopleth_te.isoCap[data_isopleth_te.n_iso]   = scatter(    x           = [nothing],
                                                                    y           = [nothing],
                                                                    mode        = "lines",
                                                                    line        =  attr(color=isoColorLine,dash=isoLineStyle,width=isoLineWidth),
                                                                    name        =  name,
                                                                    showlegend  =  true);

    data_isopleth_te.status[data_isopleth_te.n_iso]     = 1
    data_isopleth_te.label[data_isopleth_te.n_iso]      = name
    data_isopleth_te.value[data_isopleth_te.n_iso]      = data_isopleth_te.n_iso
    data_isopleth_te.active                             = findall(data_isopleth_te.status .== 1)
    n_act                                               = length(data_isopleth_te.active)

    isopleths_te = [Dict("label" => data_isopleth_te.label[data_isopleth_te.active[i]], "value" => data_isopleth_te.value[data_isopleth_te.active[i]])
                        for i=1:n_act]

    return data_isopleth_te, isopleths_te

end

function remove_single_isopleth_phaseDiagram_te(isoplethsID)
    global data_isopleth_te

    data_isopleth_te.n_iso                -= 1      
    data_isopleth_te.status[isoplethsID]   = 0;
    data_isopleth_te.isoP[isoplethsID]     = contour()
    data_isopleth_te.isoCap[isoplethsID]   = scatter()
    data_isopleth_te.label[isoplethsID]    = ""
    data_isopleth_te.value[isoplethsID]    = 0
    data_isopleth_te.active                = findall(data_isopleth_te.status .== 1)
    n_act                                  = length(data_isopleth_te.active)
    isopleths_te = [Dict("label" => data_isopleth_te.label[data_isopleth_te.active[i]], "value" => data_isopleth_te.value[data_isopleth_te.active[i]])
                    for i=1:n_act]

    return data_isopleth_te, isopleths_te
end


function remove_all_isopleth_phaseDiagram_te()
    global data_isopleth_te, data_plot_te

    data_isopleth_te.label    .= ""
    data_isopleth_te.value    .= 0
    data_isopleth_te.n_iso     = 0
    for i=1:data_isopleth_te.n_iso_max
        data_isopleth_te.isoP[i] = contour()
        data_isopleth_te.isoCap[i] = scatter()
    end
    data_isopleth_te.status   .= 0
    data_isopleth_te.active   .= 0

    # clear isopleth dropdown menu
    isopleths_te = []              

    return data_isopleth_te, isopleths_te, data_plot_te
end