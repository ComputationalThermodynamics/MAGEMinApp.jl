function get_jet_colormap(n)

    jet256 = ["RGB(0,0,127)", "RGB(0,0,132)", "RGB(0,0,136)", "RGB(0,0,141)", "RGB(0,0,145)", "RGB(0,0,150)", "RGB(0,0,154)", "RGB(0,0,159)", "RGB(0,0,163)", "RGB(0,0,168)", "RGB(0,0,172)", "RGB(0,0,177)", "RGB(0,0,182)", "RGB(0,0,186)", "RGB(0,0,191)", "RGB(0,0,195)", "RGB(0,0,200)", "RGB(0,0,204)", "RGB(0,0,209)", "RGB(0,0,213)", "RGB(0,0,218)", "RGB(0,0,222)", "RGB(0,0,227)", "RGB(0,0,232)", "RGB(0,0,236)", "RGB(0,0,241)", "RGB(0,0,245)", "RGB(0,0,250)", "RGB(0,0,254)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,4,255)", "RGB(0,8,255)", "RGB(0,12,255)", "RGB(0,16,255)", "RGB(0,20,255)", "RGB(0,24,255)", "RGB(0,28,255)", "RGB(0,32,255)", "RGB(0,36,255)", "RGB(0,40,255)", "RGB(0,44,255)", "RGB(0,48,255)", "RGB(0,52,255)", "RGB(0,56,255)", "RGB(0,60,255)", "RGB(0,64,255)", "RGB(0,68,255)", "RGB(0,72,255)", "RGB(0,76,255)", "RGB(0,80,255)", "RGB(0,84,255)", "RGB(0,88,255)", "RGB(0,92,255)", "RGB(0,96,255)", "RGB(0,100,255)", "RGB(0,104,255)", "RGB(0,108,255)", "RGB(0,112,255)", "RGB(0,116,255)", "RGB(0,120,255)", "RGB(0,124,255)", "RGB(0,128,255)", "RGB(0,132,255)", "RGB(0,136,255)", "RGB(0,140,255)", "RGB(0,144,255)", "RGB(0,148,255)", "RGB(0,152,255)", "RGB(0,156,255)", "RGB(0,160,255)", "RGB(0,164,255)", "RGB(0,168,255)", "RGB(0,172,255)", "RGB(0,176,255)", "RGB(0,180,255)", "RGB(0,184,255)", "RGB(0,188,255)", "RGB(0,192,255)", "RGB(0,196,255)", "RGB(0,200,255)", "RGB(0,204,255)", "RGB(0,208,255)", "RGB(0,212,255)", "RGB(0,216,255)", "RGB(0,220,254)", "RGB(0,224,250)", "RGB(0,228,247)", "RGB(2,232,244)", "RGB(5,236,241)", "RGB(8,240,237)", "RGB(12,244,234)", "RGB(15,248,231)", "RGB(18,252,228)", "RGB(21,255,225)", "RGB(24,255,221)", "RGB(28,255,218)", "RGB(31,255,215)", "RGB(34,255,212)", "RGB(37,255,208)", "RGB(41,255,205)", "RGB(44,255,202)", "RGB(47,255,199)", "RGB(50,255,195)", "RGB(54,255,192)", "RGB(57,255,189)", "RGB(60,255,186)", "RGB(63,255,183)", "RGB(66,255,179)", "RGB(70,255,176)", "RGB(73,255,173)", "RGB(76,255,170)", "RGB(79,255,166)", "RGB(83,255,163)", "RGB(86,255,160)", "RGB(89,255,157)", "RGB(92,255,154)", "RGB(95,255,150)", "RGB(99,255,147)", "RGB(102,255,144)", "RGB(105,255,141)", "RGB(108,255,137)", "RGB(112,255,134)", "RGB(115,255,131)", "RGB(118,255,128)", "RGB(121,255,125)", "RGB(124,255,121)", "RGB(128,255,118)", "RGB(131,255,115)", "RGB(134,255,112)", "RGB(137,255,108)", "RGB(141,255,105)", "RGB(144,255,102)", "RGB(147,255,99)", "RGB(150,255,95)", "RGB(154,255,92)", "RGB(157,255,89)", "RGB(160,255,86)", "RGB(163,255,83)", "RGB(166,255,79)", "RGB(170,255,76)", "RGB(173,255,73)", "RGB(176,255,70)", "RGB(179,255,66)", "RGB(183,255,63)", "RGB(186,255,60)", "RGB(189,255,57)", "RGB(192,255,54)", "RGB(195,255,50)", "RGB(199,255,47)", "RGB(202,255,44)", "RGB(205,255,41)", "RGB(208,255,37)", "RGB(212,255,34)", "RGB(215,255,31)", "RGB(218,255,28)", "RGB(221,255,24)", "RGB(224,255,21)", "RGB(228,255,18)", "RGB(231,255,15)", "RGB(234,255,12)", "RGB(237,255,8)", "RGB(241,252,5)", "RGB(244,248,2)", "RGB(247,244,0)", "RGB(250,240,0)", "RGB(254,237,0)", "RGB(255,233,0)", "RGB(255,229,0)", "RGB(255,226,0)", "RGB(255,222,0)", "RGB(255,218,0)", "RGB(255,215,0)", "RGB(255,211,0)", "RGB(255,207,0)", "RGB(255,203,0)", "RGB(255,200,0)", "RGB(255,196,0)", "RGB(255,192,0)", "RGB(255,189,0)", "RGB(255,185,0)", "RGB(255,181,0)", "RGB(255,177,0)", "RGB(255,174,0)", "RGB(255,170,0)", "RGB(255,166,0)", "RGB(255,163,0)", "RGB(255,159,0)", "RGB(255,155,0)", "RGB(255,152,0)", "RGB(255,148,0)", "RGB(255,144,0)", "RGB(255,140,0)", "RGB(255,137,0)", "RGB(255,133,0)", "RGB(255,129,0)", "RGB(255,126,0)", "RGB(255,122,0)", "RGB(255,118,0)", "RGB(255,115,0)", "RGB(255,111,0)", "RGB(255,107,0)", "RGB(255,103,0)", "RGB(255,100,0)", "RGB(255,96,0)", "RGB(255,92,0)", "RGB(255,89,0)", "RGB(255,85,0)", "RGB(255,81,0)", "RGB(255,77,0)", "RGB(255,74,0)", "RGB(255,70,0)", "RGB(255,66,0)", "RGB(255,63,0)", "RGB(255,59,0)", "RGB(255,55,0)", "RGB(255,52,0)", "RGB(255,48,0)", "RGB(255,44,0)", "RGB(255,40,0)", "RGB(255,37,0)", "RGB(255,33,0)", "RGB(255,29,0)", "RGB(255,26,0)", "RGB(255,22,0)", "RGB(254,18,0)", "RGB(250,15,0)", "RGB(245,11,0)", "RGB(241,7,0)", "RGB(236,3,0)", "RGB(232,0,0)", "RGB(227,0,0)", "RGB(222,0,0)", "RGB(218,0,0)", "RGB(213,0,0)", "RGB(209,0,0)", "RGB(204,0,0)", "RGB(200,0,0)", "RGB(195,0,0)", "RGB(191,0,0)", "RGB(186,0,0)", "RGB(182,0,0)", "RGB(177,0,0)", "RGB(172,0,0)", "RGB(168,0,0)", "RGB(163,0,0)", "RGB(159,0,0)", "RGB(154,0,0)", "RGB(150,0,0)", "RGB(145,0,0)", "RGB(141,0,0)", "RGB(136,0,0)", "RGB(132,0,0)", "RGB(127,0,0)"]

    np    = length(jet256)

    step  = Int64(floor(np/n))

    return jet256[1:step:end]

