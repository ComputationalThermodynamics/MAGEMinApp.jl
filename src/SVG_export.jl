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
    SVGCanvas

    A canvas of `width` x `height` user units with a plot rectangle inset by the
    margins `ml`/`mr`/`mt`/`mb`, mapping the data window `xmin..xmax` x
    `ymin..ymax` onto it (y up). Own layout, independent of Plotly's automargin:
    the SVG is a separate rendering meant to be edited, not a pixel copy of the
    screen figure. `xlog`/`ylog` (default `false`, so every existing 10-argument
    call site is unaffected) map that axis through `log10` instead - `xmin`/`xmax`
    (`ymin`/`ymax`) are then the data bounds themselves, not their logs.
"""
struct SVGCanvas
    width  :: Float64
    height :: Float64
    ml     :: Float64
    mr     :: Float64
    mt     :: Float64
    mb     :: Float64
    xmin   :: Float64
    xmax   :: Float64
    ymin   :: Float64
    ymax   :: Float64
    xlog   :: Bool
    ylog   :: Bool
end
SVGCanvas(width, height, ml, mr, mt, mb, xmin, xmax, ymin, ymax) =
    SVGCanvas(width, height, ml, mr, mt, mb, xmin, xmax, ymin, ymax, false, false)

svg_plot_width(c::SVGCanvas)  = c.width  - c.ml - c.mr
svg_plot_height(c::SVGCanvas) = c.height - c.mt - c.mb
svg_frac(v::Real, lo::Real, hi::Real, log::Bool) =
    log ? (log10(max(v, 1e-300)) - log10(max(lo, 1e-300))) / (log10(max(hi, 1e-300)) - log10(max(lo, 1e-300))) :
          (v - lo) / (hi - lo)
svg_x(c::SVGCanvas, x::Real)  = c.ml + svg_frac(x, c.xmin, c.xmax, c.xlog) * svg_plot_width(c)
svg_y(c::SVGCanvas, y::Real)  = c.mt + (1 - svg_frac(y, c.ymin, c.ymax, c.ylog)) * svg_plot_height(c)

"""
    svg_num(v)

    `v` with at most two decimals and no trailing zeros ("12", "0.5", never "-0").
"""
function svg_num(v::Real)
    s = @sprintf("%.2f", v)
    s = rstrip(rstrip(s, '0'), '.')
    return (s == "-0" || isempty(s)) ? "0" : s
end

"""
    svg_escape(s)

    `s` with the XML special characters escaped.
"""
function svg_escape(s::AbstractString)
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    return s
end

"""
    svg_id(seen, base)

    `base` as a valid, unique XML id: characters outside `[A-Za-z0-9_-]` become
    `_`, a leading digit gets a `_` in front, and a repeat gets a numeric suffix.
    `seen` is the set of ids already handed out; the result is added to it.
"""
function svg_id(seen::Set{String}, base::AbstractString)
    id = replace(String(base), r"[^A-Za-z0-9_-]" => "_")
    (isempty(id) || !isletter(first(id)) && first(id) != '_') && (id = "_" * id)
    cand = id
    k    = 1
    while cand in seen
        k += 1
        cand = "$(id)_$(k)"
    end
    push!(seen, cand)
    return cand
end

"""
    svg_dasharray(dash, width)

    The SVG `stroke-dasharray` for a Plotly dash name (`nothing` for solid),
    scaled with the line `width` the way Plotly does so a heavier line keeps the
    same look.
"""
function svg_dasharray(dash, width::Real)
    w = max(width, 1.0)
    d = dash === nothing ? "solid" : string(dash)
    d == "dot"         && return "$(svg_num(w)) $(svg_num(2w))"
    d == "dash"        && return "$(svg_num(4w)) $(svg_num(2w))"
    d == "longdash"    && return "$(svg_num(7w)) $(svg_num(3w))"
    d == "dashdot"     && return "$(svg_num(4w)) $(svg_num(2w)) $(svg_num(w)) $(svg_num(2w))"
    d == "longdashdot" && return "$(svg_num(7w)) $(svg_num(3w)) $(svg_num(w)) $(svg_num(3w))"
    return nothing
end

"""
    svg_split_polylines(x, y)

    Split parallel vectors `x`, `y` at every `nothing`/`missing`/non-finite entry
    into separate polylines (vectors of `(x, y)` tuples); polylines with fewer
    than two points are dropped.
"""
function svg_split_polylines(x::AbstractVector, y::AbstractVector)
    lines = Vector{Vector{Tuple{Float64,Float64}}}()
    cur   = Tuple{Float64,Float64}[]
    for (a, b) in zip(x, y)
        if a isa Real && b isa Real && isfinite(a) && isfinite(b)
            push!(cur, (Float64(a), Float64(b)))
        else
            length(cur) > 1 && push!(lines, cur)
            cur = Tuple{Float64,Float64}[]
        end
    end
    length(cur) > 1 && push!(lines, cur)
    return lines
end

"""
    svg_clip_segment(p, q, xmin, xmax, ymin, ymax)

    Liang-Barsky clip of the segment `p -> q` against the rectangle; `nothing` if
    it lies entirely outside, otherwise the clipped end points.
"""
function svg_clip_segment(p::Tuple{Float64,Float64}, q::Tuple{Float64,Float64}, xmin, xmax, ymin, ymax)
    dx, dy = q[1] - p[1], q[2] - p[2]
    t0, t1 = 0.0, 1.0
    for (pk, qk) in ((-dx, p[1] - xmin), (dx, xmax - p[1]), (-dy, p[2] - ymin), (dy, ymax - p[2]))
        if pk == 0
            qk < 0 && return nothing
        else
            r = qk / pk
            if pk < 0
                r > t1 && return nothing
                t0 = max(t0, r)
            else
                r < t0 && return nothing
                t1 = min(t1, r)
            end
        end
    end
    return (p[1] + t0 * dx, p[2] + t0 * dy), (p[1] + t1 * dx, p[2] + t1 * dy)
end

"""
    svg_clip_polyline(line, xmin, xmax, ymin, ymax)

    `line` (a vector of `(x, y)` tuples) clipped to the data rectangle, as a vector
    of polylines: it is cut wherever it leaves the rectangle and resumes where it
    re-enters. This replaces a `<clipPath>`, so the file needs no clipping
    construct at all.
