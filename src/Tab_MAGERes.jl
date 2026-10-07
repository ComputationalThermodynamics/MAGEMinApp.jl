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

const MAGERES_DRAWER_FIELDS = (:database, :oxides, :magma_bulk, :host_bulk, :injection_bulk, :te_elements,
                               :te_injection_ppm, :te_host_ppm, :te_magma_ppm)

const MAGERES_ENUM_FIELDS = Dict{Symbol,Vector{Dict{String,Any}}}(
    :boost_mode       => [Dict("label" => "Off", "value" => false), Dict("label" => "On", "value" => true)],
    :show_grid        => [Dict("label" => "Shown", "value" => true), Dict("label" => "Hidden", "value" => false)],
    :show_outline     => [Dict("label" => "Shown", "value" => true), Dict("label" => "Hidden", "value" => false)],
    :show_isotherms   => [Dict("label" => "Shown", "value" => true), Dict("label" => "Hidden", "value" => false)],
    :opening_mode     => [Dict("label" => "Split (½ roof up, ½ floor down)", "value" => "split"),
                          Dict("label" => "Roof uplift",                     "value" => "up"),
                          Dict("label" => "Floor subsidence",                "value" => "down")],
    :lens_shape       => [Dict("label" => "Ellipse",  "value" => "ellipse"),
                          Dict("label" => "Parabola", "value" => "parabola")],
    :thermodynamics   => [Dict("label" => "Constant properties", "value" => "constant"),
                          Dict("label" => "MAGEMin",             "value" => "magemin")],
    :thermal_bc       => [Dict("label" => "Fixed surface T + geotherm flux", "value" => "surface"),
                          Dict("label" => "Insulated",                       "value" => "insulated")],
    :injection_melt_only => [Dict("label" => "Bulk composition (as defined)", "value" => false),
                             Dict("label" => "Equilibrated melt", "value" => true)],
    :injection_target => [Dict("label" => "Mobile body (sill in place if there is none)", "value" => "body"),
                          Dict("label" => "In place (sill at the chamber centre)",        "value" => "chamber")],
    :fluid_treatment  => [Dict("label" => "Removed",  "value" => "removed"),
                          Dict("label" => "Retained", "value" => "retained")],
    :eruption_trigger => [Dict("label" => "Mean melt fraction of the mobile body", "value" => "melt"),
                          Dict("label" => "Overpressure (eruptible above the melt fraction)",
                               "value" => "overpressure")],
    :te_enabled       => [Dict("label" => "false", "value" => false), Dict("label" => "true", "value" => true)],
    :zircon_method    => [Dict("label" => "SIMS U-Th (absolute σ)",      "value" => "SIMS_UTh"),
                          Dict("label" => "LA-ICP-MS U-Pb (1 % 1σ)",     "value" => "LA_UPb"),
                          Dict("label" => "CA-ID-TIMS U-Pb (0.05 % 1σ)", "value" => "TIMS_UPb")],
    :kds_mod          => [Dict("label" => "OL",    "value" => "OL"),
                          Dict("label" => "CO",    "value" => "CO"),
                          Dict("label" => "Yak25", "value" => "Yak25")],
    :zrsat_mod        => [Dict("label" => "none",                     "value" => "none"),
                          Dict("label" => "Watson & Harrison (1983)", "value" => "WH"),
                          Dict("label" => "Boehnke et al. (2013)",    "value" => "B"),
                          Dict("label" => "Crisp and Berry (2022)",   "value" => "CB")],
)

const MAGERES_TE_SHOW_OPTIONS = [Dict("label" => "REE",                "value" => "ree"),
                                 Dict("label" => "All trace elements", "value" => "all")]
const MAGERES_TE_NORM_OPTIONS = [Dict("label" => "Chondrite normalised",      "value" => "chondrite"),
                                 Dict("label" => "Injected-magma normalised", "value" => "bulk")]

"""
    mageres_input_id(f::Symbol)

    Component id of the input control of option field `f`.
"""
mageres_input_id(f::Symbol) = "mageres-opt-$(f)"

