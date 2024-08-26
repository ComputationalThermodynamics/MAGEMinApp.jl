
"""
    get_wat_sat_functions(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                dtb,        bufferType, solver,
                                verbose,    bufferN,
                                cpx,        limOpx,     limOpxVal)
    
    Computes water-saturation at sub-solidus

"""
function get_wat_sat_functions(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                    dtb,        bufferType, solver,
                                    verbose,    bufferN,
                                    cpx,        limOpx,     limOpxVal)
   
    id_h2o      = findall(oxi .== "H2O")[1]   
    hydrated    = 1;
    if bulk_ini[id_h2o] == 0.0
        hydrated = 0;
    end

    liq = 1;
    if ~isnothing(phase_selection) && "liq" in phase_selection
        liq = 0;
    end

    if liq == 1 && hydrated == 1                                
        println("Computing water-saturation at sub-solidus. Make sure you provided enough water to oversaturate below solidus.")
        stp     = (Yrange[2] - Yrange[1])/49.0                        
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
        tolerance   = 0.1;      

        Tsol        = zeros(Float64,length(Prange))
        SatSol      = zeros(Float64,length(Prange))

        @showprogress 1 "Computing sub-solidus water-saturating curve..." for i = 1:length(Prange)

            pressure    = Prange[i]
            out         = deepcopy( point_wise_minimization(pressure, Tliq, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection) )
            n_max       = 32
            a           = Tmin
            b           = Tliq
            n           = 1
            conv        = 0
            n           = 0
            sign_a      = -1

            while n < n_max && conv == 0
                c       = (a+b)/2.0
                out     = deepcopy( point_wise_minimization(pressure, c, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection) )

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
            out         = deepcopy( point_wise_minimization(pressure, Tsol[i] + 0.5 , gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection) )

            id_dry      = findall(out.oxides .!= "H2O")
            id_h2o      = findall(out.oxides .== "H2O")[1]

            tmp_bulk    = deepcopy(out.bulk)

            # extracting excess water
            if "H2O" in out.ph
                id = findall(out.ph .== "H2O")[1]
                tmp_bulk .-= out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
            elseif "fl" in out.ph
                id = findall(out.ph .== "fl")[1]
                tmp_bulk .-= out.SS_vec[id].Comp .* out.ph_frac[id]
            end            

            tmp_bulk ./= sum(tmp_bulk)              # normalize to 100%
            tmp_bulk ./= sum(tmp_bulk[id_dry])      # normalize on anhydrous basis, to get water content
            
            SatSol[i]  = tmp_bulk[id_h2o]
        end
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
    create_forest( tmin::Float64,
                            tmax::Float64,
                            pmin::Float64,
                            pmax::Float64,
                            sub::Int64)