"""
function svg_clip_polyline(line::Vector{Tuple{Float64,Float64}}, xmin, xmax, ymin, ymax)
    out = Vector{Vector{Tuple{Float64,Float64}}}()
    cur = Tuple{Float64,Float64}[]
    for k in 1:length(line)-1
        seg = svg_clip_segment(line[k], line[k+1], xmin, xmax, ymin, ymax)
        if seg === nothing
            length(cur) > 1 && push!(out, cur)
            cur = Tuple{Float64,Float64}[]
            continue
        end
        a, b = seg
        if isempty(cur)
            push!(cur, a)
        elseif cur[end] != a
            length(cur) > 1 && push!(out, cur)
            cur = Tuple{Float64,Float64}[a]
        end
        push!(cur, b)
    end
    length(cur) > 1 && push!(out, cur)
    return out
end

"""
    svg_path_data(c, polylines)

    The `d` attribute for `polylines` (data coordinates), mapped through the
    canvas `c`: one `M ... L ...` subpath per polyline, straight segments only.
"""
function svg_path_data(c::SVGCanvas, polylines::Vector{Vector{Tuple{Float64,Float64}}})
    io = IOBuffer()
    for pl in polylines
        for (k, (x, y)) in enumerate(pl)
            print(io, k == 1 ? "M" : "L", svg_num(svg_x(c, x)), " ", svg_num(svg_y(c, y)), " ")
        end
    end
    return strip(String(take!(io)))
end

"""
    svg_open(io, c)

    Write the XML header and the opening `<svg>` tag (`viewBox` equal to the
    canvas size, `width`/`height` in the same units; `xlink` also declares the
    `xlink` namespace, needed by an embedded `<image>`). Nothing else is written
    before the first layer: no `<defs>`, styles or metadata.
"""
function svg_open(io::IO, c::SVGCanvas; xlink::Bool = false)
    println(io, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    ns = xlink ? "xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"" : "xmlns=\"http://www.w3.org/2000/svg\""
    println(io, "<svg ", ns, " version=\"1.1\" width=\"$(svg_num(c.width))\" height=\"$(svg_num(c.height))\" viewBox=\"0 0 $(svg_num(c.width)) $(svg_num(c.height))\">")
end

svg_close(io::IO) = println(io, "</svg>")

"""
    svg_group_open(io, id; stroke, width, dash, fill, opacity, rounded, font_size, font_family, anchor)

    Open a `<g id="...">` layer. The stroke/fill/font properties go on the group
    (not on every element), so an editor sees the shared style once and "select
    same stroke" works across its children. Only the properties given are
    written.
"""
function svg_group_open(io::IO, id::AbstractString; stroke = nothing, width = nothing, dash = nothing,
                         fill = nothing, opacity = nothing, rounded = false, font_size = nothing, font_family = nothing, anchor = nothing)
    attrs = String["id=\"$(svg_escape(id))\""]
    fill    === nothing || push!(attrs, "fill=\"$(fill)\"")
    stroke  === nothing || push!(attrs, "stroke=\"$(stroke)\"")
    width   === nothing || push!(attrs, "stroke-width=\"$(svg_num(width))\"")
    dash    === nothing || push!(attrs, "stroke-dasharray=\"$(dash)\"")
    opacity === nothing || push!(attrs, "opacity=\"$(svg_num(opacity))\"")
    rounded && push!(attrs, "stroke-linecap=\"round\" stroke-linejoin=\"round\"")
    font_family === nothing || push!(attrs, "font-family=\"$(font_family)\"")
    font_size   === nothing || push!(attrs, "font-size=\"$(svg_num(font_size))\"")
    anchor      === nothing || push!(attrs, "text-anchor=\"$(anchor)\"")
    println(io, "<g ", join(attrs, " "), ">")
end

svg_group_close(io::IO) = println(io, "</g>")

"""
    svg_path(io, id, d; stroke, width, dash, fill, fill_opacity)

    One `<path>` with the given `d`. `stroke`/`width`/`dash`/`fill`/`fill_opacity`
    are written only when given, i.e. when this path differs from its group's style
    (a group's own `fill`/`stroke` otherwise apply, see [`svg_group_open`](@ref)).
"""
function svg_path(io::IO, id::AbstractString, d::AbstractString; stroke = nothing, width = nothing, dash = nothing,
                   fill = nothing, fill_opacity = nothing)
    attrs = String["id=\"$(svg_escape(id))\""]
    stroke       === nothing || push!(attrs, "stroke=\"$(stroke)\"")
    width        === nothing || push!(attrs, "stroke-width=\"$(svg_num(width))\"")
    dash         === nothing || push!(attrs, "stroke-dasharray=\"$(dash)\"")
    fill         === nothing || push!(attrs, "fill=\"$(fill)\"")
    fill_opacity === nothing || push!(attrs, "fill-opacity=\"$(svg_num(fill_opacity))\"")
    push!(attrs, "d=\"$(d)\"")
    println(io, "<path ", join(attrs, " "), "/>")
end

"""
    svg_line(io, x1, y1, x2, y2)

    A `<line>` in canvas units, styled by its group.
"""
svg_line(io::IO, x1, y1, x2, y2) =
    println(io, "<line x1=\"$(svg_num(x1))\" y1=\"$(svg_num(y1))\" x2=\"$(svg_num(x2))\" y2=\"$(svg_num(y2))\"/>")

"""
    svg_rect(io, id, x, y, w, h)

    A `<rect>` in canvas units, styled by its group (`fill` "none" there for an
    outline).
"""
svg_rect(io::IO, id::AbstractString, x, y, w, h) =
    println(io, "<rect id=\"$(svg_escape(id))\" x=\"$(svg_num(x))\" y=\"$(svg_num(y))\" width=\"$(svg_num(w))\" height=\"$(svg_num(h))\"/>")

"""
    svg_polygon(io, points, fill)

    A small filled polygon in canvas units (used for arrow heads).
"""
function svg_polygon(io::IO, points, fill::AbstractString)
    pts = join(["$(svg_num(x)),$(svg_num(y))" for (x, y) in points], " ")
    println(io, "<polygon points=\"$(pts)\" fill=\"$(fill)\" stroke=\"none\"/>")
end

"""
    svg_text_runs(text)

    Plotly-style inline markup as text lines, each a vector of `(content, dy, scale)`
    runs: `<br>` starts a new line, `<sub>`/`<sup>` shift and shrink their content
    (`dy` in em, `scale` relative), and any other tag is dropped. Trailing empty
    lines (a text ending in `<br>`) are dropped so they cannot shift centred text;
    leading and interior ones are kept, they are real blank lines.
"""
function svg_text_runs(text::AbstractString)
    lines = Vector{Vector{Tuple{String,Float64,Float64}}}()
    for raw in split(text, r"<br\s*/?>", keepempty = true)
        runs  = Tuple{String,Float64,Float64}[]
        dy    = 0.0
        scale = 1.0
        last  = 1
        for m in eachmatch(r"<(/?)(sub|sup|[a-z]+)[^>]*>", raw)
            m.offset > last && push!(runs, (String(raw[last:m.offset-1]), dy, scale))
            closing, tag = m.captures[1] == "/", m.captures[2]
            if tag == "sub"
                dy, scale = closing ? (0.0, 1.0) : (0.25, 0.7)
            elseif tag == "sup"
                dy, scale = closing ? (0.0, 1.0) : (-0.4, 0.7)
            end
            last = m.offset + ncodeunits(m.match)
        end
        last <= lastindex(raw) && push!(runs, (String(raw[last:end]), dy, scale))
        push!(lines, runs)
    end
    while length(lines) > 1 && isempty(lines[end])
        pop!(lines)
    end
    return lines
end

"""
    svg_text(io, x, y, text; id, size, anchor, fill, weight, rotate, line_height)

    A real `<text>` element (never outlined) at canvas position `(x, y)`, vertically
    centred on `y` (by an explicit offset, not `dominant-baseline`, which
    Illustrator ignores). Multi-line and sub/superscript markup become `<tspan>`s. The
    only transform ever written is `rotate(-90)` about `(x, y)`, for the y-axis
    title. `size`, `anchor` and `fill` are omitted when they equal `nothing`, so
    the enclosing layer's values apply. An empty line keeps its height (it is
    written as a non-breaking space), so parallel text columns stay aligned.
    `rotate` is `false`, `true` (-90 degrees) or
    an angle in degrees; `top` anchors the first line's top at `y` instead of
    centring the block on it.