"""
    mageres_row_id(f::Symbol)

    Component id of the row holding the control of option field `f`.
"""
mageres_row_id(f::Symbol)   = "mageres-row-$(f)"

const MAGERES_CONSTANT_ONLY_FIELDS = (:rho_magma, :cp_magma, :cp_host)

"""
    mageres_row_style(f::Symbol, thermodynamics)

    Style of the row of option field `f`: hidden for constant-property-only fields when `thermodynamics`
    is "magemin", default style otherwise.
"""
mageres_row_style(f::Symbol, thermodynamics) =
    f in MAGERES_CONSTANT_ONLY_FIELDS && thermodynamics == "magemin" ? Dict("display" => "none") : Dict{String,String}()

"""
    mageres_group_slug(g::AbstractString)

    Lowercase, dash-separated slug of option group name `g`.
"""
mageres_group_slug(g::AbstractString) = lowercase(replace(g, " " => "-"))

"""
    mageres_ui_fields()

    Option fields shown in the configuration tabs, i.e. all fields of `MAGERES_OPTION_GROUPS` except the
    drawer fields.
"""
mageres_ui_fields() = [f for (_, fs) in MAGERES_OPTION_GROUPS for (f, _) in fs if !(f in MAGERES_DRAWER_FIELDS)]

"""
    mageres_labelled_row(label, control)

    Row with `label` on the left and `control` on the right.
"""
function mageres_labelled_row(label, control)
    dbc_row([
        dbc_col([ html_h1(label, style = Dict("textAlign" => "left", "font-size" => "120%")) ], width = 7),
        dbc_col([ control ], width = 5),
    ])
end

"""
    mageres_option_row(f::Symbol, label::AbstractString, default)

    Labelled row holding the input control of option field `f`: a dropdown for enumerated fields,
    a number input otherwise, initialised to `default`.
"""
function mageres_option_row(f::Symbol, label::AbstractString, default)
    id      = mageres_input_id(f)
    control = if haskey(MAGERES_ENUM_FIELDS, f)
        dcc_dropdown(   id        = id,
                        options   = MAGERES_ENUM_FIELDS[f],
                        value     = default,
                        clearable = false,
                        multi     = false)
    else
        kwargs = Dict{Symbol,Any}(:id => id, :type => "number", :value => default)
        default isa Integer && (kwargs[:step] = 1)
        dbc_input(; kwargs...)
    end
    return html_div(id       = mageres_row_id(f),
                    children = [mageres_labelled_row(label, control)],
                    style    = mageres_row_style(f, MAGEResOptions().thermodynamics))
end

"""
    mageres_bulk_rock_panel(suffix::AbstractString, default_test::Int)

    Bulk-rock selection panel (test dropdown, editable composition table, file upload and status alerts)
    whose component ids end with `suffix`, preset to test `default_test` of the "ig" database.
"""
function mageres_bulk_rock_panel(suffix::AbstractString, default_test::Int)
    sub = db[(db.db .== "ig"), :]
    row = sub[(sub.test .== default_test), :]
    html_div([
        dcc_dropdown(   id          = "test-dropdown-mageres-$(suffix)",
                        options     = [ Dict("label" => sub.title[i], "value" => sub.test[i]) for i = 1:size(sub, 1) ],
                        value       = default_test,
                        clearable   = false,
                        multi       = false),
        html_div("‎ "),
        dash_datatable(
            id           = "table-bulk-rock-mageres-$(suffix)",
            columns      = [ Dict("id" => "oxide",    "name" => "oxide",    "editable" => false),
                             Dict("id" => "fraction", "name" => "fraction", "editable" => true) ],
            data         = [ Dict("oxide" => row.oxide[1][i], "fraction" => row.frac[1][i])
                             for i = 1:length(row.oxide[1]) ],
            style_cell   = (textAlign = "center", fontSize = "110%"),
            style_header = (fontWeight = "bold",),
            editable     = true,
        ),
        html_div("‎ "),
        dcc_upload(
            id       = "upload-bulk-mageres-$(suffix)",
            children = html_div(["Drag and drop or select bulk-rock file"]),
            style    = Dict("width"        => "100%",   "height"      => "50px", "lineHeight" => "50px",
                            "borderWidth"  => "1px",    "borderStyle" => "dashed",
                            "borderRadius" => "5px",    "textAlign"   => "center"),
            multiple = false,
        ),
        dbc_alert(  "Bulk-rock composition successfully loaded",
                    id       = "upload-ok-mageres-$(suffix)",
                    is_open  = false,
                    duration = 4000),
        dbc_alert(  "Bulk-rock composition failed to load, check input file format",
                    color    = "danger",
                    id       = "upload-failed-mageres-$(suffix)",
                    is_open  = false,
                    duration = 4000),
    ])
