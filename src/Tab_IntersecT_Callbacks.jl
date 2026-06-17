#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

# Global state for the IntersecT tab
global measurements_ix = nothing   # DataFrame: parsed measurements CSV (2 rows)
global Out_intersect   = nothing   # IntersecTResult from last run
global ix_isopleths    = nothing   # ix_isopleth_data for measurement isocontours

# ────────────────────────────────────────────────────────────────────────────
# Isopleth data struct and helpers (mirrors PhaseDiagram_functions pattern)
# ────────────────────────────────────────────────────────────────────────────

mutable struct ix_isopleth_data
    n_iso     :: Int64
    n_iso_max :: Int64
    status    :: Vector{Int64}
    active    :: Vector{Int64}
    hidden    :: Vector{Int64}
    isoP      :: Vector{GenericTrace{Dict{Symbol, Any}}}
    isoCap    :: Vector{GenericTrace{Dict{Symbol, Any}}}
    label     :: Vector{String}
    value     :: Vector{Int64}
end

function initialize_ix_isopleths(; n_iso_max = 32)
    global ix_isopleths
    status  = zeros(Int64, n_iso_max)
    active  = Int64[]
    hidden  = Int64[]
    isoP    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max)
    isoCap  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max)
    for i in 1:n_iso_max
        isoP[i]   = contour()
        isoCap[i] = scatter()
    end
    label = Vector{String}(undef, n_iso_max)
    value = Vector{Int64}(undef, n_iso_max)
    ix_isopleths = ix_isopleth_data(0, n_iso_max, status, active, hidden, isoP, isoCap, label, value)
    return ix_isopleths
end

function _build_iso_dropdowns(iso)
    isopleths = [Dict("label" => iso.label[iso.active[i]], "value" => iso.value[iso.active[i]])
                 for i in 1:length(iso.active)]
    isoplethsHid = [Dict("label" => iso.label[iso.hidden[i]], "value" => iso.value[iso.hidden[i]])
                    for i in 1:length(iso.hidden)]
    return isopleths, isoplethsHid
end

