# this contains utility functions that make life easier when working with AMR, as used in MAGEMin

export find_enclosing_element, get_element_data, refine_phase_boundaries, adapt_forest, t8_print_forest_information
export t8_cmesh_triangle_2d, t8_cmesh_quad_2d
using T8code.Libt8: sc_free

mutable struct PointSearch
    point::NTuple{2,Float64}
    element::Int64
    tree::Int64
    unique_element::Int64
end

"""
    cmesh = t8_cmesh_quad_2d(comm, x= (0,10), y = (0,10))

Creates a 2D quadrilateral coarse mesh with coordinates given by `x`,`y`
"""
function t8_cmesh_quad_2d(comm, x=(0.0,10.0), y = (0.0,10.0))

    # Define a quad using the 4 vertices; note that quads are given in z-order
    x = Float64.(x)
    y = Float64.(y)
    
    vertices = [ 
    x[1], y[1], 0,                 
    x[2], y[1], 0,
    x[1], y[2], 0,
    x[2], y[2], 0,
    ]

    # 2. Initialization of the mesh.
    cmesh_ref = Ref(t8_cmesh_t())
    t8_cmesh_init(cmesh_ref)
    cmesh = cmesh_ref[]

    # 3. Definition of the geometry.
    linear_geom = t8_geometry_linear_new(2)
    t8_cmesh_register_geometry(cmesh, linear_geom)      # Use linear geometry.

    # 4. Definition of the classes of the different trees.
    t8_cmesh_set_tree_class(cmesh, 0, T8_ECLASS_QUAD)
    
    # 5. Classification of the vertices for each tree.
    t8_cmesh_set_tree_vertices(cmesh, 0, pointer(vertices), 4)
    
    # 7. Commit the mesh.
    t8_cmesh_commit(cmesh, comm)

    return cmesh
end


"""
    cmesh = t8_cmesh_triangle_2d(comm, x= (0,10), y = (0,10))

Creates a 2D triangular coarse mesh with coordinates given by `x`,`y`.
Triangular meshes have 2 trees
"""
function t8_cmesh_triangle_2d(comm, x=(0.0,10.0),  y = (0.0,10.0))

    x = Float64.(x)
    y = Float64.(y)
    
    # 1. Defining an array with all vertices.of the triangles
    vertices = [ 
        x[1], y[1], 0,                    # tree 0, triangle
        x[2], y[1], 0,
        x[2], y[2], 0,
        x[1], y[1], 0,                    # tree 1, triangle
        x[2], y[2], 0,
        x[1], y[2], 0,
        ]
  
    # 2. Initialization of the mesh.
    cmesh_ref = Ref(t8_cmesh_t())
    t8_cmesh_init(cmesh_ref)
    cmesh = cmesh_ref[]
  
    # 3. Definition of the geometry.
    linear_geom = t8_geometry_linear_new(2)
    t8_cmesh_register_geometry(cmesh, linear_geom)      # Use linear geometry.
  
    # 4. Definition of the classes of the different trees.
    t8_cmesh_set_tree_class(cmesh, 0, T8_ECLASS_TRIANGLE)
    t8_cmesh_set_tree_class(cmesh, 1, T8_ECLASS_TRIANGLE)
  
    # 5. Classification of the vertices for each tree.
    t8_cmesh_set_tree_vertices(cmesh, 0, pointer(vertices, 0), 3)
    t8_cmesh_set_tree_vertices(cmesh, 1, pointer(vertices, 9), 3)
  
    # 6. Definition of the face neighbors between the different trees.
    t8_cmesh_set_join(cmesh, 0, 1, 1, 2, 0)
  
    # 7. Commit the mesh.
    t8_cmesh_commit(cmesh, comm)
  
    return cmesh
end

