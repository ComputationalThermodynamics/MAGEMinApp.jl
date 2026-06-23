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
                            html_hr(),

                            dbc_row([
                                dbc_col([
                                    html_h1("Export references",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "120%",
                                                     "marginTop" => 0)),
                                ], width=3),
                                dbc_col([
                                    dbc_input(
                                        id    = "export-citation-id-ix",
                                        type  = "text",
                                        style = Dict("textAlign" => "center"),
                                        value = "filename"),
                                ], width=4),
                                dbc_col([
                                    dbc_button("bibtex file",
                                        id      = "export-citation-button-ix",
                                        color   = "light",
                                        n_clicks = 0,
                                        style   = Dict("textAlign" => "center",
                                                       "font-size" => "100%",
                                                       "border"    => "1px grey solid")),
                                    dbc_tooltip([
                                        html_div("Saves MAGEMin, thermodynamic database and IntersecT references"),
                                        html_div("Output path is displayed in the Julia terminal")],
                                        target = "export-citation-button-ix"),
                                ]),
                            ]),

                            dbc_row([
                                dbc_alert(
                                    "Successfully saved references",
                                    id      = "export-citation-save-ix",
                                    is_open = false,
                                    duration = 4000,
                                ),
                                dbc_alert(
                                    "Provide a valid filename (without extension)",
                                    color   = "danger",
                                    id      = "export-citation-failed-ix",
                                    is_open = false,
                                    duration = 4000,
                                ),
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

                            dbc_tabs([
                                dbc_tab(label="Diagrams", children=[

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

                                    # Caption figure (above main diagram, height driven by callback)
                                    dbc_row([
                                        dcc_graph(
                                            id     = "diagram-cap-ix",
                                            figure = Dict(),
                                            config = PlotConfig(displayModeBar=false),
                                            style  = Dict("display" => "none"),
                                        ),
                                    ]),

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

                                ]),
                                dbc_tab(label="Log", children=[
                                    html_div("‎ "),
                                    dcc_markdown(
                                        id       = "log-markdown-ix",
                                        children = "Run calculation first",
                                        style    = Dict("white-space" => "pre-wrap", "font-size" => "100%"),
                                    ),
                                ]),
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

                        html_div("‎ "),

                        # ── Isocontours ──────────────────────────────────────
                        html_h1("Isocontours",
                            style = Dict("textAlign" => "center",
                                         "font-size" => "120%",
                                         "marginTop" => 8)),
                        html_hr(),

                        # Type selector
                        dbc_row([
                            dbc_col([
                                html_h1("Type",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "iso-type-ix",
                                    options   = ["Measurements", "Field"],
                                    value     = "Measurements",
                                    clearable = false,
                                ),
                            ], width=8),
                        ]),

                        html_div("‎ "),

                        # Measurements sub-section (phase + element)
                        html_div([
                            dbc_row([
                                dbc_col([
                                    html_h1("Phase",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "marginTop" => 8)),
                                ], width=4),
                                dbc_col([
                                    dcc_dropdown(
                                        id          = "iso-phase-dd-ix",
                                        options     = [],
                                        value       = nothing,
                                        clearable   = false,
                                        placeholder = "Load measurements first",
                                    ),
                                ], width=8),
                            ]),
                            dbc_row([
                                dbc_col([
                                    html_h1("Element",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "marginTop" => 8)),
                                ], width=4),
                                dbc_col([
                                    dcc_dropdown(
                                        id          = "iso-elem-dd-ix",
                                        options     = [],
                                        value       = nothing,
                                        clearable   = false,
                                        placeholder = "Select phase first",
                                    ),
                                ], width=8),
                            ]),
                        ], id="iso-meas-section-ix"),

                        # Field sub-section (IntersecT result field)
                        html_div([
                            dbc_row([
                                dbc_col([
                                    html_h1("Field",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "marginTop" => 8)),
                                ], width=4),
                                dbc_col([
                                    dcc_dropdown(
                                        id          = "iso-field-dd-ix",
                                        options     = [],
                                        value       = nothing,
                                        clearable   = false,
                                        placeholder = "Run IntersecT first",
                                    ),
                                ], width=8),
                            ]),
                        ], id="iso-field-section-ix", style=Dict("display" => "none")),

                        html_div("‎ "),

                        dbc_row([
                            dbc_col([
                                html_h1("Min",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dbc_input(
                                    id       = "iso-min-ix",
                                    type     = "number",
                                    min      = -1e8,
                                    max      =  1e8,
                                    value    = 0.0,
                                    debounce = true,
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Step",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dbc_input(
                                    id       = "iso-step-ix",
                                    type     = "number",
                                    min      = 1e-6,
                                    max      =  1e8,
                                    value    = 0.1,
                                    debounce = true,
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Max",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dbc_input(
                                    id       = "iso-max-ix",
                                    type     = "number",
                                    min      = -1e8,
                                    max      =  1e8,
                                    value    = 1.0,
                                    debounce = true,
                                ),
                            ]),
                        ]),

                        html_hr(),

                        dbc_row([
                            dbc_col([
                                html_h1("Line style",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dcc_dropdown(
                                    id        = "iso-lstyle-ix",
                                    options   = [
                                        (label = "Solid",       value = "solid"),
                                        (label = "Dot",         value = "dot"),
                                        (label = "Dash",        value = "dash"),
                                        (label = "Longdash",    value = "longdash"),
                                        (label = "Dashdot",     value = "dashdot"),
                                        (label = "Longdashdot", value = "longdashdot"),
                                    ],
                                    value     = "solid",
                                    clearable = false,
                                ),
                            ], width=8),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Line width",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dbc_input(
                                    id    = "iso-lwidth-ix",
                                    type  = "number",
                                    min   = 0,
                                    max   = 10,
                                    value = 1,
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Color",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dbc_input(
                                    type  = "color",
                                    id    = "colorpicker-iso-ix",
                                    value = "#000000",
                                    style = Dict("width" => 75, "height" => 25),
                                ),
                            ]),
                        ]),

                        dbc_row([
                            dbc_col([
                                html_h1("Label size",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "100%",
                                                 "marginTop" => 8)),
                            ], width=4),
                            dbc_col([
                                dbc_input(
                                    id    = "iso-lsize-ix",
                                    type  = "number",
                                    min   = 6,
                                    max   = 20,
                                    value = 10,
                                ),
                            ]),
                        ]),

                        html_div("‎ "),
                        dbc_row([
                            dbc_button("Add", id="button-add-iso-ix", color="light",
                                style = Dict("textAlign" => "center",
                                             "font-size" => "100%",
                                             "border"    => "1px lightgray solid")),
                        ]),

                        html_hr(),
                        dbc_row([

                            dbc_col([
                                html_h1("Displayed",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "120%",
                                                 "marginTop" => 8)),
                                dbc_row([
                                    dcc_dropdown(
                                        id        = "isopleth-list-ix",
                                        options   = [],
                                        value     = nothing,
                                        clearable = false,
                                        multi     = false,
                                    ),
                                ]),
                                html_div("‎ "),
                                dbc_row([
                                    dbc_button("Hide", id="button-hide-iso-ix", color="light",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "border"    => "1px lightgray solid")),
                                ]),
                                dbc_row([
                                    dbc_button("Hide all", id="button-hide-all-iso-ix", color="light",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "border"    => "1px lightgray solid")),
                                ]),
                                html_div("‎ "),
                                dbc_row([
                                    dbc_button("Remove", id="button-remove-iso-ix", color="light",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "border"    => "1px lightgray solid")),
                                ]),
                                dbc_row([
                                    dbc_button("Remove all", id="button-remove-all-iso-ix", color="light",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "border"    => "1px lightgray solid")),
                                ]),
                            ], width=6),

                            dbc_col([
                                html_h1("Hidden",
                                    style = Dict("textAlign" => "center",
                                                 "font-size" => "120%",
                                                 "marginTop" => 8)),
                                dbc_row([
                                    dcc_dropdown(
                                        id        = "hidden-isopleth-list-ix",
                                        options   = [],
                                        value     = nothing,
                                        clearable = false,
                                        multi     = false,
                                    ),
                                ]),
                                html_div("‎ "),
                                dbc_row([
                                    dbc_button("Show", id="button-show-iso-ix", color="light",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "border"    => "1px lightgray solid")),
                                ]),
                                dbc_row([
                                    dbc_button("Show all", id="button-show-all-iso-ix", color="light",
                                        style = Dict("textAlign" => "center",
                                                     "font-size" => "100%",
                                                     "border"    => "1px lightgray solid")),
                                ]),
                            ], width=6),

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
        # Hidden store: incremented whenever isopleths change, to trigger diagram/caption re-render.
        dcc_store(id="ix-iso-store-ix", data=0),

    ])
end
