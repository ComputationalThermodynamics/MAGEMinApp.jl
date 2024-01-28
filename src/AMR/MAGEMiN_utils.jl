###
# MAGEMin_Data(db, list_gv, list_z_b, list_DB, list_splx_data)
#
#
#
###


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
        Out_XY_new  =   multi_point_minimization(Pvec, Tvec, MAGEMin_data, Xvec, B=Bvec, Xoxides=oxi, sys_in="mol");
        
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
