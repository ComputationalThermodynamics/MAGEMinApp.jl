# Shows how to generate julia data structured (e.g. with coordinates of triangles/quads) based on t8code generated meshes

using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ESSENTIAL
using T8code.Libt8: SC_LP_PRODUCTION

using StaticArrays, Statistics


include("./AMR_utils.jl")

function t8_step3_print_forest_information(forest)
    # Check that forest is a committed, that is valid and usable, forest.
    @T8_ASSERT(t8_forest_is_committed(forest) == 1)
  
    # Get the local number of elements.
    local_num_elements = t8_forest_get_local_num_elements(forest)
    # Get the global number of elements.
    global_num_elements = t8_forest_get_global_num_elements(forest)
  
    t8_global_productionf(" [step3] Local number of elements:\t\t%i\n", local_num_elements)
    t8_global_productionf(" [step3] Global number of elements:\t%li\n", global_num_elements)
end


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

# Define coarse mesh
cmesh_quad      = t8_cmesh_new_hypercube(T8_ECLASS_QUAD, comm, 0, 0, 0)
cmesh_tri       = t8_cmesh_new_hypercube(T8_ECLASS_TRIANGLE, comm, 0, 0, 0)

# refine a quad with size 2 by 1
connectivity   = T8code.Libt8.p4est_connectivity_new_twotrees(1,0,0)
cmesh_quad_rect = t8_cmesh_new_from_p4est(connectivity, comm, 1) 

# Uniform refinement
level = 4
forest_quad = t8_forest_new_uniform(cmesh_quad, t8_scheme_new_default_cxx(), level, 0, comm)
forest_tri = t8_forest_new_uniform(cmesh_tri, t8_scheme_new_default_cxx(), level, 0, comm)
forest_quad_rect = t8_forest_new_uniform(cmesh_quad_rect, t8_scheme_new_default_cxx(), level, 0, comm)

# Get element info of the current grid
data_quad = get_element_info(forest_quad)
data_tri  = get_element_info(forest_tri, Val{true}())
data_quad_rect  = get_element_info(forest_quad_rect, Val{false}())

# search callback; given a point, tell us in which element it is 
coords_search = (0.8, 0.71)


# Simple UI that returns the tree and the element of the enclosing element 
out_quad    = find_enclosing_element(coords_search, forest_quad)
out_tri     = find_enclosing_element(coords_search, forest_tri)


t8_step3_print_forest_information(forest_quad)
t8_step3_print_forest_information(forest_quad_rect)
t8_step3_print_forest_information(forest_tri)

# Write VTK file
t8_forest_write_vtk(forest_tri, "AMR_ex1_t8_uniform_tri")
t8_forest_write_vtk(forest_quad, "AMR_ex1_t8_uniform_quad")
t8_forest_write_vtk(forest_quad_rect, "AMR_ex1_t8_uniform_quad_rect")



# ====================
# Refine the mesh
# Callback function

for irefine = 1:4
    local data_quad
    global forest_quad
    data_quad   = get_element_info(forest_quad)
    x_c, y_c    = mean.(data_quad.x), mean.(data_quad.y)
    Phase_ID    = Cint.(((x_c .- 0.5).^2 .+ (y_c .- 0.5).^2 ) .< 0.2^2)
    refine_elements = refine_phase_boundaries(forest_quad, Phase_ID);

    forest_quad         = adapt_forest(forest_quad, refine_elements)
end


for irefine = 1:4
    local data_tri
    global forest_tri
    data_tri   = get_element_info(forest_tri)
    x_c, y_c   = mean.(data_tri.x), mean.(data_tri.y)
    Phase_ID   = Cint.(((x_c .- 0.5).^2 .+ (y_c .- 0.5).^2 ) .< 0.2^2)
    refine_elements = refine_phase_boundaries(forest_tri, Phase_ID);
    forest_tri  = adapt_forest(forest_tri, refine_elements)
end
t8_forest_write_vtk(forest_tri, "AMR_ex1_t8_adapt_right_tri")


#
# ====================



# indicate elements that should be refined:
#refine_elements     = zeros(Cint,length(data_quad.tree_id))
#x_c, y_c            = mean.(data_quad.x), mean.(data_quad.y)
#refine_elements     = Cint.(((x_c .- 0.5).^2 .+ (y_c .- 0.5).^2 ) .< 0.2^2)


#refine_elements   = zeros(Cint,length(data_quad_rect.tree_id))
#refine_elements[40] = 1
#forest_quad_rect = adapt_forest(forest_quad_rect,refine_elements)

#refine_elements   = zeros(Cint,length(data_tri.tree_id))
#data_tri   = get_element_info(forest_tri, Val{true}())
#x_c, y_c   = mean.(data_tri.x), mean.(data_tri.y)
#refine_elements   = Cint.( x_c .> 0.5)
#refine_elements[290] = 1

#forest_tri      = adapt_forest(forest_tri,refine_elements)

t8_step3_print_forest_information(forest_quad)
t8_step3_print_forest_information(forest_quad_rect)
t8_step3_print_forest_information(forest_tri)

t8_forest_write_vtk(forest_tri, "AMR_ex1_t8_adapt_right_tri")
t8_forest_write_vtk(forest_quad, "AMR_ex1_t8_adapt_right_quad")
t8_forest_write_vtk(forest_quad_rect, "AMR_ex1_t8_adapt_right_quad_rect")


