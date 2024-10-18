mutable struct ss_infos
    ss_name :: String
    n_em    :: Int64
    n_xeos  :: Int64
    ss_em   :: Vector{String}
    ss_xeos :: Vector{String}
end

mutable struct db_infos
    db_name :: String
    db_info :: String
    data_ss :: Array{ss_infos}
    ss_name :: Array{String}
    data_pp :: Array{String}
end


mutable struct isopleth_data
    n_iso   :: Int64
    n_iso_max   :: Int64

    status  :: Vector{Int64}
    active  :: Vector{Int64}
    isoP    :: Vector{GenericTrace{Dict{Symbol, Any}}}
    isoCap  :: Vector{GenericTrace{Dict{Symbol, Any}}}

    label   :: Vector{String}
    value   :: Vector{Int64}
end


function get_system_comp_acronyme(bulk,oxides)

    return acronym
end



"""
    function to format the markdown text area to display general informations of the computation
"""
function get_computation_info(npoints, meant)

    infos  = "|Number of computed points &nbsp;| Minimization time (ms) |\n"
    infos *= "|--------------------------------|------------------------|\n"
    infos *= "|  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;"*string(npoints)*"  |   &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;"*string(meant)*" |\n"

    return infos
end


function prt(   in    ::Union{Float64,Vector{Float64}};
                acc   ::Int64                             =   4)

    if typeof(in) == Vector{Float64}
        out = " $( join( round.( in, digits  =   acc)," ") )"
    else
        out = " $(       round( in, digits   =   acc)      )"
    end

    return out
end