"""
function create_forest( tmin::Float64,
                        tmax::Float64,
                        pmin::Float64,
                        pmax::Float64,
                        sub::Int64)

    # Create coarse mesh
    Prange          = (pmin,pmax)
    Trange          = (tmin,tmax)        # in Paraview it looks a bit weird with actual values
    cmesh           = t8_cmesh_quad_2d(COMM, Trange, Prange)

    # Refine coarse mesh (in a regular manner)
    level           = sub
    forest          = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, COMM)
    forest_data     = get_element_data(forest)

    return forest_data
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

    table   = "# MAGEMin " * " $(out[1].MAGEMin_ver);" * datetoday * ", " * rightnow * "; using database " * db_in.db_info * "\n"
    table   *=   "point[#] X[0.0-1.0] P[kbar] T[°C]" *" phase" * " mode[mol%]" * " mode[wt%]" * " log10(fO2)" * " log10(dQFM)" * " aH2O" * " aSiO2" * " aTiO2" *  " aAl2O3" *  " aMgO" *  " aFeO" * 
                " density[kg/m3]" * " volume[cm3/mol]" * " heatCapacity[kJ/K]" * " alpha[1/K]" * " Entropy[J/K]" * " Enthalpy[J]" *
                " Vp[km/s]" * " Vs[km/s]" * " Vp_S[km/s]" * " Vs_S[km/s]" *" BulkMod[GPa]" * " ShearMod[GPa]" *
                " " *join(out[1].oxides.*"[mol%]", " ") * " " *join(out[1].oxides.*"[wt%]", " ") *"\n"
    for k=1:np
        np  = length(out[k].ph)
        nss = out[k].n_SS
        npp = out[k].n_PP
        table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " system" * " 100.0" * " 100.0" * prt(out[k].fO2[1]) * prt(out[k].dQFM[1]) *prt(out[k].aH2O) *prt(out[k].aSiO2) *prt(out[k].aTiO2) *prt(out[k].aAl2O3) *prt(out[k].aMgO) *prt(out[k].aFeO) *
        prt(out[k].rho) * prt(out[k].V) * prt(out[k].cp) * prt(out[k].alpha) * prt(out[k].entropy) * prt(out[k].enthalpy) *
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


function refine_MAGEMin(data, 
                        MAGEMin_data    :: MAGEMin_Data, 
                        diagType        :: String,
                        PTpath,
                        phase_selection :: Union{Nothing,Vector{Int64}},
                        fixT            :: Float64,
                        fixP            :: Float64,
                        oxi             :: Vector{String},
                        bulk_L          :: Vector{Float64},
                        bulk_R          :: Vector{Float64},
                        bufferType      :: String,
                        bufferN1        :: Float64,
                        bufferN2        :: Float64,
                        scp             :: Int64,
                        refType         :: String,
                        pChip_wat       , 
                        pChip_T         ;        
                        ind_map          = nothing, 
                        Out_XY_old       = nothing)

    if isnothing(ind_map)
        ind_map = - ones(length(data.xc));
    end

    for i in 1:Threads.nthreads()
        MAGEMin_data.gv[i].buffer = pointer(bufferType)
    end

    # Step 1: determine all points that have not been computed yet
    ind_new         = findall( ind_map .< 0)
    n_new_points    = length(ind_new)

    Out_XY      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.x))
    Out_XY_new  = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n_new_points)
    if n_new_points > 0
       
        if diagType == "tx"
            Tvec = zeros(Float64,n_new_points);
            Pvec = zeros(Float64,n_new_points);
            Xvec = Vector{Vector{Float64}}(undef,n_new_points);
            Bvec = zeros(Float64,n_new_points);
            for (i, new_ind) = enumerate(ind_new)
                Pvec[i] = fixP;
                Tvec[i] = data.yc[new_ind];
                Xvec[i] = bulk_L*(1.0 - data.xc[new_ind]) + bulk_R*data.xc[new_ind];
                Bvec[i] = bufferN1*(1.0 - data.xc[new_ind]) + bufferN2*data.xc[new_ind];
            end
        elseif diagType == "px"
            Tvec = zeros(Float64,n_new_points);
            Pvec = zeros(Float64,n_new_points);
            Xvec = Vector{Vector{Float64}}(undef,n_new_points);
            Bvec = zeros(Float64,n_new_points);
            for (i, new_ind) = enumerate(ind_new)
                Tvec[i] = fixT;
                Pvec[i] = data.yc[new_ind];
                Xvec[i] = bulk_L*(1.0 - data.xc[new_ind]) + bulk_R*data.xc[new_ind];
                Bvec[i] = bufferN1*(1.0 - data.xc[new_ind]) + bufferN2*data.xc[new_ind];

            end
        elseif diagType == "pt"

            id_h2o      = findall(oxi .== "H2O")[1]
            id_dry      = findall(oxi .!= "H2O")
            
            Tvec = zeros(Float64,n_new_points);
            Pvec = zeros(Float64,n_new_points);
            Xvec = Vector{Vector{Float64}}(undef,n_new_points);
            Bvec = zeros(Float64,n_new_points);
            for (i, new_ind) = enumerate(ind_new)

                Tvec[i] = data.xc[new_ind];
                Pvec[i] = data.yc[new_ind];
                Bvec[i] = bufferN1;

                # here we check if the water need to be saturated at sub-solidus
                if ~isnothing(pChip_wat)
                    TsatSol     = pChip_T(Pvec[i])
                    waterSat    = pChip_wat(Pvec[i])
                    if Tvec[i] > TsatSol        # if we are above the solidus then we use the water content from the sub-solidus curve
                        bulk_tmp              = deepcopy(bulk_L)
                        bulk_tmp            ./= sum(bulk_tmp[id_dry])
                        bulk_tmp[id_h2o]      = waterSat
                        bulk_tmp            ./= sum(bulk_tmp)
                        Xvec[i]               = bulk_tmp
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

            Tvec = zeros(Float64,n_new_points);
            Pvec = zeros(Float64,n_new_points);
            Xvec = Vector{Vector{Float64}}(undef,n_new_points);
            Bvec = zeros(Float64,n_new_points);
            for (i, new_ind) = enumerate(ind_new)
                Tvec[i] = pChipInterp_T(data.yc[new_ind]); 
                Pvec[i] = pChipInterp_P(data.yc[new_ind]);
                Xvec[i] = bulk_L*(1.0 - data.xc[new_ind]) + bulk_R*data.xc[new_ind];
                Bvec[i] = bufferN1*(1.0 - data.xc[new_ind]) + bufferN2*data.xc[new_ind];
            end
        end

        Out_XY_new  =   multi_point_minimization(Pvec, Tvec, MAGEMin_data, X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol", scp=scp, rm_list=phase_selection); 
    end

    # Step 2: Collect new and old results
    new_point = 0;
    for (i, map) = enumerate(ind_map)
        if map>0
            Out_XY[i] = Out_XY_old[map]
        else
            new_point += 1
            Out_XY[i] = Out_XY_new[new_point]
        end
    end
    Out_XY_new = []

    # Compute hash for all points
    Hash_XY     = Vector{UInt64}(undef,length(data.x))
    n_phase_XY  = Vector{UInt64}(undef,length(data.x))

    miny        = minimum(data.yc)
    maxx        = maximum(data.xc)
    maxy        = maximum(data.yc)
    minx        = minimum(data.xc)
    if refType == "ph"

        for i=1:length(data.x)
            Hash_XY[i]      = hash(sort(Out_XY[i].ph))
            n_phase_XY[i]   = length(Out_XY[i].ph)

            if data.xc[i] == maxx && data.yc[i] == miny
                Hash_XY[i]      = hash("doo")
            end
            if data.xc[i] == minx && data.yc[i] == maxy
                Hash_XY[i]      = hash("foo")
            end

        end
    elseif refType == "em"

        for i=1:length(data.x)

            ph_em = get_dominant_en(    Out_XY[i].ph,
                                        Out_XY[i].n_SS,
                                        Out_XY[i].SS_vec)

            Hash_XY[i]      = hash(sort(ph_em))
            n_phase_XY[i]   = length(ph_em)

            if data.xc[i] == maxx && data.yc[i] == miny
                Hash_XY[i]      = hash("doo")
            end
            if data.xc[i] == minx && data.yc[i] == maxy
                Hash_XY[i]      = hash("foo")
            end
        end
    end

    if diagType == "tx" || diagType == "px" || diagType == "ptx"
        for i=1:length(data.x)
            Out_XY[i].X .= data.xc[i]
        end
    end

    return Out_XY, Hash_XY, n_phase_XY  
end



function get_dominant_en(   ph,
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
