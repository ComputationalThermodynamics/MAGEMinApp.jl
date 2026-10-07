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

"""
    MAGEResRemapLedger

    Per-field content totals of one remap (pulled from the old grid, inflow through the domain edges,
    injected, extracted), the inflow area [m²], the main source of every new leaf (old leaf index,
    -1 inflow, 0 injection) and the injected area of every new leaf [m²].
"""
struct MAGEResRemapLedger
    pulled        :: Vector{Float64}
    inflow        :: Vector{Float64}
    injected      :: Vector{Float64}
    extracted     :: Vector{Float64}
    A_inflow      :: Float64
    source        :: Vector{Int}
    injected_area :: Vector{Float64}
end

"""
    mageres_pull_content!(acc, buf, old::MAGEResGrid, Q::Matrix{Float64}, pre::MAGEResPolygon)

    Add to `acc` the area-weighted content `Q` of the old leaves overlapping polygon `pre`. Returns
    `(A, Ain, best, best_ar)`: polygon area, area covered by the old grid, and the leaf of largest overlap
    with that overlap area.
"""
function mageres_pull_content!(acc::Vector{Float64}, buf::Vector{Int}, old::MAGEResGrid, Q::Matrix{Float64},
                               pre::MAGEResPolygon)
    A = mageres_polygon_area(pre)
    A > 0 || return 0.0, 0.0, 0, 0.0
    xa, xb, ya, yb = mageres_bounding_box(pre)
    mageres_leaves_in_box!(buf, old, xa, xb, ya, yb)
    Ain     = 0.0
    best    = 0
    best_ar = 0.0
    nf      = size(Q, 1)
    @inbounds for m in buf
        bx = mageres_cell_bounds(old, old.leaves[m])
        ar = mageres_polygon_area(mageres_clip_box(pre, bx...))
        ar > 0 || continue
        w = ar / old.area[m]
        for f in 1:nf
            acc[f] += w * Q[f, m]
        end
        Ain += ar
        ar > best_ar && (best = m; best_ar = ar)
    end
    return A, min(Ain, A), best, best_ar
end

"""
    mageres_polygon_centroid_y(p::MAGEResPolygon)

    Vertical coordinate of the centroid of polygon `p`, or the vertex mean for a zero-area polygon.
"""
function mageres_polygon_centroid_y(p::MAGEResPolygon)
    A = mageres_signed_area(p)
    abs(A) > 0 || return sum(q[2] for q in p) / length(p)
    c  = p[1]
    cy = 0.0
    for i in 2:length(p)-1
        a   = cross2(p[i] - c, p[i+1] - c)
        cy += a * (c[2] + p[i][2] + p[i+1][2]) / 3
    end
    return cy / (2A)
end

"""
    mageres_add_inflow!(acc, pre::MAGEResPolygon, A_out::Float64, old::MAGEResGrid, inflow_density::Function)

    Add to `acc` the content of the area `A_out` of `pre` lying outside the old grid, using
    `inflow_density(y)` at the centroid depth of the parts above the top, below the bottom and the rest.
    Returns the added area.
"""
function mageres_add_inflow!(acc::Vector{Float64}, pre::MAGEResPolygon, A_out::Float64, old::MAGEResGrid,
                             inflow_density::Function)
    A_out > 0 || return 0.0
    ytop  = old.y0 + old.ny * old.h0
    ybot  = old.y0
    above = mageres_clip_halfplane(pre, MAGEResPoint(0.0, -1.0), -ytop)
    below = mageres_clip_halfplane(pre, MAGEResPoint(0.0, 1.0), ybot)
    Aa    = mageres_polygon_area(above)
    Ab    = mageres_polygon_area(below)
    rest  = max(0.0, A_out - Aa - Ab)
    Aa > 0 && (acc .+= Aa .* inflow_density(mageres_polygon_centroid_y(above)))
    Ab > 0 && (acc .+= Ab .* inflow_density(mageres_polygon_centroid_y(below)))
    rest > 0 && (acc .+= rest .* inflow_density(mageres_polygon_centroid_y(pre)))
    return A_out
end

