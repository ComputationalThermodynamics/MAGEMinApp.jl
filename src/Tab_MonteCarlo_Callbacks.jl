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

function Tab_MonteCarlo_Callbacks(app)

    """
        Populate/reset the Uncertainty tab's per-oxide σ table: from the
        current Setup-tab bulk on first opening the tab, from
        `mc_default_sigma.csv` on "Reset", with one value applied to every
        row on "Apply to all oxides", from the selected bulk-rock's own WDS
        data (`_wds` CSV columns, see `bulk_csv_to_db`) on "Load WDS from
        bulk" (which also switches the mode to "absolute", since WDS values
        are absolute mol% 1σ, not a % of each oxide's value), or re-expressed
        in the other unit on a mol%/wt% toggle.

        A "relative %" σ is unit-independent (it is already a % of that
        oxide's own value, whichever unit that value is shown in) and is
        never touched by the unit toggle. An "absolute" σ is not, so
        switching units converts it via [`mc_convert_absolute_sigma`](@ref),
        using `mc-bulk-unit-prev` (the unit the table was last rendered in)
        to know which direction to convert.
    """
    callback!(
        app,
        Output("mc-sigma-table",       "data"),
        Output("mc-sigma-table",       "columns"),
        Output("mc-sigma-mode",        "value"),
        Output("mc-sigma-wds-warning", "children"),
        Output("mc-sigma-wds-warning", "is_open"),
        Output("mc-bulk-unit-prev",    "data"),

        Input("pd-sidebar-tabs",       "active_tab"),
        Input("mc-sigma-reset-button", "n_clicks"),
        Input("mc-sigma-all-button",   "n_clicks"),
        Input("mc-sigma-wds-button",   "n_clicks"),
        Input("mc-bulk-unit",          "value"),

        State("table-bulk-rock",    "data"),
        State("select-bulk-unit",   "value"),
        State("mc-sigma-table",     "data"),
        State("mc-sigma-all-value", "value"),
        State("database-dropdown",  "value"),
        State("test-dropdown",      "value"),
        State("mc-sigma-mode",      "value"),
        State("mc-bulk-unit-prev",  "data"),

        prevent_initial_call = true,
    ) do active_tab, _n_reset, _n_all, _n_wds, mc_bulk_unit,
            bulk1, sys_unit, sigma_data, sigma_all_value, dtb, test_val, sigma_mode, prev_unit

        bid = pushed_button( callback_context() )

        if bid == "pd-sidebar-tabs" && (active_tab != "tab-uncertainty" || !isempty(sigma_data))
            return no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
        end

        columns(unit) = [
            Dict("id" => "oxide", "name" => "oxide"),
            Dict("id" => "value", "name" => unit == 2 ? "value [wt%]" : "value [mol%]"),
            Dict("id" => "sigma", "name" => "σ", "editable" => true),
        ]

        if bid == "mc-sigma-all-button"
            if isempty(sigma_data)
                return no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
            end
            new_data = [Dict("oxide" => r[:oxide], "value" => r[:value], "sigma" => sigma_all_value) for r in sigma_data]
            return new_data, no_update(), no_update(), no_update(), no_update(), no_update()
        end

        if bid == "mc-sigma-wds-button"
            if isempty(sigma_data)
                return no_update(), no_update(), no_update(), "Open the Uncertainty tab (or compute a phase diagram) first.", true, no_update()
            end
            if !hasproperty(db, :wds)
                return no_update(), no_update(), no_update(), "No bulk-rock CSV with WDS (_wds) columns has been loaded yet.", true, no_update()
            end

            rows = db[(db.db .== dtb) .& (db.test .== test_val), :]
            wds_by_oxide = (isempty(rows) || ismissing(rows.wds[1])) ? Dict{String,Float64}() :
                Dict(rows.oxide[1][k] => rows.wds[1][k] for k in eachindex(rows.oxide[1]) if !isnan(rows.wds[1][k]))

            if isempty(wds_by_oxide)
                return no_update(), no_update(), no_update(), "No WDS data for the currently selected bulk-rock composition.", true, no_update()
            end

            # WDS is always computed in absolute mol% (bulk_csv_to_db), so if the table
            # is currently showing wt%, the loaded σ must be converted to match
            oxi_row = rows.oxide[1]
            if mc_bulk_unit == 2
                bulk_L, _, oxi = get_bulkrock_prop(bulk1, bulk1; sys_unit = sys_unit)
                vals_mol = Dict(oxi[i] => bulk_L[i]*100.0 for i in eachindex(oxi))
                wds_mol  = [get(wds_by_oxide, ox, NaN) for ox in oxi_row]
                bulk_mol = [get(vals_mol, ox, 0.0) for ox in oxi_row]
                wds_wt   = mc_convert_absolute_sigma(bulk_mol, wds_mol, oxi_row, true)
                wds_by_oxide = Dict(oxi_row[k] => wds_wt[k] for k in eachindex(oxi_row) if !isnan(wds_wt[k]))
            end

            new_data = [Dict("oxide" => r[:oxide], "value" => r[:value], "sigma" => get(wds_by_oxide, r[:oxide], r[:sigma])) for r in sigma_data]
            return new_data, no_update(), "absolute", no_update(), false, no_update()
        end

        bulk_L, _, oxi = get_bulkrock_prop(bulk1, bulk1; sys_unit = sys_unit)
        vals_mol = bulk_L .* 100.0
        vals_wt  = mol2wt(bulk_L, oxi)     # mol2wt renormalizes its own output to sum 100, like vals_mol above

        if bid == "mc-bulk-unit"
            if isempty(sigma_data)
                return no_update(), no_update(), no_update(), no_update(), no_update(), mc_bulk_unit
            end

            sigma_lookup = Dict(String(r[:oxide]) => (r[:sigma] isa String ? parse(Float64, r[:sigma]) : Float64(r[:sigma])) for r in sigma_data)
            sigma_old    = [get(sigma_lookup, oxi[i], 0.0) for i in eachindex(oxi)]

            if sigma_mode == "absolute" && prev_unit != mc_bulk_unit
                vals_prev = prev_unit == 2 ? vals_wt : vals_mol
                converted = mc_convert_absolute_sigma(vals_prev, sigma_old, oxi, mc_bulk_unit == 2)
                sigma_new = [isnan(converted[i]) ? sigma_old[i] : converted[i] for i in eachindex(converted)]
            else
                sigma_new = sigma_old
            end

            vals_new = mc_bulk_unit == 2 ? vals_wt : vals_mol
            new_data = [Dict("oxide" => oxi[i], "value" => round(vals_new[i], digits = 4), "sigma" => round(sigma_new[i], digits = 6)) for i in eachindex(oxi)]
            return new_data, columns(mc_bulk_unit), no_update(), no_update(), no_update(), mc_bulk_unit
        end

        # tab opened for the first time, or "Reset"
        vals  = mc_bulk_unit == 2 ? vals_wt : vals_mol
        sigma = mc_sigma_for_oxides(oxi)   # always relative %, so unit-independent

        new_data = [Dict("oxide" => oxi[i], "value" => round(vals[i], digits = 4), "sigma" => sigma[i]) for i in eachindex(oxi)]
        return new_data, columns(mc_bulk_unit), no_update(), no_update(), no_update(), mc_bulk_unit
    end

    """
        Render the Uncertainty results panel: after a Monte Carlo run
        finishes (`mc-run-done`, written by the same compute-button/
        refine-pb-button callback in Tab_PhaseDiagram_Callbacks.jl that runs
        Monte Carlo itself, reusing its CompProgress/progress-bar machinery),
        rebuilding the figure from the `mc_result` global, or on a label
        change, also rebuilding. The Filter card's "Max lines" and phase
        checklist are only *staged* until "Apply" (the rebuild re-traces
        every phase for every drawn realization, so it is not run per tick):
        `mc_shown_phases`/`mc_shown_max` hold what is currently applied, and
        the label toggle rebuilds with those rather than with a possibly
        unapplied checklist. A new run resets the phases to all and takes the
        current "Max lines". Opening the panel from the "Show results" button
        ("mc-canvas-button") does *not* rebuild the figure - it only opens
        the offcanvas, leaving whatever it last displayed exactly as it was.
    """
    callback!(
        app,
        Output("mc-diagram",    "figure"),
        Output("mc-run-status", "children"),
        Output("mc-run-failed", "is_open"),
        Output("mc-canvas",     "is_open"),

        Input("mc-run-done",          "data"),
        Input("mc-canvas-button",     "n_clicks"),
        Input("mc-show-labels-switch","value"),
        Input("mc-show-boundaries-switch","value"),
        Input("mc-smooth-lines-switch","value"),
        Input("mc-phase-apply-button","n_clicks"),

        State("mc-phase-selection",   "value"),
        State("mc-max-lines",         "value"),

        prevent_initial_call = true,
    ) do mc_done, _n_canvas, show_labels, show_bounds, smooth_lines, _n_apply, phase_sel, max_lines

        global mc_result, mc_shown_phases, mc_shown_max
        bid = pushed_button( callback_context() )

        if bid == "mc-canvas-button"
            return no_update(), no_update(), no_update(), true
        end

        if bid in ("mc-show-labels-switch", "mc-show-boundaries-switch", "mc-smooth-lines-switch")
            if isnothing(mc_result)
                return no_update(), no_update(), no_update(), no_update()
            end
            fig = mc_build_figure(mc_result, show_labels; phases = mc_shown_phases, max_lines = something(mc_shown_max, mc_default_max_lines), show_boundaries = show_bounds == true, smooth_lines = smooth_lines == true)
            return fig, no_update(), no_update(), no_update()
        end

        if bid == "mc-phase-apply-button"
            if isnothing(mc_result)
                return no_update(), no_update(), no_update(), no_update()
            end
            mc_shown_phases = Vector{String}(something(phase_sel, String[]))
            mc_shown_max    = mc_max_lines_value(max_lines)
            fig = mc_build_figure(mc_result, show_labels; phases = mc_shown_phases, max_lines = mc_shown_max, show_boundaries = show_bounds == true, smooth_lines = smooth_lines == true)
            return fig, no_update(), no_update(), no_update()
        end

        if bid == "mc-run-done"
            if isnothing(mc_done) || startswith(mc_done, "failed")
                return no_update(), no_update(), true, no_update()
            elseif startswith(mc_done, "ok:") && !isnothing(mc_result)
                _, N_str, t_str = split(mc_done, ":")
                mc_shown_phases = Vector{String}(mc_phases_to_draw(mc_result))
                mc_shown_max    = mc_max_lines_value(max_lines)
                fig    = mc_build_figure(mc_result, show_labels; phases = mc_shown_phases, max_lines = mc_shown_max, show_boundaries = show_bounds == true, smooth_lines = smooth_lines == true)
                status = "Done: $N_str realizations in $t_str s."
                return fig, status, false, true
            end
        end

        return no_update(), no_update(), no_update(), no_update()
    end

    """
        Warn, when "Apply" is pressed with more than the default number of
        lines, that drawing them may take a while (the figure is still
        drawn; the alert dismisses itself).
    """
    callback!(
        app,
        Output("mc-filter-warning", "children"),
        Output("mc-filter-warning", "is_open"),

        Input("mc-phase-apply-button", "n_clicks"),

        State("mc-max-lines", "value"),

        prevent_initial_call = true,
    ) do _n, max_lines

        n = mc_max_lines_value(max_lines)
        if n > mc_default_max_lines
            return "Drawing $n lines may take a while.", true
        end
        return no_update(), false
    end

    """
        Compute the probability map ([`mc_probability_traces`](@ref)) of a
        target field from the last Monte Carlo run: per-node fraction of
        realizations whose field contains that node as a heatmap, with
        2.5/50/97.5% contours of each target phase's own stability in that
        phase's color, and the reference diagram's own phase boundaries of the
        target phases (as the main diagram's reaction lines).
        Takes its target phases/match mode from its own inputs.
    """
    callback!(
        app,
        Output("mc-heatmap-status", "children"),
        Output("mc-heatmap",        "figure"),

        Input("mc-heatmap-compute-button", "n_clicks"),

        State("mc-heatmap-target",     "value"),
        State("mc-heatmap-match-mode", "value"),

        prevent_initial_call = true,
    ) do _n_clicks, target_str, match_mode

        global mc_result, gridded_fields, mc_probability_last

        if isnothing(mc_result)
            return "Run Monte Carlo first.", no_update()
        end

        target = String.(split(something(target_str, ""), r"[,\s]+"; keepempty = false))
        if isempty(target)
            return "Enter at least one target phase.", no_update()
        end

        strict = match_mode == "strict"
        parts  = mc_probability_parts(mc_result, gridded_fields, target, strict)
        traces = mc_probability_traces_from_parts(parts)
        grid   = parts.grid

        target_lbl = join(target, " ")
        if grid.n_present == 0
            return "[$target_lbl] is absent from all $(grid.n_total) realizations.", no_update()
        end
        mc_probability_last = (mc_res = mc_result, parts = parts)

        n_nodes   = length(grid.prob)
        n_nonzero = count(>(0), grid.prob)
        status = "[$target_lbl]: present in $(grid.n_present)/$(grid.n_total) realizations; " *
                 "P(field) > 0 at $n_nonzero of $n_nodes nodes (max $(round(maximum(grid.prob), digits = 2))). " *
                 "Phase boundary statistics at 2.5% (dotted), 50% (heavy), 97.5% (dashed); reference phase boundaries in black."
        if n_nonzero < 0.01 * n_nodes
            status *= " The target phases are almost never stable together, so the heatmap is nearly empty - try fewer phases."
        end

        return status, mc_heatmap_figure(traces, mc_result.Xrange, mc_result.Yrange)
    end

    """
        Open/close the "Phases shown" checklist.
    """
    callback!(
        app,
        Output("collapse-mc-phase-selection", "is_open"),
        Input("mc-phase-toggle-button", "n_clicks"),
        State("collapse-mc-phase-selection", "is_open"),
        prevent_initial_call = true,
    ) do _n, is_open
        return is_open != 1
    end

    """
        Fill the "Phases shown" checklist with the phases the diagram draws
        (all selected) after each Monte Carlo run, or select/unselect all of
        them on the buttons. None of these redraw the figure: ticking is
        only staged, and the "Apply" button (results callback above) is what
        commits the selection to the diagram.
    """
    callback!(
        app,
        Output("mc-phase-selection", "options"),
        Output("mc-phase-selection", "value"),

        Input("mc-run-done",          "data"),
        Input("mc-phase-all-button",  "n_clicks"),
        Input("mc-phase-none-button", "n_clicks"),

        prevent_initial_call = true,
    ) do mc_done, _n_all, _n_none

        global mc_result
        bid = pushed_button( callback_context() )

        if isnothing(mc_result)
            return no_update(), no_update()
        end

        if bid == "mc-phase-none-button"
            return no_update(), String[]
        elseif bid == "mc-phase-all-button"
            return no_update(), Vector{String}(mc_phases_to_draw(mc_result))
        elseif bid == "mc-run-done" && !isnothing(mc_done) && startswith(mc_done, "ok:")
            phases  = Vector{String}(mc_phases_to_draw(mc_result))
            options = [Dict("label" => " " * display_ph_name(ph), "value" => ph) for ph in phases]
            return options, phases
        end

        return no_update(), no_update()
    end

    """
        Draw the bulk-variation spider diagram (`mc_spider_figure`) after a run
        and whenever "Apply" is pressed (same "Max lines" as the diagram).
    """
    callback!(
        app,
        Output("mc-spider", "figure"),

        Input("mc-run-done",           "data"),
        Input("mc-phase-apply-button", "n_clicks"),

        State("mc-max-lines", "value"),

        prevent_initial_call = true,
    ) do mc_done, _n, max_lines

        global mc_result
        bid = pushed_button( callback_context() )

        if isnothing(mc_result)
            return no_update()
        end
        if bid == "mc-run-done" && !startswith(something(mc_done, ""), "ok:")
            return no_update()
        end

        return mc_spider_figure(mc_result, mc_max_lines_value(max_lines))
    end

    """
        Save the Uncertainty diagram as a clean layered SVG ([`mc_export_svg`](@ref))
        into the figure directory (`output_dir`), as `<diagram title>_MC.svg`. What
        is written is what is drawn: the applied phases and Max lines
        (`mc_shown_phases`/`mc_shown_max`) and the current switches. The status line
        gives the full path and size, or why the file could not be written.
    """
    callback!(
        app,
        Output("mc-export-svg-status", "children"),

        Input("mc-export-svg-button", "n_clicks"),

        State("mc-show-labels-switch",     "value"),
        State("mc-show-boundaries-switch", "value"),
        State("mc-smooth-lines-switch",    "value"),

        prevent_initial_call = true,
    ) do _n, show_labels, show_bounds, smooth_lines

        global mc_result, mc_shown_phases, mc_shown_max, output_dir

        if isnothing(mc_result)
            return "Run Monte Carlo first."
        end

        try
            mkpath(output_dir[1])
            title = string(mc_diagram_title("")[:text])
            fname = isempty(title) ? "MC" : replace(title, r"[ /\\:]" => "_")
            path  = output_dir[1] * fname * "_MC.svg"
            r = mc_export_svg(mc_result, path; show_labels = show_labels == true, phases = mc_shown_phases,
                               max_lines = something(mc_shown_max, mc_default_max_lines),
                               show_boundaries = show_bounds == true, smooth_lines = smooth_lines == true)
            return "Saved $(r.path) ($(round(r.bytes / 1024, digits = 1)) KB, $(r.n_paths) paths)."
        catch e
            return "Export failed: " * sprint(showerror, e)
        end
    end

    """
        Save the probability map as a clean layered SVG ([`mc_export_probability_svg`](@ref))
        into the figure directory (`output_dir`), as `<title>_Probability.svg`. It
        writes the map last computed with "Compute" (cached in
        `mc_probability_last`, so it is exactly what is on screen and nothing is
        recomputed); a map from an older Monte Carlo run is refused, since it no
        longer matches the current run.
    """
    callback!(
        app,
        Output("mc-heatmap-export-svg-status", "children"),

        Input("mc-heatmap-export-svg-button", "n_clicks"),

        prevent_initial_call = true,
    ) do _n

        global mc_result, mc_probability_last, output_dir

        if isnothing(mc_probability_last)
            return "Compute the probability map first."
        end
        if mc_probability_last.mc_res !== mc_result
            return "This map is from an earlier Monte Carlo run - compute it again."
        end

        try
            mkpath(output_dir[1])
            title = string(mc_diagram_title("")[:text])
            fname = isempty(title) ? "Probability" : replace(title, r"[ /\\:]" => "_")
            path  = output_dir[1] * fname * "_Probability.svg"
            r = mc_export_probability_svg(mc_probability_last.parts, path)
            return "Saved $(r.path) ($(round(r.bytes / 1024, digits = 1)) KB, $(r.n_paths) paths)."
        catch e
            return "Export failed: " * sprint(showerror, e)
        end
    end

    return app
