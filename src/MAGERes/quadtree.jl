#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMinApp
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

const MAGEResKey = NTuple{3,Int}

"""
    MAGEResGrid

    Balanced quadtree grid: origin `(x0, y0)` and root cell size `h0` [m], `nx × ny` root cells, maximum
    level `Lmax`, sorted leaf keys `(level, i, j)` with their index map, internal keys, and per-leaf
    centre, size, area and magma area fraction.
"""
struct MAGEResGrid
    x0       :: Float64
    y0       :: Float64
    h0       :: Float64
    nx       :: Int
    ny       :: Int
    Lmax     :: Int
    leaves   :: Vector{MAGEResKey}
    index    :: Dict{MAGEResKey,Int}
    internal :: Set{MAGEResKey}
    xc       :: Vector{Float64}
    yc       :: Vector{Float64}
    h        :: Vector{Float64}
    area     :: Vector{Float64}
    frac     :: Vector{Float64}
end

"""
    cell_size(g::MAGEResGrid, l::Int)

    Cell size [m] at refinement level `l`.
"""
@inline cell_size(g::MAGEResGrid, l::Int) = g.h0 / 2^l

"""
    ncols(g::MAGEResGrid, l::Int)

    Number of cell columns at refinement level `l`.
"""
@inline ncols(g::MAGEResGrid, l::Int) = g.nx << l

"""
    nrows(g::MAGEResGrid, l::Int)

    Number of cell rows at refinement level `l`.
"""
@inline nrows(g::MAGEResGrid, l::Int) = g.ny << l

"""
    mageres_cell_bounds(x0, y0, h0, k::MAGEResKey)

    Bounds `(xa, xb, ya, yb)` [m] of the cell with key `k` in a grid of origin `(x0, y0)` and root size `h0`.
"""
function mageres_cell_bounds(x0, y0, h0, k::MAGEResKey)
    l, i, j = k
    h       = h0 / 2^l
    return (x0 + i * h, x0 + (i + 1) * h, y0 + j * h, y0 + (j + 1) * h)
end

mageres_cell_bounds(g::MAGEResGrid, k::MAGEResKey) = mageres_cell_bounds(g.x0, g.y0, g.h0, k)

"""
    mageres_children(k::MAGEResKey)

    Keys of the four child cells of cell `k`.
"""
mageres_children(k::MAGEResKey) = ((k[1] + 1, 2k[2], 2k[3]),     (k[1] + 1, 2k[2] + 1, 2k[3]),
                                   (k[1] + 1, 2k[2], 2k[3] + 1), (k[1] + 1, 2k[2] + 1, 2k[3] + 1))

"""
    mageres_max_level(o::MAGEResOptions)

    Number of refinement levels needed to go from `grid_h_max_m` down to `grid_h_min_m`.
"""
mageres_max_level(o::MAGEResOptions) = max(0, ceil(Int, log2(o.grid_h_max_m / o.grid_h_min_m) - 1e-9))

"""
    mageres_near_box(boxes::Vector{NTuple{4,Float64}}, x::Float64, y::Float64, r::Float64)

    True if the point `(x, y)` lies within distance `r` of any box `(xa, xb, ya, yb)` in `boxes`.
"""
function mageres_near_box(boxes::Vector{NTuple{4,Float64}}, x::Float64, y::Float64, r::Float64)
    for (xa, xb, ya, yb) in boxes
        dx = max(xa - x, 0.0, x - xb)
        dy = max(ya - y, 0.0, y - yb)
        dx * dx + dy * dy <= r * r && return true
    end
    return false
end

