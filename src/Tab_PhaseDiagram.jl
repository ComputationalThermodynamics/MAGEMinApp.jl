function Tab_PhaseDiagram()
    html_div([
    # one column for the plots
        dbc_col([
            html_div("‎ "),
            dbc_row([ 

                    dbc_col([
                        dbc_row([
                            dbc_col([    
                                dbc_buttongroup([
                                    dbc_button("Export ρ for LaMEM", id="export-to-lamem", color="light",  n_clicks=0,
                                    style       = Dict( "textAlign"     => "center",
                                                        "font-size"     => "100%",
                                                        "border"        =>"1px grey solid")), 
                                    dbc_button("Export for GeoModel", id="export-geomodel", color="light",  n_clicks=0,
                                    style       = Dict( "textAlign"     => "center",
                                                        "font-size"     => "100%",
                                                        "border"        =>"1px grey solid")), 
                                ]),
                            ], width=3),

                            dbc_col([    
                                dcc_textarea(
                                    id          ="system-chemistry-id",
                                    value       = "",
                                    readOnly    = true,
                                    disabled    = true,
                                    draggable   = false,
                                    style       = Dict("height" => "26px","resize"=> "none","textAlign" => "center","font-size" => "100%", "width"=> "100%",),
                                ),
                            ], width=6),

                            dbc_col([  
                                dcc_clipboard(
                                    target_id="system-chemistry-id",
                                    title="copy",
                                    style=Dict(
                                        "display" => "inline-block",
                                        "fontSize"=> 20,
                                        "verticalAlign"=> "top",
                                    ),
                                ),
                                ], width=1),
    
                            dbc_col([
                                dbc_button(
                                    "Refine uniformly", id="uni-refine-pb-button", color="light", className="me-2", n_clicks=0,
                                    style       = Dict( "textAlign"     => "center",
                                                        "font-size"     => "100%",
                                                        "border"        => "1px grey solid",
                                                        "width"         => "100%" )), 
                                dbc_button(
                                    "Refine phase boundaries", id="refine-pb-button", color="light", className="me-2", n_clicks=0,
                                    style       = Dict( "textAlign"     => "center",
                                                        "font-size"     => "100%",
                                                        "border"        => "1px grey solid",
                                                        "width"         => "100%" )), 
                            ], width=2), 
                            ]), 
                        dbc_row([
                            dcc_download(id="download-lamem-in"),  
                            dcc_download(id="download-geomodel-in"), 
                            dbc_alert(
                                "Density diagram saved for LaMEM",
                                id      ="export-to-lamem-text",
                                is_open =false,
                                duration=4000,
                            ),
                            dbc_alert(
                                "Phase diagrams for LaMEM have to be PT",
                                color="danger",
                                id      ="export-to-lamem-text-failed",
                                is_open =false,
                                duration=4000,
                            ),
                            dbc_alert(
                                "Density diagram saved for LaMEM",
                                id      ="export-geomodel-text",
                                is_open =false,
                                duration=4000,
                            ),
                            dbc_alert(
                                "Phase diagrams for LaMEM have to be PT",
                                color="danger",
                                id      ="export-geomodel-text-failed",
                                is_open =false,
                                duration=4000,
                            ),
                        ]),    
                        # html_hr(),  
                        html_div("‎ "), 

                        html_div([
                            dbc_input(
                                id      = "load-state-id",
                                type    = "number", 
                                min     = -1e50, 
                                max     =  1e50, 
                                value   =  1.0  ),
                        ], style = Dict("display" => "none"), id      = "load-state-display-id"),

                        dbc_row([
                            diagram_legend()
                        ]),
                        dbc_row([
                            diagram_plot()
                        ]),
                    ], width=9),
                    dbc_col([
                        
                        dbc_tabs([
                            dbc_tab(label="Informations", children=[
                        dbc_row([

                        # dbc_button("Phase diagram information",id="infos-phase-diagram"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    dbc_row([
                                        dbc_card([
                                            dcc_markdown(   id          = "computation-info-id", 
                                                            children    = "",
                                                            style       = Dict("white-space" => "pre"))
                                        ])
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "select-pie-unit",
                                            options = [
                                                (label = "mol%",                value = 1),
                                                (label = "wt%",                 value = 2),
                                                (label = "vol%",                value = 3), 
                                            ],
                                            value       = 1,
                                            style       = Dict("border" => "none"),
                                            clearable   = false,
                                            multi       = false),
                                        ], width=3),
                                    ]),

                                    dbc_row([
                                        dbc_col([ 
                                            pie_plot(),
                                        ]#=, width=6=#),
                                    ]),

                                    html_div([
                                    ], style = Dict("display" => "none"), id      = "test-show-id"),

                                    html_div("‎ "), 
                                    html_div([
                                        dbc_row([
                                            dbc_col([ 
                                                
                                                html_h3(id="ph-comp-title", "Mineral composition", style = Dict("textAlign" => "center","font-size" => "140%", "marginTop" => 8)),  # Title with an id
                                            ], width=11),
                                            dbc_col([ 
                                                    dcc_clipboard(
                                                        target_id   = "table-phase-composition",
                                                        title       = "copy",
                                                        style       =  Dict(
                                                            "display"       => "inline-block",
                                                            "fontSize"      => 20,
                                                            "verticalAlign" => "top",
                                                    ),
                                                ),
                                            ], width=1),
                                        ]),
                                        dbc_row([
                                            dash_datatable(
                                                id="table-phase-composition",
                                                columns=(  [    Dict("id" =>  "oxide",  "name"  =>  "oxide",    "editable" => false),
                                                                Dict("id" =>  "mol%",   "name"  =>  "mol%",     "editable" => false),
                                                                Dict("id" =>  "wt%",    "name"  =>  "wt%",      "editable" => false),
                                                                Dict("id" =>  "apfu",   "name"  =>  "apfu",     "editable" => false)
                                                                ]
                                                ),
                                                data            = [],
                                                # row_selectable  = "single",
                                                style_cell      = Dict("fontSize" => "140%", "textAlign" => "center", "padding" => "0px"),
                                                style_header    = (fontWeight="bold"),
                                                
                                            ),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "disp-test-id"),
                                    
                                    # SAVE POINTS INFORMATION
                                    html_hr(),
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Save point", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ], width=3),
                                        dbc_col([ 
                                            dbc_input(
                                                id      = "Filename-eq-id",
                                                type    = "text", 
                                                style   = Dict("textAlign" => "center") ,
                                                value   = "filename"   ),     
                                        ], width=4),
                                        dbc_col([    
                                            dbc_button("Table", id="save-eq-table-button", color="light",  n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"1px grey solid")), 
                                            dcc_download(id="download-table-text"),  
                                        ]),
                                        dbc_col([    
                                            dbc_button("text", id="save-eq-button", color="light",  n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"1px grey solid")), 
                                            dcc_download(id="download-text"),  
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_alert(
                                            "Successfully saved data point information",
                                            id      ="data-eq-save",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                        dbc_alert(
                                            "Provide a valid filename (without extension)",
                                            color="danger",
                                            id      ="data-eq-save-failed",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                        dbc_alert(
                                            "Successfully saved data point information",
                                            id      ="data-eq-table-save",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                        dbc_alert(
                                            "Provide a valid filename (without extension)",
                                            color="danger",
                                            id      ="data-eq-save-table-failed",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                    ]),
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Save all", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ], width=3),
                                        dbc_col([ 
                                            dbc_input(
                                                id      = "Filename-all-id",
                                                type    = "text", 
                                                style   = Dict("textAlign" => "center") ,
                                                value   = "filename"   ),     
                                        ], width=4),
                                        dbc_col([    
                                            dbc_button("csv file", id="save-all-table-button", color="light",  n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"1px grey solid")), 
                                            dbc_tooltip([
                                                html_div("Saving all data takes time and depends on the number of points"),
                                                html_div("Output path and progress are displayed in the Julia terminal")],target="save-all-table-button"),
                                            dcc_download(id="download-all-table-text"),  
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_alert(
                                            "Successfully saved all data points information",
                                            id      ="data-all-table-save",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                        dbc_alert(
                                            "Provide a valid filename (without extension)",
                                            color="danger",
                                            id      ="data-all-save-table-failed",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                    ]),
                                    # html_div("‎ "),

                                    dbc_row([
                                        dbc_col([
                                            html_h1("Export references", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 0)),    
                                        ], width=3),
                                        dbc_col([ 
                                            dbc_input(
                                                id      = "export-citation-id",
                                                type    = "text", 
                                                style   = Dict("textAlign" => "center") ,
                                                value   = "filename"   ),     
                                        ], width=4),
                                        dbc_col([    
                                            dbc_button("bibtex file", id="export-citation-button", color="light",  n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"1px grey solid")), 
                                            dbc_tooltip([
                                                html_div("Saving list of citation for the computed phase diagram"),
                                                html_div("Output path and progress are displayed in the Julia terminal")],target="export-citation-button"),
                                        ]),
                                    ]),


                                    html_hr(),

                                    dbc_row([   
                                        dbc_button("Display point snippet for MAGEMin_C",id="button-export-magemin_c",color="light"),
                                        dbc_collapse(
                                            dbc_card(dbc_cardbody([
                                                dcc_textarea(
                                                    id          = "magemin_c-snippet",
                                                    value       = "",
                                                    readOnly    = true,
                                                    disabled    = true,
                                                    draggable   = false,
                                                    style       = Dict("textAlign" => "left","font-size" => "100%", "width"=> "100%", "resize"=> "auto","height" => "160px")
                                                ),
                                                dcc_clipboard(
                                                    target_id="magemin_c-snippet",
                                                    title="copy",
                                                    style=Dict(
                                                        "display" => "inline-block",
                                                        "fontSize"=> 20,
                                                        "verticalAlign"=> "top",
                                                    ),
                                                ),
                                            ])),
                                            id="collapse-export-magemin_c",
                                            is_open=false,
                                        ),
                                    ]),
            
                        
                                ])),
                                id="collapse-infos-phase-diagram",
                                is_open=true,
                        ),
                        # html_div("‎ "),
                        ]),
                            ]),
                            dbc_tab(label="Display options", children=[
                                # dbc_button("Display options",id="button-display-options"),
                                dbc_collapse(
                                    dbc_card(dbc_cardbody([
                                    # html_div("‎ "),
                                    html_h1("Select field to display", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    html_hr(),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Field", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([
                                            dcc_dropdown(   id      = "fields-dropdown",
                                                            options = [
                                                                (label = "Hash",                    value = "Hash"),
                                                                (label = "Variance",                value = "Variance"),
                                                                (label = "Number of stable phases", value = "#Phases"),
                                                                (label = "G system",                value = "G_system"),
                                                                (label = "Entropy",                 value = "entropy"),
                                                                (label = "Enthalpy",                value = "enthalpy"),
                                                                (label = "Specific cp",             value = "s_cp"),
                                                                (label = "log10(fO2)",              value = "fO2"),
                                                                (label = "log10(dQFM)",             value = "dQFM"),
                                                                (label = "H2O activity",            value = "aH2O"),
                                                                (label = "FeO activity",            value = "aFeO"),
                                                                (label = "MgO activity",            value = "aMgO"),
                                                                (label = "Al2O3 activity",          value = "aAl2O3"),
                                                                (label = "SiO2 activity",           value = "aSiO2"),
                                                                (label = "TiO2 activity",           value = "aTiO2"),
                                                                (label = "ρ_system",                value = "rho"),
                                                                (label = "ρ_solid",                 value = "rho_S"),
                                                                (label = "ρ_melt",                  value = "rho_M"),
                                                                (label = "Δρ",                      value = "Delta_rho"),
                                                                (label = "Solid fraction",          value = "frac_S"),
                                                                (label = "Melt fraction",           value = "frac_M"),                                                            
                                                                (label = "Vp",                      value = "Vp"),
                                                                (label = "Vs",                      value = "Vs"),                                                            
                                                                (label = "Vp_S",                    value = "Vp_S"),
                                                                (label = "Vs_S",                    value = "Vs_S"),
                                                                (label = "Bulk residual (norm)",    value = "bulk_res_norm"),
                                                                (label = "Computation time (ms)",   value = "time_ms"),
                                                                (label = "Status",                  value = "status"),
        
                                                            ],
                                                            value="Variance" ,
                                                            clearable   = false,
                                                            multi       = false),
                                        ]), 
                                    ]),
                                    html_div("‎ "),
                                    html_h1("Diagram options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    html_hr(),
        
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Show reaction lines", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=5),
                                            dbc_col([
                                                dcc_dropdown(   id          = "show-grid",
                                                                options     =  ["true","false"],
                                                                value       = "true" ,
                                                                clearable   =  false,
                                                                multi       =  false),
                                            ]), 
                                        ]),
        
        
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Show stable phases", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=5),
                                            dbc_col([
                                                dcc_dropdown(   id          = "show-lbl-id",
                                                                options     =  ["true","false"],
                                                                value       = "true" ,
                                                                clearable   =  false,
                                                                multi       =  false),
                                            ]), 
                                        ]),
        
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Show grid", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=5),
                                            dbc_col([
                                                dcc_dropdown(   id          = "show-full-grid",
                                                                options     =  ["true","false"],
                                                                value       = "false" ,
                                                                clearable   =  false,
                                                                multi       =  false),
                                            ]), 
                                        ]),
                                        html_div("‎ "),
                                        html_h1("Color options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        html_hr(),
                                        dbc_row([
                                                dbc_col([ 
                                                    html_h1("Colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ], width=5),
                                                dbc_col([
                                                    dcc_dropdown(   id          = "colormaps_cross",
                                                                    options     = ["blackbody","Blues","cividis","Greens","Greys","hot","jet","RdBu","Reds","viridis","YlGnBu","YlOrRd"],
                                                                    value       = "Blues",
                                                                    clearable   = false,
                                                                    placeholder = "Colormap")
                                                ]), 
                                            ]),
        
                                            html_div("‎ "),
                                            dbc_row([
                                                dbc_col([ 
                                                ], width=5),
                                                dbc_col([ 
                                                    html_h1("min", style = Dict("textAlign" => "center","font-size" => "100%")),
                                                ]),
                                                dbc_col([ 
                                                    html_h1("max", style = Dict("textAlign" => "center","font-size" => "100%")),
                                                ]),
                                            ]),
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Value range", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 8)),
                                                ], width=5),
                                                dbc_col([ 
                                                    dbc_row([
                                                    dbc_col([ 
                                                            dbc_input(
                                                                id      = "min-color-id",
                                                                type    = "number", 
                                                                min     = -1e50, 
                                                                max     = 1e50, 
                                                                value   = 800.0,
                                                                debounce = true   ),
                                                        ]),
                                                        dbc_col([ 
                                                            dbc_input(
                                                                id      = "max-color-id",
                                                                type    = "number", 
                                                                min     = -1e50, 
                                                                max     = 1e50, 
                                                                value   = 1400.0,
                                                                debounce = true   ),
                                                        ]),
                                                    ]),
                                                ]),
                                            ]),
        
                                            html_div("‎ "),
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Colormap range", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ], width=5),
                                                dbc_col([
                                                    dcc_rangeslider(
                                                        id="range-slider-color",
                                                        count=1,
                                                        min=1,
                                                        max=9,
                                                        step=1,
                                                        value=[1, 9]
                                                    ),
                                                ]), 
                                            ]),
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Set min to white", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=5),
                                            dbc_col([
                                                dcc_dropdown(   id          = "set-min-white",
                                                                options     = ["true","false"],
                                                                value       = "false",
                                                                clearable   = false)
                                            ]), 
                                        ]),
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Reverse colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ], width=5),
                                                dbc_col([
                                                    dcc_dropdown(   id          = "reverse-colormap",
                                                                    options     = ["true","false"],
                                                                    value       = "false",
                                                                    clearable   = false)
                                                ]), 
                                            ]),
        
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Smooth colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ], width=5),
                                                dbc_col([
                                                    dcc_dropdown(   id          = "smooth-colormap",
                                                                    options     = ["fast","best",false],
                                                                    value       = "fast",
                                                                    clearable   = false)
                                                ]), 
                                            ]),
        
                                        ])
                                    ),
                                    id="collapse",
                                    is_open=true,
                                ),
        
        
                                ]),
                        dbc_tab(label="Isopleths", children=[
                        # dbc_button("Display isopleths",id="button-isopleths"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                html_h1("Selection", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                html_hr(),
                                dbc_row([
                                    dbc_col([
                                        html_h1("Isopleth type", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                    ]),
                                    dbc_col([
                                        html_div([
                                            dcc_dropdown(   id      = "phase-dropdown",
                                            options = [
                                                (label = "Pure phase",          value = "pp"),
                                                (label = "Solution phase",      value = "ss"),
                                                (label = "Other",               value = "of"),
                                            ],
                                            value       = "pp",
                                            clearable   = false,
                                            multi       = false),
                                        ], style = Dict("display" => "block"), id      = "phase-1-id"),

                                    ]),
                                ]),
                                    html_div([
                                        dbc_row([

                                            dbc_col([
                                                html_h1("Phase", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([
                                                dcc_dropdown(   id      = "ss-dropdown",
                                                options = [],
                                                value       = 0,
                                                clearable   = false,
                                                multi       = false),
                                            ]),

                                        ]),
                                    ], style = Dict("display" => "none"), id      = "ss-1-id"),

                                    html_div([
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Field", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([
                                                dcc_dropdown(   id      = "other-dropdown",
                                                options = [
                                                    (label = "Mode",      value = "mode"),
                                                    (label = "Endmember mode",  value = "emMode"),
                                                    (label = "Mg#",             value = "MgNum"),
                                                    (label = "Calculator",      value = "calc"),
                                                    ],
                                                value       = "mode",
                                                clearable   = false,
                                                multi       = false),
                                            ]),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "other-1-id"),

                                    html_div([
                                        dbc_row([

                                            dbc_col([
                                                html_h1("Unit", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([
                                                dcc_dropdown(   id      = "sys-unit-isopleth-dropdown",
                                                options = [ (label = "mol",    value = "mol"),
                                                            (label = "wt",     value = "wt")
                                                            ],
                                                value       = "mol",
                                                clearable   = false,
                                                multi       = false),
                                            ]),

                                        ]),
                                    ], style = Dict("display" => "none"), id      = "sys-unit-isopleth-id"),

                                    html_div([
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Calculator (apfu)", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ]),
                                            dbc_col([
                                                dbc_input(
                                                    id      = "input-calc-id",
                                                    type    = "text", 
                                                    value   = "Mg / (Mg + Fe)"   ),
                                            ]), 
                                        ]),
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Custom name", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ]),
                                            dbc_col([
                                                dbc_input(
                                                    id      = "input-cust-id",
                                                    type    = "text", 
                                                    value   = "none"   ),
                                            ]), 
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "calc-1-id"),

                                    html_div([
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Endmember", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([
                                                dcc_dropdown(   id      = "em-dropdown",
                                                options = ["none"],
                                                value       = 0,
                                                clearable   = false,
                                                multi       = false),
                                            ]),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "em-1-id"),

                                    html_div([
                                        dbc_row([
                                            
                                            dbc_col([
                                                html_h1("Field", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([
                                                dcc_dropdown(   id      = "of-dropdown",
                                                options = [
                                                    (label = "G system",                value = "G_system"),
                                                    (label = "Entropy",                 value = "entropy"),
                                                    (label = "Enthalpy",                value = "enthalpy"),
                                                    (label = "Specific cp",             value = "s_cp"),
                                                    (label = "log10(fO2)",              value = "fO2"),
                                                    (label = "log10(dQFM)",             value = "dQFM"),
                                                    (label = "H2O activity",            value = "aH2O"),
                                                    (label = "FeO activity",            value = "aFeO"),
                                                    (label = "MgO activity",            value = "aMgO"),
                                                    (label = "Al2O3 activity",          value = "aAl2O3"),
                                                    (label = "SiO2 activity",           value = "aSiO2"),
                                                    (label = "TiO2 activity",           value = "aTiO2"),
                                                    (label = "ρ_system",                value = "rho"),
                                                    (label = "ρ_solid",                 value = "rho_S"),
                                                    (label = "ρ_melt",                  value = "rho_M"),
                                                    (label = "Solid fraction",          value = "frac_S"),
                                                    (label = "Melt fraction",           value = "frac_M"),                                                            
                                                    (label = "Vp",                      value = "Vp"),
                                                    (label = "Vs",                      value = "Vs"),                                                            
                                                    (label = "Vp_S",                    value = "Vp_S"),
                                                    (label = "Vs_S",                    value = "Vs_S"),
                                                    
                                                    
                                                ],
                                                value       = "G_system",
                                                clearable   = false,
                                                multi       = false),
                                            ]),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "of-1-id"),



                                    html_div("‎ "),
                                    html_h1("Range", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    html_hr(),
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Min", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                                id="iso-min-id",
                                                type="number", 
                                                min=-1e8, 
                                                max= 1e8, 
                                                value=0.0   ),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Step", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]), 
                                        dbc_col([ 
                                            dbc_input(
                                                id="iso-step-id",
                                                type="number", 
                                                min=-1e8, 
                                                max= 1e8, 
                                                value=0.1   ),
                                        ]),
                                    ]),
                                    dbc_row([  
                                        dbc_col([
                                            html_h1("Max", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                                id="iso-max-id",
                                                type="number", 
                                                min=-1e8, 
                                                max= 1e8, 
                                                value=1.0   ),
                                        ]),
                                    ]),
                                    html_div("‎ "),
                                    html_h1("Plotting options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    html_hr(),
                                    dbc_row([    
                                        dbc_col([
                                            html_h1("Line style", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "line-style-dropdown",
                                            options = [
                                                (label = "Solid",                   value = "solid"),
                                                (label = "Dot",                     value = "dot"),
                                                (label = "Dash",                    value = "dash"),
                                                (label = "Longdash",                value = "longdash"),
                                                (label = "Dashdot",                 value = "dashdot"),
                                                (label = "Longdashdot",             value = "longdashdot"),
                                            ],
                                            value       = "solid",
                                            clearable   = false,
                                            multi       = false),
                                        ]),
                                    ]),
                                    dbc_row([    
                                        dbc_col([
                                            html_h1("Line width", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                            id      = "iso-line-width-id",
                                            type    = "number", 
                                            min     = 0,  
                                            max     = 10,  
                                            value   = 1   ),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Color", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                                type    = "color",
                                                id      = "colorpicker_isoL",
                                                value   = "#000000",
                                                style   = Dict("width" => 75, "height" => 25),
                                            ),
                                        ]),

                                    ]),
                                    dbc_row([    
                                        dbc_col([
                                            html_h1("Label size", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                            id      = "iso-text-size-id",
                                            type    = "number", 
                                            min     = 6,  
                                            max     = 20,  
                                            value   = 10   ),
                                        ]),
                                    ]),
                                    html_div("‎ "),
                                    dbc_row([
                                        dbc_button("Add",id="button-add-isopleth", color="light",
                                        style       = Dict( "textAlign"     => "center",
                                                            "font-size"     => "100%",
                                                            "border"        =>"1px lightgray solid")),
                                    ]),  

                                    html_div("‎ "),
                                    html_h1("Isopleth list", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    html_hr(),
                                    dbc_row([

                                       dbc_col([
                                            html_h1("Displayed", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            dbc_row([
                                                html_div([
                                                    dcc_dropdown(   id      = "isopleth-dropdown",
                                                    options = [],
                                                    value       = nothing,
                                                    clearable   = false,
                                                    multi       = false),
                                                ],  style       = Dict("display" => "block"), id      = "isopleth-1-id"),
                                            ]),

                                            html_div("‎ "),
                                            dbc_row([
                                            dbc_button("Hide",id="button-hide-isopleth", color="light",
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")),
                                            ]), 
                                            dbc_row([
                                                dbc_button("Hide all",id="button-hide-all-isopleth", color="light",
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")),  
                                            ]),
                                            html_div("‎ "),
                                            dbc_row([
                                                dbc_button("Remove",id="button-remove-isopleth", color="light",
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")), 
                                            ]), 
                                            dbc_row([
                                                dbc_button("Remove all",id="button-remove-all-isopleth", color="light",
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")),
                                            ]), 
 

                                        ], width=6),

                                        dbc_col([
                                            html_h1("Hidden", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            dbc_row([
                                                html_div([
                                                    dcc_dropdown(   id      = "hidden-isopleth-dropdown",
                                                    options = [],
                                                    value       = nothing,
                                                    clearable   = false,
                                                    multi       = false),
                                                ],  style       = Dict("display" => "block"), id      = "hidden-isopleth-1-id"),
                                            ]),

                                            html_div("‎ "),
                                            dbc_row([
                                                dbc_button("Show",id="button-show-isopleth", color="light",
                                                    style       = Dict( "textAlign"     => "center",
                                                                        "font-size"     => "100%",
                                                                        "border"        =>"1px lightgray solid")),
                                            ]),
                                            dbc_row([
                                                dbc_button("Show all",id="button-show-all-isopleth", color="light",
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")), 
                                            ]),

                                        ], width=6),

                                    ]),

                                ])),
                                id="collapse-isopleths",
                                is_open=true,
                        ),
                        # html_div("‎ "),
                        ]#=, className="custom-tab-label"=#),

                    
                    ]),

                    ], width=3),

                ], justify="left"),

            ], width=12)
    ])
end