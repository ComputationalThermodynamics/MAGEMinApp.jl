import MAGEMin_C: multi_point_minimization
using MAGEMin_C.Threads, ProgressMeter


mutable struct ComputationalProgress{_T,_I}
    title::String
    stage::String
    total_points::_I
    current_point::_I
    refinement_level::_I
    total_levels::_I
    tinit::_T
    tlast::_T
end

ComputationalProgress() = ComputationalProgress("","",0,0,0,0,time(),time())


function update_progress(pt, n_pts, tlast) 
    global CompProgress
    CompProgress.current_point = pt; 
    CompProgress.total_points = n_pts; 
    CompProgress.tlast = tlast; 
    return nothing
end

# to be added to MAGEMin_C
function multi_point_minimization(P           ::  T2,
                                  T           ::  T2,
                                  MAGEMin_db  ::  MAGEMin_Data;
                                  light       ::  Bool                            = false,
                                  name_solvus ::  Bool                            = false,
                                  test        ::  Int64                           = 0, # if using a build-in test case,
                                  X           ::  VecOrMat                        = nothing,
                                  B           ::  Union{Nothing, T1, Vector{T1}}  = nothing,
                                  scp         ::  Int64                           = 0,     
                                  rm_list     ::  Union{Nothing, Vector{Int64}}   = nothing,
                                  data_in     ::  Union{Nothing, Vector{MAGEMin_C.gmin_struct{Float64, Int64}}} = nothing,
                                  W           ::  Union{Nothing, W_Data}          = nothing,
                                  Xoxides     = Vector{String},
                                  sys_in      = "mol",
                                  rg          = "tc",
                                  progressbar = true,        # show a progress bar or not?
                                  callback_fn ::  Union{Nothing, Function}= nothing, 
                                  callback_int::  Int64 = 1
                                  ) where {T1 <: Float64, T2 <: AbstractVector{Float64}}

    # Set the compositional info
    CompositionType::Int64 = 0;

    if isnothing(X)
        # Use one of the build-in tests
        # Create thread-local data
        for i in 1:Threads.nthreads()
            MAGEMin_db.gv[i] = use_predefined_bulk_rock(MAGEMin_db.gv[i], test, MAGEMin_db.db);
        end
        CompositionType = 0;    # build-in tests
    else
        if isa(X,Vector{Float64})
        # same bulk rock composition for the full diagram
        @assert length(X) == length(Xoxides)

            # Set the bulk rock composition for all points
            for i in 1:Threads.nthreads()
                MAGEMin_db.gv[i] = define_bulk_rock(MAGEMin_db.gv[i], X, Xoxides, sys_in, MAGEMin_db.db);
            end
            CompositionType = 1;    # specified bulk composition for all points
        else
            @assert length(X) == length(P)
            CompositionType = 2;    # different bulk rock composition for every point
        end
    end

    # initialize vectors
    if light == true
        Out_PT = Vector{MAGEMin_C.light_gmin_struct{Float32, Int8}}(undef, length(P))
    else
        Out_PT = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, length(P))
    end
    # main loop
    if progressbar
        progr = Progress(length(P), desc="Computing $(length(P)) points...") # progress meter
    end
    count  = 0;
    @threads :static for i in eachindex(P)

        # Get thread-local buffers. As of Julia v1.9, a dynamic scheduling of
        # the threads is the default setting. To avoid task migration and the
        # resulting concurrency issues, we restrict the loop to static scheduling.
        id          = Threads.threadid()
        gv          = MAGEMin_db.gv[id]
        z_b         = MAGEMin_db.z_b[id]
        DB          = MAGEMin_db.DB[id]
        splx_data   = MAGEMin_db.splx_data[id]

        if CompositionType==2
            # different bulk-rock composition for every point - specify it here
            gv = MAGEMin_C.define_bulk_rock(gv, X[i], Xoxides, sys_in, MAGEMin_db.db);
        end

        if light == false
            if ~isnothing(data_in)
                if isnothing(B)
                    out     = MAGEMin_C.point_wise_minimization_iguess(P[i], T[i], gv, z_b, DB, splx_data; scp, rm_list, data_in = data_in[i])
                else
                    out     = MAGEMin_C.point_wise_minimization_iguess(P[i], T[i], gv, z_b, DB, splx_data; buffer_n = B[i], W = W, scp, rm_list, data_in = data_in[i])
                end  
            else
                if isnothing(B)
                    out     = MAGEMin_C.point_wise_minimization(P[i], T[i], gv, z_b, DB, splx_data; scp, rm_list, name_solvus=name_solvus)
                else
                    out     = MAGEMin_C.point_wise_minimization(P[i], T[i], gv, z_b, DB, splx_data; buffer_n = B[i], W = W, scp, rm_list, name_solvus=name_solvus)
                end
            end
        elseif light == true
            if isnothing(B)
                out     = MAGEMin_C.point_wise_minimization(P[i], T[i], gv, z_b, DB, splx_data; light=light, scp, rm_list)
            else
                out     = MAGEMin_C.point_wise_minimization(P[i], T[i], gv, z_b, DB, splx_data; light=light, buffer_n = B[i], W = W, scp, rm_list)
            end
        end


        Out_PT[i]   = deepcopy(out)

        if progressbar
            next!(progr)
        end
        if mod(i,callback_int)==0 && !isnothing(callback_fn)
            count   += 1
            callback_fn(count, length(P), time())
        end
    end
    if progressbar
        finish!(progr)
    end

    return Out_PT

end
