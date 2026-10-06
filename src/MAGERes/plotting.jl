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

const MAGERES_INJECTED_COLORS  = ("rgb(49,104,164)", "rgb(140,184,222)")
const MAGERES_EXTRACTED_COLORS = ("rgb(204,102,20)", "rgb(245,178,107)")

const MAGERES_MAP_DOMAIN  = [0.0, 0.68]
const MAGERES_LOG_DOMAIN  = [0.77, 1.0]
const MAGERES_LOG_XDOMAIN = [0.0, 0.46]
const MAGERES_INFO_X      = 0.52
const MAGERES_PIE_XDOMAIN = [0.72, 1.0]
const MAGERES_PIE_UNITS   = Dict(1 => "mol%", 2 => "wt%", 3 => "vol%")
const MAGERES_MAP_ASPECT  = 2.2

"""
    mageres_default_probe(st::MAGEResState)

    Default probe position `(x [km], depth [km])`: the symmetry axis at the lens depth.
"""
mageres_default_probe(st::MAGEResState) = (mageres_axis_x(st.opts) / 1e3, st.opts.lens_depth_km)

"""
    mageres_mirror_x(st::MAGEResState, x::Real)

    Lateral position `x` [m] reflected across the symmetry axis onto the modelled half-domain.
"""
mageres_mirror_x(st::MAGEResState, x::Real) = (a = mageres_axis_x(st.opts); x > a ? 2a - x : Float64(x))

"""
    mageres_probe_cell(st::MAGEResState, probe)

    Index of the leaf cell under `probe = (x [km], depth [km])`, mirrored onto the half-domain;
    0 when the probe lies outside the domain.
"""
function mageres_probe_cell(st::MAGEResState, probe)
    g    = st.grid
    x, d = mageres_mirror_x(st, 1e3 * Float64(probe[1])), Float64(probe[2])
    (g.x0 <= x <= mageres_axis_x(st.opts) && 0 <= d <= st.opts.domain_thickness_km) || return 0
    return mageres_leaf_at(g, x, st.z_top - 1e3 * d)
end

"""
    mageres_probe_traces(st::MAGEResState, probe, unit::Int)

    Phase-proportion pie (`unit` 1 mol%, 2 wt%, 3 vol%) and position marker for the cell under `probe`.
    Returns `(traces, info_html, sets)`, `sets` holding the mol/wt/vol% values or `nothing`.
"""
function mageres_probe_traces(st::MAGEResState, probe, unit::Int)
    th = st.thermo
    th === nothing && return GenericTrace[], "Phase proportions require MAGEMin thermodynamics", nothing
    c  = mageres_probe_cell(st, probe)
    c == 0 && return GenericTrace[], "Click a cell of the map to show its phase proportions", nothing
    p        = th.points[c]
    T        = st.Q[MAGERES_IE, c] / st.Q[MAGERES_IC, c] - MAGERES_T0_K
    material = ("host", "magma/mush", "mobile body", "cumulate mush", "compacted cumulate", "partially molten host",
                "host feeding the chamber", "restite (melt extracted)")
    cls      = Int(mageres_material_class(st)[c])
    xh       = 1e3 * Float64(probe[1]) > mageres_axis_x(st.opts) ? 2 * mageres_axis_x(st.opts) - st.grid.xc[c] :
               st.grid.xc[c]
    head     = @sprintf("<b>Selected cell</b> (%s)<br>x = %.2f km, depth = %.2f km<br>T = %.0f °C, P = %.2f kbar<br>melt %.0f %%",
                        material[cls+1], xh / 1e3, mageres_depth_km(st, st.grid.yc[c]), T,
                        mageres_lithostatic_kbar(st.opts, st.grid.yc[c]), 100 * mageres_melt_ratio(p))
    n        = minimum(length, (p.ph, p.ph_frac, p.ph_frac_wt, p.ph_frac_vol))
    keep     = [i for i in 1:n if p.ph_frac[i] > 0 || p.ph_frac_wt[i] > 0 || p.ph_frac_vol[i] > 0]
    isempty(keep) && return GenericTrace[], head * "<br>no phase data", nothing
    ids      = sort(keep; by = i -> -p.ph_frac[i])
    sets     = (100 .* p.ph_frac[ids], 100 .* p.ph_frac_wt[ids], 100 .* p.ph_frac_vol[ids])
    u        = clamp(unit, 1, 3)
    labels   = display_ph_names_tagged(p.ph[ids], st.opts.database)
    tr  = pie(; name                  = "Phase proportions",
                labels                = labels,
                values                = sets[u],
                customdata            = p.ph[ids],
                sort                  = false,
                domain                = attr(x = MAGERES_PIE_XDOMAIN, y = MAGERES_LOG_DOMAIN),
                title                 = attr(text = MAGERES_PIE_UNITS[u], position = "bottom center"),
                textposition          = "inside",
                textinfo              = "label+percent",
                hoverinfo             = "label+percent",
                insidetextorientation = "horizontal",
                showlegend            = false,
                textfont              = attr(size = 10))
    hit = scatter(; name       = "Probe",
                    x          = [xh / 1e3],
                    y          = [mageres_depth_km(st, st.grid.yc[c])],
                    xaxis      = "x",
                    yaxis      = "y",
                    mode       = "markers",
                    marker     = attr(symbol = "x-thin", size = 11, color = "rgb(0,180,255)",
                                      line = attr(width = 2, color = "rgb(0,180,255)")),
                    hoverinfo  = "skip",
                    showlegend = false)
    return GenericTrace[tr, hit], head, sets
