function Tab_PTXpaths(db_inf)
    html_div([
        html_div("‎ "),
        dbc_row([ 

                dbc_col([  

                    dbc_row([

                        dbc_button("Configuration",id="button-config"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Thermodynamic database", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 2)),
                                    ]),
                                    dbc_col([ 
                                        dcc_dropdown(   id      = "database-dropdown-ptx",
                                                        options = [
                                                            Dict(   "label" => dba.database[i],
                                                                    "value" => dba.acronym[i]  )
                                                                        for i=1:size(dba,1)
                                                        ],
                                                        value="ig" ,
                                                        clearable   = false,
                                                        multi       = false),
                                    ]),
                                    # dbc_tooltip([
                                    #     html_div("Here you can select the thermodynamic database you want"),
                                    #     html_div("Note that the chemical system can be different from database to another"),
                                    #             ],target="database-dropdown-ptx"),
                                    ]),

                                    dbc_row([  
                                        dbc_col([ 
                                            html_h1("Solution phase selection", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ]),

                                        dbc_col([ 
                                            dbc_button( "", id="button-phase-selection-PTX", color="light", className="me-2", n_clicks=0,
                                                                style       = Dict( "textAlign"     => "center",
                                                                                    "font-size"     => "100%",
                                                                                    "border"        =>"2px grey solid")), 
                                            dbc_collapse(
                                                dbc_card(dbc_cardbody([
                
                                                        dbc_col([ 
                
                                                            dcc_checklist(
                                                                id      = "phase-selection-PTX",
                                                                options = [Dict(    "label"     => " "*i,
                                                                                    "value"     => i )
                                                                                for i in db_inf.ss_name ],
                                                                value = db_inf.ss_name,
                                                                # inline = true,
                                                            ),
                    
                                                        ]),
                
                                                    ])),
                                                    id="collapse-phase-selection-PTX",
                                                    is_open=false,
                                            ),
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
                                                dbc_row(dbc_switch(label="", id="mb-cpx-switch-ptx", value=false),justify="center"),
                                            ]),
                                            dbc_col([ 
                                                html_div("Aug"),
                                            ]),
                                        ]),
                                    ], style = Dict("display" => "none"), id      = "switch-cpx-id-ptx"), #none, block

                                    #clinopyroxene for metabasite
                                    html_div([
                                        html_div("‎ "),  
                                        dbc_row([
                                            dbc_col([ 
                                            ],width=6),

                                            dbc_col([ 
                                                dcc_checklist(
                                                    id      ="limit-ca-opx-id-ptx",
                                                    options = [
                                                        Dict("label" => " Limit Ca-opx", "value" => "CAOPX"),
                                                    ],
                                                    value   = [""],
                                                    inline  = true,
                                                ),
                                                dbc_tooltip("This activate a smaller range for compositional variable of opx for the igneous database sets",target="limit-ca-opx-id-ptx"),

                                            ]),
                                            dbc_col([ 
                                                html_div([
                                                dbc_input(
                                                    id      = "ca-opx-val-id-ptx",
                                                    type    = "number", 
                                                    min     = 0.0, 
                                                    max     = 1.0, 
                                                    value   = 0.5   ),
                                                ], style = Dict("marginTop" => -5)),
                                            ],width=3),

                                        ]),
                                    ], style = Dict("display" => "block"), id      = "switch-opx-id-ptx"), #none, block



                                    # buffer
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Buffer", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ]),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "buffer-dropdown-ptx",
                                            options = [
                                                (label = "no buffer",value = "none"),
                                                (label = "QFM",      value = "qfm"),
                                                (label = "MW",       value = "mw"), 
                                                (label = "QIF",      value = "qif"),
                                                (label = "CCO",      value = "cco"),
                                                (label = "HM",       value = "hm"), 
                                                (label = "NNO",      value = "nno"), 
                                                (label = "aH2O",     value = "aH2O"), 
                                                (label = "aO2",      value = "aO2"), 
                                                (label = "aFeO",     value = "aFeO"), 
                                                (label = "aMgO",     value = "aMgO"), 
                                                (label = "aAl2O3",   value = "aAl2O3"), 
                                                (label = "aTiO2",    value = "aTiO2"), 
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
                                            dcc_dropdown(   id      = "solver-dropdown-ptx",
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
                                            dcc_dropdown(   id      = "verbose-dropdown-ptx",
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
                                id="collapse-config",
                                is_open=true,
                        ),
                    
                    ])


                    dbc_row([dbc_button("Bulk-rock composition",id="button-bulk-ptx"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([

                                    dbc_row([
                                            dbc_col([

                                                dcc_upload(
                                                    id="upload-bulk-ptx",
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
                                                    id      = "output-data-uploadn-ptx",
                                                    is_open = false,
                                                    duration= 4000,
                                                ),
                                                dbc_alert(
                                                    "Bulk-rock(s) composition(s) failed to load, check input file format",
                                                    color="danger",
                                                    id      ="output-data-uploadn-failed-ptx",
                                                    is_open = false,
                                                    duration= 4000,
                                                ),
                                                # html_div(id="output-data-uploadn"),
                                                dbc_tooltip([
                                                    html_div("An example of file providing bulk-rock compositions is given in the 'examples' folder"),
                                                    html_div("The structure of the file should comply with the following structure:"),
                                                    html_div("title::String; comments::String; db::String; sysUnit::String; oxide::Vector{String}; frac::Vector{Float64}")
                                                            ],target="upload-bulk-ptx"),

                                                html_div("‎ "),
                                                dbc_row([
                                                    dbc_col([
                                                        html_div([
                                                            dcc_dropdown(   id      = "test-dropdown-ptx",
                                                            options = [
                                                                Dict(   "label" => db[(db.db .== "ig"), :].title[i],
                                                                        "value" => db[(db.db .== "ig"), :].test[i]  )
                                                                            for i=1:length(db[(db.db .== "ig"), :].test)
                                                            ],
                                                            value       = 0,
                                                            clearable   = false,
                                                            multi       = false),
                                                        ], style = Dict("display" => "block"), id      = "test-1-id-ptx"),
                                                    ]),

                                                        
                                                    dbc_col([
                                                        html_div([
                                                            dcc_dropdown(   id      = "test-2-dropdown-ptx",
                                                            options = [
                                                                Dict(   "label" => db[(db.db .== "ig"), :].title[i],
                                                                        "value" => db[(db.db .== "ig"), :].test[i]  )
                                                                            for i=1:length(db[(db.db .== "ig"), :].test)
                                                            ],
                                                            value       = 0,
                                                            clearable   = false,
                                                            multi       = false),
                                                        ], style = Dict("display" => "none"), id      = "test-2-id-ptx"),
                                                    ]),

                                                ]),


                                                html_div("‎ "),
                                                dbc_row([
                                                        dbc_col([
                                                            html_div([
                                                                dash_datatable(
                                                                    id="table-bulk-rock-ptx",
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
                                                                            id      = "buffer-1-mul-id-ptx",
                                                                            type    = "number", 
                                                                            min     = -50.0, 
                                                                            max     = +50.0, 
                                                                            value   = 0.0   ),
                                                                    ]),
                                                                ]),
                                                                ], style = Dict("display" => "none"), id      = "buffer-1-id-ptx"), #none, block

                                                            ], style = Dict("display" => "block"), id      = "table-1-id-ptx"), #none, block

                                                        ]),
                                                        dbc_col([
                                                            html_div([
                                                                dash_datatable(
                                                                    id="table-2-bulk-rock-ptx",
                                                                    columns=(  [    Dict("id" =>  "oxide",          "name" =>  "oxide",         "editable" => false),
                                                                                    Dict("id" =>  "mol_fraction",   "name" =>  "mol_fraction",  "editable" => true)]
                                                                    ),
                                                                    data        =   [Dict(  "oxide"         => db[(db.db .== "ig") .& (db.test .== 0), :].oxide[1][i],
                                                                                            "mol_fraction"  => db[(db.db .== "ig") .& (db.test .== 0), :].frac2[1][i])
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
                                                                                id      = "buffer-2-mul-id-ptx",
                                                                                type    = "number", 
                                                                                min     = -50.0, 
                                                                                max     = +50.0, 
                                                                                value   = 0.0   ),
                                                                        ]),
                                                                    ]),
                                                                    ], style = Dict("display" => "none"), id      = "buffer-2-id-ptx"), #none, block

                                                            ], style = Dict("display" => "none"), id      = "table-2-id-ptx"), #none, block
                                                        ]),

                                                ]),


                                                html_div("‎ "),
                                                dcc_textarea(
                                                    id="database-caption-ptx",
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
                                        id="collapse-bulk-ptx",
                                        is_open=true,
                                ),

                        ])


 
                ], width=3),

                dbc_col([  

                    dbc_row([ 
                        dbc_col([  
                        ]), #, width=1


                        dbc_col([ 
                        
                            dbc_row([

                                dbc_button("Path definition",id="button-pathdef"),
                                dbc_collapse(
                                dbc_card(dbc_cardbody([


                                    dbc_row([
                                        dbc_col([ 
                                            dbc_row([
                                                html_h1("Pressure [kbar]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                            ]),
                                            dbc_row([
                                                html_h1("Tolerance [K]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                            ]),
                                            dbc_row([
                                                dbc_button("Find solidus",id="find-solidus-button", color="light", className="me-2", n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")), 
                                            ]),
                                        ]),
                                        dbc_col([ 
                                            dbc_row([
                                                dbc_input(
                                                id      = "solidus-pressure-val-id",
                                                type    = "number", 
                                                min     = 0.001, 
                                                max     = 100.01, 
                                                value   = 10.0   ),
                                            ]),
                                            dbc_row([
                                                dbc_input(
                                                id      = "solidus-tolerance-val-id",
                                                type    = "number", 
                                                min     = 1e-8, 
                                                max     = 1.0, 
                                                value   = 1e-2   ),
                                            ]),
                                            dbc_row([
                                                dcc_textarea(
                                                    id="display-solidus-textarea",
                                                    value       = "",
                                                    readOnly    = true,
                                                    disabled    = true,
                                                    draggable   = false,
                                                    style       = Dict("textAlign" => "center","font-size" => "100%", "width"=> "100%", "height" => 24, "resize"=> "none")
                                                ),
                                            ]),


                                        ]),
                                    ]),

                                    dbc_row([
                                        dbc_col([ 
                                            dbc_row([
                                                html_h1("Pressure [kbar]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                            ]),
                                            dbc_row([
                                                html_h1("Tolerance [K]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                            ]),
                                            dbc_row([
                                                dbc_button("Find liquidus",id="find-liquidus-button", color="light", className="me-2", n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px lightgray solid")), 
                                            ]),
                                        ]),
                                        dbc_col([ 
                                            dbc_row([
                                                dbc_input(
                                                id      = "liquidus-pressure-val-id",
                                                type    = "number", 
                                                min     = 0.001, 
                                                max     = 100.01, 
                                                value   = 10.0   ),
                                            ]),
                                            dbc_row([
                                                dbc_input(
                                                id      = "liquidus-tolerance-val-id",
                                                type    = "number", 
                                                min     = 1e-8, 
                                                max     = 1.0, 
                                                value   = 1e-2   ),
                                            ]),
                                            dbc_row([
                                                dcc_textarea(
                                                    id="display-liquidus-textarea",
                                                    value       = "",
                                                    readOnly    = true,
                                                    disabled    = true,
                                                    draggable   = false,
                                                    style       = Dict("textAlign" => "center","font-size" => "100%", "width"=> "100%", "height" => 24, "resize"=> "none")
                                                ),
                                            ]),


                                        ]),
                                    ]),
  
                                    html_div("‎ "), 
                                    html_h1("Define P-T points", style = Dict("textAlign" => "center","font-size" => "120%")),
                                    dbc_row([

                                        dash_datatable(
                                            id      = "ptx-table",
                                            columns =[  Dict("name" => "P [kbar]",  "id"   => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                                        Dict("name" => "T [°C]",    "id"   => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric")],
                                            data=[
                                                Dict("col-1" => 5.0,    "col-2"   => 500.0 , Symbol("col-3") => 0.0),
                                                Dict("col-1" => 10.0,   "col-2"   => 800.0 , Symbol("col-3") => 0.0),
                                            ],
                                            style_cell      = (textAlign="center", fontSize="140%",),
                                            style_header    = (fontWeight="bold",),
                                            editable        = true,
                                            row_deletable   = true
                                        ),

                                    ]),
                                    dbc_row([
                                        dbc_button("Add new point",id="add-row-button", color="light", className="me-2", n_clicks=0,
                                        style       = Dict( "textAlign"     => "center",
                                                            "font-size"     => "100%",
                                                            "border"        =>"1px lightgray solid")), 
                                    ]),

                                ])),
                                id="collapse-pathdef",
                                is_open=true,
                                ),
                                                                                
                            ])

                        ], width=3),

                        dbc_col([  
                        ]), #, width=1

                        dbc_col([ 
                        
                            dbc_row([

                                dbc_button("Path preview",id="button-path"),
                                dbc_collapse(
                                dbc_card(dbc_cardbody([

                                    dbc_row([
                                        path_plot(),
                                    ]),
                                    

                                ])),
                                id="collapse-path",
                                is_open=true,
                                ),
                                                                                
                            ])

                        ], width=4),

                        dbc_col([  
                        ]), #, width=1

                        dbc_col([ 

                            dbc_row([

                                dbc_button("Path options",id="button-path-opt"),
                                dbc_collapse(
                                    dbc_card(dbc_cardbody([
                                        # resolution is number of computational steps between two points
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Resolution", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=6),
                                            dbc_col([ 
                                                    dbc_input(
                                                    id      = "n-steps-id-ptx",
                                                    type    = "number", 
                                                    min     = 1, 
                                                    max     = 1024, 
                                                    value   = 4   ),
                                            ]),
                                        ]),                               
                                        # PTX mode
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("P-T-X Mode", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=6),
                                            dbc_col([ 
                                                dcc_dropdown(   id      = "mode-dropdown-ptx",
                                                options = [
                                                    (label = "Equilibrium",                 value = "eq"),
                                                    (label = "Fractional melting",          value = "fm"),
                                                    (label = "Fractional crystallization",  value = "fc"), 
                                                ],
                                                value       = "eq",
                                                clearable   =  false,
                                                multi       =  false    ),
                                            ]),
                                        ]),
                                        # PTX mode
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Assimilation", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=6),
                                            dbc_col([ 
                                                dcc_dropdown(   id      = "assimilation-dropdown-ptx",
                                                options = [
                                                    (label = "true",           value = "true"),
                                                    (label = "false",          value = "false"),
                                                ],
                                                value       = "false",
                                                clearable   =  false,
                                                multi       =  false    ),
                                            ]),
                                        ]),

                                        # connectivity threshold for fracitonal melting
                                        html_div([
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Connectivity threshold [%]", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ], width=6),
                                                dbc_col([ 
                                                        dbc_input(
                                                        id      = "connectivity-id",
                                                        type    = "number", 
                                                        min     = 0, 
                                                        max     = 100.0, 
                                                        value   = 7.0   ),
                                                ]),
                                            ]), 
                                        ], style = Dict("display" => "none"), id      = "show-connectivity-id"), #none, block

                                        # residual fraction for fractional crystallization
                                        html_div([
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Residual fraction [%]", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ], width=6),
                                                dbc_col([ 
                                                        dbc_input(
                                                        id      = "residual-id",
                                                        type    = "number", 
                                                        min     = 0, 
                                                        max     = 100.0, 
                                                        value   = 7.0   ),
                                                ]),
                                            ]), 
                                        ], style = Dict("display" => "none"), id      = "show-residual-id"), #none, block




                                        html_div("‎ "),
                                        dbc_row([
                                            dbc_button("Compute path",id="compute-path-button", color="light", className="me-2", n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"2px grey solid")), 
                                        ]),
                                        html_div("‎ "),
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Save path", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 4)),    
                                            ], width=3),
                                            dbc_col([ 
                                                dbc_input(
                                                    id      = "Filename-all-ptx-id",
                                                    type    = "text", 
                                                    style   = Dict("textAlign" => "center") ,
                                                    value   = "filename"   ),     
                                            ], width=4),
                                            dbc_col([    
                                                dbc_button("Table", id="save-all-table-ptx-button", color="light",  n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"2px grey solid")), 
                                                dcc_download(id="download-all-table-ptx-text"),  
                                            ]),
                                            dbc_col([    
                                                dbc_button("csv file", id="save-all-csv-ptx-button", color="light",  n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"2px grey solid")), 
                                                dcc_download(id="download-all-csv-ptx-text"),  
                                            ]),
                                        ]),
                                        dbc_row([
                                            dbc_alert(
                                                "Successfully saved all data points information",
                                                id      ="data-all-table-ptx-save",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Provide a valid filename (without extension)",
                                                color="danger",
                                                id      ="data-all-save-table-ptx-failed",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Successfully saved all data points information",
                                                id      ="data-all-csv-ptx-save",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Provide a valid filename (without extension)",
                                                color="danger",
                                                id      ="data-all-save-csv-ptx-failed",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                        ]),


                                        html_div("‎ "),
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Export references", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 0)),    
                                            ], width=3),
                                            dbc_col([ 
                                                dbc_input(
                                                    id      = "export-citation-id-ptx",
                                                    type    = "text", 
                                                    style   = Dict("textAlign" => "center") ,
                                                    value   = "filename"   ),     
                                            ], width=4),
                                            dbc_col([    
                                                dbc_button("bibtex file", id="export-citation-button-ptx", color="light",  n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"2px grey solid")), 
                                                dbc_tooltip([
                                                    html_div("Saving list of citation for the computed phase diagram"),
                                                    html_div("Output path and progress are displayed in the Julia terminal")],target="export-citation-button"),
                                            ]),
                                        ]),
    
                                        dbc_row([
                                            dbc_alert(
                                                "Successfully saved all data points information",
                                                id      ="export-citation-save-ptx",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Provide a valid filename (without extension)",
                                                color="danger",
                                                id      ="export-citation-failed-ptx",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                        ]),
    



                                    ])),
                                    id="collapse-path-opt",
                                    is_open=true,
                                ),
                                                                                
                                dbc_button("Display options",id="button-disp-opt"),
                                dbc_collapse(
                                    dbc_card(dbc_cardbody([

                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("System unit", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=6),
                                            dbc_col([ 
                                                dcc_dropdown(   id      = "sys-unit-ptx",
                                                options = [
                                                    (label = "mol%",  value = "mol"),
                                                    (label = "wt%",   value = "wt"),
                                                    (label = "vol%",  value = "vol"), 
                                                ],
                                                value       = "mol",
                                                clearable   =  false,
                                                multi       =  false    ),
                                            ]),
                                        ]),
   


                                    ])),
                                    id="collapse-disp-opt",
                                    is_open=true,
                                ),
                                                                                
                            ])

                        ], width=4),

                    ]),
                    html_div("‎ "),
                    dbc_row([                                                                                     
                        dbc_col([
                            dbc_row([
                                dbc_card(dbc_cardbody([
                                    PTX_plot()
                                ])),
                            ]),
                            html_div("‎ "),
                            dbc_row([
                                dbc_card(dbc_cardbody([
                                    dbc_row([
                                        dbc_col([ 
                                            PTX_frac_plot()
                                        ], width=10)

                                        dbc_col([ 
                                            html_div("‎ "),
                                            html_div("‎ "),
                                            html_div("‎ "),
                                            dbc_card(dbc_cardbody([

                                                # mineral list
                                                dcc_checklist(
                                                    id      = "phase-selector-id",
                                                    options = [],
                                                    value   = [],
                                                )

                                            ])),

                                        ], width=2)
                                    ])
                                ])),

                            ]),      
                        
                        ], width=12),
                    ]),

                    html_div("‎ "),
                    dbc_row([                                                                                     
                        dbc_col([
                            dbc_row([
                                dbc_card(dbc_cardbody([
                                    TAS_plot()
                                ])),
                            ]),
                        ]),
                    ]),


                ], width=9),


            ]),

    ])

end

