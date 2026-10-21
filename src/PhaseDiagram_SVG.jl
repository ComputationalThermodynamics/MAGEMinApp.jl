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

pd_fig_meta    = nothing
pd_fig_meta_te = nothing

"""
    pd_export_status(msg; ok)

    A status line for an export button: `msg` in bold green when it worked and bold
    red when it did not, so a failure cannot be mistaken for "nothing happened" (the
    plain small grey text of the other exports is easy to miss). Also printed to the
    Julia terminal.
"""
function pd_export_status(msg::AbstractString; ok::Bool)
    println(ok ? "" : "Export SVG: ", msg)
    return html_span(msg, style = Dict("color" => ok ? "#2e7d32" : "#b00020", "fontWeight" => "bold"))
end

"""
    pd_fill_gridded(gridded, data)

    The colour field `gridded` (`[ix, iy]`) with every gap filled. `get_gridded_map`
    writes the field only at the AMR mesh *points* (the computed nodes); everything
    inside a cell is `missing`. The computed nodes are kept and the gaps take the
    harmonic interpolation of them ([`svg_fill_gaps`](@ref)), the converged form of
    Plotly's `connectgaps`: smooth across coarse cells, while phase boundaries, where
    the mesh is fine, keep their jump to one cell. `data` is kept for the call
    signature (screen and SVG export share this function).

    Cells of the section-diagram void field (`SECTION_VOID_HASH`: targets outside the image
    of the P-T box or not resolved), grown by one cell, stay `missing`, i.e. blank, so the
    raster does not reach past the traced edge of the image.
"""
function pd_fill_gridded(gridded::AbstractMatrix, data)
    filled  = svg_fill_gaps(gridded)
    void    = pd_void_mask(size(filled))
    isnothing(void) || (filled[void] .= missing)
    return filled
end

function pd_void_field_id()
    (@isdefined(Hash_XY) && @isdefined(gridded_fields)) || return nothing
    return findfirst(==(SECTION_VOID_HASH), unique(Hash_XY))
end

function pd_void_mask(sz)
    k = pd_void_field_id()
    (isnothing(k) || size(gridded_fields) != sz) && return nothing
    void    = gridded_fields .== k
    grown   = copy(void)
    nx, ny  = sz
    for j in 1:ny, i in 1:nx
        void[i, j] || continue
        for (di, dj) in ((-1, 0), (1, 0), (0, -1), (0, 1))
            ii, jj = i + di, j + dj
            (1 <= ii <= nx && 1 <= jj <= ny) && (grown[ii, jj] = true)
        end
    end
    return grown
end

"""
    pd_mesh_segments(data, n)

    The AMR mesh as merged straight segments `[(x1, y1, x2, y2)]` in data
    coordinates, from `data.cells`/`data.points` (the cells `show_hide_mesh_grid`
    draws). The mesh is made of axis-aligned edges on the `n x n` node grid, so
    each edge is put on that grid, duplicates (shared by two cells) are dropped and
    touching collinear edges are merged into single long segments: a mesh of tens
    of thousands of cells comes out as a few hundred lines instead of one object
    per cell edge.
"""
function pd_mesh_segments(data, n::Int)
    x0, x1 = data.Xrange[1], data.Xrange[2]
    y0, y1 = data.Yrange[1], data.Yrange[2]
    dx, dy = (x1 - x0) / (n - 1), (y1 - y0) / (n - 1)
    node(p) = (round(Int, (p[1] - x0) / dx), round(Int, (p[2] - y0) / dy))

    horiz = Dict{Int,Vector{Tuple{Int,Int}}}()
    vert  = Dict{Int,Vector{Tuple{Int,Int}}}()
    for cell in data.cells
        for k in 1:4
            a = node(data.points[cell[k]])
            b = node(data.points[cell[k == 4 ? 1 : k + 1]])
            if a[2] == b[2] && a[1] != b[1]
                push!(get!(horiz, a[2], Tuple{Int,Int}[]), (min(a[1], b[1]), max(a[1], b[1])))
            elseif a[1] == b[1] && a[2] != b[2]
                push!(get!(vert, a[1], Tuple{Int,Int}[]), (min(a[2], b[2]), max(a[2], b[2])))
            end
        end
    end

    function merged(lines)
        out = Tuple{Int,Int,Int}[]
        for key in sort(collect(keys(lines)))
            cur = nothing
            for (lo, hi) in sort(unique(lines[key]))
                if cur !== nothing && lo <= cur[2]
                    cur = (cur[1], max(cur[2], hi))
                else
                    cur === nothing || push!(out, (key, cur[1], cur[2]))
                    cur = (lo, hi)
                end
            end
            cur === nothing || push!(out, (key, cur[1], cur[2]))
        end
        return out
    end

    segs = NTuple{4,Float64}[]
    for (j, i1, i2) in merged(horiz)
        push!(segs, (x0 + i1 * dx, y0 + j * dy, x0 + i2 * dx, y0 + j * dy))
    end
    for (i, j1, j2) in merged(vert)
        push!(segs, (x0 + i * dx, y0 + j1 * dy, x0 + i * dx, y0 + j2 * dy))
    end
    return segs