end

"""
    mageres_te_panel(suffix::AbstractString, default_test::Int)

    Trace-element composition panel (predefined composition dropdown and editable µg/g table) whose component ids
    end with `suffix`, preset to the predefined composition `default_test`.
"""
function mageres_te_panel(suffix::AbstractString, default_test::Int)
    dbte = AppData.dbte
    i    = something(findfirst(==(default_test), dbte.test), 1)
    html_div([
        dcc_dropdown(   id        = "test-te-dropdown-mageres-$(suffix)",
                        options   = [ Dict("label" => dbte.title[k], "value" => dbte.test[k]) for k = 1:size(dbte, 1) ],
                        value     = default_test,
                        clearable = false,
                        multi     = false),
        dash_datatable(
            id           = "table-te-mageres-$(suffix)",
            columns      = [ Dict("id" => "elements", "name" => "element", "editable" => false),
                             Dict("id" => "μg_g",     "name" => "μg/g",    "editable" => true) ],
            data         = [ Dict("elements" => dbte.elements[i][k], "μg_g" => dbte.μg_g[i][k])
                             for k = 1:length(dbte.elements[i]) ],
            style_cell   = (textAlign = "center", fontSize = "110%"),
            style_header = (fontWeight = "bold",),
            editable     = true,
            page_size    = 10,
        ),
    ])
end

"""
    mageres_composition_row(suffix::AbstractString, bulk_test::Int, te_test::Int)

    Side-by-side major-element bulk-rock panel and trace-element panel of composition `suffix`.
"""
function mageres_composition_row(suffix::AbstractString, bulk_test::Int, te_test::Int)
    sub = Dict("textAlign" => "center", "font-size" => "105%")
    dbc_row([
        dbc_col([ html_h1("Major elements", style = sub), mageres_bulk_rock_panel(suffix, bulk_test) ], width = 6),
        dbc_col([ html_h1("Trace elements [μg/g]", style = sub), mageres_te_panel(suffix, te_test) ], width = 6),
    ])
end

"""
    mageres_drawer_button(label::AbstractString, id::AbstractString)

    Full-width light button with text `label` and component id `id`.
"""
function mageres_drawer_button(label::AbstractString, id::AbstractString)
    dbc_button(label, id = id, color = "light", n_clicks = 0,
        style = Dict(   "textAlign" => "center", "font-size" => "100%",
                        "border"    => "1px grey solid", "width" => "100%"))
end

"""
    mageres_config_tab(group::AbstractString, fields)

    Configuration tab of option group `group`, holding composition buttons where relevant and one row per option
    field in `fields`.
"""
function mageres_config_tab(group::AbstractString, fields)
    o        = MAGEResOptions()
    children = Any[html_div("‎ ")]
    if group == "Model properties"
        append!(children, [ html_h1("Material composition",
                                    style = Dict("textAlign" => "center", "font-size" => "120%")),
                            mageres_drawer_button("Define material compositions", "button-define-bulk-mageres"),
                            html_hr()])
    elseif group == "Injection"
        append!(children, [ html_h1("Composition", style = Dict("textAlign" => "center", "font-size" => "120%")),
                            dbc_checklist(  id      = "injection-use-magma-mageres",
                                            options = [Dict("label" => " Same as magma", "value" => 1)],
                                            value   = [1],
                                            switch  = true,
                                            style   = Dict("marginLeft" => "12px")),
                            html_div("‎ "),
                            mageres_drawer_button("Define injection composition", "button-define-injection-mageres"),
                            html_hr()])
    end
    for (f, label) in fields
        f in MAGERES_DRAWER_FIELDS && continue
        push!(children, mageres_option_row(f, label, getfield(o, f)))
    end
    return dbc_tab(tab_id = "mageres-config-$(mageres_group_slug(group))", label = group, children = children)
