function Tab_PhaseDiagram(db)
    html_div([
    # one column for the plots
        dbc_col([
            html_div("‎ "),
            dbc_row([ 

                    dbc_col([diagram_plot(db)], width=8),
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
                    ], width=4),

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
                        ], width=8), 
                dbc_col([ ])

            ], justify="center"),

            ], width=12)
    ])
end