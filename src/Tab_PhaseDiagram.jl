function Tab_PhaseDiagram()
    html_div([
    # one column for the plots
        dbc_col([
            # html_div("‎ "),
            dbc_row([ 

                    dbc_col([diagram_plot()], width=7),
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
                                                                "border"        =>"1px lightgray solid")), 
                                    ]),
                                ])),
                                id="collapse-refinement",
                                is_open=true,
                        ),

                        dbc_button("Phase diagram information",id="infos-phase-diagram"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    # html_div("‎ "),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Number of computed points", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ], width=6),
                                        dbc_col([ 
                                                dbc_input(
                                                id      = "npoints-id",
                                                type    = "number", 
                                                value   = 0,
                                                disabled = true   ),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Average minimization time [ms]", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ], width=6),
                                        dbc_col([ 
                                                dbc_input(
                                                id      = "meant-id",
                                                type    = "number", 
                                                value   = 0,
                                                disabled = true   ),
                                        ]),
                                        dbc_tooltip("This is the average minimization time per point: n_points/time_per_point",target="meant-id"),
                                    ]),
                                    html_div("‎ "),
                                    dbc_row([
                                        dcc_textarea(
                                            id="click-data",
                                            value       = "",
                                            readOnly    = true,
                                            disabled    = true,
                                            draggable   = false,
                                            style       = Dict( "textAlign" => "left",
                                                                "font-size" => "110%",
                                                                "width"     => "100%",
                                                                "height"    => "160px",
                                                                "resize"    => "none")
                                        ),
                                    ]),
                                    html_div("‎ "),

                                    dbc_row([
                                        dbc_col([ 
                                            dbc_input(
                                                id      = "Filename-eq-id",
                                                type    = "text", 
                                                style   = Dict("textAlign" => "center") ,
                                                value   = "... filename ..."   ),     
                                        ], width=6),
                                        dbc_col([    
                                            dbc_button(
                                                "Save equilibrium data", id="save-eq-button", color="light",  n_clicks=0,
                                            ),
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
                                        # html_div(id="data-eq-save"),
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            dbc_input(
                                                id      = "Filename-all-id",
                                                type    = "text", 
                                                style   = Dict("textAlign" => "center") ,
                                                value   = "... filename ..."   ),     
                                        ], width=6),
                                        dbc_col([    
                                            dbc_button(
                                                "Save all data points", id="save-all-button", color="light",  n_clicks=0,
                                            ),
                                            dcc_download(id="download-all-text"),  
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_alert(
                                            "Successfully saved all data points information",
                                            id      ="data-all-save",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                        dbc_alert(
                                            "Provide a valid filename (without extension)",
                                            color="danger",
                                            id      ="data-all-save-failed",
                                            is_open =false,
                                            duration=4000,
                                        ),
                                        # html_div(id="data-all-save"),
                                    ]),

                        
                                ])),
                                id="collapse-infos-phase-diagram",
                                is_open=true,
                        ),


                        dbc_button("Display options",id="button-display-options"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Grid options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 0)),
                                    ], width=5),
                                    dbc_col([ 
                                        dcc_checklist(
                                            id      ="show-grid",
                                            options = [
                                                Dict("label" => " Show grid", "value" => "GRID"),
                                            ],
                                            value   = [""],
                                            inline  = true,
                                        ),
                                    ], width=7),
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
                                                            (label = "log10(fO2)",              value = "fO2"),
                                                            (label = "H2O activity",            value = "aH2O"),
                                                            (label = "SiO2 activity",           value = "aSiO2"),
                                                            (label = "TiO2 activity",           value = "aTiO2"),
                                                            (label = "ρ_system",                value = "rho"),
                                                            (label = "ρ_solid",                 value = "rho_S"),
                                                            (label = "ρ_melt",                  value = "rho_M"),
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
                    dbc_col([
                        dbc_row([

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
                                                    (label = "log10(fO2)",              value = "fO2"),
                                                    (label = "H2O activity",            value = "aH2O"),
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
                                is_open=true,
                        ),

                        ]),
                    ], width=2),

                ], justify="left"),

            ], width=12)
    ])
end