end

"""
    mageres_view_box(st::MAGEResState)

    Plotted window `(xa, xb, ya, yb)` [m]: twice the chamber length wide (wider if the chamber has grown beyond it),
    centred vertically on the chamber with the height giving the map aspect `MAGERES_MAP_ASPECT`, at least the chamber
    plus a margin, kept inside the domain.
"""
function mageres_view_box(st::MAGEResState)
    o              = st.opts
    g              = st.grid
    L              = 1e3 * o.lens_length_km
    cx, cy         = mageres_axis_x(o), -1e3 * o.lens_depth_km
    m              = 0.15L
    xa, xb         = cx - L, cx + L
    ca, cb         = cy - m, cy + m
    if mageres_is_open(st.chamber)
        bx     = mageres_bounding_box(mageres_chamber_polygon(st.chamber))
        xa, xb = min(xa, bx[1] - m), max(xb, bx[2] + m)
        ca, cb = bx[3] - m, bx[4] + m
    end
    xa, xb = max(xa, g.x0), min(xb, 2 * mageres_axis_x(o) - g.x0)
    bottom = -1e3 * o.domain_thickness_km
    hgt    = min(max((xb - xa) / MAGERES_MAP_ASPECT, cb - ca), -bottom)
    ym     = 0.5 * (ca + cb)
    ya, yb = ym - 0.5hgt, ym + 0.5hgt
    ya, yb = ya < bottom ? (bottom, bottom + hgt) : yb > 0.0 ? (-hgt, 0.0) : (ya, yb)
    return (xa, xb, ya, yb)
end

"""
    mageres_sample_box(st::MAGEResState, vbox)

    Sampled window around the plotted window `vbox`: the full domain width and half the window height above and
    below, clipped to the domain, so that the map stays filled when the axes extend to the screen aspect.
"""
function mageres_sample_box(st::MAGEResState, vbox)
    g              = st.grid
    xa, xb, ya, yb = vbox
    bottom         = -1e3 * st.opts.domain_thickness_km
    pad            = 0.5 * (yb - ya)
    return (g.x0, 2 * mageres_axis_x(st.opts) - g.x0, max(ya - pad, bottom), min(yb + pad, 0.0))
end

"""
    mageres_smooth_value(st::MAGEResState, v::Vector{Float64}, x::Float64, y::Float64)

    Inverse-squared-distance weighted mean of the cell field `v` at `(x, y)` [m] over the containing leaf,
    its face neighbours and their face neighbours.
"""
function mageres_smooth_value(st::MAGEResState, v::Vector{Float64}, x::Float64, y::Float64)
    g     = st.grid
    c     = mageres_leaf_at(g, x, y)
    cells = [c]
    for d in 1:4, m in mageres_face_neighbors(g, c, d)[2]
        push!(cells, m)
        for d2 in 1:4, m2 in mageres_face_neighbors(g, m, d2)[2]
            push!(cells, m2)
        end
    end
    num = 0.0
    den = 0.0
    for m in unique(cells)
        r2   = (g.xc[m] - x)^2 + (g.yc[m] - y)^2
        w    = 1 / (r2 + (0.1 * g.h[c])^2)
        num += w * v[m]
        den += w
    end
    return num / den
end

"""
    mageres_smooth_image(st::MAGEResState, v::Vector{Float64}, xs::Vector{Float64}, ys::Vector{Float64})

    Smoothed cell field `v` sampled at the mirrored points `ys × xs` [m], as a `length(ys) × length(xs)` matrix.
"""
function mageres_smooth_image(st::MAGEResState, v::Vector{Float64}, xs::Vector{Float64}, ys::Vector{Float64})
    return [mageres_smooth_value(st, v, mageres_mirror_x(st, x), y) for y in ys, x in xs]
end