end

"""
    mc_diagram_title(prefix)

    The main phase diagram's own title (`layout[:title]`, whatever it was last
    set to) with `prefix` in front: "MC - " for the Uncertainty diagram,
    "Probability - " for the probability map. Same `attr` (centered at the
    top) as the main diagram's title.
"""
function mc_diagram_title(prefix::String)
    global layout
    base = ""
    if @isdefined(layout) && haskey(layout, :title)
        t    = layout[:title]
        base = t isa AbstractString ? String(t) : (haskey(t, :text) ? string(t[:text]) : "")
    end
    return attr(text = isempty(base) ? rstrip(prefix, [' ', '-']) : prefix * base,
                x = 0.5, xanchor = "center", yanchor = "top")
end

"""
    mc_max_lines_value(x)

    The Filter card's "Max lines" input as an `Int` >= 1 (the default when
    empty/invalid).
"""
function mc_max_lines_value(x)
    x isa Number && isfinite(x) || return mc_default_max_lines
    return max(1, Int(round(x)))
end

"""
    mc_figure_parts(mc_res; show_labels = false, phases = nothing, max_lines = mc_default_max_lines,
                     show_boundaries = true, smooth_lines = false)

    Everything the Uncertainty diagram shows, as data, in the selected pressure
    unit: `(sets, reference, annotations, xrange, yrange, ticks, title, xtitle,
    ytitle)`. `sets` are the realization lines per phase
    ([`mc_spaghetti_sets`](@ref); `phases` restricts them to that subset and
    `max_lines` is how many realizations are drawn), `reference` the primary
    diagram's own phase boundaries of *all* its phases on top of them when
    `show_boundaries` ([`mc_reference_reaction_traces`](@ref); independent of
    `phases`, which only filters the realization lines), `annotations` the main diagram's own
    field labels in data coordinates when `show_labels` (its `layout` global,
    populated by `get_diagram_labels`; only the labels placed on the diagram, not
    the table texts at the bottom of the main diagram), and `smooth_lines` removes
    the raster's one-cell steps from all of the lines. Both the screen figure
    ([`mc_build_figure`](@ref)) and the SVG export ([`mc_export_svg`](@ref)) are
    built from this, so they cannot drift apart. Pressure is converted with
    `display_pressure` here, once (the lines and ranges are kept in kbar
    everywhere else).
"""
function mc_figure_parts(mc_res; show_labels::Bool = false, phases::Union{Nothing,Vector{String}} = nothing,
                          max_lines::Int = mc_default_max_lines, show_boundaries::Bool = true, smooth_lines::Bool = false)
    global gridded_fields, layout

    sets = mc_spaghetti_sets(mc_res, mc_res.Xrange, mc_res.Yrange; max_realizations = max_lines, phases = phases,
                              smooth = smooth_lines)
    sets = [merge(set, (lines = [(k = l.k, x = l.x, y = display_pressure(l.y)) for l in set.lines],)) for set in sets]

    reference = GenericTrace[]
    if show_boundaries
        reference = mc_reference_reaction_traces(mc_primary_phases(), gridded_fields, mc_res.Xrange, mc_res.Yrange; smooth = smooth_lines)
        for t in reference
            t[:y] = display_pressure(t[:y])
        end
    end

    annotations = PlotlyBase.PlotlyAttribute[]
    if show_labels && @isdefined(layout) && haskey(layout, :annotations)
        annotations = [merge(deepcopy(ann), attr(visible = true)) for ann in layout[:annotations]]
        for ann in annotations
            if get(ann.fields, :yref, "") == "y" && haskey(ann.fields, :y) && ann[:y] isa Number
                ann[:y] = display_pressure(Float64(ann[:y]))
            end
        end
    end

    t = mc_diagram_title("MC - ")
    return (sets = sets, reference = reference, annotations = annotations,
            xrange = collect(Float64.(mc_res.Xrange)), yrange = [display_pressure(Float64(y)) for y in mc_res.Yrange],
            ticks = 4, title = string(t[:text]),
            xtitle = "Temperature [Celsius]", ytitle = "Pressure [$(pressure_unit_label())]")
