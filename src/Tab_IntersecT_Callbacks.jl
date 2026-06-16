#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

# Global state for the IntersecT tab
global measurements_ix = nothing   # DataFrame: parsed measurements CSV (2 rows)
global Out_intersect   = nothing   # IntersecTResult from last run

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

    # gridded[T_idx, P_idx] — same index convention as get_gridded_map.
    # NaN values remain nothing (JSON null); Plotly leaves those cells blank.
    gridded = Matrix{Union{Nothing, Float64}}(nothing, n, n)
    for k in 1:min(np, length(values))
        v = values[k]
        isnan(v) && continue
        ii = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj = compute_index(data.points[k][2], data.Yrange[1], dy)
        (1 ≤ ii ≤ n && 1 ≤ jj ≤ n) || continue
        gridded[ii, jj] = v
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

    # Collect traces: IntersecT heatmap first, then optional overlays
    traces = AbstractTrace[trace]

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
    frame_with_logos = vcat(collect(frame), [intersect_logo])

    ix_layout = Layout(
        images        = frame_with_logos,
        width         = 640,
        height        = 640,
        autosize      = false,
        margin        = attr(autoexpand=false, l=0, r=116, b=50, t=50, pad=1),
        xaxis_range   = data.Xrange,
        yaxis_range   = [display_pressure(data.Yrange[1]), display_pressure(data.Yrange[2])],
        xaxis         = attr(
            title     = result.x_label,
            tickmode  = "linear",
            tick0     = data.Xrange[1],
            dtick     = (data.Xrange[2] - data.Xrange[1]) / (ticks + 1),
            fixedrange = true,
        ),
        yaxis         = attr(
            title     = "P [$(pressure_unit_label())]",
            tickmode  = "linear",
            tick0     = display_pressure(data.Yrange[1]),
            dtick     = display_pressure((data.Yrange[2] - data.Yrange[1]) / (ticks + 1)),
            fixedrange = true,
        ),
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
    # Triggered when the user uploads a file.
    # Populates the phase checklist (all diagram phases as options, measurement
    # phases pre-selected) and updates the status markdown.
    callback!(
        app,
        Output("phase-checklist-ix",  "options"),
        Output("phase-checklist-ix",  "value"),
        Output("upload-status-ix",    "children"),
        Input("upload-measurements-ix", "contents"),
        State("upload-measurements-ix", "filename"),
        prevent_initial_call = true,
    ) do contents, filename

        global measurements_ix, Out_XY

        if isnothing(contents)
            return [], [], "*No file loaded*"
        end

        try
            df = _parse_measurements_upload(contents)
            global measurements_ix = df

            meas_phases = _phases_from_headers(df)

            # Build checklist options from diagram phases, converted to Warr 2021 names.
            # Internal MAGEMin names (e.g. "g", "bi") are mapped to Warr abbreviations
            # (e.g. "Grt", "Bt") so they match the Phase_Element headers in the CSV.
            raw_phases = (  @isdefined(Out_XY) &&
                            !isnothing(Out_XY) &&
                            length(Out_XY) > 0       ) ?
                list_intersect_phases(Out_XY) : meas_phases

            all_phases  = [display_ph_name(ph) for ph in raw_phases]

            # Only list phases present in BOTH the diagram AND the measurement file
            intersection = filter(ph -> ph in meas_phases, all_phases)
            options      = [Dict("label" => " "*ph, "value" => ph) for ph in intersection]
            preselected  = intersection

            n_elem     = ncol(df)
            meas_str   = join(names(df), ", ")
            status_msg = "**$(filename)**\n\n$(n_elem) measurements: $(meas_str)\n\nPhases found: $(join(meas_phases, ", "))"

            return options, preselected, status_msg

        catch e
            return [], [], "**Error loading file:** $(sprint(showerror, e))"
        end
    end

    # ── Callback 4: Run IntersecT ─────────────────────────────────────────────
    # Callback 4: Run IntersecT.
    # Outputs only dropdown options/value and alert — NOT the figure.
    # Setting the dropdown value chains into callback 5, which renders the figure.
    # This avoids the Dash rule that forbids two callbacks sharing the same output.
    callback!(
        app,
        Output("field-dropdown-ix",   "options"),
        Output("field-dropdown-ix",   "value"),
        Output("intersect-alert-ix",  "is_open"),
        Output("intersect-alert-ix",  "children"),
        Output("intersect-alert-ix",  "color"),
        Input("run-intersect-ix",     "n_clicks"),
        State("phase-checklist-ix",   "value"),
        State("analysis-type-ix",     "value"),
        prevent_initial_call = true,
    ) do _, selected_phases, analysis_type

        global Out_XY, measurements_ix, Out_intersect

        # Guards
        if !(@isdefined(Out_XY)) || isnothing(Out_XY) || length(Out_XY) == 0
            return [], nothing, true,
                   "No phase diagram found. Compute a PT diagram first.", "danger"
        end
        if isnothing(measurements_ix)
            return [], nothing, true,
                   "No measurement file loaded. Upload a CSV first.", "danger"
        end
        if isnothing(selected_phases) || length(selected_phases) == 0
            return [], nothing, true,
                   "No phases selected. Check at least one phase in the checklist.", "warning"
        end

        try
            # Build phase_elements from the measurement file, filtered to selected phases
            phase_elements = filter(names(measurements_ix)) do col
                parts = split(col, '_'; limit=2)
                length(parts) == 2 && (String(parts[1]) in selected_phases)
            end

            if isempty(phase_elements)
                return [], nothing, true,
                       "No matching Phase_Element columns found for the selected phases.", "danger"
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

            return opts, default, false, "", "danger"

        catch e
            return [], nothing, true, sprint(showerror, e), "danger"
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
        Output("diagram-ix",             "figure"),
        Input("field-dropdown-ix",       "value"),
        Input("colormaps-ix",            "value"),
        Input("min-color-ix",            "value"),
        Input("max-color-ix",            "value"),
        Input("range-slider-color-ix",   "value"),
        Input("set-min-white-ix",        "value"),
        Input("reverse-colormap-ix",     "value"),
        Input("smooth-colormap-ix",      "value"),
        Input("show-full-grid-ix",       "value"),
        Input("show-lbl-ix",             "value"),
        Input("show-grid-ix",            "value"),
        prevent_initial_call = true,
    ) do field_value, colormap, zmin_val, zmax_val, color_range, set_min_white, reverse_cmap, smooth_cmap, show_full_grid, show_lbl, show_grid

        global Out_intersect

        if isnothing(field_value) || isnothing(Out_intersect)
            return Dict()
        end

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

    return app
end
