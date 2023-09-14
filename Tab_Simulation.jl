function Tab_Simulation(db)
    html_div([
    # one column for the plots
        dbc_col([
                html_div("‎ "),
                # first row with 2 columns for plot added related buttons
                dbc_row([   
                    dbc_col([ 

                        #database
                        dbc_row([
                            dbc_col([ 
                                html_h1("Thermodynamic database", style = Dict("textAlign" => "center","font-size" => "140%")),
                            ]),
                            dbc_col([ 
                                dcc_dropdown(   id      = "database-dropdown",
                                                options = [
                                                    (label = "Metapelite (White et al., 2014)",         value = "mp"),
                                                    (label = "Metabasite (Green et al., 2016)",         value = "mb"),
                                                    (label = "Ultramafic (Tomlinson et al., 2021)",     value = "um"),
                                                    (label = "Igneous HP18 (Green et al., 2023)",       value = "ig"),
                                                    (label = "Igneous T21 (Green et al., 2023)",        value = "igd"),
                                                    (label = "Alkaline (Weller et al., 2023)",  value = "alk"),

                                                ],
                                                value="ig" ,
                                                multi   = false),
                            ]),
                        ]),

                        #diagram type
                        dbc_row([
                            dbc_col([ 
                                html_h1("Diagram type", style = Dict("textAlign" => "center","font-size" => "140%")),
                            ]),
                            dbc_col([ 
                                dcc_dropdown(   id      = "diagram-dropdown",
                                options = [
                                    (label = "P-T diagram",         value = "pt"),
                                    (label = "P-X diagram",         value = "px"),
                                    (label = "T-X diagram",         value = "tx"),
                                ],
                                value="pt" ,
                                multi   = false),
                            ]),
                        ]),

                        #solver
                        dbc_row([
                            dbc_col([ 
                                html_h1("Solver", style = Dict("textAlign" => "center","font-size" => "140%")),
                            ]),
                            dbc_col([ 
                                dcc_dropdown(   id      = "solver-dropdown",
                                options = [
                                    (label = "PGE",         value = "pge"),
                                    (label = "Legacy",      value = "lp"),
                                ],
                                value="pge" ,
                                multi   = false),
                            ]),
                        ]),

                        #buffer
                        dbc_row([
                            dbc_col([ 
                                html_h1("Buffer", style = Dict("textAlign" => "center","font-size" => "140%")),
                            ]),
                            dbc_col([ 
                                dcc_dropdown(   id      = "buffer-dropdown",
                                options = [
                                    (label = "no buffer",         value = "nob"),
                                    (label = "QFM",      value = "qfm"),
                                    (label = "MW",      value = "mw"), 
                                ],
                                value="nob" ,
                                multi   = false),
                            ]),
                        ]),

                        #refinement type
                        dbc_row([
                            dbc_col([ 
                                html_h1("Refinement type", style = Dict("textAlign" => "center","font-size" => "140%")),
                            ]),
                            dbc_col([ 
                                dcc_dropdown(   id      = "refinement-dropdown",
                                options = [
                                    (label = "Phases only",         value = "ph"),
                                    (label = "End-members",         value = "em"),
                                ],
                                value   = "ph", 
                                multi   = false),
                            ]),
                        ]),

                        #refinement levels 
                        dbc_row([
                            dbc_col([ 
                                html_h1("Refinement levels", style = Dict("textAlign" => "center","font-size" => "140%")),
                            ]),
                            dbc_col([ 
                                dcc_dropdown(   id      = "refinement-levels",
                                options = [
                                    (label = "2",         value = 2),
                                    (label = "3",         value = 3),
                                    (label = "4",         value = 4),
                                    (label = "5",         value = 5),
                                    (label = "6",         value = 6),
                                    (label = "7",         value = 7),
                                    (label = "8",         value = 8),
                                ],
                                value=2, 
                                multi   = false),
                            ]),
                        ]),

                        ], width=4), 

                        dbc_col([ 

                            dbc_row([
                                dbc_col([ 
                                    html_h1("Pressure range", style = Dict("textAlign" => "center","font-size" => "140%")),
                                ]),
                                dbc_col([ 
                                    dbc_row([
                                    dbc_col([ 
                                        html_h1("P min", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        dbc_input(
                                            id="pmin-id",
                                            type="number", 
                                            min=0.01, 
                                            max=100.01, 
                                            value=0.01   ),

                                    ]),
                                    dbc_col([ 
                                        html_h1("P step", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        dbc_input(
                                            id="pstep-id",
                                            type="number", 
                                            min=0.01, 
                                            max=100.01, 
                                            value=4.0   ),

                                    ]),
                                    dbc_col([ 
                                        html_h1("P max", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        dbc_input(
                                            id="pmax-id",
                                            type="number", 
                                            min=0.01, 
                                            max=100.01, 
                                            value=24.01   ),

                                    ]), 
                                    ]),
                                ]),
                            ]),

                            dbc_row([
                                dbc_col([ 
                                    html_h1("Temperature range", style = Dict("textAlign" => "center","font-size" => "140%")),
                                ]),
                                dbc_col([ 
                                    dbc_row([
                                    dbc_col([ 
                                            html_h1("T min", style = Dict("textAlign" => "center","font-size" => "100%")),
                                            dbc_input(
                                                id="tmin-id",
                                                type="number", 
                                                min=0.0, 
                                                max=2000.0, 
                                                value=800.0   ),

                                        ]),
                                        dbc_col([ 
                                            html_h1("T step", style = Dict("textAlign" => "center","font-size" => "100%")),
                                            dbc_input(
                                                id="tstep-id",
                                                type="number", 
                                                min=0.0, 
                                                max=2000.0, 
                                                value=100.0   ),

                                        ]),
                                        dbc_col([ 
                                            html_h1("T max", style = Dict("textAlign" => "center","font-size" => "100%")),
                                            dbc_input(
                                                id="tmax-id",
                                                type="number", 
                                                min=0.0, 
                                                max=2000.0,
                                                value=1400.0   ),

                                        ]),
                                    ]),
                                ]),
                            ]),

                        ], width=5),
                    ], justify="left"),


                    html_div("‎ "),
                    dbc_row([ 

                            dbc_col([diagram_plot(db)], width=10),
                            dbc_col([  


                                        dbc_row([dbc_button("Display options",id="button-display-options"),
                                        dbc_collapse(
                                            dbc_card(dbc_cardbody([

                                                dbc_col([
                                                    dcc_dropdown(   id          = "colormaps_cross",
                                                                    options     = [String.(keys(colormaps))...],
                                                                    value       = "roma",
                                                                    clearable   = false,
                                                                    placeholder = "Colormap")
                                                ]), 

                                                ])
                                            ),
                                            id="collapse",
                                            is_open=false,
                                        ),

                                        dbc_button("Grid refinement",id="button-refinement"),
                                        dbc_collapse(
                                            dbc_card(dbc_cardbody([

                                                ])),
                                                id="collapse-refinement",
                                                is_open=false,
                                        ),
     
                            ])




                            ]),

                ], justify="left"),

                        dbc_row([       dbc_col([
                    
                        dbc_button("Time Period",id="button-timeperiod",className="d-grid col-12 mx-auto"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                dbc_col([
                                    dcc_rangeslider(
                                        id = "period-slider",
                                        min = 2022,
                                        max = 2024,
                                        step = 1,
                                        value=[2022, 2023, 2024],
                                        allowCross=false,
                                        tooltip=attr(placement="bottom"),
                                        marks = Dict([i => ("$i") for i in [2022, 2023, 2024]])
                                    )
                                            # dcc_slider(min=0.0,max=1.0,marks=Dict(0=>"2023",0.5=>"year",1=>"2024"),value=1.0, id = "screenshot-opacity", tooltip=attr(placement="bottom")),    
                                        ]),
                                ])),
                                id="collapse-timeperiod",
                                is_open=false,
                                )
                                ], width=10), 
                        dbc_col([ ])

                ], justify="center"),

                html_div("‎ "),
                html_div("‎ "),
                

                ], width=16)
    ])
end