"""
function svg_text(io::IO, x, y, text::AbstractString; id = nothing, size = nothing, anchor = nothing, fill = nothing,
                   weight = nothing, rotate = false, line_height = 1.15, top = false)
    lines = svg_text_runs(text)
    n     = length(lines)
    fs    = size === nothing ? 10.0 : Float64(size)
    attrs = String[]
    id     === nothing || push!(attrs, "id=\"$(svg_escape(id))\"")
    push!(attrs, "x=\"$(svg_num(x))\"", "y=\"$(svg_num(y))\"")
    size   === nothing || push!(attrs, "font-size=\"$(svg_num(size))\"")
    anchor === nothing || push!(attrs, "text-anchor=\"$(anchor)\"")
    fill   === nothing || push!(attrs, "fill=\"$(fill)\"")
    weight === nothing || push!(attrs, "font-weight=\"$(weight)\"")
    rotate === false || push!(attrs, "transform=\"rotate($(svg_num(rotate === true ? -90 : rotate)) $(svg_num(x)) $(svg_num(y)))\"")
    print(io, "<text ", join(attrs, " "), ">")
    for (i, runs) in enumerate(lines)
        line_dy = i == 1 ? (top ? 0.8 : -(n - 1) * line_height / 2 + 0.35) : line_height
        prev    = 0.0
        isempty(runs) && (runs = [("\u00a0", 0.0, 1.0)])
        for (j, (content, dy, scale)) in enumerate(runs)
            a = String[]
            if j == 1
                push!(a, "x=\"$(svg_num(x))\"")
                push!(a, "dy=\"$(svg_num(line_dy + dy - prev))em\"")
            elseif dy != prev
                push!(a, "dy=\"$(svg_num(dy - prev))em\"")
            end
            prev = dy
            scale == 1.0 || push!(a, "font-size=\"$(svg_num(fs * scale))\"")
            print(io, "<tspan ", join(a, " "), ">", svg_escape(content), "</tspan>")
        end
    end
    println(io, "</text>")
end

"""
    svg_tick_label(v)

    A tick value as text without floating-point noise or a trailing ".0"
    (`10.4`, `550`, never `10.400000000000001` or `550.0`).
"""
function svg_tick_label(v::Real)
    r = round(Float64(v), digits = 3)
    return isinteger(r) ? string(Int(r)) : string(r)
end

"""
    svg_layout_layers(io, c, seen; xticks, yticks, xtitle, ytitle, title,
                       font = "Helvetica, Arial, sans-serif", ink = "#333333")

    The `Layout` layer of a figure: `Outline` (frame rectangle), `Ticks` (marks on
    all four sides at `xticks`/`yticks`, data values), `Tick_labels` (bottom and
    left), `Axis_titles` (the y title rotated -90) and `Title`. Shared by every
    exporter so all of them have the same frame and tick styling.
