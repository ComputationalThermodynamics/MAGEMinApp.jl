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

const PD3D_SPEC_PREFIXES = ("f", "a", "b", "c")

function pd3d_option_row(label, control)
    dbc_row([
        dbc_col([
            html_h1(label, style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
        ], width=5),
        dbc_col([control]),
    ])
end

pd3d_title(txt) = html_h1(txt, style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8, "fontWeight" => "bold"))

pd3d_bool_dropdown(id, value) = dcc_dropdown(id = id, options = ["true","false"], value = value, clearable = false, multi = false)

pd3d_number(id, value; kw...) = dbc_input(; id = id, type = "number", value = value, debounce = false, kw...)

pd3d_export_button(label, id) = dbc_button(label, id = id, color = "light", n_clicks = 0,
                                           style = Dict("textAlign" => "center", "font-size" => "100%", "border" => "1px grey solid", "width" => "100%"))

pd3d_hidden_div(children, id) = html_div(children, id = id, style = Dict("display" => "none"))

function pd3d_spec_selector(prefix; type = "ss", phase = "liq", ssfield = "mode", offield = "frac_M_vol", unit = "vol")
    dd(id, options, value) = dcc_dropdown(id = id, options = options, value = value, clearable = false)
    calc(id, value)        = dbc_input(id = id, type = "text", value = value, debounce = true)
    html_div([
        pd3d_option_row("Type", dd("pd3d-$prefix-type", PD3D_ISO_TYPES, type)),
        pd3d_hidden_div([pd3d_option_row("Phase",    dd("pd3d-$prefix-phase",   [], phase))],                       "pd3d-$prefix-phase-div"),
        pd3d_hidden_div([pd3d_option_row("Field",    dd("pd3d-$prefix-ssfield", PD3D_SS_FIELDS, ssfield))],        "pd3d-$prefix-ssfield-div"),
        pd3d_hidden_div([pd3d_option_row("Field",    dd("pd3d-$prefix-offield", pd3d_field_options(), offield))],  "pd3d-$prefix-offield-div"),
        pd3d_hidden_div([pd3d_option_row("Unit",     dd("pd3d-$prefix-unit",    PD3D_UNITS_MODE, unit))],          "pd3d-$prefix-unit-div"),
        pd3d_hidden_div([pd3d_option_row("Remove excess fluid",
                                                     dd("pd3d-$prefix-rmf",     [(label = "true", value = true), (label = "false", value = false)], false))],
                                                                                                                    "pd3d-$prefix-rmf-div"),
        pd3d_hidden_div([pd3d_option_row("Oxide",     dd("pd3d-$prefix-ox",     [], nothing))],                     "pd3d-$prefix-ox-div"),
        pd3d_hidden_div([pd3d_option_row("Endmember", dd("pd3d-$prefix-em",     [], nothing))],                     "pd3d-$prefix-em-div"),
        pd3d_hidden_div([pd3d_option_row("Calculator (apfu)",    calc("pd3d-$prefix-calc",   "Mg / (Mg + Fe)"))],    "pd3d-$prefix-calc-div"),
        pd3d_hidden_div([pd3d_option_row("Calculator (oxides)",  calc("pd3d-$prefix-calcox", "MgO / (MgO + FeO)"))], "pd3d-$prefix-calcox-div"),
        pd3d_hidden_div([pd3d_option_row("Calculator (site fractions)", calc("pd3d-$prefix-calcsf", ""))],
                                                                                                                    "pd3d-$prefix-calcsf-div"),
        pd3d_hidden_div([html_div(id = "pd3d-$prefix-sites", style = Dict("font-size" => "85%", "color" => "grey", "textAlign" => "center"))],
                                                                                                                    "pd3d-$prefix-sites-div"),
        dcc_store(id = "pd3d-$prefix-spec", data = collect(pd3d_spec_from_selector(type, phase, ssfield, offield, unit, false, nothing, nothing, "", "", ""))),
    ])
end

