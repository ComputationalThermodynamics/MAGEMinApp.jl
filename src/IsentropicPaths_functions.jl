
function compute_new_IsentropicPath(    nsteps,     bulk_ini,   oxi,    phase_selection,    pure_phase_selection,
                                        Pini,       Tini,       Pfinal, tolerance,
                                        dtb,        dataset,    bufferType, solver,
                                        verbose,    bulk,       bufferN,
                                        cpx,        limOpx,     limOpxVal                                )

    global Out_ISOS, ph_names, compo_matrix

    nsteps = Int64(nsteps)

    # get indexes of phases to remove
    phase_selection = remove_phases(string_vec_diff(phase_selection,pure_phase_selection,dtb),dtb)

    # prepare flags
    mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                    cpx,        limOpx,     limOpxVal ) 

    np       = 2

    ph_names = Vector{String}()
    n_tot    = np + nsteps

    # allocate memory
    Out_ISOS = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n_tot);
    out      = MAGEMin_C.gmin_struct{Float64, Int64};

    # initialize single thread MAGEMin 
    GC.gc() 
    gv, z_b, DB, splx_data = init_MAGEMin(  dtb;        
                                            verbose     = verbose,
                                            dataset     = dataset,
                                            mbCpx       = mbCpx,
                                            limitCaOpx  = limitCaOpx,
                                            CaOpxLim    = CaOpxLim,
                                            buffer      = bufferType,
                                            solver      = sol    );

    # define system unit and starting bulk rock composition
    sys_in  = "mol"
    gv      =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);

    # compute starting point
    Out_ISOS[1] = deepcopy( point_wise_minimization(Pini,Tini, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

    # retrieve reference entropy of the system
    Sref        = Out_ISOS[1].entropy[1];
    n_max       = 32

    delta_T     = (Pini-Pfinal)/(nsteps+1)*(8.0);

    @showprogress for j = 2:n_tot

            P = Pini + (j-1)*( (Pfinal - Pini)/ (nsteps+1) )

            a           = Out_ISOS[j-1].T_C - 2.0*delta_T
            b           = Out_ISOS[j-1].T_C
            n           = 1
            conv        = 0
            n           = 0
            sign_a      = -1
    
            while n < n_max && conv == 0
                c       = (a+b)/2.0
                out     = deepcopy( point_wise_minimization(P, c , gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
                result  = out.entropy[1] - Sref

                sign_c  = sign(result)
    
                if abs(b-a) < tolerance
                    conv = 1
                else
                    if  sign_c == sign_a
                        a = c
                        sign_a = sign_c
                    else
                        b = c
                    end
                    
                end
                n += 1
            end

            Out_ISOS[j] = deepcopy(out)
    end


    #free MAGEMin
    LibMAGEMin.FreeDatabases(gv, DB, z_b)

    for k = 1:nsteps+1
        for l=1:length(Out_ISOS[k].ph)
            if ~(Out_ISOS[k].ph[l] in ph_names)
                push!(ph_names,Out_ISOS[k].ph[l])
            end
        end
    end
    ph_names = sort(ph_names)

end


function get_data_plot_isoS_path()

    n_tot   = length(Out_ISOS)

    x       = Vector{Float64}(undef, n_tot)
    y       = Vector{Float64}(undef, n_tot)

    for i=1:n_tot
        x[i] = Out_ISOS[i].T_C
        y[i] = Out_ISOS[i].P_kbar
    end

    df_path_plot = DataFrame(   x=x,
                                y=y     )

    return df_path_plot
end


function get_data_plot_isoS(sysunit)

    n_ph    = length(ph_names)
    n_tot   = length(Out_ISOS)
    data_plot  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph);

    x       = Vector{String}(undef, n_tot)
    Y       = zeros(Float64, n_ph, n_tot)

    colormap = get_jet_colormap(n_ph)
 
    for i=1:n_ph

        ph = ph_names[i]

        for k=1:n_tot
            
            x[k]    = string(round(Out_ISOS[k].P_kbar,digits=1))*"; "*string(round(Out_ISOS[k].T_C,digits=1))
            id      = findall(Out_ISOS[k].ph .== ph)

            if sysunit == "mol"
                if ~isempty(id)
                    Y[i,k] = sum(Out_ISOS[k].ph_frac[id]) .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "wt"
                if ~isempty(id)
                    Y[i,k] = sum(Out_ISOS[k].ph_frac_wt[id]) .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "vol"
                if ~isempty(id)
                    Y[i,k] = sum(Out_ISOS[k].ph_frac_vol[id]) .*100.0                # we sum in case of solvi
                end
            end
        
        end
    end 

    for k=1:n_tot
        Y[:,k] .= Y[:,k]/sum(Y[:,k]) .* 100.0
    end

    for i=1:n_ph
        data_plot[i] = scatter(;    x           =  x,
                                    y           =  Y[i,:],
                                    name        = ph_names[i],
                                    stackgroup  = "one",
                                    mode        = "lines",
                                    line        = attr(     width   =  0.5,
                                                            color   = colormap[i])  )
     end

    # build phase list:
    phase_list = [Dict("label" => "  "*ph_names[i], "value" => ph_names[i]) for i=1:n_ph]

    return data_plot, phase_list
end


"""
    function get_data_comp_plot(sysunit,phases)

    Gets the composition of selected stable phases accross the PTX paths and create a scatter plot
"""
function get_data_comp_plot_isoS(sysunit,phases)

    n_ox    = length(Out_ISOS[1].oxides)
    oxides  = Out_ISOS[1].oxides
    n_ph    = length(phases)
    n_tot   = length(Out_ISOS)

    data_comp_plot  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ox);
    x               = Vector{Union{String,Missing}}(undef, (n_tot+1)*n_ph)
    compo_matrix    = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1)*n_ph) .= missing
    colormap        = get_jet_colormap(n_ox)
 
    k = 1
    for i=1:n_ph
        ph      = phases[i]
        for j=1:n_tot
            
            x[k]    = string(round(Out_ISOS[j].P_kbar,digits=1))*"; "*string(round(Out_ISOS[j].T_C,digits=1))
            id      = findall(Out_ISOS[j].ph .== ph)

            if ~isempty(id)
                n_solvi = length(id)
                if sysunit == "mol"
                    
                    if n_solvi > 1      # then this is a solution phase as there is a solvus
                        for n=1:n_solvi
                            compo_matrix[:,k] += Out_ISOS[j].SS_vec[id[n]].Comp ./ Float64(n_solvi) .*100.0
                        end
                    else
                        id      = id[1]
                        n_SS    = Out_ISOS[j].n_SS
                        if id > n_SS    # then this is a pure phase
                            compo_matrix[:,k] = Out_ISOS[j].PP_vec[id - n_SS].Comp .*100.0
                        else            # else this is a solution phase
                            compo_matrix[:,k] = Out_ISOS[j].SS_vec[id].Comp .*100.0
                        end

                    end

                elseif sysunit == "wt"

                    if n_solvi > 1      # then this is a solution phase as there is a solvus
                        for n=1:n_solvi
                            compo_matrix[:,k] += Out_ISOS[j].SS_vec[id[n]].Comp_wt ./ Float64(n_solvi) .*100.0
                        end
                    else
                        id      = id[1]
                        n_SS    = Out_ISOS[j].n_SS
                        if id > n_SS    # then this is a pure phase
                            compo_matrix[:,k] = Out_ISOS[j].PP_vec[id - n_SS].Comp_wt .*100.0
                        else            # else this is a solution phase
                            compo_matrix[:,k] = Out_ISOS[j].SS_vec[id].Comp_wt .*100.0
                        end

                    end

                end
            else                    # else the phase is not stable therefore we don't fill the array
                compo_matrix[:,k] .= missing
            end
            k+=1
        
        end
        x[k]    = missing
        compo_matrix[:,k] .= missing
        k+=1

    end 

    for k=1:n_ox

        data_comp_plot[k] = scatter(;   x           =  x,
                                        y           =  compo_matrix[k,:],
                                        name        =  oxides[k],
                                        mode        = "markers+lines",
                                        marker      = attr(     size    = 5.0,
                                                                color   = colormap[k]),

                                        line        = attr(     width   = 1.0,
                                                                color   = colormap[k])  )

    end


    return data_comp_plot