"""
    mageres_field_image(st::MAGEResState, v::Vector{Float64}; box = mageres_view_box(st), resolution = nothing)

    Cell field `v` sampled on a regular grid over `box` with spacing `resolution` [m] (default width / 300,
    never finer than the finest leaf). Returns `(xs, ys, z)`.
"""
function mageres_field_image(st::MAGEResState, v::Vector{Float64}; box = mageres_view_box(st), resolution = nothing)
    g              = st.grid
    xa, xb, ya, yb = box
    h  = max(resolution === nothing ? (xb - xa) / 300 : Float64(resolution), g.h0 / 2^g.Lmax)
    nx = max(1, round(Int, (xb - xa) / h))
    ny = max(1, round(Int, (yb - ya) / h))
    xs = [xa + (i - 0.5) * (xb - xa) / nx for i in 1:nx]
    ys = [ya + (j - 0.5) * (yb - ya) / ny for j in 1:ny]
    z  = [v[mageres_leaf_at(g, mageres_mirror_x(st, x), y)] for y in ys, x in xs]
    return xs, ys, z
end

"""
    mageres_depth_km(st::MAGEResState, y)

    Depth [km] below the domain top of the elevation(s) `y` [m].
"""
mageres_depth_km(st::MAGEResState, y) = (st.z_top .- y) ./ 1e3

"""
    mageres_pressure_kbar(st::MAGEResState)

    Lithostatic pressure [kbar] at every cell centre.
"""
mageres_pressure_kbar(st::MAGEResState) = [mageres_lithostatic_kbar(st.opts, y) for y in st.grid.yc]

"""
    mageres_level(st::MAGEResState)

    Refinement level of every leaf cell, as Float64.
"""
mageres_level(st::MAGEResState) = Float64[k[1] for k in st.grid.leaves]

"""
    mageres_field_values(st::MAGEResState, field::Symbol)

    Cell values, colour range, colourbar title, colourscale and reverse-scale flag of the map field
    `field` (`:T`, `:frac`, `:pressure`, `:level`, `:melt`, `:calc` or `:material`).
"""
function mageres_field_values(st::MAGEResState, field::Symbol)
    o = st.opts
    field == :T        && (T = mageres_temperature(st);
                           return T, (o.T_surface_C, max(o.T_injection_C, maximum(T))), "T (°C)", "Hot", true)
    field == :frac     && return st.grid.frac, (0.0, 1.0), "magma fraction", "Reds", false
    field == :pressure && (P = mageres_pressure_kbar(st); return P, extrema(P), "P (kbar)", "Viridis", false)
    field == :level    && return mageres_level(st), (0.0, Float64(st.grid.Lmax)), "refinement level", "Blues", false
    field == :melt     && return mageres_melt_fraction(st), (0.0, 1.0), "melt / (melt + solid), vol",
                                 MAGERES_MELT_COLORS, false
    field == :calc     && return (st.thermo === nothing ? zeros(mageres_ncells(st.grid)) :
                                  Float64.(st.thermo.calc_count)),
                                 (0.0, st.thermo === nothing ? 1.0 :
                                       max(1.0, Float64(maximum(st.thermo.calc_count; init = 0)))),
                                 "calculations per cell", "YlOrRd", true
    field == :material && return mageres_material_class(st), (-0.5, length(MAGERES_MATERIAL_CLASS_COLORS) - 0.5),
                                 "0 host · 1 magma/mush · 2 mobile · 3 cumulate mush · 4 compacted cumulate<br>5 host melt ≤ φ<sub>perc</sub> · 6 host melt > φ<sub>perc</sub> (feeding the chamber) · 7 restite",
                                 MAGERES_MATERIAL_COLORS, false
    throw(ArgumentError("unknown field $field"))
end

const MAGERES_MELT_COLORS = [[0.0, "rgb(255,255,255)"], [0.05, "rgb(237,242,250)"], [0.25, "rgb(191,211,230)"],
                             [0.5, "rgb(140,150,198)"], [0.75, "rgb(136,65,157)"], [1.0, "rgb(77,0,75)"]]

const MAGERES_MATERIAL_CLASS_COLORS = ("rgb(200,200,200)", "rgb(214,96,77)", "rgb(253,174,97)", "rgb(145,191,219)",
                                       "rgb(49,84,150)", "rgb(250,232,150)", "rgb(140,81,160)", "rgb(140,110,80)")