"""
    mageres_build_grid(o::MAGEResOptions, c::MAGEResChamber; targets = NTuple{4,Float64}[])

    Build the balanced quadtree `MAGEResGrid` of the half-domain, refined with `grid_grading` around the
    chamber boundary and the `targets` boxes, with the magma area fraction of every leaf.
"""
function mageres_build_grid(o::MAGEResOptions, c::MAGEResChamber;
                            targets::Vector{NTuple{4,Float64}} = NTuple{4,Float64}[])
    W    = mageres_axis_x(o)
    H    = 1e3 * o.domain_thickness_km
    h0   = o.grid_h_max_m
    nx   = round(Int, W / h0)
    ny   = round(Int, H / h0)
    Lmax = mageres_max_level(o)
    x0   = 0.0
    y0   = -H
    hmin = h0 / 2^Lmax
    cp   = mageres_is_open(c) ? mageres_chamber_polygon(c) : nothing
    function needs_refinement(k::MAGEResKey)
        k[1] >= Lmax && return false
        xa, xb, ya, yb = mageres_cell_bounds(x0, y0, h0, k)
        h              = xb - xa
        xc, yc         = 0.5(xa + xb), 0.5(ya + yb)
        if cp !== nothing
            d = max(0.0, mageres_boundary_distance(MAGEResPoint(xc, yc), cp) - h / sqrt(2))
            h > hmin + o.grid_grading * d && return true
        end
        isempty(targets) && return false
        r = (o.grid_grading > 0 ? (h - hmin) / o.grid_grading : 0.0) + h / sqrt(2)
        return mageres_near_box(targets, xc, yc, r)
    end
    leaves   = Set{MAGEResKey}()
    internal = Set{MAGEResKey}()
    stack    = [(0, i, j) for i in 0:nx-1 for j in 0:ny-1]
    while !isempty(stack)
        k = pop!(stack)
        if needs_refinement(k)
            push!(internal, k)
            append!(stack, mageres_children(k))
        else
            push!(leaves, k)
        end
    end
    mageres_balance!(leaves, internal, nx, ny)
    list  = sort!(collect(leaves))
    index = Dict(k => n for (n, k) in enumerate(list))
    nc    = length(list)
    xc    = Vector{Float64}(undef, nc)
    yc    = similar(xc)
    hh    = similar(xc)
    frac  = zeros(nc)
    bb    = cp === nothing ? nothing : mageres_bounding_box(cp)
    for (n, k) in enumerate(list)
        xa, xb, ya, yb = mageres_cell_bounds(x0, y0, h0, k)
        xc[n]          = 0.5 * (xa + xb)
        yc[n]          = 0.5 * (ya + yb)
        hh[n]          = xb - xa
        if bb !== nothing && !(xb < bb[1] || xa > bb[2] || yb < bb[3] || ya > bb[4])
            frac[n] = mageres_polygon_area(mageres_clip_box(cp, xa, xb, ya, yb)) / (hh[n]^2)
        end
    end
    return MAGEResGrid(x0, y0, h0, nx, ny, Lmax, list, index, internal, xc, yc, hh, hh .^ 2, frac)
end

"""
    mageres_ancestor_leaf(leaves::Set{MAGEResKey}, k::MAGEResKey)

    Key in `leaves` that equals or contains cell `k` at the same or a coarser level, or `nothing`.
"""
function mageres_ancestor_leaf(leaves::Set{MAGEResKey}, k::MAGEResKey)
    l, i, j = k
    for m in l:-1:0
        a = (m, i >> (l - m), j >> (l - m))
        a in leaves && return a
    end
    return nothing
end

"""
    mageres_balance!(leaves::Set{MAGEResKey}, internal::Set{MAGEResKey}, nx::Int, ny::Int)

    Split leaves in place until face-adjacent leaves differ by at most one refinement level.
"""
function mageres_balance!(leaves::Set{MAGEResKey}, internal::Set{MAGEResKey}, nx::Int, ny::Int)
    while true
        split = Set{MAGEResKey}()
        for (l, i, j) in leaves
            for (di, dj) in ((1, 0), (-1, 0), (0, 1), (0, -1))
                ti, tj = i + di, j + dj
                (0 <= ti < nx << l && 0 <= tj < ny << l) || continue
                t = (l, ti, tj)
                (t in leaves || t in internal) && continue
                a = mageres_ancestor_leaf(leaves, t)
                a !== nothing && a[1] < l - 1 && push!(split, a)
            end
        end
        isempty(split) && return
        for k in split
            delete!(leaves, k)
            push!(internal, k)
            for ch in mageres_children(k)
                push!(leaves, ch)
            end
        end
    end
end