# Helper function to find the enclosing element
function find_element(forest, ltreeid, element, is_leaf, leaf_elements, tree_leaf_index, query, query_index)
    @T8_ASSERT(query == C_NULL)
    user_data_ptr = Ptr{PointSearch}(t8_forest_get_user_data(forest))
    @T8_ASSERT(user_data_ptr != C_NULL)
    user_data = unsafe_load(user_data_ptr)

    # Get a pointer to our user data and increase the counter of searched elements.
    point       =   [user_data.point...]
    tolerance   =   1e-8
    isinside    =   t8_forest_element_point_inside(forest, ltreeid, element, point, tolerance)
    
    if (isinside != 0) && (is_leaf != 0)
        # we found the enclosing element
        tree_class      = t8_forest_get_tree_class(forest, ltreeid)
        eclass_scheme   = t8_forest_get_eclass_scheme(forest, tree_class)
        element_level   = t8_element_level(eclass_scheme, element)
        num_faces       = t8_element_num_faces(eclass_scheme, element)

        element_coords = Array{Float64}(undef, 2)
        t8_element_vertex_reference_coords(eclass_scheme, element, 0, pointer(element_coords))
        
        tree_element_offset =   t8_forest_get_tree_element_offset(forest, ltreeid)
        local_element_id    =   tree_element_offset + tree_leaf_index


        user_data.element = tree_leaf_index
        user_data.tree = ltreeid
        user_data.unique_element = local_element_id
        unsafe_store!(user_data_ptr, user_data)
    end
    return isinside
end


"""
    user_element = find_enclosing_element(point::NTuple, forest)

Given a tuple with 2D point coordinates, it returns the element and tree of the enclosing element
"""
function find_enclosing_element(point::NTuple, forest)

    # Initialize struct that holds the tree and element @ the end
    user_data = PointSearch(point,-1,-1,-1)
    
    t8_forest_set_user_data(forest, Ref(user_data))
    t8_forest_search(forest, 
                        @cfunction(find_element, Cint, (t8_forest_t, t8_locidx_t, Ptr{t8_element_t}, Cint, Ptr{t8_element_array_t}, t8_locidx_t, Ptr{Cvoid}, Cint )),  
                        C_NULL, C_NULL);

    return user_data         
end

"""
    data = get_element_data(forest, triangle=Val{false}())

    Returns the local coordinates of the vertices, the element,  the tree of and level of every element
"""
function get_element_data(forest, triangle=Val{false}())

    num_local_elements  =   t8_forest_get_local_num_elements(forest)
    if triangle == Val{true}()
        num_faces       =  3
    else
        num_faces       =  4
    end     

    x                   = zeros(SVector{num_faces,Float64}, num_local_elements)
    y                   = zeros(SVector{num_faces,Float64}, num_local_elements)
    xc                  = zeros(Float64,num_local_elements)
    yc                  = zeros(Float64,num_local_elements)
    element_id          = zeros(Cint,num_local_elements)
    tree_id             = zeros(Cint,num_local_elements)
    unique_element_id   = zeros(Cint,num_local_elements)
    element_level       = zeros(Cint,num_local_elements)

    current_index       = 1
    num_local_trees     = t8_forest_get_num_local_trees(forest)

    # Allocate local coords
    element_coords_ll = Array{Float64}(undef, 2)
    element_coords_lr = Array{Float64}(undef, 2)
    element_coords_ur = Array{Float64}(undef, 2)
    element_coords_ul = Array{Float64}(undef, 2)
    
    for itree = 0:num_local_trees-1
        tree_class = t8_forest_get_tree_class(forest, itree)
        eclass_scheme = t8_forest_get_eclass_scheme(forest, tree_class)
        num_elements_in_tree = t8_forest_get_tree_num_elements(forest, itree)
        tree_element_offset =   t8_forest_get_tree_element_offset(forest, itree)
        
        for ielement in 0:(num_elements_in_tree-1)
            element = t8_forest_get_element_in_tree(forest, itree, ielement)
            element_level_local = t8_element_level(eclass_scheme, element)
         
            # Retrieve centroid coordinates of elements (in normalized manner)
            t8_forest_element_centroid(forest, itree, element,   pointer(element_coords_ll))
            xc[current_index]= element_coords_ll[1]
            yc[current_index]= element_coords_ll[2]
            
            # retrieve coordinates of vertices
            t8_forest_element_coordinate(forest, itree, element,   0, pointer(element_coords_ll))
            t8_forest_element_coordinate(forest, itree, element,   1, pointer(element_coords_lr))
            if triangle == Val{true}()
                t8_forest_element_coordinate(forest, itree, element,   2, pointer(element_coords_ul))
                x[current_index]= SVector(element_coords_ll[1],element_coords_lr[1], element_coords_ul[1])
                y[current_index]= SVector(element_coords_ll[2],element_coords_lr[2], element_coords_ul[2])

            else
                t8_forest_element_coordinate(forest, itree, element,   3, pointer(element_coords_ur))
                t8_forest_element_coordinate(forest, itree, element,   2, pointer(element_coords_ul))
                x[current_index]= SVector(element_coords_ll[1],element_coords_lr[1], element_coords_ur[1], element_coords_ul[1])
                y[current_index]= SVector(element_coords_ll[2],element_coords_lr[2], element_coords_ur[2], element_coords_ul[2])
            end

            element_id[current_index] = ielement
            element_level[current_index] = element_level_local
            unique_element_id[current_index] = ielement+tree_element_offset
            tree_id[current_index]    = itree
            current_index += 1

        end
    end


    return (;x, y, xc, yc, element_id, tree_id, unique_element_id, element_level)