const MAGERES_RESTITE_FRAC          = 0.5
const MAGERES_MATERIAL_CLASS_NAMES  = ("Host rock",
                                       "Magma or mush (melt ≤ φ<sub>lock</sub>, not mobile)",
                                       "Mobile body (melt > φ<sub>lock</sub>)",
                                       "Cumulate mush (melt > φ<sub>perc</sub>)",
                                       "Compacted cumulate",
                                       "Partially molten host (melt ≤ φ<sub>perc</sub>)",
                                       "Host feeding the chamber (melt > φ<sub>perc</sub>)",
                                       "Restite (melt extracted)")
const MAGERES_LEGEND_ROW_PX         = 20
const MAGERES_LEGEND_TOP_PX         = 48
const MAGERES_CUMULATE_MUSH_EXCESS  = 0.02

const MAGERES_MATERIAL_COLORS = [[x, c] for (k, c) in enumerate(MAGERES_MATERIAL_CLASS_COLORS)
                                 for x in ((k - 1) / length(MAGERES_MATERIAL_CLASS_COLORS),
                                           k / length(MAGERES_MATERIAL_CLASS_COLORS))]

"""
    mageres_material_class(st::MAGEResState; split_cumulate::Bool = true)

    Material class of every cell: 0 host, 1 magma/mush, 2 mobile body, 3 cumulate mush, 4 compacted cumulate,
    5 partially molten host, 6 host feeding the chamber, 7 restite (host that has given melt to the chamber).
    With `split_cumulate = false` all cumulate is class 4.
"""
function mageres_material_class(st::MAGEResState; split_cumulate::Bool = true)
    n = mageres_ncells(st.grid)
    v = Float64[st.grid.frac[c] >= 0.5 ? 1.0 : 0.0 for c in 1:n]
    if st.thermo !== nothing
        melt    = mageres_melt_fraction(st)
        donor   = length(st.donor) == n ? st.donor : falses(n)
        restite = length(st.restite_frac) == n ? st.restite_frac .>= MAGERES_RESTITE_FRAC : falses(n)
        for c in 1:n
            v[c] == 0 || continue
            if melt[c] > st.opts.phi_perc || donor[c]
                v[c] = 6.0
            elseif restite[c]
                v[c] = 7.0
            elseif melt[c] > 0
                v[c] = 5.0
            end
        end
    end
    length(st.body) == n && (v[st.body] .= 2.0)
    if length(st.cumulate_t) == n
        cum     = mageres_cumulate(st)
        v[cum] .= 4.0
        if split_cumulate && st.thermo !== nothing
            melt = mageres_melt_fraction(st)
            v[cum .& (melt .> st.opts.phi_perc + MAGERES_CUMULATE_MUSH_EXCESS)] .= 3.0
        end
    end
    return v
end

"""
    mageres_finite_or_nothing(v)

    Copy of `v` as Float64 with non-finite entries replaced by `nothing`.
"""
mageres_finite_or_nothing(v) = Union{Float64,Nothing}[isfinite(x) ? Float64(x) : nothing for x in v]

"""
    mageres_grid_trace(st::MAGEResState; box = mageres_view_box(st))

    Line trace of the left and bottom edges of every leaf cell and of its mirror image, clipped to `box`,
    in km / depth coordinates.
"""
function mageres_grid_trace(st::MAGEResState; box = mageres_view_box(st))
    g = st.grid
    x = Union{Float64,Nothing}[]
    y = Union{Float64,Nothing}[]
    bxa, bxb, wa, wb = box
    a = mageres_axis_x(st.opts)
    for k in g.leaves
        xa0, xb0, ya, yb = mageres_cell_bounds(g, k)
        (yb < wa || ya > wb) && continue
        ya, yb = max(ya, wa), min(yb, wb)
        for (xa, xb) in ((xa0, xb0), (2a - xb0, 2a - xa0))
            (xb < bxa || xa > bxb) && continue
            xa, xb = max(xa, bxa), min(xb, bxb)
            append!(x, (xa / 1e3, xa / 1e3, xb / 1e3, nothing))
            append!(y, (mageres_depth_km(st, yb), mageres_depth_km(st, ya), mageres_depth_km(st, ya), nothing))
        end
    end
    return scatter(; x         = x,
                     y         = y,
                     mode      = "lines",
                     xaxis     = "x",
                     yaxis     = "y",
                     line      = attr(color = "rgba(40,40,40,0.35)", width = 0.5),
                     hoverinfo = "skip",
                     name      = "grid")
end

"""
    mageres_polygon_trace(st::MAGEResState, p::Vector{MAGEResPoint}; kwargs...)

    Closed line trace of the polygon `p` [m] on the map axes, in km / depth coordinates;
    `kwargs` are passed to `scatter`.
"""
function mageres_polygon_trace(st::MAGEResState, p::Vector{MAGEResPoint}; kwargs...)
    x = [q[1] / 1e3 for q in p]
    y = [mageres_depth_km(st, q[2]) for q in p]
    push!(x, x[1]); push!(y, y[1])
    return scatter(; x = x, y = y, mode = "lines", xaxis = "x", yaxis = "y", kwargs...)