function get_phase_diagram_information(npoints, dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2, PTpath, watsat)

    ptx_data    = copy(PTpath)
    np      = length(ptx_data)
    Pres    = zeros(Float64,np)
    Temp    = zeros(Float64,np)
    x       = zeros(Float64,np)
    for i=1:np
        Pres[i] = ptx_data[i][Symbol("col-1")]
        Temp[i] = ptx_data[i][Symbol("col-2")]
        x[i]    = (i-1)*(1.0/(np-1))
    end

    PD_infos  = Vector{String}(undef,2)

    datetoday = string(Dates.today())
    rightnow  = string(Dates.Time(Dates.now()))


    if diagType == "pt"
        dgtype = "Pressure-Temperature, fixed composition"
    elseif diagType == "px"
        dgtype = "Pressure-Composition, fixed temperature"
    elseif diagType == "tx"
        dgtype = "Temperature-Composition, fixed pressure"
    elseif diagType == "ptx"
        dgtype = "Pressure Temperature path-Composition"
    end

    if solver == "lp"
        solv = "LP (legacy)"
    elseif solver == "pge"
        solv = "PGE (default)"
    elseif solver == "hyb"
        solv = "Hybrid (PGE&LP)"
    end


    db_in     = retrieve_solution_phase_information(dtb)


    PD_infos[1]  = "Phase Diagram computed using MAGEMin v"*Out_XY[1].MAGEMin_ver*" (GUI v0.4.5) <br>"
    PD_infos[1] *= "‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾<br>"
    PD_infos[1] *= "Number of points <br>"
    
    PD_infos[1] *= "Date & time <br>"
    PD_infos[1] *= "Database <br>"
    PD_infos[1] *= "Diagram type <br>"
    if watsat == "true"
        PD_infos[1] *= "Water saturation<br>"
    end
    PD_infos[1] *= "Solver <br>"
    PD_infos[1] *= "Oxide list <br>"
    if bufferType != "none"
        PD_infos[1] *= "Buffer <br>"
    end            
    
    if diagType == "pt"
        PD_infos[1] *= "X comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end       
    elseif diagType == "px"
        PD_infos[1] *= "X0 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end
        PD_infos[1] *= "X1 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "Fixed Temp <br>"
    elseif diagType == "tx"
        PD_infos[1] *= "X0 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "X1 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "Fixed Pres <br>"
    elseif diagType == "ptx"
        PD_infos[1] *= "X0 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "X2 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "PT path [P kbar]<br>"
        PD_infos[1] *= "PT path [T °C]<br>"
        # add ptx path here
    end
    oxi_string = replace.(oxi,"2"=>"₂", "3"=>"₃");

    PD_infos[1] *= "_____________________________________________________________________________________________________"
    PD_infos[2] = "<br>"
    PD_infos[2] *= "<br>"
    PD_infos[2] *= string(npoints) * "<br>"
    
    PD_infos[2] *= datetoday * ", " * rightnow * "<br>"
    PD_infos[2] *= db_in.db_info *"; "* Out_XY[1].dataset * "<br>" 

    PD_infos[2] *= dgtype *"<br>"

    if watsat == "true"
        PD_infos[2] *= "Computed at solidus <br>"
    end

    PD_infos[2] *= solv *"<br>"

    PD_infos[2] *= join(oxi_string, " ") *"<br>"
    if bufferType != "none"
        PD_infos[2] *= bufferType *"<br>"
    end            
    if diagType == "pt"
        PD_infos[2] *= join(bulk_L, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end       
    elseif diagType == "px"
        PD_infos[2] *= join(bulk_L, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end
        PD_infos[2] *= join(bulk_R, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(fixT, " ") *"<br>"
    elseif diagType == "tx"
        PD_infos[2] *= join(bulk_L, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end        
        PD_infos[2] *= join(bulk_R, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(fixP, " ") *"<br>"
    elseif diagType == "ptx"
        PD_infos[2] *= join(bulk_L, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end        
        PD_infos[2] *= join(bulk_R, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(Pres, " ") *"<br>"
        PD_infos[2] *= join(Temp, " ") *"<br>"
    end
    PD_infos[2] *= "_"

    return PD_infos
end

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
    elseif diagType == "tx"
        Xrange          = (Float64(0.0),Float64(1.0) )
        Yrange          = (Float64(tmin),Float64(tmax))
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Temperature [Celsius]"
    elseif diagType == "ptx"
        Xrange          = (Float64(0.0),Float64(1.0) )
        Yrange          = (Float64(0.0),Float64(1.0))
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Pressure-Temperature path"
    end
    return xtitle, ytitle, Xrange, Yrange
end

"""
    convert2Float64(bufferN1, bufferN2,fixT,fixP)

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
    pushed_button( ctx )

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
    get_terock_prop(bulkte1, bulkte2)

    retrieve trace element compositions
"""
function get_terock_prop(bulkte1, bulkte2)
 
    n_el        = length(bulkte1);
    bulkte_L    = zeros(n_el); 
    bulkte_R    = zeros(n_el);
    elem        = Vector{String}(undef, n_el)
    # in case the bulk rock is entered manually, the inputed values can be a string, this ensures convertion to float64
    for i=1:n_el
        tmp = bulkte1[i][:μg_g]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        tmp2 = bulkte2[i][:μg_g]
        if typeof(tmp2) == String
            tmp2 = parse(Float64,tmp2)
        end
        bulkte_L[i]     = tmp;
        bulkte_R[i]     = tmp2;
        elem[i]         = bulkte1[i][:elements];
    end

    return bulkte_L, bulkte_R, elem
end



function tepm_function( diagType    :: String,
                        dtb         :: String,
                        kds_mod     :: String,
                        zrsat_mod   :: String,
                        bulkte_L    :: Vector{Float64},
                        bulkte_R    :: Vector{Float64} )

    np          = length(Out_XY)

    Out_TE_XY   = Vector{MAGEMin_C.out_tepm}(undef,np)
    TEvec       = Vector{Float64};
    all_TE_ph   = []

    for i = 1:np

        if diagType != "pt"
            TEvec = bulkte_L*(1.0 - Out_XY[i].X[1]) + bulkte_R*Out_XY[i].X[1];
        else
            TEvec = bulkte_L
        end

        Out_TE_XY[i]  = TE_prediction(TEvec,KDs_dtb, zrsat_mod,Out_XY[i],dtb);

        if ~isnothing(Out_TE_XY[i].ph_TE)
            for j in Out_TE_XY[i].ph_TE
                if !(j in all_TE_ph)
                    push!(all_TE_ph,string(j))
                end
            end
        end

    end

    return Out_TE_XY, all_TE_ph
end



"""
    compute_new_phaseDiagram(   xtitle,     ytitle,     
                                Xrange,     Yrange,     fieldname,
                                dtb,        diagType,   verbose,    scp,    solver,
                                fixT,       fixP,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                smooth,     colorm,     reverseColorMap,
                                test,       PT_infos,   refType                                     )

    Compute a new phase diagram from scratch
"""
function compute_new_phaseDiagram(  xtitle,     ytitle,     lbl,
                                    Xrange,     Yrange,     fieldname,  customTitle,
                                    dtb,        diagType,   verbose,    scp,    solver,     phase_selection,
                                    fixT,       fixP,
                                    sub,        refLvl,
                                    watsat,     cpx,        limOpx,     limOpxVal,  PTpath,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    minColor,   maxColor,
                                    smooth,     colorm,     reverseColorMap,
                                    test,       refType                                  )

        # empty!(AppData.PseudosectionData);              #this empty the data from previous pseudosection computation

        #________________________________________________________________________________________#
        # Create coarse mesh
        cmesh           = t8_cmesh_quad_2d(MPI.COMM_WORLD, Xrange, Yrange)

        # Refine coarse mesh (in a regular manner)
        level           = sub
        forest          = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, MPI.COMM_WORLD)
        data            = get_element_data(forest)

        #________________________________________________________________________________________#
        # initialize database
        global forest, data, Hash_XY, Out_XY, n_phase_XY, data_plot, gridded, gridded_info, X, Y, layout, n_lbl
        global addedRefinementLvl  = 0;
        global MAGEMin_data;

        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 


        global pChip_wat, pChip_T;
        if diagType == "pt" && watsat == "true"
            pChip_wat, pChip_T = get_wat_sat_function(         Yrange,     bulk_L,     oxi,    phase_selection,
                                                                dtb,        bufferType, solver,
                                                                verbose,    bufferN1,
                                                                cpx,        limOpx,     limOpxVal)
        else
            pChip_wat, pChip_T = nothing, nothing
        end
                                                
        MAGEMin_data    =   Initialize_MAGEMin( dtb;
                                                verbose     = false,
                                                limitCaOpx  = limitCaOpx,
                                                CaOpxLim    = CaOpxLim,
                                                mbCpx       = mbCpx,
                                                buffer      = bufferType,
                                                solver      = sol    );

        #________________________________________________________________________________________#                      
        # initial optimization on regular grid

        Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  data, MAGEMin_data, diagType, PTpath,
                                                        phase_selection, fixT, fixP,
                                                        oxi, bulk_L, bulk_R,
                                                        bufferType, bufferN1, bufferN2,
                                                        scp, refType,
                                                        pChip_wat, pChip_T    )

        
        #________________________________________________________________________________________#     
        # Refine the mesh along phase boundaries

        for irefine = 1:refLvl
            refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
            forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
 
            t = @elapsed Out_XY, Hash_XY, n_phase_XY, = refine_MAGEMin(             data_new, MAGEMin_data, diagType, PTpath,
                                                                                    phase_selection, fixT, fixP,
                                                                                    oxi, bulk_L, bulk_R,
                                                                                    bufferType, bufferN1, bufferN2,
                                                                                    scp, refType,
                                                                                    pChip_wat, pChip_T, 
                                                                                    ind_map         = ind_map,
                                                                                    Out_XY_old      = Out_XY  ) # recompute points that have not been computed before
                                                                     
            println("Computed $(length(ind_map.<0)) new points in $t seconds")
            data    = data_new
            forest  = forest_new
            
        end

        for i = 1:Threads.nthreads()
            finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
        end

        #________________________________________________________________________________________#                   
        # Scatter plotly of the grid

        gridded, gridded_info, X, Y, npoints, meant = get_gridded_map(  fieldname,
                                                                        "major",
                                                                        oxi,
                                                                        Out_XY,
                                                                        nothing,
                                                                        Hash_XY,
                                                                        sub,
                                                                        refLvl,
                                                                        refType,
                                                                        data.xc,
                                                                        data.yc,
                                                                        data.x,
                                                                        data.y,
                                                                        Xrange,
                                                                        Yrange)

        PT_infos                           = get_phase_diagram_information(npoints, dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2,PTpath,watsat)

        data_plot, annotations = get_diagram_labels(    fieldname,
                                                        oxi,
                                                        Out_XY,
                                                        Hash_XY,
                                                        sub,
                                                        refLvl,
                                                        refType,
                                                        data.xc,
                                                        data.yc,
                                                        PT_infos )
        ticks   = 4
        frame   = get_plot_frame(Xrange,Yrange, ticks)                                  
        layout  = Layout(
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
                    margin      = attr(autoexpand = false, l=50, r=280, b=260, t=50, pad=4),
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
                
        heat_map = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
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

        hover_lbl = heatmap(    x               = X,
                                y               = Y,
                                z               = X,
                                type            = "heatmap",
                                showscale       = false,
                                opacity         = 0.0,
                                hoverinfo       = "text",
                                showlegend      = false,
                                text            = gridded_info )


        data_plot[1]    = heat_map

        return vcat(data_plot,hover_lbl), layout, npoints, meant
end



"""
    refine_phaseDiagram(            xtitle,     ytitle,     
                                    Xrange,     Yrange,     fieldname,
                                    dtb,        diagType,   verbose,    scp,    solver,
                                    fixT,       fixP,
                                    sub,        refLvl,
                                    cpx,        limOpx,     limOpxVal,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    smooth,     colorm,     reverseColorMap,
                                    test,       PT_infos,   refType                                   )
    Refine existing phase diagram
"""
function refine_phaseDiagram(   xtitle,     ytitle,     lbl,
                                Xrange,     Yrange,     fieldname,  customTitle,
                                dtb,        diagType,   watsat,     
                                verbose,    scp,        solver, phase_selection,
                                fixT,       fixP,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,  PTpath,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                minColor,   maxColor,
                                smooth,     colorm,     reverseColorMap,
                                test,       refType                                 )

    global forest, data, Hash_XY, Out_XY, n_phase_XY, data_plot, gridded, gridded_info, X, Y, addedRefinementLvl, layout, n_lbl, pChip_wat, pChip_T

    mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                    cpx,        limOpx,     limOpxVal ) 

    MAGEMin_data    =   Initialize_MAGEMin( dtb;
                                            verbose     = false,
                                            limitCaOpx  = limitCaOpx,
                                            CaOpxLim    = CaOpxLim,
                                            mbCpx       = mbCpx,
                                            buffer      = bufferType,
                                            solver      = sol    );

    refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
    forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new

    t = @elapsed Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin( data_new, MAGEMin_data, diagType, PTpath,
                                                                            phase_selection, fixT, fixP,
                                                                            oxi, bulk_L, bulk_R,
                                                                            bufferType, bufferN1, bufferN2, 
                                                                            scp, refType,
                                                                            pChip_wat,  pChip_T,
                                                                            ind_map         = ind_map,
                                                                            Out_XY_old      = Out_XY) # recompute points that have not been computed before

    println("Computed $(length(ind_map.<0)) new points in $(round(t, digits=3)) seconds")
    data                = data_new
    forest              = forest_new
    addedRefinementLvl += 1;

    for i = 1:Threads.nthreads()
        finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
    end

    #________________________________________________________________________________________#                   
    # Scatter plotly of the grid
    gridded, gridded_info, X, Y, npoints, meant = get_gridded_map(  fieldname,
                                                                    "major",
                                                                    oxi,
                                                                    Out_XY,
                                                                    nothing,
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
    
    PT_infos                           = get_phase_diagram_information(npoints,dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2,PTpath,watsat)
                                                              
    data_plot, annotations = get_diagram_labels(    fieldname,
                                                    oxi,
                                                    Out_XY,
                                                    Hash_XY,
                                                    sub,
                                                    refLvl,
                                                    refType,
                                                    data.xc,
                                                    data.yc,
                                                    PT_infos )
                                           
    layout[:annotations] = annotations 
    layout[:title] = attr(
        text    = customTitle,
        x       = 0.4,
        xanchor = "center",
        yanchor = "top"
    )
    
    data_plot[1] = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
                            connectgaps     = true,
                            zsmooth         =  smooth,
                            type            = "heatmap",
                            colorscale      = colorm,
                            colorbar_title  = fieldname,
                            reversescale    = reverseColorMap,
                            hoverinfo       = "skip",
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5         ),)

    hover_lbl = heatmap(    x               = X,
                            y               = Y,
                            z               = X,
                            type            = "heatmap",
                            showscale       = false,
                            opacity         = 0.0,
                            hoverinfo       = "text",
                            showlegend      = false,
                            text            = gridded_info )

    return vcat(data_plot,hover_lbl), layout, npoints, meant

end


"""
    update_colormap_phaseDiagram(      xtitle,     ytitle,     
                                                Xrange,     Yrange,     fieldname,
                                                dtb,        diagType,
                                                smooth,     colorm,     reverseColorMap,
                                                test                                  )
    Updates the colormap configuration of the phase diagram
"""
function update_colormap_phaseDiagram(      xtitle,     ytitle,     
                                            Xrange,     Yrange,     fieldname,
                                            dtb,        diagType,
                                            minColor,   maxColor,
                                            smooth,     colorm,     reverseColorMap,
                                            test                                  )
    global PT_infos, layout

    data_plot[1] = heatmap( x               =  X,
                            y               =  Y,
                            z               =  gridded,
                            zmin            =  minColor,
                            zmax            =  maxColor,
                            zsmooth         =  smooth,
                            connectgaps     = true,
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

    return data_plot,layout
end


"""
    show_hide_reaction_lines(    xtitle,     ytitle,     grid,  
                                    Xrange,     Yrange,     fieldname,
                                    dtb,
                                    smooth,     colorm,     reverseColorMap,
                                    test                                  )
    Shows/hides the grid
"""
function  show_hide_reaction_lines(  sub, 
                                        refLvl, 
                                        Xrange, 
                                        Yrange  )

    global data, Hash_XY, addedRefinementLvl

    boundaries  = get_boundaries(   Hash_XY,
                                    sub,
                                    refLvl+addedRefinementLvl,
                                    Xrange,
                                    Yrange,
                                    data.xc,
                                    data.yc,
                                    data.x,
                                    data.y          ) 
    
    bnd            = findall(boundaries .> 0)


    grid_plot = GenericTrace{Dict{Symbol, Any}}

    grid_plot =  scatter(   x           = data.xc[boundaries[bnd]],
                            y           = data.yc[boundaries[bnd]],
                            mode        = "markers",
                            # line_color  = "#FFFFFF",
                            # color       = "#333333",
                            marker      = attr(color = "#333333", size = 1.5),
                            hoverinfo   = "skip",
                            showlegend  = false     );

    return grid_plot
end




"""
    show_hide_reaction_lines(    xtitle,     ytitle,     grid,  
                                    Xrange,     Yrange,     fieldname,
                                    dtb,
                                    smooth,     colorm,     reverseColorMap,
                                    test                                  )
    Shows/hides the grid
"""
function  show_hide_mesh_grid()

    np             = length(data.x)
    grid_plot      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, np);
    for i = 1:np

        grid_plot[i] = scatter(     x           = data.x[i],
                                    y           = data.y[i],
                                    mode        = "lines",
                                    # line_color  = "#FFFFFF",
                                    line_color  = "#333333",
                                    line_width  = 0.2,
                                    hoverinfo   = "skip",
                                    showlegend  = false     )
    end

    return grid_plot
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
function  update_diplayed_field_phaseDiagram(   xtitle,     ytitle,     
                                                Xrange,     Yrange,     fieldname,
                                                dtb,        oxi,
                                                sub,        refLvl,
                                                smooth,     colorm,     reverseColorMap,
                                                test,       refType                                  )

    global data, Out_XY, data_plot, gridded, gridded_info, X, Y, addedRefinementLvl, PT_infos, layout

    gridded, X, Y, npoints, meant = get_gridded_map_no_lbl(     fieldname,
                                                                "major",
                                                                "none",
                                                                oxi,
                                                                Out_XY,
                                                                nothing,
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


    data_plot[1] = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
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

    return data_plot,layout
end

"""

    Initiatize global variable storing isopleths information
"""
function initialize_g_isopleth(; n_iso_max = 32)
    global data_isopleth

    status    = zeros(Int64,n_iso_max)
    active    = []
    isoP      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap
    isoCap    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap

    for i=1:n_iso_max
        isoP[i] = contour()
        isoCap[i] = scatter()
    end

    label     = Vector{String}(undef,n_iso_max)
    value     = Vector{Int64}(undef,n_iso_max)

    data_isopleth = isopleth_data(0, n_iso_max,
                                status, active, isoP, isoCap,
                                label, value)

    
    return data_isopleth
end


"""

    add_isopleth_phaseDiagram
"""
function add_isopleth_phaseDiagram(         Xrange,     Yrange, 
                                            sub,        refLvl,
                                            dtb,        oxi,
                                            isopleths,  phase,      ss,     em,     of,     ot,     calc, cust,
                                            isoLineStyle,   isoLineWidth, isoColorLine,           isoLabelSize,       
                                            minIso,     stepIso,    maxIso      )

    isoLabelSize    = Int64(isoLabelSize)

    if (phase == "ss" && ot == "mode") || (phase == "pp")
        mod     = "ph_frac"
        em      = ""
        name    = ss*"_[mode]"
    elseif (phase == "ss" && ot == "emMode")
        mod     = "em_frac"
        name    = ss*"_"*em*"_[mode]"
    elseif (phase == "ss" && ot == "MgNum")
        mod     = "ss_MgNum"
        em      = ""
        name    = ss*"_Mg#"
    elseif (phase == "ss" && ot == "calc")
        mod     = "ss_calc"
        em      = ""
        if cust != "none"
            name    = ss*"_["*cust*"]"
        else
            name    = ss*"_["*calc*"]"
        end
        # name    = ss*"_["*calc*"]"
    elseif (phase == "of")
        em      = ""
        ss      = ""
        mod     = "of_mod"
        name    = of
    else
        println("Wrong combination, needs debugging...")
    end

    global data_isopleth, nIsopleths, data, Out_XY, data_plot, X, Y, addedRefinementLvl

    gridded, X, Y = get_isopleth_map(   mod, ss, em, of, ot, calc,
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

    data_isopleth.n_iso += 1

    data_isopleth.isoP[data_isopleth.n_iso]= contour(   x                   = X,
                                                        y                   = Y,
                                                        z                   = gridded,
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

    data_isopleth.isoCap[data_isopleth.n_iso]   = scatter(  x           = [nothing],
                                                            y           = [nothing],
                                                            mode        = "lines",
                                                            line        =  attr(color=isoColorLine,dash=isoLineStyle,width=isoLineWidth),
                                                            name        =  name,
                                                            showlegend  =  true);

    data_isopleth.status[data_isopleth.n_iso]   = 1
    data_isopleth.label[data_isopleth.n_iso]    = name
    data_isopleth.value[data_isopleth.n_iso]    = data_isopleth.n_iso
    data_isopleth.active                        = findall(data_isopleth.status .== 1)
    n_act                                       = length(data_isopleth.active)

    isopleths = [Dict("label" => data_isopleth.label[data_isopleth.active[i]], "value" => data_isopleth.value[data_isopleth.active[i]])
                        for i=1:n_act]

    return data_isopleth, isopleths

end

function remove_single_isopleth_phaseDiagram(isoplethsID)
    global data_isopleth

    data_isopleth.n_iso                -= 1      
    data_isopleth.status[isoplethsID]   = 0;
    data_isopleth.isoP[isoplethsID]     = contour()
    data_isopleth.isoCap[isoplethsID]   = scatter()
    data_isopleth.label[isoplethsID]    = ""
    data_isopleth.value[isoplethsID]    = 0
    data_isopleth.active                = findall(data_isopleth.status .== 1)
    n_act                          = length(data_isopleth.active)
    isopleths = [Dict("label" => data_isopleth.label[data_isopleth.active[i]], "value" => data_isopleth.value[data_isopleth.active[i]])
                    for i=1:n_act]

    return data_isopleth, isopleths
end


function remove_all_isopleth_phaseDiagram()
    global data_isopleth, data_plot

    data_isopleth.label    .= ""
    data_isopleth.value    .= 0
    data_isopleth.n_iso     = 0
    for i=1:data_isopleth.n_iso_max
        data_isopleth.isoP[i] = contour()
        data_isopleth.isoCap[i] = scatter()
    end
    data_isopleth.status   .= 0
    data_isopleth.active   .= 0

    # clear isopleth dropdown menu
    isopleths = []              

    return data_isopleth, isopleths, data_plot
end