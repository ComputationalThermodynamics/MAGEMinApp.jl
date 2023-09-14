# example of creating uniform grid

using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ESSENTIAL
using T8code.Libt8: SC_LP_PRODUCTION


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

  @show lelement_id, which_tree, num_elements, is_family, ts

  refine_element = unsafe_load(adapt_data_ptr,lelement_id+1)

  # refines if 1, don't do anything if 0, coarsen if -1
  return refine_element
end


# Call the callback 
function adapt_forest(forest)
    num_local_trees = t8_forest_get_num_local_trees(forest)
    
    num_local_elements = t8_forest_get_local_num_elements(forest)
    refine_elements = zeros(Cint,num_local_elements)
       
    #refine_elements = Vector{Cint}(undef, num_elements_in_tree)
    refine_elements[20] = 1
    refine_elements[40] = -1
    
    # Check that forest is a committed, that is valid and usable, forest.
    @T8_ASSERT(t8_forest_is_committed(forest) == 1)

    # Create a new forest that is adapted from \a forest with our adaptation callback.
    # We provide the adapt_data as user data that is stored as the used_data pointer of the
    # new forest (see also t8_forest_set_user_data).
    # The 0, 0 arguments are flags that control
    #   recursive  -    If non-zero adaptation is recursive, thus if an element is adapted the children
    #                   or parents are plugged into the callback again recursively until the forest does not
    #                   change any more. If you use this you should ensure that refinement will stop eventually.
    #                   One way is to check the element's level against a given maximum level.
    #   do_face_ghost - If non-zero additionally a layer of ghost elements is created for the forest.
    #                   We will discuss ghost in latgirt ader steps of the tutorial.
    forest_adapt = t8_forest_new_adapt(forest, @t8_adapt_callback(adapt_callback), 0, 0, pointer(refine_elements))
  

    return forest_adapt
  end

#
# ====================



forest_quad = adapt_forest(forest_quad)
forest_quad_rect = adapt_forest(forest_quad_rect)
forest_tri  = adapt_forest(forest_tri)

t8_step3_print_forest_information(forest_quad)
t8_step3_print_forest_information(forest_quad_rect)
t8_step3_print_forest_information(forest_tri)

t8_forest_write_vtk(forest_tri, "AMR_ex1_t8_adapt_right_tri")
t8_forest_write_vtk(forest_quad, "AMR_ex1_t8_adapt_right_quad")
t8_forest_write_vtk(forest_quad_rect, "AMR_ex1_t8_adapt_right_quad_rect")