end


"""
    Retrieve TAS diagram
"""
function get_TAS_diagram(phases)

    tas      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, 16);

    F        = [35. 0; 41 0; 41 7; 45 9.4; 48.4 11.5; 52.5 14; 48 16; 35 16;35 0]
    Pc       = [41. 0; 45 0; 45 3; 41 3;41 0]
    U1       = [41. 3; 45 3; 45 5; 49.4 7.3; 45 9.4; 41 7;41 3]
    U2       = [49.4 7.3; 53 9.3; 48.4 11.5; 45 9.4;49.4 7.3]
    U3       = [53. 9.3; 57.6 11.7; 52.5 14; 48.4 11.5;53 9.3]
    Ph       = [52.5 14; 57.6 11.7; 65 16; 48 16;52.5 14]
    B        = [45. 0; 52 0; 52 5; 45 5;45 0]
    S1       = [45. 5; 52 5; 49.4 7.3;45 5]
    S2       = [52. 5; 57 5.9; 53 9.3; 49.4 7.3;52 5]
    S3       = [57. 5.9; 63 7; 57.6 11.7; 53 9.3;57 5.9]
    T        = [63. 7; 69 8; 69 16; 65 16; 57.6 11.7;63 7]
    O1       = [52. 0; 57 0; 57 5.9; 52 5;52 0]
    O2       = [57. 0; 63 0; 63 7; 57 5.9;57 0]
    O3       = [63. 0; 77 0; 69 8; 63 7;63 0]
    R        = [77. 0; 85 0; 85 16; 69 16; 69 8;77 0]

    fields   = (F,Pc,U1,U2,U3,Ph,B,S1,S2,S3,T,O1,O2,O3,R)
    nf       = length(fields)
    xc       = zeros(nf)
    yc       = zeros(nf)

    for i=1:nf
        xc[i] = sum(fields[i][1:end-1,1])/(size(fields[i],1)-1.0)
        yc[i] = sum(fields[i][1:end-1,2])/(size(fields[i],1)-1.0)
    end
    
    # annotations shifts
    xc[1]   -=4.0;
    yc[1]   +=3.0;
    yc[3]   +=1.0;
    xc[6]   +=2.0;
    yc[8]   -=0.25;
    yc[9]   +=0.25;


    name = ["foidite" "picrobasalt" "basanite" "phonotephrite" "tephriphonolite" "phonolite" "basalt" "trachybasalt" "basaltic<br>trachyandesite" "trachyandesite" "trachyte" "basaltic<br>andesite" "andesite" "dacite" "rhyolite"];
       
    for i = 1:nf
        tas[i] = scatter(   x           = fields[i][:,1], 
                            y           = fields[i][:,2], 
                            hoverinfo   = "skip",
                            mode        = "lines",
                            showscale   = false,
                            showlegend  = false,
                            line        = attr( color   = "black", 
                                                width   = 0.75)                )
    end


    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_tot   = length(Out_PTX)

    liq_tas         = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))      .= missing
    colormap        = get_jet_colormap(n_tot+1)
 
    for j=1:n_tot
        id      = findall(Out_PTX[j].ph .== "liq")
        if ~isempty(id)
            liq_tas[:,j] = Out_PTX[j].SS_vec[id[1]].Comp_wt .*100.0
        end
    end

    dry  = findall(oxides .!= "H2O") 
    id_Y = findall(oxides .== "K2O" .|| oxides .== "Na2O")
    id_X = findall(oxides .== "SiO2") 

    if ~isempty(dry)
        liq_tas ./=sum(liq_tas[dry,:],dims=1)
        liq_tas .*= 100.0
    end

    tas[end] = scatter(     x           = liq_tas[id_X,:], 
                            y           = sum(liq_tas[id_Y,:],dims=1), 
                            hoverinfo   = "skip",
                            mode        = "markers",
                            opacity     = 0.8,
                            showscale   = false,
                            showlegend  = false,
                            marker      = attr(     size        = fracEvol[:,1].*15.0 .+ 6.0,
                                                    color       = colormap,
                                                    line        = attr( width = 0.75,
                                                                        color = "black" )    ))

    # print("liq_tas: $liq_tas\n")

    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,nf)

    for i=1:nf
        annotations[i] =   attr(    xref        = "x",
                                    yref        = "y",
                                    x           = xc[i],
                                    y           = yc[i],
                                    text        = name[i],
                                    showarrow   = false,
                                    visible     = true,
                                    font        = attr( size = 10, color = "#212121"),
                                )  
    end

    layout  = Layout(

        title= attr(
            text    = "TAS Diagram (Anhydrous)",
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
        xaxis_title = "SiO2 [wt%]",
        yaxis_title = "K2O + Na2O [wt%]",
        xaxis_range = [35.0, 85.0], 
        # yaxis_range = [0.0,15.0],
        annotations = annotations,
        width       = 760,
        height      = 480,
        # autosize    = false,
    )

   
    return tas, layout
end

function get_init_param(    dtb         :: String,
                            solver      :: String,
                            cpx,        
                            limOpx,    
                            limOpxVal   :: Float64 )   

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

    return mbCpx,limitCaOpx,CaOpxLim,sol

end



function compute_Tliq(          pressure,   bulk_ini,   oxi,
                                dtb,        bufferType, solver,
                                verbose,    bulk,       bufferN,
                                cpx,        limOpx,     limOpxVal       )


        Tliq = "oki"


        out = MAGEMin_C.gmin_struct{Float64, Int64}

        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 


        # initialize single thread MAGEMin 
        gv, z_b, DB, splx_data = init_MAGEMin(  dtb;        
                                                verbose     = verbose,
                                                mbCpx       = mbCpx,
                                                limitCaOpx  = limitCaOpx,
                                                CaOpxLim    = CaOpxLim,
                                                buffer      = bufferType,
                                                solver      = sol    );
        sys_in  = "mol"
        gv      =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);

        out = deepcopy( point_wise_minimization(pressure,2000.0, gv, z_b, DB, splx_data, sys_in) )

        print("$out\n")

        LibMAGEMin.FreeDatabases(gv, DB, z_b)




    # # allocate
    # n_xeos      = SS_ref_db[ph_id].n_xeos
    # n_pc        = SS_ref_db[ph_id].n_em

    # pc_xeos     = zeros(n_pc,n_xeos)
    # pc_comp     = zeros(n_pc,gv.len_ox)
    # pc_G0       = zeros(n_pc)

    # tol         = 1e-6
    # target_dg   = 1e-4
    # n_max       = 32

    # for i=1:n_pc
    #     bump        = (rand(SS_ref_db[ph_id].n_xeos).-0.5)./100
    #     delta_g     = 1.0                                                   # initialize missfit
    #     a           = 0.0
    #     b           = 1.0
    #     n           = 1
    #     conv        = 0
    #     n           = 0
    #     sign_a      = -1


    #     while n < n_max && conv == 0
    #         c = (a+b)/2.0
    #         delta_g, comp_norm, g0 = get_delta_g(mSS_vec,id,ph,ph_id,bump,c,SS_ref_db,gv,z_b,target_dg)
    #         sign_c  = sign(delta_g)
    #         # print("delta_g: $delta_g\n")
    #         if abs(delta_g) < tol
    #             conv = 1
    #             pc_xeos[i,:] .= mSS_vec[id].xeos_Ppc .+ bump.*c
    #             pc_comp[i,:] .= comp_norm
    #             pc_G0[i]      = g0
    #         else
    #             if  sign_c == sign_a
    #                 a = c
    #                 sign_a = sign_c
    #             else
    #                 b = c
    #             end
                
    #         end
    #         n += 1
    #     end

    # end



        return Tliq
