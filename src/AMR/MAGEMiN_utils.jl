
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
    table   *=   "point[#] P[kbar] T[°C]" *" phase" * " mode[mol%]" * " mode[wt%]" * " log10(fO2)" * " log10(dQFM)" * 
                " density[kg/m3]" * " volume[cm3/mol]" * " heatCapacity[kJ/K]" * " alpha[1/K]" * " Entropy[J/K]" * " Enthalpy[J]" *
                " Vp[km/s]" * " Vs[km/s]" * " BulkMod[GPa]" * " ShearMod[GPa]" *
                " " *join(out[1].oxides.*"[mol%]", " ") * " " *join(out[1].oxides.*"[wt%]", " ") *"\n"
    for k=1:np
        np  = length(out[k].ph)
        nss = out[k].n_SS
        npp = np-nss
        table *= "$k" * prt(out[k].P_kbar) * prt(out[k].T_C) * " system" * " 100.0" * " 100.0" * " "*string(out[k].fO2) * " "*string(out[k].dQFM) *
        prt(out[k].rho) * prt(out[k].V) * prt(out[k].cp) * prt(out[k].alpha) * prt(out[k].entropy) * prt(out[k].enthalpy) *
        prt(out[k].Vp) * prt(out[k].Vs) *prt(out[k].bulkMod) * prt(out[k].shearMod) *
        prt(out[k].bulk.*100.0) * prt(out[k].bulk_wt.*100.0) * "\n"
        for i=1:nss
            table *= "$k" * prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[i] * prt(out[k].ph_frac[i].*100.0) * prt(out[k].ph_frac_wt[i].*100.0) * " -" *
            prt(out[k].SS_vec[i].rho) * prt(out[k].SS_vec[i].V) * prt(out[k].SS_vec[i].cp) * prt(out[k].SS_vec[i].alpha) * prt(out[k].SS_vec[i].entropy) * prt(out[k].SS_vec[i].enthalpy) *
            prt(out[k].SS_vec[i].Vp) * prt(out[k].SS_vec[i].Vs) * prt(out[k].SS_vec[i].bulkMod) * prt(out[k].SS_vec[i].shearMod) *
            prt(out[k].SS_vec[i].Comp.*100.0) * prt(out[k].SS_vec[i].Comp_wt.*100.0) * "\n"
        end

        if npp > 0
            for i=1:npp
                pos = i + nss
                table *= "$k" * prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[pos] * prt(out[k].ph_frac[pos].*100.0) * prt(out[k].ph_frac_wt[pos].*100.0) * " -" *
                prt(out[k].PP_vec[i].rho) * prt(out[k].PP_vec[i].V) * prt(out[k].PP_vec[i].cp) * prt(out[k].PP_vec[i].alpha) * prt(out[k].PP_vec[i].entropy) * prt(out[k].PP_vec[i].enthalpy) *
                prt(out[k].PP_vec[i].Vp) * prt(out[k].PP_vec[i].Vs) * prt(out[k].PP_vec[i].bulkMod) * prt(out[k].PP_vec[i].shearMod) *
                prt(out[k].PP_vec[i].Comp.*100.0) * prt(out[k].PP_vec[i].Comp_wt.*100.0) * "\n"
            end
        end

    end


    return table
end

function refine_MAGEMin(data, 
                        MAGEMin_data    :: MAGEMin_Data, 
                        diagType        :: String,
                        fixT            :: Float64,
                        fixP            :: Float64,
                        oxi             :: Vector{String},
                        bulk_L          :: Vector{Float64},
                        bulk_R          :: Vector{Float64},
                        bufferType      :: String,
                        bufferN1        :: Float64,
                        bufferN2        :: Float64,
                        refType         :: String;
                        ind_map          = nothing, 
                        Out_XY_old       = nothing, 
                        n_phase_XY_old   = nothing)

    if isnothing(ind_map)
        ind_map = - ones(length(data.xc));
    end

    for i in 1:Threads.nthreads()
        MAGEMin_data.gv[i].buffer = pointer(bufferType)
    end

    Out_XY = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.x))

    # Step 1: determine all points that have not been computed yet
    ind_new      = findall( ind_map .< 0)
    n_new_points = length(ind_new)
    Out_XY_new   = []
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
        else 
            Tvec = zeros(Float64,n_new_points);
            Pvec = zeros(Float64,n_new_points);
            Xvec = Vector{Vector{Float64}}(undef,n_new_points);
            Bvec = zeros(Float64,n_new_points);
            for (i, new_ind) = enumerate(ind_new)
                Tvec[i] = data.xc[new_ind];
                Pvec[i] = data.yc[new_ind];
                Xvec[i] = bulk_L;
                Bvec[i] = bufferN1;
            end
        end
        Out_XY_new  =   multi_point_minimization(Pvec, Tvec, MAGEMin_data, X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol");
        
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

    if refType == "ph"

        for i=1:length(data.x)
            Hash_XY[i]      = hash(sort(Out_XY[i].ph))
            n_phase_XY[i]   = length(Out_XY[i].ph)

            if data.xc[i] == maxx && data.yc[i] == miny
                Hash_XY[i]      = hash("pouet")
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
                Hash_XY[i]      = hash("pouet")
            end
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