end

"""
    mageres_composition_text(n::Vector{Float64}, oxides::Vector{String})

    HTML lines `oxide percent` of the normalised composition `n`, skipping oxides below 0.1 %;
    empty when `n` sums to zero.
"""
function mageres_composition_text(n::Vector{Float64}, oxides::Vector{String})
    s = sum(n)
    s > 0 || return ""
    return join((@sprintf("%s %.2f", oxides[i], 100 * n[i] / s) for i in eachindex(n) if n[i] / s > 1e-3), "<br>")
end

const MAGERES_LOG_MAX_BOXES = 50

"""
    mageres_log_groups(c::MAGEResColumn)

    Consecutive layers of column `c` grouped so that each group spans at least 1/`MAGERES_LOG_MAX_BOXES` of the
    column's total area; one group per layer when the layers are large enough.
"""
function mageres_log_groups(c::MAGEResColumn)
    groups = UnitRange{Int}[]
    total  = mageres_column_area(c)
    total > 0 || return groups
    a0, acc = 1, 0.0
    for k in eachindex(c.layers)
        acc += c.layers[k].area
        if acc >= total / MAGERES_LOG_MAX_BOXES || k == length(c.layers)
            push!(groups, a0:k)
            a0, acc = k + 1, 0.0
        end
    end
    return groups
end

"""
    mageres_log_traces(c::MAGEResColumn, row::Float64, colors::NTuple{2,String}, label::String, oxides::Vector{String})

    Filled boxes along cumulative area [km²] at `row` of the log panel, one per layer of column `c` or per group of
    consecutive small layers (`mageres_log_groups`), alternating `colors`, with episode details on hover.
"""
function mageres_log_traces(c::MAGEResColumn, row::Float64, colors::NTuple{2,String}, label::String,
                            oxides::Vector{String})
    traces = GenericTrace[]
    x      = 0.0
    for (k, r) in enumerate(mageres_log_groups(c))
        ls    = c.layers[r]
        dx    = sum(l.area for l in ls) / 1e6
        T     = sum(l.T * l.area for l in ls) / sum(l.area for l in ls)
        moles = reduce(+, (l.moles for l in ls))
        head  = length(ls) == 1 ?
                @sprintf("%s episode %d<br>t = %.0f yr", label, first(r), ls[1].t) :
                @sprintf("%s episodes %d–%d (%d)<br>t = %.0f–%.0f yr", label, first(r), last(r), length(ls), ls[1].t,
                         ls[end].t)
        push!(traces, scatter(; x           = [x, x + dx, x + dx, x, x],
                                y           = row .+ [-0.35, -0.35, 0.35, 0.35, -0.35],
                                xaxis       = "x2",
                                yaxis       = "y2",
                                mode        = "lines",
                                fill        = "toself",
                                fillcolor   = colors[isodd(k) ? 1 : 2],
                                line        = attr(color = "white", width = 1),
                                name        = uppercasefirst(label),
                                legendgroup = uppercasefirst(label),
                                showlegend  = false,
                                hoveron     = "fills",
                                hoverinfo   = "text",
                                text        = @sprintf("%s<br>area = %.4f km²<br>T = %.0f °C<br>%s", head, dx, T,
                                                       mageres_composition_text(moles, oxides))))
        x += dx
    end
    return traces
end

