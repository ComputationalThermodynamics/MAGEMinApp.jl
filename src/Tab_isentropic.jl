function Tab_IsentropicPaths()
    html_div([
        html_div("‎ "),
        dbc_row([ 

                dbc_col([  

                    dbc_row([

                        dbc_button("Configuration",id="button-config-isoS"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Thermodynamic database", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 2)),
                                    ]),
                                    dbc_col([ 
                                        dcc_dropdown(   id      = "database-dropdown-isoS",
                                                        options = [
                                                            Dict(   "label" => dba.database[i],
                                                                    "value" => dba.acronym[i]  )
                                                                        for i=1:size(dba,1)
                                                        ],
                                                        value="ig" ,
                                                        clearable   = false,
                                                        multi       = false),
                                    ]),
                                    ]),


                                    #clinopyroxene for metabasite
                                    html_div([
                                        html_div("‎ "),  
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("clinopyroxene", style = Dict("textAlign" => "center","font-size" => "120%")),
                                            ],width=6),
                                            dbc_col([ 
                                                html_div("Omph"),
                                            ],width=3),
                                            dbc_col([ 
                                                dbc_row(dbc_switch(label="", id="mb-cpx-switch-isoS", value=false),justify="center"),
                                            ]),
                                            dbc_col([ 
                                                html_div("Aug"),
                                            ]),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "switch-cpx-id-isoS"), #none, block

                                    #clinopyroxene for metabasite
                                    html_div([
                                        html_div("‎ "),  
                                        dbc_row([
                                            dbc_col([ 
                                            ],width=6),

                                            dbc_col([ 
                                                dcc_checklist(
                                                    id      ="limit-ca-opx-id-isoS",
                                                    options = [
                                                        Dict("label" => " Limit Ca-opx", "value" => "CAOPX"),
                                                    ],
                                                    value   = [""],
                                                    inline  = true,
                                                ),
                                                dbc_tooltip("This activate a smaller range for compositional variable of opx for the igneous database sets",target="limit-ca-opx-id-isoS"),

                                            ]),
                                            dbc_col([ 
                                                html_div([
                                                dbc_input(
                                                    id      = "ca-opx-val-id-isoS",
                                                    type    = "number", 
                                                    min     = 0.0, 
                                                    max     = 1.0, 
                                                    value   = 0.5   ),
                                                ], style = Dict("marginTop" => -5)),
                                            ],width=3),

                                        ]),
                                    ], style = Dict("display" => "block"), id      = "switch-opx-id-isoS"), #none, block



                                    # buffer
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Buffer", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ]),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "buffer-dropdown-isoS",
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
                                    #solver
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Solver", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ]),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "solver-dropdown-isoS",
                                            options = [
                                                (label = "PGE",         value = "pge"),
                                                (label = "Legacy",      value = "lp"),
                                                (label = "Hybrid",      value = "hyb")
                                            ],
                                            value="hyb" ,
                                            clearable   = false,
                                            multi   = false),
                                        ]),
                                    ]),
                                    #verbose
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Verbose", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ]),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "verbose-dropdown-isoS",
                                            options = [
                                                (label = "none",        value = -1),
                                                (label = "light",       value =  0),
                                                (label = "full",        value =  1),
                                            ],
                                            value       = -1,
                                            clearable   = false,
                                            multi       = false),
                                        ]),
                                    ]),

                                ])),
                                id="collapse-config-isoS",
                                is_open=true,
                        ),
                    
                    ])


                    dbc_row([dbc_button("Bulk-rock composition",id="button-bulk-isoS"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([

                                    dbc_row([
                                            dbc_col([

                                                dcc_upload(
                                                    id="upload-bulk-isoS",
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
                                                dbc_alert(
                                                    "Bulk-rock(s) composition(s) successfully loaded",
                                                    id      = "output-data-uploadn-isoS",
                                                    is_open = false,
                                                    duration= 4000,
                                                ),
                                                dbc_alert(
                                                    "Bulk-rock(s) composition(s) failed to load, check input file format",
                                                    color="danger",
                                                    id      ="output-data-uploadn-failed-isoS",
                                                    is_open = false,
                                                    duration= 4000,
                                                ),
                                                # html_div(id="output-data-uploadn"),
                                                dbc_tooltip([
                                                    html_div("An example of file providing bulk-rock compositions is given in the 'examples' folder"),
                                                    html_div("The structure of the file should comply with the following structure:"),
                                                    html_div("title::String; comments::String; db::String; sysUnit::String; oxide::Vector{String}; frac::Vector{Float64}")
                                                            ],target="upload-bulk-isoS"),

                                                html_div("‎ "),
                                                dbc_row([

                                                    html_div([
                                                        dcc_dropdown(   id      = "test-dropdown-isoS",
                                                        options = [
                                                            Dict(   "label" => db[(db.db .== "ig"), :].title[i],
                                                                    "value" => db[(db.db .== "ig"), :].test[i]  )
                                                                        for i=1:length(db[(db.db .== "ig"), :].test)
                                                        ],
                                                        value       = 0,
                                                        clearable   = false,
                                                        multi       = false),
                                                    ], style = Dict("display" => "block"), id      = "test-1-id-isoS"),
                                                ]),


                                                html_div("‎ "),
                                                dbc_row([
                                                    
                                                            html_div([
                                                                dash_datatable(
                                                                    id="table-bulk-rock-isoS",
                                                                    columns=(  [    Dict("id" =>  "oxide",          "name" =>  "oxide",         "editable" => false),
                                                                                    Dict("id" =>  "mol_fraction",   "name" =>  "mol_fraction",  "editable" => true)]
                                                                    ),
                                                                    data        =   [Dict(  "oxide"         => db[(db.db .== "ig") .& (db.test .== 0), :].oxide[1][i],
                                                                                            "mol_fraction"  => db[(db.db .== "ig") .& (db.test .== 0), :].frac[1][i])
                                                                                                for i=1:length(db[(db.db .== "ig") .& (db.test .== 0), :].oxide[1]) ],
                                                                    style_cell  = (textAlign="center", fontSize="140%",),
                                                                    style_header= (fontWeight="bold",),
                                                                    # editable    = true
                                                                ),

                                                                # Buffer multiplier
                                                                html_div([
                                                                html_div("‎ "),
                                                                dbc_row([
                                                                    dbc_col([ 
                                                                        html_h1("Buffer multiplier", style = Dict("textAlign" => "center","font-size" => "120%")),
                                                                    ]),
                                                                    dbc_col([ 
                                                                            dbc_input(
                                                                            id      = "buffer-1-mul-id-isoS",
                                                                            type    = "number", 
                                                                            min     = -50.0, 
                                                                            max     = +50.0, 
                                                                            value   = 0.0   ),
                                                                    ]),
                                                                ]),
                                                                ], style = Dict("display" => "none"), id      = "buffer-1-id-isoS"), #none, block

                                                            ], style = Dict("display" => "block"), id      = "table-1-id-isoS"), #none, block
                                                ]),


                                                html_div("‎ "),
                                                dcc_textarea(
                                                    id="database-caption-isoS",
                                                    value       = db[(db.db .== "ig") .& (db.test .== 0), :].db[1],
                                                    readOnly    = true,
                                                    disabled    = true,
                                                    draggable   = false,
                                                    style       = Dict("textAlign" => "center","font-size" => "100%", "width"=> "100%", "resize"=> "none")
                                                ),

                                            ]),

                                            ], justify="center"),
                                            ])
                                        ),
                                        id="collapse-bulk-isoS",
                                        is_open=true,
                                ),

                        ])


 
                ], width=3),

                dbc_col([ ], width=9),


            ]),

    ])

end

