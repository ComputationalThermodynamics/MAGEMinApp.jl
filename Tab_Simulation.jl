function Tab_Simulation(db)
    html_div([
    # one column for the plots
        dbc_col([

                html_div("‎ "),
                # first row with 2 columns for plot added related buttons
                dbc_row([   dbc_col([diagram_plot(db)]),

                ], justify="center"),

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
                                ], width=16), 
                        dbc_col([ ])

                ], justify="center"),

                html_div("‎ "),
                html_div("‎ "),
                

                ], width=16)
    ])
end