"""
    mageres_traces(st::MAGEResState; field = :T, show_grid = true, resolution = nothing, preview = nothing,
                   probe = nothing, pie_unit = 1, show_outline = true, show_isotherms = true)

    Traces of the reservoir figure: heatmap of `field`, optional grid, isotherms, chamber outline and preview
    polygon, the injected / erupted logs and the optional probe pie.
"""
function mageres_traces(st::MAGEResState; field::Symbol = :T, show_grid::Bool = true, resolution = nothing,
                        preview::Union{Nothing,Vector{MAGEResPoint}} = nothing, probe = nothing, pie_unit::Int = 1,
                        show_outline::Bool = true, show_isotherms::Bool = true)
    o    = st.opts
    vbox = mageres_view_box(st)
    box  = mageres_sample_box(st, vbox)
    res  = resolution === nothing ? (vbox[2] - vbox[1]) / 300 : resolution
    v, (zmin, zmax), title, cs, rev = mageres_field_values(st, field)
    xs, ys, z = mageres_field_image(st, v; box = box, resolution = res)
    zrows     = [collect(z[j, :]) for j in axes(z, 1)]
    md        = MAGERES_MAP_DOMAIN
    cbar = attr(title     = attr(text = title, side = "right"),
                len       = md[2] - md[1],
                lenmode   = "fraction",
                y         = (md[1] + md[2]) / 2,
                yanchor   = "middle",
                x         = 1.005,
                xanchor   = "left",
                thickness = 14,
                xpad      = 0)
    field == :material && (cbar[:tickmode] = "array";
                           cbar[:tickvals] = collect(0:length(MAGERES_MATERIAL_CLASS_COLORS)-1))
    traces = GenericTrace[heatmap(; name          = "Model cells",
                                    x             = xs ./ 1e3,
                                    y             = mageres_depth_km(st, ys),
                                    z             = zrows,
                                    transpose     = false,
                                    xaxis         = "x",
                                    yaxis         = "y",
                                    colorscale    = cs,
                                    reversescale  = rev,
                                    zmin          = zmin,
                                    zmax          = zmax,
                                    colorbar      = cbar,
                                    showscale     = field != :material,
                                    hovertemplate = "x %{x:.2f} km<br>depth %{y:.2f} km<br>%{z:.2f}<extra></extra>")]
    show_grid && push!(traces, mageres_grid_trace(st; box = box))
    if field == :T && show_isotherms
        nx_c, ny_c = max(2, length(xs) ÷ 3), max(2, length(ys) ÷ 3)
        xc         = collect(range(xs[1], xs[end]; length = nx_c))
        yc         = collect(range(ys[1], ys[end]; length = ny_c))
        zs         = mageres_smooth_image(st, v, xc, yc)
        zc         = [collect(zs[j, :]) for j in axes(zs, 1)]
        push!(traces, contour(; name      = "Isotherms",
                                x         = xc ./ 1e3,
                                y         = mageres_depth_km(st, yc),
                                z         = zc,
                                transpose = false,
                                xaxis     = "x",
                                yaxis     = "y",
                                showscale = false,
                                hoverinfo = "skip",
                                line      = attr(color = "white", width = 1),
                                contours  = attr(coloring   = "none",
                                                 start      = 100,
                                                 size       = 100,
                                                 var"end"   = 2000,
                                                 showlabels = true,
                                                 labelfont  = attr(color = "white", size = 10))))
    end
    if show_outline && mageres_is_open(st.chamber)
        push!(traces, mageres_polygon_trace(st, mageres_chamber_polygon(st.chamber);
                                            name       = "Chamber outline",
                                            line       = attr(color = "rgb(40,160,255)", width = 1.5),
                                            showlegend = false,
                                            hoverinfo  = "skip"))
    end
    (preview === nothing || !show_outline) || push!(traces, mageres_polygon_trace(st, preview;
                                                        name       = "Chamber after first injection",
                                                        line       = attr(color = "rgb(40,160,255)", width = 1.5,
                                                                          dash = "dash"),
                                                        showlegend = false,
                                                        hoverinfo  = "skip"))
    push!(traces, scatter(; name = "Log axis", x = [0.0, 0.0], y = [0.0, 1.0], xaxis = "x2", yaxis = "y2", mode = "lines",
                            line = attr(width = 0), hoverinfo = "skip", showlegend = false))
    append!(traces, mageres_log_traces(st.source, 1.0, MAGERES_INJECTED_COLORS, "injected", o.oxides))
    append!(traces, mageres_log_traces(st.pluton, 0.0, MAGERES_EXTRACTED_COLORS, "erupted", o.oxides))
    probe === nothing || append!(traces, mageres_probe_traces(st, probe, pie_unit)[1])
    return traces
end

"""
    mageres_material_legend_height()

    Height [px] of the material legend drawn below the map.
"""
mageres_material_legend_height() =
    MAGERES_LEGEND_TOP_PX + length(MAGERES_MATERIAL_CLASS_COLORS) * MAGERES_LEGEND_ROW_PX