end

"""
    mc_build_figure(mc_res, show_labels; phases = nothing, max_lines = mc_default_max_lines,
                     show_boundaries = true, smooth_lines = false)

    Build the Uncertainty panel's own figure from [`mc_figure_parts`](@ref)
    (which documents the arguments): the realization spaghetti, one pooled trace
    per phase, with the primary diagram's own phase boundaries on top, drawn with
    the exact same *plot area* as the main phase diagram (width 720, height 900
    minus its margins - not scaled down, since scaling it while the offcanvas
    panel wasn't sized to match let the container squeeze the figure and distort
    its aspect ratio), but a shorter canvas (`height=700` vs the main diagram's
    900): the main diagram's `b=260` bottom margin reserves room for content
    baked into that same canvas (its phase-assemblage table); this panel has
    nothing below the plot, so its own bottom margin only needs room for the
    axis title/ticks (`b=60`) - same plot area and P-T proportions, without the
    leftover blank space a copied `b=260` would leave beneath it. Same frame and
    tick styling (`get_plot_frame`).
"""
function mc_build_figure(mc_res, show_labels; phases::Union{Nothing,Vector{String}} = nothing,
                          max_lines::Int = mc_default_max_lines, show_boundaries::Bool = true, smooth_lines::Bool = false)
    parts  = mc_figure_parts(mc_res; show_labels = show_labels == true, phases = phases, max_lines = max_lines,
                              show_boundaries = show_boundaries, smooth_lines = smooth_lines)
    traces = vcat(GenericTrace[mc_spaghetti_trace(set) for set in parts.sets], parts.reference)
    xr, yr = parts.xrange, parts.yrange
    frame  = get_plot_frame(mc_res.Xrange, mc_res.Yrange, parts.ticks)

    mc_layout = Layout(
        images        = frame,
        title         = mc_diagram_title("MC - "),
        width         = 720,
        height        = 700,
        autosize      = false,
        hoverlabel    = attr(bgcolor = "#566573", bordercolor = "#f8f9f9"),
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title   = parts.xtitle,
        yaxis_title   = parts.ytitle,
        annotations   = parts.annotations,
        margin        = attr(autoexpand = false, l = 0, r = 116, b = 60, t = 50, pad = 1),
        xaxis_range   = xr,
        yaxis_range   = yr,
        xaxis         = attr(tickmode = "linear", tick0 = xr[1],
                              dtick = (xr[2] - xr[1]) / (parts.ticks + 1), fixedrange = true),
        yaxis         = attr(tickmode = "linear", tick0 = yr[1],
                              dtick = (yr[2] - yr[1]) / (parts.ticks + 1), fixedrange = true),
    )
    return plot(traces, mc_layout)
