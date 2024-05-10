function Tab_TraceElement()
    html_div([
    # one column for the plots
        dbc_col([

            dbc_row([ 

                dbc_col([diagram_plot_te()], width=9),
                dbc_col([  
                    dbc_row([

                    dbc_button("Display options",id="display-options-te-button"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([
                                dbc_row([
                                    dbc_button(
                                        "Load/Reload trace-elements", id="load-button-te", color="light", className="me-2", n_clicks=0,
                                        style       = Dict( "textAlign"     => "center",
                                                            "font-size"     => "100%",
                                                            "border"        =>"2px grey solid")), 
                                ]),

                            ])),
                            id="collapse-display-options-te",
                            is_open=true,
                    ),


                    html_div("‎ "),
                    dbc_button("Display options",id="button-display-options-te"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([

                            dbc_row([
                                dbc_col([ 
                                    html_h1("Show reaction lines", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                ], width=5),
                                dbc_col([
                                    dcc_dropdown(   id          = "show-grid-te",
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
                                    dcc_dropdown(   id          = "show-full-grid-te",
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
                                    dcc_dropdown(   id          = "show-lbl-id-te",
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
                                    dcc_dropdown(   id      = "fields-dropdown-te",
                                                    options = [
                                                        (label = "Sat_zr_liq",              value = "Sat_zr_liq"    ),
                                                        (label = "Cliq_Zr",                 value = "Cliq_Zr"       ),
                                                        (label = "zrc_wt",                  value = "zrc_wt"        ),
                                                    ],
                                                    value="Sat_zr_liq" ,
                                                    clearable   = false,
                                                    multi       = false),
                                ]), 
                            ]),

                            dbc_row([
                                    dbc_col([ 
                                        html_h1("Colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    ], width=5),
                                    dbc_col([
                                        dcc_dropdown(   id          = "colormaps_cross-te",
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
                                        dcc_dropdown(   id          = "smooth-colormap-te",
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
                                            id="range-slider-color-te",
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
                                        dcc_dropdown(   id          = "reverse-colormap-te",
                                                        options     = ["true","false"],
                                                        value       = "false",
                                                        clearable   = false)
                                    ]), 
                                ]),

                            ])
                        ),
                        id="collapse-opt-te",
                        is_open=true,
                    ),

                    ]),
                ]),
            ]),



        ], width=12)
    ])
end