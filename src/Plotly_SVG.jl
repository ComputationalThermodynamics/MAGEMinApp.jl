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