end

"""
    mageres_file_dialogs(kind::AbstractString, noun::AbstractString, default_name::AbstractString, store_id)

    "Save <noun>" and "Load <noun>" buttons with their dialogs (file name, existing saves) and status alerts; component
    ids are built from `kind` (e.g. `open-save-<kind>-mageres`). `store_id`, when given, adds a data store with that id.
"""
function mageres_file_dialogs(kind::AbstractString, noun::AbstractString, default_name::AbstractString,
                              store_id = nothing)
    button(label, id) = dbc_button(label, id = id, color = "light", n_clicks = 0,
                                   style = Dict("textAlign" => "center", "font-size" => "100%",
                                                "border"    => "1px grey solid", "width" => "100%"))
    children = Any[
        dbc_row([
            dbc_col([ button("Save $(noun)", "open-save-$(kind)-mageres") ], width = 6),
            dbc_col([ button("Load $(noun)", "open-load-$(kind)-mageres") ], width = 6),
        ]),
        dbc_modal([
            dbc_modalheader(dbc_modaltitle("Save MAGEMin Reservoir $(noun)")),
            dbc_modalbody([
                dbc_row([
                    dbc_col([ html_label("File name:") ], width = 3),
                    dbc_col([ dbc_input(id = "save-$(kind)-filename-mageres", type = "text", value = default_name,
                                        placeholder = "e.g. $(default_name)", style = Dict("width" => "100%")) ]),
                ]),
                html_div("‎ "),
                html_small("Or pick an existing $(noun) to overwrite:", style = Dict("color" => "grey")),
                dcc_dropdown(id = "save-$(kind)-existing-mageres", options = [], value = nothing,
                             placeholder = "Select existing $(noun)…", clearable = true, multi = false,
                             style = Dict("marginTop" => "4px")),
            ]),
            dbc_modalfooter([
                dbc_button("Save",   id = "save-$(kind)-button-mageres", color = "primary",   n_clicks = 0),
                dbc_button("Cancel", id = "close-save-$(kind)-mageres",  color = "secondary", n_clicks = 0,
                           className = "ms-2"),
            ]),
        ], id = "save-$(kind)-modal-mageres", is_open = false),
        dbc_modal([
            dbc_modalheader(dbc_modaltitle("Load MAGEMin Reservoir $(noun)")),
            dbc_modalbody([
                html_small("Select a $(noun):", style = Dict("color" => "grey")),
                dcc_dropdown(id = "load-$(kind)-existing-mageres", options = [], value = nothing,
                             placeholder = "Select a saved $(noun)…", clearable = false, multi = false,
                             style = Dict("marginTop" => "4px")),
                html_div("‎ "),
                html_small("Or type a name manually:", style = Dict("color" => "grey")),
                dbc_input(id = "load-$(kind)-filename-mageres", type = "text",
                          placeholder = "file name (without extension)", style = Dict("marginTop" => "4px",
                                                                                      "width"     => "100%")),
            ]),
            dbc_modalfooter([
                dbc_button("Load",   id = "load-$(kind)-button-mageres", color = "primary",   n_clicks = 0),
                dbc_button("Cancel", id = "close-load-$(kind)-mageres",  color = "secondary", n_clicks = 0,
                           className = "ms-2"),
            ]),
        ], id = "load-$(kind)-modal-mageres", is_open = false),
        dbc_alert("", id = "save-$(kind)-alert-mageres", is_open = false, duration = 6000),
        dbc_alert("", id = "load-$(kind)-alert-mageres", is_open = false, duration = 6000),
    ]
    store_id === nothing || push!(children, dcc_store(id = store_id, data = nothing))
    return html_div(children)
end

const MAGERES_GIF_GRAPHS = ("mageres-results-temperature-fig", "mageres-results-material-fig",
                            "mageres-results-melt-fig", "mageres-results-calc-fig", "mageres-tas-fig",
                            "mageres-cumulate-fig")

