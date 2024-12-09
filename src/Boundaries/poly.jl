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
 
function get_poly(phase, P, T, nit)

    # identify phase domains
    domains = get_domains(phase)

    nr, nc = size(phase)
    nnr    = nr + 1
    nnc    = nc + 1
    ncell  = nr*nc
    nnode  = nnr*nnc
    cnt    = 1
    ndom   = length(domains)
    phases = zeros(Int, ndom)
    nedges = zeros(Int, ndom)
    edges  = zeros(Int, (4*ncell, 2))

    # loop over domains
    for (i, domain) in enumerate(domains)

        # get and store edges and phase ID for each domain
        pID, ucnt = get_domain_edges(phase, domain, edges, nr, nc, nnr, cnt)
        phases[i] = pID
        nedges[i] = ucnt-cnt
        cnt       = ucnt
    
    end

    # truncate edge storage
    edges = edges[1:cnt-1, :]

    # sort eges for unique identification
    sedges = sort(edges, dims=2)

    # remove edge duplicates, get unique numbering
    sedges = collect(zip(sedges[:, 1], sedges[:, 2]))
    uedges = unique(sedges)
    
    # get unique numbering
    edgnum = Int.(indexin(sedges, uedges))
    edges  = [getfield.(uedges, 1) getfield.(uedges, 2)]

    # renumber nodes in edges, get set of node indices to keep
    edges, N = renum_edges(edges)

    # generate nodal coordinates
    J = ceil.(Int, N/nnr)
    I = N - (J.-1)*nnr
    nodes = [T[I] P[J]]

    # count edges connected to each node
    nodecount = get_node_counts(edges, size(nodes, 1))

    # fix boundary nodes and nodes shared by more than two phases
    fixed = (I .== 1) .|| (I .== nnr) .|| (J .== 1) .|| (J .== nnc) .|| (nodecount .> 2)
    
    # smooth boundaries
    nodes = diffuse(nodes, edges, fixed, nit)

    # store polygon edge numbers and ordered coordinates
    polys = fill(Int[],       ndom)
    pcoor = fill(Float64[;;], ndom)
    cnt   = 1

    for (i, nedge) in enumerate(nedges)

        poly      = copy(edgnum[cnt:cnt+nedge-1])
        pedges, N = renum_edges(edges[poly, :])
        pnodes    = nodes[N, :]
        pnodes    = get_node_cycle(pnodes, pedges)
        polys[i]  = poly
        pcoor[i]  = pnodes
    
        cnt += nedge
    end

    return nodes, edges, polys, pcoor, phases

end

#------------------------------------------------------------------------------

function get_domains(phase)

    # get phase domains (connected components)

    ncell, edges = get_internal_edges(phase)
    
    G = SimpleGraph(ncell)

    for edge in eachrow(edges)

        add_edge!(G, edge[1], edge[2])
    
    end

    domains = connected_components(G)

    return domains
end

#------------------------------------------------------------------------------

function get_domain_edges(phase, domain, edges, nr, nc, nnr, cnt)

    # get edges bounding domain
    local pID

    for cell in domain

        j = ceil(Int, cell/nr)
        i = cell - (j-1)*nr

        pID = phase[i, j]

        # left edge (i,j - i,j+1)
        if i == 1 || phase[i-1, j] != pID

            edges[cnt, 1] = (i) + (j-1)*nnr
            edges[cnt, 2] = (i) + (j  )*nnr
            cnt += 1
        
        end

        # right edge (i+1,j - i+1,j+1)
        if i == nr || phase[i+1, j] != pID

            edges[cnt, 1] = (i+1) + (j-1)*nnr
            edges[cnt, 2] = (i+1) + (j  )*nnr
            cnt += 1
        end

        # bottom edge (i,j - i+1,j)
        if j == 1 || phase[i, j-1] != pID

            edges[cnt, 1] = (i  ) + (j-1)*nnr
            edges[cnt, 2] = (i+1) + (j-1)*nnr
            cnt += 1
        end

        # top edge (i,j+1 - i+1,j+1)
        if j == nc || phase[i, j+1] != pID

            edges[cnt, 1] = (i  ) + (j)*nnr
            edges[cnt, 2] = (i+1) + (j)*nnr
            cnt += 1

        end
    end

    return pID, cnt
end

#------------------------------------------------------------------------------

function get_internal_edges(phase)

    # get edges connecting cells with same phase

    nr, nc = size(phase)
    ncell  = nr*nc
    edges  = zeros(Int, (4*ncell, 2))
    cnt    = 1

    for i in 1:nr
        for j in 1:nc

            ID = i + (j-1)*nr
            p  = phase[i, j]

            if i > 1 && phase[i-1, j] == p
                edges[cnt, 1] = ID
                edges[cnt, 2] = (i-1) + (j-1)*nr
                cnt += 1
            end

            if i < nr && phase[i+1, j] == p
                edges[cnt, 1] = ID
                edges[cnt, 2] = (i+1) + (j-1)*nr
                cnt += 1
            end
            if j > 1 && phase[i, j-1] == p
                edges[cnt, 1] = ID
                edges[cnt, 2] = (i) + (j-2)*nr
                cnt += 1
            end
            if j < nc && phase[i, j+1] == p
                edges[cnt, 1] = ID
                edges[cnt, 2] = (i) + (j)*nr
                cnt += 1
            end
        end
    end

    return ncell, edges[1:cnt-1, :]
end

#------------------------------------------------------------------------------

function get_node_counts(edges, nnode)

    # count edges connected to each node
    nodecount = zeros(Int, nnode)

    for edge in eachrow(edges)
        nodecount[edge[1]] += 1
        nodecount[edge[2]] += 1
    end

    return nodecount
end

#------------------------------------------------------------------------------

function diffuse(nodes, edges, fixed, nit)

    n1    = edges[:, 1]
    n2    = edges[:, 2]
    nedge = size(edges, 1)
    ncoor = copy(nodes)
    ecoor = zeros(Float64, size(edges))

    for i in 1:nit

        # get coordinates of edge centers
        ecoor[:] = (ncoor[n1, :] + ncoor[n2, :])/2.0

        # average edge coordinates to the nodes
        ncoor[:] .= 0.0

        for j in 1:nedge
            ncoor[n1[j], :] += ecoor[j, :]/2.0
            ncoor[n2[j], :] += ecoor[j, :]/2.0
        end

        # keep fixed nodes
        ncoor[fixed, :] = nodes[fixed, :]
    end

    return ncoor
end

#------------------------------------------------------------------------------