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

const MAGEResPoint   = SVector{2,Float64}
const MAGEResPolygon = Vector{MAGEResPoint}

"""
    cross2(a::MAGEResPoint, b::MAGEResPoint)

    Scalar 2D cross product a × b (z-component).
"""
@inline cross2(a::MAGEResPoint, b::MAGEResPoint) = a[1] * b[2] - a[2] * b[1]

"""
    mageres_signed_area(p::MAGEResPolygon)

    Signed area of polygon `p` [m²], positive for counter-clockwise vertex order; 0.0 for fewer than 3 vertices.
"""
function mageres_signed_area(p::MAGEResPolygon)
    n = length(p)
    n < 3 && return 0.0
    c = p[1]
    s = 0.0
    @inbounds for i in 2:n-1
        s += cross2(p[i] - c, p[i+1] - c)
    end
    return 0.5 * s
end

"""
    mageres_polygon_area(p::MAGEResPolygon)

    Unsigned area of polygon `p` [m²].
"""
mageres_polygon_area(p::MAGEResPolygon) = abs(mageres_signed_area(p))

"""
    mageres_clip_halfplane(P::MAGEResPolygon, g::MAGEResPoint, c::Float64)

    Clip polygon `P` to the half-plane g ⋅ x ≤ c and return the clipped polygon.
"""
function mageres_clip_halfplane(P::MAGEResPolygon, g::MAGEResPoint, c::Float64)
    n   = length(P)
    out = MAGEResPoint[]
    n == 0 && return out
    @inbounds for i in 1:n
        a  = P[i]
        b  = P[mod1(i + 1, n)]
        fa = g ⋅ a - c
        fb = g ⋅ b - c
        fa <= 0 && push!(out, a)
        if (fa < 0 && fb > 0) || (fa > 0 && fb < 0)
            push!(out, a + (fa / (fa - fb)) * (b - a))
        end
    end
    return out
end

"""
    mageres_clip_box(P::MAGEResPolygon, xa::Float64, xb::Float64, ya::Float64, yb::Float64)

    Clip polygon `P` to the axis-aligned box [xa, xb] × [ya, yb].
"""
function mageres_clip_box(P::MAGEResPolygon, xa::Float64, xb::Float64, ya::Float64, yb::Float64)
    Q = mageres_clip_halfplane(P, MAGEResPoint(-1.0, 0.0), -xa)
    Q = mageres_clip_halfplane(Q, MAGEResPoint(1.0, 0.0), xb)
    Q = mageres_clip_halfplane(Q, MAGEResPoint(0.0, -1.0), -ya)
    return mageres_clip_halfplane(Q, MAGEResPoint(0.0, 1.0), yb)
end

"""
    mageres_box_polygon(xa, xb, ya, yb)

    Counter-clockwise rectangle polygon of the box [xa, xb] × [ya, yb].
"""
mageres_box_polygon(xa, xb, ya, yb) =
    MAGEResPoint[MAGEResPoint(xa, ya), MAGEResPoint(xb, ya), MAGEResPoint(xb, yb), MAGEResPoint(xa, yb)]

"""
    mageres_bounding_box(p::MAGEResPolygon)

    Axis-aligned bounding box of polygon `p` as `(xa, xb, ya, yb)`.
"""
function mageres_bounding_box(p::MAGEResPolygon)
    xa = xb = p[1][1]
    ya = yb = p[1][2]
    for q in p
        xa = min(xa, q[1]); xb = max(xb, q[1])
        ya = min(ya, q[2]); yb = max(yb, q[2])
    end
    return (xa, xb, ya, yb)
end

"""
    mageres_point_in_polygon(q::MAGEResPoint, p::MAGEResPolygon)

    True if point `q` lies inside polygon `p` (even-odd ray-casting test).
"""
function mageres_point_in_polygon(q::MAGEResPoint, p::MAGEResPolygon)
    inside = false
    n      = length(p)
    j      = n
    @inbounds for i in 1:n
        a = p[i]
        b = p[j]
        if (a[2] > q[2]) != (b[2] > q[2])
            x = a[1] + (q[2] - a[2]) * (b[1] - a[1]) / (b[2] - a[2])
            q[1] < x && (inside = !inside)
        end
        j = i
    end
    return inside