"""
    mageres_export_row(id)

    Right-aligned export row above graph `id`: status texts and the "Export svg" button, preceded by a "Save gif" button
    for the graphs of `MAGERES_GIF_GRAPHS`. Ids derive from `id` (`<id>-svg-button`, `<id>-gif-button`, ...).
"""
function mageres_export_row(id::AbstractString)
    id in MAGERES_GIF_GRAPHS || return svg_export_button_row(id)
    status(sid) = html_div(id = sid, children = "",
                           style = Dict("display"     => "inline-block", "font-size"     => "75%",
                                        "color"       => "grey",         "marginRight"   => "10px",
                                        "verticalAlign" => "middle",     "wordBreak"     => "break-all"))
    button(label, bid) = dbc_button(label, id = bid, color = "light", n_clicks = 0,
                                    style = Dict("font-size"  => "80%", "border" => "1px grey solid",
                                                 "marginLeft" => "6px"))
    dbc_row([
        dbc_col([
            status(id * "-gif-status"),
            status(id * "-svg-status"),
            button("Save gif", id * "-gif-button"),
            button("Export svg", id * "-svg-button"),
        ], width = "auto"),
    ], justify = "end", style = Dict("marginBottom" => "4px"))
end

"""
    mageres_graph(id)

    Graph with component id `id`, showing a "No data yet" placeholder figure, with its export row above it.
"""
mageres_graph(id) = html_div([
    mageres_export_row(id),
    dcc_graph(  id     = id,
                figure = mageres_placeholder_figure("No data yet"),
                config = Dict("displaylogo" => false)),
])

