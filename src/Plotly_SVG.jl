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
    A generic Plotly-figure -> clean layered SVG translator.

    Unlike the MC/probability/phase-diagram exporters (`MonteCarlo_functions.jl`,
    `PhaseDiagram_SVG.jl`), which redraw from the app's own globals because their
    figures hold a rasterised field or an AMR mesh the figure object does not carry,
    every figure this file targets (the PTX path result plots and the TAS/AFM/mineral
    classification diagrams, in both the PTX and Phase diagram tabs) is an ordinary
    Plotly `scatter`/`bar`/`scatterternary` figure: everything drawn is already in the
    figure. So instead of one bespoke exporter per figure (there are 27 of them, built
    by unrelated, copy-pasted functions across two files), this translates the figure
    object itself, taken straight from the browser as a callback `State`. It covers the
    Plotly subset these figures use; anything else is skipped, not guessed, and the
    skip is named in the export status.
"""

# ---------------------------------------------------------------- accessors --

"""
    pget(obj, key; default = nothing)

    `obj[key]` for any of the shapes a Plotly figure/trace/layout arrives in: a
    `PlotlyBase.Plot` (the figure itself, `:data`/`:layout` only - built headless, as
    in the standalone tests), a `PlotlyBase.PlotlyAttribute` (a trace or a layout
    piece built locally), a `JSON3.Object` (a callback `State` taken straight from the
    browser - what every real call site passes) or a plain `Dict`. The last three
    support `get`/`haskey` directly (`PlotlyAttribute` through its own methods,
    `JSON3.Object` because it is an `AbstractDict`), so one accessor covers them;
    `nothing`/JSON `null` counts as absent. Falls back from a `Symbol` key to its
    `String` form (and back) since JSON3 accepts either but a plain `Dict{String,Any}`
    only matches its own key type.
"""
function pget(obj, key::Symbol; default = nothing)
    obj === nothing && return default
    if obj isa PlotlyBase.Plot
        key === :data && return obj.data
        key === :layout && return obj.layout
        return default
    end
    v = try
        get(obj, key, nothing)
    catch
        nothing
    end
    v === nothing || return v
    v = try
        get(obj, string(key), nothing)
    catch
        nothing
    end
    return v === nothing ? default : v
end

"""
    phas(obj, key)

    Whether `obj` has a non-null value at `key` (see [`pget`](@ref)).
"""
phas(obj, key::Symbol) = pget(obj, key) !== nothing

"""
    pnum(v)

    `v` as a `Float64`, or `nothing` for `missing`/`nothing`/non-finite/non-numeric
    (a single-element array, the JSON round-trip of a `1xN` `Matrix` column - see
    [`pflatten`](@ref) - unwraps first).
"""
function pnum(v)
    (v === nothing || v === missing) && return nothing
    if !(v isa Number) && (v isa AbstractVector || (applicable(length, v) && applicable(getindex, v, 1) && !(v isa AbstractString)))
        length(v) == 0 && return nothing
        return pnum(v[1])
    end
    v isa Number || return nothing
    x = Float64(v)
    return isfinite(x) ? x : nothing
end

"""
    pstr(v)

    `v` as a `String`, or `nothing` for `missing`/`nothing`/empty.
"""
function pstr(v)
    (v === nothing || v === missing) && return nothing
    s = string(v)
    return isempty(s) ? nothing : s
end

"""
    pflatten(v)

    `v` (a Julia `Vector`, a `JSON3.Array`, or `nothing`) as a plain `Vector{Any}` of
    scalars/`nothing`: each element that is itself a 1-element array (how JSON.jl
    serialises a column of a `1xN` `Matrix`, e.g. the TAS/AFM traces' `x`/`y`, which
    are built as `1x(n+1)` matrices from a single-element `findall` index) is
    unwrapped to that one element; a `String` is left as one whole element, never
    iterated into characters; `NaN`/non-finite numbers become `nothing`.
"""
function pflatten(v)
    v === nothing && return Any[]
    out = Any[]
    for el in v
        if el isa AbstractString
            push!(out, el)
        elseif el isa AbstractVector || (el !== nothing && !(el isa Number) && applicable(length, el) && applicable(getindex, el, 1))
            push!(out, length(el) == 0 ? nothing : (n = pnum(el[1]); n === nothing ? pstr(el[1]) : n))
        elseif el isa Number
            x = Float64(el)
            push!(out, isfinite(x) ? x : nothing)
        else
            push!(out, el)
        end
    end
    return out
end

"""
    pvec(obj, key)

    [`pflatten`](@ref)ed value of `obj[key]`, or `Any[]` if absent.
"""
pvec(obj, key::Symbol) = pflatten(pget(obj, key))

# ------------------------------------------------------------------ layers --

"""
    PTrace

    One trace of a figure, normalised out of whatever form it arrived in
    (`PlotlyAttribute` or `JSON3.Object`) into plain fields, ready to draw.
"""
struct PTrace
    kind         :: Symbol   # :scatter, :bar, :scatterternary, :other
    x            :: Vector{Any}
    y            :: Vector{Any}
    a            :: Vector{Any}
    b            :: Vector{Any}
    c            :: Vector{Any}
    name         :: String
    showlegend   :: Bool
    mode         :: String
    line_color   :: Union{Nothing,String}
    line_width   :: Float64
    line_dash    :: Union{Nothing,String}
    marker_color :: Any             # a color string, a Vector{Union{Float64,Nothing}}, or nothing
    marker_size  :: Any             # a number or a Vector
    marker_symbol:: Union{Nothing,String}
    marker_opacity :: Float64
    marker_line_color :: Union{Nothing,String}
    marker_line_width :: Float64
    colorscale   :: Any
    colorscale_reverse :: Bool
    showscale    :: Bool
    colorbar_title :: Union{Nothing,String}
    stackgroup   :: Union{Nothing,String}
    opacity      :: Float64
end

const PMARKER_DEFAULT_R = 3.0

"""
    ptrace_kind(tr)

    `:scatter`, `:bar`, `:scatterternary` or `:other` for Plotly trace `tr`, from
    its `type` field.
"""
function ptrace_kind(tr)
    t = pstr(pget(tr, :type))
    t == "bar" && return :bar
    t == "scatterternary" && return :scatterternary
    (t === nothing || t == "scatter" || t == "scattergl") && return :scatter
    return :other
end

"""
    ptrace_dummy(tr)

    Whether `tr` is a legend-only placeholder: named, meant to show in the legend,
    but with no real point (every `x`/`y`, or `a`/`b`/`c` for a ternary trace, is
    `nothing`) - the size-key entries ("0%"/"50%"/"100%") on the TAS/AFM/probability
    diagrams. These are drawn as ordinary legend entries, not as an empty layer.
"""
function ptrace_dummy(tr::PTrace)
    isempty(tr.name) && return false
    xy = tr.kind == :scatterternary ? vcat(tr.a, tr.b, tr.c) : vcat(tr.x, tr.y)
    return !isempty(xy) && all(v -> v === nothing, xy)
end

"""
    build_ptrace(tr)

    A [`PTrace`](@ref) read out of the raw Plotly trace `tr` (any of the three
    figure representations, see [`pget`](@ref)).
"""
function build_ptrace(tr)
    line   = pget(tr, :line)
    marker = pget(tr, :marker)
    cbar   = pget(marker, :colorbar)
    cbtitle = pget(cbar, :title)
    mcolor = pget(marker, :color)
    mcolor_v = if mcolor === nothing
        nothing
    elseif mcolor isa AbstractString
        String(mcolor)
    else
        v = pflatten(mcolor)
        all(x -> x isa Real || x === nothing, v) ? Vector{Union{Float64,Nothing}}(v) : pstr(mcolor)
    end
    msize = pget(marker, :size)
    msize_v = msize === nothing ? nothing : (msize isa Number ? Float64(msize) :
              (v = pflatten(msize); Vector{Union{Float64,Nothing}}([x === nothing ? nothing : Float64(x) for x in v])))
    return PTrace(
        ptrace_kind(tr),
        pvec(tr, :x), pvec(tr, :y), pvec(tr, :a), pvec(tr, :b), pvec(tr, :c),
        something(pstr(pget(tr, :name)), ""),
        pget(tr, :showlegend; default = true) == true,
        something(pstr(pget(tr, :mode)), "lines"),
        pstr(pget(line, :color)), something(pnum(pget(line, :width)), 1.0), pstr(pget(line, :dash)),
        mcolor_v, msize_v, pstr(pget(marker, :symbol)),
        something(pnum(pget(marker, :opacity)), 1.0),
        pstr(pget(marker, :line, default = nothing) === nothing ? nothing : pget(pget(marker, :line), :color)),
        something(pnum(pget(marker, :line, default = nothing) === nothing ? nothing : pget(pget(marker, :line), :width)), 0.75),
        pget(marker, :colorscale), pget(marker, :reversescale) == true, pget(marker, :showscale) == true,
        pstr(pget(cbtitle, :text)),
        pstr(pget(tr, :stackgroup)),
        something(pnum(pget(tr, :opacity)), 1.0),
    )
end

"""
    ptrace_color(tr)

    The single colour to represent `tr` with in a legend or as a plain stroke/fill
    (its line colour, else its fixed marker colour, else the app's ink grey).
"""
function ptrace_color(tr::PTrace)
    tr.line_color !== nothing && return tr.line_color
    tr.marker_color isa AbstractString && return tr.marker_color
    return "#333333"
end

"""
    marker_radius(tr, i, n)

    The canvas-unit radius of point `i` of `n` for `tr`'s marker (Plotly `size` is a
    pixel *diameter*; halved here). A `size` vector shorter than the data (a real
    off-by-one in the TAS/AFM traces, which Plotly tolerates by clamping) reuses its
    last entry for the remaining points.