end


function initialize_layout_isoS_path(   Pini :: Float64,
                                        Tini :: Float64,
                                        Pfinal :: Float64   )

    layout_isoS  = Layout(   font        = attr(size = 10),
                        height      = 240,
                        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
                        autosize    = false,
                        xaxis_title = "Temperature [°C]",
                        yaxis_title = "Pressure [kbar]",
                        xaxis_range = [Tini-300,Tini+100], 
                        yaxis_range = [0.0,Pini+5.0],
                        showlegend  = false,
                        xaxis       = attr(     fixedrange    = true,
                                            ),
                         yaxis       = attr(     fixedrange    = true,
                                            ),
    )

    return layout_isoS
end

function initialize_layout_isoS(title,sysunit)
    ytitle               = "Phase fraction ["*sysunit*"%]"
    layout_isoS  = Layout(

        title= attr(
            text    = title,
            x       = 0.5,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "P-T conditions [kbar, °C]",
        yaxis_title = ytitle,
        # annotations = annotations,
        # width       = 900,
        height      = 360,
        xaxis       = attr(     fixedrange    = true,
                            ),
        yaxis       = attr(     fixedrange    = true,
                            ),
    )

    return layout_isoS
end

function initialize_comp_layout_isoS(sysunit)
    ytitle               = "oxide fraction ["*sysunit*"%]"
    layout_comp  = Layout(

        title= attr(
            text    = "Phase composition",
            x       = 0.5,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "P-T conditions [kbar, °C]",
        yaxis_title = ytitle,
        # annotations = annotations,
        # width       = 900,
        height      = 360,
        # autosize    = false,
    )

    return layout_comp
end