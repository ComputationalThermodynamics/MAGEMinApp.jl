
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
MAGEMin_data2dataframe( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}})

    Transform MAGEMin output into a dataframe for quick(ish) save

"""
function MAGEMin_data2dataframe( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}},dtb,fileout)

    db_in     = retrieve_solution_phase_information(dtb)
    datetoday = string(Dates.today())
    rightnow  = string(Dates.Time(Dates.now()))

    metadata   = "# MAGEMin " * " $(out[1].MAGEMin_ver);" * datetoday * ", " * rightnow * "; using database " * db_in.db_info * "\n"

    # Here we create the dataframe's header:
    MAGEMin_db = DataFrame(         Symbol("point[#]")      => Int64[],
                                    Symbol("X[0.0-1.0]")    => Float64[],
                                    Symbol("P[kbar]")       => Float64[],
                                    Symbol("T[°C]")         => Float64[],
                                    Symbol("phase")         => String[],
                                    Symbol("mode[mol%]")    => Float64[],
                                    Symbol("mode[wt%]")     => Float64[],
                                    Symbol("log10(fO2)")    => Float64[],
                                    Symbol("log10(dQFM)")   => Float64[],
                                    Symbol("aH2O")          => Float64[],
                                    Symbol("aSiO2")         => Float64[],
                                    Symbol("aTiO2")         => Float64[],
                                    Symbol("aAl2O3")        => Float64[],
                                    Symbol("aMgO")          => Float64[],
                                    Symbol("aFeO")          => Float64[],
                                    Symbol("density[kg/m3]")    => Float64[],
                                    Symbol("volume[cm3/mol]")   => Float64[],
                                    Symbol("heatCapacity[kJ/K]")=> Float64[],
                                    Symbol("alpha[1/K]")    => Float64[],
                                    Symbol("Entropy[J/K]")  => Float64[],
                                    Symbol("Enthalpy[J]")   => Float64[],
                                    Symbol("Vp[km/s]")      => Float64[],
                                    Symbol("Vs[km/s]")      => Float64[],
                                    Symbol("BulkMod[GPa]")  => Float64[],
                                    Symbol("ShearMod[GPa]") => Float64[],
    )

    for i in out[1].oxides
        col = i*"[mol%]"
        MAGEMin_db[!, col] = Float64[] 
    end

    for i in out[1].oxides
        col = i*"[wt%]"
        MAGEMin_db[!, col] = Float64[] 
    end

    # here we fill the dataframe with the all minimized point entries
    if typeof(out) == MAGEMin_C.gmin_struct{Float64, Int64}
        out = [out]
    end
    np      = length(out)

    print("\noutput path: $(pwd())\n")
    @showprogress "Saving data to csv..." for k=1:np
        np  = length(out[k].ph)
        nss = out[k].n_SS
        npp = np-nss

        part_1 = Dict(  "point[#]"      => k,
                        "X[0.0-1.0]"    => out[k].X[1],
                        "P[kbar]"       => out[k].P_kbar,
                        "T[°C]"         => out[k].T_C,
                        "phase"         => "system",
                        "mode[mol%]"    => 100.0,
                        "mode[wt%]"     => 100.0,
                        "log10(fO2)"    => out[k].fO2[1],
                        "log10(dQFM)"   => out[k].dQFM[1],
                        "aH2O"          => out[k].aH2O,
                        "aSiO2"         => out[k].aSiO2,
                        "aTiO2"         => out[k].aTiO2,
                        "aAl2O3"        => out[k].aAl2O3,
                        "aMgO"          => out[k].aMgO,
                        "aFeO"          => out[k].aFeO,
                        "density[kg/m3]"    => out[k].rho,
                        "volume[cm3/mol]"   => out[k].V,
                        "heatCapacity[kJ/K]"=> out[k].cp,
                        "alpha[1/K]"    => out[k].alpha,
                        "Entropy[J/K]"  => out[k].entropy,
                        "Enthalpy[J]"   => out[k].enthalpy,
                        "Vp[km/s]"      => out[k].Vp,
                        "Vs[km/s]"      => out[k].Vs,
                        "BulkMod[GPa]"  => out[k].bulkMod,
                        "ShearMod[GPa]" => out[k].shearMod )          

        part_2 = Dict(  (out[1].oxides[j]*"[mol%]" => out[k].bulk[j]*100.0)
                        for j in eachindex(out[1].oxides))

        part_3 = Dict(  (out[1].oxides[j]*"[wt%]" => out[k].bulk_wt[j]*100.0)
                        for j in eachindex(out[1].oxides))
   
        row    = merge(part_1,part_2,part_3)   

        push!(MAGEMin_db, row, cols=:union)

        for i=1:nss
            part_1 = Dict(  "point[#]"      => k,
                            "X[0.0-1.0]"    => out[k].X[1],
                            "P[kbar]"       => out[k].P_kbar,
                            "T[°C]"         => out[k].T_C,
                            "phase"         => out[k].ph[i],
                            "mode[mol%]"    => out[k].ph_frac[i].*100.0,
                            "mode[wt%]"     => out[k].ph_frac_wt[i].*100.0,
                            "log10(fO2)"    => "-",
                            "log10(dQFM)"   => "-",
                            "aH2O"          => "-",
                            "aSiO2"         => "-",
                            "aTiO2"         => "-",
                            "aAl2O3"        => "-",
                            "aMgO"          => "-",
                            "aFeO"          => "-",
                            "density[kg/m3]"    => out[k].SS_vec[i].rho,
                            "volume[cm3/mol]"   => out[k].SS_vec[i].V,
                            "heatCapacity[kJ/K]"=> out[k].SS_vec[i].cp,
                            "alpha[1/K]"    => out[k].SS_vec[i].alpha,
                            "Entropy[J/K]"  => out[k].SS_vec[i].entropy,
                            "Enthalpy[J]"   => out[k].SS_vec[i].enthalpy,
                            "Vp[km/s]"      => out[k].SS_vec[i].Vp,
                            "Vs[km/s]"      => out[k].SS_vec[i].Vs,
                            "BulkMod[GPa]"  => out[k].SS_vec[i].bulkMod,
                            "ShearMod[GPa]" => out[k].SS_vec[i].shearMod )  

            part_2 = Dict(  (out[1].oxides[j]*"[mol%]" => out[k].SS_vec[i].Comp[j]*100.0)
                            for j in eachindex(out[1].oxides))

            part_3 = Dict(  (out[1].oxides[j]*"[wt%]" => out[k].SS_vec[i].Comp_wt[j]*100.0)
                            for j in eachindex(out[1].oxides))

            row    = merge(part_1,part_2,part_3)   

            push!(MAGEMin_db, row, cols=:union)
            
        end

        if npp > 0
            for i=1:npp
                pos = i + nss

                part_1 = Dict(  "point[#]"      => k,
                                "X[0.0-1.0]"    => out[k].X[1],
                                "P[kbar]"       => out[k].P_kbar,
                                "T[°C]"         => out[k].T_C,
                                "phase"         => out[k].ph[pos],
                                "mode[mol%]"    => out[k].ph_frac[pos].*100.0,
                                "mode[wt%]"     => out[k].ph_frac_wt[pos].*100.0,
                                "log10(fO2)"    => "-",
                                "log10(dQFM)"   => "-",
                                "aH2O"          => "-",
                                "aSiO2"         => "-",
                                "aTiO2"         => "-",
                                "aAl2O3"        => "-",
                                "aMgO"          => "-",
                                "aFeO"          => "-",
                                "density[kg/m3]"    => out[k].PP_vec[i].rho,
                                "volume[cm3/mol]"   => out[k].PP_vec[i].V,
                                "heatCapacity[kJ/K]"=> out[k].PP_vec[i].cp,
                                "alpha[1/K]"    => out[k].PP_vec[i].alpha,
                                "Entropy[J/K]"  => out[k].PP_vec[i].entropy,
                                "Enthalpy[J]"   => out[k].PP_vec[i].enthalpy,
                                "Vp[km/s]"      => out[k].PP_vec[i].Vp,
                                "Vs[km/s]"      => out[k].PP_vec[i].Vs,
                                "BulkMod[GPa]"  => out[k].PP_vec[i].bulkMod,
                                "ShearMod[GPa]" => out[k].PP_vec[i].shearMod )  

                part_2 = Dict(  (out[1].oxides[j]*"[mol%]" => out[k].PP_vec[i].Comp[j]*100.0)
                                for j in eachindex(out[1].oxides))

                part_3 = Dict(  (out[1].oxides[j]*"[wt%]" => out[k].PP_vec[i].Comp_wt[j]*100.0)
                                for j in eachindex(out[1].oxides))

                row    = merge(part_1,part_2,part_3)   

                push!(MAGEMin_db, row, cols=:union)

            end
        end

    end

    meta = fileout*"_metadata.txt"
    filename = fileout*".csv"
    CSV.write(filename, MAGEMin_db)

    open(meta, "w") do file
        write(file, metadata)
    end

    return nothing
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
                " Vp[km/s]" * " Vs[km/s]" * " BulkMod[GPa]" * " ShearMod[GPa]" *
                " " *join(out[1].oxides.*"[mol%]", " ") * " " *join(out[1].oxides.*"[wt%]", " ") *"\n"
    for k=1:np
        np  = length(out[k].ph)
        nss = out[k].n_SS
        npp = np-nss
        table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " system" * " 100.0" * " 100.0" * prt(out[k].fO2[1]) * prt(out[k].dQFM[1]) *prt(out[k].aH2O) *prt(out[k].aSiO2) *prt(out[k].aTiO2) *prt(out[k].aAl2O3) *prt(out[k].aMgO) *prt(out[k].aFeO) *
        prt(out[k].rho) * prt(out[k].V) * prt(out[k].cp) * prt(out[k].alpha) * prt(out[k].entropy) * prt(out[k].enthalpy) *
        prt(out[k].Vp) * prt(out[k].Vs) *prt(out[k].bulkMod) * prt(out[k].shearMod) *
        prt(out[k].bulk.*100.0) * prt(out[k].bulk_wt.*100.0) * "\n"
        for i=1:nss
            table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[i] * prt(out[k].ph_frac[i].*100.0) * prt(out[k].ph_frac_wt[i].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
            prt(out[k].SS_vec[i].rho) * prt(out[k].SS_vec[i].V) * prt(out[k].SS_vec[i].cp) * prt(out[k].SS_vec[i].alpha) * prt(out[k].SS_vec[i].entropy) * prt(out[k].SS_vec[i].enthalpy) *
            prt(out[k].SS_vec[i].Vp) * prt(out[k].SS_vec[i].Vs) * prt(out[k].SS_vec[i].bulkMod) * prt(out[k].SS_vec[i].shearMod) *
            prt(out[k].SS_vec[i].Comp.*100.0) * prt(out[k].SS_vec[i].Comp_wt.*100.0) * "\n"
        end

        if npp > 0
            for i=1:npp
                pos = i + nss
                table *= "$k" * prt(out[k].X[1]) * prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[pos] * prt(out[k].ph_frac[pos].*100.0) * prt(out[k].ph_frac_wt[pos].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
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
                        refType         :: String;
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
        elseif diagType == "ptx"

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
