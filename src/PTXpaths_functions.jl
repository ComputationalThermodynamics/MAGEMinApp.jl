function get_jet_colormap(n)

    jet256 = ["RGB(0,0,127)", "RGB(0,0,132)", "RGB(0,0,136)", "RGB(0,0,141)", "RGB(0,0,145)", "RGB(0,0,150)", "RGB(0,0,154)", "RGB(0,0,159)", "RGB(0,0,163)", "RGB(0,0,168)", "RGB(0,0,172)", "RGB(0,0,177)", "RGB(0,0,182)", "RGB(0,0,186)", "RGB(0,0,191)", "RGB(0,0,195)", "RGB(0,0,200)", "RGB(0,0,204)", "RGB(0,0,209)", "RGB(0,0,213)", "RGB(0,0,218)", "RGB(0,0,222)", "RGB(0,0,227)", "RGB(0,0,232)", "RGB(0,0,236)", "RGB(0,0,241)", "RGB(0,0,245)", "RGB(0,0,250)", "RGB(0,0,254)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,4,255)", "RGB(0,8,255)", "RGB(0,12,255)", "RGB(0,16,255)", "RGB(0,20,255)", "RGB(0,24,255)", "RGB(0,28,255)", "RGB(0,32,255)", "RGB(0,36,255)", "RGB(0,40,255)", "RGB(0,44,255)", "RGB(0,48,255)", "RGB(0,52,255)", "RGB(0,56,255)", "RGB(0,60,255)", "RGB(0,64,255)", "RGB(0,68,255)", "RGB(0,72,255)", "RGB(0,76,255)", "RGB(0,80,255)", "RGB(0,84,255)", "RGB(0,88,255)", "RGB(0,92,255)", "RGB(0,96,255)", "RGB(0,100,255)", "RGB(0,104,255)", "RGB(0,108,255)", "RGB(0,112,255)", "RGB(0,116,255)", "RGB(0,120,255)", "RGB(0,124,255)", "RGB(0,128,255)", "RGB(0,132,255)", "RGB(0,136,255)", "RGB(0,140,255)", "RGB(0,144,255)", "RGB(0,148,255)", "RGB(0,152,255)", "RGB(0,156,255)", "RGB(0,160,255)", "RGB(0,164,255)", "RGB(0,168,255)", "RGB(0,172,255)", "RGB(0,176,255)", "RGB(0,180,255)", "RGB(0,184,255)", "RGB(0,188,255)", "RGB(0,192,255)", "RGB(0,196,255)", "RGB(0,200,255)", "RGB(0,204,255)", "RGB(0,208,255)", "RGB(0,212,255)", "RGB(0,216,255)", "RGB(0,220,254)", "RGB(0,224,250)", "RGB(0,228,247)", "RGB(2,232,244)", "RGB(5,236,241)", "RGB(8,240,237)", "RGB(12,244,234)", "RGB(15,248,231)", "RGB(18,252,228)", "RGB(21,255,225)", "RGB(24,255,221)", "RGB(28,255,218)", "RGB(31,255,215)", "RGB(34,255,212)", "RGB(37,255,208)", "RGB(41,255,205)", "RGB(44,255,202)", "RGB(47,255,199)", "RGB(50,255,195)", "RGB(54,255,192)", "RGB(57,255,189)", "RGB(60,255,186)", "RGB(63,255,183)", "RGB(66,255,179)", "RGB(70,255,176)", "RGB(73,255,173)", "RGB(76,255,170)", "RGB(79,255,166)", "RGB(83,255,163)", "RGB(86,255,160)", "RGB(89,255,157)", "RGB(92,255,154)", "RGB(95,255,150)", "RGB(99,255,147)", "RGB(102,255,144)", "RGB(105,255,141)", "RGB(108,255,137)", "RGB(112,255,134)", "RGB(115,255,131)", "RGB(118,255,128)", "RGB(121,255,125)", "RGB(124,255,121)", "RGB(128,255,118)", "RGB(131,255,115)", "RGB(134,255,112)", "RGB(137,255,108)", "RGB(141,255,105)", "RGB(144,255,102)", "RGB(147,255,99)", "RGB(150,255,95)", "RGB(154,255,92)", "RGB(157,255,89)", "RGB(160,255,86)", "RGB(163,255,83)", "RGB(166,255,79)", "RGB(170,255,76)", "RGB(173,255,73)", "RGB(176,255,70)", "RGB(179,255,66)", "RGB(183,255,63)", "RGB(186,255,60)", "RGB(189,255,57)", "RGB(192,255,54)", "RGB(195,255,50)", "RGB(199,255,47)", "RGB(202,255,44)", "RGB(205,255,41)", "RGB(208,255,37)", "RGB(212,255,34)", "RGB(215,255,31)", "RGB(218,255,28)", "RGB(221,255,24)", "RGB(224,255,21)", "RGB(228,255,18)", "RGB(231,255,15)", "RGB(234,255,12)", "RGB(237,255,8)", "RGB(241,252,5)", "RGB(244,248,2)", "RGB(247,244,0)", "RGB(250,240,0)", "RGB(254,237,0)", "RGB(255,233,0)", "RGB(255,229,0)", "RGB(255,226,0)", "RGB(255,222,0)", "RGB(255,218,0)", "RGB(255,215,0)", "RGB(255,211,0)", "RGB(255,207,0)", "RGB(255,203,0)", "RGB(255,200,0)", "RGB(255,196,0)", "RGB(255,192,0)", "RGB(255,189,0)", "RGB(255,185,0)", "RGB(255,181,0)", "RGB(255,177,0)", "RGB(255,174,0)", "RGB(255,170,0)", "RGB(255,166,0)", "RGB(255,163,0)", "RGB(255,159,0)", "RGB(255,155,0)", "RGB(255,152,0)", "RGB(255,148,0)", "RGB(255,144,0)", "RGB(255,140,0)", "RGB(255,137,0)", "RGB(255,133,0)", "RGB(255,129,0)", "RGB(255,126,0)", "RGB(255,122,0)", "RGB(255,118,0)", "RGB(255,115,0)", "RGB(255,111,0)", "RGB(255,107,0)", "RGB(255,103,0)", "RGB(255,100,0)", "RGB(255,96,0)", "RGB(255,92,0)", "RGB(255,89,0)", "RGB(255,85,0)", "RGB(255,81,0)", "RGB(255,77,0)", "RGB(255,74,0)", "RGB(255,70,0)", "RGB(255,66,0)", "RGB(255,63,0)", "RGB(255,59,0)", "RGB(255,55,0)", "RGB(255,52,0)", "RGB(255,48,0)", "RGB(255,44,0)", "RGB(255,40,0)", "RGB(255,37,0)", "RGB(255,33,0)", "RGB(255,29,0)", "RGB(255,26,0)", "RGB(255,22,0)", "RGB(254,18,0)", "RGB(250,15,0)", "RGB(245,11,0)", "RGB(241,7,0)", "RGB(236,3,0)", "RGB(232,0,0)", "RGB(227,0,0)", "RGB(222,0,0)", "RGB(218,0,0)", "RGB(213,0,0)", "RGB(209,0,0)", "RGB(204,0,0)", "RGB(200,0,0)", "RGB(195,0,0)", "RGB(191,0,0)", "RGB(186,0,0)", "RGB(182,0,0)", "RGB(177,0,0)", "RGB(172,0,0)", "RGB(168,0,0)", "RGB(163,0,0)", "RGB(159,0,0)", "RGB(154,0,0)", "RGB(150,0,0)", "RGB(145,0,0)", "RGB(141,0,0)", "RGB(136,0,0)", "RGB(132,0,0)", "RGB(127,0,0)"]

    np    = length(jet256)

    step  = Int64(floor(np/n))

    return jet256[1:step:end]

