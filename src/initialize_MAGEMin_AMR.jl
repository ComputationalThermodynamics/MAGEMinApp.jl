# coupling T8Code with multithreaded MAGEMin
using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ERROR, SC_LP_PRODUCTION, SC_LP_ESSENTIAL, SC_LP_DEBUG
using Statistics
using StaticArrays
using MAGEMin_C

include("./AMR/AMR_utils.jl")
include("./AMR/MAGEMiN_utils.jl")

function Initialize_AMR()
    # Initialize MPI. This has to happen before we initialize sc or t8code.
    if !MPI.Initialized()
        mpiret  = MPI.Init(threadlevel = MPI.THREAD_FUNNELED, finalize_atexit = true)
        @assert mpiret>=MPI.THREAD_FUNNELED "MPI library with insufficient threading support"
    end

    COMM = MPI.COMM_WORLD

    t8code_package_id = t8_get_package_id()
    if t8code_package_id<0
        # Initialize the sc library, has to happen before we initialize t8code.
        sc_init(COMM, 0, 1, C_NULL, SC_LP_ERROR)
        if T8code.Libt8.p4est_is_initialized() == 0
            T8code.Libt8.p4est_init(C_NULL, SC_LP_ERROR)
        end
        t8_init(SC_LP_ERROR)
    end

    return COMM
end
