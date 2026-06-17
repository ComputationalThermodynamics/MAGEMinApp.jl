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

function Tab_IntersecT()
    html_div([
        dbc_col([
            dbc_row([

                # ── COLUMN 1 ── Setup controls (width=3)
                dbc_col([

                    dbc_button("Setup", id="button-setup-ix",
                        style = Dict("width" => "100%")),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([

                            # Logo
                            dbc_row([
                                dbc_col([
                                    dbc_cardimg(
                                        src   = "assets/static/images/Logo-IntersecT.png",
                                        style = Dict("width" => "180px", "marginBottom" => "10px"),
                                    ),
                                ], width="auto"),
                            ], justify="center"),

                            html_div("‎ "),

                            # Run button
                            dbc_row([
                                dbc_button(
                                    "Run IntersecT",
                                    id        = "run-intersect-ix",
                                    n_clicks  = 0,
                                    style     = Dict(
                                        "textAlign"        => "center",
                                        "font-size"        => "105%",
                                        "background-color" => "#d3f2ce",
                                        "color"            => "black",
                                        "border"           => "1px grey solid",
                                        "width"            => "100%",
                                    ),
                                ),
                            ]),
                            html_div("‎ "),

                            # Measurement file upload
                            dbc_row([
                                dbc_col([
                                    html_h1("Measurement file",
                                        style = Dict("textAlign" => "left", "font-size" => "120%")),
                                ]),
                            ]),
                            dbc_row([
                                dcc_upload(
                                    id       = "upload-measurements-ix",
                                    children = html_div("Drag and drop or select CSV file"),
                                    style    = Dict(
                                        "width"        => "100%",
                                        "height"       => "50px",
                                        "lineHeight"   => "50px",
                                        "borderWidth"  => "1px",
                                        "borderStyle"  => "dashed",
                                        "borderRadius" => "5px",
                                        "textAlign"    => "center",
                                    ),
                                    multiple = false,
                                ),
                            ]),
                            html_div("‎ "),
                            dbc_row([
                                dbc_card([
                                    dcc_markdown(
                                        id       = "upload-status-ix",
                                        children = "*No file loaded*",
                                        style    = Dict("white-space" => "pre-wrap",
                                                        "word-break"  => "break-word",
                                                        "font-size"   => "90%",
                                                        "padding"     => "4px"),
                                    ),
                                ]),
                            ]),

                            html_div("‎ "),

                            # Phase checklist (populated after file load)
                            dbc_row([
                                dbc_col([
                                    html_h1("Stable phases",
                                        style = Dict("textAlign" => "left", "font-size" => "120%")),
                                ]),
                            ]),
                            dbc_row([
                                dbc_col([
                                    dcc_checklist(
                                        id      = "phase-checklist-ix",
                                        options = [],
                                        value   = [],
                                        style   = Dict("font-size" => "100%"),
                                    ),
                                ]),
                            ]),

                            html_div("‎ "),

                            # Analysis type dropdown
                            dbc_row([
                                dbc_col([
                                    html_h1("Analysis type",
                                        style = Dict("textAlign" => "left",
                                                     "font-size" => "120%",
                                                     "marginTop" => 4)),
                                ], width=5),
                                dbc_col([
                                    dcc_dropdown(
                                        id        = "analysis-type-ix",
                                        options   = ["WDS spot", "WDS map", "EDS"],
                                        value     = "WDS spot",
                                        clearable = false,
                                    ),
                                ], width=7),
                            ]),

                            html_div("‎ "),

                            dbc_row([
                                dbc_alert(
                                    "",
                                    id       = "intersect-alert-ix",
                                    is_open  = false,
                                    duration = 6000,
                                    color    = "danger",
                                ),
                            ]),

                        ])),
                        id      = "collapse-setup-ix",
                        is_open = true,
                    ),

                ], width=3),

                # ── COLUMN 2 ── Results: display dropdown + diagram (width=6)
                dbc_col([

                    dbc_button("Results", id="button-results-ix",
                        style = Dict("width" => "100%")),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([

                            # Output field dropdown
                            dbc_row([
                                dbc_col([
                                    html_h1("Display",
                                        style = Dict("textAlign" => "left",
                                                     "font-size" => "120%",
                                                     "marginTop" => 4)),
                                ], width=2),
                                dbc_col([
                                    dcc_dropdown(
                                        id          = "field-dropdown-ix",
                                        options     = [],
                                        value       = nothing,
                                        clearable   = false,
                                        placeholder = "Run calculation first",
                                    ),
                                ], width=10),
                            ]),

                            html_div("‎ "),

                            # Diagram
                            dbc_row([
                                dcc_graph(
                                    id     = "diagram-ix",
                                    figure = Dict(),
                                ),
                            ]),

                            html_div("‎ "),

                            # Sub-diagrams row
                            dbc_row([
                                dbc_col([
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Display",
                                                style = Dict("textAlign" => "left",
                                                             "font-size" => "120%",
                                                             "marginTop" => 4)),
                                        ], width=3),
                                        dbc_col([
                                            dcc_dropdown(
                                                id          = "field-dropdown-ix-1",
                                                options     = [],
                                                value       = nothing,
                                                clearable   = false,
                                                placeholder = "Run calculation first",
                                            ),
                                        ], width=9),
                                    ]),
                                    html_div("‎ "),
                                    dcc_graph(
                                        id     = "diagram-ix-1",
                                        figure = Dict(),
                                    ),
                                ], width=6),

                                dbc_col([
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Display",
                                                style = Dict("textAlign" => "left",
                                                             "font-size" => "120%",
                                                             "marginTop" => 4)),
                                        ], width=3),
                                        dbc_col([
                                            dcc_dropdown(
                                                id          = "field-dropdown-ix-2",
                                                options     = [],
                                                value       = nothing,
                                                clearable   = false,
                                                placeholder = "Run calculation first",
                                            ),
                                        ], width=9),
                                    ]),
                                    html_div("‎ "),
                                    dcc_graph(
                                        id     = "diagram-ix-2",
                                        figure = Dict(),
                                    ),
                                ], width=6),
                            ]),

                        ])),
                        id      = "collapse-results-ix",
                        is_open = true,
                    ),

                ], width=6),

                # ── COLUMN 3 ── Color options + Overlay options (width=3)
                dbc_col([

                    dbc_button("Options", id="button-options-ix",
                        style = Dict("width" => "100%")),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([

                        # ── Color options ────────────────────────────────
                        html_h1("Color options",
                            style = Dict("textAlign" => "center",
                                         "font-size" => "120%",
                                         "marginTop" => 8)),
                        html_hr(),

                        dbc_row([
                            dbc_col([
                                html_h1("Colormap",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "colormaps-ix",
                                    options   = vcat(
                                        [Dict("label" => n, "value" => n) for n in [
                                            "blackbody","Blues","cividis","Greens","Greys",
                                            "hot","jet","RdBu","RdYlGn","Reds","viridis",
                                            "YlGnBu","YlOrRd"]],
                                        [Dict("label" => "- R.J. Tamblyn colormaps -",
                                              "value" => "separator",
                                              "disabled" => true)],
                                        [Dict("label" => n, "value" => n) for n in [
                                            "Pink","Sunset","Dawn","Almeria",
                                            "Almeria Extended","Almeria Red","Almeria Blue"]],
                                    ),
                                    value     = "RdBu",
                                    clearable = false,
                                ),
                            ]),
                        ]),

                        html_div("‎ "),
                        dbc_row([
                            dbc_col([], width=5),
                            dbc_col([html_h1("min", style = Dict("textAlign" => "center", "font-size" => "100%"))]),
                            dbc_col([html_h1("max", style = Dict("textAlign" => "center", "font-size" => "100%"))]),
                        ]),
                        dbc_row([
                            dbc_col([
                                html_h1("Value range",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dbc_row([
                                    dbc_col([
                                        dbc_input(
                                            id       = "min-color-ix",
                                            type     = "number",
                                            min      = -1e50,
                                            max      =  1e50,
                                            value    = 0.0,
                                            debounce = true,
                                        ),
                                    ]),
                                    dbc_col([
                                        dbc_input(
                                            id       = "max-color-ix",
                                            type     = "number",
                                            min      = -1e50,
                                            max      =  1e50,
                                            value    = 100.0,
                                            debounce = true,
                                        ),
                                    ]),
                                ]),
                            ]),
                        ]),

                        html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                html_h1("Colormap range",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_rangeslider(
                                    id    = "range-slider-color-ix",
                                    count = 1,
                                    min   = 1,
                                    max   = 9,
                                    step  = 1,
                                    value = [1, 9],
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Set min to white",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "set-min-white-ix",
                                    options   = ["true","false"],
                                    value     = "false",
                                    clearable = false,
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Reverse colormap",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "reverse-colormap-ix",
                                    options   = ["true","false"],
                                    value     = "false",
                                    clearable = false,
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Smooth colormap",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "smooth-colormap-ix",
                                    options   = ["fast","best",false],
                                    value     = "fast",
                                    clearable = false,
                                ),
                            ]),
                        ]),

                        html_div("‎ "),

                        # ── Overlay options ──────────────────────────────
                        html_h1("Overlay options",
                            style = Dict("textAlign" => "center",
                                         "font-size" => "120%",
                                         "marginTop" => 8)),
                        html_hr(),

                        dbc_row([
                            dbc_col([
                                html_h1("Show grid",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "show-full-grid-ix",
                                    options   = ["true", "false"],
                                    value     = "false",
                                    clearable = false,
                                    multi     = false,
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Show phase label",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "show-lbl-ix",
                                    options   = ["true", "false"],
                                    value     = "true",
                                    clearable = false,
                                    multi     = false,
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Show reaction lines",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=5),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "show-grid-ix",
                                    options   = ["true", "false"],
                                    value     = "true",
                                    clearable = false,
                                    multi     = false,
                                ),
                            ]),
                        ]),

                    ])),
                        id      = "collapse-options-ix",
                        is_open = true,
                    ),

                ], width=3),

            ]),
        ], width=12),

        # Hidden store: incremented by Run button so all diagram callbacks re-fire
        # even when dropdown values haven't changed (e.g. re-run after diagram refinement).
        dcc_store(id="intersect-run-store-ix", data=0),

    ])
end