end

"""
    pd_isopleth_contours(data_isopleth, i)

    The `Contour.jl` contour collection of isopleth slot `i`: the stored `isoT[i]`
    when it was recorded when the isopleth was built, otherwise (an isopleth built
    by a code path that does not record it, as the Trace elements builder used not
    to) rebuilt from the export trace `isoPexp[i]`, which holds the same grid
    (`x`, `y`, and `z` transposed to `[iy, ix]`) and the same levels
    (`contours_start`, `contours_end`, `contours_size`).
"""
function pd_isopleth_contours(data_isopleth, i::Int)
    tr = isassigned(data_isopleth.isoPexp, i) ? data_isopleth.isoPexp[i] : nothing
    if tr === nothing || !haskey(tr, :contours_start) || !haskey(tr, :z)
        return data_isopleth.isoT[i]
    end
    lo, hi = Float64(tr[:contours_start]), Float64(tr[:contours_end])
    step   = Float64(tr[:contours_size])
    z      = Float64.(coalesce.(permutedims(tr[:z]), NaN))
    levels = step > 0 ? [lo + k * step for k in 0:floor(Int, (hi - lo) / step + 1e-9)] : [lo]
    return CTR.contours(collect(Float64.(tr[:x])), collect(Float64.(tr[:y])), z, levels)
end

"""
    pd_finite_runs(xs, ys)

    The pieces of a contour polyline between non-finite vertices. Contour.jl gives
    NaN coordinates where a line would cross into an undefined (NaN) part of the
    grid, e.g. where the phase of a composition isopleth is absent; splitting there
    ends the line at the edge of the defined region. Pieces shorter than 2 points
    are dropped.
"""
function pd_finite_runs(xs, ys)
    runs = Vector{Vector{Tuple{Float64,Float64}}}()
    cur  = Tuple{Float64,Float64}[]
    for (x, y) in zip(xs, ys)
        if isfinite(x) && isfinite(y)
            push!(cur, (Float64(x), Float64(y)))
        else
            length(cur) > 1 && push!(runs, cur)
            cur = Tuple{Float64,Float64}[]
        end
    end
    length(cur) > 1 && push!(runs, cur)
    return runs
end