end

"""
    mc_heatmap_figure(traces, Xrange, Yrange)

    Wrap the probability map's `traces` in exactly the Uncertainty diagram's
    canvas ([`mc_build_figure`](@ref)): 720 x 700 px with the same margins, so
    the two diagrams have the same size and plot area, the same
    `get_plot_frame` outline/ticks and the same linear ticks and fixed axes
    (pressure in the selected display unit). The right margin, where the
    diagram has its phase legend, holds the colorbar (top) and the per-phase
    contour legend (below it).
"""
function mc_heatmap_figure(traces, Xrange, Yrange)
    ticks = 4
    frame = get_plot_frame(Xrange, Yrange, ticks)
    y1    = display_pressure(Float64(Yrange[1]))
    y2    = display_pressure(Float64(Yrange[2]))

    heat_layout = Layout(
        images        = frame,
        title         = mc_diagram_title("Probability - "),
        width         = 720,
        height        = 700,
        autosize      = false,
        hoverlabel    = attr(bgcolor = "#566573", bordercolor = "#f8f9f9"),
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title   = "Temperature [Celsius]",
        yaxis_title   = "Pressure [$(pressure_unit_label())]",
        margin        = attr(autoexpand = false, l = 0, r = 116, b = 60, t = 50, pad = 1),
        legend        = attr(x = 1.02, xanchor = "left", y = 0.5, yanchor = "top"),
        xaxis_range   = collect(Xrange),
        yaxis_range   = [y1, y2],
        xaxis         = attr(tickmode = "linear", tick0 = Xrange[1],
                              dtick = (Xrange[2] - Xrange[1]) / (ticks + 1), fixedrange = true),
        yaxis         = attr(tickmode = "linear", tick0 = y1,
                              dtick = (y2 - y1) / (ticks + 1), fixedrange = true),
    )
    return plot(traces, heat_layout)
