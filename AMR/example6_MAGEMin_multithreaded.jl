# This is a MWE that shows how multithreading crashes MAGEMin_C; works fine on 1 thread

using MAGEMin_C
using Base.Threads: @threads


# Holds the database data
struct DataBase_DATA
    db :: String
    gv :: Vector
    z_b :: Vector
    DB  :: Vector
    splx_data :: Vector
end


"""
    This initialize the MAGEMin databases on every thread. This actually has to be done only once per computation
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
    Out_PT, Hash_PT = Calculate_MAGEMin(Pvec::Vector, Tvec::Vector, MAGEMin_db::DataBase_DAT)

Calculates a stable phase assemblage for a given Pressure (`P`) and Temperature (`T`)
"""
function Calculate_MAGEMin(Pvec::Vector, Tvec::Vector, MAGEMin_db::DataBase_DATA)

    # Initialize MAGEMin database
  #  db          = "ig"      # database: ig, igneous (Holland et al., 2018); mp, metapelite (White et al 2014b)
   # gv, z_b, DB, splx_data      = init_MAGEMin(db);

    test        = 0;
    sys_in      = "mol"     #default is mol, if wt is provided conversion will be done internally (MAGEMin works on mol basis)
    for i=1:Threads.nthreads()
        MAGEMin_db.gv[i]          = use_predefined_bulk_rock(MAGEMin_db.gv[i], test, MAGEMin_db.db);
    end
    
    # initialize vectore
    Out_PT = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, length(Pvec))
    Hash_PT = Vector{UInt64}(undef, length(Pvec))

    #=
    # MAGEMIN uses these variables and overwrites them. Thus, we need one copy
    # for each thread. Since I do not know whether `copy` or `ddepcopy` is
    # implemented correctly for them, I create new variables for each thread.
    nt = Threads.nthreads()
    list_gv = Vector{typeof(gv)}(undef, nt)
    list_z_b = Vector{typeof(z_b)}(undef, nt)
    list_DB = Vector{typeof(DB)}(undef, nt)
    list_splx_data = Vector{typeof(splx_data)}(undef, nt)

    for id in 1:nt
        gv, z_b, DB, splx_data = init_MAGEMin(db)
        gv = use_predefined_bulk_rock(gv, test, db)
        list_gv[id] = gv
        list_z_b[id] = z_b
        list_DB[id] = DB
        list_splx_data[id] = splx_data
    end
    =#

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
        Hash_PT[i] = hash(sort(out.ph))

        # if mod(128,i) == 0
        #     GC.gc()
        # end
    end

    # finalize_MAGEMin(gv, DB)
    # TODO: I would expect that we should also clean up the other variables.
    # However, it looks like MAGEMin uses some global variables quite a lot.
    # In particular, calling the code below segfaults for me with errors
    # like
    # - malloc: double free for ptr
    # - error for object ...: pointer being freed was not allocated
    #=
    for id in 1:nt
         gv = list_gv[id]
         z_b = list_z_b[id]
         DB = list_DB[id]
         splx_data = list_splx_data[id]
         finalize_MAGEMin(gv, DB)
     end
    =#

    return Out_PT, Hash_PT
end


MAGEMin_db = Initialize_MAGEMin("ig");



# Allocate some initial conditions
n = 100
Pvec = rand(0:50, n)
Tvec = rand(800:10:2000, n)

# call code
t = @elapsed out_PT, hash_PT = Calculate_MAGEMin(Pvec, Tvec, MAGEMin_db)
print("Code took $t seconds")