"""
    mageres_add_material_legend!(layout, plot_height::Real)

    Add to `layout` one row per material class below the map: a box in the class colour and, to its right, the class
    number and description. `plot_height` is the height [px] of the plotting area.
"""
function mageres_add_material_legend!(layout, plot_height::Real)
    shapes = Any[]
    notes  = Any[]
    for (k, col) in enumerate(MAGERES_MATERIAL_CLASS_COLORS)
        yc = -(MAGERES_LEGEND_TOP_PX + (k - 0.5) * MAGERES_LEGEND_ROW_PX) / plot_height
        push!(shapes, attr(type       = "rect",
                           name       = "Material_legend",
                           xref       = "paper",
                           yref       = "paper",
                           xsizemode  = "pixel",
                           ysizemode  = "pixel",
                           xanchor    = 0,
                           yanchor    = yc,
                           x0         = 0,
                           x1         = 22,
                           y0         = -7,
                           y1         = 7,
                           fillcolor  = col,
                           line       = attr(color = "rgb(90,90,90)", width = 0.5)))
        push!(notes, attr(text      = "$(k - 1) — $(MAGERES_MATERIAL_CLASS_NAMES[k])",
                          name      = "Material_legend",
                          xref      = "paper",
                          yref      = "paper",
                          x         = 0,
                          y         = yc,
                          xshift    = 30,
                          xanchor   = "left",
                          yanchor   = "middle",
                          showarrow = false,
                          align     = "left",
                          font      = attr(size = 12)))
    end
    layout[:shapes]      = shapes
    layout[:annotations] = vcat(Any[a for a in get(layout.fields, :annotations, Any[])], notes)
    return layout
end

"""
    mageres_layout(st::MAGEResState; height = 760, title = @sprintf("t = %.0f yr", st.t), probe = nothing, pie_unit = 1,
                   pie_index = nothing)

    Layout of the reservoir figure: map and log axes, title and, with `probe`, the cell info annotation and
    mol% / wt% / vol% buttons restyling the pie trace at index `pie_index`.
"""
function mageres_layout(st::MAGEResState; height::Int = 760, title::AbstractString = @sprintf("t = %.0f yr", st.t),
                        probe = nothing, pie_unit::Int = 1, pie_index = nothing, bottom_extra::Int = 0)
    xa, xb, ya, yb = mageres_view_box(st)
    total          = max(mageres_column_area(st.source), mageres_column_area(st.pluton)) / 1e6
    axis           = (showline = true, linecolor = "black", mirror = true, zeroline = false, ticks = "outside",
                      ticklen = 4)
    x1 = attr(; title     = attr(text = "Lateral distance (km)", standoff = 4),
                range     = [xa / 1e3, xb / 1e3],
                anchor    = "y",
                axis...)
    y1 = attr(; title       = attr(text = "Depth (km)", standoff = 4),
                domain      = MAGERES_MAP_DOMAIN,
                scaleanchor = "x",
                scaleratio  = 1,
                range       = [mageres_depth_km(st, ya), mageres_depth_km(st, yb)],
                axis...)
    x2 = attr(; title  = attr(text = "Cumulative area (km²)", standoff = 2),
                anchor = "y2",
                domain = MAGERES_LOG_XDOMAIN,
                range  = [0, total > 0 ? 1.02 * total : 1.0],
                axis...)
    y2 = attr(; domain     = MAGERES_LOG_DOMAIN,
                range      = [-0.6, 1.6],
                tickvals   = [0, 1],
                ticktext   = ["Erupted", "Injected"],
                fixedrange = true,
                anchor     = "x2",
                axis...)
    layout = Layout(; height       = height,
                      showlegend   = false,
                      hovermode    = "closest",
                      title        = attr(text = title, y = 0.995, yanchor = "top", font = attr(size = 15)),
                      xaxis        = x1,
                      yaxis        = y1,
                      xaxis2       = x2,
                      yaxis2       = y2,
                      plot_bgcolor = "white",
                      margin       = attr(l = 60, r = 90, t = 36, b = 44 + bottom_extra))
    if probe !== nothing
        _, head, sets = mageres_probe_traces(st, probe, pie_unit)
        layout[:annotations] = [attr(text      = head,
                                     xref      = "paper",
                                     yref      = "paper",
                                     x         = MAGERES_INFO_X,
                                     y         = MAGERES_LOG_DOMAIN[2],
                                     xanchor   = "left",
                                     yanchor   = "top",
                                     showarrow = false,
                                     align     = "left",
                                     font      = attr(size = 12))]
        if sets !== nothing && pie_index !== nothing
            buttons = [attr(label  = MAGERES_PIE_UNITS[u],
                            method = "restyle",
                            args   = [Dict("values" => [sets[u]], "title.text" => MAGERES_PIE_UNITS[u]), [pie_index]])
                       for u in 1:3]
            layout[:updatemenus] = [attr(type        = "buttons",
                                         direction   = "left",
                                         showactive  = true,
                                         active      = clamp(pie_unit, 1, 3) - 1,
                                         buttons     = buttons,
                                         x           = MAGERES_INFO_X,
                                         y           = MAGERES_LOG_DOMAIN[1] + 0.005,
                                         xanchor     = "left",
                                         yanchor     = "bottom",
                                         pad         = attr(l = 0, r = 2, t = 0, b = 0),
                                         font        = attr(size = 11),
                                         bgcolor     = "white",
                                         bordercolor = "rgb(180,180,180)")]
        end
    end
    return layout
