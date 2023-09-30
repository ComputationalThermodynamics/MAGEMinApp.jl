"""
duplicate of matlab meshgrid function
"""
function meshgrid(xin,yin)
    nx      = length(xin)
    ny      = length(yin)
    xout    = zeros(ny,nx)
    yout    = zeros(ny,nx)
    for jx = 1:nx
        for ix=1:ny
            xout[ix,jx] = xin[jx]
            yout[ix,jx] = yin[ix]
        end
    end
    return (x=xout, y=yout)
end


function GenerateRegularMesh_AMR(T_vec1D, P_vec1D)
    # Generates a regular mesh for use with AMR methods (initial mesh)

    T_2D, P_2D = meshgrid(T_vec1D, P_vec1D)

    id = ones(Int, size(P_2D))  # Specify the type as Int

    idx = CartesianIndices(id)
    
    for (i, index) in enumerate(idx)
        id[index] = i
    end

    id1 = id[1:end-1, 1:end-1]
    id2 = id[1:end-1, 2:end]
    id3 = id[2:end, 2:end]
    id4 = id[2:end, 1:end-1]

    elements4 = hcat(id1[:], id2[:], id3[:], id4[:])
    coordinates = hcat(T_2D[:], P_2D[:])
    irregular = zeros(0, 3)

    return coordinates, elements4, irregular
end


P_vec1D       =   [0.,1.,0.,1.]
T_vec1D       =   [0.,0.,1.,1.]


coordinates, elements4, irregular = GenerateRegularMesh_AMR(T_vec1D, P_vec1D)