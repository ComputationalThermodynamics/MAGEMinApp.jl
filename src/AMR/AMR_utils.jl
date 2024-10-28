export init_AMR, select_cells_to_split_and_keep, perform_AMR

mutable struct AMR_data
    cells           :: Vector{Vector{Int64}}
    ncells          :: Vector{Vector{Int64}}
    ncells_c        :: Vector{Int64}
    points          :: Vector{Vector{Float64}}
    npoints         :: Vector{Vector{Float64}}
    hash_map        :: Dict{Vector{Float64}, Int}
    bnd_cells       :: Vector{Tuple}
    split_cell_list :: Vector{Int64}
    keep_cell_list  :: Vector{Int64}
    Xrange          :: Vector{Float64}
    Yrange          :: Vector{Float64}
end

function compute_index(value, min_value, delta)
    return Int64(round((value - min_value + delta) / delta))
end

function init_AMR(Xrange,Yrange,igs)

    nc_per_dim      = 2^igs              #number of cells per dimension
    np_per_dim      = nc_per_dim+1       #number of points per dimension

    points          = Vector{Vector{Float64}}(undef, 0)
    cells           = Vector{Vector{Int64}}(undef, 0)
    ncells_c        = Vector{Int64}(undef, 0)
    npoints         = Vector{Vector{Float64}}(undef, 0)
    ncells          = Vector{Vector{Int64}}(undef, 0)
    hash_map        = Dict{Vector{Float64}, Int}()
    bnd_cells       = Vector{Tuple}(undef, 0)
    split_cell_list = Vector{Int64}(undef, 0)
    keep_cell_list  = Vector{Int64}(undef, 0)

    # initialize rectinilinear grid
    for j in 1:np_per_dim
        for i in 1:np_per_dim
            push!(points, [(j-1)*(Xrange[2]-Xrange[1])/(np_per_dim-1) + Xrange[1], (i-1)*(Yrange[2]-Yrange[1])/(np_per_dim-1) + Yrange[1]])
        end
    end
    for j in 1:nc_per_dim
        for i in 1:nc_per_dim
            push!(cells, [i+(j-1)*np_per_dim, i+1+(j-1)*np_per_dim, i+1+j*np_per_dim, i+j*np_per_dim])
        end
    end

    data = AMR_data(    cells,
                        ncells,
                        ncells_c,
                        points,
                        npoints,
                        hash_map,
                        bnd_cells,
                        split_cell_list,
                        keep_cell_list,
                        [Xrange[1],Xrange[2]],[Yrange[1],Yrange[2]])
    return data
end

function all_identical(arr::Vector{UInt64})
    return all(x -> x == arr[1], arr)
end

function select_cells_to_split_and_keep(data)
    data.split_cell_list = []
    data.keep_cell_list  = []

    for i=1:length(data.cells)
        tmp = zeros(UInt64,4)
        for j=1:4
            tmp[j] = Hash_XY[data.cells[i][j]]
        end
        if all_identical(tmp)
            push!(data.keep_cell_list, i)
        else
            push!(data.split_cell_list, i)
        end
    end

    return data
end


function perform_AMR(data)
    npoints         = Vector{Vector{Float64}}(undef, 0)
    ncells          = Vector{Vector{Int64}}(undef, 0)
    ncells_c        = Vector{Int64}(undef, 0)

    tp              = length(data.points)
    ns              = length(data.split_cell_list)
    for i=1:ns

        tmp     = data.points[data.cells[data.split_cell_list[i]][1]]/2.0 + data.points[data.cells[data.split_cell_list[i]][3]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        c       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][1]]/2.0 + data.points[data.cells[data.split_cell_list[i]][2]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        w       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][2]]/2.0 + data.points[data.cells[data.split_cell_list[i]][3]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        n       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][3]]/2.0 + data.points[data.cells[data.split_cell_list[i]][4]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        e       = p;

        tmp = data.points[data.cells[data.split_cell_list[i]][4]]/2.0 + data.points[data.cells[data.split_cell_list[i]][1]]/2.0
        if haskey(data.hash_map, tmp)
            p = data.hash_map[tmp]
        else
            push!(npoints, tmp)
            tp += 1
            data.hash_map[tmp] = tp
            p  = tp
        end
        s       = p;

        push!(ncells, [data.cells[data.split_cell_list[i]][1], w, c, s])
        push!(ncells, [w, data.cells[data.split_cell_list[i]][2], n, c])
        push!(ncells, [c, n, data.cells[data.split_cell_list[i]][3], e])
        push!(ncells, [s, c, e, data.cells[data.split_cell_list[i]][4]])
        push!(ncells_c, c)
    end

    data.points = vcat(data.points, npoints)

    data.bnd_cells  = Vector{Tuple}(undef, 0)
    nk              = length(data.keep_cell_list) 
    ix = [1 2; 2 3; 3 4; 4 1]
    for i=1:nk
        tmp_bnd = (i,)
        for k = 1:4
            tmp = data.points[data.cells[data.keep_cell_list[i]][ix[k,1]]]/2.0 + data.points[data.cells[data.keep_cell_list[i]][ix[k,2]]]/2.0
            if haskey(data.hash_map, tmp)
                p        = data.hash_map[tmp]
                tmp_bnd = (tmp_bnd...,p)
            end
        end

        push!(data.bnd_cells,tmp_bnd)

    end

    data.cells = vcat(data.cells[data.keep_cell_list], ncells)

    data.ncells     = ncells
    data.npoints    = npoints
    data.ncells_c   = ncells_c

    return data
end