end


function compute_new_PTXpath(   nsteps,     PTdata,     mode,       bulk_ini,   oxi,
                                dtb,        bufferType, solver,
                                verbose,    bulk,       bufferN,
                                cpx,        limOpx,     limOpxVal,
                                nCon,       nRes                                  )

        global Out_PTX, ph_names, fracEvol


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
            fracEvol= Matrix{Float64}(undef,n_tot,2)
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


            fracEvol[1,1] = 1.0;          # starting material fraction is always one as we want to measure the relative change here
            fracEvol[1,2] = 0.0; 
            k = 1
            @showprogress for i = 1:np-1
                for j = 1:nsteps+1
                    P = Pres[i] + (j-1)*( (Pres[i+1] - Pres[i])/ (nsteps+1) )
                    T = Temp[i] + (j-1)*( (Temp[i+1] - Temp[i])/ (nsteps+1) )

                    if mode == "fm" || mode == "fc"
                        gv      =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);
                    end
                    # print("nCon: $nCon\n")
                    Out_PTX[k] = deepcopy( point_wise_minimization(P,T, gv, z_b, DB, splx_data, sys_in) )

                    if mode == "fm"
                        if Out_PTX[k].frac_S > 0.0
                            if nCon > 0.0
                                if Out_PTX[k].frac_M > nCon/100.0
                                    bulk_ini .= Out_PTX[k].bulk_S .*((100.0-nCon)/100.0) .+ Out_PTX[k].bulk_M .*(nCon/100.0)

                                    fracEvol[k+1,1] = fracEvol[k,1] * (Out_PTX[k].frac_S + Out_PTX[k].frac_F + nCon/100.0) 
                                    fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                                else
                                    fracEvol[k+1,1] = fracEvol[k,1]
                                    fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                                end
                            else
                                bulk_ini .= Out_PTX[k].bulk_S
                                fracEvol[k+1,1] = fracEvol[k,1]
                                fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                            end
                        else
                            fracEvol[k+1,1] = fracEvol[k,1]
                            fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                        end
                    elseif mode == "fc"
                        if Out_PTX[k].frac_M > 0.0

                            if nRes > 0.0
                                if Out_PTX[k].frac_S > nRes/100.0
                                    bulk_ini .= Out_PTX[k].bulk_M .*((100.0-nRes)/100.0) .+ Out_PTX[k].bulk_S .*(nRes/100.0)

                                    fracEvol[k+1,1] = fracEvol[k,1] * (Out_PTX[k].frac_M + nRes/100.0) 
                                    fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                                else
                                    fracEvol[k+1,1] = fracEvol[k,1] * (Out_PTX[k].frac_M + Out_PTX[k].frac_S) 
                                    fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                                end
                            else
                                bulk_ini .= Out_PTX[k].bulk_M
                                fracEvol[k+1,1] = fracEvol[k,1] * (Out_PTX[k].frac_M) 
                                fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                            end
                        else
                            fracEvol[k+1,1] = fracEvol[k,1]
                            fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                        end
                    else
                        fracEvol[k+1,1] = fracEvol[k,1]
                        fracEvol[k+1,2] = 1.0 - fracEvol[k+1,1] 
                    end


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