"""
    Tab_MAGERes()

    Layout of the MAGEMin Reservoir tab: configuration and simulation panels, initial-condition, results and
    methodology tabs, and the bulk-rock and injection composition drawers.
"""
function Tab_MAGERes()
    html_div([
        html_div("‎ "),
        dbc_row([

            dbc_col([
                dbc_row([
                    dbc_button("Configuration", id = "button-config-mageres"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([
                            mageres_file_dialogs("config", "configuration", "my_reservoir", "mageres-config-store"),
                            html_div("‎ "),
                            dbc_tabs(id = "mageres-config-tabs",
                                     [mageres_config_tab(g, fs) for (g, fs) in MAGERES_OPTION_GROUPS]),
                        ])),
                        id      = "collapse-config-mageres",
                        is_open = true,
                    ),
                ]),

                html_div("‎ "),

                dbc_row([
                    dbc_button("Simulation", id = "button-simulation-mageres"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([
                            dbc_row([
                                dbc_col([
                                    dbc_button("Compute initial conditions", id = "compute-ic-button-mageres",
                                        color    = "light",
                                        n_clicks = 0,
                                        style    = Dict("textAlign"        => "center", "font-size" => "100%",
                                                        "background-color" => "#cfe2f3",
                                                        "border"           => "1px black solid", "width" => "100%")),
                                    html_div("‎ "),
                                    dbc_button("Launch simulation", id = "launch-run-button-mageres",
                                        color    = "light",
                                        n_clicks = 0,
                                        style    = Dict("textAlign"        => "center", "font-size" => "100%",
                                                        "background-color" => "#d3f2ce",
                                                        "border"           => "1px black solid", "width" => "100%")),
                                    html_div("‎ "),
                                    dbc_button("Cancel", id = "cancel-run-button-mageres",
                                        color    = "light",
                                        n_clicks = 0,
                                        style    = Dict("textAlign"        => "center", "font-size" => "100%",
                                                        "background-color" => "#f2d3d3",
                                                        "border"           => "1px black solid", "width" => "100%")),
                                ], width = 6),
                                dbc_col([
                                    html_div(id = "run-status-text-mageres", children = "No run launched yet."),
                                ], width = 6),
                            ]),
                            dbc_alert(  "",
                                        id       = "ic-status-alert-mageres",
                                        color    = "danger",
                                        is_open  = false,
                                        duration = 6000),
                        ])),
                        id      = "collapse-simulation-mageres",
                        is_open = true,
                    ),
                ]),

                dcc_store(id = "run-id-store-mageres",          data = ""),
                dcc_store(id = "mageres-progress-off",          data = ""),
                dcc_interval(id = "run-poll-interval-mageres",  interval = 2000, disabled = true),

            ], width = 4),

            dbc_col([
                dbc_tabs(id = "mageres-main-tabs", [
                    dbc_tab(tab_id = "mageres-tab-ic", label = "Initial conditions", children = [
                        dbc_tabs(id = "mageres-ic-tabs", [
                            dbc_tab(label = "Material",    children = [ mageres_graph("mageres-ic-material-fig") ]),
                            dbc_tab(label = "Temperature", children = [ mageres_graph("mageres-ic-temperature-fig") ]),
                            dbc_tab(label = "Pressure",    children = [ mageres_graph("mageres-ic-pressure-fig") ]),
                            dbc_tab(label = "Grid",        children = [ mageres_graph("mageres-ic-grid-fig") ]),
                        ]),
                    ]),
                    dbc_tab(tab_id = "mageres-tab-results", label = "Results", children = [
                        html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                mageres_file_dialogs("sim", "simulation", "my_simulation", "mageres-sim-config-store"),
                                dbc_row([
                                    dbc_col([
                                        dbc_button("Resume simulation", id = "resume-run-button-mageres",
                                            color    = "light",
                                            n_clicks = 0,
                                            style    = Dict("textAlign"        => "center", "font-size" => "100%",
                                                            "background-color" => "#d3f2ce",
                                                            "border"           => "1px grey solid", "width" => "100%")),
                                    ], width = 6),
                                ], justify = "end", style = Dict("marginTop" => "6px")),
                                dcc_store(id = "mageres-loaded-run-store", data = nothing),
                            ], width = 6),
                        ], justify = "end"),
                        html_div("‎ "),
                        dbc_row([
                            dbc_col([
                                html_h1("Output", style = Dict("textAlign" => "right", "font-size" => "120%",
                                                               "marginBottom" => "0")),
                            ], width = 2),
                            dbc_col([
                                dcc_dropdown(   id        = "mageres-timestep-select",
                                                options   = [ Dict("label" => "Latest", "value" => -1) ],
                                                value     = -1,
                                                clearable = false,
                                                multi     = false),
                            ], width = 5),
                            dcc_store(id = "mageres-probe-store", data = nothing),
                            dcc_store(id = "mageres-pie-unit",    data = 1),
                        ], align = "center"),
                        html_div("‎ "),
                        dbc_tabs(id = "mageres-results-tabs", [
                            dbc_tab(label    = "Temperature",
                                    children = [ mageres_graph("mageres-results-temperature-fig") ]),
                            dbc_tab(label    = "Material",
                                    children = [ mageres_graph("mageres-results-material-fig") ]),
                            dbc_tab(label    = "Melt fraction",
                                    children = [ mageres_graph("mageres-results-melt-fig") ]),
                            dbc_tab(label    = "Thermodynamic calculations",
                                    children = [ mageres_graph("mageres-results-calc-fig") ]),
                            dbc_tab(label    = "Eruption",
                                    children = [
                                        dbc_tabs(id = "mageres-eruption-tabs", [
                                            dbc_tab(label    = "Volumes",
                                                    children = [ mageres_graph("mageres-eruption-fig") ]),
                                            dbc_tab(label    = "Trace elements",
                                                    children = [
                                                        html_div("‎ "),
                                                        dbc_row([
                                                            dbc_col([
                                                                dcc_dropdown(   id        = "mageres-te-show",
                                                                                options   = MAGERES_TE_SHOW_OPTIONS,
                                                                                value     = "ree",
                                                                                clearable = false,
                                                                                multi     = false),
                                                            ], width = 3),
                                                            dbc_col([
                                                                dcc_dropdown(   id        = "mageres-te-norm",
                                                                                options   = MAGERES_TE_NORM_OPTIONS,
                                                                                value     = "chondrite",
                                                                                clearable = false,
                                                                                multi     = false),
                                                            ], width = 3),
                                                        ]),
                                                        mageres_graph("mageres-eruption-te-fig"),
                                                    ]),
                                            dbc_tab(label    = "Zircon ages",
                                                    children = [ mageres_graph("mageres-zircon-rank-fig"),
                                                                 mageres_graph("mageres-zircon-ages-fig"),
                                                                 mageres_graph("mageres-zircon-spots-fig"),
                                                                 mageres_graph("mageres-zircon-families-fig") ]),
                                        ]),
                                    ]),
                            dbc_tab(label    = "Composition",
                                    children = [
                                        dbc_tabs(id = "mageres-melt-tabs", [
                                            dbc_tab(label    = "Injected",
                                                    children = [ mageres_graph("mageres-melt-in-fig") ]),
                                            dbc_tab(label    = "Chamber",
                                                    children = [ mageres_graph("mageres-melt-chamber-fig") ]),
                                            dbc_tab(label    = "Erupted",
                                                    children = [ mageres_graph("mageres-melt-out-fig") ]),
                                        ]),
                                    ]),
                            dbc_tab(label    = "TAS diagram (anhydrous)",
                                    children = [ mageres_graph("mageres-tas-fig") ]),
                            dbc_tab(label    = "Cumulate log",
                                    children = [ mageres_graph("mageres-cumulate-fig") ]),
                            dbc_tab(label    = "Diagnostics",
                                    children = [
                                        dbc_tabs(id = "mageres-diagnostics-tabs", [
                                            dbc_tab(label    = "Conservation",
                                                    children = [ mageres_graph("mageres-diagnostics-fig") ]),
                                            dbc_tab(label    = "Vital signs",
                                                    children = [ mageres_graph("mageres-vital-signs-fig") ]),
                                            dbc_tab(label    = "Convection",
                                                    children = [ mageres_graph("mageres-convection-fig") ]),
                                            dbc_tab(label    = "Energy budget",
                                                    children = [ mageres_graph("mageres-energy-budget-fig") ]),
                                        ]),
                                    ]),
                        ]),
                    ]),
                    dbc_tab(tab_id = "mageres-tab-methodology", label = "Methodology", children = [
                        html_div(   dcc_markdown(MAGERES_METHODOLOGY_MD),
                                    style = Dict(   "padding"   => "16px 24px", "maxWidth" => "980px",
                                                    "textAlign" => "justify")),
                    ]),
                ]),
            ], width = 8),

        ]),

        dbc_offcanvas(
            [
                html_h1("Thermodynamics", style = Dict("textAlign" => "center", "font-size" => "120%")),
                mageres_labelled_row("Database", dcc_dropdown(  id        = "database-dropdown-mageres",
                                                                options   = dtb_dict,
                                                                value     = "ig",
                                                                clearable = false,
                                                                multi     = false)),
                html_hr(),
                html_h1("Magma", style = Dict("textAlign" => "center", "font-size" => "120%")),
                mageres_composition_row("magma", 5, MAGERES_TE_INJECTION_TEST),
                html_hr(),
                html_h1("Host rock", style = Dict("textAlign" => "center", "font-size" => "120%")),
                mageres_composition_row("host", 6, MAGERES_TE_HOST_TEST),
            ],
            id        = "mageres-bulk-canvas",
            title     = "MAGEMin Reservoir - bulk-rock compositions",
            is_open   = false,
            placement = "start",
            style     = Dict("width" => "40vw", "overflowY" => "auto",
                             "background-color" => "rgba(255, 255, 255, 1.0)"),
        ),

        dbc_offcanvas(
            [
                html_h1("Injected magma", style = Dict("textAlign" => "center", "font-size" => "120%")),
                mageres_composition_row("injection", 5, MAGERES_TE_INJECTION_TEST),
            ],
            id        = "mageres-injection-canvas",
            title     = "MAGEMin Reservoir - injection composition",
            is_open   = false,
            placement = "start",
            style     = Dict("width" => "40vw", "overflowY" => "auto",
                             "background-color" => "rgba(255, 255, 255, 1.0)"),
        ),
    ])
end