"""
    pd_isopleth_sets(data_isopleth, xy_y)

    The active isopleths of a diagram as data: for each slot in
    `data_isopleth.active`, `(name, color, dash, width, label_size, levels)` with
    `levels` the `(value, polylines)` of its contour lines, taken from the
    `Contour.jl` geometry the isopleth was built with (`isoT`, in data
    coordinates) and styled from the trace it was drawn with (`isoCap`/`isoP`).
    `xy_y` converts a y value to the display unit. `name` goes through
    `display_iso_label`, as the on-screen caption does.
"""
function pd_isopleth_sets(data_isopleth, xy_y; sigma::Real = 0.0)
    sets = NamedTuple[]
    for i in data_isopleth.active
        grid = sigma > 0 ? pd_isopleth_grid(data_isopleth, i) : nothing
        line  = data_isopleth.isoCap[i][:line]
        color = string(line[:color])
        dash  = haskey(line, :dash) ? line[:dash] : "solid"
        width = Float64(haskey(line, :width) ? line[:width] : 1.0)
        lsize = try
            Float64(data_isopleth.isoP[i][:contours][:labelfont][:size])
        catch
            10.0
        end
        levels = Tuple{Float64,Vector{Vector{Tuple{Float64,Float64}}}}[]
        for lvl in CTR.levels(pd_isopleth_contours(data_isopleth, i))
            polys = Vector{Vector{Tuple{Float64,Float64}}}()
            for l in CTR.lines(lvl)
                xs, ys = CTR.coordinates(l)
                for line in pd_finite_runs(xs, ys)
                    grid === nothing || (line = pd_smooth_isoline(line, Float64(CTR.level(lvl)), grid, sigma))
                    push!(polys, [(x, xy_y(y)) for (x, y) in line])
                end
            end
            isempty(polys) || push!(levels, (Float64(CTR.level(lvl)), polys))
        end
        label_bg = try
            data_isopleth.isoP[i][:meta] == "label-bg"
        catch
            false
        end
        push!(sets, (name = display_iso_label(string(data_isopleth.label[i])), color = color, dash = dash,
                     width = width, label_size = lsize, label_bg = label_bg, levels = levels))
    end
    return sets
end

