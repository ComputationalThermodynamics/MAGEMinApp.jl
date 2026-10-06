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

            Input("pd3d-computed",              "data"),
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
        ) do _computed, type, phase, ssfield, offield, unit, rmf, ox, em, calc, calcox, calcsf, _naming
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
                    collect(spec)
        end
    end


    callback!(
        app,
        Output("pd3d-a-iso",                "value"),
        Output("pd3d-a-range",              "children"),

        Input("pd3d-computed",              "data"),
        Input("pd3d-a-spec",                "data"),
        State("pd3d-a-iso",                 "value"),

        prevent_initial_call = true,
    ) do _computed, spec_a, iso
        st = PD3D[]
        isnothing(st) && return no_update(), ""
        lo, hi = pd3d_range(pd3d_field(st, pd3d_spec(spec_a)...))
        keep   = pushed_button( callback_context() ) == "pd3d-computed" && iso isa Number && lo < iso < hi
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

        Input("pd3d-graph",                 "clickData"),
        Input("pd3d-pie-unit",              "value"),

        prevent_initial_call = true,
    ) do click, pie_unit
        st = PD3D[]
        (isnothing(st) || isnothing(click)) && return no_update(), no_update(), no_update(), no_update()
        pt      = click[:points][1]
        l, xval = pd3d_nearest(st, to_kbar_pressure(Float64(pt[:x])), Float64(pt[:y]), Float64(pt[:z]))
        tab     = pushed_button( callback_context() ) == "pd3d-graph" ? "pd3d-tab-info" : no_update()
        return phase_pie_figure(st.Out[l], st.dtb, pie_unit, xval), Dict("id" => st.id, "l" => l), tab, system_chemistry_text(st.Out[l])
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
        ph = click_pie[:points][1][:customdata]
        return Dict("display" => "block"), phase_composition_rows(st.Out[node[:l]], ph), "$(display_ph_name(ph)) composition"
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

    return app
end
