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

function purge_noise(phase, min_dist)

    # get unique phases
    phaseID = unique(phase)

    # initialize purge mask
    purge = zeros(Bool, size(phase))
    dist  = zeros(Int,  size(phase))

    # loop over unique phases
    for p in phaseID

        # mask pixels of current phase
        mask = phase .!= p

        dist = get_chessboard_distance(mask)

        # propagate maximum distance in all phase regions
        floodpix(dist)

        # purge small disconnected regions
        purge[(dist .< min_dist) .&& (dist .> 0)] .= true

    end

    # purge pixels
    phase[purge] .= 0

    # assign phases in purged pixels
    fillpix(phase, purge)

    return purge
end

#------------------------------------------------------------------------------

function floodpix(dist)

    R      = findall(dist .!= 0)
    nr, nc = size(dist)
    nch    = 1

    # iterate until all pixels have the same distance in every connected region
    while nch != 0

        nch = 0

        # only loop over pixels with nonzero distance
        for idx in R

            i, j = idx[1], idx[2]

            im, ip, jm, jp = i, i, j, j

            if i > 1    im = i-1 end
            if i < nr   ip = i+1 end

            if j > 1     jm = j-1 end
            if j < nc    jp = j+1 end

            # get largest distance from the neighborhood
            d  = dist[i, j]
            dp = d

            if d < dist[im, j]  d = dist[im, j]  end
            if d < dist[ip, j]  d = dist[ip, j]  end
            if d < dist[i,  jm] d = dist[i,  jm] end
            if d < dist[i,  jp] d = dist[i,  jp] end

            if dp != d

                dist[i, j] = d
                nch +=1

            end
        end
    end
end

#------------------------------------------------------------------------------

function fillpix(phase, purge)

    R      = findall(purge .!= 0)
    nr, nc = size(purge)
    npx    = length(R)

    # iterate until all pixels are assigned with a phase
    while npx != 0
        
        # only loop over pixels with zero phase
        for idx in R

            i, j = idx[1], idx[2]

            # skip assigned pixel
            p = phase[i, j]

            if p != 0 continue end

            im, ip, jm, jp = i, i, j, j
    
            if i > 1    im = i-1 end
            if i < nr   ip = i+1 end
    
            if j > 1     jm = j-1 end
            if j < nc    jp = j+1 end

            # assign phase from the neighborhood
            if phase[im, j]  != 0   p = phase[im, j]  end
            if phase[ip, j]  != 0   p = phase[ip, j]  end
            if phase[i,  jm] != 0   p = phase[i,  jm] end
            if phase[i,  jp] != 0   p = phase[i,  jp] end

            if p != 0
                phase[i, j] = p
                npx -= 1
            end
        end
    end
end

#------------------------------------------------------------------------------
