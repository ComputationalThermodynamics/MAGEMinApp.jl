# This shows how to set custom coordinates on the coarse mesh

using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ESSENTIAL, SC_LP_DEBUG
using T8code.Libt8: SC_LP_PRODUCTION

using StaticArrays, Statistics


include("./AMR_utils.jl")


# Initialize MPI. This has to happen before we initialize sc or t8code.
if !MPI.Initialized()
    mpiret  = MPI.Init()
    comm    = MPI.COMM_WORLD.val
end

t8code_package_id = t8_get_package_id()
if t8code_package_id<0
    # Initialize the sc library, has to happen before we initialize t8code.
    sc_init(comm, 1, 1, C_NULL, SC_LP_ESSENTIAL)
    
     # Initialize t8code with log level SC_LP_PRODUCTION. See sc.h for more info on the log levels.
    t8_init(SC_LP_PRODUCTION)

    T8code.Libt8.p4est_init(C_NULL, SC_LP_PRODUCTION)
end



# The mesh generation routines have been put in AMR_utile
cmesh_2D = t8_cmesh_quad_2d(comm, (10,20), (30,40))
t8_cmesh_vtk_write_file(cmesh_2D, "cmesh_2D_quad", 1.0)

cmesh_tri_2D = t8_cmesh_triangle_2d(comm)
t8_cmesh_vtk_write_file(cmesh_tri_2D, "cmesh_2D_triangle", 1.0)

