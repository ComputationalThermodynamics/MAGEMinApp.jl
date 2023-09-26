function Tab_Simulation()
    html_div([
    # one column for the plots
        dbc_col([
                html_div("‎ "),
                # first row with 2 columns for plot added related buttons
                dbc_row([   
                    dbc_col([ 
                        dbc_row([   
                        dbc_button("General parameters",id="button-general-parameters",color="primary"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([

                                #database
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Thermodynamic database", style = Dict("textAlign" => "center","font-size" => "120%")),
                                    ]),
                                    dbc_col([ 
                                        dcc_dropdown(   id      = "database-dropdown",
                                                        options = [
                                                            Dict(   "label" => dba.database[i],
                                                                    "value" => dba.acronym[i]  )
                                                                        for i=1:size(dba,1)
                                                        ],
                                                        value="ig" ,
                                                        clearable   = false,
                                                        multi   = false),
                                    ]),
                                ]),
                                #diagram type
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Diagram type", style = Dict("textAlign" => "center","font-size" => "120%")),
                                    ]),
                                    dbc_col([ 
                                        dcc_dropdown(   id      = "diagram-dropdown",
                                        options = [
                                            (label = "P-T diagram",         value = "pt"),
                                            (label = "P-X diagram",         value = "px"),
                                            (label = "T-X diagram",         value = "tx"),
                                        ],
                                        value="pt" ,
                                        clearable   = false,
                                        multi   = false),
                                    ]),
                                ]),
                                html_div("‎ "),
                                #solver
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Solver", style = Dict("textAlign" => "center","font-size" => "120%")),
                                    ]),
                                    dbc_col([ 
                                        dcc_dropdown(   id      = "solver-dropdown",
                                        options = [
                                            (label = "PGE",         value = "pge"),
                                            (label = "Legacy",      value = "lp"),
                                        ],
                                        value="pge" ,
                                        clearable   = false,
                                        multi   = false),
                                    ]),
                                ]),
                                #buffer
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Buffer", style = Dict("textAlign" => "center","font-size" => "120%")),
                                    ]),
                                    dbc_col([ 
                                        dcc_dropdown(   id      = "buffer-dropdown",
                                        options = [
                                            (label = "no buffer",value = "none"),
                                            (label = "QFM",      value = "qfm"),
                                            (label = "MW",       value = "mw"), 
                                            (label = "QIF",      value = "qif"),
                                            (label = "CCO",      value = "cco"),
                                            (label = "HM",       value = "hm"), 
                                            (label = "NNO",      value = "nno"), 
                                        ],
                                        value="none" ,
                                        clearable   = false,
                                        multi       = false),
                                    ]),
                                ]),

                                ])),
                                id="collapse-general-parameters",
                                is_open=true,
                        ),
                        ])
                        ], width=4), 

                        dbc_col([ 
                        ]),

                        dbc_col([ 
                        dbc_row([dbc_button("Grid parameters",id="button-PT-conditions"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([

                                    dbc_row([
                                        dbc_col([ 
                                        ], width=3),
                                        dbc_col([ 
                                            html_h1("min", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        ]),
                                        dbc_col([ 
                                            html_h1("max", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        ]),
                                        dbc_col([ 
                                            html_h1("Init subdivision", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Pressure", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ], width=3),
                                        dbc_col([ 
                                            dbc_row([
                                            dbc_col([ 
                                                dbc_input(
                                                    id="pmin-id",
                                                    type="number", 
                                                    min=0.01, 
                                                    max=100.01, 
                                                    value=0.01   ),
                                            ]),
                                            dbc_col([ 
                                                dbc_input(
                                                    id="pmax-id",
                                                    type="number", 
                                                    min=0.01, 
                                                    max=100.01, 
                                                    value=24.01   ),
                                            ]), 
                                            dbc_col([ 
                                                dbc_input(
                                                    id      = "psub-id",
                                                    type    = "number", 
                                                    min     = 2, 
                                                    value   = 3   ),
                                            ]),

                                            ]),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Temperature", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ], width=3),
                                        dbc_col([ 
                                            dbc_row([
                                            dbc_col([ 
                                                    # html_h1("T min", style = Dict("textAlign" => "center","font-size" => "100%")),
                                                    dbc_input(
                                                        id="tmin-id",
                                                        type="number", 
                                                        min=0.0, 
                                                        max=2000.0, 
                                                        value=800.0   ),
                                                ]),
                                                dbc_col([ 
                                                    # html_h1("T max", style = Dict("textAlign" => "center","font-size" => "100%")),
                                                    dbc_input(
                                                        id      = "tmax-id",
                                                        type    = "number", 
                                                        min     = 0.0, 
                                                        max     = 2000.0,
                                                        value   = 1200.0   ),
                                                ]),
                                                dbc_col([ 
                                                    # html_h1("Init subdivision", style = Dict("textAlign" => "center","font-size" => "100%")),
                                                    dbc_input(
                                                        id      = "tsub-id",
                                                        type    = "number", 
                                                        min     = 2,  
                                                        value   = 3   ),
                                                ]),
                                            ]),
                                        ]),
                                    ]),
                                    html_div("‎ "),
                                    #refinement type
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Refinement type", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ]),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "refinement-dropdown",
                                            options = [
                                                (label = "Phases only",         value = "ph"),
                                                (label = "End-members",         value = "em"),
                                            ],
                                            value   = "ph", 
                                            clearable   = false,
                                            multi   = false),
                                        ]),
                                    ]),
                                    #refinement levels 
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Refinement levels", style = Dict("textAlign" => "center","font-size" => "120%")),
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
                                            clearable   = false,
                                            multi   = false),
                                        ]),
                                    ]),

                                ])
                            ),
                            id="collapse-PT-conditions",
                            is_open=true,
                            ),

                            ])
                        ], width=4),


                        dbc_col([ 
                        ]),

                        dbc_col([ 
                        dbc_row([dbc_button("Bulk-rock composition",id="button-bulk"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([

                                        dbc_row([
                                                dbc_col([
                                                    # dbc_row([
                                                    #     dbc_col([
                                                    #         html_div("Predefined"),
                                                    #         ]),
                                                    #     dbc_col([
                                                    #         dbc_switch(label="",id="mode-bulk", value=false),
                                                    #     ]),
                                                    #     dbc_col([
                                                    #         html_div("Custom"),
                                                    #     ]),
                                                    # ]),

                                                    dcc_upload(
                                                        id="upload-bulk",
                                                        children=html_div([
                                                            "Drag and drop or select bulk-rock file",
                                                        ]),
                                                        style=Dict(
                                                            "width" => "100%",
                                                            "height" => "60px",
                                                            "lineHeight" => "60px",
                                                            "borderWidth" => "1px",
                                                            "borderStyle" => "dashed",
                                                            "borderRadius" => "5px",
                                                            "textAlign" => "center"
                                                        ),
                                                        # Allow multiple files to be uploaded
                                                        multiple=false
                                                    ),
                                                    html_div(id="output-data-uploadn"),

                                                    html_div("‎ "),
                                                    dcc_dropdown(   id      = "test-dropdown",
                                                    options = [
                                                        Dict(   "label" => db[(db.db .== "ig"), :].title[i],
                                                                "value" => db[(db.db .== "ig"), :].test[i]  )
                                                                    for i=1:length(db[(db.db .== "ig"), :].test)
                                                    ],
                                                    value       = 0,
                                                    clearable   = false,
                                                    multi       = false),

                                                    # html_h1(db[(db.db .== "ig") .& (db.test .== 0), :].comments, style = Dict("textAlign" => "center","font-size" => "100%")),
                                                    html_div("‎ "),
                                                    dash_datatable(
                                                        id="table-bulk-rock",
                                                        columns=(  [    Dict("id" =>  "oxide",          "name" =>  "oxide",         "editable" => false),
                                                                        Dict("id" =>  "mol fraction",   "name" =>  "mol fraction",  "editable" => true)]
                                                        ),
                                                        data        =   [Dict(  "oxide"         => db[(db.db .== "ig") .& (db.test .== 0), :].oxide[1][i],
                                                                                "mol fraction"  => db[(db.db .== "ig") .& (db.test .== 0), :].frac[1][i])
                                                                                    for i=1:length(db[(db.db .== "ig") .& (db.test .== 0), :].oxide[1]) ],
                                                        style_cell  = (textAlign="center", fontSize="140%",),
                                                        style_header= (fontWeight="bold",),
                                                        # editable    = true
                                                    ),
                                                    html_div("‎ "),
                                                    dcc_textarea(
                                                        id="database-caption",
                                                        # placeholder="Enter a value...",
                                                        value       = db[(db.db .== "ig") .& (db.test .== 0), :].db[1],
                                                        readOnly    = true,
                                                        disabled    = true,
                                                        draggable   = false,
                                                        style       = Dict("textAlign" => "center","font-size" => "100%", "width"=> "100%", "resize"=> "none")
                                                    ),

                                                    # html_h1(db[(db.db .== "ig") .& (db.test .== 0), :].database, id="database-caption",style = Dict("textAlign" => "center","font-size" => "100%")),
                                                ]),

                                                ], justify="center"),
                                                ])
                                            ),
                                            id="collapse-bulk",
                                            is_open=true,
                                    ),

                            ])

                        ], width=3),



                    ]),

                    html_div("‎ "),
                    dbc_col([ 
                    dbc_row([
                        dbc_button(
                            "Compute mesh", id="mesh-button", color="success", className="me-2", n_clicks=0
                        ),
                    ]),
                    html_div("‎ "),
                    dbc_row([
                        dbc_button(
                            "Compute phase diagram", id="compute-button", color="success", className="me-2", n_clicks=0
                        ),
                    ]),
                    ], width=4)

                ], width=12)
    ])
end