end



function compute_new_PTXpath(   nsteps,     PTdata,     mode,       bulk_ini,   oxi,
                                dtb,        bufferType, solver,
                                verbose,    bulk,       bufferN,
                                cpx,        limOpx,     limOpxVal,
                                nCon,       nRes                                  )

        global Out_PTX, ph_names, fracEvol, compo_matrix


        nsteps = Int64(nsteps)

        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 

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
                                    # mode            = "markers+lines",
                                    mode            = "lines",
                                    # marker          = attr(     size    = 5.0,
                                    #                             color   = "black"),
                                    line            = attr( dash    = "dash",
                                                            color   = "black", 
                                                            width   = 0.75)                ) 

     data_plot[n_ph+2] = scatter(   x               = x,
                                    y               = fracEvol[:,1].*100.0, 
                                    name            = "remaining %",
                                    hoverinfo       = "skip",
                                    # mode            = "markers+lines",
                                    mode            = "lines",
                                    # marker          = attr(     size    = 5.0,
                                    #                             color   = "black"),
                                    line            = attr( color   = "black", 
                                                            width   = 0.75)                ) 


    # build phase list:
    phase_list = [Dict("label" => "  "*ph_names[i], "value" => ph_names[i]) for i=1:n_ph]


    return data_plot, phase_list
