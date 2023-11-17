"""
    Diagram type function 
        diagram_type(diagType, tmin, tmax, pmin, pmax)

    returns axis titles and axis ranges
"""
function diagram_type(diagType, tmin, tmax, pmin, pmax)
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
    return xtitle, ytitle, Xrange, Yrange
end

"""
    converts input to float if the provided value is an integer
"""
function convert2Float64(bufferN1, bufferN2,fixT,fixP)
    bufferN1 = Float64(bufferN1)
    bufferN2 = Float64(bufferN2)
    fixT     = Float64(fixT)
    fixP     = Float64(fixP)

    return bufferN1, bufferN2, fixT, fixP
end

"""
    Get the id of the last pushed button
"""
function pushed_button( ctx )
    ctx = callback_context()
    if length(ctx.triggered) == 0
        bid = ""
    else
        bid = split(ctx.triggered[1].prop_id, ".")[1]
    end
    return bid
end

"""
    get_colormap_prop(colorMap, rangeColor, reverse) 

    retrieve colormap range and reserve boolean
"""
function get_colormap_prop(colorMap, rangeColor, reverse) 

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

    return colorm, reverseColorMap
end



"""
    get_bulkrock_prop(bulk1, bulk2)

    retrieve bulk rock composition and components from dash table
"""
function get_bulkrock_prop(bulk1, bulk2)
 
    n_ox    = length(bulk1);
    bulk_L  = zeros(n_ox); 
    bulk_R  = zeros(n_ox);
    oxi     = Vector{String}(undef, n_ox)
    # in case the bulk rock is entered manually, the inputed values can be a string, this ensures convertion to float64
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

    return bulk_L, bulk_R, oxi
end


"""
    compute_new_phaseDiagram(   xtitle,     ytitle,     
                                Xrange,     Yrange,     fieldname,
                                dtb,        diagType,   verbose,
                                fixT,       fixP,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                smooth,     colorm,     reverseColorMap,
                                test                                    )

    Compute a new phase diagram from scratch
"""
function compute_new_phaseDiagram(  xtitle,     ytitle,     
                                    Xrange,     Yrange,     fieldname,
                                    dtb,        diagType,   verbose,
                                    fixT,       fixP,
                                    sub,        refLvl,
                                    cpx,        limOpx,     limOpxVal,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    smooth,     colorm,     reverseColorMap,
                                    test                                  )

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
        global MAGEMin_data, forest, data, Hash_XY, Out_XY, n_phase_XY, field, data_plot, gridded, gridded_info, X, Y, PhasesLabels
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
                                                mbCpx       = mbCpx,
                                                buffer      = bufferType    );

        #________________________________________________________________________________________#                      
        # initial optimization on regular grid
        Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  data, 
                                                        MAGEMin_data,
                                                        diagType,
                                                        fixT,
                                                        fixP,
                                                        oxi,
                                                        bulk_L,
                                                        bulk_R,
                                                        bufferType,
                                                        bufferN1,
                                                        bufferN2    )
                    
        #________________________________________________________________________________________#     
        # Refine the mesh along phase boundaries

        for irefine = 1:refLvl
            refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
            forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
            t = @elapsed Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(  data_new,
                                                                        MAGEMin_data,
                                                                        diagType,
                                                                        fixT,
                                                                        fixP,
                                                                        oxi,
                                                                        bulk_L,
                                                                        bulk_R,
                                                                        bufferType,
                                                                        bufferN1,
                                                                        bufferN2, 
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
                    # annotations = PhasesLabels,
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

        return fig, npoints, grid_out, meant
end



"""
   
    Refine existing phase diagram
"""
function refine_phaseDiagram(   xtitle,     ytitle,     
                                Xrange,     Yrange,     fieldname,
                                dtb,        diagType,   verbose,
                                fixT,       fixP,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                smooth,     colorm,     reverseColorMap,
                                test                                  )

    global MAGEMin_data, forest, data, Hash_XY, Out_XY, n_phase_XY, field, data_plot, gridded, gridded_info, X, Y, PhasesLabels,addedRefinementLvl

    refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
    forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    t = @elapsed Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(  data_new,
                                                                MAGEMin_data,
                                                                diagType,
                                                                fixT,
                                                                fixP,
                                                                oxi,
                                                                bulk_L,
                                                                bulk_R,
                                                                bufferType,
                                                                bufferN1,
                                                                bufferN2, 
                                                                ind_map         = ind_map,
                                                                Out_XY_old      = Out_XY,
                                                                n_phase_XY_old  = n_phase_XY) # recompute points that have not been computed before

    println("Computed $(length(ind_map.<0)) new points in $t seconds")
    data                = data_new
    forest              = forest_new
    addedRefinementLvl += 1;

    empty!(AppData.PseudosectionData)
    push!(AppData.PseudosectionData,Out_XY);

    #________________________________________________________________________________________#                   
    # Scatter plotly of the grid

    gridded, gridded_info, X, Y, npoints, meant, PhasesLabels = get_gridded_map(    fieldname,
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

    global  data_plot, gridded, gridded_info, X, Y, PhasesLabels

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


    return fig, npoints, grid_out, meant

end


"""
   
    Updates the colormap configuration of the phase diagram
"""
function update_colormap_phaseDiagram(      xtitle,     ytitle,     
                                            Xrange,     Yrange,     fieldname,
                                            dtb,        diagType,
                                            smooth,     colorm,     reverseColorMap,
                                            test                                  )

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
        # annotations = PhasesLabels,
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

    return fig, grid_out
end




"""
   
    Updates the field displayed
"""
function  update_diplayed_field_phaseDiagram(   xtitle,     ytitle,     
                                                Xrange,     Yrange,     fieldname,
                                                dtb,        oxi,
                                                sub,        refLvl,
                                                smooth,     colorm,     reverseColorMap,
                                                test                                  )

    global data, Out_XY, data_plot, gridded, gridded_info, X, Y, PhasesLabels, addedRefinementLvl

    gridded, gridded_info, X, Y, npoints, meant, PhasesLabels = get_gridded_map(    fieldname,
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

    layout      = Layout(
    title=attr( text    = db[(db.db .== dtb), :].title[test+1],
                x       = 0.5,
                xanchor = "center",
                yanchor = "top"     ),
    plot_bgcolor = "#FFF",
    paper_bgcolor = "#FFF",
    xaxis_title = xtitle,
    yaxis_title = ytitle,
    # annotations = PhasesLabels,
    width       = 800,
    height      = 800 )

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

    return fig, grid_out
end



"""
   
    Shows/hides the grid
"""
function  show_hide_grid_phaseDiagram(  xtitle,     ytitle,     grid,  
                                        Xrange,     Yrange,     fieldname,
                                        dtb,
                                        smooth,     colorm,     reverseColorMap,
                                        test                                  )

    global data, data_plot, gridded, gridded_info, X, Y, PhasesLabels

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
        # annotations = PhasesLabels,
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

    return fig, grid_out
end