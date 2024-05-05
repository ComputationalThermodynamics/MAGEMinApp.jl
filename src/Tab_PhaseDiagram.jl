function Tab_PhaseDiagram()
    html_div([
    # one column for the plots
        dbc_col([
            # html_div("‎ "),
            dbc_row([ 

                    dbc_col([diagram_plot()], width=9),
                    dbc_col([  
                        dbc_row([

                        dbc_button("Grid refinement",id="button-refinement"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    dbc_row([
                                        dbc_button(
                                            "Refine phase boundaries", id="refine-pb-button", color="light", className="me-2", n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"2px grey solid")), 
                                    ]),
                                ])),
                                id="collapse-refinement",
                                is_open=true,
                        ),
                        html_div("‎ "),
                        dbc_button("Phase diagram information",id="infos-phase-diagram"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    # html_div("‎ "),
                                    dbc_row([
                                        dbc_card([
                                            dcc_markdown(   id          = "computation-info-id", 
                                                            children    = "",
                                                            style       = Dict("white-space" => "pre"))
                                        ])
                                    ]),

                                    html_div("‎ "),
                                    dbc_row([
                                        dbc_col([ 
                                            dbc_card([
                                            dcc_markdown(   id          = "click-data-left", 
                                                            children    = "",
                                                            style       = Dict("white-space" => "pre"))
                                            ])
                                        ], width=6),
                                        dbc_col([ 
                                            dbc_card([
                                            dcc_markdown(   id          = "click-data-right", 
                                                            children    = "",
                                                            style       = Dict("white-space" => "pre"))
                                            ])
                                        ], width=3),
                                        dbc_col([ 
                                            dbc_card([
                                            dcc_markdown(   id          = "click-data-bottom", 
                                                            children    = "",
                                                            style       = Dict("white-space" => "pre"))
                                            ])
                                        ], width=3),
                                    ],className="g-0"),
  
                                    html_div("‎ "),

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
                                                                "border"        =>"2px grey solid")), 
                                            dcc_download(id="download-table-text"),  
                                        ]),
                                        dbc_col([    
                                            dbc_button("Formatted", id="save-eq-button", color="light",  n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"2px grey solid")), 
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
                                                                "border"        =>"2px grey solid")), 
                                            dbc_tooltip([
                                                html_div("Saving all data takes time and depends on the number of points"),
                                                html_div("Output path and progress are displayed in the Julia terminal")],target="save-all-table-button"),
                                            dcc_download(id="download-all-table-text"),  
                                        ]),
                                    ]),

                                    html_div("‎ "),
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
                                                                "border"        =>"2px grey solid")), 
                                            dbc_tooltip([
                                                html_div("Saving list of citation for the computed phase diagram"),
                                                html_div("Output path and progress are displayed in the Julia terminal")],target="export-citation-button"),
                                        ]),
                                    ]),

                                    dbc_row([
                                        dbc_alert(
                                            "Successfully saved all data points information",
                                            id      ="export-citation-save",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                        dbc_alert(
                                            "Provide a valid filename (without extension)",
                                            color="danger",
                                            id      ="export-citation-failed",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                    ]),

                        
                                ])),
                                id="collapse-infos-phase-diagram",
                                is_open=true,
                        ),
                        html_div("‎ "),
                        dbc_button("Display isopleths",id="button-isopleths"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                html_h1("Selection", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
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
                                                html_h1("Endmember", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([
                                                dcc_dropdown(   id      = "em-dropdown",
                                                options = [],
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
                                                ],
                                                value       = "G_system",
                                                clearable   = false,
                                                multi       = false),
                                            ]),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "of-1-id"),



                                    html_div("‎ "),
                                    html_h1("Range", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    dbc_row([
                                        dbc_col([
                                            html_h1("Min", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                                id="iso-min-id",
                                                type="number", 
                                                min=-2.0, 
                                                max= 2.0, 
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
                                                min= 0.0, 
                                                max= 2.0, 
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
                                                min=-2.0, 
                                                max= 2.0, 
                                                value=1.0   ),
                                        ]),
                                    ]),
                                    html_div("‎ "),
                                    html_h1("Plotting options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
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
                                    html_h1("Isopleth list", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    dbc_row([

                                       dbc_col([
                                            dbc_row([
                                                dbc_button("Add",id="button-add-isopleth", color="light",
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")),
                                            ]),  
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
                                            html_div("‎ "),
                                            dbc_row([
                                                dbc_button("Hide all",id="button-hide-all-isopleth", color="light",
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
                                       ]),
                                       dbc_col([
                                            dbc_row([
                                                html_div([
                                                    dcc_dropdown(   id      = "isopleth-dropdown",
                                                    options = [],
                                                    value       = nothing,
                                                    clearable   = false,
                                                    multi       = false),
                                                ],  style = Dict("display" => "block"), id      = "isopleth-1-id"),
                                            ]),

                                        ]),

                                    ]),

                                ])),
                                id="collapse-isopleths",
                                is_open=false,
                        ),
                        html_div("‎ "),
                        dbc_button("Display options",id="button-display-options"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([

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
                                                            (label = "Bulk residual (norm)",    value = "bulk_res_norm"),
                                                            (label = "Computation time (ms)",   value = "time_ms"),
                                                            (label = "Status",                  value = "status"),

                                                        ],
                                                        value="Variance" ,
                                                        clearable   = false,
                                                        multi       = false),
                                    ]), 
                                ]),

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
                                            html_h1("Reverse colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([
                                            dcc_dropdown(   id          = "reverse-colormap",
                                                            options     = ["true","false"],
                                                            value       = "false",
                                                            clearable   = false)
                                        ]), 
                                    ]),

                                ])
                            ),
                            id="collapse",
                            is_open=true,
                        ),



                    ])
                    ], width=3),

                ], justify="left"),

            ], width=12)
    ])
end