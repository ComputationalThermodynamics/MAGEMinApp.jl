function Tab_PTXpaths()
    html_div([
        html_div("‎ "),

        dbc_row([ 

                dbc_col([  
                    dbc_row([

                        dbc_button("Configuration",id="button-config"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                    dbc_row([
                                        html_div("pouet "),
                                    ]),
                                ])),
                                id="collapse-config",
                                is_open=true,
                        ),
                    
                    ])
                ], width=2),

                dbc_col([  
                    dbc_row([

                        dbc_button("Path definition",id="button-path"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                dbc_row([
                                        path_plot(),
                                    ]),
                                    html_div("‎ "),
                        
                                dbc_row([

                                    dash_datatable(
                                        id="ptx-table",
                                        columns=[Dict("name" => "P [kbar]", "id"    => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                                    Dict("name" => "T [°C]", "id"      => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric")],
                                        data=[
                                            Dict("col-1" => 5.0, "col-2" => 500.0),
                                            Dict("col-1" => 10.0, "col-2" => 800.0),
                                        ],
                                        style_cell      = (textAlign="center", fontSize="140%",),
                                        style_header    = (fontWeight="bold",),
                                        editable        = true,
                                        row_deletable   = true
                                    ),

                                ]),
                                html_div("‎ "),
                                dbc_row([
                                    dbc_button("Add point",id="add-row-button", color="light", className="me-2", n_clicks=0,
                                    style       = Dict( "textAlign"     => "center",
                                                        "font-size"     => "100%",
                                                        "border"        =>"1px lightgray solid")), 
                                ]),
                                html_div("‎ "),
                                dbc_row([
                                    dbc_button("Compute path",id="compute-path-button", color="light", className="me-2", n_clicks=0,
                                    style       = Dict( "textAlign"     => "center",
                                                        "font-size"     => "100%",
                                                        "border"        =>"1px lightgray solid")), 
                                ]),


                            ])),
                            id="collapse-path",
                            is_open=true,
                        ),
                    
                    ])
                ], width=3),

                dbc_col([PTX_plot()], width=7),

            ]),

    ])

end


# dash_datatable(
#     id="adding-rows-table",
#     columns=[Dict(
#         "name" =>  "Column $i",
#         "id" =>  "column-$i",
#         "deletable" =>  true,
#         "renamable" =>  true
#     ) for i in 1:4],
#     data=[
#         Dict("column-$i" =>  (j + (i-1)*5)-1 for i in 1:4)
#         for j in 1:5
#     ],
#     editable=true,
#     row_deletable=true
# ),