"""
    pd_figure_parts(; data, gridded, heat_map, layout_g, reaction, data_isopleth, iso_show,
                      assemblage_rows, xtitle, ytitle, diagType,
                      show_reaction, show_mesh, show_labels)

    Everything a phase diagram shows, as plain data in the display pressure unit,
    from the globals its on-screen figure is built from (passed in, so the Phase
    diagram and Trace elements tabs, which keep parallel `_te` globals, share it):
    `data` (the AMR mesh), `gridded` (the field, `[ix, iy]`), `heat_map` (the export
    heatmap trace, for its colorscale/range/smoothing/title), `layout_g` (title and
    label annotations and the two paper-anchored provenance text columns, which are
    `PT_infos` - a local of the compute function, so the copies in `layout` are the
    ones to read), `reaction` (the reaction-line traces), `data_isopleth` with
    `iso_show` and `assemblage_rows` (the numbered assemblage list); `show_*` are
    the layer toggles. Returns a
    NamedTuple with the ranges, ticks, titles, field raster inputs, `mesh`,
    `reaction` (`(phase, x, y, color, dash, width)`), `isopleths`,
    `annotations`, `info`, `assemblages`.

    Pressure is converted with `display_pressure` here, once, under the same rule as
    the on-screen figure (`apply_pressure_display`: only for the `pt`, `px` and `ptx`
    diagram types when GPa is selected).
"""
function pd_figure_parts(; data, gridded, heat_map, layout_g, reaction, data_isopleth, iso_show,
                          assemblage_rows, xtitle::AbstractString, ytitle::AbstractString, diagType::AbstractString,
                          show_reaction::Bool, show_mesh::Bool, show_labels::Bool, geotherms = GenericTrace[],
                          fills = Tuple{Vector{Matrix{Float64}},NTuple{4,Float64}}[], iso_sigma::Real = 0.0)
    global phase_infos
    convert_p = use_GPa[1] && pressure_on_y_axis(diagType)
    yconv(y::Real) = convert_p ? display_pressure(Float64(y)) : Float64(y)
    yconv(y)       = y
    xr = collect(Float64.(data.Xrange))
    yr = [yconv(v) for v in data.Yrange]
    n  = size(gridded, 1)

    zvals = collect(skipmissing(gridded))
    zmin  = haskey(heat_map, :zmin) ? Float64(heat_map[:zmin]) : minimum(zvals)
    zmax  = haskey(heat_map, :zmax) ? Float64(heat_map[:zmax]) : maximum(zvals)
    smooth = haskey(heat_map, :zsmooth) && heat_map[:zsmooth] !== false && heat_map[:zsmooth] != "false"
    stops  = svg_colorscale(heat_map[:colorscale]; reverse = haskey(heat_map, :reversescale) && heat_map[:reversescale] == true)
    ftitle = try
        string(heat_map[:colorbar][:title][:text])
    catch
        ""
    end
    ztick = try
        Float64(heat_map[:colorbar][:dtick])
    catch
        nothing
    end

    mesh = show_mesh ? [(a, yconv(b), c, yconv(d)) for (a, b, c, d) in pd_mesh_segments(data, n)] : NTuple{4,Float64}[]

    lines = NamedTuple[]
    if show_reaction && reaction !== nothing
        all_ph = Vector{String}(vcat(phase_infos.act_ss, phase_infos.act_pp))
        if length(reaction) == length(all_ph)
            for (i, t) in enumerate(reaction)
                ln = t[:line]
                push!(lines, (phase = all_ph[i], x = t[:x], y = [yconv(v) for v in t[:y]],
                              color = string(haskey(ln, :color) ? ln[:color] : "#000000"),
                              dash  = haskey(ln, :dash) ? ln[:dash] : "solid",
                              width = Float64(haskey(ln, :width) ? ln[:width] : 0.75)))
            end
        end
    end

    isopleths = (iso_show == 1 && data_isopleth.n_iso > 0) ? pd_isopleth_sets(data_isopleth, yconv; sigma = iso_sigma) : NamedTuple[]

    annotations = PlotlyBase.PlotlyAttribute[]
    if show_labels && layout_g !== nothing && haskey(layout_g, :annotations)
        for ann in layout_g[:annotations]
            f = ann.fields
            (get(f, :xref, "") == "x" && get(f, :yref, "") == "y" && !isempty(string(get(f, :text, "")))) || continue
            a = merge(deepcopy(ann), attr(visible = true))
            haskey(a.fields, :y) && a[:y] isa Number && (a[:y] = yconv(Float64(a[:y])))
            push!(annotations, a)
        end
    end

    title = try
        t = layout_g[:title]
        t isa AbstractString ? String(t) : (haskey(t, :text) ? string(t[:text]) : "")
    catch
        ""
    end
    ytitle_disp = convert_p && occursin("Pressure", ytitle) ? "Pressure [$(pressure_unit_label())]" : String(ytitle)

    assemblages = show_labels ? ["$(r["N"])) $(r["Assemblage"])" for r in assemblage_rows] : String[]

    info = String[]
    if layout_g !== nothing && haskey(layout_g, :annotations)
        paper = [a.fields for a in layout_g[:annotations] if get(a.fields, :xref, "") == "paper" && !isempty(string(get(a.fields, :text, "")))]
        sort!(paper, by = f -> get(f, :x, 0.0))
        info = [string(f[:text]) for f in paper]
    end

    return (xrange = xr, yrange = yr, ticks = 4, title = title, xtitle = String(xtitle), ytitle = ytitle_disp,
            gridded = pd_fill_gridded(gridded, data), zmin = zmin, zmax = zmax, stops = stops, smooth = smooth, field_title = ftitle, ztick = ztick,
            mesh = mesh, reaction = lines,
            fills = [([[(r[k, 1], yconv(r[k, 2])) for k in 1:size(r, 1)] for r in rings], col) for (rings, col) in fills],
            isopleths = isopleths, geotherms = subd_svg_lines(geotherms, yconv), annotations = annotations,
            info = info, assemblages = assemblages)
end

"""
    pd_contour_label(line, c)

    Where to put the value label of one contour polyline `line` on canvas `c`:
    `(x, y, angle)` at the middle of the line's length, the angle following the
    line and kept upright (-90..90 degrees); `nothing` for a line too short to
    hold a label.
"""
function pd_contour_label(line::Vector{Tuple{Float64,Float64}}, c::SVGCanvas)
    return pd_polyline_label([(svg_x(c, x), svg_y(c, y)) for (x, y) in line], 0.5)
end

