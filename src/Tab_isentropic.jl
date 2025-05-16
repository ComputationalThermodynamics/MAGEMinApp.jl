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
                                    ],width=4),
                                    dbc_col([ 
                                        dcc_dropdown(   id      = "database-dropdown-isoS",
                                                        # options = [
                                                        #     Dict(   "label" => dba.database[i],
                                                        #             "value" => dba.acronym[i]  )
                                                        #                 for i=1:size(dba,1)
                                                        # ],
                                                        options     = dtb_dict,
                                                        value="ig" ,
                                                        clearable   = false,
                                                        multi       = false),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Dataset", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 8)),
                                        ],width=4),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "dataset-dropdown-isoS",
                                                            options = [Dict(    "label"     => "ds$(AppData.db_inf.dataset_opt[i])",
                                                                                "value"     => AppData.db_inf.dataset_opt[i] )
                                                                            for i = 1:length(AppData.db_inf.dataset_opt) ],
                                                            value       = AppData.db_inf.db_dataset,
                                                            clearable   = false,
                                                            multi       = false),
                                        ]),
                                    ]),
                                    dbc_row([  
                                        dbc_col([ 
                                            html_h1("Phase selection", style = Dict("textAlign" => "center","font-size" => "120%")),
                                        ],width=4),

                                        dbc_col([ 
                                            dbc_row([  
                                                html_h1("Solution phase", style = Dict("textAlign" => "center","font-size" => "100%")),
                                            ]),
                            
                                            dbc_row([  
                                                dbc_button( "", id="button-phase-selection-isoS", color="light", className="me-2", n_clicks=0,
                                                                style       = Dict( "textAlign"     => "center",
                                                                                    "font-size"     => "100%",
                                                                                    "border"        =>"1px grey solid",
                                                                                    "width"         => "40px" )), 
                                            ],justify="center"),                                        
                                            dbc_row([  
                                                dbc_collapse(
                                                    dbc_card(dbc_cardbody([
                    
                                                            dbc_col([ 
                    
                                                                dcc_checklist(
                                                                    id      = "phase-selection-isoS",
                                                                    options = [Dict(    "label"     => " "*i,
                                                                                        "value"     => i )
                                                                                    for i in AppData.db_inf.ss_name ],
                                                                    value = AppData.db_inf.ss_name,
                                                                    # inline = true,
                                                                ),
                        
                                                            ]),
                    
                                                        ])),
                                                        id="collapse-phase-selection-isoS",
                                                        is_open=false,
                                                ),
                                            ]),
                                        ]),

                                        dbc_col([ 
                                            dbc_row([  
                                                html_h1("Pure phase", style = Dict("textAlign" => "center","font-size" => "100%")),
                                            ]),
                                    
                                            dbc_row([  
                                                dbc_button( "", id="button-pure-phase-selection-isoS", color="light", className="me-2", n_clicks=0,
                                                                    style       = Dict( "textAlign"     => "center",
                                                                                        "font-size"     => "100%",
                                                                                        "border"        =>"1px grey solid",
                                                                                        "width"         => "40px" )), 
                                                ],justify="center"),                                        
                                                dbc_row([ 
                                                dbc_collapse(
                                                    dbc_card(dbc_cardbody([
                    
                                                            dbc_col([ 
                    
                                                                dcc_checklist(
                                                                    id      = "pure-phase-selection-isoS",
                                                                    options = [],
                                                                    value = "",
                                                                    # inline = true,
                                                                ),
                        
                                                            ]),
                    
                                                        ])),
                                                        id="collapse-pure-phase-selection-isoS",
                                                        is_open=false,
                                                ),
                                            ]),
                                        ]),

                                    ],style = Dict("marginTop" => "2px", "marginBottom" => "2px")),


                                    #clinopyroxene for metabasite
                                    html_div([
                                        html_div("‎ "),  
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Clinopyroxene", style = Dict("textAlign" => "center","font-size" => "120%")),
                                            ],width=4),
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
                                            ],width=4),

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
                                        ],width=4),
                                        dbc_col([ 
                                            dcc_dropdown(   id      = "buffer-dropdown-isoS",
                                            options = [
                                                (label = "no buffer",value = "none"),
                                                (label = "QFM",      value = "qfm"),
                                                (label = "MW",       value = "mw"), 
                                                (label = "IW",       value = "iw"), 
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
                                        ],width=4),
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
                                        ],width=4),
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

                                                dbc_row([
                                                    dbc_col([ 
                                                        dcc_dropdown(   id      = "select-bulk-unit-isoS",
                                                        options = [
                                                            (label = "mol%",                value = 1),
                                                            (label = "wt%",                 value = 2),
                                                        ],
                                                        value       = 1,
                                                        style       = Dict("border" => "none"),
                                                        clearable   = false,
                                                        multi       = false),
                                                    ], width=3),


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

                                                    ], width=9),

                                                ]),

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
                                                                                    Dict("id" =>  "fraction",   "name" =>  "fraction",  "editable" => true)]
                                                                    ),
                                                                    data        =   [Dict(  "oxide"         => db[(db.db .== "ig") .& (db.test .== 0), :].oxide[1][i],
                                                                                            "fraction"  => db[(db.db .== "ig") .& (db.test .== 0), :].frac[1][i])
                                                                                                for i=1:length(db[(db.db .== "ig") .& (db.test .== 0), :].oxide[1]) ],
                                                                    style_cell  = (textAlign="center", fontSize="140%",),
                                                                    style_header= (fontWeight="bold",),
                                                                    # editable    = true
                                                                ),

                                                                # buffer offset
                                                                html_div([
                                                                html_div("‎ "),
                                                                dbc_row([
                                                                    dbc_col([ 
                                                                        html_h1("buffer offset", style = Dict("textAlign" => "center","font-size" => "120%")),
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

                dbc_col([ 


                    dbc_row([ 
                        dbc_col([  
                        ]), #, width=1


                        dbc_col([ 
                        
                            dbc_row([

                                dbc_button("Path definition",id="button-pathdef-isoS"),
                                dbc_collapse(
                                dbc_card(dbc_cardbody([

                                    dbc_row([
                                        dbc_col([ 
                                             html_h1("Starting pressure [kbar]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                            id      = "starting-pressure-isoS-id",
                                            type    = "number", 
                                            min     = 0.001, 
                                            max     = 1500.01, 
                                            value   = 30.0   ),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                             html_h1("Starting temperature [°C]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                            id      = "starting-temperature-isoS-id",
                                            type    = "number", 
                                            min     = 1.0, 
                                            max     = 3000.0, 
                                            value   = 1500.0   ),
                                        ]),
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                             html_h1("Ending pressure [kbar]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                        ]),
                                        dbc_col([ 
                                            dbc_input(
                                            id      = "ending-pressure-isoS-id",
                                            type    = "number", 
                                            min     = 0.001, 
                                            max     = 1500.01, 
                                            value   = 1.0   ),
                                        ]),
                                    ]),


                                ])),
                                id="collapse-pathdef-isoS",
                                is_open=true,
                                ),
                                                                                
                            ]),
                            dbc_row([

                                dbc_button("Path information",id="button-pathinformation-isoS"),
                                dbc_collapse(
                                dbc_card(dbc_cardbody([

                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Entropy [J/K]", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 4)),
                                        ]),
                                        dbc_col([ 
                                            dcc_textarea(
                                                id="display-entropy-textarea",
                                                value       = "",
                                                readOnly    = true,
                                                disabled    = true,
                                                draggable   = false,
                                                style       = Dict("textAlign" => "center","font-size" => "100%", "width"=> "100%", "height" => 24, "resize"=> "none")
                                            ),
                                        ]),
                                    ]),
                                ])),
                                id="collapse-pathinformation-isoS",
                                is_open=true,
                                ),
                                                                                
                            ])

                        ], width=3),

                        dbc_col([  
                        ]), #, width=1

                        dbc_col([ 
                        
                            dbc_row([

                                dbc_button("P-T isentropic path", id="button-isoS-path"),
                                dbc_collapse(
                                dbc_card(dbc_cardbody([

                                    dbc_row([
                                        path_isoS_plot(),
                                    ]),
                                    
                                ])),
                                id="collapse-isoS-path",
                                is_open=true,
                                ),
                                                                                
                            ])

                        ], width=4),

                        dbc_col([  
                        ]), #, width=1


                        dbc_col([ 

                            dbc_row([

                                dbc_button("Path options",id="button-path-opt-isoS"),
                                dbc_collapse(
                                    dbc_card(dbc_cardbody([
                                        # resolution is number of computational steps between two points
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Resolution", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=6),
                                            dbc_col([ 
                                                    dbc_input(
                                                    id      = "n-steps-id-isoS",
                                                    type    = "number", 
                                                    min     = 1, 
                                                    max     = 1024, 
                                                    value   = 16   ),
                                            ]),
                                        ]),                               
                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("Tolerance", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=6),
                                            dbc_col([ 
                                                    dbc_input(
                                                    id      = "tolerance-id-isoS",
                                                    type    = "number", 
                                                    min     = 1e-8, 
                                                    max     = 1.0, 
                                                    value   = 1e-4   ),
                                            ]),
                                        ]),  

                                        html_div("‎ "),
                                        dbc_row([
                                            dbc_button("Compute path",id="compute-path-button-isoS", color="light", className="me-2", n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "background-color" => "#d3f2ce",
                                                                "border"        =>"1px grey solid")), 
                                        ]),
                                        html_div("‎ "),
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Save path", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 4)),    
                                            ], width=3),
                                            dbc_col([ 
                                                dbc_input(
                                                    id      = "Filename-all-isoS-id",
                                                    type    = "text", 
                                                    style   = Dict("textAlign" => "center") ,
                                                    value   = "filename"   ),     
                                            ], width=4),
                                            dbc_col([    
                                                dbc_button("Table", id="save-all-table-isoS-button", color="light",  n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px grey solid")), 
                                                dcc_download(id="download-all-table-isoS-text"),  
                                            ]),
                                            dbc_col([    
                                                dbc_button("csv file", id="save-all-csv-isoS-button", color="light",  n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px grey solid")), 
                                                dcc_download(id="download-all-csv-isoS-text"),  
                                            ]),
                                        ]),
                                        dbc_row([
                                            dbc_alert(
                                                "Successfully saved all data points information",
                                                id      ="data-all-table-isoS-save",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Provide a valid filename (without extension)",
                                                color="danger",
                                                id      ="data-all-save-table-isoS-failed",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Successfully saved all data points information",
                                                id      ="data-all-csv-isoS-save",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Provide a valid filename (without extension)",
                                                color="danger",
                                                id      ="data-all-save-csv-isoS-failed",
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
                                                    id      = "export-citation-id-isoS",
                                                    type    = "text", 
                                                    style   = Dict("textAlign" => "center") ,
                                                    value   = "filename"   ),     
                                            ], width=4),
                                            dbc_col([    
                                                dbc_button("bibtex file", id="export-citation-button-isoS", color="light",  n_clicks=0,
                                                style       = Dict( "textAlign"     => "center",
                                                                    "font-size"     => "100%",
                                                                    "border"        =>"1px grey solid")), 

                                                dbc_tooltip([
                                                    html_div("Saving list of citation for the computed phase diagram"),
                                                    html_div("Output path and progress are displayed in the Julia terminal")],target="export-citation-button"),
                                            ]),
                                        ]),
    
                                        dbc_row([
                                            dbc_alert(
                                                "Successfully saved all data points information",
                                                id      ="export-citation-save-isoS",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                            dbc_alert(
                                                "Provide a valid filename (without extension)",
                                                color="danger",
                                                id      ="export-citation-failed-isoS",
                                                is_open =false,
                                                duration=4000,
                                            ),
                                        ]),
    


                                    ])),
                                    id="collapse-path-opt-isoS",
                                    is_open=true,
                                ),
                                                                                
                                dbc_button("Display options",id="button-disp-opt-isoS"),
                                dbc_collapse(
                                    dbc_card(dbc_cardbody([

                                        dbc_row([
                                            dbc_col([ 
                                                html_h1("System unit", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                            ], width=6),
                                            dbc_col([ 
                                                dcc_dropdown(   id      = "sys-unit-isoS",
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
                                    id="collapse-disp-opt-isoS",
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
                                    isoS_plot()
                                ])),
                            ]),
                            html_div("‎ "),
                            dbc_row([
                                dbc_card(dbc_cardbody([
                                    dbc_row([
                                        dbc_col([ 
                                            isoS_frac_plot()
                                        ], width=10)

                                        dbc_col([ 
                                            html_div("‎ "),
                                            html_div("‎ "),
                                            html_div("‎ "),
                                            dbc_card(dbc_cardbody([

                                                # mineral list
                                                dcc_checklist(
                                                    id      = "phase-selector-isoS-id",
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

                ], width=9),


            ]),

    ])

end