"""
function marker_radius(tr::PTrace, i::Int, n::Int)
    tr.marker_size === nothing && return PMARKER_DEFAULT_R
    tr.marker_size isa Number && return Float64(tr.marker_size) / 2
    v = tr.marker_size
    isempty(v) && return PMARKER_DEFAULT_R
    s = v[clamp(i, 1, length(v))]
    return s === nothing ? PMARKER_DEFAULT_R : Float64(s) / 2
end

"""
    ptrace_color_lookup(tr)

    A function `i -> "rgb(r,g,b)"` giving the fill colour of point `i` of `tr`: when
    `tr.marker_color` is a data vector with a `colorscale`, each point's value is
    normalised over the *trace's own* min/max (matching Plotly, which autoscales a
    marker colorscale to its trace's data unless `cmin`/`cmax` are given - not seen in
    these figures) and looked up in the scale; otherwise every point gets the same
    fixed colour (the trace's marker colour, or `#333333` if none is set).
"""
function ptrace_color_lookup(tr::PTrace)
    if tr.marker_color isa AbstractVector && tr.colorscale !== nothing
        stops = svg_colorscale(tr.colorscale; reverse = tr.colorscale_reverse)
        vals  = Float64[v for v in tr.marker_color if v isa Real]
        zmin, zmax = isempty(vals) ? (0.0, 1.0) : (minimum(vals), maximum(vals))
        span  = zmax == zmin ? 1.0 : zmax - zmin
        mc    = tr.marker_color
        return i -> begin
            v = i <= length(mc) ? mc[i] : nothing
            v === nothing && return "#888888"
            rc = svg_color_at(stops, clamp((v - zmin) / span, 0.0, 1.0))
            "rgb($(round(Int, rc[1])),$(round(Int, rc[2])),$(round(Int, rc[3])))"
        end
    end
    fixed = tr.marker_color isa AbstractString ? tr.marker_color : "#333333"
    fc, _ = svg_css_color(fixed)
    return _ -> fc
end

# ------------------------------------------------------------------- axes --

"""
    PAxis

    A resolved cartesian axis: `kind` (`:linear`, `:log` or `:category`), data
    `lo`/`hi`, `categories` (the ordered label list when `kind == :category`),
    explicit `tickvals`/`ticklabels` (from `layout.xaxis.tickvals`/`ticktext`, or
    `nothing` to compute them), `tick_angle`, `title` and `reversed`.
"""
struct PAxis
    kind        :: Symbol
    lo          :: Float64
    hi          :: Float64
    categories  :: Vector{String}
    tickvals    :: Union{Nothing,Vector{Float64}}
    ticklabels  :: Union{Nothing,Vector{String}}
    tick_angle  :: Float64
    title       :: String
    reversed    :: Bool
end

"""
    collect_categories(traces, which)

    The ordered, de-duplicated category labels of `traces`' `x` (`which = :x`) or
    `y` (`:y`) values, in first-appearance order across traces in the order given -
    the same order Plotly assigns positions in when it auto-detects a category axis.
"""
function collect_categories(traces::Vector{PTrace}, which::Symbol)
    seen = String[]
    seenset = Set{String}()
    for tr in traces
        for v in (which == :x ? tr.x : tr.y)
            v isa AbstractString || continue
            v in seenset && continue
            push!(seenset, v)
            push!(seen, v)
        end
    end
    return seen
end

"""
    axis_is_category(traces, which)

    Whether any trace's `x` (`which = :x`) / `y` (`:y`) values contain a string -
    Plotly's own rule for auto-detecting a category axis.
"""
axis_is_category(traces::Vector{PTrace}, which::Symbol) =
    any(tr -> any(v -> v isa AbstractString, which == :x ? tr.x : tr.y), traces)

"""
    resolve_axis(axis_layout, traces, which; stacked_hi = nothing)

    Build the [`PAxis`](@ref) for `which` (`:x`/`:y`) from its layout attributes
    (`type`, `range`, `autorange`, `tickmode`/`tickvals`/`ticktext`, `tickangle`,
    `title`) and, when no explicit `range` is given, the data itself. `stacked_hi`,
    when given, is the highest point actually drawn (the top of a stacked band or
    bar, which is higher than any single trace's own values); it is included in the
    autorange alongside 0, since a stacked fill always reaches its zero baseline
    even when every individual trace happens to stay positive (all of a phase's own
    fractions might never dip near zero while the *stack* still starts there) - the
    bug this guards against put a filled band's bottom edge, drawn down to 0, far
    outside an axis range that had autoscaled to the data's own min instead.
"""
function resolve_axis(axis_layout, traces::Vector{PTrace}, which::Symbol; stacked_hi::Union{Nothing,Real} = nothing)
    explicit_type = pstr(pget(axis_layout, :type))
    is_cat  = explicit_type == "category" || (explicit_type === nothing && axis_is_category(traces, which))
    is_log  = explicit_type == "log"
    title   = something(pstr(pget(pget(axis_layout, :title), :text)), something(pstr(pget(axis_layout, :title)), ""))
    tangle  = something(pnum(pget(axis_layout, :tickangle)), 0.0)
    reversed = pstr(pget(axis_layout, :autorange)) == "reversed"

    if is_cat
        cats = collect_categories(traces, which)
        isempty(cats) && (cats = ["1"])
        n = length(cats)
        tv, tl = nothing, nothing
        etv = pget(axis_layout, :tickvals)
        if etv !== nothing
            tv = Float64.(pflatten(etv))
            tl = String.(pflatten(pget(axis_layout, :ticktext)))
        end
        # Plotly only reserves half a category's width on each side when something
        # actually needs that width to avoid being clipped at the frame - a bar (so
        # its outer edge has room) or a plain marker-only trace. A line/area trace
        # (stacked or not) has no width of its own, so Plotly runs it edge to edge:
        # padding it here left a visible gap between the frame and a stacked area's
        # outermost band, on both sides, that the real figure does not have.
        pad = any(t -> t.kind == :bar, traces) ? 0.5 : (any(t -> occursin("lines", t.mode), traces) ? 0.0 : 0.5)
        return PAxis(:category, -pad, n - 1 + pad, cats, tv, tl, tangle, title, reversed)
    end

    vals = Float64[]
    for tr in traces
        for v in (which == :x ? tr.x : tr.y)
            v isa Real && isfinite(v) && (!is_log || v > 0) && push!(vals, v)
        end
    end
    stacked_hi !== nothing && (push!(vals, Float64(stacked_hi)); push!(vals, 0.0))  # a stack's fill always reaches its zero baseline
    rng = pget(axis_layout, :range)
    if rng !== nothing
        r = Float64.(pflatten(rng))
        # Plotly's own convention for a log axis: an explicit range is given in log10
        # space (the exponents), not the data values themselves - a real browser session
        # writes exactly this back into the figure once Plotly.js has computed an
        # autorange (autorange stays reported, but a concrete range appears alongside
        # it), which no synthetic or HTTP-only test ever produces since nothing here
        # emulates the browser's own client-side autorange step. Reading it as a plain
        # data value crashed outright the moment that exponent was negative (any C/
        # chondrite ratio under 1) - `log10(lo)` on an already-log value a line below.
        lo, hi = is_log ? (10.0^r[1], 10.0^r[2]) : (r[1], r[2])
    elseif isempty(vals)
        lo, hi = (is_log ? (1.0, 10.0) : (0.0, 1.0))
    else
        lo, hi = minimum(vals), maximum(vals)
        if is_log
            lo, hi = lo <= 0 ? 1e-3 : lo, hi <= lo ? lo * 10 : hi
            pad = (log10(hi) - log10(lo)) * 0.08
            pad == 0 && (pad = 0.3)
            lo, hi = 10.0^(log10(lo) - pad), 10.0^(log10(hi) + pad)
        else
            pad = (hi - lo) * 0.06
            pad == 0 && (pad = max(abs(hi), 1.0) * 0.1)
            lo, hi = lo - pad, hi + pad
        end
    end

    tv, tl = nothing, nothing
    etv = pget(axis_layout, :tickvals)
    if etv !== nothing
        tv = Float64.(pflatten(etv))
        etl = pget(axis_layout, :ticktext)
        etl !== nothing && (tl = String.(pflatten(etl)))
    end
    return PAxis(is_log ? :log : :linear, lo, hi, String[], tv, tl, tangle, title, reversed)
end

"""
    axis_ticks(ax)

    `(tickvals, ticklabels)` for [`PAxis`](@ref) `ax`: the explicit `tickvals`/
    `ticklabels` when the layout gave them; otherwise `svg_nice_ticks` for a linear
    axis, decade marks for a log axis, or up to 10 evenly-sampled categories for a
    category axis (the same thinning `_ptx_tick_labels` applies to the PTX path
    click-picker).
"""
function axis_ticks(ax::PAxis)
    if ax.tickvals !== nothing
        return ax.tickvals, something(ax.ticklabels, svg_tick_label.(ax.tickvals))
    end
    if ax.kind == :category
        n = length(ax.categories)
        step = max(1, div(n - 1, 9))
        idx  = sort(unique(vcat(1:step:n, n)))
        return Float64.(idx .- 1), [ax.categories[i] for i in idx]
    end
    axlo, axhi = ax.lo <= ax.hi ? (ax.lo, ax.hi) : (ax.hi, ax.lo)
    if ax.kind == :log
        axlo, axhi = max(axlo, 1e-300), max(axhi, 1e-300)  # defensive: resolve_axis should already guarantee this, but a crash here would take the whole export down
        k0, k1 = floor(Int, log10(axlo)), ceil(Int, log10(axhi))
        vals = [10.0^k for k in k0:k1 if axlo <= 10.0^k <= axhi]
        isempty(vals) && (vals = [axlo, axhi])
        return vals, svg_tick_label.(vals)
    end
    # ax.lo/ax.hi are in whatever order svg_frac needs to map the axis's own direction -
    # a plain explicit range given high-to-low (e.g. the Ca-amphibole panels'
    # xaxis_range=[8.0, 5.5], the only signal that axis is reversed, since it never sets
    # autorange="reversed") reaches here with ax.lo > ax.hi. svg_nice_ticks needs them
    # ascending, or it gives up and returns a single tick at ax.lo instead of a spread
    # across the axis.
    vals = svg_nice_ticks(axlo, axhi)
    return vals, svg_tick_label.(vals)
end

"""
    axis_position(ax, v)

    Where value `v` (a category label when `ax.kind == :category`, else a number)
    sits on axis `ax`, in `ax`'s own data units (its index for a category axis).
"""
function axis_position(ax::PAxis, v)
    if ax.kind == :category
        v isa AbstractString || return nothing
        i = findfirst(==(v), ax.categories)
        return i === nothing ? nothing : Float64(i - 1)
    end
    return v isa Real ? Float64(v) : nothing
end

# --------------------------------------------------------------- main entry --

"""
    plotly_export_svg(fig, path; canvas_title = nothing)

    Write `fig` (a Plotly figure - `PlotlyBase.Plot`, or the `JSON3.Object` a
    `dcc_graph`'s `figure` `State` hands a callback straight from the browser) to
    `path` as a clean, layered SVG. Handles `scatter`/`bar`/`scatterternary` traces;
    linear, log and category axes; `stackgroup="one"` areas and `barmode="stack"`
    bars; a data-driven marker `colorscale` with its `colorbar`; annotations; and a
    legend (including the boxed size-key style the classification diagrams use).
    Anything else - a trace type or layout feature none of these 27 figures use - is
    skipped, not approximated, and named in the returned `warnings`.

    Layers, in paint order: one per real (non-dummy) trace, named after it (falling
    back to `Trace_k`) with the group id de-duplicated per phase/oxide name across
    traces so e.g. every "TAS field boundary" line shares one `Field_boundaries`
    layer while the sample points get their own `Samples` layer; `Labels` (the
    layout's annotations); `Layout` (frame, ticks, axis titles, figure title);
    `Colorbar`, when a trace has a data-driven marker colour; `Legend`.

    Returns `(path, bytes, n_paths, warnings)`.
"""
function plotly_export_svg(fig, path::AbstractString; canvas_title::Union{Nothing,AbstractString} = nothing, config = nothing,
                            extra_info::Union{Nothing,Tuple{String,String}} = nothing)
    layout = pget(fig, :layout)
    raw_traces = pget(fig, :data, default = [])
    warnings = String[]

    traces = PTrace[]
    for tr in raw_traces
        pt = build_ptrace(tr)
        if pt.kind == :other
            push!(warnings, "skipped a $(pstr(pget(tr,:type)) === nothing ? "trace" : pget(tr,:type)) trace (unsupported type)")
            continue
        end
        push!(traces, pt)
    end

    title = something(canvas_title, something(pstr(pget(pget(layout, :title), :text)), something(pstr(pget(layout, :title)), "")))

    if any(t -> t.kind == :scatterternary, traces)
        return plotly_export_ternary_svg(traces, layout, path, title, warnings)
    end
    return plotly_export_cartesian_svg(traces, layout, path, title, warnings; config = config, extra_info = extra_info)
end

"""
    trace_layer_id(tr, seen, boundary_group)

    The group id a trace should draw into: an unnamed thin black polyline with no
    markers (a classification field boundary) shares `boundary_group` (so 15
    boundary lines become one `Field_boundaries` layer); otherwise the trace's own
    name (or `Trace_k`, unique per [`svg_id`](@ref)).
"""
function trace_layer_id(tr::PTrace, k::Int, seen::Set{String}, boundary_group::Union{Nothing,String})
    if boundary_group !== nothing && isempty(tr.name) && tr.mode == "lines" && tr.marker_color === nothing
        boundary_group in seen && return boundary_group
        return svg_id(seen, boundary_group)
    end
    base = isempty(tr.name) ? "Trace_$(k)" : tr.name
    return svg_id(seen, base)
end

"""
    merge_boundary_traces(real)

    `real` with every "classification field boundary" trace (unnamed, `mode ==
    "lines"`, no marker colour, not stacked - what the 15 TAS/AFM/mineral-panel field
    outlines all look like) combined into one, at the position of the first one, its
    `x`/`y` the originals concatenated with a `nothing` separator between each (so
    [`svg_split_polylines`](@ref) draws them as separate polylines within one layer).

    This exists because the draw loop opens and closes one `<g>` per trace it
    iterates: giving 15 separate boundary traces the *same* resolved layer id
    (`Field_boundaries`, via [`trace_layer_id`](@ref)) does not merge them into one
    `<g>` - it opens 15 sibling `<g>` elements that all happen to carry that id,
    which is invalid SVG (duplicate ids) and was exactly what a real TAS export
    produced before this existed. Merging the traces themselves, before the draw
    loop ever sees them, is what actually produces one layer.
"""
function merge_boundary_traces(real::Vector{PTrace})
    is_boundary(tr) = isempty(tr.name) && tr.mode == "lines" && tr.marker_color === nothing && tr.stackgroup === nothing && tr.kind == :scatter
    boundaries = filter(is_boundary, real)
    length(boundaries) <= 1 && return real

    mx, my = Any[], Any[]
    for tr in boundaries
        isempty(mx) || (push!(mx, nothing); push!(my, nothing))
        append!(mx, tr.x)
        append!(my, tr.y)
    end
    p = boundaries[1]
    merged = PTrace(p.kind, mx, my, p.a, p.b, p.c, p.name, p.showlegend, p.mode, p.line_color, p.line_width, p.line_dash,
                     p.marker_color, p.marker_size, p.marker_symbol, p.marker_opacity, p.marker_line_color, p.marker_line_width,
                     p.colorscale, p.colorscale_reverse, p.showscale, p.colorbar_title, p.stackgroup, p.opacity)

    first_idx = findfirst(is_boundary, real)
    out = PTrace[]
    for (i, tr) in enumerate(real)
        if is_boundary(tr)
            i == first_idx && push!(out, merged)
        else
            push!(out, tr)
        end
    end
    return out
end

"""
    trace_position_sums(tr, xax)

    `tr`'s own `y` values summed by x position (`axis_position(xax, ·)`), as a
    `Dict{Float64,Float64}` in first-seen order is not needed since the caller sorts
    by key. Two path steps that round to the same category label are a real
    possibility (`"P; T"` rounded to one decimal), and a stacked chart must treat
    that trace's own repeat as one combined point, not add it into the running
    cross-trace total a second time - without this, a repeated category would push
    a stacked band's top arbitrarily high (points end up off the canvas).
"""
function trace_position_sums(tr::PTrace, xax::PAxis)
    sums = Dict{Float64,Float64}()
    for (xi, yi) in zip(tr.x, tr.y)
        pos = axis_position(xax, xi)
        (pos === nothing || !(yi isa Real)) && continue
        sums[pos] = get(sums, pos, 0.0) + yi
    end
    return sums
end

"""
    plotly_export_cartesian_svg(traces, layout, path, title, warnings)

    The non-ternary path of [`plotly_export_svg`](@ref).
"""
function plotly_export_cartesian_svg(traces::Vector{PTrace}, layout, path::AbstractString, title::AbstractString, warnings::Vector{String};
                                      config = nothing, extra_info::Union{Nothing,Tuple{String,String}} = nothing)
    real  = filter(!ptrace_dummy, traces)
    dummy = filter(ptrace_dummy, traces)
    real  = merge_boundary_traces(real)

    has_colorbar = any(t -> t.showscale, real)
    has_legend   = any(t -> t.showlegend && !isempty(t.name), real) || !isempty(dummy)
    # every one of these figures' own callback sets toImageButtonOptions.width/height
    # as the size it intends this exact figure to be downloaded at - a much better
    # aspect-ratio source than layout.width/height, which most of these figures never
    # set at all (they size themselves to their container in the browser instead)
    dl = pget(config, :toImageButtonOptions)
    lw = pnum(pget(dl, :width));  lw === nothing && (lw = pnum(pget(layout, :width)))
    lh = pnum(pget(dl, :height)); lh === nothing && (lh = pnum(pget(layout, :height)))
    pw = 650.0
    ph = (lw !== nothing && lh !== nothing && lw > 0) ? clamp(pw * lh / lw, 180.0, 650.0) : (lh !== nothing ? clamp(lh, 180.0, 650.0) : 420.0)

    xaxis_l, yaxis_l = pget(layout, :xaxis), pget(layout, :yaxis)
    legend_l = pget(layout, :legend)
    legend_above = pstr(pget(legend_l, :orientation)) == "h" && something(pnum(pget(legend_l, :y)), 0.0) >= 0.95

    mt = (isempty(title) ? 26.0 : 46.0) + (legend_above ? 26.0 : 0.0)
    mb = 46.0 + (something(pnum(pget(xaxis_l, :tickangle)), 0.0) != 0 ? 22.0 : 0.0)
    ml = 66.0
    mr = (has_colorbar || has_legend) ? 176.0 : 30.0

    barmode = pstr(pget(layout, :barmode))

    xax0 = resolve_axis(xaxis_l, real, :x)

    # stacking pass: per-x cumulative tops, needed for the y-range and for drawing
    stack_top = Dict{Float64,Float64}()
    for tr in real
        (tr.stackgroup !== nothing || (tr.kind == :bar && barmode == "stack")) || continue
        for (pos, ysum) in trace_position_sums(tr, xax0)
            stack_top[pos] = get(stack_top, pos, 0.0) + ysum
        end
    end
    stacked_hi = isempty(stack_top) ? nothing : maximum(values(stack_top))

    yax = resolve_axis(yaxis_l, real, :y; stacked_hi = stacked_hi)
    xax = xax0
    if xax.reversed
        xax = PAxis(xax.kind, xax.hi, xax.lo, xax.categories, xax.tickvals, xax.ticklabels, xax.tick_angle, xax.title, false)
    end
    if yax.reversed
        yax = PAxis(yax.kind, yax.hi, yax.lo, yax.categories, yax.tickvals, yax.ticklabels, yax.tick_angle, yax.title, false)
    end

    info = extra_info === nothing ? String[] : [extra_info[1], extra_info[2]]
    info_h = svg_info_height(info)
    # extra room goes into the bottom margin, not into a taller plot area - ph itself
    # (the data plot's own height) must stay exactly what it was computed to be above,
    # same as pd_export_svg keeps its own 590px plot area fixed and grows `mb` instead.
    # mb0 (the original tick-label/axis-title allowance) is kept so the info box starts
    # after that zone, not right at the frame edge where it would overlap the ticks.
    mb0 = mb
    mb += info_h > 0 ? info_h + 24 : 0.0

    width  = ml + pw + mr
    height = mt + ph + mb
    c = SVGCanvas(width, height, ml, mr, mt, mb, xax.lo, xax.hi, yax.lo, yax.hi, xax.kind == :log, yax.kind == :log)
    # xax.lo/xax.hi are in whatever order svg_frac needs for this axis's own direction
    # (svg_frac's plain (v-lo)/(hi-lo) already draws a reversed axis correctly from
    # that, no matter which of lo/hi is bigger) - clipping and point-visibility below
    # need them sorted, same as yax already is via min/max at each of its own uses.
    xlo, xhi = xax.lo <= xax.hi ? (xax.lo, xax.hi) : (xax.hi, xax.lo)

    seen = Set{String}()
    io   = IOBuffer()
    n_paths = 0
    svg_open(io, c; xlink = false)

    # a "classification field boundary" trace: unnamed thin black lines, no markers
    is_boundary(tr) = isempty(tr.name) && tr.mode == "lines" && tr.marker_color === nothing && tr.stackgroup === nothing
    boundary_group = any(is_boundary, real) ? "Field_boundaries" : nothing

    running = Dict{Float64,Float64}()  # per-x cumulative base, refilled per stacking group as traces are drawn
    for (k, tr) in enumerate(real)
        id = trace_layer_id(tr, k, seen, boundary_group)   # already unique/registered - use as-is, never re-wrap in svg_id
        color, _ = svg_css_color(ptrace_color(tr))
        line_dash = svg_dasharray(tr.line_dash, tr.line_width)

        if tr.kind == :bar
            mcol, mop = svg_css_color(tr.marker_color isa AbstractString ? tr.marker_color : "#888888")
            svg_group_open(io, id; fill = mcol, opacity = something(mop, tr.opacity))
            barw = xax.kind == :category ? svg_plot_width(c) / max(length(xax.categories), 1) * 0.62 : 4.0
            for (pos, ysum) in sort(collect(trace_position_sums(tr, xax)); by = first)
                base = get(running, pos, 0.0)
                top  = barmode == "stack" ? base + ysum : ysum
                x1, x2 = svg_x(c, pos) - barw / 2, svg_x(c, pos) + barw / 2
                y1, y2 = svg_y(c, base), svg_y(c, top)
                svg_rect(io, svg_id(seen, id * "_$(svg_tick_label(pos))"), min(x1, x2), min(y1, y2), abs(x2 - x1), abs(y2 - y1))
                n_paths += 1
                barmode == "stack" && (running[pos] = top)
            end
            svg_group_close(io)
            continue
        end

        # kept in the trace's own given order, exactly like Plotly itself draws a
        # "lines" trace - it never reorders by x. A closed field-boundary polygon (every
        # classification diagram's field outline) is not x-monotonic, so a `sort!` here
        # (as this used to have) scrambles its vertex order into a zigzag instead of the
        # actual outline, and - worse - eats the `nothing` separator between a merged
        # trace's originally-distinct polylines (merge_boundary_traces), fusing what
        # should be several separate field outlines into one connected mess. An invalid
        # position (a category string with no match, or the `nothing` separator itself)
        # is kept as `(nothing, ...)` rather than dropped, so svg_split_polylines still
        # sees the gap and breaks the polyline there.
        pts = Tuple{Union{Float64,Nothing},Union{Float64,Nothing}}[]
        for (xi, yi) in zip(tr.x, tr.y)
            push!(pts, (axis_position(xax, xi), yi isa Real ? Float64(yi) : nothing))
        end

        if tr.stackgroup !== nothing
            xs, ytop, ybot = Float64[], Float64[], Float64[]
            for (pos, ysum) in sort(collect(trace_position_sums(tr, xax)); by = first)
                base = get(running, pos, 0.0)
                push!(xs, pos); push!(ybot, base); push!(ytop, base + ysum)
                running[pos] = base + ysum
            end
            svg_group_open(io, id; fill = "none")
            d = svg_area_band(c, xs, ytop, ybot)
            if !isempty(d)
                svg_path(io, svg_id(seen, id * "_fill"), d; stroke = "none", fill = color, fill_opacity = 0.65)
                n_paths += 1
            end
            if length(xs) > 1
                topd = svg_path_data(c, [collect(zip(xs, ytop))])
                if !isempty(topd)
                    svg_path(io, svg_id(seen, id * "_line"), topd; stroke = color, width = tr.line_width, dash = line_dash)
                    n_paths += 1
                end
            end
            svg_group_close(io)
            continue
        end

        svg_group_open(io, id; fill = "none")
        if occursin("lines", tr.mode)
            xs = [p[1] for p in pts]; ys = [p[2] for p in pts]
            polylines = svg_split_polylines(xs, ys)
            clipped = reduce(vcat, [svg_clip_polyline(l, xlo, xhi, min(yax.lo, yax.hi), max(yax.lo, yax.hi)) for l in polylines];
                             init = Vector{Vector{Tuple{Float64,Float64}}}())
            d = svg_path_data(c, clipped)
            if !isempty(d)
                svg_path(io, svg_id(seen, id * "_line"), d; stroke = color, width = tr.line_width, dash = line_dash)
                n_paths += 1
            end
        end
        if occursin("markers", tr.mode)
            colorat = ptrace_color_lookup(tr)
            lc2, _ = tr.marker_line_color === nothing ? (nothing, nothing) : svg_css_color(tr.marker_line_color)
            for (i, (pos, yi)) in enumerate(pts)
                (pos === nothing || yi === nothing) && continue
                (xlo <= pos <= xhi && min(yax.lo, yax.hi) <= yi <= max(yax.lo, yax.hi)) || continue
                cx, cy = svg_x(c, pos), svg_y(c, yi)
                r = marker_radius(tr, i, length(pts))
                svg_marker(io, svg_id(seen, id * "_pt_$(i)"), cx, cy, r, tr.marker_symbol;
                           fill = colorat(i), stroke = lc2, width = lc2 === nothing ? nothing : tr.marker_line_width, opacity = tr.opacity * tr.marker_opacity)
                n_paths += 1
            end
        end
        svg_group_close(io)
    end

    if !isempty(pget(layout, :annotations, default = []))
        plotly_annotations_layer(io, c, seen, pget(layout, :annotations))
    end

    nxt, nxl = axis_ticks(xax)
    nyt, nyl = axis_ticks(yax)
    svg_layout_layers(io, c, seen; xticks = nxt, yticks = nyt, xtitle = xax.title, ytitle = yax.title, title = title,
                       xticklabels = nxl, yticklabels = nyl, xtick_angle = xax.tick_angle)

    ycur = c.mt
    if has_colorbar
        tr = real[findfirst(t -> t.showscale, real)]
        stops = svg_colorscale(tr.colorscale; reverse = tr.colorscale_reverse)
        vals  = Float64[v for v in tr.marker_color if v isa Real]
        zmin, zmax = isempty(vals) ? (0.0, 1.0) : (minimum(vals), maximum(vals))
        bar_x, bar_w, bar_h = c.ml + svg_plot_width(c) + 26, 12.0, 130.0
        svg_group_open(io, svg_id(seen, "Colorbar"); font_family = "Helvetica, Arial, sans-serif", font_size = 10, fill = "#333333")
        svg_gradient_bar_stops(io, svg_id(seen, "Colorbar_bar"), bar_x, ycur, bar_w, bar_h, stops)
        for (k2, v) in enumerate(svg_nice_ticks(zmin, zmax; target = 5))
            t = zmax == zmin ? 0.0 : (v - zmin) / (zmax - zmin)
            svg_text(io, bar_x + bar_w + 5, ycur + bar_h * (1 - t), svg_tick_label(v); id = svg_id(seen, "Colorbar_tick_$(k2)"), anchor = "start")
        end
        tr.colorbar_title === nothing || svg_text(io, bar_x + bar_w + 46, ycur + bar_h / 2, tr.colorbar_title;
                                                    id = svg_id(seen, "Colorbar_title"), size = 11, anchor = "middle", rotate = 90)
        svg_group_close(io)
        ycur += bar_h + 24
    end

    if !isempty(dummy)
        entries = [(label = something(t.name, ""), color = "#888888", dash = nothing, width = nothing,
                    marker = something(t.marker_size isa Number ? t.marker_size : nothing, 8.0)) for t in dummy]
        svg_legend_layer(io, seen, entries; x = c.ml + svg_plot_width(c) + 20, y = ycur, id = "Size_legend", box = true)
        ycur += length(entries) * 17.0 + 24
    end

    named = filter(t -> t.showlegend && !isempty(t.name), real)
    if !isempty(named)
        entries = [(label = t.name, color = ptrace_color(t), dash = t.line_dash, width = t.line_width, marker = nothing) for t in named]
        if legend_above
            legend_right = pstr(pget(legend_l, :xanchor)) == "right"
            svg_legend_layer(io, seen, entries; x = c.ml, y = 14.0, id = "Legend", horizontal = true,
                              right_edge = legend_right ? c.ml + svg_plot_width(c) : nothing)
        else
            svg_legend_layer(io, seen, entries; x = c.ml + svg_plot_width(c) + 20, y = ycur, id = "Legend")
        end
    end

    svg_info_layer(io, seen, info; left = c.ml, y = c.mt + ph + mb0 + 14, pw = svg_plot_width(c))

    svg_close(io)
    bytes = take!(io)
    write(path, bytes)
    return (path = String(path), bytes = length(bytes), n_paths = n_paths, warnings = warnings)
end

"""
    plotly_annotations_layer(io, c, seen, annotations)

    Field-name labels from `layout.annotations` (data-referenced `xref="x"`/
    `yref="y"`, visible, non-empty text), as real `<text>`. A self-contained
    counterpart to [`svg_annotation_layer`](@ref) (that one assumes a
    `PlotlyBase.PlotlyAttribute`, via its `.fields`; annotations taken from the
    browser are a `JSON3.Object` instead, which has no `.fields`, so this reads
    them with [`pget`](@ref), which works on either).
"""
function plotly_annotations_layer(io::IO, c::SVGCanvas, seen::Set{String}, annotations)
    svg_group_open(io, svg_id(seen, "Labels"); fill = "#212121", font_family = "Helvetica, Arial, sans-serif", font_size = 10, anchor = "middle")
    for (i, ann) in enumerate(annotations)
        (pget(ann, :visible; default = true) == true && pstr(pget(ann, :xref)) == "x" && pstr(pget(ann, :yref)) == "y") || continue
        txt = pstr(pget(ann, :text))
        txt === nothing && continue
        x, y = pnum(pget(ann, :x)), pnum(pget(ann, :y))
        (x === nothing || y === nothing) && continue
        fsize = something(pnum(pget(pget(ann, :font), :size)), 10.0)
        svg_text(io, svg_x(c, x), svg_y(c, y), txt; id = svg_id(seen, "Label_$(lpad(i, 3, '0'))"), size = fsize)
    end
    svg_group_close(io)
end

# -------------------------------------------------------------------- ternary --

"""
    plotly_export_ternary_svg(traces, layout, path, title, warnings)

    The `scatterternary` path of [`plotly_export_svg`](@ref) (the AFM diagram): an
    equilateral triangle, `a` at the top vertex, `b` at bottom-right, `c` at
    bottom-left (Plotly's own convention), `sum = a+b+c` normalised to
    `layout.ternary.sum` (default 100); axis titles from `ternary.aaxis`/`baxis`/
    `caxis`; 20% gridlines; sample points and their legend/colorbar exactly as the
    cartesian path.
"""
function plotly_export_ternary_svg(traces::Vector{PTrace}, layout, path::AbstractString, title::AbstractString, warnings::Vector{String})
    real  = filter(!ptrace_dummy, traces)
    dummy = filter(ptrace_dummy, traces)
    tern  = pget(layout, :ternary)
    asum  = something(pnum(pget(tern, :sum)), 100.0)
    atitle = something(pstr(pget(pget(pget(tern, :aaxis), :title), :text)), something(pstr(pget(pget(tern, :aaxis), :title)), "A"))
    btitle = something(pstr(pget(pget(pget(tern, :baxis), :title), :text)), something(pstr(pget(pget(tern, :baxis), :title)), "B"))
    ctitle = something(pstr(pget(pget(pget(tern, :caxis), :title), :text)), something(pstr(pget(pget(tern, :caxis), :title)), "C"))

    side  = 480.0
    ml, mt = 90.0, (isempty(title) ? 40.0 : 64.0)   # extra room above the top vertex's own axis title when there is a figure title too
    has_colorbar = any(t -> t.showscale, real)
    has_legend   = !isempty(dummy) || any(t -> t.showlegend && !isempty(t.name), real)
    mr = (has_colorbar || has_legend) ? 200.0 : 60.0
    width  = ml + side + mr
    height = mt + side * (sqrt(3) / 2) + 70.0
    top    = (Float64(ml + side / 2), Float64(mt))
    right  = (Float64(ml + side), Float64(mt + side * sqrt(3) / 2))
    left   = (Float64(ml), Float64(mt + side * sqrt(3) / 2))
    tern_xy(a, b, cc) = begin
        s = a + b + cc
        s == 0 && return ((left[1] + right[1] + top[1]) / 3, (left[2] + right[2] + top[2]) / 3)
        u, v = b / s, cc / s  # barycentric weight of "right" and "left"; top weight = a/s = 1-u-v
        (u * right[1] + v * left[1] + (1 - u - v) * top[1], u * right[2] + v * left[2] + (1 - u - v) * top[2])
    end

    # a plain SVGCanvas just to carry width/height to svg_open; ternary points are placed with
    # this function's own tern_xy, not svg_x/svg_y, since barycentric coordinates are not a
    # rectangular data window
    c = SVGCanvas(width, height, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0)
    seen = Set{String}()
    io   = IOBuffer()
    n_paths = 0
    svg_open(io, c)

    svg_group_open(io, svg_id(seen, "Frame"); stroke = "#333333", width = 1, fill = "none")
    svg_path(io, svg_id(seen, "Frame_triangle"), "M$(svg_num(top[1])) $(svg_num(top[2])) L$(svg_num(right[1])) $(svg_num(right[2])) L$(svg_num(left[1])) $(svg_num(left[2])) Z")
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Gridlines"); stroke = "#cccccc", width = 0.5, fill = "none")
    for f in 0.2:0.2:0.8
        p1, p2 = tern_xy(asum * (1 - f), asum * f, 0.0), tern_xy(asum * (1 - f), 0.0, asum * f)
        svg_line(io, p1[1], p1[2], p2[1], p2[2])
        p1, p2 = tern_xy(0.0, asum * f, asum * (1 - f)), tern_xy(asum * (1 - f), asum * f, 0.0)
        svg_line(io, p1[1], p1[2], p2[1], p2[2])
        p1, p2 = tern_xy(0.0, asum * (1 - f), asum * f), tern_xy(asum * f, 0.0, asum * (1 - f))
        svg_line(io, p1[1], p1[2], p2[1], p2[2])
    end
    svg_group_close(io)

    for (k, tr) in enumerate(real)
        id = svg_id(seen, isempty(tr.name) ? "Trace_$(k)" : tr.name)
        colorat = ptrace_color_lookup(tr)
        lc2, _ = tr.marker_line_color === nothing ? (nothing, nothing) : svg_css_color(tr.marker_line_color)
        svg_group_open(io, id; fill = "none")
        n = length(tr.a)
        for i in 1:n
            av, bv, cv = tr.a[i], tr.b[i], tr.c[i]
            (av isa Real && bv isa Real && cv isa Real) || continue
            cx, cy = tern_xy(av, bv, cv)
            r = marker_radius(tr, i, n)
            svg_marker(io, svg_id(seen, id * "_pt_$(i)"), cx, cy, r, tr.marker_symbol;
                       fill = colorat(i), stroke = lc2, width = lc2 === nothing ? nothing : tr.marker_line_width, opacity = tr.opacity * tr.marker_opacity)
            n_paths += 1
        end
        svg_group_close(io)
    end

    svg_group_open(io, svg_id(seen, "Axis_titles"); fill = "#333333", font_family = "Helvetica, Arial, sans-serif", font_size = 12, anchor = "middle")
    svg_text(io, top[1], top[2] - 18, atitle; id = svg_id(seen, "Axis_title_a"))
    svg_text(io, right[1] + 30, right[2] + 12, btitle; id = svg_id(seen, "Axis_title_b"))
    svg_text(io, left[1] - 30, left[2] + 12, ctitle; id = svg_id(seen, "Axis_title_c"))
    svg_group_close(io)

    if !isempty(title)
        svg_group_open(io, svg_id(seen, "Title"); fill = "#333333", font_family = "Helvetica, Arial, sans-serif", font_size = 14, anchor = "middle")
        svg_text(io, width / 2, 18, title; id = svg_id(seen, "Figure_title"), weight = "bold")
        svg_group_close(io)
    end

    ycur = mt
    if has_colorbar
        tr = real[findfirst(t -> t.showscale, real)]
        stops = svg_colorscale(tr.colorscale; reverse = tr.colorscale_reverse)
        vals  = Float64[v for v in tr.marker_color if v isa Real]
        zmin, zmax = isempty(vals) ? (0.0, 1.0) : (minimum(vals), maximum(vals))
        bar_x, bar_w, bar_h = ml + side + 26, 12.0, 130.0
        svg_group_open(io, svg_id(seen, "Colorbar"); font_family = "Helvetica, Arial, sans-serif", font_size = 10, fill = "#333333")
        svg_gradient_bar_stops(io, svg_id(seen, "Colorbar_bar"), bar_x, ycur, bar_w, bar_h, stops)
        for (k2, v) in enumerate(svg_nice_ticks(zmin, zmax; target = 5))
            t = zmax == zmin ? 0.0 : (v - zmin) / (zmax - zmin)
            svg_text(io, bar_x + bar_w + 5, ycur + bar_h * (1 - t), svg_tick_label(v); id = svg_id(seen, "Colorbar_tick_$(k2)"), anchor = "start")
        end
        tr.colorbar_title === nothing || svg_text(io, bar_x + bar_w + 46, ycur + bar_h / 2, tr.colorbar_title;
                                                    id = svg_id(seen, "Colorbar_title"), size = 11, anchor = "middle", rotate = 90)
        svg_group_close(io)
        ycur += bar_h + 24
    end
    if !isempty(dummy)
        entries = [(label = something(t.name, ""), color = "#888888", dash = nothing, width = nothing,
                    marker = something(t.marker_size isa Number ? t.marker_size : nothing, 8.0)) for t in dummy]
        svg_legend_layer(io, seen, entries; x = ml + side + 20, y = ycur, id = "Size_legend", box = true)
    end

    svg_close(io)
    bytes = take!(io)
    write(path, bytes)
    return (path = String(path), bytes = length(bytes), n_paths = n_paths, warnings = warnings)
end

# ---------------------------------------------------------------- wiring --

"""
    svg_export_button_row(graph_id)

    A right-aligned "Export svg" button with a status text to its left, meant to sit
    directly above the `dcc_graph` `graph_id`. Ids are derived from `graph_id`
    (`<graph_id>-svg-button`/`-svg-status`), so a row and its
    [`register_svg_export!`](@ref) call always agree without repeating the ids by
    hand at each of the ~30 call sites this is used from.
"""
function svg_export_button_row(graph_id::AbstractString)
    dbc_row([
        dbc_col([
            html_div(id = graph_id * "-svg-status", children = "",
                     style = Dict("display" => "inline-block", "font-size" => "75%", "color" => "grey",
                                  "marginRight" => "10px", "verticalAlign" => "middle", "wordBreak" => "break-all")),
            dbc_button("Export svg", id = graph_id * "-svg-button", color = "light", n_clicks = 0,
                       style = Dict("font-size" => "80%", "border" => "1px grey solid")),
        ], width = "auto"),
    ], justify = "end", style = Dict("marginBottom" => "4px"))
end

"""
    register_svg_export!(app, graph_id, filename_stem; extra_states = (), info_fn = nothing)

    Register the export callback for one figure: clicking `<graph_id>-svg-button`
    (from [`svg_export_button_row`](@ref)) reads the figure straight off
    `<graph_id>` (`State(graph_id, "figure")` - exactly what is on screen, no other
    global needed) and writes it with [`plotly_export_svg`](@ref) to
    `<output_dir><filename_stem>.svg`, reporting the result through
    `pd_export_status` in `<graph_id>-svg-status`. A separate small callback per
    figure (rather than one big one over the whole table) so each one only ever
    reads its own graph and never collides with another Output.

    `extra_states`/`info_fn` add a below-the-plot provenance text box (`extra_info` on
    [`plotly_export_svg`](@ref)) that exists *only* in the exported file - it is built
    fresh, server-side, right here inside the click handler, from whatever globals
    `info_fn` reads (`Out_PTX`/`Out_TE_PTX` for the PTX tab), never added to the figure
    the browser actually displays. `extra_states` is zero or more extra `(component_id,
    prop)` Dash `State`s to read (e.g. `[("te-ptx-step-id", "value"),
    ("normalization-te-ptx", "value")]`, for a figure whose info depends on a UI
    selection); `info_fn` is called with their values, in order, positionally, and must
    return a `(labels, values)` tuple or `nothing`.
"""
function register_svg_export!(app, graph_id::AbstractString, filename_stem::AbstractString;
                               extra_states = (),
                               info_fn::Union{Nothing,Function} = nothing)
    states = Any[State(graph_id, "figure"), State(graph_id, "config")]
    for (cid, prop) in extra_states
        push!(states, State(cid, prop))
    end
    callback!(
        app,
        Output(graph_id * "-svg-status", "children"),
        Input(graph_id * "-svg-button", "n_clicks"),
        states...,
        prevent_initial_call = true,
    ) do cb_args...
        fig, config = cb_args[2], cb_args[3]
        global output_dir
        if fig === nothing || isempty(pget(fig, :data, default = []))
            return pd_export_status("Nothing to export yet - compute/display the figure first."; ok = false)
        end
        try
            mkpath(output_dir[1])
            extra_info = info_fn === nothing ? nothing : info_fn(cb_args[4:end]...)
            r   = plotly_export_svg(fig, output_dir[1] * filename_stem * ".svg"; config = config, extra_info = extra_info)
            msg = "Saved $(r.path) ($(round(r.bytes / 1024, digits = 1)) KB, $(r.n_paths) paths)."
            isempty(r.warnings) || (msg *= " " * join(r.warnings, "; ") * ".")
            return pd_export_status(msg; ok = true)
        catch e
            return pd_export_status("Export failed: " * sprint(showerror, e); ok = false)
        end
    end
    return app
end

"""
    PTX_SVG_EXPORTS

    `(graph_id, filename_stem)` for every result/classification/trace-element figure
    of the "PTX paths" tab that gets an "Export svg" button.
"""
const PTX_SVG_EXPORTS = [
    ("ptx-plot",             "PTX_stable_phase_fraction"),
    ("ptx-field-plot",       "PTX_selected_field_across_path"),
    ("ptx-frac-plot",        "PTX_stable_phase_composition"),
    ("ptx-removed-plot",     "PTX_extracted_composition_stepwise"),
    ("ptx-removed-int-plot", "PTX_extracted_composition_integrated"),
    ("ptx-extracted-plot",   "PTX_extracted_phase_fraction_integrated"),
    ("TAS-plot",             "PTX_TAS_volcanic"),
    ("TAS-pluto-plot",       "PTX_TAS_plutonic"),
    ("AFM-plot",             "PTX_AFM"),
    ("te-fieldbuilder-ptx",  "PTX_TE_fieldbuilder"),
]
# ree-spectrum-ptx (PTX_TE_spectrum) and te-evol-ptx (PTX_TE_evolution) are registered
# separately, in Tab_PTXpaths_Callbacks.jl, with the extra `info_fn` that builds their
# export-only provenance box - see register_svg_export!'s docstring.

"""
    PD_CLASSIFICATION_SVG_EXPORTS

    `(graph_id, filename_stem)` for every classification-diagram figure of the Phase
    diagram tab's offcanvas panels that gets an "Export svg" button.
"""
const PD_CLASSIFICATION_SVG_EXPORTS = [
    ("TAS-plot-pd",           "PhaseDiagram_TAS_volcanic"),
    ("TAS-pluto-plot-pd",     "PhaseDiagram_TAS_plutonic"),
    ("AFM-plot-pd",           "PhaseDiagram_AFM"),
    ("CaAmpPanelA-plot-pd",   "PhaseDiagram_CaAmphibole_A"),
    ("CaAmpPanelB-plot-pd",   "PhaseDiagram_CaAmphibole_B"),
    ("CaAmpPanelC-plot-pd",   "PhaseDiagram_CaAmphibole_C"),
    ("CpxQJ-plot-pd",         "PhaseDiagram_Clinopyroxene_QJ"),
    ("CpxQuad-plot-pd",       "PhaseDiagram_Clinopyroxene_Quad"),
    ("CpxNaPx-plot-pd",       "PhaseDiagram_Clinopyroxene_NaPx"),
    ("OpxQuad-plot-pd",       "PhaseDiagram_Orthopyroxene_Quad"),
    ("MicaInterlayer-plot-pd",  "PhaseDiagram_Mica_Interlayer"),
    ("MicaCeladonite-plot-pd",  "PhaseDiagram_Mica_Celadonite"),
    ("Feldspar-plot-pd",      "PhaseDiagram_Feldspar"),
    ("Garnet-plot-pd",        "PhaseDiagram_Garnet"),
    ("Spinel-plot-pd",        "PhaseDiagram_Spinel"),
    ("Ilmenite-plot-pd",      "PhaseDiagram_Ilmenite"),
]

"""
    register_svg_exports!(app, table)

    [`register_svg_export!`](@ref) for every `(graph_id, filename_stem)` of `table`
    (e.g. [`PTX_SVG_EXPORTS`](@ref), [`PD_CLASSIFICATION_SVG_EXPORTS`](@ref)).
"""
function register_svg_exports!(app, table)
    for (graph_id, stem) in table
        register_svg_export!(app, graph_id, stem)
    end
    return app
end

# --------------------------------------------------------- general figures --

const PLOTLY_COLORWAY = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f",
                         "#bcbd22", "#17becf"]

"""
    GAxis

    A resolved axis of a general figure: name ("x", "y2", ...), kind (`:linear`, `:log`, `:category`), data range
    `lo`→`hi` mapped to pixels `p0`→`p1`, categories, explicit ticks, title, side, pixel position of the axis line,
    visibility, mirror flag, the pixel extent of the perpendicular domain and the font size.
"""
struct GAxis
    name       :: String
    kind       :: Symbol
    lo         :: Float64
    hi         :: Float64
    p0         :: Float64
    p1         :: Float64
    categories :: Vector{String}
    tickvals   :: Union{Nothing,Vector{Float64}}
    ticklabels :: Union{Nothing,Vector{String}}
    title      :: String
    side       :: String
    pos        :: Float64
    visible    :: Bool
    mirror     :: Bool
    other0     :: Float64
    other1     :: Float64
    showlabels :: Bool
end

"""
    gaxis_px(ax::GAxis, v)

    Pixel position of value `v` (a number, or a category label on a category axis) on axis `ax`; `nothing` when it
    has no position.
"""
function gaxis_px(ax::GAxis, v)
    if ax.kind == :category
        v isa AbstractString && (i = findfirst(==(v), ax.categories); return i === nothing ? nothing : gaxis_px(ax, Float64(i - 1)))
        v isa Real || return nothing
    end
    v isa Real || return nothing
    f = ax.kind == :log ? (v > 0 ? (log10(v) - log10(ax.lo)) / (log10(ax.hi) - log10(ax.lo)) : nothing) :
                          (v - ax.lo) / (ax.hi - ax.lo)
    f === nothing && return nothing
    return ax.p0 + f * (ax.p1 - ax.p0)
end

"""
    gaxis_inrange(ax::GAxis, v::Real)

    Whether the data value `v` lies within the range of axis `ax`.
"""
gaxis_inrange(ax::GAxis, v::Real) = min(ax.lo, ax.hi) - 1e-9 * abs(ax.hi - ax.lo) <= v <=
                                    max(ax.lo, ax.hi) + 1e-9 * abs(ax.hi - ax.lo)

"""
    gfig_keys(obj)

    Keys of a layout or trace object (a `PlotlyBase` attribute, a `JSON3.Object` or a `Dict`) as symbols.
"""
gfig_keys(obj) = obj === nothing ? Symbol[] :
                 hasproperty(obj, :fields) && getfield(obj, :fields) isa AbstractDict ? Symbol.(collect(keys(getfield(obj, :fields)))) :
                 Symbol.(collect(keys(obj)))

"""
    gfig_axis_key(name::AbstractString)

    Layout key of axis `name` ("x2" → `:xaxis2`, "y" → `:yaxis`).
"""
gfig_axis_key(name::AbstractString) = Symbol(name[1:1] * "axis" * name[2:end])

"""
    gfig_trace_type(tr)

    Plotly type of trace `tr` ("scatter" when unset).
"""
gfig_trace_type(tr) = something(pstr(pget(tr, :type)), "scatter")

"""
    gfig_visible(tr)

    Whether trace `tr` is drawn (not hidden nor legend-only).
"""
gfig_visible(tr) = (v = pget(tr, :visible; default = true); v === true || v == "true")

"""
    gfig_axis_ref(tr, which::Symbol)

    Axis name ("x", "x2", "y", ...) trace `tr` is drawn on along `which` (`:x` or `:y`).
"""
gfig_axis_ref(tr, which::Symbol) = something(pstr(pget(tr, which == :x ? :xaxis : :yaxis)), string(which))

"""
    gfig_error(tr)

    Symmetric error-bar half lengths of trace `tr` (`error_y` of type "data"), or `nothing`.
"""
function gfig_error(tr)
    e = pget(tr, :error_y)
    (e === nothing || pget(e, :visible; default = true) == false) && return nothing
    a = pvec(e, :array)
    isempty(a) && return nothing
    return a
end

"""
    gfig_bar_width(tr, positions::Vector{Float64}, bargap::Float64)

    Width (data units along the position axis) of every bar of trace `tr` at `positions`: its `width` attribute,
    otherwise the smallest spacing (1 for a single bar) reduced by `bargap`.
"""
function gfig_bar_width(tr, positions::Vector{Float64}, bargap::Float64)
    w = pget(tr, :width)
    w isa Real && return fill(Float64(w), length(positions))
    w !== nothing && (v = pflatten(w); return [x isa Real ? Float64(x) : 0.8 for x in v])
    p = sort(unique(positions))
    d = length(p) > 1 ? minimum(diff(p)) : 1.0
    return fill(d * (1 - bargap), length(positions))
end

"""
    gfig_marker_path(symbol, cx, cy, r)

    SVG path data of a Plotly marker `symbol` of radius `r` [px] at `(cx, cy)`; `nothing` for a circle.
"""
function gfig_marker_path(symbol, cx, cy, r)
    s = symbol === nothing ? "circle" : replace(lowercase(string(symbol)), "-open" => "")
    f(x, y) = "$(svg_num(cx + x)) $(svg_num(cy + y))"
    s == "diamond"     && return "M$(f(0, -1.3r)) L$(f(1.3r, 0)) L$(f(0, 1.3r)) L$(f(-1.3r, 0)) Z"
    s == "square"      && return "M$(f(-r, -r)) L$(f(r, -r)) L$(f(r, r)) L$(f(-r, r)) Z"
    s == "triangle-up" && return "M$(f(0, -1.2r)) L$(f(1.1r, 0.7r)) L$(f(-1.1r, 0.7r)) Z"
    s in ("x", "x-thin") && return "M$(f(-r, -r)) L$(f(r, r)) M$(f(r, -r)) L$(f(-r, r))"
    s == "line-ns"     && return "M$(f(0, -r)) L$(f(0, r))"
    return nothing
end

"""
    gfig_title(t)

    Text of a Plotly title given as a string or as an object with `text`; empty when absent.
"""
gfig_title(t) = t === nothing ? "" : t isa AbstractString ? String(t) : something(pstr(pget(t, :text)), "")

"""
    gfig_group_key(tr)

    Key gathering traces into one layer: the legend group, else the name, else the trace type, axes, mode, colours and
    fill (unnamed traces with the same styling).
"""
function gfig_group_key(tr)
    lg = pstr(pget(tr, :legendgroup))
    lg === nothing || return "lg:" * lg
    nm = pstr(pget(tr, :name))
    nm === nothing || return "nm:" * nm
    return join(("sig", gfig_trace_type(tr), gfig_axis_ref(tr, :x), gfig_axis_ref(tr, :y),
                 something(pstr(pget(tr, :mode)), ""), something(pstr(pget(pget(tr, :line), :color)), ""),
                 something(pstr(pget(tr, :fill)), "")), "|")
end

"""
    gfig_group_label(key::AbstractString, k::Int)

    Layer name of the trace group `key` (its legend group or name; `Group_k` for unnamed traces).
"""
gfig_group_label(key::AbstractString, k::Int) = startswith(key, "sig") ? "Group_$(k)" : key[4:end]

"""
    gfig_named_runs(items)

    Consecutive runs of `items` (shapes or annotations) sharing the same non-empty `name`, as `(name, indices)` pairs;
    unnamed items form runs of one with an empty name.
"""
function gfig_named_runs(items)
    runs = Tuple{String,Vector{Int}}[]
    for (i, it) in enumerate(items)
        nm = something(pstr(pget(it, :name)), "")
        if !isempty(nm) && !isempty(runs) && runs[end][1] == nm
            push!(runs[end][2], i)
        else
            push!(runs, (nm, [i]))
        end
    end
    return runs
end

"""
    gfig_pixel_point(axes, xref, yref, x, y, L, R, T, B)

    Pixel position of a point given in the `xref`/`yref` frames ("paper", "x", "y2", ...) of a figure whose plot area is
    `L`..`R` × `T`..`B`; `nothing` when the point cannot be placed.
"""
function gfig_pixel_point(axes, xref, yref, x, y, L, R, T, B)
    (x isa Real && y isa Real) || return nothing
    px = xref == "paper" ? L + x * (R - L) : (haskey(axes, xref) ? gaxis_px(axes[xref], x) : nothing)
    py = yref == "paper" ? B - y * (B - T) : (haskey(axes, yref) ? gaxis_px(axes[yref], y) : nothing)
    (px === nothing || py === nothing) && return nothing
    return px, py
end

"""
    gfig_text_box(text::AbstractString, fs::Real)

    Approximate width and height [px] of the multi-line Plotly `text` at font size `fs`.
"""
function gfig_text_box(text::AbstractString, fs::Real)
    lines = svg_text_runs(text)
    w     = maximum((sum(length(r[1]) * (r[3] == 1.0 ? 1.0 : 0.7) for r in l; init = 0.0) for l in lines); init = 0.0)
    return 0.56 * fs * w, 1.15 * fs * max(length(lines), 1)
end

"""
    plotly_export_figure_svg(fig, path; config = nothing, underlay = nothing, width = nothing)

    Write any Plotly figure `fig` to `path` as a layered SVG, with multiple and stacked axes (`domain`, `anchor`,
    `overlaying`, `side`, `scaleanchor`), scatter lines (linear and step shapes), markers (per-point symbols),
    `toself` fills, symmetric error bars, vertical and horizontal (stacked) bars, contour lines, heatmaps (cell
    rectangles), pies, layout shapes (`rect`, `line`, `circle`, `path`, data/paper/pixel sizing), annotations,
    colour bars and the legend. `underlay(io, xaxis, yaxis, seen)` replaces the drawing of the heatmap of the main
    axes (e.g. with the true model cells). Returns `(path, bytes, n_paths, warnings)`.
"""
function plotly_export_figure_svg(fig, path::AbstractString; config = nothing, underlay = nothing, width = nothing)
    layout   = pget(fig, :layout)
    traces   = [tr for tr in pget(fig, :data, default = []) if gfig_visible(tr)]
    warnings = String[]
    dl       = pget(config, :toImageButtonOptions)
    W        = Float64(something(width, pnum(pget(dl, :width)), pnum(pget(layout, :width)), 1000.0))
    H        = Float64(something(pnum(pget(layout, :height)), pnum(pget(dl, :height)), 450.0))
    mg       = pget(layout, :margin)
    ml, mr   = something(pnum(pget(mg, :l)), 80.0), something(pnum(pget(mg, :r)), 80.0)
    mt, mb   = something(pnum(pget(mg, :t)), 100.0), something(pnum(pget(mg, :b)), 80.0)
    L, R, T, B = ml, W - mr, mt, H - mb
    barmode  = something(pstr(pget(layout, :barmode)), "group")
    bargap   = something(pnum(pget(layout, :bargap)), 0.2)

    names = Set{String}()
    for tr in traces
        gfig_trace_type(tr) == "pie" && continue
        push!(names, gfig_axis_ref(tr, :x), gfig_axis_ref(tr, :y))
    end
    for k in gfig_keys(layout)
        m = match(r"^([xy])axis(\d*)$", string(k))
        m === nothing || push!(names, m.captures[1] * m.captures[2])
    end

    vals    = Dict(n => Float64[] for n in names)
    cats    = Dict(n => String[] for n in names)
    stacked = Dict{Tuple{String,String,Float64},Float64}()
    for tr in traces
        t = gfig_trace_type(tr)
        t == "pie" && continue
        xn, yn = gfig_axis_ref(tr, :x), gfig_axis_ref(tr, :y)
        xs, ys = pvec(tr, :x), pvec(tr, :y)
        for (n, v) in ((xn, xs), (yn, ys)), e in v
            e isa AbstractString ? (e in cats[n] || push!(cats[n], e)) : (e isa Real && push!(vals[n], e))
        end
        err = gfig_error(tr)
        if err !== nothing
            for (i, y) in enumerate(ys)
                (y isa Real && i <= length(err) && err[i] isa Real) && push!(vals[yn], y + err[i], y - err[i])
            end
        end
        if t == "bar"
            h = pstr(pget(tr, :orientation)) == "h"
            vn, pn = h ? (xn, yn) : (yn, xn)
            push!(vals[vn], 0.0)
            if barmode == "stack"
                for (p, v) in zip(h ? ys : xs, h ? xs : ys)
                    (p isa Real && v isa Real) || continue
                    k = (pn, vn, Float64(p))
                    stacked[k] = get(stacked, k, 0.0) + v
                    push!(vals[vn], stacked[k])
                end
            end
            p = Float64[v for v in (h ? ys : xs) if v isa Real]
            if !isempty(p)
                w = gfig_bar_width(tr, p, bargap)
                append!(vals[pn], p .- w ./ 2, p .+ w ./ 2)
            end
        end
        if t in ("heatmap", "contour")
            for (n, v) in ((xn, xs), (yn, ys))
                num = Float64[e for e in v if e isa Real]
                length(num) > 1 && (d = (num[end] - num[1]) / (length(num) - 1); append!(vals[n], [num[1] - d / 2, num[end] + d / 2]))
            end
        end
        t in ("scatter", "scattergl", "bar", "heatmap", "contour") || push!(warnings, "skipped a $t trace")
    end

    raw = Dict{String,Any}()
    for n in names
        al  = pget(layout, gfig_axis_key(n))
        typ = pstr(pget(al, :type))
        rng = pget(al, :range)
        kind = typ == "log" ? :log : (typ == "category" || (typ === nothing && !isempty(cats[n]))) ? :category : :linear
        if kind == :category
            c   = isempty(cats[n]) ? ["1"] : cats[n]
            lo, hi = -0.5, length(c) - 0.5
            rng === nothing || (r = Float64.(pflatten(rng)); (lo, hi) = (r[1], r[2]))
        elseif rng !== nothing
            r = Float64.(pflatten(rng))
            lo, hi = kind == :log ? (10.0^r[1], 10.0^r[2]) : (r[1], r[2])
        else
            v = kind == :log ? filter(>(0), vals[n]) : vals[n]
            if isempty(v)
                lo, hi = kind == :log ? (1.0, 10.0) : (0.0, 1.0)
            elseif kind == :log
                a, b = log10(minimum(v)), log10(maximum(v))
                p = max(0.06 * (b - a), 0.1)
                lo, hi = 10.0^(a - p), 10.0^(b + p)
            else
                a, b = minimum(v), maximum(v)
                p = b > a ? 0.06 * (b - a) : max(abs(b), 1.0) * 0.1
                lo, hi = a - p, b + p
            end
            pstr(pget(al, :rangemode)) == "tozero" && kind == :linear && (lo = min(lo, 0.0); hi = max(hi, 0.0))
            pstr(pget(al, :autorange)) == "reversed" && ((lo, hi) = (hi, lo))
        end
        raw[n] = (al = al, kind = kind, lo = lo, hi = hi, cats = kind == :category ? (isempty(cats[n]) ? ["1"] : cats[n]) : String[])
    end

    dom(n) = (al = raw[n].al; ov = pstr(pget(al, :overlaying));
              ov !== nothing && haskey(raw, ov) ? dom(ov) : (d = pget(al, :domain); d === nothing ? (0.0, 1.0) : Tuple(Float64.(pflatten(d)))))
    pix = Dict{String,Tuple{Float64,Float64}}()
    for n in names
        d0, d1 = dom(n)
        pix[n] = n[1] == 'x' ? (L + d0 * (R - L), L + d1 * (R - L)) : (B - d0 * (B - T), B - d1 * (B - T))
    end
    for n in names
        n[1] == 'y' || continue
        sa = pstr(pget(raw[n].al, :scaleanchor))
        (sa === nothing || !haskey(raw, sa) || raw[n].kind != :linear || raw[sa].kind != :linear) && continue
        ratio = something(pnum(pget(raw[n].al, :scaleratio)), 1.0)
        rx, ry = raw[sa], raw[n]
        ux = abs(pix[sa][2] - pix[sa][1]) / abs(rx.hi - rx.lo)
        uy = abs(pix[n][2] - pix[n][1]) / abs(ry.hi - ry.lo) / ratio
        if uy > ux
            span = abs(pix[n][2] - pix[n][1]) / (ux * ratio)
            c    = (ry.lo + ry.hi) / 2
            s    = sign(ry.hi - ry.lo)
            raw[n] = (al = ry.al, kind = ry.kind, lo = c - s * span / 2, hi = c + s * span / 2, cats = ry.cats)
        else
            span = abs(pix[sa][2] - pix[sa][1]) / (uy * ratio)
            c    = (rx.lo + rx.hi) / 2
            s    = sign(rx.hi - rx.lo)
            raw[sa] = (al = rx.al, kind = rx.kind, lo = c - s * span / 2, hi = c + s * span / 2, cats = rx.cats)
        end
    end

    axes = Dict{String,GAxis}()
    for n in names
        r      = raw[n]
        al     = r.al
        isx    = n[1] == 'x'
        anchor = something(pstr(pget(al, :anchor)), isx ? "y" : "x")
        side   = something(pstr(pget(al, :side)), isx ? "bottom" : "left")
        other  = haskey(pix, anchor) ? pix[anchor] : (isx ? (B, T) : (L, R))
        pos    = isx ? (side == "top" ? min(other...) : max(other...)) : (side == "right" ? max(other...) : min(other...))
        tv     = pget(al, :tickvals)
        tl     = pget(al, :ticktext)
        title  = gfig_title(pget(al, :title))
        vis    = pget(al, :visible; default = true) != false
        axes[n] = GAxis(n, r.kind, r.lo, r.hi, pix[n][1], pix[n][2], r.cats,
                        tv === nothing ? nothing : Float64.([x for x in pflatten(tv) if x isa Real]),
                        tl === nothing ? nothing : String.(string.(pflatten(tl))),
                        title, side, pos, vis, pget(al, :mirror; default = false) == true,
                        min(other...), max(other...), pget(al, :showticklabels; default = true) != false)
    end

    seen    = Set{String}()
    io      = IOBuffer()
    n_paths = 0
    legend_extra = 0.0
    lg      = pget(layout, :legend)
    named   = [k for (k, tr) in enumerate(traces) if !isempty(something(pstr(pget(tr, :name)), "")) &&
               pget(tr, :showlegend; default = true) != false && gfig_trace_type(tr) != "pie"]
    show_lg = pget(layout, :showlegend) === true || (pget(layout, :showlegend) != false && length(named) >= 2)
    lg_h    = pstr(pget(lg, :orientation)) == "h"
    lg_y    = something(pnum(pget(lg, :y)), lg_h ? -0.12 : 1.0)
    if show_lg && lg_h && lg_y < 0
        legend_extra = max(0.0, (B - lg_y * (B - T)) + 24 - H)
    end
    Hc = H + legend_extra
    svg_open(io, SVGCanvas(W, Hc, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0))

    function draw_shapes(layer)
        shapes = [s for s in pget(layout, :shapes, default = []) if something(pstr(pget(s, :layer)), "above") == layer]
        isempty(shapes) && return
        svg_group_open(io, svg_id(seen, layer == "below" ? "Shapes_below" : "Shapes"))
        sub  = Dict(r[2][1] => r for r in gfig_named_runs(shapes) if !isempty(r[1]) && length(r[2]) > 1)
        ends = Set(r[2][end] for r in values(sub))
        for (i, s) in enumerate(shapes)
            haskey(sub, i) && svg_group_open(io, svg_id(seen, sub[i][1]))
            draw_one_shape(i, s)
            i in ends && svg_group_close(io)
        end
        svg_group_close(io)
    end

    function draw_one_shape(i, s)
        typ  = something(pstr(pget(s, :type)), "rect")
        xref = something(pstr(pget(s, :xref)), "x")
        yref = something(pstr(pget(s, :yref)), "y")
        fc, fo = svg_css_color(something(pstr(pget(s, :fillcolor)), "rgba(0,0,0,0)"))
        ln   = pget(s, :line)
        lc, lo = svg_css_color(something(pstr(pget(ln, :color)), "rgb(68,68,68)"))
        lw   = something(pnum(pget(ln, :width)), 2.0)
        fill = fo !== nothing && fo <= 0 ? "none" : fc
        stroke = lw <= 0 || (lo !== nothing && lo <= 0) ? "none" : lc
        id   = svg_id(seen, "Shape_$(i)")
        if typ == "path"
            d = pstr(pget(s, :path))
            d === nothing && return
            toks = split(replace(d, r"([MLZmlz])" => s" \1 "))
            out  = String[]
            k    = 1
            while k <= length(toks)
                tk = toks[k]
                if tk in ("M", "L")
                    p = gfig_pixel_point(axes, xref, yref, parse(Float64, toks[k+1]), parse(Float64, toks[k+2]), L, R, T, B)
                    p === nothing || push!(out, "$(tk)$(svg_num(p[1])) $(svg_num(p[2]))")
                    k += 3
                else
                    uppercase(tk) == "Z" && push!(out, "Z")
                    k += 1
                end
            end
            svg_path(io, id, join(out, " "); stroke = stroke, width = lw, fill = fill,
                     fill_opacity = fo === nothing ? nothing : fo)
            n_paths += 1
            return
        end
        x0, x1 = pnum(pget(s, :x0)), pnum(pget(s, :x1))
        y0, y1 = pnum(pget(s, :y0)), pnum(pget(s, :y1))
        (x0 === nothing || x1 === nothing || y0 === nothing || y1 === nothing) && return
        if pstr(pget(s, :xsizemode)) == "pixel"
            a = gfig_pixel_point(axes, xref, yref, pnum(pget(s, :xanchor)), pnum(pget(s, :yanchor)), L, R, T, B)
            a === nothing && return
            p0, p1 = (a[1] + x0, a[2] - y0), (a[1] + x1, a[2] - y1)
        else
            p0 = gfig_pixel_point(axes, xref, yref, x0, y0, L, R, T, B)
            p1 = gfig_pixel_point(axes, xref, yref, x1, y1, L, R, T, B)
            (p0 === nothing || p1 === nothing) && return
        end
        if typ == "line"
            svg_path(io, id, "M$(svg_num(p0[1])) $(svg_num(p0[2])) L$(svg_num(p1[1])) $(svg_num(p1[2]))";
                     stroke = lc, width = lw, dash = svg_dasharray(pstr(pget(ln, :dash)), lw))
        elseif typ == "circle"
            cx, cy = (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2
            rx, ry = abs(p1[1] - p0[1]) / 2, abs(p1[2] - p0[2]) / 2
            println(io, "<ellipse id=\"$(svg_escape(id))\" cx=\"$(svg_num(cx))\" cy=\"$(svg_num(cy))\" rx=\"$(svg_num(rx))\" ry=\"$(svg_num(ry))\" fill=\"$(fill)\" stroke=\"$(stroke)\" stroke-width=\"$(svg_num(lw))\"" *
                        (svg_dasharray(pstr(pget(ln, :dash)), lw) === nothing ? "" : " stroke-dasharray=\"$(svg_dasharray(pstr(pget(ln, :dash)), lw))\"") * "/>")
        else
            svg_path(io, id, "M$(svg_num(p0[1])) $(svg_num(p0[2])) L$(svg_num(p1[1])) $(svg_num(p0[2])) L$(svg_num(p1[1])) $(svg_num(p1[2])) L$(svg_num(p0[1])) $(svg_num(p1[2])) Z";
                     stroke = stroke, width = lw, fill = fill, fill_opacity = fo)
        end
        n_paths += 1
    end

    draw_shapes("below")

    colorbars = Any[]
    bases     = Dict{Tuple{String,String,Float64},Float64}()
    drawable = [k for (k, tr) in enumerate(traces) if gfig_trace_type(tr) != "pie" &&
                haskey(axes, gfig_axis_ref(tr, :x)) && haskey(axes, gfig_axis_ref(tr, :y))]
    gkeys    = Dict(k => gfig_group_key(traces[k]) for k in drawable)
    order    = String[]
    members  = Dict{String,Vector{Int}}()
    for k in drawable
        g = gkeys[k]
        haskey(members, g) || (push!(order, g); members[g] = Int[])
        push!(members[g], k)
    end
    draw_order = reduce(vcat, (members[g] for g in order); init = Int[])
    open_key   = nothing
    for k in draw_order
        tr = traces[k]
        t  = gfig_trace_type(tr)
        gk = gkeys[k]
        if open_key !== nothing && gk != open_key
            svg_group_close(io)
            open_key = nothing
        end
        if open_key === nothing && length(members[gk]) > 1
            svg_group_open(io, svg_id(seen, gfig_group_label(gk, k)))
            open_key = gk
        end
        xn, yn = gfig_axis_ref(tr, :x), gfig_axis_ref(tr, :y)
        X, Y  = axes[xn], axes[yn]
        name  = something(pstr(pget(tr, :name)), "")
        id    = svg_id(seen, isempty(name) ? "Trace_$(k)" : name)
        line  = pget(tr, :line)
        mk    = pget(tr, :marker)
        dflt  = PLOTLY_COLORWAY[mod1(k, length(PLOTLY_COLORWAY))]
        xs, ys = pvec(tr, :x), pvec(tr, :y)

        if t == "heatmap"
            if underlay !== nothing && xn == "x" && yn == "y"
                svg_group_open(io, id)
                n_paths += underlay(io, X, Y, seen)
                svg_group_close(io)
            else
                z    = [pflatten(row) for row in pget(tr, :z, default = [])]
                stops = svg_colorscale(something(pget(tr, :colorscale), "Viridis"); reverse = pget(tr, :reversescale) == true)
                zv   = Float64[v for row in z for v in row if v isa Real]
                zmin = something(pnum(pget(tr, :zmin)), isempty(zv) ? 0.0 : minimum(zv))
                zmax = something(pnum(pget(tr, :zmax)), isempty(zv) ? 1.0 : maximum(zv))
                xe   = Float64[v for v in xs if v isa Real]
                ye   = Float64[v for v in ys if v isa Real]
                edges(c) = length(c) > 1 ? vcat(c[1] - (c[2] - c[1]) / 2, (c[1:end-1] .+ c[2:end]) ./ 2, c[end] + (c[end] - c[end-1]) / 2) : [c[1] - 0.5, c[1] + 0.5]
                ex, ey = edges(xe), edges(ye)
                svg_group_open(io, id; stroke = "none")
                for (j, row) in enumerate(z), i in eachindex(row)
                    v = row[i]
                    v isa Real || continue
                    rc = svg_color_at(stops, clamp((v - zmin) / max(zmax - zmin, 1e-300), 0, 1))
                    a1, a2 = gaxis_px(X, ex[i]), gaxis_px(X, ex[i+1])
                    b1, b2 = gaxis_px(Y, ey[j]), gaxis_px(Y, ey[j+1])
                    println(io, "<rect x=\"$(svg_num(min(a1, a2)))\" y=\"$(svg_num(min(b1, b2)))\" width=\"$(svg_num(abs(a2 - a1) + 0.3))\" height=\"$(svg_num(abs(b2 - b1) + 0.3))\" fill=\"rgb($(round(Int, rc[1])),$(round(Int, rc[2])),$(round(Int, rc[3])))\"/>")
                    n_paths += 1
                end
                svg_group_close(io)
            end
            if pget(tr, :showscale; default = true) != false
                push!(colorbars, tr)
            end
            continue
        end

        if t == "contour"
            z    = [Float64[v isa Real ? v : NaN for v in pflatten(row)] for row in pget(tr, :z, default = [])]
            xe   = Float64[v for v in xs if v isa Real]
            ye   = Float64[v for v in ys if v isa Real]
            (isempty(z) || length(xe) < 2 || length(ye) < 2) && continue
            Z    = [z[j][i] for i in eachindex(xe), j in eachindex(ye)]
            cs   = pget(tr, :contours)
            l0, dl, l1 = something(pnum(pget(cs, :start)), 0.0), something(pnum(pget(cs, :size)), 1.0), something(pnum(pget(cs, :end)), 0.0)
            levels = collect(l0:dl:l1)
            lc, _ = svg_css_color(something(pstr(pget(line, :color)), "#444444"))
            lw    = something(pnum(pget(line, :width)), 1.0)
            svg_group_open(io, id; stroke = lc, width = lw, fill = "none")
            labels = Tuple{Float64,Float64,String}[]
            for cl in CTR.levels(CTR.contours(xe, ye, Z, levels))
                lev = CTR.level(cl)
                for ln in CTR.lines(cl)
                    xv, yv = CTR.coordinates(ln)
                    pts = [(gaxis_px(X, a), gaxis_px(Y, b)) for (a, b) in zip(xv, yv) if gaxis_inrange(X, a) && gaxis_inrange(Y, b)]
                    length(pts) < 2 && continue
                    svg_path(io, svg_id(seen, id * "_$(svg_tick_label(lev))"),
                             "M" * join(("$(svg_num(p[1])) $(svg_num(p[2]))" for p in pts), " L"))
                    n_paths += 1
                    length(pts) > 6 && push!(labels, (pts[length(pts) ÷ 2]..., svg_tick_label(lev)))
                end
            end
            svg_group_close(io)
            if pget(cs, :showlabels) == true && !isempty(labels)
                svg_group_open(io, svg_id(seen, id * "_labels"); fill = lc, font_family = "Helvetica, Arial, sans-serif",
                               font_size = 9, anchor = "middle")
                for (a, b, s) in labels
                    svg_text(io, a, b, s)
                end
                svg_group_close(io)
            end
            continue
        end

        if t == "bar"
            h      = pstr(pget(tr, :orientation)) == "h"
            PX, VX = h ? (Y, X) : (X, Y)
            pos    = h ? ys : xs
            val    = h ? xs : ys
            pnum_  = [p isa Real ? Float64(p) : (p isa AbstractString ? (i = findfirst(==(p), PX.categories); i === nothing ? NaN : Float64(i - 1)) : NaN) for p in pos]
            w      = gfig_bar_width(tr, pnum_, bargap)
            mc     = pget(mk, :color)
            fc, fo = svg_css_color(mc isa AbstractString ? mc : dflt)
            ml_    = pget(mk, :line)
            lc, _  = svg_css_color(something(pstr(pget(ml_, :color)), fc))
            lw     = something(pnum(pget(ml_, :width)), 0.0)
            svg_group_open(io, id; fill = fc, opacity = fo, stroke = lw > 0 ? lc : nothing, width = lw > 0 ? lw : nothing)
            for (i, (p, v)) in enumerate(zip(pnum_, val))
                (isfinite(p) && v isa Real) || continue
                k0   = (PX.name, VX.name, p)
                base = barmode == "stack" ? get(bases, k0, 0.0) : 0.0
                top  = base + v
                barmode == "stack" && (bases[k0] = top)
                a1, a2 = gaxis_px(PX, p - w[min(i, end)] / 2), gaxis_px(PX, p + w[min(i, end)] / 2)
                b1, b2 = gaxis_px(VX, base), gaxis_px(VX, top)
                (a1 === nothing || a2 === nothing || b1 === nothing || b2 === nothing) && continue
                x0, y0, ww, hh = h ? (min(b1, b2), min(a1, a2), abs(b2 - b1), abs(a2 - a1)) :
                                     (min(a1, a2), min(b1, b2), abs(a2 - a1), abs(b2 - b1))
                (ww > 0 && hh > 0) || continue
                svg_rect(io, svg_id(seen, id * "_bar_$(i)"), x0, y0, ww, hh)
                n_paths += 1
            end
            svg_group_close(io)
            continue
        end

        t in ("scatter", "scattergl") || continue
        mode  = something(pstr(pget(tr, :mode)), length(xs) > 20 ? "lines" : "lines+markers")
        lcol  = something(pstr(pget(line, :color)), pget(mk, :color) isa AbstractString ? pstr(pget(mk, :color)) : nothing, dflt)
        lc, lop = svg_css_color(lcol)
        lw    = something(pnum(pget(line, :width)), 2.0)
        shape = something(pstr(pget(line, :shape)), "linear")
        op    = something(pnum(pget(tr, :opacity)), 1.0)
        pts   = [(gaxis_px(X, a), gaxis_px(Y, b)) for (a, b) in zip(xs, ys)]
        xlo, xhi = min(X.p0, X.p1), max(X.p0, X.p1)
        ylo, yhi = min(Y.p0, Y.p1), max(Y.p0, Y.p1)
        svg_group_open(io, id; fill = "none", opacity = op < 1 ? op : nothing)
        fillm = pstr(pget(tr, :fill))
        if fillm == "toself"
            ok = [p for p in pts if p[1] !== nothing && p[2] !== nothing]
            if length(ok) >= 3
                fc, fo = svg_css_color(something(pstr(pget(tr, :fillcolor)), lcol))
                d = "M" * join(("$(svg_num(clamp(p[1], xlo, xhi))) $(svg_num(clamp(p[2], ylo, yhi)))" for p in ok), " L") * " Z"
                svg_path(io, svg_id(seen, id * "_fill"), d; fill = fc, fill_opacity = something(fo, 0.5) * (lw > 0 ? 1.0 : 1.0),
                         stroke = lw > 0 ? lc : "none", width = lw > 0 ? lw : nothing)
                n_paths += 1
            end
        elseif occursin("lines", mode) && lw > 0
            segs = Vector{Vector{Tuple{Float64,Float64}}}()
            cur  = Tuple{Float64,Float64}[]
            prev = nothing
            for p in pts
                if p[1] === nothing || p[2] === nothing
                    length(cur) > 1 && push!(segs, cur)
                    cur, prev = Tuple{Float64,Float64}[], nothing
                    continue
                end
                if prev !== nothing && shape in ("hv", "vh", "hvh", "vhv")
                    if shape == "hv"
                        push!(cur, (p[1], prev[2]))
                    elseif shape == "vh"
                        push!(cur, (prev[1], p[2]))
                    elseif shape == "hvh"
                        xm = (prev[1] + p[1]) / 2
                        push!(cur, (xm, prev[2]), (xm, p[2]))
                    else
                        ym = (prev[2] + p[2]) / 2
                        push!(cur, (prev[1], ym), (p[1], ym))
                    end
                end
                push!(cur, (Float64(p[1]), Float64(p[2])))
                prev = p
            end
            length(cur) > 1 && push!(segs, cur)
            clipped = reduce(vcat, [svg_clip_polyline(s, xlo, xhi, ylo, yhi) for s in segs];
                             init = Vector{Vector{Tuple{Float64,Float64}}}())
            d = join(("M" * join(("$(svg_num(p[1])) $(svg_num(p[2]))" for p in s), " L") for s in clipped if length(s) > 1), " ")
            if !isempty(d)
                svg_path(io, svg_id(seen, id * "_line"), d; stroke = lc, width = lw,
                         dash = svg_dasharray(pstr(pget(line, :dash)), lw))
                n_paths += 1
            end
        end
        err = gfig_error(tr)
        if err !== nothing
            e   = pget(tr, :error_y)
            ec, _ = svg_css_color(something(pstr(pget(e, :color)), lcol))
            ew  = something(pnum(pget(e, :thickness)), 1.5)
            cap = something(pnum(pget(e, :width)), 4.0)
            svg_group_open(io, svg_id(seen, id * "_errors"); stroke = ec, width = ew)
            for (i, (a, b)) in enumerate(zip(xs, ys))
                (i <= length(err) && err[i] isa Real && b isa Real) || continue
                px = gaxis_px(X, a)
                p1, p2 = gaxis_px(Y, b - err[i]), gaxis_px(Y, b + err[i])
                (px === nothing || p1 === nothing || p2 === nothing) && continue
                xlo <= px <= xhi || continue
                q1, q2 = clamp(p1, ylo, yhi), clamp(p2, ylo, yhi)
                svg_line(io, px, q1, px, q2)
                cap > 0 && (svg_line(io, px - cap, q1, px + cap, q1); svg_line(io, px - cap, q2, px + cap, q2))
                n_paths += 1
            end
            svg_group_close(io)
        end
        if occursin("markers", mode)
            mcol  = pget(mk, :color)
            msz   = pget(mk, :size)
            msym  = pget(mk, :symbol)
            mlin  = pget(mk, :line)
            mlc   = pstr(pget(mlin, :color))
            mlw   = something(pnum(pget(mlin, :width)), 0.0)
            mop   = something(pnum(pget(mk, :opacity)), 1.0)
            for (i, p) in enumerate(pts)
                (p[1] === nothing || p[2] === nothing) && continue
                (xlo - 0.5 <= p[1] <= xhi + 0.5 && ylo - 0.5 <= p[2] <= yhi + 0.5) || continue
                col  = mcol isa AbstractString ? mcol : (mcol !== nothing && !(mcol isa Real) && length(mcol) >= i && mcol[i] isa AbstractString ? mcol[i] : lcol)
                sz   = msz isa Real ? Float64(msz) : (msz !== nothing && length(msz) >= i && msz[i] isa Real ? Float64(msz[i]) : 6.0)
                sym  = msym isa AbstractString ? msym : (msym !== nothing && length(msym) >= i ? string(msym[i]) : "circle")
                fc, fo = svg_css_color(col)
                open_ = occursin("open", sym) || occursin("line-", sym) || sym in ("x", "x-thin")
                sc, _ = svg_css_color(something(mlc, col))
                r    = sz / 2
                pd   = gfig_marker_path(sym, p[1], p[2], r)
                if pd === nothing
                    svg_circle(io, svg_id(seen, id * "_pt_$(i)"), p[1], p[2], r; fill = open_ ? "none" : fc,
                               stroke = open_ ? fc : (mlw > 0 ? sc : nothing), width = open_ ? 1.2 : (mlw > 0 ? mlw : nothing),
                               opacity = mop * something(fo, 1.0) < 1 ? mop * something(fo, 1.0) : nothing)
                else
                    svg_path(io, svg_id(seen, id * "_pt_$(i)"), pd; fill = open_ ? "none" : fc,
                             stroke = open_ ? (mlc === nothing ? fc : sc) : (mlw > 0 ? sc : "none"),
                             width = open_ ? max(mlw, 1.2) : (mlw > 0 ? mlw : nothing))
                end
                n_paths += 1
            end
        end
        svg_group_close(io)
    end

    open_key === nothing || svg_group_close(io)

    for (k, tr) in enumerate(traces)
        gfig_trace_type(tr) == "pie" || continue
        vals_ = Float64[v isa Real ? v : 0.0 for v in pvec(tr, :values)]
        labs  = string.(pvec(tr, :labels))
        tot   = sum(vals_)
        tot > 0 || continue
        dm    = pget(tr, :domain)
        dx    = Float64.(pflatten(something(pget(dm, :x), [0, 1])))
        dy    = Float64.(pflatten(something(pget(dm, :y), [0, 1])))
        x0, x1 = L + dx[1] * (R - L), L + dx[2] * (R - L)
        y0, y1 = B - dy[2] * (B - T), B - dy[1] * (B - T)
        r     = 0.45 * min(x1 - x0, y1 - y0)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        cols  = pget(pget(tr, :marker), :colors)
        pal   = cols === nothing ? PLOTLY_COLORWAY : string.(pflatten(cols))
        id    = svg_id(seen, something(pstr(pget(tr, :name)), "Pie_$(k)"))
        svg_group_open(io, id; stroke = "#ffffff", width = 1)
        a = π / 2
        labs_out = Tuple{Float64,Float64,String}[]
        for (i, v) in enumerate(vals_)
            v > 0 || continue
            da = 2π * v / tot
            a2 = a - da
            p1 = (cx + r * cos(a), cy - r * sin(a))
            p2 = (cx + r * cos(a2), cy - r * sin(a2))
            fc, _ = svg_css_color(pal[mod1(i, length(pal))])
            svg_path(io, svg_id(seen, id * "_" * (i <= length(labs) ? labs[i] : "slice_$i")),
                     "M$(svg_num(cx)) $(svg_num(cy)) L$(svg_num(p1[1])) $(svg_num(p1[2])) A$(svg_num(r)) $(svg_num(r)) 0 $(da > π ? 1 : 0) 1 $(svg_num(p2[1])) $(svg_num(p2[2])) Z";
                     fill = fc)
            n_paths += 1
            am = (a + a2) / 2
            v / tot >= 0.04 && push!(labs_out, (cx + 0.62r * cos(am), cy - 0.62r * sin(am),
                                                @sprintf("%s<br>%.0f%%", i <= length(labs) ? labs[i] : "", 100 * v / tot)))
            a = a2
        end
        svg_group_close(io)
        svg_group_open(io, svg_id(seen, id * "_labels"); fill = "#ffffff", font_family = "Helvetica, Arial, sans-serif",
                       font_size = 9, anchor = "middle")
        for (lx, ly, s) in labs_out
            svg_text(io, lx, ly, s)
        end
        svg_group_close(io)
        ttl = pstr(pget(pget(tr, :title), :text))
        ttl === nothing || svg_text(io, cx, cy + r + 12, ttl; size = 11, anchor = "middle", fill = "#333333")
    end

    draw_shapes("above")

    svg_group_open(io, svg_id(seen, "Axes"); stroke = "#333333", width = 1, fill = "none")
    for n in sort(collect(names))
        ax = axes[n]
        ax.visible || continue
        isx = n[1] == 'x'
        isx ? svg_line(io, min(ax.p0, ax.p1), ax.pos, max(ax.p0, ax.p1), ax.pos) :
              svg_line(io, ax.pos, min(ax.p0, ax.p1), ax.pos, max(ax.p0, ax.p1))
        if ax.mirror
            opp = isx ? (ax.pos == ax.other0 ? ax.other1 : ax.other0) : (ax.pos == ax.other0 ? ax.other1 : ax.other0)
            isx ? svg_line(io, min(ax.p0, ax.p1), opp, max(ax.p0, ax.p1), opp) :
                  svg_line(io, opp, min(ax.p0, ax.p1), opp, max(ax.p0, ax.p1))
        end
    end
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Ticks"); stroke = "#333333", width = 1, fill = "none")
    tick_sets = Dict{String,Tuple{Vector{Float64},Vector{String}}}()
    for n in sort(collect(names))
        ax = axes[n]
        ax.visible || continue
        lo, hi = min(ax.lo, ax.hi), max(ax.lo, ax.hi)
        tv, tl = if ax.tickvals !== nothing
            ax.tickvals, something(ax.ticklabels, svg_tick_label.(ax.tickvals))
        elseif ax.kind == :category
            nc = length(ax.categories); st_ = max(1, div(nc - 1, 9)); idx = sort(unique(vcat(1:st_:nc, nc)))
            Float64.(idx .- 1), [ax.categories[i] for i in idx]
        elseif ax.kind == :log
            ks = [k for k in floor(Int, log10(lo)):ceil(Int, log10(hi)) if lo <= 10.0^k <= hi]
            st_ = max(1, ceil(Int, length(ks) / 8))
            ks  = ks[1:st_:end]
            [10.0^k for k in ks], [abs(k) >= 3 ? "10<sup>$(k)</sup>" : svg_tick_label(10.0^k) for k in ks]
        else
            v = svg_nice_ticks(lo, hi)
            v, svg_tick_label.(v)
        end
        keep = [i for i in eachindex(tv) if gaxis_inrange(ax, tv[i])]
        tick_sets[n] = (tv[keep], tl[min.(keep, length(tl))])
        isx = n[1] == 'x'
        out = isx ? (ax.side == "top" ? -4.0 : 4.0) : (ax.side == "right" ? 4.0 : -4.0)
        for v in tick_sets[n][1]
            p = gaxis_px(ax, v)
            p === nothing && continue
            isx ? svg_line(io, p, ax.pos, p, ax.pos + out) : svg_line(io, ax.pos, p, ax.pos + out, p)
        end
    end
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Tick_labels"); fill = "#333333", font_family = "Helvetica, Arial, sans-serif", font_size = 10)
    for n in sort(collect(names))
        ax = axes[n]
        (ax.visible && ax.showlabels && haskey(tick_sets, n)) || continue
        isx = n[1] == 'x'
        for (v, s) in zip(tick_sets[n]...)
            p = gaxis_px(ax, v)
            p === nothing && continue
            if isx
                svg_text(io, p, ax.side == "top" ? ax.pos - 12 : ax.pos + 14, s; anchor = "middle")
            else
                svg_text(io, ax.side == "right" ? ax.pos + 7 : ax.pos - 7, p, s; anchor = ax.side == "right" ? "start" : "end")
            end
        end
    end
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Axis_titles"); fill = "#333333", font_family = "Helvetica, Arial, sans-serif", font_size = 12,
                   anchor = "middle")
    for n in sort(collect(names))
        ax = axes[n]
        (ax.visible && !isempty(ax.title)) || continue
        mid = (ax.p0 + ax.p1) / 2
        if n[1] == 'x'
            svg_text(io, mid, ax.side == "top" ? ax.pos - 30 : ax.pos + 32, ax.title)
        else
            wl = haskey(tick_sets, n) ? maximum(length.(tick_sets[n][2]); init = 1) * 6.0 : 20.0
            xp = ax.side == "right" ? ax.pos + wl + 18 : ax.pos - wl - 18
            svg_text(io, xp, mid, ax.title; rotate = ax.side == "right" ? 90 : true)
        end
    end
    svg_group_close(io)

    function draw_one_label(i, a)
        pget(a, :visible; default = true) == false && return
        txt = pstr(pget(a, :text))
        txt === nothing && return
        p = gfig_pixel_point(axes, something(pstr(pget(a, :xref)), "x"), something(pstr(pget(a, :yref)), "y"),
                             pnum(pget(a, :x)), pnum(pget(a, :y)), L, R, T, B)
        p === nothing && return
        fs  = something(pnum(pget(pget(a, :font), :size)), 12.0)
        px  = p[1] + something(pnum(pget(a, :xshift)), 0.0)
        py  = p[2] - something(pnum(pget(a, :yshift)), 0.0)
        w, h = gfig_text_box(txt, fs)
        xa  = something(pstr(pget(a, :xanchor)), "center")
        ya  = something(pstr(pget(a, :yanchor)), "middle")
        x0  = xa == "left" ? px : xa == "right" ? px - w : px - w / 2
        y0  = ya == "top" ? py : ya == "bottom" ? py - h : py - h / 2
        bg  = pstr(pget(a, :bgcolor))
        if bg !== nothing
            bc, bo = svg_css_color(bg)
            rc, _  = svg_css_color(something(pstr(pget(a, :bordercolor)), "rgba(0,0,0,0)"))
            svg_path(io, svg_id(seen, "Label_box_$(i)"),
                     "M$(svg_num(x0 - 3)) $(svg_num(y0 - 2)) h$(svg_num(w + 6)) v$(svg_num(h + 4)) h$(svg_num(-w - 6)) Z";
                     fill = bc, fill_opacity = bo, stroke = pget(a, :bordercolor) === nothing ? "none" : rc,
                     width = something(pnum(pget(a, :borderwidth)), 1.0))
        end
        al  = something(pstr(pget(a, :align)), "center")
        tx  = al == "left" ? x0 : al == "right" ? x0 + w : x0 + w / 2
        svg_text(io, tx, y0, txt; id = svg_id(seen, "Label_$(lpad(i, 3, '0'))"), size = fs,
                 anchor = al == "left" ? "start" : al == "right" ? "end" : "middle", top = true,
                 fill = pstr(pget(pget(a, :font), :color)) === nothing ? nothing : svg_css_color(pstr(pget(pget(a, :font), :color)))[1])
    end

    anns = pget(layout, :annotations, default = [])
    if !isempty(anns)
        svg_group_open(io, svg_id(seen, "Labels"); fill = "#212121", font_family = "Helvetica, Arial, sans-serif")
        asub  = Dict(r[2][1] => r for r in gfig_named_runs(anns) if !isempty(r[1]) && length(r[2]) > 1)
        aends = Set(r[2][end] for r in values(asub))
        for (i, a) in enumerate(anns)
            haskey(asub, i) && svg_group_open(io, svg_id(seen, asub[i][1] * "_labels"))
            draw_one_label(i, a)
            i in aends && svg_group_close(io)
        end
        svg_group_close(io)
    end

    ttl = pget(layout, :title)
    tt  = gfig_title(ttl)
    if !isempty(tt)
        svg_group_open(io, svg_id(seen, "Title"); fill = "#333333", font_family = "Helvetica, Arial, sans-serif",
                       font_size = something(pnum(pget(pget(ttl, :font), :size)), 15.0))
        svg_text(io, L, 22, tt; id = svg_id(seen, "Figure_title"), anchor = "start", top = false)
        svg_group_close(io)
    end

    for (j, tr) in enumerate(colorbars)
        cb    = pget(tr, :colorbar)
        stops = svg_colorscale(something(pget(tr, :colorscale), "Viridis"); reverse = pget(tr, :reversescale) == true)
        zmin, zmax = something(pnum(pget(tr, :zmin)), 0.0), something(pnum(pget(tr, :zmax)), 1.0)
        len   = something(pnum(pget(cb, :len)), 1.0)
        yc    = something(pnum(pget(cb, :y)), 0.5)
        x     = L + something(pnum(pget(cb, :x)), 1.02) * (R - L) + 4
        h     = len * (B - T)
        y     = B - yc * (B - T) - h / 2
        thick = something(pnum(pget(cb, :thickness)), 14.0)
        svg_group_open(io, svg_id(seen, "Colorbar"); font_family = "Helvetica, Arial, sans-serif", font_size = 10, fill = "#333333")
        svg_gradient_bar_stops(io, svg_id(seen, "Colorbar_bar"), x, y, thick, h, stops)
        for (k2, v) in enumerate(svg_nice_ticks(min(zmin, zmax), max(zmin, zmax); target = 6))
            t = zmax == zmin ? 0.0 : (v - zmin) / (zmax - zmin)
            svg_text(io, x + thick + 4, y + h * (1 - t), svg_tick_label(v); id = svg_id(seen, "Colorbar_tick_$(k2)"), anchor = "start")
        end
        ct = pstr(pget(pget(cb, :title), :text))
        ct === nothing || svg_text(io, x + thick + 40, y + h / 2, ct; id = svg_id(seen, "Colorbar_title"), size = 11,
                                   anchor = "middle", rotate = 90)
        svg_group_close(io)
    end

    if show_lg
        entries = Any[]
        groups  = Set{String}()
        for k in named
            tr = traces[k]
            g  = something(pstr(pget(tr, :legendgroup)), "")
            (!isempty(g) && g in groups) && continue
            isempty(g) || push!(groups, g)
            t   = gfig_trace_type(tr)
            mk  = pget(tr, :marker)
            col = t == "bar" ? (pget(mk, :color) isa AbstractString ? pstr(pget(mk, :color)) : PLOTLY_COLORWAY[mod1(k, 10)]) :
                  something(pstr(pget(pget(tr, :line), :color)), pget(mk, :color) isa AbstractString ? pstr(pget(mk, :color)) : nothing,
                            PLOTLY_COLORWAY[mod1(k, 10)])
            mode = something(pstr(pget(tr, :mode)), "lines")
            push!(entries, (label = pstr(pget(tr, :name)), color = col, kind = t == "bar" ? :box : (mode == "markers" ? :dot : :line),
                            dash = pstr(pget(pget(tr, :line), :dash))))
        end
        lx = L + something(pnum(pget(lg, :x)), lg_h ? 0.0 : 1.02) * (R - L)
        ly = B - lg_y * (B - T)
        svg_group_open(io, svg_id(seen, "Legend"); font_family = "Helvetica, Arial, sans-serif", font_size = 10, fill = "#333333")
        xx, yy = lx, lg_h ? ly + 8 : ly + 6
        for e in entries
            ec, _ = svg_css_color(e.color)
            if e.kind == :box
                svg_path(io, svg_id(seen, "Legend_swatch_" * e.label), "M$(svg_num(xx)) $(svg_num(yy - 5)) h14 v10 h-14 Z"; fill = ec, stroke = "none")
            elseif e.kind == :dot
                svg_circle(io, svg_id(seen, "Legend_swatch_" * e.label), xx + 7, yy, 4; fill = ec)
            else
                svg_path(io, svg_id(seen, "Legend_swatch_" * e.label), "M$(svg_num(xx)) $(svg_num(yy)) h18"; stroke = ec, width = 2,
                         dash = svg_dasharray(e.dash, 2))
            end
            svg_text(io, xx + 22, yy, e.label; id = svg_id(seen, "Legend_text_" * e.label), anchor = "start")
            if lg_h
                xx += 34 + 0.56 * 10 * length(e.label)
                if xx > W - 40
                    xx, yy = lx, yy + 16
                end
            else
                yy += 16
            end
        end
        svg_group_close(io)
    end

    svg_close(io)
    bytes = take!(io)
    write(path, bytes)
    return (path = String(path), bytes = length(bytes), n_paths = n_paths, warnings = unique(warnings))
end

"""
    register_figure_svg_export!(app, graph_id, filename_fn; extra_states = (), underlay_fn = nothing)

    Register the "Export svg" callback of graph `graph_id` (button row from [`svg_export_button_row`](@ref)) using the
    general exporter [`plotly_export_figure_svg`](@ref): the on-screen figure is written to
    `<output_dir><filename_fn(extra...)>.svg`. `underlay_fn(extra...)`, when given, returns the underlay function of the
    exporter (or `nothing`), built from the values of `extra_states`.
"""
function register_figure_svg_export!(app, graph_id::AbstractString, filename_fn::Function; extra_states = (),
                                     underlay_fn::Union{Nothing,Function} = nothing)
    states = Any[State(graph_id, "figure"), State(graph_id, "config")]
    for (cid, prop) in extra_states
        push!(states, State(cid, prop))
    end
    callback!(
        app,
        Output(graph_id * "-svg-status", "children"),
        Input(graph_id * "-svg-button", "n_clicks"),
        states...,
        prevent_initial_call = true,
    ) do cb_args...
        fig, config = cb_args[2], cb_args[3]
        extra       = cb_args[4:end]
        global output_dir
        if fig === nothing || isempty(pget(fig, :data, default = []))
            return pd_export_status("Nothing to export yet - compute/display the figure first."; ok = false)
        end
        try
            mkpath(output_dir[1])
            ul  = underlay_fn === nothing ? nothing : underlay_fn(extra...)
            r   = plotly_export_figure_svg(fig, output_dir[1] * filename_fn(extra...) * ".svg"; config = config, underlay = ul)
            msg = "Saved $(r.path) ($(round(r.bytes / 1024, digits = 1)) KB, $(r.n_paths) paths)."
            isempty(r.warnings) || (msg *= " " * join(r.warnings, "; ") * ".")
            return pd_export_status(msg; ok = true)
        catch e
            return pd_export_status("Export failed: " * sprint(showerror, e); ok = false)
        end
    end
    return app
end
