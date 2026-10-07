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

pd3d_str(v) = v isa AbstractString ? String(v) : ""

pd3d_spec(data) = (isnothing(data) || length(data) != 3) ? ("sys", "", "frac_M_vol") : (String(data[1]), String(data[2]), String(data[3]))

function Tab_PhaseDiagram3D_Callbacks(app)

    callback!(
        app,
        Output("tabs",              "active_tab"),
        Input("pd2d-goto-tab",      "data"),
        Input("pd3d-goto-tab",      "data"),

        prevent_initial_call = true,
    ) do tab2d, tab3d
        tab = pushed_button( callback_context() ) == "pd3d-goto-tab" ? tab3d : tab2d
        return (tab isa AbstractString && !isempty(tab)) ? tab : no_update()
    end


    callback!(
        app,
        Output("tab-3d-diagram-tab",    "tab_style"),
        Input("diagram-dropdown",       "value"),
        Input("tabs",                   "active_tab"),

        prevent_initial_call = false,
    ) do diagType, active_tab
        return (diagType == "ptx3d" || active_tab == "tab-3d-diagram") ? Dict{String,String}() : Dict("display" => "none")
    end


    callback!(
        app,
        Output("pd3d-x0-label",             "style"),
        Output("pd3d-x1-label",             "style"),
        Output("pd3d-bulk-x-alert",         "is_open"),
        Output("pd3d-bulk-x-alert",         "color"),
        Output("pd3d-bulk-x-alert",         "children"),
        Input("diagram-dropdown",           "value"),
        Input("table-bulk-rock",            "data"),
        Input("table-2-bulk-rock",          "data"),
        Input("select-bulk-unit",           "value"),

        prevent_initial_call = false,
    ) do diagType, bulk1, bulk2, sys_unit
        label(show) = Dict("display" => show ? "block" : "none", "textAlign" => "center", "fontWeight" => "bold", "font-size" => "110%", "marginBottom" => 4)
        diagType == "ptx3d" || return label(false), label(false), false, "info", ""
        rel = try
            bulk_L, bulk_R, oxi = get_bulkrock_prop(bulk1, bulk2; sys_unit = sys_unit)
            pd3d_x_axis(oxi, bulk_L, bulk_R)
        catch
            nothing
        end
        isnothing(rel) && return label(true), label(true), false, "info", ""
        if rel.relation == :identical
            return label(true), label(true), true, "warning",
                   "Both bulk-rock compositions are identical: nothing varies along the X axis of the 3D diagram. Edit the X = 1 composition (e.g. its H₂O content)."
        end
        return label(true), label(true), true, "info", "X axis of the 3D diagram: " * rel.info * "."
    end


    callback!(
        app,
        Output("pd3d-estimate-id",  "value"),
        Input("pd3d-nP-id",         "value"),
        Input("pd3d-nT-id",         "value"),
        Input("pd3d-nX-id",         "value"),

        prevent_initial_call = false,
    ) do nP, nT, nX
        return pd3d_estimate(nP, nT, nX)
    end


    callback!(
        app,
        Output("pd3d-computed",             "data"),
        Output("pd3d-goto-tab",             "data"),
        Output("pd3d-progress-off",         "data"),
        Output("pd3d-error-id",             "children"),
        Output("pd3d-error-id",             "is_open"),
        Output("output-loading-id-3d",      "children"),

        Input("compute-3d-button",          "value"),

        State("database-dropdown",          "value"),
        State("dataset-dropdown",           "value"),
        State("exp-dropdown",               "value"),
        State("mb-cpx-switch",              "value"),
        State("limit-ca-opx-id",            "value"),
        State("ca-opx-val-id",              "value"),
        State("phase-selection",            "value"),
        State("pure-phase-selection",       "value"),
        State("tmin-id",                    "value"),
        State("tmax-id",                    "value"),
        State("pmin-id",                    "value"),
        State("pmax-id",                    "value"),
        State("pd3d-nP-id",                 "value"),
        State("pd3d-nT-id",                 "value"),
        State("pd3d-nX-id",                 "value"),
        State("buffer-dropdown",            "value"),
        State("buffer-1-mul-id",            "value"),
        State("buffer-2-mul-id",            "value"),
        State("solver-dropdown",            "value"),
        State("scp-dropdown",               "value"),
        State("sas-dropdown",               "value"),
        State("wf-id",                      "value"),
        State("seismic-cor-dropdown",       "value"),
        State("aspect-ratio-id",            "value"),
        State("seismic-water-dropdown",     "value"),
        State("shallow-cor-dropdown",       "value"),
        State("fluid-as-melt-dropdown",     "value"),
        State("anelastic-cor-dropdown",     "value"),
        State("table-bulk-rock",            "data"),
        State("table-2-bulk-rock",          "data"),
        State("select-bulk-unit",           "value"),

        prevent_initial_call = true,
    ) do    _compute,
            dtb,        dataset,    custW,      cpx,        limOpx,     limOpxVal,  ph_selection, pure_ph_selection,
            tmin,       tmax,       pmin,       pmax,       nP,         nT,         nX,
            bufferType, bufferN1,   bufferN2,   solver,     scp,
            sas,        wf,         seismicCorMode, aspectRatioVal, seismicWaterMode, shallowCorMode, fluidAsMeltMode, anelasticCorMode,
            bulk1,      bulk2,      sys_unit

        progress = string(rand())
        try
            bulk_L, bulk_R, oxi = get_bulkrock_prop(bulk1, bulk2; sys_unit = sys_unit)
            phase_selection     = remove_phases(string_vec_diff(to_str_vec(ph_selection), to_str_vec(pure_ph_selection), dtb), dtb)
            PD3D[] = compute_phaseDiagram3D(    (to_kbar_pressure(Float64(pmin)), to_kbar_pressure(Float64(pmax))), (Float64(tmin), Float64(tmax)),
                                                Int(nP),    Int(nT),    Int(nX),
                                                dtb,        dataset,    Bool(custW),    scp,    solver,     phase_selection,
                                                cpx,        limOpx,     Float64(limOpxVal),
                                                bulk_L,     bulk_R,     oxi,
                                                bufferType, Float64(bufferN1), Float64(bufferN2),
                                                sas == 0 ? "VRH" : "HS", Float64(wf),
                                                Bool(seismicCorMode), Float64(aspectRatioVal), Int64(seismicWaterMode),
                                                Bool(shallowCorMode), Bool(fluidAsMeltMode), Bool(anelasticCorMode) )
        catch e
            msg = sprint(showerror, e)
            println("3D phase diagram computation failed: ", msg)
            return no_update(), no_update(), progress, "3D computation failed: $msg", true, ""
        end
        return PD3D[].id, "tab-3d-diagram", progress, "", false, ""
    end


    for prefix in PD3D_SPEC_PREFIXES
        callback!(
            app,
            Output("pd3d-$prefix-phase",        "options"),
            Output("pd3d-$prefix-phase",        "value"),
            Output("pd3d-$prefix-unit",         "options"),
            Output("pd3d-$prefix-unit",         "value"),
            Output("pd3d-$prefix-ox",           "options"),
            Output("pd3d-$prefix-ox",           "value"),
            Output("pd3d-$prefix-em",           "options"),
            Output("pd3d-$prefix-em",           "value"),
            Output("pd3d-$prefix-sites",        "children"),
            Output("pd3d-$prefix-phase-div",    "style"),
            Output("pd3d-$prefix-ssfield-div",  "style"),
            Output("pd3d-$prefix-offield-div",  "style"),
            Output("pd3d-$prefix-unit-div",     "style"),
            Output("pd3d-$prefix-rmf-div",      "style"),
            Output("pd3d-$prefix-ox-div",       "style"),
            Output("pd3d-$prefix-em-div",       "style"),
            Output("pd3d-$prefix-calc-div",     "style"),
            Output("pd3d-$prefix-calcox-div",   "style"),
            Output("pd3d-$prefix-calcsf-div",   "style"),
            Output("pd3d-$prefix-sites-div",    "style"),
            Output("pd3d-$prefix-spec",         "data"),
            Output("pd3d-$prefix-type",         "value"),
            Output("pd3d-$prefix-ssfield",      "value"),
            Output("pd3d-$prefix-offield",      "value"),

            Input("pd3d-computed",              "data"),
            Input("pd3d-surf-preset",           "value"),
            Input("pd3d-$prefix-type",          "value"),
            Input("pd3d-$prefix-phase",         "value"),
            Input("pd3d-$prefix-ssfield",       "value"),
            Input("pd3d-$prefix-offield",       "value"),
            Input("pd3d-$prefix-unit",          "value"),
            Input("pd3d-$prefix-rmf",           "value"),
            Input("pd3d-$prefix-ox",            "value"),
            Input("pd3d-$prefix-em",            "value"),
            Input("pd3d-$prefix-calc",          "value"),
            Input("pd3d-$prefix-calcox",        "value"),
            Input("pd3d-$prefix-calcsf",        "value"),
            Input("mineral-naming-dropdown",    "value"),

            prevent_initial_call = false,
        ) do _computed, preset, type, phase, ssfield, offield, unit, rmf, ox, em, calc, calcox, calcsf, _naming
            pr = prefix in ("a", "b", "c") && any(t -> startswith(String(t.prop_id), "pd3d-surf-preset."), callback_context().triggered) ? pd3d_surf_preset(preset) : nothing
            if !isnothing(pr)
                q       = getfield(pr, Symbol(prefix))
                type    = q.type
                phase   = get(q, :phase, phase)
                ssfield = get(q, :ssfield, ssfield)
                offield = get(q, :offield, offield)
                unit    = get(q, :unit, unit)
                em      = get(q, :em, em)
            end
            vis(b)     = Dict("display" => b ? "block" : "none")
            is_ss      = type == "ss"
            mode_like  = type == "pp" || (is_ss && ssfield == "mode")
            unit_comp  = is_ss && ssfield in ("oxComp", "emMode", "calc_ox")
            unit_opts  = unit_comp ? PD3D_UNITS_COMP : PD3D_UNITS_MODE
            unit       = (unit_comp && unit == "vol") ? "mol" : unit

            st         = PD3D[]
            phases     = isnothing(st) || type == "of" ? String[] : pd3d_phases(st; solution_only = is_ss, pure_only = type == "pp")
            phase_opts = [(label = display_ph_name(ph), value = ph) for ph in phases]
            if !isempty(phases) && !(phase in phases)
                phase = "liq" in phases ? "liq" : phases[1]
            end

            oxides  = isnothing(st) ? String[] : String.(st.Out[1].oxides)
            ox      = ox in oxides ? ox : (isempty(oxides) ? nothing : oxides[1])
            ems     = isnothing(st) ? String[] : pd3d_em_names(st, phase)
            em      = em in ems ? em : (isempty(ems) ? nothing : ems[1])
            sites   = isnothing(st) ? String[] : pd3d_site_names(st, phase)

            spec    = pd3d_spec_from_selector(type, phase, ssfield, offield, unit, rmf, ox, em, calc, calcox, calcsf)

            return  phase_opts, phase, unit_opts, unit,
                    [(label = o, value = o) for o in oxides], ox,
                    [(label = e, value = e) for e in ems], em,
                    isempty(sites) ? "" : "Sites: " * join(sites, ", "),
                    vis(type != "of"), vis(is_ss), vis(type == "of"),
                    vis(mode_like || unit_comp), vis(mode_like),
                    vis(is_ss && ssfield == "oxComp"), vis(is_ss && ssfield == "emMode"),
                    vis(is_ss && ssfield == "calc"), vis(is_ss && ssfield == "calc_ox"), vis(is_ss && ssfield == "calc_sf"),
                    vis(is_ss && ssfield == "calc_sf"),
                    collect(spec),
                    type, ssfield, offield
        end
    end


    callback!(
        app,
        Output("pd3d-a-iso",                "value"),
        Output("pd3d-a-range",              "children"),

        Input("pd3d-computed",              "data"),
        Input("pd3d-a-spec",                "data"),
        Input("pd3d-surf-preset",           "value"),
        State("pd3d-a-iso",                 "value"),

        prevent_initial_call = true,
    ) do _computed, spec_a, preset, iso
        st = PD3D[]
        isnothing(st) && return no_update(), ""
        lo, hi = pd3d_range(pd3d_field(st, pd3d_spec(spec_a)...))
        trig   = [String(t.prop_id) for t in callback_context().triggered]
        pr     = any(t -> startswith(t, "pd3d-surf-preset."), trig) ? pd3d_surf_preset(preset) : nothing
        if !isnothing(pr)
            iso = pr.iso
            keep = lo <= iso <= hi
        else
            keep = any(t -> startswith(t, "pd3d-computed."), trig) && iso isa Number && lo < iso < hi
        end
        iso    = keep ? iso : round((lo + hi) / 2, sigdigits = 3)
        return iso, "range: $(round(lo, sigdigits = 4)) – $(round(hi, sigdigits = 4))"
    end


    callback!(
        app,
        Output("pd3d-isomin",               "value"),
        Output("pd3d-isomax",               "value"),
        Output("pd3d-nsurf",                "value"),

        Input("pd3d-computed",              "data"),
        Input("pd3d-f-spec",                "data"),

        prevent_initial_call = true,
    ) do _computed, spec_f
        st = PD3D[]
        isnothing(st) && return no_update(), no_update(), no_update()
        spec = pd3d_spec(spec_f)
        return pd3d_default_iso(pd3d_integer_spec(spec[1], spec[3]) ? spec[3] : "", pd3d_range(pd3d_field(st, spec...))...)
    end


    callback!(
        app,
        Output("pd3d-phases-sel",           "options"),
        Input("pd3d-computed",              "data"),
        Input("mineral-naming-dropdown",    "value"),

        prevent_initial_call = true,
    ) do _computed, _naming
        st = PD3D[]
        isnothing(st) && return no_update()
        return [(label = display_ph_name(ph), value = ph) for ph in pd3d_phases(st)]
    end


    callback!(
        app,
        Output("pd3d-graph",                "figure"),

        Input("pd3d-computed",              "data"),
        Input("pd3d-layers",                "value"),
        Input("pd3d-f-spec",                "data"),
        Input("pd3d-mode",                  "value"),
        Input("pd3d-isomin",                "value"),
        Input("pd3d-isomax",                "value"),
        Input("pd3d-nsurf",                 "value"),
        Input("pd3d-opacity",               "value"),
        Input("pd3d-caps",                  "value"),
        Input("pd3d-colormap",              "value"),
        Input("pd3d-reverse-colormap",      "value"),
        Input("pd3d-a-spec",                "data"),
        Input("pd3d-a-iso",                 "value"),
        Input("pd3d-b-spec",                "data"),
        Input("pd3d-surf-colormap",         "value"),
        Input("pd3d-surf-reverse",          "value"),
        Input("pd3d-surf-opacity",          "value"),
        Input("pd3d-contours",              "value"),
        Input("pd3d-c-spec",                "data"),
        Input("pd3d-c-nlev",                "value"),
        Input("pd3d-c-lw",                  "value"),
        Input("pd3d-c-lsize",               "value"),
        Input("pd3d-phases-sel",            "value"),
        Input("pd3d-phase-eps",             "value"),
        Input("pd3d-phase-opacity",         "value"),
        Input("pd3d-cloud-stride",          "value"),
        Input("pd3d-cloud-size",            "value"),
        Input("pd3d-reverse-T",             "value"),
        Input("pd3d-reverse-P",             "value"),
        Input("pd3d-camera",                "value"),
        Input("pd3d-reset-view",            "n_clicks"),
        Input("pressure-unit-dropdown",     "value"),
        Input("mineral-naming-dropdown",    "value"),

        prevent_initial_call = true,
    ) do    _computed,  layers,
            spec_f,
            mode,       isomin,     isomax,     nsurf,      opacity,    caps,       colorMap,   reverse,
            spec_a,     a_iso,
            spec_b,     surf_cmap,  surf_rev,   surf_opacity,
            contours,   spec_c,     nlev,       lw,         lsize,
            phases,     eps,        phase_opacity,
            stride,     msize,
            reverseT,   reverseP,   camera,     reset_view, pressure_unit, warr_naming

        st = PD3D[]
        isnothing(st) && return no_update()

        global use_GPa, use_warr_names
        use_GPa[1]        = (pressure_unit == "gpa")
        use_warr_names[1] = (warr_naming == "warr")

        o = (   layers          = something(layers, String[]),
                f               = pd3d_spec(spec_f),
                mode            = mode,
                isomin          = isomin,
                isomax          = isomax,
                nsurf           = nsurf,
                opacity         = opacity,
                caps            = caps == "true",
                colormap        = colorMap,
                reverse         = reverse,
                a               = pd3d_spec(spec_a),
                iso             = something(a_iso, 0.0),
                b               = pd3d_spec(spec_b),
                c               = pd3d_spec(spec_c),
                show_contours   = contours == "true",
                nlev            = nlev,
                lw              = lw,
                lsize           = lsize,
                phases          = phases,
                eps             = Float64(something(eps, 0.001)),
                phase_opacity   = Float64(something(phase_opacity, 0.35)),
                stride          = stride,
                msize           = msize,
                reverseT        = reverseT == "true",
                reverseP        = reverseP == "true",
                camera          = camera,
                uirev           = "$(st.id)-$(camera)-$(reset_view)",
                surf_colormap   = surf_cmap,
                surf_reverse    = surf_rev,
                surf_opacity    = surf_opacity )

        return pd3d_figure(st, o)
    end


    callback!(
        app,
        Output("pd3d-pie",                  "figure"),
        Output("pd3d-node",                 "data"),
        Output("pd3d-sidebar-tabs",         "active_tab"),
        Output("pd3d-system-chemistry-id",  "value"),
        Output("pd3d-point-status",         "children"),
        Output("pd3d-layers-prev",          "data"),

        Input("pd3d-click",                 "data"),
        Input("pd3d-pie-unit",              "value"),
        Input("pd3d-click-mode",            "value"),
        Input("pd3d-layers",                "value"),
        State("pd3d-node",                  "data"),
        State("pd3d-layers-prev",           "data"),

        prevent_initial_call = true,
    ) do click, pie_unit, mode, layers, node, layers_prev
        bid  = pushed_button( callback_context() )
        none = ntuple(_ -> no_update(), 6)

        if bid == "pd3d-layers"
            added = setdiff(something(layers, String[]), something(layers_prev, String[]))
            tabs  = Dict("field" => "pd3d-tab-field", "surface" => "pd3d-tab-surface", "phases" => "pd3d-tab-phases", "cloud" => "pd3d-tab-phases")
            tab   = isempty(added) ? no_update() : get(tabs, first(added), no_update())
            return no_update(), no_update(), tab, no_update(), no_update(), layers
        end

        st = PD3D[]
        isnothing(st) && return none

        if bid == "pd3d-pie-unit"
            (isnothing(node) || node[:id] != st.id) && return none
            out = node[:exact] ? PD3D_POINT[] : st.Out[node[:l]]
            return phase_pie_figure(out, st.dtb, pie_unit, node[:xval]), no_update(), no_update(), no_update(), no_update(), no_update()
        end

        isnothing(click) && return none
        pt   = click[:points][1]
        p_kb = to_kbar_pressure(Float64(pt[:x]))
        t, x = Float64(pt[:y]), Float64(pt[:z])
        if mode == "exact"
            local out
            dt = @elapsed out = try pd3d_compute_point(st, p_kb, t, x) catch e; e end
            if out isa Exception
                return no_update(), no_update(), no_update(), no_update(), "Exact point failed: $(sprint(showerror, out))", no_update()
            end
            PD3D_POINT[] = out
            xval   = clamp(x, 0.0, 1.0)
            newn   = Dict("id" => st.id, "l" => 0, "exact" => true, "xval" => xval,
                          "x" => display_pressure(p_kb), "y" => t, "z" => xval)
            status = "Exact point computed in $(round(dt, digits = 2)) s (red marker)."
        else
            l, xval = pd3d_nearest(st, p_kb, t, x)
            out     = st.Out[l]
            newn    = Dict("id" => st.id, "l" => l, "exact" => false, "xval" => xval,
                           "x" => display_pressure(out.P_kbar), "y" => out.T_C, "z" => xval)
            status  = "Nearest grid node to the clicked point (red marker)."
        end
        return phase_pie_figure(out, st.dtb, pie_unit, newn["xval"]), newn, "pd3d-tab-info", system_chemistry_text(out), status, no_update()
    end


    callback!(
        app,
        Output("pd3d-comp-div",             "style"),
        Output("pd3d-comp-table",           "data"),
        Output("pd3d-comp-title",           "children"),

        Input("pd3d-pie",                   "clickData"),
        Input("pd3d-node",                  "data"),

        prevent_initial_call = true,
    ) do click_pie, node
        st = PD3D[]
        hidden = (Dict("display" => "none"), [], "")
        if pushed_button( callback_context() ) != "pd3d-pie" || isnothing(st) || isnothing(node) || node[:id] != st.id
            return hidden
        end
        ph  = click_pie[:points][1][:customdata]
        out = node[:exact] ? PD3D_POINT[] : st.Out[node[:l]]
        return Dict("display" => "block"), phase_composition_rows(out, ph), "$(display_ph_name(ph)) composition"
    end

    callback!(
        app,
        Output("pd3d-export-status",        "children"),
        Input("pd3d-export-html",           "n_clicks"),
        Input("pd3d-export-mesh",           "n_clicks"),
        Input("pd3d-export-vtk",            "n_clicks"),
        State("pd3d-export-name",           "value"),

        prevent_initial_call = true,
    ) do _html, _mesh, _vtk, name
        st, o = PD3D[], PD3D_LAST_OPTS[]
        (isnothing(st) || isnothing(o)) && return "Compute and display a 3D diagram first."
        name = pd3d_safe_name(something(name, ""))
        name = isempty(name) ? "MAGEMin_3D" : name
        mkpath(output_dir[1])
        bid  = pushed_button( callback_context() )
        try
            if bid == "pd3d-export-html"
                path = joinpath(output_dir[1], name * ".html")
                sz   = pd3d_export_html(st, o, path)
                return "Saved $(path) ($(round(sz / 1e6, digits = 1)) MB)"
            elseif bid == "pd3d-export-mesh"
                dir = joinpath(output_dir[1], name * "_meshes")
                n   = pd3d_export_meshes(st, o, dir)
                return n == 0 ? "No surface to export: enable a layer with surfaces (field, coloured surface or phase-in/out)." :
                                "Saved $n surface(s) as PLY + STL in $(dir)"
            elseif bid == "pd3d-export-vtk"
                path = joinpath(output_dir[1], name * ".vtk")
                n    = pd3d_export_vtk(st, o, path)
                return "Saved $(path) ($n fields, $(round(filesize(path) / 1e6, digits = 1)) MB)"
            end
        catch e
            msg = sprint(showerror, e)
            println("3D export failed: ", msg)
            return "Export failed: $msg"
        end
        return no_update()
    end

    callback!(
        """
        function(click) {
            var host = document.getElementById('pd3d-graph');
            if (host && !host.__pd3dWatch) {
                host.__pd3dWatch   = true;
                host.__pd3dWaiters = [];
                host.addEventListener('mousedown', function(e) {
                    host.__pd3dDown    = [e.clientX, e.clientY];
                    host.__pd3dPressed = true;
                }, true);
                window.addEventListener('mouseup', function(e) {
                    if (!host.__pd3dPressed) { return; }
                    host.__pd3dPressed = false;
                    var moved   = host.__pd3dDown ? Math.hypot(e.clientX - host.__pd3dDown[0], e.clientY - host.__pd3dDown[1]) : 0;
                    var waiters = host.__pd3dWaiters;
                    host.__pd3dWaiters = [];
                    waiters.forEach(function(w) { w(moved <= 5); });
                }, true);
            }
            if (!click) { return window.dash_clientside.no_update; }
            if (!host || !host.__pd3dPressed) { return click; }
            return new Promise(function(resolve) {
                host.__pd3dWaiters.push(function(isClick) { resolve(isClick ? click : window.dash_clientside.no_update); });
            });
        }
        """,
        app,
        Output("pd3d-click",                "data"),
        Input("pd3d-graph",                 "clickData"),
        prevent_initial_call = false,
    )


    callback!(
        """
        function(node, fig) {
            setTimeout(function() {
                var gd = document.querySelector('#pd3d-graph .js-plotly-plot');
                if (!gd || !gd.data) { return; }
                var scene = gd._fullLayout && gd._fullLayout.scene && gd._fullLayout.scene._scene;
                var cam   = scene ? scene.getCamera() : null;
                var keepCamera = function() {
                    if (!cam) { return; }
                    var sc = gd._fullLayout.scene._scene;
                    sc.camera.lookAt([cam.eye.x, cam.eye.y, cam.eye.z], [cam.center.x, cam.center.y, cam.center.z], [cam.up.x, cam.up.y, cam.up.z]);
                    if (gd.layout.scene) { gd.layout.scene.camera = {eye: cam.eye, center: cam.center, up: cam.up, projection: (gd.layout.scene.camera || {}).projection}; }
                };
                var old = [];
                gd.data.forEach(function(d, i) { if (d.name === 'clicked point') { old.push(i); } });
                var p = old.length ? Plotly.deleteTraces(gd, old) : Promise.resolve();
                p.then(function() {
                    if (node && node.x !== undefined && node.x !== null) {
                        return Plotly.addTraces(gd, {type: 'scatter3d', mode: 'markers', name: 'clicked point',
                                                     x: [node.x], y: [node.y], z: [node.z], showlegend: false, hoverinfo: 'skip',
                                                     marker: {size: 7, color: 'red', symbol: 'diamond', line: {color: 'black', width: 2}}});
                    }
                }).then(keepCamera);
            }, 400);
            return '';
        }
        """,
        app,
        Output("pd3d-marker-dummy",         "children"),
        Input("pd3d-node",                  "data"),
        Input("pd3d-graph",                 "figure"),
        prevent_initial_call = true,
    )

    return app
end