"""
    mageres_leaf_at(g::MAGEResGrid, x::Float64, y::Float64)

    Index of the leaf containing the point `(x, y)` (clamped to the grid), or 0 if none is found.
"""
function mageres_leaf_at(g::MAGEResGrid, x::Float64, y::Float64)
    for l in 0:g.Lmax
        h = cell_size(g, l)
        i = clamp(floor(Int, (x - g.x0) / h), 0, ncols(g, l) - 1)
        j = clamp(floor(Int, (y - g.y0) / h), 0, nrows(g, l) - 1)
        n = get(g.index, (l, i, j), 0)
        n > 0 && return n
    end
    return 0
end

"""
    mageres_leaves_in_box!(out::Vector{Int}, g::MAGEResGrid, xa, xb, ya, yb)

    Fill `out` with the indices of the leaves whose bounds intersect the box [xa, xb] × [ya, yb] and return it.
"""
function mageres_leaves_in_box!(out::Vector{Int}, g::MAGEResGrid, xa, xb, ya, yb)
    empty!(out)
    ia = max(0, floor(Int, (xa - g.x0) / g.h0))
    ib = min(g.nx - 1, floor(Int, (xb - g.x0) / g.h0))
    ja = max(0, floor(Int, (ya - g.y0) / g.h0))
    jb = min(g.ny - 1, floor(Int, (yb - g.y0) / g.h0))
    (ia > ib || ja > jb) && return out
    stack = MAGEResKey[(0, i, j) for i in ia:ib for j in ja:jb]
    while !isempty(stack)
        k  = pop!(stack)
        bx = mageres_cell_bounds(g, k)
        (bx[2] < xa || bx[1] > xb || bx[4] < ya || bx[3] > yb) && continue
        n = get(g.index, k, 0)
        if n > 0
            push!(out, n)
        elseif k in g.internal
            append!(stack, mageres_children(k))
        end
    end
    return out
end

const MAGERES_DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))

"""
    mageres_face_neighbors(g::MAGEResGrid, n::Int, d::Int)

    Neighbours of leaf `n` across face `d` (1 +x, 2 -x, 3 +y, 4 -y) as `(kind, indices)`, with `kind`
    one of `:boundary`, `:same`, `:finer` or `:coarser`.
"""
function mageres_face_neighbors(g::MAGEResGrid, n::Int, d::Int)
    l, i, j = g.leaves[n]
    di, dj  = MAGERES_DIRS[d]
    ti, tj  = i + di, j + dj
    (0 <= ti < ncols(g, l) && 0 <= tj < nrows(g, l)) || return (:boundary, Int[])
    t = (l, ti, tj)
    m = get(g.index, t, 0)
    m > 0 && return (:same, [m])
    if t in g.internal
        ks = if d == 1
            ((l + 1, 2ti, 2tj), (l + 1, 2ti, 2tj + 1))
        elseif d == 2
            ((l + 1, 2ti + 1, 2tj), (l + 1, 2ti + 1, 2tj + 1))
        elseif d == 3
            ((l + 1, 2ti, 2tj), (l + 1, 2ti + 1, 2tj))
        else
            ((l + 1, 2ti, 2tj + 1), (l + 1, 2ti + 1, 2tj + 1))
        end
        return (:finer, [g.index[k] for k in ks])
    end
    return (:coarser, [g.index[(l - 1, ti >> 1, tj >> 1)]])
end

"""
    mageres_ncells(g::MAGEResGrid)

    Number of leaves of the grid.
"""
mageres_ncells(g::MAGEResGrid) = length(g.leaves)

"""
    mageres_magma_area(g::MAGEResGrid)

    Total magma area of the grid [m²], the sum of leaf area times magma fraction.
"""
mageres_magma_area(g::MAGEResGrid) = sum(g.frac .* g.area)

"""
    mageres_max_level_jump(g::MAGEResGrid)

    Largest refinement-level difference between any two face-adjacent leaves.
"""
function mageres_max_level_jump(g::MAGEResGrid)
    worst = 0
    for n in 1:mageres_ncells(g), d in 1:4
        _, nb = mageres_face_neighbors(g, n, d)
        for m in nb
            worst = max(worst, abs(g.leaves[m][1] - g.leaves[n][1]))
        end
    end
    return worst
end