end

"""
    mageres_plot_state(st::MAGEResState; height = 900, title = @sprintf("t = %.0f yr", st.t), kwargs...)

    PlotlyJS plot of `st`; `kwargs` are passed to `mageres_traces`.
"""
mageres_plot_state(st::MAGEResState; height::Int = 900, title = @sprintf("t = %.0f yr", st.t), kwargs...) =
    PlotlyJS.plot(mageres_traces(st; kwargs...), mageres_layout(st; height = height, title = title))

const MAGERES_KALEIDO_LOCK = ReentrantLock()

"""
    mageres_kaleido_savefig(fig, path; kwargs...)

    `PlotlyJS.savefig(fig, path; kwargs...)` holding `MAGERES_KALEIDO_LOCK`, so that one figure at a time goes through
    the shared Kaleido process. Returns `path`.
"""
mageres_kaleido_savefig(fig, path::AbstractString; kwargs...) =
    lock(() -> PlotlyJS.savefig(fig, path; kwargs...), MAGERES_KALEIDO_LOCK)

"""
    mageres_save_figure(path, st::MAGEResState; refresh = 0, width = 1400, height = 1000, kwargs...)

    Write the figure of `st` to `path` (HTML or image, by extension) through a temporary file; an HTML file
    reloads every `refresh` s when `refresh > 0`. Returns `path`.
"""
function mageres_save_figure(path::AbstractString, st::MAGEResState; refresh::Real = 0, width::Int = 1400,
                             height::Int = 1000, kwargs...)
    fig = mageres_plot_state(st; height = height, kwargs...)
    tmp = path * ".tmp" * splitext(path)[2]
    if endswith(lowercase(path), ".html")
        PlotlyJS.savefig(fig, tmp)
        if refresh > 0
            html = read(tmp, String)
            write(tmp, replace(html, "<head>" => "<head><meta http-equiv=\"refresh\" content=\"$(refresh)\">";
                               count = 1))
        end
    else
        mageres_kaleido_savefig(fig, tmp; width = width, height = height)
    end
    mv(tmp, path; force = true)
    return path
end

"""
    mageres_write_frame_viewer(path, frames::Vector{String}, labels::Vector{String})

    Write to `path` an HTML page with a slider / play viewer over the image files `frames`, captioned by
    `labels`. Returns `path`.
"""
function mageres_write_frame_viewer(path::AbstractString, frames::Vector{String}, labels::Vector{String})
    fl   = join(("\"" * f * "\"" for f in frames), ",")
    ll   = join(("\"" * replace(l, "\"" => "'") * "\"" for l in labels), ",")
    html = """
    <!doctype html>
    <html><head><meta charset="utf-8"><title>Quad MAGERes evolution</title>
    <style>
    body{font-family:-apple-system,Helvetica,Arial,sans-serif;margin:16px;background:#fff;color:#222}
    .bar{display:flex;gap:12px;align-items:center;margin-bottom:10px;flex-wrap:wrap}
    input[type=range]{flex:1;min-width:200px}
    button{font-size:15px;padding:4px 12px}
    img{max-width:100%;height:auto;border:1px solid #ddd}
    </style></head><body>
    <div class="bar"><button id="prev">&#9664;</button><button id="play">Play</button><button id="next">&#9654;</button>
    <input id="s" type="range" min="0" max="$(length(frames) - 1)" value="0"><span id="l"></span></div>
    <img id="im" src="$(isempty(frames) ? "" : frames[1])">
    <script>
    const F=[$fl], L=[$ll]; const s=document.getElementById('s'), im=document.getElementById('im'), l=document.getElementById('l');
    let timer=null;
    function show(i){i=Math.max(0,Math.min(F.length-1,i)); s.value=i; im.src=F[i]; l.textContent=(i+1)+'/'+F.length+'  '+L[i];}
    s.oninput=()=>show(+s.value);
    document.getElementById('prev').onclick=()=>show(+s.value-1);
    document.getElementById('next').onclick=()=>show(+s.value+1);
    document.getElementById('play').onclick=function(){ if(timer){clearInterval(timer);timer=null;this.textContent='Play';return;}
      this.textContent='Pause'; timer=setInterval(()=>{ if(+s.value>=F.length-1){clearInterval(timer);timer=null;document.getElementById('play').textContent='Play';return;} show(+s.value+1);},400);};
    document.onkeydown=e=>{ if(e.key==='ArrowRight')show(+s.value+1); if(e.key==='ArrowLeft')show(+s.value-1); };
    F.forEach(f=>{const x=new Image(); x.src=f;});
    show(0);
    </script></body></html>
    """
    write(path, html)
    return path
end
