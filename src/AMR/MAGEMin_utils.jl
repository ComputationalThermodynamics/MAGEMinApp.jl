
"""
    get_wat_sat_function(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                dtb,        bufferType, solver,
                                verbose,    bufferN,
                                cpx,        limOpx,     limOpxVal)
    
    Computes water-saturation at sub-solidus

"""
function get_wat_sat_function(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                    dtb,        bufferType, solver,
                                    verbose,    bufferN,
                                    cpx,        limOpx,     limOpxVal, watsat_val)
   
    id_h2o      = findfirst(oxi .== "H2O")
    hydrated    = 1;
    watsat_val  = watsat_val/100.0

    if bulk_ini[id_h2o] == 0.0
        hydrated = 0;
    end

    liq = 1;
    if ~isnothing(phase_selection) && "liq" in phase_selection
        liq = 0;
    end

    if liq == 1 && hydrated == 1                                
        println("Computing water-saturation at sub-solidus. Make sure you provided enough water to oversaturate below solidus.")
        stp     = (Yrange[2] - Yrange[1])/31.0                        
        Prange  = Vector(Yrange[1]:stp:Yrange[2])

        # prepare flags
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

        sys_in      = "mol"
        gv          =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);

        Tmin        = 500.0;
        Tliq        = 2200.0;
        tolerance   = 1e-4;      

        Tsol        = zeros(Float64,length(Prange))
        SatSol      = zeros(Float64,length(Prange))

        @showprogress 1 "Computing sub-solidus water-saturating curve..." for i = 1:length(Prange)

            pressure    = Prange[i]
            out         = deepcopy( point_wise_minimization(pressure, Tliq, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
            n_max       = 64
            a           = Tmin
            b           = Tliq
            n           = 1
            conv        = 0
            n           = 0
            sign_a      = -1

            while n < n_max && conv == 0
                c       = (a+b)/2.0
                out     = deepcopy( point_wise_minimization(pressure, c, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

                if "liq" in out.ph
                    result = 1;
                else
                    result = -1;
                end

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

            Tsol[i]     = (a+b)/2.0
            out         = deepcopy( point_wise_minimization(pressure, (a+b)/2.0 + 0.01 , gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

            id_dry      = findall(out.oxides .!= "H2O")
            id_h2o      = findall(out.oxides .== "H2O")[1]

            tmp_bulk    = deepcopy(out.bulk)

            # extracting excess water
            if "H2O" in out.ph
                id = findfirst(out.ph .== "H2O")
                tmp_bulk .-= out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
            elseif "fl" in out.ph
                id = findfirst(out.ph .== "fl")
                tmp_bulk .-= out.SS_vec[id].Comp .* out.ph_frac[id]
            end            
            tmp_bulk ./= sum(tmp_bulk)              # normalize to 100%

            if watsat_val > 0.0
                tmp_bulk[id_h2o] += watsat_val/(1.0 - watsat_val)
                tmp_bulk ./= sum(tmp_bulk) 
            end

            tmp_bulk ./= sum(tmp_bulk[id_dry])      # normalize on anhydrous basis, to get water content
            SatSol[i]  = tmp_bulk[id_h2o]
            
        end

        # println("SatSol $SatSol")
        pChip_wat   = Interpolator(Prange, SatSol)
        pChip_T     = Interpolator(Prange, Tsol)
        LibMAGEMin.FreeDatabases(gv, DB, z_b)
    else
        println("To compute water-saturation at sub-solidus liq must be part of the solution phase model and the bulk composition must contain water")
        println("Phase diagram will be computed without water-saturation at sub-solidus...")
        pChip_wat, pChip_T = nothing, nothing
    end

    return pChip_wat, pChip_T
end


"""
    MAGEMin_data2table( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}})

    Transform MAGEMin output into a table

"""
function MAGEMin_data2table( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}},dtb)

    db_in     = retrieve_solution_phase_information(dtb)
    datetoday = string(Dates.today())
    rightnow  = string(Dates.Time(Dates.now()))

    if typeof(out) == MAGEMin_C.gmin_struct{Float64, Int64}
        out = [out]
    end
    np      = length(out)

    table   = "# MAGEMin " * " $(out[1].MAGEMin_ver);" * datetoday * ", " * rightnow * "; using database " * AppData.db_inf.db_info * "\n"
    table   *=   "point[#] X[0.0-1.0] P[kbar] T[°C]" *" phase" * " mode[mol%]" * " mode[wt%]" * " log10(fO2)" * " log10(dQFM)" * " aH2O" * " aSiO2" * " aTiO2" *  " aAl2O3" *  " aMgO" *  " aFeO" * 
                " density[kg/m3]" * " volume[cm3/mol]" * " heatCapacity[kJ/K]" * " alpha[1/K]" * " Entropy[J/K]" * " Enthalpy[J]" *
                " Vp[km/s]" * " Vs[km/s]" * " Vp_S[km/s]" * " Vs_S[km/s]" *" BulkMod[GPa]" * " ShearMod[GPa]" *
                " " *join(out[1].oxides.*"[mol%]", " ") * " " *join(out[1].oxides.*"[wt%]", " ") *"\n"
    for k=1:np
        np  = length(out[k].ph)
        nss = out[k].n_SS
        npp = out[k].n_PP
        table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " system" * " 100.0" * " 100.0" * prt(out[k].fO2[1]) * prt(out[k].dQFM[1]) *prt(out[k].aH2O) *prt(out[k].aSiO2) *prt(out[k].aTiO2) *prt(out[k].aAl2O3) *prt(out[k].aMgO) *prt(out[k].aFeO) *
        prt(out[k].rho) * prt(out[k].V) * prt(out[k].s_cp[1]) * prt(out[k].alpha) * prt(out[k].entropy) * prt(out[k].enthalpy) *
        prt(out[k].Vp) * prt(out[k].Vs) *prt(out[k].Vp_S) * prt(out[k].Vs_S) *prt(out[k].bulkMod) * prt(out[k].shearMod) *
        prt(out[k].bulk.*100.0) * prt(out[k].bulk_wt.*100.0) * "\n"
        for i=1:nss
            table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[i] * prt(out[k].ph_frac[i].*100.0) * prt(out[k].ph_frac_wt[i].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
            prt(out[k].SS_vec[i].rho) * prt(out[k].SS_vec[i].V) * prt(out[k].SS_vec[i].cp) * prt(out[k].SS_vec[i].alpha) * prt(out[k].SS_vec[i].entropy) * prt(out[k].SS_vec[i].enthalpy) *
            prt(out[k].SS_vec[i].Vp) * prt(out[k].SS_vec[i].Vs) * " -" * " -" *prt(out[k].SS_vec[i].bulkMod) * prt(out[k].SS_vec[i].shearMod) *
            prt(out[k].SS_vec[i].Comp.*100.0) * prt(out[k].SS_vec[i].Comp_wt.*100.0) * "\n"
        end

        if npp > 0
            for i=1:npp
                pos = i + nss
                table *= "$k" * prt(out[k].X[1]) * prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[pos] * prt(out[k].ph_frac[pos].*100.0) * prt(out[k].ph_frac_wt[pos].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
                prt(out[k].PP_vec[i].rho) * prt(out[k].PP_vec[i].V) * prt(out[k].PP_vec[i].cp) * prt(out[k].PP_vec[i].alpha) * prt(out[k].PP_vec[i].entropy) * prt(out[k].PP_vec[i].enthalpy) *
                prt(out[k].PP_vec[i].Vp) * prt(out[k].PP_vec[i].Vs) * " -" * " -" * prt(out[k].PP_vec[i].bulkMod) * prt(out[k].PP_vec[i].shearMod) *
                prt(out[k].PP_vec[i].Comp.*100.0) * prt(out[k].PP_vec[i].Comp_wt.*100.0) * "\n"
            end
        end

    end


    return table
end


# find_dominant_em_ids
function find_dominant_em_ids(  SS_vec )
    n_ph    = length(SS_vec)
    ids     = ()
    for i=1:n_ph
        f    = SS_vec[i].emFrac
        ids  = (ids..., findfirst(f .== maximum(f)))
    end
    
    return ids
end

function get_dominant_em(   ph,
                            n_SS,
                            SS_vec)
    n_ph  = length(ph)
    ph_em = Vector{String}(undef,n_ph)
    for i=1:n_SS
        f = SS_vec[i].emFrac
        id = findall(f .== maximum(f))[1]
        em = SS_vec[i].emNames[id]
        ph_em[i] = ph[i]*":"*em
    end
    for i=n_SS+1:n_ph
        ph_em[i] = ph[i]
    end

    return ph_em
end

function get_data_thread( MAGEMin_db :: MAGEMin_Data )

    id          = Threads.threadid()
    gv          = MAGEMin_db.gv[id]
    z_b         = MAGEMin_db.z_b[id]
    DB          = MAGEMin_db.DB[id]
    splx_data   = MAGEMin_db.splx_data[id]
    
   return (gv, z_b, DB, splx_data)
end

function refine_MAGEMin(dtb,data, 
                        MAGEMin_data    :: MAGEMin_Data, 
                        custW           :: Bool,
                        diagType        :: String,
                        PTpath,
                        phase_selection :: Union{Nothing,Vector{Int64}},
                        fixT            :: Float64,
                        fixP            :: Float64,
                        e1_liq          :: Float64,
                        e2_liq          :: Float64,
                        e1_remain_wat       :: Float64,
                        e2_remain_wat       :: Float64,
                        e1_remain       :: Float64,
                        e2_remain       :: Float64,
                        oxi             :: Vector{String},
                        bulk_L          :: Vector{Float64},
                        bulk_R          :: Vector{Float64},
                        bufferType      :: String,
                        bufferN1        :: Float64,
                        bufferN2        :: Float64,
                        scp             :: Int64,
                        boost           :: Bool,
                        refType         :: String,
                        pChip_wat       , 
                        pChip_T         )
    global Out_XY, addedRefinementLvl;

    #= First we create a structure to store the data in memory =#
    if custW == true
        if !isempty(AppData.customWs)
            df = AppData.customWs
            n_entries = size(df,1)
            new_Ws = Vector{MAGEMin_C.W_data{Float64,Int64}}(undef, n_entries)

            for i=1:size(df,1)
                dtb     = df[i, :dtb]
                ss_id   = df[i, :id]
                n_Ws    = df[i, :n_Ws]
                Ws      = split(df[i, :Ws], ";")
                Ws      = parse.(Float64, Ws)
                Ws      = reshape(Ws, n_Ws, 3)
                
                new_Ws[i] = MAGEMin_C.W_data(dtb, ss_id, n_Ws, Ws)   

                # println("new_Ws: $(new_Ws)")
            end
        else
            new_Ws = nothing
        end
    else
        new_Ws = nothing
    end

    if isempty(data.split_cell_list)
        Out_XY_new      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.points))
        n_new_points    = length(data.points)
        npoints         = data.points
    else
        Out_XY_new      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.npoints))
        n_new_points    = length(data.npoints)
        npoints         = data.npoints
    end

    for i in 1:Threads.maxthreadid()
        MAGEMin_data.gv[i].buffer = pointer(bufferType)
    end

    if n_new_points > 0
        Tvec = zeros(Float64,n_new_points);
        Pvec = zeros(Float64,n_new_points);
        Xvec = Vector{Vector{Float64}}(undef,n_new_points);
        Bvec = zeros(Float64,n_new_points);

        if !isempty(data.split_cell_list) && boost == true
            Gvec = Vector{Vector{LibMAGEMin.mSS_data}}(undef,n_new_points);
            Ivec = Vector{Bool}(undef,n_new_points) .= true;
        else
            Ivec = false
            Gvec = nothing;
        end

        if diagType != "tt"    
            if diagType == "tx"

                for i = 1:n_new_points
                    Pvec[i] = fixP;
                    Tvec[i] = npoints[i][2];
                    Xvec[i] = bulk_L*(1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            elseif diagType == "px"

                for i = 1:n_new_points
                    Tvec[i] = fixT;
                    Pvec[i] = npoints[i][2];
                    Xvec[i] = bulk_L*(1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            elseif diagType == "pt"

                if "H2O" in oxi
                    id_h2o      = findfirst(oxi .== "H2O")
                    id_dry      = findall(oxi .!= "H2O")
                end

                for i = 1:n_new_points
                    Tvec[i] = npoints[i][1];
                    Pvec[i] = npoints[i][2];
                    Bvec[i] = bufferN1;
                    
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end

                    # here we check if the water need to be saturated at sub-solidus
                    if ~isnothing(pChip_wat)
                        TsatSol     = pChip_T(Pvec[i])
                        waterSat    = pChip_wat(Pvec[i])

                        if Tvec[i] > TsatSol        # if we are above the solidus then we use the water content from the sub-solidus curve
                            tmp_bulk              = deepcopy(bulk_L)
                            tmp_bulk            ./= sum(tmp_bulk[id_dry])
                            tmp_bulk[id_h2o]      = waterSat
                            tmp_bulk            ./= sum(tmp_bulk)

                            if !isempty(data.ncorners) && boost == true # Here we roughly check if the bulk composition is feasible with respect to initial guess
                                check_bulk = vcat([Out_XY[data.npoints_ig[i][j]].bulk[id_h2o] for j=1:length(data.npoints_ig[i])]...)
                                if tmp_bulk[id_h2o] > maximum(check_bulk) || tmp_bulk[id_h2o] < minimum(check_bulk)
                                    Ivec[i] = false
                                end
                            end   

                            Xvec[i]               = tmp_bulk
                        else
                            Xvec[i] = bulk_L;
                        end
                    else
                        Xvec[i] = bulk_L;
                    end
                end
            elseif diagType == "ptx"

                ptx_data    = copy(PTpath)
                np          = length(ptx_data)
                Pres        = zeros(Float64,np)
                Temp        = zeros(Float64,np)
                x           = zeros(Float64,np)
                for i=1:np
                    Pres[i] = ptx_data[i][Symbol("col-1")]
                    Temp[i] = ptx_data[i][Symbol("col-2")]
                    x[i]    = (i-1)*(1.0/(np-1))
                end
                pChipInterp_P = Interpolator(x, Pres)
                pChipInterp_T = Interpolator(x, Temp)

                for i = 1:n_new_points
                    Tvec[i] = pChipInterp_T(npoints[i][2]); 
                    Pvec[i] = pChipInterp_P(npoints[i][2]);
                    Xvec[i] = bulk_L*(  1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true

                        n_ph = [ length(Out_XY[data.npoints_ig[i][j]].ph) for j=1:length(data.npoints_ig[i])]
                        ids  = sortperm(n_ph, rev=true)

                        tmp = [Out_XY[data.npoints_ig[i][ids[j]]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            end
            if diagType == "pt" && dtb != "sb11" && dtb != "sb21" && isnothing(pChip_wat) == true
                fixed_bulk = true
            else
                fixed_bulk = false
            end
            Out_XY_new  =   multi_point_minimization(   Pvec, Tvec, MAGEMin_data;
                                                        X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol", G=Gvec, scp=scp, 
                                                        rm_list=phase_selection, name_solvus=true, fixed_bulk=fixed_bulk, iguess=Ivec, callback_fn = update_progress, W=new_Ws); 
        else
            # if TT diagram does not exist, compute it
            id_h2o = findfirst(oxi .== "H2O") # check if H2O is in the oxides
            if isempty(data.split_cell_list)    
                n           = Int64(sqrt(n_new_points))
                Out_col_1   = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n)
                start_bulk  = deepcopy(bulk_L)
                for i=1:n
                    out     = single_point_minimization(    fixP, npoints[i][2], MAGEMin_data;
                                                            X=start_bulk, B=bufferN1, Xoxides=oxi, sys_in="mol",  scp=scp, 
                                                            rm_list=phase_selection, name_solvus=true)   
                    
                    if "fl" in out.ph || "H2O" in out.ph || "liq" in out.ph
                        if "fl" in out.ph
                            id               = findfirst(out.ph .== "fl")
                            start_bulk      .= out.bulk .- out.SS_vec[id].Comp .* out.ph_frac[id]
                            start_bulk     .+= e1_remain_wat .* out.SS_vec[id].Comp;
                        end
                        if "H2O" in out.ph
                            id               = findfirst(out.ph .== "H2O")
                            start_bulk      .= out.bulk .- out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
                            start_bulk[id_h2o]  += e1_remain_wat;
                        end
                        if "liq" in out.ph
                            id = findfirst(out.ph .== "liq")

                            if  out.ph_frac_vol[id] > e1_liq/100.0
                                ratio        = (out.ph_frac_vol[id] - e1_remain/100.0)/out.ph_frac_vol[id]
                                start_bulk  .= out.bulk .- out.SS_vec[id].Comp .* (out.ph_frac[id]*ratio)
                            end
                        end
                        start_bulk ./= sum(start_bulk)
        
                        out         = single_point_minimization(    fixP, npoints[i][2], MAGEMin_data;
                                                                    X=start_bulk, B=bufferN1, Xoxides=oxi, sys_in="mol",  scp=scp, 
                                                                    rm_list=phase_selection, name_solvus=true, W=new_Ws)   
            
                        Out_col_1[i] = deepcopy(out)
                    else
                        Out_col_1[i] = deepcopy(out)
                    end
                end

                Out_rows    = Vector{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}}(undef, n);
                progr       = Progress(n, desc="Computing $n Polymetamorphic paths...") # progress meter
                @threads :static for i=1:n

                    Out_PT      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, n)
                    P_          = fixP
                    T_          = collect(range(data.Xrange[1], stop=data.Xrange[2], length=n))
                    bulk_       = deepcopy(Out_col_1[i].bulk)

                    gv, z_b, DB, splx_data = get_data_thread(MAGEMin_data)
                    gv          = define_bulk_rock(gv, bulk_, oxi, "mol",unsafe_string(gv.db))
                    for j=1:n 

                        out     = point_wise_minimization(  P_, T_[j], gv, z_b, DB, splx_data;
                                                            buffer_n=bufferN1, name_solvus=true, scp=scp, rm_list=phase_selection, W=new_Ws)

                        if "fl" in out.ph || "H2O" in out.ph || "liq" in out.ph
                            if "fl" in out.ph
                                id              = findfirst(out.ph .== "fl")
                                bulk_          .= out.bulk .- out.SS_vec[id].Comp .* out.ph_frac[id]
                                bulk_           .+= e2_remain_wat .* out.SS_vec[id].Comp;
                            end
                            if "H2O" in out.ph
                                id              = findfirst(out.ph .== "H2O")
                                bulk_          .= out.bulk .- out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
                                bulk_[id_h2o]  += e2_remain_wat;
                            end
                            if "liq" in out.ph
                                id = findfirst(out.ph .== "liq")
                                if  out.ph_frac_vol[id] > e2_liq/100.0
                                    ratio        = (out.ph_frac_vol[id] - e2_remain/100.0)/out.ph_frac_vol[id]
                                    bulk_       .= out.bulk .- out.SS_vec[id].Comp .* (out.ph_frac[id]*ratio)
                                end
                            end
                            gv      = define_bulk_rock(gv, bulk_, oxi, "mol",unsafe_string(gv.db))
                            out     = point_wise_minimization(  P_, T_[j], gv, z_b, DB, splx_data;
                                                                buffer_n=bufferN1, name_solvus=true, scp=scp, rm_list=phase_selection, W=new_Ws)

                            Out_PT[j] = deepcopy(out)
                        else
                            Out_PT[j] = deepcopy(out)
                        end
                    end
                    Out_rows[i] = Out_PT
                    next!(progr)
                end
                finish!(progr)

                for i=1:n
                    for j=1:n
                        Out_XY_new[(i-1)*n+j] = Out_rows[j][i]
                    end
                end

            else #refinement of the TT diagram
                for i = 1:n_new_points
                    Tvec[i] = npoints[i][1];
                    Pvec[i] = fixP;
                    Bvec[i] = bufferN1;

                    tmp_bulk = zeros(length(oxi))
                    for j=1:length(data.ncorners[i])
                        tmp_bulk .+= Out_XY[data.ncorners[i][j]].bulk
                    end
                    tmp_bulk  ./= Float64(length(data.ncorners[i]))
                    Xvec[i]     = tmp_bulk

                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end

                Out_XY_new  =   multi_point_minimization(   Pvec, Tvec, MAGEMin_data;
                                                            X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol", G=Gvec, scp=scp, 
                                                            rm_list=phase_selection, name_solvus=true, iguess=boost, callback_fn = update_progress, W=new_Ws); 

            end
        end

    else
        println("There is no new point to compute...")
    end
    Out_XY      = vcat(Out_XY, Out_XY_new)

    # Compute hash for all points
    n_points    = length(Out_XY)
    Hash_XY     = Vector{UInt64}(undef,n_points)
    n_phase_XY  = Vector{Int64}(undef,n_points)

    if refType == "ph"
        for i=1:n_points
            Hash_XY[i]      = hash(sort(Out_XY[i].ph))
            n_phase_XY[i]   = length(Out_XY[i].ph)
        end
    elseif refType == "em"
        for i=1:n_points
            ph_em = get_dominant_em(    Out_XY[i].ph,
                                        Out_XY[i].n_SS,
                                        Out_XY[i].SS_vec)

            Hash_XY[i]      = hash(sort(ph_em))
            n_phase_XY[i]   = length(ph_em)
        end
    end

    if diagType == "tx" || diagType == "px" || diagType == "ptx"
        for i=1:n_points
            Out_XY[i].X .= data.points[i][1]
        end
    end

    return Out_XY, Hash_XY, n_phase_XY  
end

