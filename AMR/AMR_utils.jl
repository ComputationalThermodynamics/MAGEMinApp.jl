# this contains utility functions that make life easier when working with AMR, as used in MAGEMin

export find_enclosing_element, get_element_info

using T8code.Libt8: sc_free

mutable struct PointSearch
    point::NTuple{2,Float64}
    element::Int64
    tree::Int64
    unique_element::Int64
end



# Helper function 
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
    data = get_element_info(forest, triangle=Val{false}())

    Returns the local coordinates of the vertices, the element,  the tree of and level of every element
"""
function get_element_info(forest, triangle=Val{false}())

    num_local_elements  =   t8_forest_get_local_num_elements(forest)
    if triangle == Val{true}()
        num_faces       =  3
    else
        num_faces       =  4
    end     

    x                   = zeros(SVector{num_faces,Float64}, num_local_elements)
    y                   = zeros(SVector{num_faces,Float64}, num_local_elements)
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
         
            # Retrieve local coordinates of quad elements (in normalized manner)
            #t8_forest_element_centroid(forest, itree, element,   pointer(element_coords_ll))
            ##t8_forest_element_centroid(forest, itree, element,   pointer(element_coords_lr))
           # t8_forest_element_centroid(forest, itree, element,   pointer(element_coords_ur))
           # t8_forest_element_centroid(forest, itree, element,   pointer(element_coords_ul))
            
            
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


    return (;x, y, element_id, tree_id, unique_element_id, element_level)
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


# Call the callback 
function adapt_forest(forest, refine_elements::Vector{Cint})

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


"""

This indicates which elements need to be refined based on different numbers between neighboring values

Taken from trixi
"""
function refine_phase_boundaries(forest, Phase_ID)
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
                neighbor_leafs = unsafe_wrap(Array, pneighbor_leafs_ref[], num_neighbors)
                neighbor_scheme = pneigh_scheme_ref[]

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