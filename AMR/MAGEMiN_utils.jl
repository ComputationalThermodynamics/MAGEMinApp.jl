# Various MAGEMin multithreading options
using Base.Threads: @threads


# ind_map         =nothing
# Out_PT_old      =nothing
# n_phase_PT_old  =nothing

function refine_MAGEMin(data, MAGEMin_data::MAGEMin_Data; ind_map=nothing, Out_PT_old=nothing, n_phase_PT_old=nothing)
    if isnothing(ind_map)
        ind_map = - ones(length(data.xc));
    end

    Out_PT = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.x))

    # Step 1: determine all points that have not been computed yet
    ind_new = findall( ind_map.< 0)
    n_new_points = length(ind_new)
    Out_PT_new   = []
    if n_new_points>0

        # create list of P/T values
        # (NOTE: if we later want to change chemistry as well, we will need to create a chemistry vector)
        Pvec = zeros(Float64,n_new_points)
        Tvec = zeros(Float64,n_new_points)
        for (i, new_ind) = enumerate(ind_new)
            Pvec[i] = data.yc[new_ind]
            Tvec[i] = data.xc[new_ind]
        end

        Out_PT_new  =   multi_point_minimization(Pvec, Tvec, MAGEMin_data, test=0);

    end

    # Step 2: Collect new and old results
    new_point = 0;
    for (i, map) = enumerate(ind_map)
        if map>0
            Out_PT[i] = Out_PT_old[map]
        else
            new_point += 1
            Out_PT[i] = Out_PT_new[new_point]
        end
    end

    Out_PT_new =[]

    # Compute hash for all points
    Hash_PT     = Vector{UInt64}(undef,length(data.x))
    n_phase_PT  = Vector{UInt64}(undef,length(data.x))
    for i=1:length(data.x)
        Hash_PT[i] = hash(sort(Out_PT[i].ph))
        n_phase_PT[i] = length(Out_PT[i].ph)
    end

    return Out_PT, Hash_PT, n_phase_PT
end
