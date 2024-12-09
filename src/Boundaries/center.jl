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

function get_centers(pcoor, P, T)

    # select "center" points in the polygons

    # get grid steps
    dT = (maximum(T) - minimum(T))/length(T)
    dP = (maximum(P) - minimum(P))/length(P)

    # allocate center arrays
    centers = zeros(Float64, (length(pcoor), 2))


    # println("pcoor: $pcoor")

    # loop over polygons
    for (i, pnodes) in enumerate(pcoor)

        # generate background mask for each polygon
        mask, Pb, Tb = get_background_mask(pnodes, dT, dP)

        # select senter point from the mask
        centers[i, :] = select_point(mask, Pb, Tb)

    end

    return centers
end

#------------------------------------------------------------------------------

function get_background_mask(pnodes, dT, dP)

    # get coordinate bounds with margin
    Tmin = minimum(pnodes[:, 1]) - 2.0*dT
    Tmax = maximum(pnodes[:, 1]) + 2.0*dT
    Pmin = minimum(pnodes[:, 2]) - 2.0*dP
    Pmax = maximum(pnodes[:, 2]) + 2.0*dP

    # get number of cells in the background mask
    Tnc = floor(Int, (Tmax - Tmin)/dT)
    Pnc = floor(Int, (Pmax - Pmin)/dP)

    # get coordinate arrays
    Tb = range(Tmin, Tmax, Tnc + 1) 
    Pb = range(Pmin, Pmax, Pnc + 1) 

    # generate coordinates for all cell centers
    TG, PG = ndgrid((Tb[1:end-1] + Tb[2:end])/2.0, (Pb[1:end-1] + Pb[2:end])/2.0)

    # setup background mask
    M    = inpoly2([TG[:] PG[:]], pnodes)
    IN   = M[:,1] .| M[:,2]
    mask = reshape(IN, size(TG))

    return mask, Pb, Tb
end

#------------------------------------------------------------------------------

function select_point(mask, Pb, Tb)

    # compute distance to polygon boundary
    dist = get_chessboard_distance(.!mask)

    # select cells with maximum distance to the polygon boundary
    R = Tuple.(findall(dist .== maximum(dist)))
    I = first.(R)
    J = last.(R)
 
    # get coordinates of cell centers
    coord = [(Tb[I] .+ Tb[I.+1])/2.0 (Pb[J] .+ Pb[J.+1])/2.0]

    # compute centroid coordinate
    cen = mean(coord, dims=1)
    
    # get distances to centroid
    D = sqrt.((coord[:, 1] .- cen[1]).^2 + (coord[:, 2] .- cen[2]).^2)

    # SELECT POINT WITH LARGEST DISTANCE TO BOUNDARY AND CLOSEST TO CENTROID
    return coord[argmin(D), :]
end

#------------------------------------------------------------------------------