function get_data_plot(sysunit)

    n_ph    = length(ph_names)
    n_tot   = length(Out_PTX)
    data_plot  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph+2);

    x       = Vector{String}(undef, n_tot)
    Y       = zeros(Float64, n_ph, n_tot)

    colormap = get_jet_colormap(n_ph)
 
    for i=1:n_ph

        ph = ph_names[i]

        for k=1:n_tot
            
            x[k]    = string(round(Out_PTX[k].P_kbar,digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
            id      = findall(Out_PTX[k].ph .== ph)

            if sysunit == "mol"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac[id]) .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "wt"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac_wt[id]) .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "vol"
                if ~isempty(id)
                    n_id = length(id)
                    rho = 0.0
                    for ii = 1:n_id
                        if id[ii] <= Out_PTX[k].n_SS
                            rho += Out_PTX[k].SS_vec[id[ii]].rho / n_id
                        else
                            rho += Out_PTX[k].PP_vec[id[ii]-Out_PTX[k].n_SS].rho / n_id
                        end
                    end

                    Y[i,k] = sum(Out_PTX[k].ph_frac_wt[id])/rho                # we sum in case of solvi

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

     data_plot[n_ph+1] = scatter(   x               = x,
                                    name            = "removed %",
                                    y               = fracEvol[:,2].*100.0, 
                                    hoverinfo       = "skip",
                                    # showlegend      = false,
                                    line            = attr( dash    = "dash",
                                                            color   = "black", 
                                                            width   = 0.5)                ) 
     data_plot[n_ph+2] = scatter(   x               = x,
                                    y               = fracEvol[:,1].*100.0, 
                                    name            = "remaining %",
                                    hoverinfo       = "skip",
                                    # showlegend      = false,
                                    line            = attr( color   = "black", 
                                                            width   = 0.5)                ) 


    return data_plot
end


function initialize_layout(title,sysunit)
    ytitle               = "Phase fraction ["*sysunit*"%]"
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
        yaxis_title = ytitle,
        # annotations = annotations,
        # width       = 900,
        height      = 360,
        # autosize    = false,
    )

    return layout
end