function Tab_PhaseDiagram3D()
    html_div([
        dbc_col([
            html_div("‎ "),
            dbc_row([
                dbc_col([
                    dbc_row([
                        dbc_col([], width=3),
                        dbc_col([
                            dcc_textarea(
                                id          = "pd3d-system-chemistry-id",
                                value       = "",
                                readOnly    = true,
                                disabled    = true,
                                draggable   = false,
                                style       = Dict("height" => "26px","resize"=> "none","textAlign" => "center","font-size" => "100%", "width"=> "100%",),
                            ),
                        ], width=6),
                        dbc_col([
                            dcc_clipboard(
                                target_id   = "pd3d-system-chemistry-id",
                                title       = "copy",
                                style       = Dict(
                                    "display"       => "inline-block",
                                    "fontSize"      => 20,
                                    "verticalAlign" => "top",
                                ),
                            ),
                        ], width=1),
                    ]),
                    dbc_alert("", id = "pd3d-error-id", color = "danger", is_open = false, dismissable = true),
                    dcc_loading(
                        type        = "circle",
                        children    = [
                            dcc_graph(  id      = "pd3d-graph",
                                        figure  = pd3d_empty_figure(),
                                        config  = Dict( "displaylogo"           => false,
                                                        "toImageButtonOptions"  => Dict("format" => "png", "filename" => "MAGEMin_3D_diagram", "scale" => 2))),
                        ],
                    ),
                ], width=9),

                dbc_col([
                    dbc_card(dbc_cardbody([
                        pd3d_title("Layers"),
                        dbc_checklist(  id      = "pd3d-layers",
                                        options = [ Dict("label" => "Field isosurfaces / volume",      "value" => "field"),
                                                    Dict("label" => "Coloured surface (+ contours)",   "value" => "surface"),
                                                    Dict("label" => "Phase-in/out surfaces",           "value" => "phases"),
                                                    Dict("label" => "Grid points (assemblage)",        "value" => "cloud") ],
                                        value   = ["field"]),
                        html_hr(),
                        pd3d_title("View"),
                        pd3d_option_row("Reverse T axis", pd3d_bool_dropdown("pd3d-reverse-T", "false")),
                        pd3d_option_row("Reverse P axis", pd3d_bool_dropdown("pd3d-reverse-P", "true")),
                        pd3d_option_row("Camera",
                            dcc_dropdown(   id          = "pd3d-camera",
                                            options     = [ (label = "3D",               value = "iso"),
                                                            (label = "P-T (along X)",    value = "pt"),
                                                            (label = "P-X (along T)",    value = "px"),
                                                            (label = "T-X (along P)",    value = "tx") ],
                                            value       = "iso",
                                            clearable   = false)),
                        html_div("‎ "),
                        dbc_button("Reset view", id = "pd3d-reset-view", color = "light", n_clicks = 0,
                                    style = Dict("textAlign" => "center", "font-size" => "100%", "border" => "1px grey solid", "width" => "100%")),
                    ])),
                    html_div("‎ "),
                    dbc_tabs(id = "pd3d-sidebar-tabs", active_tab = "pd3d-tab-info", [

                        dbc_tab(label = "Informations", tab_id = "pd3d-tab-info", children = [
                            dbc_card(dbc_cardbody([
                                phase_pie_section(  unit_id = "pd3d-pie-unit", pie_id = "pd3d-pie", title_id = "pd3d-comp-title",
                                                    table_id = "pd3d-comp-table", div_id = "pd3d-comp-div")...,
                            ])),
                        ]),

                        dbc_tab(label = "Field", tab_id = "pd3d-tab-field", children = [
                            dbc_card(dbc_cardbody([
                                pd3d_spec_selector("f"; type = "of", offield = "frac_M_vol"),
                                pd3d_option_row("Rendering",
                                    dcc_dropdown(   id          = "pd3d-mode",
                                                    options     = [ (label = "Isosurfaces", value = "isosurface"),
                                                                    (label = "Volume",      value = "volume") ],
                                                    value       = "isosurface",
                                                    clearable   = false,
                                                    multi       = false)),
                                html_hr(),
                                pd3d_option_row("Min value",            pd3d_number("pd3d-isomin", nothing)),
                                pd3d_option_row("Max value",            pd3d_number("pd3d-isomax", nothing)),
                                pd3d_option_row("Number of surfaces",   pd3d_number("pd3d-nsurf", 5; min = 1, max = 50, step = 1)),
                                pd3d_option_row("Opacity",              pd3d_number("pd3d-opacity", 0.6; min = 0.05, max = 1.0, step = 0.05)),
                                pd3d_option_row("Show caps",            pd3d_bool_dropdown("pd3d-caps", "false")),
                                html_hr(),
                                pd3d_option_row("Colormap",
                                    dcc_dropdown(   id          = "pd3d-colormap",
                                                    options     = colormap_dropdown_options(),
                                                    value       = "viridis",
                                                    clearable   = false)),
                                pd3d_option_row("Reverse colormap", pd3d_bool_dropdown("pd3d-reverse-colormap", "false")),
                            ])),
                        ]),

                        dbc_tab(label = "Surface", tab_id = "pd3d-tab-surface", children = [
                            dbc_card(dbc_cardbody([
                                pd3d_title("Surface: A = value"),
                                pd3d_spec_selector("a"; type = "ss", phase = "liq", ssfield = "MgNum"),
                                pd3d_option_row("Value of A",   pd3d_number("pd3d-a-iso", 0.7)),
                                html_div(id = "pd3d-a-range", style = Dict("textAlign" => "center", "font-size" => "90%", "color" => "grey")),
                                html_hr(),
                                pd3d_title("Colour: B"),
                                pd3d_spec_selector("b"; type = "ss", phase = "liq", ssfield = "mode", unit = "vol"),
                                pd3d_option_row("Colormap",
                                    dcc_dropdown(   id          = "pd3d-surf-colormap",
                                                    options     = colormap_dropdown_options(),
                                                    value       = "viridis",
                                                    clearable   = false)),
                                pd3d_option_row("Reverse colormap", pd3d_bool_dropdown("pd3d-surf-reverse", "false")),
                                pd3d_option_row("Opacity",          pd3d_number("pd3d-surf-opacity", 0.8; min = 0.05, max = 1.0, step = 0.05)),
                                html_hr(),
                                pd3d_title("Contour lines: C"),
                                pd3d_option_row("Show contours",    pd3d_bool_dropdown("pd3d-contours", "true")),
                                pd3d_spec_selector("c"; type = "ss", phase = "g", ssfield = "mode", unit = "vol"),
                                pd3d_option_row("Number of levels", pd3d_number("pd3d-c-nlev", 8; min = 1, max = 40, step = 1)),
                                pd3d_option_row("Line width",       pd3d_number("pd3d-c-lw", 3; min = 1, max = 12, step = 1)),
                                pd3d_option_row("Label size",       pd3d_number("pd3d-c-lsize", 10; min = 6, max = 24, step = 1)),
                            ])),
                        ]),

                        dbc_tab(label = "Export", tab_id = "pd3d-tab-export", children = [
                            dbc_card(dbc_cardbody([
                                pd3d_option_row("File name", dbc_input(id = "pd3d-export-name", type = "text", value = "MAGEMin_3D")),
                                html_div("‎ "),
                                pd3d_export_button("Interactive HTML (shareable, one file)", "pd3d-export-html"),
                                html_div("‎ "),
                                pd3d_export_button("Surfaces: PLY (colour) + STL", "pd3d-export-mesh"),
                                html_div("‎ "),
                                pd3d_export_button("Full grid for ParaView (VTK)", "pd3d-export-vtk"),
                                html_div(id = "pd3d-export-status", children = "",
                                         style = Dict("textAlign" => "center", "font-size" => "85%", "color" => "grey", "marginTop" => 8, "wordBreak" => "break-all")),
                                html_hr(),
                                html_div("Directory: $(output_dir[1])",
                                         style = Dict("textAlign" => "center", "font-size" => "85%", "color" => "grey", "wordBreak" => "break-all")),
                            ])),
                        ]),

                        dbc_tab(label = "Phases & grid", tab_id = "pd3d-tab-phases", children = [
                            dbc_card(dbc_cardbody([
                                pd3d_title("Phase-in/out surfaces"),
                                dcc_dropdown(id = "pd3d-phases-sel", options = [], value = [], multi = true, placeholder = "Select phases"),
                                pd3d_option_row("Threshold [vol frac.]", pd3d_number("pd3d-phase-eps", 0.001; min = 0.0, max = 1.0, step = 0.001)),
                                pd3d_option_row("Opacity",               pd3d_number("pd3d-phase-opacity", 0.35; min = 0.05, max = 1.0, step = 0.05)),
                                html_hr(),
                                pd3d_title("Grid points"),
                                pd3d_option_row("Show every n-th node", pd3d_number("pd3d-cloud-stride", 1; min = 1, max = 10, step = 1)),
                                pd3d_option_row("Marker size",          pd3d_number("pd3d-cloud-size", 3; min = 1, max = 12, step = 1)),
                            ])),
                        ]),
                    ]),
                ], width=3),
            ], justify="left"),

            dcc_store(id = "pd3d-computed"),
            dcc_store(id = "pd3d-node"),
            dcc_store(id = "pd3d-goto-tab"),
            dcc_store(id = "pd3d-progress-off"),
        ], width=12),
    ])
end