end



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

  tree_element_offset =   t8_forest_get_tree_element_offset(forest_from, which_tree)

  local_element_id = tree_element_offset+lelement_id

  refine_element = unsafe_load(adapt_data_ptr,local_element_id+1)

  # refines if 1, don't do anything if 0, coarsen if -1
  return refine_element
end

"""

    forest_new, data_new, ind_map  = adapt_forest(forest, refine_elements::Vector{Cint}, data_old::NamedTuple)

This refines elements in `forest` according to the value indicated in `refine_elements`. If 1 the element is refined; if 0 left untouched (-1 = coarsened, but that is probably not used much here).
`ind_map` returns a mapping from the old to the new mesh, which can be used to determine which cells need to be recomputed (with values<0), and
which cells can be transferred from the old mesh
"""
function adapt_forest(forest, refine_elements::Vector{Cint}, data_old::NamedTuple)

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

    # Get retrieve the new data for each of the elements  
    data_adapt  = get_element_data(forest_tri_new);

    # mapping from old->new elements; the elements that are not refined 
    # will get a new number in the new mesh; the mapping will show how.
    ind_map     = indices_map(data_adapt, data_old, refine_elements)

    return forest_adapt, data_adapt, ind_map
end


"""
    refine_elements = refine_phase_boundaries(forest, Phase_ID::Vector)

This indicates which elements need to be refined based on different numbers between neighboring values

Taken from trixi
"""
function refine_phase_boundaries(forest, Phase_ID::Vector)
    # Check that forest is a committed, that is valid and usable, forest.
    @assert t8_forest_is_committed(forest) != 0

    # Get the number of local elements of forest.
    num_local_elements = t8_forest_get_local_num_elements(forest)
    @assert num_local_elements == length(Phase_ID)

    refine_elements     =   zeros(Cint, num_local_elements)

    # Get the number of ghost elements of forest.
    num_ghost_elements = t8_forest_get_num_ghosts(forest)
    
    # Get the number of trees that have elements of this process.
    num_local_trees = t8_forest_get_num_local_trees(forest)

    current_index = t8_locidx_t(0)

    for itree in 0:(num_local_trees - 1)
        tree_class = t8_forest_get_tree_class(forest, itree)
        eclass_scheme = t8_forest_get_eclass_scheme(forest, tree_class)
        tree_element_offset =   t8_forest_get_tree_element_offset(forest, itree)

        # Get the number of elements of this tree.
        num_elements_in_tree = t8_forest_get_tree_num_elements(forest, itree)

        for ielement in 0:(num_elements_in_tree - 1)
            element = t8_forest_get_element_in_tree(forest, itree, ielement)

            level = t8_element_level(eclass_scheme, element)

            num_faces = t8_element_num_faces(eclass_scheme, element)

            refine = false
            local_phaseID = Phase_ID[ielement+tree_element_offset+1]

            for iface in 0:(num_faces - 1)
                pelement_indices_ref = Ref{Ptr{t8_locidx_t}}()
                pneighbor_leafs_ref = Ref{Ptr{Ptr{t8_element}}}()
                pneigh_scheme_ref = Ref{Ptr{t8_eclass_scheme}}()

                dual_faces_ref = Ref{Ptr{Cint}}()
                num_neighbors_ref = Ref{Cint}()

                forest_is_balanced = Cint(1)

                t8_forest_leaf_face_neighbors(forest, itree, element,
                                              pneighbor_leafs_ref, iface, dual_faces_ref,
                                              num_neighbors_ref,
                                              pelement_indices_ref, pneigh_scheme_ref,
                                              forest_is_balanced)

                num_neighbors = num_neighbors_ref[]
                neighbor_ielements = unsafe_wrap(Array, pelement_indices_ref[],
                                                 num_neighbors)
                #neighbor_leafs = unsafe_wrap(Array, pneighbor_leafs_ref[], num_neighbors)
                #neighbor_scheme = pneigh_scheme_ref[]

                for i_neigh in 1:num_neighbors
                    element_neighbor = neighbor_ielements[i_neigh]
                    neighbor_phaseID = Phase_ID[element_neighbor+1]
                    
                    if neighbor_phaseID != local_phaseID
                        refine = true
                        break
                    end
                end

                refine && break

           #     t8_free(dual_faces_ref[])
           #     t8_free(pneighbor_leafs_ref[])
           #     t8_free(pelement_indices_ref[])
            end # for

            refine_elements[ielement+tree_element_offset+1] = Cint(refine)

            current_index += 1
        end # for
    end # for

    return refine_elements