"""
    pd_export_svg(parts, path)

    Write a phase diagram to `path` as one clean, layered SVG for Illustrator, from
    [`pd_figure_parts`](@ref), replacing the old per-layer Kaleido exports. Same
    design as [`mc_export_svg`](@ref), on a 758 px wide canvas whose plot area is the
    same 554 x 590; the canvas grows downwards for the provenance text and the
    assemblage list. Layers, in paint order (absent when switched off or empty):

    - `Field`: the colored field, one embedded PNG `<image>` covering the plot area
      ([`svg_field_png`](@ref), with the on-screen colorscale, range and smoothing);
    - `Mesh`: the AMR mesh as merged straight segments ([`pd_mesh_segments`](@ref));
    - `Reaction_lines`: one path per phase (`Reaction_<phase>`) with the dash, width
      and color set for it in the reaction-line options;
    - `Isopleth_<name>`: one layer per active isopleth, one path per contour level,
      with the value labels as text along the lines;
    - `Labels`: the field labels and leader lines ([`svg_annotation_layer`](@ref));
    - `Layout`: outline, ticks, tick labels, axis titles, figure title;
    - `Colorbar`: a multi-stop gradient, its ticks and the field name;
    - `Isopleth_legend`: a swatch and name per active isopleth;
    - `Info`: the two provenance text columns shown under the diagram;
    - `Assemblage_list`: the numbered assemblages the small labels refer to.

    Lines are clipped to the plot area in Julia (no clip path); every path is
    straight `M`/`L` segments. The only `<defs>` is the colorbar gradient. Returns
    `(path, bytes, n_paths)`.
"""
function pd_export_svg(parts, path::AbstractString)
    xr, yr = parts.xrange, parts.yrange
    font   = "Helvetica, Arial, sans-serif"
    ink    = "#333333"
    pw, ph = 554.0, 590.0
    ml, mr, mt = 64.0, 140.0, 48.0
    line_h = 11.5

    info_h     = svg_info_height(parts.info; line_h = line_h)
    ncol       = 3
    list_rows  = cld(length(parts.assemblages), ncol)
    list_h     = list_rows * 10.5
    height     = 48.0 + ph + 62.0 + (info_h > 0 ? info_h + 24 : 0) + (list_h > 0 ? list_h + 30 : 0) + 10
    c          = SVGCanvas(758.0, height, ml, mr, mt, height - mt - ph, xr[1], xr[2], yr[1], yr[2])
    left, right, top, bottom = c.ml, c.ml + pw, c.mt, c.mt + ph
    seen   = Set{String}()
    io     = IOBuffer()
    n_paths = 0

    clipped(x, y) = reduce(vcat, [svg_clip_polyline(l, xr[1], xr[2], yr[1], yr[2]) for l in svg_split_polylines(x, y)];
                           init = Vector{Vector{Tuple{Float64,Float64}}}())

    svg_open(io, c; xlink = true)

    png, _, _ = svg_field_png(parts.gridded, parts.zmin, parts.zmax, parts.stops; smooth = parts.smooth)
    fills = get(parts, :fills, [])
    svg_group_open(io, svg_id(seen, "Field"); hidden = !isempty(fills))
    svg_image(io, svg_id(seen, "Field_raster"), c, png)
    svg_group_close(io)

    if !isempty(fills)
        svg_group_open(io, svg_id(seen, "Field_polygons"); width = 0.3)
        for (k, (rings, col)) in enumerate(fills)
            d   = join([svg_path_data(c, [r]) * " Z" for r in rings], " ")
            rgb, op = svg_css_color(pd_rgba(col))
            svg_path(io, svg_id(seen, "Field_$(k)"), d; fill = rgb, stroke = op === nothing ? rgb : "none", fill_opacity = op)
            n_paths += 1
        end
        svg_group_close(io)
    end

    if !isempty(parts.mesh)
        d = svg_path_data(c, [[(a, b), (cc, dd)] for (a, b, cc, dd) in parts.mesh])
        svg_group_open(io, svg_id(seen, "Mesh"); stroke = "#333333", width = 0.2, fill = "none")
        svg_path(io, svg_id(seen, "Mesh_lines"), d)
        svg_group_close(io)
        n_paths += 1
    end

    if !isempty(parts.reaction)
        svg_group_open(io, svg_id(seen, "Reaction_lines"); fill = "none", rounded = true)
        for r in parts.reaction
            d = svg_path_data(c, clipped(r.x, r.y))
            isempty(d) && continue
            svg_path(io, svg_id(seen, "Reaction_" * display_ph_name(r.phase)), d; stroke = r.color, width = r.width,
                     dash = svg_dasharray(r.dash, r.width))
            n_paths += 1
        end
        svg_group_close(io)
    end

    iso_placed = NTuple{5,Float64}[]
    for iso in parts.isopleths
        svg_group_open(io, svg_id(seen, "Isopleth_" * iso.name); stroke = iso.color, width = iso.width, fill = "none",
                        dash = svg_dasharray(iso.dash, iso.width), rounded = true)
        idbase = svg_id(seen, "Iso_" * iso.name)
        labels = Tuple{Float64,Float64,Float64,String}[]
        for (lvl, polys) in iso.levels
            cl = reduce(vcat, [svg_clip_polyline(p, xr[1], xr[2], yr[1], yr[2]) for p in polys];
                        init = Vector{Vector{Tuple{Float64,Float64}}}())
            d = svg_path_data(c, cl)
            isempty(d) && continue
            lvl_txt = svg_tick_label(round_sig(lvl; sig = 4, mindigits = 0))
            svg_path(io, svg_id(seen, "$(idbase)_$(lvl_txt)"), d)
            n_paths += 1
            for l in cl
                lab = pd_place_line_label!(iso_placed, [(svg_x(c, x), svg_y(c, y)) for (x, y) in l], lvl_txt, iso.label_size)
                lab === nothing || push!(labels, (lab[1], lab[2], lab[3], lvl_txt))
            end
        end
        svg_group_close(io)
        if !isempty(labels)
            svg_group_open(io, svg_id(seen, "Isopleth_labels_" * iso.name); fill = iso.color, font_family = font,
                            font_size = iso.label_size, anchor = "middle")
            for (k, (x, y, ang, txt)) in enumerate(labels)
                if get(iso, :label_bg, false)
                    w, h = pd_label_box(txt, iso.label_size)
                    println(io, "<rect id=\"$(svg_escape(svg_id(seen, "$(idbase)_label_bg_$(k)")))\" x=\"$(svg_num(x - w / 2))\" y=\"$(svg_num(y - h / 2))\" width=\"$(svg_num(w))\" height=\"$(svg_num(h))\" fill=\"#ffffff\" fill-opacity=\"0.7\" stroke=\"none\" transform=\"rotate($(svg_num(ang)) $(svg_num(x)) $(svg_num(y)))\"/>")
                end
                svg_text(io, x, y, txt; id = svg_id(seen, "$(idbase)_label_$(k)"), rotate = ang)
            end
            svg_group_close(io)
        end
    end

    geo = get(parts, :geotherms, NamedTuple[])
    if !isempty(geo)
        svg_group_open(io, svg_id(seen, "Subduction_geotherms"); fill = "none", rounded = true)
        ends = Tuple{Float64,Float64,String,String}[]
        for g in geo
            cl = clipped(g.x, g.y)
            d  = svg_path_data(c, cl)
            isempty(d) && continue
            svg_path(io, svg_id(seen, "Geotherm_" * g.label), d; stroke = g.color, width = g.width, dash = svg_dasharray(g.dash, g.width))
            n_paths += 1
            last_pt = cl[end][end]
            push!(ends, (svg_x(c, last_pt[1]), svg_y(c, last_pt[2]), g.label, g.color))
        end
        svg_group_close(io)
        if !isempty(ends)
            svg_group_open(io, svg_id(seen, "Subduction_geotherm_labels"); font_family = font, font_size = 10, anchor = "start")
            for (x, y, txt, col) in ends
                svg_text(io, x + 3, y + 10, txt; id = svg_id(seen, "Geotherm_label_" * txt), fill = col)
            end
            svg_group_close(io)
        end
    end

    svg_annotation_layer(io, c, seen, parts.annotations; font = font)

    nt = parts.ticks + 1
    svg_layout_layers(io, c, seen; xticks = [xr[1] + k * (xr[2] - xr[1]) / nt for k in 0:nt],
                       yticks = [yr[1] + k * (yr[2] - yr[1]) / nt for k in 0:nt],
                       xtitle = parts.xtitle, ytitle = parts.ytitle, title = parts.title, font = font, ink = ink)

    bar_x, bar_w = right + 16, 12.0
    bar_h        = 0.75 * ph
    bar_y        = top + (ph - bar_h) / 2
    svg_group_open(io, svg_id(seen, "Colorbar"); font_family = font, font_size = 10, fill = ink)
    svg_gradient_bar_stops(io, svg_id(seen, "Colorbar_bar"), bar_x, bar_y, bar_w, bar_h, parts.stops)
    zticks = isnothing(get(parts, :ztick, nothing)) ? svg_nice_ticks(parts.zmin, parts.zmax) :
             collect(ceil(parts.zmin / parts.ztick - 1e-9) * parts.ztick : parts.ztick : parts.zmax + 1e-9)
    zlabels = [svg_tick_label(v) for v in zticks]
    zy      = [bar_y + bar_h * (1 - (parts.zmax == parts.zmin ? 0.0 : (v - parts.zmin) / (parts.zmax - parts.zmin))) for v in zticks]
    svg_group_open(io, svg_id(seen, "Colorbar_outline"); stroke = ink, width = 0.75, fill = "none")
    svg_rect(io, svg_id(seen, "Colorbar_frame"), bar_x, bar_y, bar_w, bar_h)
    svg_group_close(io)
    svg_group_open(io, svg_id(seen, "Colorbar_ticks"); stroke = ink, width = 0.75)
    for y in zy
        svg_line(io, bar_x + bar_w - 4, y, bar_x + bar_w, y)
    end
    svg_group_close(io)
    for (k, y) in enumerate(zy)
        svg_text(io, bar_x + bar_w + 5, y, zlabels[k]; id = svg_id(seen, "Colorbar_tick_$(k)"), anchor = "start")
    end
    title_dx = max(42.0, 5.0 + 5.8 * maximum(length, zlabels; init = 0) + 14.0)
    isempty(parts.field_title) || svg_text(io, bar_x + bar_w + title_dx, bar_y + bar_h / 2, parts.field_title;
                                            id = svg_id(seen, "Colorbar_title"), size = 11, anchor = "middle", rotate = 90)
    svg_group_close(io)

    if !isempty(parts.isopleths)
        svg_group_open(io, svg_id(seen, "Isopleth_legend"); font_family = font, font_size = 10, fill = ink)
        y = bar_y + bar_h + 28
        for iso in parts.isopleths
            svg_path(io, svg_id(seen, "Legend_swatch_" * iso.name), "M$(svg_num(right + 16)) $(svg_num(y)) L$(svg_num(right + 36)) $(svg_num(y))";
                     stroke = iso.color, width = iso.width, dash = svg_dasharray(iso.dash, iso.width))
            svg_text(io, right + 42, y, iso.name; id = svg_id(seen, "Legend_text_" * iso.name), anchor = "start")
            y += 17
        end
        svg_group_close(io)
    end

    y_info = bottom + 62
    svg_info_layer(io, seen, parts.info; left = left, y = y_info, pw = pw, font = font, ink = ink, line_h = line_h)

    if !isempty(parts.assemblages)
        y_list = y_info + (info_h > 0 ? info_h + 24 : 0)
        svg_group_open(io, svg_id(seen, "Assemblage_list"); font_family = font, font_size = 9, fill = ink)
        colw = (c.width - ml - 10) / ncol
        for k in 1:ncol
            rows = parts.assemblages[(k-1)*list_rows+1:min(k * list_rows, end)]
            isempty(rows) && continue
            svg_text(io, ml + (k - 1) * colw, y_list, join(rows, "<br>"); id = svg_id(seen, "Assemblage_column_$(k)"), anchor = "start",
                     top = true, line_height = 10.5 / 9)
        end
        svg_group_close(io)
    end

    svg_close(io)
    bytes = take!(io)
    write(path, bytes)
    return (path = String(path), bytes = length(bytes), n_paths = n_paths)
end
