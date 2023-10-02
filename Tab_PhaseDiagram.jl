function Tab_PhaseDiagram()
    html_div([
    # one column for the plots
        dbc_col([
            html_div("‎ "),
            dbc_row([ 

                    dbc_col([diagram_plot()], width=9),
                    dbc_col([  
                        dbc_row([dbc_button("Display options",id="button-display-options"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([

                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Field", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    ]),
                                    dbc_col([
                                        dcc_dropdown(   id      = "fields-dropdown",
                                                        options = [
                                                            (label = "Variance",                value = "nvar"),
                                                            (label = "Number of stable phases", value = "nsp"),
                                                            (label = "ρ_system",                value = "rho"),
                                                            (label = "ρ_solid",                 value = "rho_S"),
                                                            (label = "ρ_melt",                  value = "rho_M"),
                                                            (label = "Vp",                      value = "Vp"),
                                                            (label = "Vs",                      value = "Vs"),
                                                            (label = "Status",                  value = "status"),

                                                        ],
                                                        value="nvar" ,
                                                        clearable   = false,
                                                        multi   = false),
                                    ]), 
                                ]),

                                dbc_row([
                                        dbc_col([ 
                                            html_h1("Colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ]),
                                        dbc_col([
                                            dcc_dropdown(   id          = "colormaps_cross",
                                                            options     = [String.(keys(colormaps))...],
                                                            value       = "roma",
                                                            clearable   = false,
                                                            placeholder = "Colormap")
                                        ]), 
                                    ])
                                ])
                            ),
                            id="collapse",
                            is_open=true,
                        ),

                        dbc_button("Grid refinement",id="button-refinement"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([

                                ])),
                                id="collapse-refinement",
                                is_open=false,
                        ),
                    ])
                    ], width=3),

                ], justify="left"),

            ], width=12)
    ])
end