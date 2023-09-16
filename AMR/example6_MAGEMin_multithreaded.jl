# This is a MWE that shows how multithreading crashes MAGEMin_C; works fine on 1 thread

using MAGEMin_C
using Base.Threads



"""
    Out_PT, Hash_PT = Calculate_MAGEMin(Pvec::Vector,Tvec::Vector)

Calculates a stable phase assemblage for a given Pressure (`P`) and Temperature (`T`)
"""
function Calculate_MAGEMin(Pvec::Vector,Tvec::Vector)

    # Initialize MAGEMin database    
    db          = "ig"      # database: ig, igneous (Holland et al., 2018); mp, metapelite (White et al 2014b)
    gv, z_b, DB, splx_data      = init_MAGEMin(db);

    test        = 0;
    sys_in      = "mol"     #default is mol, if wt is provided conversion will be done internally (MAGEMin works on mol basis)
    gv          = use_predefined_bulk_rock(gv, test, db);

    # initialize vectore
    Out_PT = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(Pvec))
    Hash_PT = Vector{UInt64}(undef,length(Pvec))

    # main loop
    @threads for i = 1: length(Pvec)
    
        # compute a new point using a ccall
        Out_PT[i] = point_wise_minimization(Pvec[i],Tvec[i], gv, z_b, DB, splx_data, sys_in)   

        if mod(128,i) == 0
            GC.gc()
        end
    end

    finalize_MAGEMin(gv,DB)

    # Compjute has
    for i=1:length(Pvec)
        Hash_PT[i] = hash(sort(Out_PT[i].ph))
    end

    return Out_PT, Hash_PT
end


# Allocate some initial conditions
n = 100;
Pvec = rand(0:50,n)
Tvec = rand(800:10:2000,n)

# call code
@time out_PT, hash_PT = Calculate_MAGEMin(Pvec,Tvec)