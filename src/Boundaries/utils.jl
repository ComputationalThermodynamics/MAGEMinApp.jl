#=@ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 **
 **   Project      : MAGEMinApp
 **   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
 **   Developers   : Nicolas Riel, Boris Kaus, Anton Popov, Hendrik Ranocha
 **   Contributors : Dominguez, H., Assunção J., Green E., Berlie N., and Rummel L.
 **   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
 **   Contact      : nriel[at]uni-mainz.de
 ** ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ @*/
=#


function reduce_matrix(matrix)
    rows, cols = size(matrix)
    
    # Find the indices of non-zero values
    non_zero_indices = findall(x -> x != 0, matrix)
    
    # If there are no non-zero values, return an empty matrix
    if isempty(non_zero_indices)
        return []
    end
    
    # Determine the bounding box
    min_row = minimum(i[1] for i in non_zero_indices)
    max_row = maximum(i[1] for i in non_zero_indices)
    min_col = minimum(i[2] for i in non_zero_indices)
    max_col = maximum(i[2] for i in non_zero_indices)
    
    # Extract the submatrix
    submatrix = matrix[min_row:max_row, min_col:max_col]
    
    return submatrix, (min_row, max_row, min_col, max_col)
end


function expand_with_zeros(matrix; bands=2)
    rows, cols = size(matrix)
    
    # Create a new matrix with extra rows and columns filled with zeros
    expanded_matrix = zeros(Int, rows + 2 * bands, cols + 2 * bands)
    
    # Copy the original matrix into the center of the new matrix
    expanded_matrix[bands+1:end-bands, bands+1:end-bands] .= matrix
    
    return expanded_matrix
end


function get_chessboard_distance(mask)

    nr, nc = size(mask)
    ind    = feature_transform(mask)
    dist   = zeros(Int, size(mask))

    for i in 1:nr
        for j in 1:nc
            ii         = ind[i, j][1]
            jj         = ind[i, j][2]
            dist[i, j] = max(abs(ii-i), abs(jj-j))
        end
    end

    return dist
end

#------------------------------------------------------------------------------

# get continuous node numbering in the edges

function renum_edges(edges)

    # get nodes to keep
    N = unique(edges[:])
  
    # get new node numbering
    renum    = zeros(Int, maximum(N))
    nnode    = size(N, 1)
    renum[N] = 1:nnode
    
    # renumber nodes in edges
    redges = renum[edges]

    return redges, N

end

#------------------------------------------------------------------------------

# prepare edge coordinates for plotting with GLMakie.linesegments!

function get_edge_coord_plot(nodes, edges)

    # get start & end coordinates of the edges
    xs = nodes[edges[:, 1], 1]
    ys = nodes[edges[:, 1], 2]
    xe = nodes[edges[:, 2], 1]
    ye = nodes[edges[:, 2], 2]

    # get edge coordinates
    x = [xs'; xe'][:]
    y = [ys'; ye'][:]

    return x, y

end

#------------------------------------------------------------------------------

# get polygon nodes odered in a cycle

function get_node_cycle(nodes, edges)

    G = SimpleGraph(size(nodes, 1))

    for edge in eachrow(edges)

        add_edge!(G, edge[1], edge[2])
    
    end

    cycle = cycle_basis(G)
    
    if length(cycle) > 1
        throw("More than one cycle detected for a polygon")
    end

    cnodes = nodes[cycle[1], : ]

    return cnodes

end

#------------------------------------------------------------------------------