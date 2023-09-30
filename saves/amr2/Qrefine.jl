function QrefineR(coordinates, elements, irregular, varargin...)
    coordinates_initial = copy(coordinates)
    nE = size(elements, 1)
    markedElements = varargin[end]

    edge2nodes, irregular2edges, element2edges, boundary2edges = provideGeometricData(irregular, elements, varargin[1:end-1])

    edge2newNode = zeros(Int, size(edge2nodes, 1))

    edge2newNode[element2edges[markedElements, :]] .= 1
    edge2newNode[irregular2edges[:, 1]] .= 1
    kdx = 1
    swap = []
    
    while !isempty(kdx) || !isempty(swap)
        markedEdge = edge2newNode[element2edges, :]
        kdx = find(sum(abs.(markedEdge), dims=2) .< 4 .& ((sum(abs.(markedEdge), dims=2) .> 2) .| (minimum(markedEdge, dims=2) .< 0)))
        idx, jdx = findall(!markedEdge[kdx, :])
        edge2newNode[element2edges[kdx[idx] .+ (jdx .- 1) .* nE]] .= 1
        
        markedEdge = edge2newNode[irregular2edges, :]
        flag = irregular2edges[any(markedEdge[:, 2:end], dims=2), 1]
        swap = find(edge2newNode[flag] .!= -1)
        edge2newNode[flag[swap]] .= -1
    end

    edge2newNode[irregular2edges[:, 1]] .= -1
    idx = edge2newNode .> 0
    edge2newNode[idx] .= size(coordinates, 1) .+ (1:nnz(idx))

    for i in findall(idx)
        coordinates[edge2newNode[i], :] .= (coordinates[edge2nodes[i, 1], :] .+ coordinates[edge2nodes[i, 2], :]) ./ 2
    end

    prPts = [edge2nodes[idx, 1] edge2nodes[idx, 2] zeros(Int, nnz(idx)) zeros(Int, nnz(idx))]

    varargout = Vector{Any}(undef, nargout - 4)

    for j = 1:nargout - 4
        boundary = varargin[j]
        if !isempty(boundary)
            newNodes = edge2newNode[boundary2edges[j]]
            markedEdges = findall(newNodes .> 0)
            if !isempty(markedEdges)
                boundary = vcat(boundary[.!newNodes, :], [boundary[markedEdges, 1] newNodes[markedEdges]]', [newNodes[markedEdges] boundary[markedEdges, 2]]')
            end
        end
        varargout[j] = boundary
    end

    edge2newNode[irregular2edges[:, 1]] .= irregular[:, 3]
    newNodes = reshape(edge2newNode[element2edges], :, 4)
    reftyp = (newNodes .!= 0) * (2 .^ (0:3))'
    none = reftyp .< 15
    red = reftyp .== 15

    idx = findall(red)
    midNodes = zeros(Int, nE)
    midNodes[idx] .= size(coordinates, 1) .+ (1:length(idx))

    for i in idx
        coordinates = vcat(coordinates, sum(coordinates[elements[i, :], :], dims=1) ./ 4)
    end

    prPts = vcat(prPts, elements[idx, :])

    idx = zeros(Int, nE)
    idx[none] .= 1
    idx[red] .= 4
    idx = vcat([1], cumsum(idx))
    newElements = zeros(Int, idx[end] - 1, 4)
    newElements[idx[none], :] .= elements[none, :]
    newElements[vcat(idx[red], 1 .+ idx[red], 2 .+ idx[red], 3 .+ idx[red]), :] .= [elements[red, 1] newNodes[red, 1] midNodes[red] newNodes[red, 4]; elements[red, 2] newNodes[red, 2] midNodes[red] newNodes[red, 1]; elements[red, 3] newNodes[red, 3] midNodes[red] newNodes[red, 2]; elements[red, 4] newNodes[red, 4] midNodes[red] newNodes[red, 3]]

    kdx = find(reftyp .> 0 .& reftyp .< 15)
    idx, jdx, val = findall(newNodes[kdx, :])
    edx = element2edges[kdx[idx] .+ (jdx .- 1) .* nE]
    newIrregular = hcat(edge2nodes[edx, :], val)

    newNodes = reshape(edge2newNode[irregular2edges[:, 2:3]], :, 2)
    kdx = find(sum(newNodes, dims=2) .!= 0)
    idx, jdx, val = findall(newNodes[kdx, :])
    edx = irregular2edges[kdx[idx] .+ (jdx .- 1 .+ 1) .* size(irregular2edges, 1))
    newIrregular = vcat(newIrregular, hcat(edge2nodes[edx[:], :], val[:]))

    indDuplicates = 1:size(coordinates, 1)
    coordUnique, iA, iC = unique(coordinates, dims=1, order=true)

    if length(iA) < length(indDuplicates)
        indDuplicates[iA] .= []  

        Duplicate_num = Int[]

        for i in 1:length(indDuplicates)
            ind = findall((coordinates_initial[:, 1] .== coordinates[indDuplicates[i], 1]) .& (coordinates_initial[:, 2] .== coordinates[indDuplicates[i], 2]))
            push!(Duplicate_num, ind[1])
        end

        for i in 1:length(indDuplicates)
            ind = findall(newElements .== indDuplicates[i])
            if !isempty(ind)
                newElements[ind] .= Duplicate_num[i]
            end
        end
    end
end