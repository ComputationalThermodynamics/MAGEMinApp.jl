# Shows how to generate julia data structured (e.g. with coordinates of triangles/quads) based on t8code generated meshes

using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ESSENTIAL
using T8code.Libt8: SC_LP_PRODUCTION

using StaticArrays


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
function adapt_callback(forest, forest_from, which_tree, lelement_id,
                                  ts, is_family, num_elements, elements_ptr) :: Cint

  # Our adaptation criterion is given by the vector refine_elements, passed into by the function
  # adapt_forest
  adapt_data_ptr = Ptr{Cint}(t8_forest_get_user_data(forest))

  # You can use assert for assertions that are active in debug mode (when configured with --enable-debug).
  # If the condition is not true, then the code will abort.
  # In this case, we want to make sure that we actually did set a user pointer to forest and thus
  # did not get the NULL pointer from t8_forest_get_user_data.
  @T8_ASSERT(adapt_data_ptr != C_NULL)

  #@show lelement_id, which_tree, num_elements, is_family, ts
  tree_element_offset =   t8_forest_get_tree_element_offset(forest_from, which_tree)
  @show tree_element_offset

  local_element_id = tree_element_offset+lelement_id

  refine_element = unsafe_load(adapt_data_ptr,local_element_id+1)

  # refines if 1, don't do anything if 0, coarsen if -1
  return refine_element
end


# Call the callback 
function adapt_forest(forest, refine_elements)
    num_local_trees = t8_forest_get_num_local_trees(forest)
    
    num_local_elements  = t8_forest_get_local_num_elements(forest)
    
    @show num_local_elements
    refine_elements     = zeros(Cint,num_local_elements)
       
    #refine_elements = Vector{Cint}(undef, num_elements_in_tree)
    refine_elements[20] = 1
   # refine_elements[40] = -1
    
    # Check that forest is a committed, that is valid and usable, forest.
    @T8_ASSERT(t8_forest_is_committed(forest) == 1)

    # Initialize new forest
    forest_adapt_ref = Ref(t8_forest_t())
    t8_forest_init(forest_adapt_ref)
    forest_adapt = forest_adapt_ref[]
    
    # Specify that this forest should result from forest.
    # The last argument is the flag 'no_repartition'.
    t8_forest_set_user_data(forest_adapt, pointer(refine_elements))
    t8_forest_set_adapt(forest_adapt, forest, @t8_adapt_callback(adapt_callback), 0)
    
    t8_forest_set_balance(forest_adapt, C_NULL, 0)  # enforces 2:1 balance
    t8_forest_set_partition(forest_adapt, C_NULL, 0)
    t8_forest_set_ghost(forest_adapt, 1, T8_GHOST_FACES)
    t8_forest_commit(forest_adapt)

    return forest_adapt
  end

#
# ====================

# indicate elements that should be refined:
refine_elements   = zeros(Cint,length(data_quad.tree_id))
refine_elements[40] = 1

forest_quad       = adapt_forest(forest_quad, refine_elements)

refine_elements   = zeros(Cint,length(data_quad_rect.tree_id))
refine_elements[40] = 1
forest_quad_rect = adapt_forest(forest_quad_rect,refine_elements)

refine_elements   = zeros(Cint,length(data_tri.tree_id))
refine_elements[40] = 1
forest_tri      = adapt_forest(forest_tri,refine_elements)

t8_step3_print_forest_information(forest_quad)
t8_step3_print_forest_information(forest_quad_rect)
t8_step3_print_forest_information(forest_tri)

t8_forest_write_vtk(forest_tri, "AMR_ex1_t8_adapt_right_tri")
t8_forest_write_vtk(forest_quad, "AMR_ex1_t8_adapt_right_quad")
t8_forest_write_vtk(forest_quad_rect, "AMR_ex1_t8_adapt_right_quad_rect")