end

"""
    mc_spider_figure(mc_res, max_lines)

    Vertical spider diagram of the bulk-composition variation of a Monte Carlo
    run: horizontal axis the change of each oxide from the primary bulk
    (`(bulks - bulk_ref) * 100`, mol%), vertical axis the oxides (first oxide
    on top). One blue line at 0.6 opacity per drawn realization (the first
    `max_lines`, as in the diagram; separate traces so overlapping lines
    darken), then the primary composition (zero change) in black, drawn last.
    180 px wide to fit its column, tall enough for one row per oxide; framed
    with the same thin dark outline and outside tick marks as the diagrams
    (mirrored axis lines).
"""
function mc_spider_figure(mc_res, max_lines::Int)
    oxi    = String.(mc_res.oxides)
    n      = length(oxi)
    delta  = (mc_res.bulks .- reshape(mc_res.bulk_ref, 1, :)) .* 100.0
    n_draw = min(size(delta, 1), max_lines)

    traces = GenericTrace[]
    for k in 1:n_draw
        push!(traces, scatter(x = delta[k, :], y = oxi, mode = "lines", hoverinfo = "skip", showlegend = false,
                               opacity = 0.6, line = attr(color = "blue", width = 1)))
    end
    push!(traces, scatter(x = zeros(n), y = oxi, mode = "lines", hoverinfo = "skip", showlegend = false,
                           line = attr(color = "black", width = 1.5), name = "primary"))

    spider_layout = Layout(
        width         = 180,
        height        = max(300, 100 + 22 * n),
        autosize      = false,
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        margin        = attr(l = 46, r = 8, t = 8, b = 42, pad = 1),
        xaxis         = attr(title = attr(text = "Δ bulk [mol%]", font = attr(size = 10)),
                              tickfont = attr(size = 9), zeroline = false, fixedrange = true,
                              showline = true, mirror = true, linecolor = "#333333", linewidth = 1,
                              ticks = "outside", tickcolor = "#333333", ticklen = 3),
        yaxis         = attr(type = "category", categoryorder = "array", categoryarray = oxi,
                              autorange = "reversed", tickfont = attr(size = 9), fixedrange = true,
                              showline = true, mirror = true, linecolor = "#333333", linewidth = 1,
                              ticks = "outside", tickcolor = "#333333", ticklen = 3),
    )
    return plot(traces, spider_layout)
end