"""
function svg_layout_layers(io::IO, c::SVGCanvas, seen::Set{String}; xticks, yticks, xtitle::AbstractString,
                            ytitle::AbstractString, title::AbstractString,
                            font::AbstractString = "Helvetica, Arial, sans-serif", ink::AbstractString = "#333333",
                            xticklabels = nothing, yticklabels = nothing, xtick_angle::Real = 0)
    pw, ph = svg_plot_width(c), svg_plot_height(c)
    left, right, top, bottom = c.ml, c.ml + pw, c.mt, c.mt + ph
    tl = 4.0
    xlab(k, v) = xticklabels === nothing ? svg_tick_label(v) : String(xticklabels[k])
    ylab(k, v) = yticklabels === nothing ? svg_tick_label(v) : String(yticklabels[k])

    svg_group_open(io, svg_id(seen, "Layout"); font_family = font, font_size = 10, fill = ink)
    svg_group_open(io, svg_id(seen, "Outline"); stroke = ink, width = 1, fill = "none")
    svg_rect(io, svg_id(seen, "Outline_frame"), left, top, pw, ph)
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Ticks"); stroke = ink, width = 0.75)
    for v in xticks
        x = svg_x(c, v)
        svg_line(io, x, bottom, x, bottom + tl)
        svg_line(io, x, top, x, top - tl)
    end
    for v in yticks
        y = svg_y(c, v)
        svg_line(io, left, y, left - tl, y)
        svg_line(io, right, y, right + tl, y)
    end
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Tick_labels"); fill = ink)
    for (k, v) in enumerate(xticks)
        if xtick_angle == 0
            svg_text(io, svg_x(c, v), bottom + tl + 10, xlab(k, v); id = svg_id(seen, "Tick_x_$(k)"), anchor = "middle")
        else
            svg_text(io, svg_x(c, v), bottom + tl + 8, xlab(k, v); id = svg_id(seen, "Tick_x_$(k)"),
                     anchor = "end", rotate = xtick_angle)
        end
    end
    for (k, v) in enumerate(yticks)
        svg_text(io, left - tl - 4, svg_y(c, v), ylab(k, v); id = svg_id(seen, "Tick_y_$(k)"), anchor = "end")
    end
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Axis_titles"); fill = ink, font_size = 12, anchor = "middle")
    isempty(xtitle) || svg_text(io, (left + right) / 2, bottom + (xtick_angle == 0 ? 40 : 56), xtitle; id = svg_id(seen, "Axis_title_x"))
    isempty(ytitle) || svg_text(io, left - 46, (top + bottom) / 2, ytitle; id = svg_id(seen, "Axis_title_y"), rotate = true)
    svg_group_close(io)

    if !isempty(title)
        svg_group_open(io, svg_id(seen, "Title"); fill = ink, font_size = 14, anchor = "middle")
        svg_text(io, (left + right) / 2, top / 2, title; id = svg_id(seen, "Figure_title"), weight = "bold")
        svg_group_close(io)
    end
    svg_group_close(io)
end

"""
    svg_circle(io, id, cx, cy, r; fill, stroke, width, opacity)

    A `<circle>` marker in canvas units. `fill = "none"` (with `stroke` set) draws an
    open marker (Plotly's `"circle-open"`).
"""
function svg_circle(io::IO, id::AbstractString, cx, cy, r; fill = nothing, stroke = nothing, width = nothing, opacity = nothing)
    attrs = String["id=\"$(svg_escape(id))\"", "cx=\"$(svg_num(cx))\"", "cy=\"$(svg_num(cy))\"", "r=\"$(svg_num(r))\""]
    fill    === nothing || push!(attrs, "fill=\"$(fill)\"")
    stroke  === nothing || push!(attrs, "stroke=\"$(stroke)\"")
    width   === nothing || push!(attrs, "stroke-width=\"$(svg_num(width))\"")
    # a whole-element `opacity`, not `fill-opacity` - a classification-diagram marker
    # has a solid outline (marker.line) as well as its coloured fill, and Plotly's own
    # per-marker/per-trace opacity fades the outline right along with the fill; using
    # `fill-opacity` here left every marker's black ring at full strength, the one part
    # of the marker that never got any less opaque, once the outline was itself opaque
    # black (every classification diagram's markers all set exactly that outline).
    opacity === nothing || push!(attrs, "opacity=\"$(svg_num(opacity))\"")
    println(io, "<circle ", join(attrs, " "), "/>")
end

"""
    svg_marker(io, id, cx, cy, r, symbol; fill, stroke, width, opacity)

    One data-point marker at canvas position `(cx, cy)`. Every symbol these figures
    use resolves to a circle: `"circle-open"` (or any name containing `"open"`) is
    unfilled with the given `stroke`; anything else, including Plotly's default
    (unset) symbol, is a filled circle. `r` is the marker radius in canvas units
    (Plotly's `marker.size` is a diameter in px; convert before calling).
"""
function svg_marker(io::IO, id::AbstractString, cx, cy, r, symbol; fill = nothing, stroke = nothing, width = nothing, opacity = nothing)
    if symbol !== nothing && occursin("open", lowercase(string(symbol)))
        svg_circle(io, id, cx, cy, r; fill = "none", stroke = something(fill, stroke), width = something(width, 1.0), opacity = opacity)
    else
        svg_circle(io, id, cx, cy, r; fill = fill, stroke = stroke, width = width, opacity = opacity)
    end
end

"""
    svg_area_band(c, xs, ytop, ybot)

    The `d` attribute of a closed polygon between two parallel series `ytop`/`ybot`
    over `xs` (a stacked-area band): along `ytop` left to right, back along `ybot`
    right to left, closed. Points where either boundary is `nothing`/non-finite are
    skipped (the band is drawn only where both are defined).
"""
function svg_area_band(c::SVGCanvas, xs::AbstractVector, ytop::AbstractVector, ybot::AbstractVector)
    keep = [xs[i] isa Real && ytop[i] isa Real && ybot[i] isa Real && isfinite(xs[i]) && isfinite(ytop[i]) && isfinite(ybot[i])
            for i in eachindex(xs)]
    any(keep) || return ""
    io = IOBuffer()
    first = true
    for i in eachindex(xs)
        keep[i] || continue
        print(io, first ? "M" : "L", svg_num(svg_x(c, xs[i])), " ", svg_num(svg_y(c, ytop[i])), " ")
        first = false
    end
    for i in reverse(eachindex(xs))
        keep[i] || continue
        print(io, "L", svg_num(svg_x(c, xs[i])), " ", svg_num(svg_y(c, ybot[i])), " ")
    end
    print(io, "Z")
    return strip(String(take!(io)))
end

"""
    svg_info_height(info; line_h = 11.5)

    Vertical room `info` needs below the plot (the tallest column's `<br>`-separated
    line count times `line_h`), `0.0` when `info` is empty - for sizing the canvas
    before drawing, the same way [`pd_export_svg`](@ref) always has.
"""
svg_info_height(info; line_h::Real = 11.5) =
    isempty(info) ? 0.0 : maximum(length(svg_text_runs(t)) for t in info) * line_h

"""
    svg_info_layer(io, seen, info; left, y, pw, font, ink, line_h = 11.5, id = "Info")

    The provenance text box under a plot: `info` (one multi-line, `<br>`-joined string
    per column - a phase-diagram-style box is `[labels, values]`, two columns) as real
    `<text>`, columns spaced `0.2 * pw` apart starting at `left`, top-anchored at `y`.
    Shared by every exporter that carries this kind of box via paper-anchored
    (`xref="paper"`) annotations, so it looks identical wherever it appears -
    `pd_export_svg` (phase diagram/trace elements) and `plotly_export_cartesian_svg`
    (PTX paths).
"""
function svg_info_layer(io::IO, seen::Set{String}, info; left::Real, y::Real, pw::Real,
                         font::AbstractString = "Helvetica, Arial, sans-serif", ink::AbstractString = "#333333",
                         line_h::Real = 11.5, id::AbstractString = "Info")
    isempty(info) && return
    svg_group_open(io, svg_id(seen, id); font_family = font, font_size = 10, fill = ink)
    for (k, t) in enumerate(info)
        svg_text(io, left + (k - 1) * 0.2 * pw, y, t; id = svg_id(seen, "$(id)_column_$(k)"), anchor = "start",
                  top = true, line_height = line_h / 10)
    end
    svg_group_close(io)
end

"""
    svg_legend_layer(io, seen, entries; x, y, title = nothing, id = "Legend",
                      font, ink, line_height = 17.0, box = false)

    A vertical legend at canvas position `(x, y)` (its top-left corner, already in
    canvas units - not data coordinates, so no `SVGCanvas` is needed): one row per
    entry of `(label, color, dash, width, marker)` - a short line swatch (dashed per
    `dash`/`width` when given) plus, when `marker` is not `nothing`, a small filled
    circle of that color in front of it - then the label. `title`, if given, is a bold
    line above the entries. `box`, when true, draws a light rounded border and
    background around the whole legend (the size-key boxes on the classification
    diagrams). Shared by every exporter so legends look the same across the app.
"""
function svg_legend_layer(io::IO, seen::Set{String}, entries; x::Real, y::Real, title = nothing,
                           id::AbstractString = "Legend", font::AbstractString = "Helvetica, Arial, sans-serif",
                           ink::AbstractString = "#333333", line_height::Real = 17.0, box::Bool = false,
                           horizontal::Bool = false, right_edge::Union{Nothing,Real} = nothing)
    isempty(entries) && title === nothing && return
    n = length(entries) + (title === nothing ? 0 : 1)
    entry_w(e) = length(e.label) * 6.0 + 26.0 + 18.0   # swatch + gap + text + trailing gap, same estimate as the box width below
    if horizontal
        # Plotly's `legend.orientation = "h"` (te-evol-ptx and similar): one row, not
        # stacked - and `right_edge` (from `legend.xanchor = "right"`) starts the row far
        # enough left that it ends there, instead of the fixed left-margin `x` every other
        # legend uses, which left this one sitting over the plot instead of past its edge.
        total = sum(entry_w, entries; init = 0.0)
        x = right_edge === nothing ? x : right_edge - total
    end
    if box
        h = n * line_height + 12.0
        w = maximum(length(e.label) for e in entries; init = 10) * 6.0 + 50.0
        svg_group_open(io, svg_id(seen, id * "_box"); stroke = "#cccccc", width = 1, fill = "#ffffff")
        svg_rect(io, svg_id(seen, id * "_box_rect"), x - 6, y - 6, w, h)
        svg_group_close(io)
    end
    svg_group_open(io, svg_id(seen, id); font_family = font, font_size = 10, fill = ink)
    yy = y
    if title !== nothing
        svg_text(io, x, yy, title; id = svg_id(seen, id * "_title"), anchor = "start", weight = "bold", top = true)
        yy += line_height
    end
    xx = x
    for e in entries
        cy = yy + 3.0
        ex = horizontal ? xx : x
        if e.marker !== nothing
            svg_circle(io, svg_id(seen, id * "_marker_" * e.label), ex + 8, cy, max(e.marker / 2, 2.0);
                       fill = "#888888", stroke = "#000000", width = 0.75)
        else
            # e.color is whatever the trace itself gave it - the draw loop's own line/marker
            # always goes through svg_css_color first (normalises "RGB(...)"/"rgba(...)" and
            # pulls out any alpha), but a legend swatch was writing that raw string straight
            # into `stroke`; get_jet_colormap's own colours are upper-case "RGB(...)", not
            # valid CSS syntax to every SVG reader, so the swatch line silently failed to
            # draw - correct on screen, invisible once opened elsewhere (Illustrator).
            ecol, ealpha = svg_css_color(e.color)
            svg_group_open(io, svg_id(seen, id * "_swatch_group_" * e.label); stroke = ecol,
                            width = something(e.width, 1.5), dash = svg_dasharray(e.dash, something(e.width, 1.5)),
                            opacity = ealpha)
            svg_line(io, ex, cy, ex + 16, cy)
            svg_group_close(io)
        end
        svg_text(io, ex + 22, cy, e.label; id = svg_id(seen, id * "_text_" * e.label), anchor = "start")
        if horizontal
            xx += entry_w(e)
        else
            yy += line_height
        end
    end
    svg_group_close(io)
end

"""
    svg_heatmap_png(prob; low = (255,255,255), high = (200,30,30), target_px = 1100)

    Rasterise a probability grid `prob` (`[iy, ix]`, rows = y increasing upward,
    values in [0, 1]) to PNG bytes, colored linearly from `low` at 0 to `high` at 1
    (the on-screen colorscale). Each cell is a block of `f x f` pixels (nearest
    neighbour, `f` even, about `target_px` across), so the cells stay crisp blocks
    when an editor scales the image. Plotly centres a cell on its node, so the
    outer cells reach half a spacing beyond the plot edge, where the axis clips
    them; with an even `f` they simply keep `f/2` pixels and the image covers
    exactly the plot rectangle, with no clipping needed. Exact zeros are fully
    transparent. Returns `(png_bytes, width_px, height_px)`; the top image row is
    the largest y.
"""
function svg_heatmap_png(prob::AbstractMatrix{<:Real}; low = (255, 255, 255), high = (200, 30, 30), target_px::Int = 1100)
    ny, nx = size(prob)
    f      = 2 * cld(target_px, 2 * max(nx, ny))
    W, H   = (nx - 1) * f, (ny - 1) * f
    img    = Matrix{RGBA{N0f8}}(undef, H, W)
    lerp(a, b, p) = clamp(round(Int, a + (b - a) * p), 0, 255) / 255
    for r in 1:H, c in 1:W
        i = floor(Int, (c - 0.5) / f + 0.5) + 1
        j = floor(Int, (ny - 1) - (r - 0.5) / f + 0.5) + 1
        p = clamp(Float64(prob[j, i]), 0.0, 1.0)
        img[r, c] = p <= 0 ? RGBA{N0f8}(0, 0, 0, 0) :
                    RGBA{N0f8}(lerp(low[1], high[1], p), lerp(low[2], high[2], p), lerp(low[3], high[3], p), 1)
    end
    path = tempname() * ".png"
    try
        Images.save(path, img)
        return read(path), W, H
    finally
        rm(path; force = true)
    end
end

"""
    svg_image(io, id, c, png)

    An `<image>` covering exactly the canvas's plot rectangle, with `png` (bytes)
    embedded as a base64 data URI. Uses `xlink:href` (older Illustrator does not
    read plain `href`; the file must be opened with `svg_open(...; xlink = true)`),
    `preserveAspectRatio="none"` and `image-rendering="pixelated"` so the cell
    blocks stay sharp.
"""
function svg_image(io::IO, id::AbstractString, c::SVGCanvas, png::AbstractVector{UInt8})
    println(io, "<image id=\"$(svg_escape(id))\" x=\"$(svg_num(c.ml))\" y=\"$(svg_num(c.mt))\" width=\"$(svg_num(svg_plot_width(c)))\" height=\"$(svg_num(svg_plot_height(c)))\" preserveAspectRatio=\"none\" image-rendering=\"pixelated\" xlink:href=\"data:image/png;base64,$(base64encode(png))\"/>")
end

"""
    svg_gradient_bar(io, id, x, y, w, h, low, high)

    A `w` x `h` bar at `(x, y)` filled with a vertical `<linearGradient>` from
    `low` (bottom) to `high` (top), the colors as `"rgb(r,g,b)"` strings. The one
    `<defs>` the exporters write: Illustrator imports a linear gradient as a
    native, editable gradient, which beats dozens of stacked rectangles.
"""
function svg_gradient_bar(io::IO, id::AbstractString, x, y, w, h, low::AbstractString, high::AbstractString)
    gid = id * "_gradient"
    println(io, "<defs><linearGradient id=\"$(svg_escape(gid))\" x1=\"0\" y1=\"1\" x2=\"0\" y2=\"0\"><stop offset=\"0\" stop-color=\"$(low)\"/><stop offset=\"1\" stop-color=\"$(high)\"/></linearGradient></defs>")
    println(io, "<rect id=\"$(svg_escape(id))\" x=\"$(svg_num(x))\" y=\"$(svg_num(y))\" width=\"$(svg_num(w))\" height=\"$(svg_num(h))\" fill=\"url(#$(svg_escape(gid)))\"/>")
end

"""
    svg_parse_color(str)

    `(r, g, b, a)` (channels 0-255, alpha 0-1) of a CSS color string as Plotly
    scales use them: `"rgb(r,g,b)"`, `"rgba(r,g,b,a)"` or `"#rrggbb"`.
"""
function svg_parse_color(str::AbstractString)
    s = strip(str)
    if startswith(s, "#") && length(s) >= 7
        return (parse(Int, s[2:3], base = 16) * 1.0, parse(Int, s[4:5], base = 16) * 1.0, parse(Int, s[6:7], base = 16) * 1.0, 1.0)
    end
    m = match(r"rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)"i, s)
    m === nothing && error("svg_parse_color: cannot read color \"$(str)\"")
    a = m.captures[4] === nothing ? 1.0 : parse(Float64, m.captures[4])
    return (parse(Float64, m.captures[1]), parse(Float64, m.captures[2]), parse(Float64, m.captures[3]), a)
end

"""
    svg_css_color(str; default = "#000000")

    `str` (any Plotly trace/marker color: `"rgb(...)"`/`"rgba(...)"` in either case,
    `"#rrggbb"`, a CSS name like `"steelblue"`, or `nothing`) as `(color, opacity)` for
    SVG `fill`/`stroke` + `fill-opacity`/`stroke-opacity`: an `rgba(...)` with alpha
    below 1 is split into an opaque `rgb(...)` plus that opacity (SVG1.1 `<paint>` has
    no alpha channel of its own); anything else - hex or a CSS name, which SVG already
    understands - passes through unchanged with `opacity = nothing`.
"""
function svg_css_color(str; default::AbstractString = "#000000")
    str === nothing && return (default, nothing)
    s = strip(String(str))
    isempty(s) && return (default, nothing)
    m = match(r"rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)"i, s)
    m === nothing && return (s, nothing)
    r, g, b = round(Int, parse(Float64, m.captures[1])), round(Int, parse(Float64, m.captures[2])), round(Int, parse(Float64, m.captures[3]))
    a = m.captures[4] === nothing ? 1.0 : parse(Float64, m.captures[4])
    return ("rgb($r,$g,$b)", a >= 1.0 ? nothing : a)
end

"""
    svg_colorscale(colorm; reverse = false)

    The stops `[(t, (r, g, b, a))]` (t in [0, 1] ascending, channels 0-255, alpha
    0-1) of a Plotly colorscale in any of the four forms the app passes: a color
    scheme or vector of `Colorant`s with 0-1 channels (evenly spaced,
    `colors[Symbol(name)]`), a colormap name (resolved like the app does: the
    custom colormaps, else the color schemes), a vector of `[fraction, "rgb(...)"]`
    stops (restricted ranges, the custom colormaps, `set_min_to_white`, which
    carries an `rgba(...)` transparent end), or a flat `Vector{String}` of colors
    with no explicit fraction, evenly spaced (`get_jet_colormap`'s own shape - every
    classification diagram's marker colorscale takes this form, not any of the
    other three). `reverse` flips the scale the way Plotly's `reversescale` does.
"""
function svg_colorscale(colorm; reverse::Bool = false)
    if colorm isa AbstractString
        # a bare name here (not a custom Tamblyn map) is one of Plotly's OWN built-in
        # colorscales, resolved client-side by Plotly.js itself, not by Julia at all - so
        # PLOTLYJS_COLORSCALES (Plotly.js's real stop table for that name) is what actually
        # matches the screen; colors[Symbol(...)] (ColorSchemes.jl) is a different, only
        # similarly-named implementation, and was silently giving a same-named but visibly
        # different gradient for every classification diagram using a non-"jet" colormap
        # (get_jet_colormap, used elsewhere in the app, is its own third, still different,
        # hand-coded "jet" and is unaffected - only a bare dropdown-selected name hits this).
        colorm = if haskey(custom_colormaps, colorm)
            get_custom_colorscale(String(colorm), [1, 9])
        elseif haskey(PLOTLYJS_COLORSCALES, lowercase(String(colorm)))
            PLOTLYJS_COLORSCALES[lowercase(String(colorm))]
        else
            colors[Symbol(colorm)]
        end
    end
    n = length(colorm)
    stops = Tuple{Float64,NTuple{4,Float64}}[]
    if first(colorm) isa AbstractVector
        for st in colorm
            push!(stops, (Float64(st[1]), svg_parse_color(string(st[2]))))
        end
    elseif first(colorm) isa AbstractString
        # a flat Vector{String} of colors, evenly spaced with no explicit fraction -
        # get_jet_colormap's own form, what every classification diagram's marker
        # colorscale (get_TAS_phase_diagram, get_AFM_phase_diagram, every mineral
        # panel) actually sends; caught only by testing against a real, app-computed
        # figure rather than a hand-built one, since none of the app's other colour
        # scales take this particular shape
        for (i, col) in enumerate(colorm)
            push!(stops, ((i - 1) / max(n - 1, 1), svg_parse_color(String(col))))
        end
    else
        for (i, c) in enumerate(colorm)
            push!(stops, ((i - 1) / max(n - 1, 1), (255.0 * c.r, 255.0 * c.g, 255.0 * c.b, 1.0)))
        end
    end
    reverse && (stops = [(1.0 - t, c) for (t, c) in Base.reverse(stops)])
    return stops
end

"""
    svg_color_at(stops, t)

    The color at position `t` in [0, 1] of `stops` ([`svg_colorscale`](@ref)),
    linearly interpolated per channel (alpha too), clamped at the ends.
"""
function svg_color_at(stops, t::Real)
    t <= stops[1][1]   && return stops[1][2]
    t >= stops[end][1] && return stops[end][2]
    k = searchsortedlast([s[1] for s in stops], t)
    (t0, c0), (t1, c1) = stops[k], stops[k+1]
    w = t1 == t0 ? 0.0 : (t - t0) / (t1 - t0)
    return ntuple(i -> c0[i] + (c1[i] - c0[i]) * w, 4)
end

"""
    svg_fill_gaps(field)

    `field` with its `missing`/non-finite nodes filled, like Plotly's `connectgaps`:
    repeatedly, every gap node that has defined 4-neighbours takes their mean, until
    none is left (a field with no defined node at all is returned unchanged).
"""
function svg_fill_gaps(field::AbstractMatrix)
    nx, ny = size(field)
    F      = Matrix{Union{Float64,Missing}}(undef, nx, ny)
    for i in eachindex(F)
        v = field[i]
        F[i] = (v === missing || (v isa Real && !isfinite(v))) ? missing : Float64(v)
    end
    all(ismissing, F) && return F
    while any(ismissing, F)
        G = copy(F)
        for j in 1:ny, i in 1:nx
            ismissing(F[i, j]) || continue
            acc, cnt = 0.0, 0
            for (di, dj) in ((1, 0), (-1, 0), (0, 1), (0, -1))
                ii, jj = i + di, j + dj
                (1 <= ii <= nx && 1 <= jj <= ny && !ismissing(F[ii, jj])) || continue
                acc += F[ii, jj]; cnt += 1
            end
            cnt > 0 && (G[i, j] = acc / cnt)
        end
        F = G
    end
    return F
end

"""
    svg_field_png(field, zmin, zmax, stops; smooth = false, target_px = 1100)

    Rasterise a scalar `field` (`[ix, iy]`, `Union{Float64,Missing}`) to PNG bytes
    with the colorscale `stops` over `zmin..zmax`, like the on-screen heatmap. Same
    geometry as [`svg_heatmap_png`](@ref): blocks of an even `f` pixels centred on
    the nodes, the outer cells keeping `f/2`, so the image covers exactly the plot
    rectangle; the top image row is the largest y. `smooth = false` gives crisp
    cell blocks, `true` bilinear interpolation between nodes (Plotly's `zsmooth`).
    Gaps (`missing` nodes, which the AMR mesh can leave uncovered) are filled first
    ([`svg_fill_gaps`](@ref)), as the on-screen heatmap's `connectgaps` does.
    Returns `(png_bytes, width_px, height_px)`.
"""
function svg_field_png(field::AbstractMatrix, zmin::Real, zmax::Real, stops; smooth::Bool = false, target_px::Int = 1100)
    field  = svg_fill_gaps(field)
    nx, ny = size(field)
    f      = 2 * cld(target_px, 2 * max(nx, ny))
    W, H   = (nx - 1) * f, (ny - 1) * f
    img    = Matrix{RGBA{N0f8}}(undef, H, W)
    span   = zmax == zmin ? 1.0 : Float64(zmax - zmin)
    rgba(v) = begin
        c = svg_color_at(stops, clamp((v - zmin) / span, 0.0, 1.0))
        RGBA{N0f8}(clamp(c[1], 0, 255) / 255, clamp(c[2], 0, 255) / 255, clamp(c[3], 0, 255) / 255, clamp(c[4], 0, 1))
    end
    clear = RGBA{N0f8}(0, 0, 0, 0)
    val(i, j) = (v = field[clamp(i, 1, nx), clamp(j, 1, ny)]; v === missing || (v isa Real && !isfinite(v)) ? nothing : Float64(v))
    for r in 1:H, c in 1:W
        u = (c - 0.5) / f
        v = (ny - 1) - (r - 0.5) / f
        if !smooth
            z = val(floor(Int, u + 0.5) + 1, floor(Int, v + 0.5) + 1)
            img[r, c] = z === nothing ? clear : rgba(z)
        else
            i0, j0 = floor(Int, u) + 1, floor(Int, v) + 1
            fu, fv = u - (i0 - 1), v - (j0 - 1)
            zs = (val(i0, j0), val(i0 + 1, j0), val(i0, j0 + 1), val(i0 + 1, j0 + 1))
            if any(isnothing, zs)
                z = val(floor(Int, u + 0.5) + 1, floor(Int, v + 0.5) + 1)
                img[r, c] = z === nothing ? clear : rgba(z)
            else
                img[r, c] = rgba((1 - fu) * (1 - fv) * zs[1] + fu * (1 - fv) * zs[2] + (1 - fu) * fv * zs[3] + fu * fv * zs[4])
            end
        end
    end
    path = tempname() * ".png"
    try
        Images.save(path, img)
        return read(path), W, H
    finally
        rm(path; force = true)
    end
end

"""
    svg_gradient_bar_stops(io, id, x, y, w, h, stops; max_stops = 32)

    Like [`svg_gradient_bar`](@ref) for a full colorscale: a vertical
    `<linearGradient>` (bottom = t 0) with one `<stop>` per scale stop (resampled
    to `max_stops` if the scale has more; alpha goes into `stop-opacity`), filling
    a `w` x `h` rect at `(x, y)`.
"""
function svg_gradient_bar_stops(io::IO, id::AbstractString, x, y, w, h, stops; max_stops::Int = 32)
    gid  = id * "_gradient"
    use  = length(stops) <= max_stops ? stops : [(t, svg_color_at(stops, t)) for t in range(0, 1, length = max_stops)]
    print(io, "<defs><linearGradient id=\"$(svg_escape(gid))\" x1=\"0\" y1=\"1\" x2=\"0\" y2=\"0\">")
    for (t, c) in use
        op = c[4] >= 1 ? "" : " stop-opacity=\"$(svg_num(c[4]))\""
        print(io, "<stop offset=\"$(svg_num(t))\" stop-color=\"rgb($(round(Int, c[1])),$(round(Int, c[2])),$(round(Int, c[3])))\"$(op)/>")
    end
    println(io, "</linearGradient></defs>")
    println(io, "<rect id=\"$(svg_escape(id))\" x=\"$(svg_num(x))\" y=\"$(svg_num(y))\" width=\"$(svg_num(w))\" height=\"$(svg_num(h))\" fill=\"url(#$(svg_escape(gid)))\"/>")
end

"""
    svg_nice_ticks(lo, hi; target = 6)

    Round tick values covering `lo..hi` (steps of 1, 2 or 5 times a power of ten,
    about `target` of them), ascending and all inside the range.
"""
function svg_nice_ticks(lo::Real, hi::Real; target::Int = 6)
    hi <= lo && return [Float64(lo)]
    raw  = (hi - lo) / max(target - 1, 1)
    mag  = 10.0^floor(log10(raw))
    step = mag * (raw / mag <= 1.5 ? 1 : raw / mag <= 3.5 ? 2 : raw / mag <= 7.5 ? 5 : 10)
    first_t = ceil(lo / step - 1e-9) * step
    ticks = Float64[]
    v = first_t
    while v <= hi + 1e-9 * step
        push!(ticks, round(v, digits = 10) + 0.0)
        v += step
    end
    return ticks
end

"""
    svg_annotation_layer(io, c, seen, annotations; id = "Labels", font)

    A layer of field labels from Plotly-style `annotations` (data-referenced,
    visible, with text; anything else is skipped): each label a real `<text>`
    (multi-line markup becomes tspans), centred on its anchor, and for annotations
    with an arrow a leader line from the text offset `(ax, ay)` to the anchor with
    a small arrow head, in its own `Label_leader_NNN` group. Shared by the
    exporters so every diagram's labels look the same.
"""
function svg_annotation_layer(io::IO, c::SVGCanvas, seen::Set{String}, annotations; id::AbstractString = "Labels",
                               font::AbstractString = "Helvetica, Arial, sans-serif")
    isempty(annotations) && return
    svg_group_open(io, svg_id(seen, id); fill = "#212121", font_family = font, font_size = 10, anchor = "middle")
    for (i, ann) in enumerate(annotations)
        f = ann.fields
        (get(f, :visible, true) == true && get(f, :xref, "") == "x" && get(f, :yref, "") == "y") || continue
        txt = string(get(f, :text, ""))
        isempty(txt) && continue
        px, py = svg_x(c, f[:x]), svg_y(c, f[:y])
        fsize  = haskey(f, :font) && haskey(f[:font], :size) ? f[:font][:size] : 10
        if get(f, :showarrow, false) == true
            tx, ty = px + get(f, :ax, 0), py + get(f, :ay, 0)
            len    = hypot(px - tx, py - ty)
            if len > 0
                ux, uy = (px - tx) / len, (py - ty) / len
                svg_group_open(io, svg_id(seen, "Label_leader_$(lpad(i, 3, '0'))"); stroke = "#212121", width = 0.5)
                svg_line(io, tx, ty, px - 4 * ux, py - 4 * uy)
                svg_group_close(io)
                svg_polygon(io, [(px, py), (px - 4 * ux - 1.5 * uy, py - 4 * uy + 1.5 * ux), (px - 4 * ux + 1.5 * uy, py - 4 * uy - 1.5 * ux)], "#212121")
            end
            svg_text(io, tx, ty, txt; id = svg_id(seen, "Label_$(lpad(i, 3, '0'))"), size = fsize)
        else
            svg_text(io, px, py, txt; id = svg_id(seen, "Label_$(lpad(i, 3, '0'))"), size = fsize)
        end
    end
    svg_group_close(io)
end
