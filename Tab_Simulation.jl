function Tab_Simulation()
    html_div([
    # one column for the plots
        dbc_col([
                html_div("‎ "),
                # first row with 2 columns for plot added related buttons
                dbc_row([   

                        dbc_col([ 
                        dbc_row([dbc_button("Phase diagram parameters",id="button-PT-conditions"),
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

                                    #clinopyroxene for metabasite
                                    html_div([
                                        html_div("‎ "),  
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("clinopyroxene", style = Dict("textAlign" => "center","font-size" => "120%")),
                                            ],width=6),
                                            dbc_col([ 
                                                html_div("Omphacite"),
                                            ],width=3),
                                            dbc_col([ 
                                                dbc_row(dbc_switch(label="", id="mb-cpx-switch", value=false),justify="center"),
                                            ]),
                                            dbc_col([ 
                                                html_div("Augite"),
                                            ]),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "switch-cpx-id"), #none, block

                                    #clinopyroxene for metabasite
                                    html_div([
                                        html_div("‎ "),  
                                        dbc_row([
                                            dbc_col([ 
                                                # html_h1("Limit Ca-orthopyroxene", style = Dict("textAlign" => "center","font-size" => "120%")),
                                            ],width=6),
                                            # dbc_col([ 
                                            # ],width=1),
                                            dbc_col([ 
                                                dcc_checklist(
                                                    id      ="limit-ca-opx-id",
                                                    options = [
                                                        Dict("label" => " Limit Ca-opx", "value" => "CAOPX"),
                                                    ],
                                                    value   = [""],
                                                    inline  = true,
                                                ),
                                            ]),
                                            dbc_col([ 
                                                html_div([
                                                dbc_input(
                                                    id      = "ca-opx-val-id",
                                                    type    = "number", 
                                                    min     = 0.0, 
                                                    max     = 1.0, 
                                                    value   = 0.5   ),
                                                ], style = Dict("marginTop" => -5)),
                                            ],width=3),

                                        ]),
                                    ], style = Dict("display" => "block"), id      = "switch-opx-id"), #none, block


                                    #PT caption 
                                    html_div("‎ "),  
                                    html_div("‎ "),  
                                    dbc_row([
                                        dbc_col([ 
                                        ], width=6),
                                        dbc_col([ 
                                            html_h1("min", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        ]),
                                        dbc_col([ 
                                            html_h1("max", style = Dict("textAlign" => "center","font-size" => "100%")),
                                        ]),
                                    ]),
                                    html_div([
                                    #pressure
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Pressure", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ], width=6),
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
                                            ]),
                                        ]),
                                    ]),
                                    ], style = Dict("display" => "block"), id      = "pressure-id"), #none, block

                                    html_div([
                                    #temperature                                                        
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Temperature", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ], width=6),
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
                                                        value   = 1400.0   ),
                                                ]),
                                            ]),
                                        ]),
                                    ]),
                                    ], style = Dict("display" => "block"), id      = "temperature-id"), #none, block

                                    # Fixed pressure
                                    html_div([
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Fixed pressure", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ]),
                                        dbc_col([ 
                                                dbc_input(
                                                id      = "fixed-pressure-val-id",
                                                type    = "number", 
                                                min     = 0.01, 
                                                max     = 100.01, 
                                                value   = 10.01   ),
                                        ]),
                                    ]),
                                    ], style = Dict("display" => "none"), id      = "fixed-pressure-id"), #none, block

                                    # Fixed temperature
                                    html_div([
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Fixed temperature", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ]),
                                        dbc_col([ 
                                                dbc_input(
                                                id      = "fixed-temperature-val-id",
                                                type    = "number", 
                                                min     = 0.0, 
                                                max     = 10000.0, 
                                                value   = 800.0   ),
                                        ]),
                                    ]),
                                    ], style = Dict("display" => "none"),id = "fixed-temperature-id"), #none, block
                                   

                                    html_div("‎ "),
                                    #subdivision
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Initial grid subdivision", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ]),
                                        dbc_col([ 
                                                dbc_input(
                                                id      = "gsub-id",
                                                type    = "number", 
                                                min     = 2,  
                                                value   = 3   ),
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
                                    html_div("‎ "), 
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Refinement levels", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                                id      = "refinement-levels",
                                                type    = "number", 
                                                min     = 1,  
                                                value   = 2   ),
                                        ]),
                                    ]),
                                    html_div("‎ "), 
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
                                    #verbose
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Verbose", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ]),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "verbose-dropdown",
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
                                                    dbc_row([
                                                        
                                                            dbc_col([
                                                                html_div([
                                                                    dcc_dropdown(   id      = "test-dropdown",
                                                                    options = [
                                                                        Dict(   "label" => db[(db.db .== "ig"), :].title[i],
                                                                                "value" => db[(db.db .== "ig"), :].test[i]  )
                                                                                    for i=1:length(db[(db.db .== "ig"), :].test)
                                                                    ],
                                                                    value       = 0,
                                                                    clearable   = false,
                                                                    multi       = false),
                                                                ], style = Dict("display" => "block"), id      = "test-1-id"),
                                                            ]),
                                                        
                                                            dbc_col([
                                                                html_div([
                                                                    dcc_dropdown(   id      = "test-2-dropdown",
                                                                    options = [
                                                                        Dict(   "label" => db[(db.db .== "ig"), :].title[i],
                                                                                "value" => db[(db.db .== "ig"), :].test[i]  )
                                                                                    for i=1:length(db[(db.db .== "ig"), :].test)
                                                                    ],
                                                                    value       = 0,
                                                                    clearable   = false,
                                                                    multi       = false),
                                                                ], style = Dict("display" => "none"), id      = "test-2-id"),
                                                            ]),
                                                    ]),


                                                    html_div("‎ "),


                                                    dbc_row([
                                                        
                                                            dbc_col([
                                                                html_div([
                                                                    dash_datatable(
                                                                        id="table-bulk-rock",
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
                                                                                id      = "buffer-1-mul-id",
                                                                                type    = "number", 
                                                                                min     = -50.0, 
                                                                                max     = +50.0, 
                                                                                value   = 0.0   ),
                                                                        ]),
                                                                    ]),
                                                                    ], style = Dict("display" => "none"), id      = "buffer-1-id"), #none, block

                                                                ], style = Dict("display" => "block"), id      = "table-1-id"), #none, block
                                                            ]),
                                                        
                                                        
                                                        dbc_col([
                                                            html_div([
                                                                dash_datatable(
                                                                    id="table-2-bulk-rock",
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
                                                                                id      = "buffer-2-mul-id",
                                                                                type    = "number", 
                                                                                min     = -50.0, 
                                                                                max     = +50.0, 
                                                                                value   = 0.0   ),
                                                                        ]),
                                                                    ]),
                                                                    ], style = Dict("display" => "none"), id      = "buffer-2-id"), #none, block

                                                            ], style = Dict("display" => "none"), id      = "table-2-id"), #none, block
                                                        ]),
                                                    ]),


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

                                                ]),

                                                ], justify="center"),
                                                ])
                                            ),
                                            id="collapse-bulk",
                                            is_open=true,
                                    ),

                            ])

                        ], width=4),

                        dbc_col([ 
                        ]),

                        dbc_col([ 
                            dbc_row([   
                            dbc_button("General parameters",id="button-general-parameters",color="primary"),
                            dbc_collapse(
                                dbc_card(dbc_cardbody([

                                        dbc_col([ 
                                            #title                                                           
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Title", style = Dict("textAlign" => "center","font-size" => "120%")),
                                                ], width=3),
                                                dbc_col([ 
                                                    dbc_input(
                                                        id      = "title-id",
                                                        type    = "text",  
                                                        value   = db[(db.db .== "ig"), :].title[1]   ),            
                                                ]),
                                            ]),
                                            #Filename
                                            html_div("‎ "),
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Filename", style = Dict("textAlign" => "center","font-size" => "120%")),
                                                ], width=3),
                                                dbc_col([ 
                                                    dbc_input(
                                                        id      = "Filename-id",
                                                        type    = "text", 
                                                        style   = Dict("textAlign" => "center") ,
                                                        value   = " ... "   ),            
                                                ]),
                                            ]),
                                            # load save buttons
                                            dbc_row([
                                                dbc_col([ 
                                                ], width=4),        
                                                dbc_col([ 
                                                    dbc_button(
                                                        "Load", id="load-button", color="light",  n_clicks=0,
                                                    ),
                                                ]),
                                                dbc_col([ 
                                                    dbc_button(
                                                        "Save", id="Save-button", color="light",  n_clicks=0,
                                                    ),
                                                ]),
                                            ]),

                                            html_div("‎ "),
                                            dbc_row([
                                                dbc_button(
                                                    "Compute phase diagram", id="compute-button", color="light", className="me-2", n_clicks=0,
                                                    style       = Dict( "textAlign"     => "center",
                                                                        "font-size"     => "100%",
                                                                        "border"        =>"1px grey solid")
                                                ),
                                            ]),
                                        ])

                                    ])),
                                    id="collapse-general-parameters",
                                    is_open=true,
                            ),
                            ])
                            ], width=3),


                    ]),

                ], width=12)
    ])
end