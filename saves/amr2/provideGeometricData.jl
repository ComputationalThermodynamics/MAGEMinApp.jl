



function provideGeometricData(elements3, elements4, varargin...)
    edges = [reshape(elements3[:, [1, 2, 2, 3, 3, 1]], :, 2); 
             reshape(elements4[:, [1, 2, 2, 3, 3, 4, 4, 1]], :, 2)]
    
    ptr = [3 * size(elements3, 1), 4 * size(elements4, 1), zeros(Int, nargin - 2)]
    
    for j = 1:nargin - 2
        ptr[j + 2] = size(varargin[j], 1)
        edges = [edges; varargin[j]]
    end
    
    ptr = cumsum(ptr)
    
    # Create numbering of edges
    edge2nodes, _, ie = unique(sort(edges, dims=2), dims=1, return_index=true)
    element3edges = reshape(ie[1:ptr[1]], :, 3)
    element4edges = reshape(ie[ptr[1] + 1:ptr[2]], :, 4)
    
    # Provide boundary2edges
    varargout = Vector{Any}(undef, nargin - 2)
    
    for j = 1:nargin - 2
        varargout[j] = ie[ptr[j + 1] + 1:ptr[j + 2]]
    end
    
    return edge2nodes, element3edges, element4edges, varargout
end