end


"""
    function get_data_comp_plot(sysunit,phases)

    Gets the composition of selected stable phases accross the PTX paths and create a scatter plot
"""
function get_data_comp_plot(sysunit,phases)

    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_ph    = length(phases)
    n_tot   = length(Out_PTX)

    data_comp_plot  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ox);
    x               = Vector{Union{String,Missing}}(undef, (n_tot+1)*n_ph)
    compo_matrix    = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1)*n_ph) .= missing
    colormap        = get_jet_colormap(n_ox)
 
    k = 1
    for i=1:n_ph
        ph      = phases[i]
        for j=1:n_tot
            
            x[k]    = string(round(Out_PTX[j].P_kbar,digits=1))*"; "*string(round(Out_PTX[j].T_C,digits=1))
            id      = findall(Out_PTX[j].ph .== ph)

            if ~isempty(id)
                n_solvi = length(id)
                if sysunit == "mol"
                    
                    if n_solvi > 1      # then this is a solution phase as there is a solvus
                        for n=1:n_solvi
                            compo_matrix[:,k] += Out_PTX[j].SS_vec[id[n]].Comp ./ Float64(n_solvi) .*100.0
                        end
                    else
                        id      = id[1]
                        n_SS    = Out_PTX[j].n_SS
                        if id > n_SS    # then this is a pure phase
                            compo_matrix[:,k] = Out_PTX[j].PP_vec[id - n_SS].Comp .*100.0
                        else            # else this is a solution phase
                            compo_matrix[:,k] = Out_PTX[j].SS_vec[id].Comp .*100.0
                        end

                    end

                elseif sysunit == "wt"

                    if n_solvi > 1      # then this is a solution phase as there is a solvus
                        for n=1:n_solvi
                            compo_matrix[:,k] += Out_PTX[j].SS_vec[id[n]].Comp_wt ./ Float64(n_solvi) .*100.0
                        end
                    else
                        id      = id[1]
                        n_SS    = Out_PTX[j].n_SS
                        if id > n_SS    # then this is a pure phase
                            compo_matrix[:,k] = Out_PTX[j].PP_vec[id - n_SS].Comp_wt .*100.0
                        else            # else this is a solution phase
                            compo_matrix[:,k] = Out_PTX[j].SS_vec[id].Comp_wt .*100.0
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
                                        name        = oxides[k],
                                        mode        = "markers+lines",
                                        marker      = attr(     size    = 5.0,
                                                                color   = colormap[k]),

                                        line        = attr(     width   = 1.0,
                                                                color   = colormap[k])  )

    end


    return data_comp_plot
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

function initialize_comp_layout(sysunit)
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