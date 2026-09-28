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

function Tab_MonteCarlo()
    dbc_tab(tab_id="tab-uncertainty", label="Uncertainty", children=[
        dbc_row([
            dbc_collapse(
                dbc_card(dbc_cardbody([
                    html_div(id="mc-status", children="Compute a P-T phase diagram first.",
                        style = Dict("textAlign" => "center", "font-size" => "100%", "color" => "grey")),
                ])),
                id      = "collapse-mc-status",
                is_open = true,
            ),
        ]),
        dbc_row([
            dbc_collapse(
                dbc_card(dbc_cardbody([
                        html_h1("Bulk uncertainty", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                        html_hr(),
                        dbc_row([
                            dbc_col([
                                dcc_dropdown(   id      = "mc-sigma-mode",
                                                options = [
                                                    (label = "relative %",       value = "relative"),
                                                    (label = "absolute [mol%]",  value = "absolute"),
                                                ],
                                                value     = "relative",
                                                clearable = false,
                                                style     = Dict("border" => "none"),
                                            ),
                            ], width=5),
                            dbc_col([
                                dbc_button("Reset", id="mc-sigma-reset-button", color="light", n_clicks=0,
                                    style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                  "border"    => "1px grey solid", "width" => "100%")),
                            ], width=7),
                        ]),
                        # html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                dbc_input(  id      = "mc-sigma-all-value",
                                            type    = "number",
                                            min     = 0.0,
                                            value   = 5.0   ),
                            ], width=5),
                            dbc_col([
                                dbc_button("Apply to all oxides", id="mc-sigma-all-button", color="light", n_clicks=0,
                                    style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                  "border"    => "1px grey solid", "width" => "100%")),
                            ], width=7),
                        ]),
                        html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                dbc_button("Load WDS from bulk", id="mc-sigma-wds-button", color="light", n_clicks=0,
                                    style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                  "border"    => "1px grey solid", "width" => "100%")),
                                dbc_tooltip(
                                    "Fills σ from the _wds columns of the currently selected bulk-rock composition (see examples/bulk-rock.csv). Oxides without WDS data keep their current σ.",
                                    target="mc-sigma-wds-button"),
                            ]),
                        ]),
                        dbc_alert(
                            "",
                            id      = "mc-sigma-wds-warning",
                            color   = "warning",
                            is_open = false,
                            duration= 6000,
                        ),
                        html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                html_h1("Unit", style = Dict("textAlign" => "center","font-size" => "100%", "marginTop" => 0, "marginBottom" => 0)),
                            ], width=3),
                            dbc_col([
                                dcc_dropdown(   id      = "mc-bulk-unit",
                                options = [
                                    (label = "mol%",                value = 1),
                                    (label = "wt%",                 value = 2),
                                ],
                                value       = 1,
                                style       = Dict("border" => "none"),
                                clearable   = false,
                                multi       = false),
                            ], width=4),
                        ], align="center"),
                        dcc_store(id="mc-bulk-unit-prev", data=1),
                        html_div("‎ "),
                        dbc_row([
                            dash_datatable(
                                id          = "mc-sigma-table",
                                columns     = [
                                    Dict("id" => "oxide", "name" => "oxide"        ),
                                    Dict("id" => "value", "name" => "value [mol%]" ),
                                    Dict("id" => "sigma", "name" => "σ", "editable" => true),
                                ],
                                data        = [],
                                editable    = false,
                                style_cell  = (textAlign="center", fontSize="100%"),
                                style_header= (fontWeight="bold",),
                                page_size   = 16,
                            ),
                        ]),
                        # html_div(
                        #     "H2O default σ is high (25%) since it is usually estimated rather than measured. For a water-oversaturated bulk that value is only a placeholder large enough to guarantee a free fluid phase, not a real content — lower its σ towards 0 in that case, since perturbing it mostly changes fluid mode, not the solid assemblage.",
                        #     style = Dict("textAlign" => "left", "font-size" => "75%", "color" => "grey", "marginTop" => 6),
                        # ),

                    ])),
                id      = "collapse-mc-sigma",
                is_open = true,
            ),
        ]),
        dbc_row([
            dbc_collapse(
                dbc_card(dbc_cardbody([
                        html_h1("Run", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                        html_hr(),
                        dbc_row([
                            dbc_col([
                                html_h1("Realizations", style = Dict("textAlign" => "center","font-size" => "100%")),
                                dbc_input(  id      = "mc-n-realizations",
                                            type    = "number",
                                            min     = 1,
                                            max     = 1000,
                                            value   = 100   ),
                            ], width=6),
                            dbc_col([
                                html_h1("Seed", style = Dict("textAlign" => "center","font-size" => "100%")),
                                dbc_input(  id          = "mc-seed",
                                            type        = "number",
                                            placeholder = "random"   ),
                            ], width=6),
                        ]),
                        html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                dbc_button("Run Monte Carlo", id="mc-run-button-raw", color="light", n_clicks=0,
                                    style = Dict( "textAlign"        => "center",
                                                  "font-size"        => "100%",
                                                  "border"           => "1px grey solid",
                                                  "width"            => "100%",
                                                  "background-color" => "#d3f2ce")),
                            ]),
                        ]),
                        html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                dbc_button("Display results", id="mc-canvas-button", color="light", n_clicks=0,
                                    style = Dict( "textAlign" => "center", "font-size" => "100%",
                                                  "border"    => "1px grey solid", "width" => "100%")),
                            ]),
                        ]),
                        html_div("‎ "),
                        html_div(id="mc-run-status", children="",
                            style = Dict("textAlign" => "center", "font-size" => "90%", "color" => "grey")),
                        dbc_alert(
                            "Monte Carlo needs a P-T phase diagram computed first (with a fixed, non water-saturated bulk).",
                            id      = "mc-run-failed",
                            color   = "danger",
                            is_open = false,
                            duration= 6000,
                        ),
                    ])),
                id      = "collapse-mc-run",
                is_open = true,
            ),
        ]),
        dbc_offcanvas(
            [
                html_div([
                    html_div([
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    html_h1("Diagram options", style = Dict("textAlign" => "center","font-size" => "110%")),
                                    html_hr(),
                                    dbc_switch(label="Show phase labels", id="mc-show-labels-switch", value=false),
                                    dbc_switch(label="Display phase boundaries", id="mc-show-boundaries-switch", value=true),
                                    dbc_switch(label="Smooth lines", id="mc-smooth-lines-switch", value=false),
                                    html_div("‎ "),
                                    dbc_button("Export SVG", id="mc-export-svg-button", color="light", n_clicks=0,
                                        style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                      "border"    => "1px grey solid", "width" => "100%")),
                                    html_div(id="mc-export-svg-status", children="",
                                        style = Dict("textAlign" => "center", "font-size" => "75%", "color" => "grey",
                                                     "marginTop" => 6, "wordBreak" => "break-all")),
                                ])),
                            id      = "collapse-mc-diagram-options",
                            is_open = true,
                        ),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    html_h1("Filter", style = Dict("textAlign" => "center","font-size" => "110%")),
                                    html_hr(),
                                    html_h1("Max lines", style = Dict("textAlign" => "center","font-size" => "100%")),
                                    dbc_input(  id      = "mc-max-lines",
                                                type    = "number",
                                                min     = 1,
                                                step    = 1,
                                                value   = mc_default_max_lines   ),
                                    html_div("‎ "),
                                    dbc_button("Apply", id="mc-phase-apply-button", color="light", n_clicks=0,
                                        style = Dict( "textAlign"        => "center",
                                                      "font-size"        => "90%",
                                                      "border"           => "1px grey solid",
                                                      "width"            => "100%",
                                                      "background-color" => "#d3f2ce")),
                                    dbc_alert(
                                        "",
                                        id       = "mc-filter-warning",
                                        color    = "warning",
                                        is_open  = false,
                                        duration = 6000,
                                        style    = Dict("textAlign" => "center", "font-size" => "90%", "marginTop" => 8),
                                    ),
                                    html_div("‎ "),
                                    dbc_button("Phases shown", id="mc-phase-toggle-button", color="light", n_clicks=0,
                                        style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                      "border"    => "1px grey solid", "width" => "100%")),
                                    dbc_collapse(
                                        html_div([
                                            html_div("‎ "),
                                            dbc_button("Select all", id="mc-phase-all-button", color="light", n_clicks=0,
                                                style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                              "border"    => "1px grey solid", "width" => "100%")),
                                            html_div(style = Dict("height" => "6px")),
                                            dbc_button("Unselect all", id="mc-phase-none-button", color="light", n_clicks=0,
                                                style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                              "border"    => "1px grey solid", "width" => "100%")),
                                            html_div("‎ "),
                                            html_div(
                                                dcc_checklist(
                                                    id      = "mc-phase-selection",
                                                    options = [],
                                                    value   = [],
                                                ),
                                                style = Dict("maxHeight" => "260px", "overflowY" => "auto"),
                                            ),
                                        ]),
                                        id      = "collapse-mc-phase-selection",
                                        is_open = false,
                                    ),
                                ])),
                            id      = "collapse-mc-filter",
                            is_open = true,
                        ),
                    ]),
                    html_div([
                        mc_diagram_plot(),
                    ]),
                    html_div([
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    html_h1("Probability map", style = Dict("textAlign" => "center","font-size" => "110%")),
                                    html_hr(),
                                    html_h1("Target phases", style = Dict("textAlign" => "center","font-size" => "100%")),
                                    dbc_input(  id          = "mc-heatmap-target",
                                                type        = "text",
                                                placeholder = "e.g. g bi pl"   ),
                                    html_div("‎ "),
                                    html_h1("Match", style = Dict("textAlign" => "center","font-size" => "100%")),
                                    dcc_dropdown(   id      = "mc-heatmap-match-mode",
                                                    options = [
                                                        (label = "loose (contains)", value = "loose"),
                                                        (label = "strict (exact)",   value = "strict"),
                                                    ],
                                                    value     = "loose",
                                                    clearable = false,
                                                    style     = Dict("border" => "none"),
                                                ),
                                    html_div("‎ "),
                                    dbc_button("Compute", id="mc-heatmap-compute-button", color="light", n_clicks=0,
                                        style = Dict( "textAlign"        => "center",
                                                      "font-size"        => "100%",
                                                      "border"           => "1px grey solid",
                                                      "width"            => "100%",
                                                      "background-color" => "#d3f2ce")),
                                    html_div("‎ "),
                                    html_div(id="mc-heatmap-status", children="",
                                        style = Dict("textAlign" => "center", "font-size" => "90%", "color" => "grey")),
                                    html_div("‎ "),
                                    dbc_button("Export SVG", id="mc-heatmap-export-svg-button", color="light", n_clicks=0,
                                        style = Dict( "textAlign" => "center", "font-size" => "90%",
                                                      "border"    => "1px grey solid", "width" => "100%")),
                                    html_div(id="mc-heatmap-export-svg-status", children="",
                                        style = Dict("textAlign" => "center", "font-size" => "75%", "color" => "grey",
                                                     "marginTop" => 6, "wordBreak" => "break-all")),
                                ])),
                            id      = "collapse-mc-heatmap",
                            is_open = true,
                        ),
                        dcc_graph(id="mc-spider", figure=plot(Layout(width=180, height=380)),
                                  style = Dict("marginTop" => "12px")),
                    ]),
                    html_div([
                        dcc_graph(id="mc-heatmap", figure=plot(Layout(width=720, height=700))),
                    ]),
                ], style = Dict("display" => "grid", "gridTemplateColumns" => "180px 720px 180px 720px",
                                "gap" => "12px", "alignItems" => "start", "overflowX" => "auto")),
            ],
            id        = "mc-canvas",
            title     = "Monte Carlo boundary uncertainty",
            is_open   = false,
            placement = "top",
            style     = Dict( "height"           => "83.3333vh",
                              "maxHeight"        => "83.3333vh",
                              "overflowY"        => "auto",
                              "background-color" => "rgba(255, 255, 255, 1.0)"),
        ),
    ])
end