end



"""
this adds userdata to the VTK file - BROKEN!
"""
function t8_output_data_to_vtu(forest, element_data, prefix)
    num_elements = t8_forest_get_local_num_elements(forest)
    # We need to allocate a new array to store the volumes on their own.
    # This array has one entry per local element. */
    element_volumes = Vector{Cdouble}(undef, num_elements)
    @assert num_elements == length(element_data)

    # Copy the elment's volumes from our data array to the output array.
    for ielem = 1:num_elements
      element_volumes[ielem] = element_data[ielem]
    end
  
    # The number of user defined data fields to write.
    num_data = 1
  
    # WARNING: This code hangs for Julia v1.8.* or older. Use at least Julia v1.9.
    # For each user defined data field we need one t8_vtk_data_field_t variable.
    vtk_data = t8_vtk_data_field_t(
      T8_VTK_SCALAR, # Set the type of this variable. Since we have one value per element, we pick T8_VTK_SCALAR.
      NTuple{8192, Cchar}(rpad("Element volume\0", 8192, ' ')), # The name of the field as should be written to the file.
      pointer(element_volumes), # Pointer to the data.
    )
  
    # To write user defined data, we need to extended output function
    # t8_forest_vtk_write_file from t8_forest_vtk.h. Despite writin user data,
    # it also offers more control over which properties of the forest to write.
    write_treeid = 1
    write_mpirank = 1
    write_level = 1
    write_element_id = 1
    write_ghosts = 0
    t8_forest_write_vtk_ext(forest, prefix, write_treeid, write_mpirank,
                             write_level, write_element_id, write_ghosts,
                             0, 0, num_data, Ref(vtk_data))
  end


"""
  ind_map = indices_map(data_new::NamedTuple, data_old::NamedTuple, refine_elements::Vector)

In a refined grid, the numbering of cells is different. 
This routine returns a mapping, `ind_map` of how to go from the original to the new forest.
Negative values within this mapping are cells that need to be recomputed.

`data_new` and `data_old` are computed with `get_element_data`.
"""
function indices_map(data_new::NamedTuple, data_old::NamedTuple, refine_elements::Vector)

    @assert length(refine_elements) == length(data_old.x)

    ind_map = zeros(Int64,length(data_new.xc))
    num_vertices = length(data_old.x[1])

    current_index = 1;
    for (old_index, refine) in enumerate(refine_elements)
        if refine==0
            ind_map[current_index] = old_index
            current_index += 1;
        elseif refine==1
            for j=1:num_vertices
                ind_map[current_index] = -old_index
                current_index += 1;
            end
        end
    end

    if 1==0
        # checking (center coords of unrefined elements should agree)
        xc_new = data_new.xc[ind_map.>0]
        xc     = data_old.xc[ind_map[ind_map.>0]]
        yc_new = data_new.yc[ind_map.>0]
        yc     = data_old.yc[ind_map[ind_map.>0]]
        @assert sum((xc_new .- xc) + (yc_new .- yc)) == 0
    end

    return ind_map
end


"""
Prints info about the current forest
"""
function t8_print_forest_information(forest)
    # Check that forest is a committed, that is valid and usable, forest.
    @T8_ASSERT(t8_forest_is_committed(forest) == 1)
  
    # Get the local number of elements.
    local_num_elements = t8_forest_get_local_num_elements(forest)
    # Get the global number of elements.
    global_num_elements = t8_forest_get_global_num_elements(forest)
  
    println(" Local number of elements: $local_num_elements")
    println(" Global number of elements: $global_num_elements")

    return nothing
end