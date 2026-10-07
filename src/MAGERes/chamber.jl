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
    MAGEResChamber

    Sill-like magma chamber: local frame `F`, along-axis stations `S` [m], normalized thickness profile
    `shape`, its integral `I` [m], roof opening share `a`, thickness scale `T` [m], and injection and
    extraction counters.
"""
mutable struct MAGEResChamber
    F             :: MAGEResFrame
    S             :: Vector{Float64}
    shape         :: Vector{Float64}
    I             :: Float64
    a             :: Float64
    T             :: Float64
    n_injections  :: Int
    n_extractions :: Int
end

const MAGERES_SYMMETRY = 2.0

"""
    mageres_axis_x(o::MAGEResOptions)

    Horizontal position [m] of the symmetry axis, at half the domain width.
"""
mageres_axis_x(o::MAGEResOptions) = 500 * o.domain_width_km

"""
    MAGEResChamber(o::MAGEResOptions)

    Closed chamber (zero thickness) centred on the symmetry axis at the chamber depth of `o`, with
    `lens_n_segments` segments and an ellipse or parabola thickness profile.
"""
function MAGEResChamber(o::MAGEResOptions)
    L          = 1e3 * o.lens_length_km
    S          = collect(range(-L / 2, L / 2; length = o.lens_n_segments + 1))
    f          = o.lens_shape == "ellipse" ? (x -> sqrt(max(0.0, 1 - x^2))) : (x -> max(0.0, 1 - x^2))
    shape      = [f(2s / L) for s in S]
    shape[1]   = 0.0
    shape[end] = 0.0
    F          = MAGEResFrame(MAGEResPoint(mageres_axis_x(o), mageres_model_top_depth(o) - 1e3 * o.lens_depth_km), 0.0)
    return MAGEResChamber(F, S, shape, mageres_trapz(S, shape), mageres_opening_share(o.opening_mode), 0.0, 0, 0)
end

"""
    mageres_injection_volume(o::MAGEResOptions)

    Cross-sectional area [m²] of one injected lens of length `lens_length_km` and thickness
    `lens_thickness_m` (ellipse or parabola profile).
"""
function mageres_injection_volume(o::MAGEResOptions)
    L = 1e3 * o.lens_length_km
    w = o.lens_thickness_m
    return o.lens_shape == "ellipse" ? π / 4 * L * w : 2 / 3 * L * w
end

"""
    mageres_chamber_area(c::MAGEResChamber)

    Cross-sectional area of the chamber [m²].
"""
mageres_chamber_area(c::MAGEResChamber) = c.T * c.I

"""
    mageres_chamber_thickness(c::MAGEResChamber)

    Maximum thickness of the chamber [m].
"""
mageres_chamber_thickness(c::MAGEResChamber) = c.T * maximum(c.shape)

"""
    mageres_is_open(c::MAGEResChamber)

    True if the chamber has a positive thickness.
"""
mageres_is_open(c::MAGEResChamber) = c.T > 0

"""
    mageres_chamber_polygon(c::MAGEResChamber)

    Outline polygon of the chamber: floor stations followed by roof stations in reverse order.
"""
function mageres_chamber_polygon(c::MAGEResChamber)
    N     = length(c.S)
    floor = [frame_point(c.F, c.S[i], -(1 - c.a) * c.T * c.shape[i]) for i in 1:N]
    roof  = [frame_point(c.F, c.S[i], c.a * c.T * c.shape[i]) for i in N-1:-1:2]
    return vcat(floor, roof)
end
