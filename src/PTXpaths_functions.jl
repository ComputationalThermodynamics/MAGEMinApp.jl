function compute_new_PTXpath(   nsteps,     PTdata,     mode,       bulk_ini,   oxi,
                                dtb,        bufferType, solver,
                                verbose,    bulk,       bufferN,
                                cpx,        limOpx,     limOpxVal                                  )

        global Out_PTX, ph_names


        nsteps = Int64(nsteps)
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
        if solver == "pge"
            sol = 1
        elseif solver == "lp"
            sol = 0
        elseif solver == "hyb" 
            sol = 2         
        end

        # retrieve PTX path
        data    = copy(PTdata)
        np      = length(data)

        if np <= 1
            print("Cannot compute a path if at least 2 points are not defined! \n")
        else
            ph_names= Vector{String}()
            n_tot   = np + (np-1)*nsteps
            Out_PTX = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n_tot)

            Pres    = zeros(Float64,np)
            Temp    = zeros(Float64,np)
    
            for i=1:np
                Pres[i] = data[i][Symbol("col-1")]
                Temp[i] = data[i][Symbol("col-2")]
            end

            # initialize single thread MAGEMin 
            gv, z_b, DB, splx_data = init_MAGEMin(  dtb;        
                                                    verbose     = verbose,
                                                    mbCpx       = mbCpx,
                                                    limitCaOpx  = limitCaOpx,
                                                    CaOpxLim    = CaOpxLim,
                                                    buffer      = bufferType,
                                                    solver      = sol    );
    
            # define system unit and starting bulk rock composition
            sys_in  = "mol"
            gv      =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);
    
            k = 1
            for i = 1:np-1
                for j = 1:nsteps+1
                    P = Pres[i] + (j-1)*( (Pres[i+1] - Pres[i])/ (nsteps+1) )
                    T = Temp[i] + (j-1)*( (Temp[i+1] - Temp[i])/ (nsteps+1) )

                    Out_PTX[k] = deepcopy( point_wise_minimization(P,T, gv, z_b, DB, splx_data, sys_in) )
                    k += 1
                end
            end
            Out_PTX[k] = deepcopy( point_wise_minimization(Pres[np],Temp[np], gv, z_b, DB, splx_data, sys_in) )
  
            for k = 1:n_tot
                for l=1:length(Out_PTX[k].ph)
                    if ~(Out_PTX[k].ph[l] in ph_names)
                        push!(ph_names,Out_PTX[k].ph[l])
                    end
                end
            end
            ph_names = sort(ph_names)

            # free MAGEMin
            LibMAGEMin.FreeDatabases(gv, DB, z_b)
        end

end

function get_data_plot()

    n_ph    = length(ph_names)
    n_tot   = length(Out_PTX)
    data_plot  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph);

    x       = Vector{String}(undef, n_tot)
    Y       = zeros(Float64, n_ph, n_tot)

    for i=1:n_ph

        ph = ph_names[i]

        for k=1:n_tot
            x[k]    = string(round(Out_PTX[k].P_kbar,digits=3))*", "*string(round(Out_PTX[k].T_C,digits=3))
            id      = findall(Out_PTX[k].ph .== ph)

            if ~isempty(id)
                Y[i,k] = sum(Out_PTX[k].ph_frac[id]) .*100.0                # we sum in case of solvi
            end

        end

        data_plot[i] = scatter(;    x           =  x,
                                    y           =  Y[i,:],
                                    name        = ph,
                                    stackgroup  = "one",
                                    mode        = "lines",
                                    line        = attr(     width   =  0.5,
                                                            color   = colors[Symbol("jet")][i])  )

    end


    return data_plot
end


function initialize_layout(title)

    layout  = Layout(

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
        yaxis_title = "Phase fraction [mol%]",
        # annotations = annotations,
        # width       = 900,
        height      = 320,
        # autosize    = false,
    )

    return layout
end