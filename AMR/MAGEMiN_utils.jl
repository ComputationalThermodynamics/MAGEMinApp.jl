# Various MAGEMin multithreading options
using Base.Threads: @threads
using MAGEMin_C

"""
This holds the MAGEMin databases & requires structs for every thread
"""
struct DataBase_DATA
    db :: String
    gv :: Vector
    z_b :: Vector
    DB  :: Vector
    splx_data :: Vector
end


"""
    Dat = Initialize_MAGEMin(db="ig")

This initialize the MAGEMin databases on every thread. This actually has to be done only once per simulation/database if all is well.
"""
function Initialize_MAGEMin(db="ig")
    gv, z_b, DB, splx_data      = init_MAGEMin(db);

    nt = Threads.nthreads()
    list_gv = Vector{typeof(gv)}(undef, nt)
    list_z_b = Vector{typeof(z_b)}(undef, nt)
    list_DB = Vector{typeof(DB)}(undef, nt)
    list_splx_data = Vector{typeof(splx_data)}(undef, nt)

    for id in 1:nt
        gv, z_b, DB, splx_data = init_MAGEMin(db)
        list_gv[id] = gv
        list_z_b[id] = z_b
        list_DB[id] = DB
        list_splx_data[id] = splx_data
    end

    return DataBase_DATA(db, list_gv, list_z_b, list_DB, list_splx_data)
end


"""
Finalizes MAGEMin and clears variables
"""
function Finalize_MAGEMin(dat::DataBase_DATA)
    for id in 1:Threads.nthreads()
        gv = dat.gv[id]
        DB = dat.DB[id]
        finalize_MAGEMin(gv, DB)

        # These are indeed not freed (same with C-code), which should be added for completion
        # They are rather small structs compared to the others
        z_b = dat.z_b[id]
        splx_data = dat.splx_data[id]

     end
     return nothing
end

"""
    Out_PT = Calculate_MAGEMin(Pvec::Vector, Tvec::Vector, MAGEMin_db::DataBase_DAT; sys_in="mol", test=0)

Calculates a stable phase assemblage for a given Pressure (`P`) and Temperature (`T`)
"""
function Calculate_MAGEMin(Pvec::Vector, Tvec::Vector, MAGEMin_db::DataBase_DATA; sys_in="mol", test=0)

    for i=1:Threads.nthreads()
        MAGEMin_db.gv[i]          = use_predefined_bulk_rock(MAGEMin_db.gv[i], test, MAGEMin_db.db);
    end

    # initialize vectors
    Out_PT = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, length(Pvec))

    # main loop
    @threads :static for i in eachindex(Pvec)
        # Get thread-local buffers. As of Julia v1.9, a dynamic scheduling of
        # the threads is the default setting. To avoid task migration and the
        # resulting concurrency issues, we restrict the loop to static scheduling.
        id = Threads.threadid()
        gv  = MAGEMin_db.gv[id]
        z_b = MAGEMin_db.z_b[id]
        DB = MAGEMin_db.DB[id]
        splx_data = MAGEMin_db.splx_data[id]

        # compute a new point using a ccall
        out = point_wise_minimization(Pvec[i], Tvec[i], gv, z_b, DB, splx_data, sys_in)
        Out_PT[i] = out
    end

    return Out_PT
end