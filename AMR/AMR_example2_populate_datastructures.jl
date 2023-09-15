# Shows how to generate julia data structured (e.g. with coordinates of triangles/quads) based on t8code generated meshes

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
    #sc_init(comm, 1, 1, C_NULL, SC_LP_DEBUG)
    
    
     # Initialize t8code with log level SC_LP_PRODUCTION. See sc.h for more info on the log levels.
    t8_init(SC_LP_PRODUCTION)
#    t8_init(SC_LP_DEBUG)

    T8code.Libt8.p4est_init(C_NULL, SC_LP_PRODUCTION)
    #T8code.Libt8.p4est_init(C_NULL, SC_LP_DEBUG)
end

# Define coarse mesh
cmesh_quad      = t8_cmesh_new_hypercube(T8_ECLASS_QUAD, comm, 0, 0, 0)
cmesh_tri       = t8_cmesh_new_hypercube(T8_ECLASS_TRIANGLE, comm, 0, 0, 0)

# refine a quad with size 2 by 1
connectivity   = T8code.Libt8.p4est_connectivity_new_twotrees(1,0,0)
cmesh_quad_rect = t8_cmesh_new_from_p4est(connectivity, comm, 1) 

# Uniform refinement
level               = 4
forest_quad         = t8_forest_new_uniform(cmesh_quad, t8_scheme_new_default_cxx(), level, 0, comm)
forest_tri          = t8_forest_new_uniform(cmesh_tri, t8_scheme_new_default_cxx(), level, 0, comm)
forest_quad_rect    = t8_forest_new_uniform(cmesh_quad_rect, t8_scheme_new_default_cxx(), level, 0, comm)

# Get element info of the current grid
data_quad           = get_element_data(forest_quad)
data_tri            = get_element_data(forest_tri, Val{true}())
data_quad_rect      = get_element_data(forest_quad_rect, Val{false}())

# Search: Simple UI that returns the tree and the element of the enclosing element 
coords_search = (0.8, 0.71)
out_quad    = find_enclosing_element(coords_search, forest_quad)
out_tri     = find_enclosing_element(coords_search, forest_tri)


t8_step3_print_forest_information(forest_quad)
t8_step3_print_forest_information(forest_quad_rect)
t8_step3_print_forest_information(forest_tri)

# Write VTK file
t8_forest_write_vtk(forest_tri,         "AMR_ex1_t8_uniform_tri")
t8_forest_write_vtk(forest_quad,        "AMR_ex1_t8_uniform_quad")
t8_forest_write_vtk(forest_quad_rect,   "AMR_ex1_t8_uniform_quad_rect")



# ====================
# Refine the mesh
data_quad   = get_element_data(forest_quad)
for irefine = 1:5
    global forest_quad, data_quad

    # Define some criteria (should be integere)
    x_c, y_c    = mean.(data_quad.x), mean.(data_quad.y)
    Phase_ID    = Cint.(((x_c .- 0.5).^2 .+ (y_c .- 0.5).^2 ) .< 0.2^2)

    # refine elements where the integer array changes
    refine_elements     = refine_phase_boundaries(forest_quad, Phase_ID);

    # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    forest_quad, data_quad, ind_map  = adapt_forest(forest_quad, refine_elements, data_quad)
end    

# do the same for triangles
data_tri   = get_element_data(forest_tri)
for irefine = 1:5
    global forest_tri, data_tri
    x_c, y_c   = mean.(data_tri.x), mean.(data_tri.y)
    Phase_ID   = Cint.(((x_c .- 0.5).^2 .+ (y_c .- 0.5).^2 ) .< 0.2^2)

    refine_elements = refine_phase_boundaries(forest_tri, Phase_ID);
    forest_tri, data_tri, ind_map  = adapt_forest(forest_tri, refine_elements, data_tri)
end

# print info about meshes: 
println("forest_tri:")
t8_print_forest_information(forest_quad)
println("forest_quad:")
t8_print_forest_information(forest_quad_rect)
println("forest_quad_rect:")
t8_print_forest_information(forest_tri)

# write grids to disk
t8_forest_write_vtk(forest_tri, "AMR_ex1_t8_adapt_right_tri")
t8_forest_write_vtk(forest_quad, "AMR_ex1_t8_adapt_right_quad")
t8_forest_write_vtk(forest_quad_rect, "AMR_ex1_t8_adapt_right_quad_rect")