end

"""
    mageres_point_segment_distance(q::MAGEResPoint, a::MAGEResPoint, b::MAGEResPoint)

    Euclidean distance from point `q` to the segment [a, b].
"""
function mageres_point_segment_distance(q::MAGEResPoint, a::MAGEResPoint, b::MAGEResPoint)
    ab = b - a
    L2 = ab ⋅ ab
    L2 == 0 && return norm(q - a)
    λ = clamp(((q - a) ⋅ ab) / L2, 0.0, 1.0)
    return norm(q - (a + λ * ab))
end

"""
    mageres_boundary_distance(q::MAGEResPoint, p::MAGEResPolygon)

    Shortest distance from point `q` to the edges of the closed polygon `p`.
"""
function mageres_boundary_distance(q::MAGEResPoint, p::MAGEResPolygon)
    n = length(p)
    return minimum(mageres_point_segment_distance(q, p[i], p[mod1(i + 1, n)]) for i in 1:n)
end

"""
    MAGEResFrame

    Local orthonormal frame with origin `o`, tangent unit vector `t` and normal unit vector `n`.
"""
struct MAGEResFrame
    o :: MAGEResPoint
    t :: MAGEResPoint
    n :: MAGEResPoint
end

"""
    MAGEResFrame(o::MAGEResPoint, θ::Real)

    Frame at origin `o` with its tangent rotated by the angle `θ` [rad] from the x-axis.
"""
MAGEResFrame(o::MAGEResPoint, θ::Real) =
    MAGEResFrame(o, MAGEResPoint(cos(θ), sin(θ)), MAGEResPoint(-sin(θ), cos(θ)))

"""
    mageres_frame_coords(F::MAGEResFrame, p::MAGEResPoint)

    Frame coordinates `(s, ξ)` of point `p`: tangential and normal offsets from the origin of `F`.
"""
@inline function mageres_frame_coords(F::MAGEResFrame, p::MAGEResPoint)
    d = p - F.o
    return (d ⋅ F.t, d ⋅ F.n)
end

"""
    frame_point(F::MAGEResFrame, s::Real, ξ::Real = 0.0)

    Point at frame coordinates `(s, ξ)` of `F`.
"""
@inline frame_point(F::MAGEResFrame, s::Real, ξ::Real = 0.0) = F.o + s * F.t + ξ * F.n

"""
    mageres_frame_halfplane(P::MAGEResPolygon, F::MAGEResFrame, cs::Float64, cξ::Float64, c0::Float64)

    Clip polygon `P` to the half-plane cs·s + cξ·ξ ≤ c0 expressed in the frame coordinates of `F`.
"""
mageres_frame_halfplane(P::MAGEResPolygon, F::MAGEResFrame, cs::Float64, cξ::Float64, c0::Float64) =
    mageres_clip_halfplane(P, cs * F.t + cξ * F.n, c0 + (cs * F.t + cξ * F.n) ⋅ F.o)

"""
    mageres_trapz(s::AbstractVector, w::AbstractVector)

    Trapezoidal integral of the samples `w` over the abscissae `s`.
"""
mageres_trapz(s::AbstractVector, w::AbstractVector) =
    sum(0.5 * (w[i] + w[i+1]) * (s[i+1] - s[i]) for i in 1:length(s)-1)

"""
    mageres_interp_pl(S::AbstractVector, V::AbstractVector, s::Real)

    Piecewise-linear interpolation of the values `V` at stations `S` to position `s`; 0.0 at or outside
    the end stations.
"""
function mageres_interp_pl(S::AbstractVector, V::AbstractVector, s::Real)
    (s <= S[1] || s >= S[end]) && return 0.0
    k = clamp(searchsortedlast(S, s), 1, length(S) - 1)
    λ = (s - S[k]) / (S[k+1] - S[k])
    return V[k] + λ * (V[k+1] - V[k])
end