"""
    mageres_event_pieces(B::MAGEResPolygon, c::MAGEResChamber, ΔT::Float64)

    Split polygon `B` for a chamber thickness change `ΔT` [m] into `(piece, pre, region)` tuples: the
    piece, its pre-event polygon (empty for newly injected magma) and its region `:host` or `:chamber`.
"""
function mageres_event_pieces(B::MAGEResPolygon, c::MAGEResChamber, ΔT::Float64)
    pieces = Tuple{MAGEResPolygon,MAGEResPolygon,Symbol}[]
    if ΔT == 0 || !(mageres_is_open(c) || ΔT > 0)
        push!(pieces, (B, B, :host))
        return pieces
    end
    F, S, w, a = c.F, c.S, c.shape, c.a
    T0         = c.T
    T1         = c.T + ΔT
    ss         = [mageres_frame_coords(F, p)[1] for p in B]
    smin, smax = extrema(ss)
    if smin < S[1]
        P = mageres_frame_halfplane(B, F, 1.0, 0.0, S[1])
        length(P) >= 3 && push!(pieces, (P, P, :host))
    end
    if smax > S[end]
        P = mageres_frame_halfplane(B, F, -1.0, 0.0, -S[end])
        length(P) >= 3 && push!(pieces, (P, P, :host))
    end
    k1 = max(1, searchsortedlast(S, smin))
    k2 = min(length(S) - 1, searchsortedfirst(S, smax) - 1)
    for k in k1:k2
        Q = mageres_frame_halfplane(mageres_frame_halfplane(B, F, -1.0, 0.0, -S[k]), F, 1.0, 0.0, S[k+1])
        length(Q) >= 3 || continue
        rs = (w[k+1] - w[k]) / (S[k+1] - S[k])
        ŵ(s) = w[k] + rs * (s - S[k])
        r0, r1    = a * T1 * w[k], a * T1 * rs
        f0, f1    = (1 - a) * T1 * w[k], (1 - a) * T1 * rs
        above     = mageres_frame_halfplane(Q, F, r1, -1.0, r1 * S[k] - r0)
        underroof = mageres_frame_halfplane(Q, F, -r1, 1.0, r0 - r1 * S[k])
        inside    = mageres_frame_halfplane(underroof, F, -f1, -1.0, f0 - f1 * S[k])
        below     = mageres_frame_halfplane(Q, F, f1, 1.0, f1 * S[k] - f0)
        if length(above) >= 3
            pre = [p - (a * ΔT * ŵ(mageres_frame_coords(F, p)[1])) * F.n for p in above]
            push!(pieces, (above, pre, :host))
        end
        if length(below) >= 3
            pre = [p + ((1 - a) * ΔT * ŵ(mageres_frame_coords(F, p)[1])) * F.n for p in below]
            push!(pieces, (below, pre, :host))
        end
        length(inside) >= 3 || continue
        if ΔT > 0
            u0, u1 = a * ΔT * w[k], a * ΔT * rs
            d0, d1 = (1 - a) * ΔT * w[k], (1 - a) * ΔT * rs
            up     = mageres_frame_halfplane(inside, F, u1, -1.0, u1 * S[k] - u0)
            rest   = mageres_frame_halfplane(inside, F, -u1, 1.0, u0 - u1 * S[k])
            lo     = mageres_frame_halfplane(rest, F, d1, 1.0, d1 * S[k] - d0)
            band   = mageres_frame_halfplane(rest, F, -d1, -1.0, d0 - d1 * S[k])
            length(up) >= 3 &&
                push!(pieces, (up, [p - (a * ΔT * ŵ(mageres_frame_coords(F, p)[1])) * F.n for p in up], :chamber))
            length(lo) >= 3 &&
                push!(pieces, (lo, [p + ((1 - a) * ΔT * ŵ(mageres_frame_coords(F, p)[1])) * F.n for p in lo],
                               :chamber))
            length(band) >= 3 && push!(pieces, (band, MAGEResPoint[], :chamber))
        else
            pre = T0 > 0 ? [frame_point(F, mageres_frame_coords(F, p)[1], mageres_frame_coords(F, p)[2] * T0 / T1)
                            for p in inside] : MAGEResPoint[]
            push!(pieces, (inside, pre, :chamber))
        end
    end
    return pieces
end

"""
    mageres_remap(old::MAGEResGrid, Q::Matrix{Float64}, c::MAGEResChamber, ΔT::Float64, new::MAGEResGrid;
                  mode, injected_density, inflow_density)

    Conservatively remap the content `Q` (fields × old leaves) onto the `new` grid across a chamber
    thickness change `ΔT` [m], filling opened chamber area with `injected_density` and, for `mode = :remove`,
    extracting the content squeezed out of a closing chamber. Returns `(Qn, ledger::MAGEResRemapLedger)`.
"""
function mageres_remap(old::MAGEResGrid, Q::Matrix{Float64}, c::MAGEResChamber, ΔT::Float64, new::MAGEResGrid;
                       mode::Symbol, injected_density::Vector{Float64}, inflow_density::Function)
    nf            = size(Q, 1)
    Qn            = zeros(nf, mageres_ncells(new))
    buf           = Int[]
    pulled        = zeros(nf)
    inflow        = zeros(nf)
    injected      = zeros(nf)
    extracted     = zeros(nf)
    A_inflow      = 0.0
    acc           = zeros(nf)
    inf           = zeros(nf)
    source        = zeros(Int, mageres_ncells(new))
    injected_area = zeros(mageres_ncells(new))
    for n in 1:mageres_ncells(new)
        xa, xb, ya, yb = mageres_cell_bounds(new, new.leaves[n])
        src_ar         = 0.0
        for (piece, pre, region) in mageres_event_pieces(mageres_box_polygon(xa, xb, ya, yb), c, ΔT)
            fill!(acc, 0.0)
            fill!(inf, 0.0)
            A, Ain, m, ar = mageres_pull_content!(acc, buf, old, Q, pre)
            ar > src_ar && (source[n] = m; src_ar = ar)
            A - Ain > src_ar && (source[n] = -1; src_ar = A - Ain)
            A_inflow += mageres_add_inflow!(inf, pre, A - Ain, old, inflow_density)
            pulled  .+= acc
            inflow  .+= inf
            acc     .+= inf
            if region == :chamber
                Ap = mageres_polygon_area(piece)
                if ΔT > 0
                    Ap - A > src_ar && (source[n] = 0; src_ar = Ap - A)
                    acc              .+= (Ap - A) .* injected_density
                    injected         .+= (Ap - A) .* injected_density
                    injected_area[n]  += Ap - A
                elseif mode == :remove && A > 0
                    kept       = acc .* (Ap / A)
                    extracted .+= acc .- kept
                    acc        .= kept
                end
            end
            @views Qn[:, n] .+= acc
        end
    end
    return Qn, MAGEResRemapLedger(pulled, inflow, injected, extracted, A_inflow, source, injected_area)
end