function _add_ix_iso_from_field(field::Vector{Float64}, label_base::String,
                                 minIso, stepIso, maxIso,
                                 isoColorLine, isoLineStyle, isoLineWidth, isoLabelSize)
    global ix_isopleths, data

    (!@isdefined(data))                  && return [], []
    isnothing(ix_isopleths)              && initialize_ix_isopleths()
    ix_isopleths.n_iso >= ix_isopleths.n_iso_max && return _build_iso_dropdowns(ix_isopleths)
    isempty(field)                       && return _build_iso_dropdowns(ix_isopleths)

    n_unique_t = length(unique([p[1] for p in data.points]))
    n_unique_p = length(unique([p[2] for p in data.points]))
    n  = max(n_unique_t, n_unique_p)
    dx = (data.Xrange[2] - data.Xrange[1]) / (n - 1)
    dy = (data.Yrange[2] - data.Yrange[1]) / (n - 1)

    x      = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y      = range(data.Yrange[1], stop = data.Yrange[2], length = n)
    X      = repeat(x, n)[:]
    y_disp = display_pressure.(collect(y))
    Y      = repeat(y_disp', n)[:]

    np          = length(data.points)
    iso_gridded = Matrix{Union{Nothing, Float64}}(nothing, n, n)
    for k_pt in 1:min(np, length(field))
        isnan(field[k_pt]) && continue
        ii = compute_index(data.points[k_pt][1], data.Xrange[1], dx)
        jj = compute_index(data.points[k_pt][2], data.Yrange[1], dy)
        (1 ≤ ii ≤ n && 1 ≤ jj ≤ n) || continue
        iso_gridded[ii, jj] = field[k_pt]
    end

    name = "$(label_base) [$(round(minIso,digits=3)):$(round(stepIso,digits=3)):$(round(maxIso,digits=3))]"

    ix_isopleths.n_iso += 1
    idx = ix_isopleths.n_iso
    ix_isopleths.isoP[idx] = contour(
        x                 = X,
        y                 = Y,
        z                 = iso_gridded,
        contours_coloring = "lines",
        colorscale        = [[0, isoColorLine], [1, isoColorLine]],
        contours_start    = minIso,
        contours_end      = maxIso,
        contours_size     = stepIso,
        line_width        = isoLineWidth,
        line_dash         = isoLineStyle,
        showscale         = false,
        hoverinfo         = "skip",
        contours          = attr(coloring="lines", showlabels=true,
                                 labelfont=attr(size=Int64(isoLabelSize), color=isoColorLine)),
    )
    ix_isopleths.isoCap[idx] = scatter(
        x          = [nothing],
        y          = [nothing],
        mode       = "lines",
        line       = attr(color=isoColorLine, dash=isoLineStyle, width=isoLineWidth),
        name       = name,
        showlegend = true,
    )
    ix_isopleths.status[idx] = 1
    ix_isopleths.label[idx]  = name
    ix_isopleths.value[idx]  = idx
    ix_isopleths.active      = findall(ix_isopleths.status .== 1)
    ix_isopleths.hidden      = findall(ix_isopleths.status .== 2)

    return _build_iso_dropdowns(ix_isopleths)
end

function add_ix_isopleth(phase_name, element_name, minIso, stepIso, maxIso,
                          isoColorLine, isoLineStyle, isoLineWidth, isoLabelSize)
    global Out_XY
    (!@isdefined(Out_XY) || isnothing(Out_XY) || isempty(Out_XY)) && return [], []
    field = _get_apfu_field(phase_name, element_name)
    return _add_ix_iso_from_field(field, "$(phase_name) $(element_name)",
                                   minIso, stepIso, maxIso,
                                   isoColorLine, isoLineStyle, isoLineWidth, isoLabelSize)
end

function hide_ix_isopleth(iso_id)
    global ix_isopleths
    isnothing(ix_isopleths) && return [], []
    ix_isopleths.status[iso_id] = 2
    ix_isopleths.active = findall(ix_isopleths.status .== 1)
    ix_isopleths.hidden = findall(ix_isopleths.status .== 2)
    return _build_iso_dropdowns(ix_isopleths)
end

function hide_all_ix_isopleths()
    global ix_isopleths
    isnothing(ix_isopleths) && return [], []
    for i in ix_isopleths.active
        ix_isopleths.status[i] = 2
    end
    ix_isopleths.active = findall(ix_isopleths.status .== 1)
    ix_isopleths.hidden = findall(ix_isopleths.status .== 2)
    return _build_iso_dropdowns(ix_isopleths)
end

function show_ix_isopleth(iso_id)
    global ix_isopleths
    isnothing(ix_isopleths) && return [], []
    ix_isopleths.status[iso_id] = 1
    ix_isopleths.active = findall(ix_isopleths.status .== 1)
    ix_isopleths.hidden = findall(ix_isopleths.status .== 2)
    return _build_iso_dropdowns(ix_isopleths)
end

function show_all_ix_isopleths()
    global ix_isopleths
    isnothing(ix_isopleths) && return [], []
    for i in ix_isopleths.hidden
        ix_isopleths.status[i] = 1
    end
    ix_isopleths.active = findall(ix_isopleths.status .== 1)
    ix_isopleths.hidden = findall(ix_isopleths.status .== 2)
    return _build_iso_dropdowns(ix_isopleths)
end

function remove_ix_isopleth(iso_id)
    global ix_isopleths
    isnothing(ix_isopleths) && return [], []
    ix_isopleths.n_iso              -= 1
    ix_isopleths.status[iso_id]      = 0
    ix_isopleths.isoP[iso_id]        = contour()
    ix_isopleths.isoCap[iso_id]      = scatter()
    ix_isopleths.label[iso_id]       = ""
    ix_isopleths.value[iso_id]       = 0
    ix_isopleths.active = findall(ix_isopleths.status .== 1)
    ix_isopleths.hidden = findall(ix_isopleths.status .== 2)
    return _build_iso_dropdowns(ix_isopleths)
end

function remove_all_ix_isopleths()
    global ix_isopleths
    isnothing(ix_isopleths) && return
    for i in 1:ix_isopleths.n_iso_max
        ix_isopleths.isoP[i]   = contour()
        ix_isopleths.isoCap[i] = scatter()
        ix_isopleths.label[i]  = ""
        ix_isopleths.value[i]  = 0
        ix_isopleths.status[i] = 0
    end
    ix_isopleths.n_iso  = 0
    ix_isopleths.active = Int64[]
    ix_isopleths.hidden = Int64[]
end

# ────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ────────────────────────────────────────────────────────────────────────────

"""
Decode a Dash dcc_upload `contents` string (base64) and return a parsed DataFrame.
"""
function _parse_measurements_upload(contents::String)::DataFrame
    _, content_string = split(contents, ','; limit=2)
    decoded = base64decode(content_string)
    input   = String(decoded)
    return CSV.read(IOBuffer(input), DataFrame; header=true)
end

"""
Extract unique phase names from IntersecT-style column headers ("Phase_Element").
"""
function _phases_from_headers(df::DataFrame)::Vector{String}
    seen   = Set{String}()
    phases = String[]
    for col in names(df)
        parts = split(col, '_'; limit=2)
        if length(parts) == 2
            ph = String(parts[1])
            if !(ph in seen)
                push!(phases, ph)
                push!(seen, ph)
            end
        end
    end
    return phases
end

"""
Build the list of dropdown options for the IntersecT result fields.
"""
function _build_field_options(result)::Vector{Dict{String,String}}
    opts = Dict{String,String}[]

    # Scalar fields (one value per grid point)
    push!(opts, Dict("label" => "Qcmp weighted",   "value" => "Qcmp_weighted"))
    push!(opts, Dict("label" => "Qcmp unweighted", "value" => "Qcmp_unweighted"))
    push!(opts, Dict("label" => "redchi2 total",   "value" => "redchi2_tot"))

    # Per-phase fields
    for (p, ph) in enumerate(result.phase_names)
        push!(opts, Dict("label" => "Qcmp $(ph)",     "value" => "Qcmp_phase_$(p)"))
        push!(opts, Dict("label" => "redchi2 $(ph)",  "value" => "redchi2_phase_$(p)"))
    end

    # Per-element fields
    for (j, el) in enumerate(result.element_names)
        push!(opts, Dict("label" => "Qcmp $(el)", "value" => "Qcmp_elem_$(j)"))
    end

    return opts
end

"""
Extract the field vector corresponding to a dropdown value string from an IntersecTResult.
"""
function _get_field(result, value::String)::Vector{Float64}
    if value == "Qcmp_weighted"
        return result.Qcmp_weighted
    elseif value == "Qcmp_unweighted"
        return result.Qcmp_unweighted
    elseif value == "redchi2_tot"
        return result.redchi2_tot
    elseif startswith(value, "Qcmp_phase_")
        p = parse(Int, value[length("Qcmp_phase_")+1:end])
        return result.Qcmp_phase[:, p]
    elseif startswith(value, "redchi2_phase_")
        p = parse(Int, value[length("redchi2_phase_")+1:end])
        return result.redchi2_phase[:, p]
    elseif startswith(value, "Qcmp_elem_")
        j = parse(Int, value[length("Qcmp_elem_")+1:end])
        return result.Qcmp_elem[:, j]
    else
        return fill(NaN, length(result.x))
    end
end

"""
Field label for the colorbar title.
"""
function _field_label(result, value::String)::String
    if value == "Qcmp_weighted"
        return "Q*cmp weighted"
    elseif value == "Qcmp_unweighted"
        return "Q*cmp unweighted"
    elseif value == "redchi2_tot"
        return "redchi² total"
    elseif startswith(value, "Qcmp_phase_")
        p = parse(Int, value[length("Qcmp_phase_")+1:end])
        return "Q*cmp $(result.phase_names[p])"
    elseif startswith(value, "redchi2_phase_")
        p = parse(Int, value[length("redchi2_phase_")+1:end])
        return "redchi² $(result.phase_names[p])"
    elseif startswith(value, "Qcmp_elem_")
        j = parse(Int, value[length("Qcmp_elem_")+1:end])
        return "Q*cmp $(result.element_names[j])"
    else
        return value
    end
end

"""
Grid the APFU field for a given phase and element symbol over the current
diagram's `data.points`. Returns a vector of length `length(data.points)` with
NaN where the phase is absent or the element is not in the oxide list.
"""
function _get_apfu_field(phase_name::String, element_name::String)::Vector{Float64}
    global Out_XY, data

    (!@isdefined(Out_XY) || isnothing(Out_XY) || isempty(Out_XY)) && return Float64[]
    (!@isdefined(data))                                             && return Float64[]

    oxides = Out_XY[1].oxides
    elem_to_ox_idx = Dict{String, Int}()
    for (k, ox) in enumerate(oxides)
        elem = get(OXIDE_TO_ELEMENT, String(ox), nothing)
        isnothing(elem)              && continue
        haskey(elem_to_ox_idx, elem) && continue
        elem_to_ox_idx[elem] = k
    end
    haskey(elem_to_ox_idx, element_name) || return fill(NaN, length(data.points))
    ox_idx = elem_to_ox_idx[element_name]

    np     = length(data.points)
    values = fill(NaN, np)
    for i in 1:min(np, length(Out_XY))
        ph_list = Out_XY[i].ph
        n_SS    = Out_XY[i].n_SS
        idx = findfirst(k -> k ≤ n_SS &&
                        display_ph_name(String(ph_list[k])) == phase_name,
                        1:n_SS)
        isnothing(idx) && continue
        apfu = Out_XY[i].SS_vec[idx].Comp_apfu
        length(apfu) < ox_idx && continue
        v = apfu[ox_idx]
        values[i] = (ismissing(v) || (v isa Number && isnan(Float64(v)))) ? NaN : Float64(v)
    end
    return values
end

"""
Render a heatmap figure for the IntersecT result using the same grid mapping
convention as get_gridded_map: gridded[T_idx, P_idx] with n²-length X/Y
coordinate vectors so Plotly renders in scatter-heatmap mode and respects the
standard P-T axis orientation (P increasing upward).

Color options mirror those of the phase diagram (colormap, value range,
colormap range, set-min-to-white, reverse, smooth).
"""
function _render_intersect_figure(result, field_value::String;
    colormap       = "RdYlGn",
    zmin_val       = nothing,
    zmax_val       = nothing,
    color_range    = [1, 9],
    set_min_white  = "false",
    reverse_cmap   = "false",
    smooth_cmap    = "fast",
    show_full_grid = "false",
    show_lbl       = "true",
    show_grid      = "true",
    fig_width      = 640,
    fig_height     = 640,
    show_logos     = true,
)
    values = _get_field(result, field_value)
    label  = _field_label(result, field_value)

    finite_vals = filter(isfinite, values)
    zmin = isnothing(zmin_val) ?
        (isempty(finite_vals) ? 0.0   : round(minimum(finite_vals), digits=2)) :
        Float64(zmin_val)
    zmax = isnothing(zmax_val) ?
        (isempty(finite_vals) ? 100.0 : round(maximum(finite_vals), digits=2)) :
        Float64(zmax_val)

    # Build colorscale (handles custom R.J. Tamblyn maps and range trimming)
    colorm, reverseColorMap = get_colormap_prop(colormap, color_range, reverse_cmap)
    if set_min_white == "true"
        colorm = set_min_to_white(colorm; reverseColorMap)
    end

    global data

    np = length(data.points)

    # Derive grid size n from the number of unique T (and P) values in data.points.
    # For no-AMR runs (only initial subdivision) this equals 2^sub + 1 exactly.
    n_unique_t = length(unique([p[1] for p in data.points]))
    n_unique_p = length(unique([p[2] for p in data.points]))
    n  = max(n_unique_t, n_unique_p)
    dx = (data.Xrange[2] - data.Xrange[1]) / (n - 1)
    dy = (data.Yrange[2] - data.Yrange[1]) / (n - 1)

    x = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    # n²-length flat coordinate vectors — same as get_gridded_map.
    # Y is converted to display pressure units (kbar → GPa when use_GPa[1]).
    X      = repeat(x,  n)[:]
    y_disp = display_pressure.(collect(y))
    Y      = repeat(y_disp', n)[:]

    # Main heatmap: skip NaN (phase absent), let connectgaps=true smooth the valid region.
    gridded = Matrix{Union{Nothing, Float64}}(nothing, n, n)
    for k in 1:min(np, length(values))
        v = values[k]
        isnan(v) && continue
        ii = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj = compute_index(data.points[k][2], data.Yrange[1], dy)
        (1 ≤ ii ≤ n && 1 ≤ jj ≤ n) || continue
        gridded[ii, jj] = v
    end

    # White mask: BFS nearest-neighbor fill on binary absent(1)/present(0) classification.
    # Covers the regions that connectgaps=true incorrectly extrapolates into.
    mask = Matrix{Union{Nothing, Float64}}(nothing, n, n)
    for k in 1:min(np, length(values))
        v  = values[k]
        ii = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj = compute_index(data.points[k][2], data.Yrange[1], dy)
        (1 ≤ ii ≤ n && 1 ≤ jj ≤ n) || continue
        mask[ii, jj] = isnan(v) ? 1.0 : 0.0
    end
    mask_visited = fill(false, n, n)
    mask_queue   = Vector{Tuple{Int,Int}}(undef, n * n)
    mq_head = 1; mq_tail = 0
    for ii in 1:n, jj in 1:n
        if !isnothing(mask[ii, jj])
            mq_tail += 1; mask_queue[mq_tail] = (ii, jj); mask_visited[ii, jj] = true
        end
    end
    while mq_head <= mq_tail
        ii, jj = mask_queue[mq_head]; mq_head += 1
        for (di, dj) in ((-1,0),(1,0),(0,-1),(0,1))
            ni, nj = ii+di, jj+dj
            (1 ≤ ni ≤ n && 1 ≤ nj ≤ n) || continue
            mask_visited[ni, nj] && continue
            mask[ni, nj] = mask[ii, jj]
            mask_visited[ni, nj] = true
            mq_tail += 1; mask_queue[mq_tail] = (ni, nj)
        end
    end
    # Keep only absent cells (1.0) visible; present cells become nothing (transparent).
    for ii in 1:n, jj in 1:n
        v = mask[ii, jj]
        !isnothing(v) && v == 0.0 && (mask[ii, jj] = nothing)
    end

    trace = heatmap(
        x            = X,
        y            = Y,
        z            = gridded,
        zmin         = zmin,
        zmax         = zmax,
        zsmooth      = smooth_cmap,
        colorscale   = colorm,
        reversescale = reverseColorMap,
        connectgaps  = true,
        type         = "heatmap",
        colorbar     = attr(
            lenmode       = "fraction",
            len           = 0.75,
            thicknessmode = "fraction",
            exponentformat = "e",
            x             = 1.005,
            y             = 0.5,
            title         = attr(text = label, side = "right"),
        ),
    )

    trace_mask = heatmap(
        x           = X,
        y           = Y,
        z           = mask,
        zmin        = 0.0,
        zmax        = 1.0,
        colorscale  = [[0, "white"], [1, "white"]],
        showscale   = false,
        connectgaps = false,
        hoverinfo   = "skip",
        type        = "heatmap",
    )

    # Collect traces: heatmap, white mask, then optional overlays
    traces = AbstractTrace[trace, trace_mask]

    if show_full_grid == "true" && @isdefined(data)
        try
            for gt in show_hide_mesh_grid()
                gt_c = deepcopy(gt)
                if use_GPa[1] && haskey(gt_c, :y)
                    gt_c[:y] = display_pressure(collect(gt_c[:y]))
                end
                push!(traces, gt_c)
            end
        catch
        end
    end

    if show_grid == "true" && @isdefined(data_reaction)
        try
            for rt in data_reaction
                rt_c = deepcopy(rt)
                if use_GPa[1] && haskey(rt_c, :y)
                    rt_c[:y] = display_pressure(collect(rt_c[:y]))
                end
                push!(traces, rt_c)
            end
        catch
        end
    end

    # ── Measurement isocontour overlays (main diagram only) ──────────────────
    if show_logos && @isdefined(ix_isopleths) && !isnothing(ix_isopleths) && ix_isopleths.n_iso > 0
        for i in ix_isopleths.active
            push!(traces, ix_isopleths.isoP[i])
        end
    end

    # Collect phase label annotations from the phase diagram layout global.
    # Always deepcopy and force visible=true so the phase diagram's own label
    # toggle state (which writes visible=false into the shared layout object)
    # does not suppress labels here. Also convert y to display pressure units.
    annotations = []
    if show_lbl == "true" && @isdefined(layout) && @isdefined(n_lbl) && n_lbl > 0
        try
            all_anns = layout[:annotations]
            for i in 1:min(n_lbl, length(all_anns))
                ann_c = deepcopy(all_anns[i])
                ann_c[:visible] = true
                if use_GPa[1] && get(ann_c, :yref, "") == "y" && haskey(ann_c, :y)
                    ann_c[:y] = display_pressure(Float64(ann_c[:y]))
                end
                push!(annotations, ann_c)
            end
        catch e
            @warn "IntersecT: failed to load phase label annotations: $e"
        end
    end

    ticks = 4
    frame = get_plot_frame(data.Xrange, data.Yrange, ticks)

    if show_logos
        intersect_logo = attr(
            source  = "assets/static/images/Logo-IntersecT.png",
            xref    = "paper",
            yref    = "paper",
            x       = 0.05,
            y       = 1.01,
            sizex   = 0.1,
            sizey   = 0.1,
            xanchor = "left",
            yanchor = "bottom",
        )
        # frame[1] is the MAGEMin logo; frame[2:end] are border lines and ticks
        frame_images = vcat(collect(frame), [intersect_logo])
    else
        # The image-based border lines (sizex/sizey ≈ 0.002 in paper coords) become
        # sub-pixel at 320px and don't render. Use Plotly native axis lines instead,
        # so pass no images at all.
        frame_images = []
    end

    r_margin = round(Int, fig_width  * 116 / 640)
    b_margin = round(Int, fig_height *  50 / 640)
    t_margin = round(Int, fig_height *  50 / 640)

    # For sub-diagrams (no logos) use Plotly's native axis showline+mirror to draw
    # the box border — image-based lines become sub-pixel at 320px and don't render.
    if show_logos
        xaxis_attr = attr(
            title      = result.x_label,
            tickmode   = "linear",
            tick0      = data.Xrange[1],
            dtick      = (data.Xrange[2] - data.Xrange[1]) / (ticks + 1),
            fixedrange = true,
        )
        yaxis_attr = attr(
            title      = "P [$(pressure_unit_label())]",
            tickmode   = "linear",
            tick0      = display_pressure(data.Yrange[1]),
            dtick      = display_pressure((data.Yrange[2] - data.Yrange[1]) / (ticks + 1)),
            fixedrange = true,
        )
    else
        xaxis_attr = attr(
            title      = result.x_label,
            tickmode   = "linear",
            tick0      = data.Xrange[1],
            dtick      = (data.Xrange[2] - data.Xrange[1]) / (ticks + 1),
            fixedrange = true,
            showline   = true,
            linewidth  = 1,
            linecolor  = "black",
            mirror     = true,
            ticks      = "outside",
        )
        yaxis_attr = attr(
            title      = "P [$(pressure_unit_label())]",
            tickmode   = "linear",
            tick0      = display_pressure(data.Yrange[1]),
            dtick      = display_pressure((data.Yrange[2] - data.Yrange[1]) / (ticks + 1)),
            fixedrange = true,
            showline   = true,
            linewidth  = 1,
            linecolor  = "black",
            mirror     = true,
            ticks      = "outside",
        )
    end

    ix_layout = Layout(
        images        = frame_images,
        width         = fig_width,
        height        = fig_height,
        autosize      = false,
        margin        = attr(autoexpand=false, l=0, r=r_margin, b=b_margin, t=t_margin, pad=1),
        xaxis_range   = data.Xrange,
        yaxis_range   = [display_pressure(data.Yrange[1]), display_pressure(data.Yrange[2])],
        xaxis         = xaxis_attr,
        yaxis         = yaxis_attr,
        annotations   = annotations,
        paper_bgcolor = "white",
        plot_bgcolor  = "white",
        uirevision    = "constant",
    )

    return plot(traces, ix_layout)
end


# ────────────────────────────────────────────────────────────────────────────
# Dash callbacks
# ────────────────────────────────────────────────────────────────────────────

function Tab_IntersecT_Callbacks(app)

    # ── Callback 1: Toggle Setup collapse ────────────────────────────────────
    callback!(
        app,
        Output("collapse-setup-ix",   "is_open"),
        Input("button-setup-ix",      "n_clicks"),
        State("collapse-setup-ix",    "is_open"),
        prevent_initial_call = true,
    ) do n, is_open
        return n > 0 ? is_open == 0 : is_open
    end

    # ── Callback 2: Toggle Results collapse ───────────────────────────────────
    callback!(
        app,
        Output("collapse-results-ix",  "is_open"),
        Input("button-results-ix",     "n_clicks"),
        State("collapse-results-ix",   "is_open"),
        prevent_initial_call = true,
    ) do n, is_open
        return n > 0 ? is_open == 0 : is_open
    end

    # ── Callback 2b: Toggle Options collapse ──────────────────────────────────
    callback!(
        app,
        Output("collapse-options-ix",  "is_open"),
        Input("button-options-ix",     "n_clicks"),
        State("collapse-options-ix",   "is_open"),
        prevent_initial_call = true,
    ) do n, is_open
        return n > 0 ? is_open == 0 : is_open
    end

    # ── Callback 3: Load measurement CSV ─────────────────────────────────────
    callback!(
        app,
        Output("phase-checklist-ix",   "options"),
        Output("phase-checklist-ix",   "value"),
        Output("upload-status-ix",     "children"),
        Output("iso-phase-dd-ix",      "options"),
        Output("iso-phase-dd-ix",      "value"),
        Input("upload-measurements-ix", "contents"),
        State("upload-measurements-ix", "filename"),
        prevent_initial_call = true,
    ) do contents, filename

        global measurements_ix, Out_XY

        no_file = ([], [], "*No file loaded*", [], nothing)

        isnothing(contents) && return no_file

        try
            df = _parse_measurements_upload(contents)
            global measurements_ix = df

            meas_phases = _phases_from_headers(df)

            raw_phases = (@isdefined(Out_XY) && !isnothing(Out_XY) && length(Out_XY) > 0) ?
                list_intersect_phases(Out_XY) : meas_phases

            all_phases   = [display_ph_name(ph) for ph in raw_phases]
            intersection = filter(ph -> ph in meas_phases, all_phases)
            options      = [Dict("label" => " "*ph, "value" => ph) for ph in intersection]
            preselected  = intersection

            n_elem     = ncol(df)
            meas_str   = join(names(df), ", ")
            status_msg = "**$(filename)**\n\n$(n_elem) measurements: $(meas_str)\n\nPhases found: $(join(meas_phases, ", "))"

            iso_opts = [Dict("label" => ph, "value" => ph) for ph in meas_phases]
            iso_val  = isempty(meas_phases) ? nothing : meas_phases[1]

            return options, preselected, status_msg, iso_opts, iso_val

        catch e
            return [], [], "**Error loading file:** $(sprint(showerror, e))", [], nothing
        end
    end

    # ── Callback 4: Run IntersecT ─────────────────────────────────────────────
    # Callback 4: Run IntersecT.
    # Outputs only dropdown options/value and alert — NOT the figure.
    # Setting the dropdown value chains into callback 5, which renders the figure.
    # This avoids the Dash rule that forbids two callbacks sharing the same output.
    callback!(
        app,
        Output("field-dropdown-ix",       "options"),
        Output("field-dropdown-ix",       "value"),
        Output("intersect-alert-ix",      "is_open"),
        Output("intersect-alert-ix",      "children"),
        Output("intersect-alert-ix",      "color"),
        Output("field-dropdown-ix-1",     "options"),
        Output("field-dropdown-ix-1",     "value"),
        Output("field-dropdown-ix-2",     "options"),
        Output("field-dropdown-ix-2",     "value"),
        Output("intersect-run-store-ix",  "data"),
        Input("run-intersect-ix",         "n_clicks"),
        State("phase-checklist-ix",       "value"),
        State("analysis-type-ix",         "value"),
        prevent_initial_call = true,
    ) do n_clicks, selected_phases, analysis_type

        global Out_XY, measurements_ix, Out_intersect

        # Guards
        if !(@isdefined(Out_XY)) || isnothing(Out_XY) || length(Out_XY) == 0
            return [], nothing, true,
                   "No phase diagram found. Compute a PT diagram first.", "danger",
                   [], nothing, [], nothing, n_clicks
        end
        if isnothing(measurements_ix)
            return [], nothing, true,
                   "No measurement file loaded. Upload a CSV first.", "danger",
                   [], nothing, [], nothing, n_clicks
        end
        if isnothing(selected_phases) || length(selected_phases) == 0
            return [], nothing, true,
                   "No phases selected. Check at least one phase in the checklist.", "warning",
                   [], nothing, [], nothing, n_clicks
        end

        try
            # Build phase_elements from the measurement file, filtered to selected phases
            phase_elements = filter(names(measurements_ix)) do col
                parts = split(col, '_'; limit=2)
                length(parts) == 2 && (String(parts[1]) in selected_phases)
            end

            if isempty(phase_elements)
                return [], nothing, true,
                       "No matching Phase_Element columns found for the selected phases.", "danger",
                       [], nothing, [], nothing, n_clicks
            end

            model_df = build_intersect_model_df(Out_XY, phase_elements;
                x_col = "T [Celsius]",
                y_col = "P [kbar]",
            )
            result   = IntersecT.run_intersect(
                model_df, measurements_ix;
                x_col         = "T [Celsius]",
                y_col         = "P [kbar]",
                analysis_type = analysis_type,
            )
            global Out_intersect = result

            opts    = _build_field_options(result)
            default = "Qcmp_weighted"

            return opts, default, false, "", "danger",
                   opts, default, opts, default, n_clicks

        catch e
            return [], nothing, true, sprint(showerror, e), "danger",
                   [], nothing, [], nothing, n_clicks
        end
    end

    # ── Callback 5: Auto-set value range when the displayed field changes ───────
    callback!(
        app,
        Output("min-color-ix", "value"),
        Output("max-color-ix", "value"),
        Input("field-dropdown-ix", "value"),
        prevent_initial_call = true,
    ) do field_value

        global Out_intersect

        if isnothing(field_value) || isnothing(Out_intersect)
            return 0.0, 100.0
        end

        vals        = _get_field(Out_intersect, field_value)
        finite_vals = filter(isfinite, vals)
        if isempty(finite_vals)
            return 0.0, 100.0
        end
        return round(minimum(finite_vals), digits=2),
               round(maximum(finite_vals), digits=2)
    end

    # ── Callback 6: Update diagram when dropdown or color/overlay options change ─
    callback!(
        app,
        Output("diagram-ix",            "figure"),
        Input("field-dropdown-ix",      "value"),
        Input("colormaps-ix",           "value"),
        Input("min-color-ix",           "value"),
        Input("max-color-ix",           "value"),
        Input("range-slider-color-ix",  "value"),
        Input("set-min-white-ix",       "value"),
        Input("reverse-colormap-ix",    "value"),
        Input("smooth-colormap-ix",     "value"),
        Input("show-full-grid-ix",      "value"),
        Input("show-lbl-ix",            "value"),
        Input("show-grid-ix",           "value"),
        Input("intersect-run-store-ix", "data"),
        Input("ix-iso-store-ix",        "data"),
        prevent_initial_call = true,
    ) do field_value, colormap, zmin_val, zmax_val, color_range, set_min_white, reverse_cmap, smooth_cmap, show_full_grid, show_lbl, show_grid, _, __

        global Out_intersect

        (isnothing(field_value) || isnothing(Out_intersect)) && return Dict()

        return _render_intersect_figure(
            Out_intersect, field_value;
            colormap       = colormap,
            zmin_val       = zmin_val,
            zmax_val       = zmax_val,
            color_range    = color_range,
            set_min_white  = set_min_white,
            reverse_cmap   = reverse_cmap,
            smooth_cmap    = smooth_cmap,
            show_full_grid = show_full_grid,
            show_lbl       = show_lbl,
            show_grid      = show_grid,
        )
    end

    # ── Callback 7: Sub-diagram 1 ─────────────────────────────────────────────
    callback!(
        app,
        Output("diagram-ix-1",           "figure"),
        Input("field-dropdown-ix-1",     "value"),
        Input("colormaps-ix",            "value"),
        Input("range-slider-color-ix",   "value"),
        Input("set-min-white-ix",        "value"),
        Input("reverse-colormap-ix",     "value"),
        Input("smooth-colormap-ix",      "value"),
        Input("intersect-run-store-ix",  "data"),
        prevent_initial_call = true,
    ) do field_value, colormap, color_range, set_min_white, reverse_cmap, smooth_cmap, _

        global Out_intersect

        if isnothing(field_value) || isnothing(Out_intersect)
            return Dict()
        end

        return _render_intersect_figure(
            Out_intersect, field_value;
            colormap       = colormap,
            color_range    = color_range,
            set_min_white  = set_min_white,
            reverse_cmap   = reverse_cmap,
            smooth_cmap    = smooth_cmap,
            show_full_grid = "false",
            show_lbl       = "false",
            show_grid      = "false",
            fig_width      = 320,
            fig_height     = 260,
            show_logos     = false,
        )
    end

    # ── Callback 8: Sub-diagram 2 ─────────────────────────────────────────────
    callback!(
        app,
        Output("diagram-ix-2",           "figure"),
        Input("field-dropdown-ix-2",     "value"),
        Input("colormaps-ix",            "value"),
        Input("range-slider-color-ix",   "value"),
        Input("set-min-white-ix",        "value"),
        Input("reverse-colormap-ix",     "value"),
        Input("smooth-colormap-ix",      "value"),
        Input("intersect-run-store-ix",  "data"),
        prevent_initial_call = true,
    ) do field_value, colormap, color_range, set_min_white, reverse_cmap, smooth_cmap, _

        global Out_intersect

        if isnothing(field_value) || isnothing(Out_intersect)
            return Dict()
        end

        return _render_intersect_figure(
            Out_intersect, field_value;
            colormap       = colormap,
            color_range    = color_range,
            set_min_white  = set_min_white,
            reverse_cmap   = reverse_cmap,
            smooth_cmap    = smooth_cmap,
            show_full_grid = "false",
            show_lbl       = "false",
            show_grid      = "false",
            fig_width      = 320,
            fig_height     = 260,
            show_logos     = false,
        )
    end

    # ── Callback 9a: Type selector → show/hide sections + populate field dropdown
    callback!(
        app,
        Output("iso-meas-section-ix",  "style"),
        Output("iso-field-section-ix", "style"),
        Output("iso-field-dd-ix",      "options"),
        Output("iso-field-dd-ix",      "value"),
        Input("iso-type-ix",           "value"),
        prevent_initial_call = true,
    ) do iso_type

        global Out_intersect

        show  = Dict("display" => "block")
        hide  = Dict("display" => "none")

        if iso_type == "Field"
            opts = (@isdefined(Out_intersect) && !isnothing(Out_intersect)) ?
                   _build_field_options(Out_intersect) : []
            val  = isempty(opts) ? nothing : opts[1]["value"]
            return hide, show, opts, val
        else
            return show, hide, [], nothing
        end
    end

    # ── Callback 9b: Phase or field selection → elem dropdown + min/step/max ──
    callback!(
        app,
        Output("iso-elem-dd-ix", "options"),
        Output("iso-elem-dd-ix", "value"),
        Output("iso-min-ix",     "value"),
        Output("iso-step-ix",    "value"),
        Output("iso-max-ix",     "value"),
        Input("iso-phase-dd-ix", "value"),
        Input("iso-field-dd-ix", "value"),
        State("iso-type-ix",     "value"),
        prevent_initial_call = true,
    ) do phase_name, field_dd, iso_type

        global measurements_ix, Out_intersect

        bid = pushed_button(callback_context())

        # Field type: triggered by field dropdown change
        if something(iso_type, "Measurements") == "Field" || bid == "iso-field-dd-ix"
            (isnothing(field_dd) || !(@isdefined(Out_intersect)) || isnothing(Out_intersect)) &&
                return no_update(), no_update(), 0.0, 0.1, 1.0
            vals        = _get_field(Out_intersect, field_dd)
            finite_vals = filter(isfinite, vals)
            if isempty(finite_vals)
                return no_update(), no_update(), 0.0, 0.1, 1.0
            end
            vmin  = round(minimum(finite_vals), digits=3)
            vmax  = round(maximum(finite_vals), digits=3)
            vstep = max(round((vmax - vmin) / 10, digits=3), 1e-6)
            return no_update(), no_update(), vmin, vstep, vmax
        end

        # Measurements type: triggered by phase dropdown change
        if isnothing(phase_name) || !(@isdefined(measurements_ix)) || isnothing(measurements_ix)
            return [], nothing, 0.0, 0.1, 1.0
        end
        meas_cols = filter(names(measurements_ix)) do col
            parts = split(col, '_'; limit=2)
            length(parts) == 2 && String(parts[1]) == phase_name
        end
        elems = [String(split(col, '_'; limit=2)[2]) for col in meas_cols]
        isempty(elems) && return [], nothing, 0.0, 0.1, 1.0

        opts       = [Dict("label" => e, "value" => e) for e in elems]
        first_elem = elems[1]
        field       = _get_apfu_field(phase_name, first_elem)
        finite_vals = filter(isfinite, field)
        if isempty(finite_vals)
            return opts, first_elem, 0.0, 0.1, 1.0
        end
        vmin  = round(minimum(finite_vals), digits=3)
        vmax  = round(maximum(finite_vals), digits=3)
        vstep = max(round((vmax - vmin) / 10, digits=3), 1e-4)
        return opts, first_elem, vmin, vstep, vmax
    end

    # ── Callback 11: Isopleth management (Add/Hide/Show/Remove) ──────────────
    callback!(
        app,
        Output("isopleth-list-ix",        "options"),
        Output("isopleth-list-ix",        "value"),
        Output("hidden-isopleth-list-ix", "options"),
        Output("hidden-isopleth-list-ix", "value"),
        Output("ix-iso-store-ix",         "data"),
        Input("button-add-iso-ix",        "n_clicks"),
        Input("button-hide-iso-ix",       "n_clicks"),
        Input("button-hide-all-iso-ix",   "n_clicks"),
        Input("button-remove-iso-ix",     "n_clicks"),
        Input("button-remove-all-iso-ix", "n_clicks"),
        Input("button-show-iso-ix",       "n_clicks"),
        Input("button-show-all-iso-ix",   "n_clicks"),
        State("iso-type-ix",              "value"),
        State("iso-phase-dd-ix",          "value"),
        State("iso-elem-dd-ix",           "value"),
        State("iso-field-dd-ix",          "value"),
        State("iso-min-ix",               "value"),
        State("iso-step-ix",              "value"),
        State("iso-max-ix",               "value"),
        State("colorpicker-iso-ix",       "value"),
        State("iso-lstyle-ix",            "value"),
        State("iso-lwidth-ix",            "value"),
        State("iso-lsize-ix",             "value"),
        State("isopleth-list-ix",         "value"),
        State("hidden-isopleth-list-ix",  "value"),
        State("ix-iso-store-ix",          "data"),
        prevent_initial_call = true,
    ) do _, _, _, _, _, _, _,
        iso_type, phase, elem, field_dd, minv, stepv, maxv, color, lstyle, lwidth, lsize,
        sel_active, sel_hidden, store_cnt

        global ix_isopleths, Out_XY, Out_intersect

        bid = pushed_button(callback_context())
        isnothing(ix_isopleths) && initialize_ix_isopleths()

        no_change = ([], nothing, [], nothing, store_cnt)
        use_field = something(iso_type, "Measurements") == "Field"

        if bid == "button-add-iso-ix"
            (!@isdefined(Out_XY) || isnothing(Out_XY) || isempty(Out_XY)) && return no_change
            if use_field
                isnothing(field_dd) && return no_change
                (!@isdefined(Out_intersect) || isnothing(Out_intersect)) && return no_change
                raw_field = _get_field(Out_intersect, field_dd)
                lbl       = "$(_field_label(Out_intersect, field_dd))"
            else
                (isnothing(phase) || isnothing(elem)) && return no_change
                raw_field = _get_apfu_field(phase, elem)
                lbl       = "$(phase) $(elem)_apfu"
            end
            ispl, ispl_hid = _add_ix_iso_from_field(
                raw_field, lbl,
                Float64(something(minv, 0.0)), Float64(something(stepv, 0.1)), Float64(something(maxv, 1.0)),
                something(color, "#000000"), something(lstyle, "solid"),
                something(lwidth, 1), something(lsize, 10),
            )
            return ispl, nothing, ispl_hid, nothing, store_cnt + 1

        elseif bid == "button-hide-iso-ix"
            isnothing(sel_active) && return no_change
            ispl, ispl_hid = hide_ix_isopleth(sel_active)
            return ispl, nothing, ispl_hid, nothing, store_cnt + 1

        elseif bid == "button-hide-all-iso-ix"
            ispl, ispl_hid = hide_all_ix_isopleths()
            return ispl, nothing, ispl_hid, nothing, store_cnt + 1

        elseif bid == "button-remove-iso-ix"
            isnothing(sel_active) && return no_change
            ispl, ispl_hid = remove_ix_isopleth(sel_active)
            return ispl, nothing, ispl_hid, nothing, store_cnt + 1

        elseif bid == "button-remove-all-iso-ix"
            remove_all_ix_isopleths()
            return [], nothing, [], nothing, store_cnt + 1

        elseif bid == "button-show-iso-ix"
            isnothing(sel_hidden) && return no_change
            ispl, ispl_hid = show_ix_isopleth(sel_hidden)
            return ispl, nothing, ispl_hid, nothing, store_cnt + 1

        elseif bid == "button-show-all-iso-ix"
            ispl, ispl_hid = show_all_ix_isopleths()
            return ispl, nothing, ispl_hid, nothing, store_cnt + 1

        else
            return no_change
        end
    end

    # ── Callback 12: Figure caption (legend above main diagram) ──────────────
    callback!(
        app,
        Output("diagram-cap-ix", "figure"),
        Output("diagram-cap-ix", "style"),
        Input("ix-iso-store-ix", "data"),
    ) do _

        global ix_isopleths

        n_active = (isnothing(ix_isopleths) || isempty(ix_isopleths.active)) ? 0 : length(ix_isopleths.active)

        if n_active == 0
            return plot(Layout(height=1, paper_bgcolor="white", plot_bgcolor="white",
                               margin=attr(l=0,r=0,t=0,b=0,pad=0))),
                   Dict("display" => "none")
        end

        n_rows     = ceil(Int, n_active / 4)
        cap_height = max(30, 28 * n_rows)

        cap_layout = Layout(
            height        = cap_height,
            plot_bgcolor  = "white",
            paper_bgcolor = "white",
            margin        = attr(l=5, r=5, t=5, b=5, pad=0),
            xaxis         = attr(showticklabels=false, showgrid=false, zeroline=false,
                                 showline=false, visible=false),
            yaxis         = attr(showticklabels=false, showgrid=false, zeroline=false,
                                 showline=false, visible=false),
            legend        = attr(x=0.0, xanchor="left", y=1.0, yanchor="top",
                                 orientation="h", bgcolor="rgba(0,0,0,0)"),
            showlegend    = true,
        )

        caps = [scatter(
            x          = [nothing],
            y          = [nothing],
            mode       = "lines",
            line       = ix_isopleths.isoCap[ix_isopleths.active[i]][:line],
            name       = replace(ix_isopleths.label[ix_isopleths.active[i]], r" \[.*\]$" => ""),
            showlegend = true,
        ) for i in 1:n_active]

        return plot(caps, cap_layout),
               Dict("display" => "block", "height" => "$(cap_height)px")
    end

    return app
end
