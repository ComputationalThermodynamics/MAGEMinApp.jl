#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

function Tab_TraceElement()
    html_div([
    # one column for the plots
        dbc_col([

            dbc_row([ 

                dbc_col([
                    dbc_row([
                        dbc_button("Rare Earth Elements spectrum",id="button-spectrum"),
                        dbc_collapse(
                            dbc_card(dbc_cardbody([
                                        dbc_row([
                                            dbc_col([
                                                spectrum_plot_te()
                                            ], width=10),
                                            dbc_col([
                                                
                                                dbc_row([
                                                    dbc_card([
                                                        dcc_markdown(   id          = "click-data-left-spectrum", 
                                                                        children    = "",
                                                                        style       = Dict("white-space" => "pre"))
                                                    ]),
                                                ]),
                                                html_div("‎ "),
                                                html_div([
                                                    dbc_row([
                                                        dbc_col([ 
                                                            html_h1("Show", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                        ], width=6),
                                                        dbc_col([
                                                            dcc_dropdown(   id          = "show-spectrum-te",
                                                                            options     =  ["ree","all"],
                                                                            value       = "ree" ,
                                                                            clearable   =  false,
                                                                            multi       =  false),
                                                        ], width=6), 
                                                    ]),
                                                    dbc_row([
                                                        dbc_col([ 
                                                            html_h1("Norm.", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                        ]),
                                                        dbc_col([
                                                            dcc_dropdown(   id          = "normalization-te",
                                                                            options     =  ["bulk","chondrite"],
                                                                            value       = "bulk" ,
                                                                            clearable   =  false,
                                                                            multi       =  false),
                                                        ], width=6), 
                                                    ]),
                                                ], style = Dict("display" => "block"), id  = "display-show-norm-id"), #none, block


                                            ], width=2),  
                                        ]),
                                    ])),
                                    id="collapse-spectrum",
                                    is_open=true,
                            ),
                    ]),
                    dbc_row([   
                        dbc_col([
                            html_div("‎ "),
                            dbc_row([
                                diagram_legend_te()
                            ]),
                            dbc_row([
                                diagram_plot_te()
                            ]),
                        ], width=9),
                        dbc_col([
                            html_div("‎ "),
                            html_div("‎ "), 
                            dbc_row([dbc_button("Export figure",id="export-figure-te"),
                            dbc_collapse(
                                dbc_card(dbc_cardbody([
                                    dbc_row([
                                        dbc_button("Export all layers", 
                                                    id          = "export-layers-te", color="light",  n_clicks=0,
                                                    style       =  Dict( "textAlign"    => "center",
                                                                        "font-size"     => "100%",
                                                                        "border"        =>"1px grey solid")), 
                                    ]),
                                    dbc_row([
                                        html_div("‎ "),
                                        dcc_textarea(
                                            id          ="state-directory-2-te",
                                            value       = "Figure directory: $(pwd())/output/",
                                            readOnly    = true,
                                            disabled    = true,
                                            draggable   = false,
                                            style       = Dict("textAlign" => "center","font-size" => "100%", "width"=> "100%", "resize"=> "none")
                                        )
                                    ]),

                                ])),
                                id          = "collapse-export-figure-te",
                                is_open     =  true,
                            ),
                            ]),
                            
                            dbc_row([dbc_button("Phase assemblages",id="phase-label-te"),
                            dbc_collapse(
                                dbc_card(dbc_cardbody([

                                    html_div([
                                        dbc_row([

                                            dcc_clipboard(
                                                target_id   = "stable-assemblage-id-te",
                                                title       = "copy",
                                                style       =  Dict(    "display"       => "inline-block",
                                                                        "fontSize"      =>  20,
                                                                        "verticalAlign" => "top"    ),
                                            ),
                                        ]),
                                        dbc_row([
                                            dbc_card([
                                                dcc_markdown(   id          = "stable-assemblage-id-te", 
                                                                children    = "",
                                                                style       = Dict(     "white-space" => "pre", 
                                                                                        "max-height" => "640px",
                                                                                        "overflow-y" => "auto"      ))
                                            ])
                                        ]),
                                    ], style = Dict("display" => "block"), id      = "show-text-list-id-te"), #none, block

                                                            ])),
                                id="collapse-phase-label-te",
                                is_open=true,
                                dimension="width",
                            ),
                            ]),

                        ], width=3),
                    ]),



                ], width=9),
                dbc_col([  
                    dbc_row([

                    dbc_button("General options",id="display-options-te-button"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([
                                dbc_row([
                                    dbc_button(
                                        "Load/Reload trace-elements", id="load-button-te", color="light", className="me-2", n_clicks=0,
                                        style       = Dict( "textAlign"     => "center",
                                                            "font-size"     => "100%",
                                                            "background-color" => "#d3f2ce",
                                                            "border"        =>"1px grey solid")), 
                                ]),

                                html_div("‎ "),
                                dbc_row([
                                    dbc_col([
                                        html_h1("Save point", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                    ], width=3),
                                    dbc_col([ 
                                        dbc_input(
                                            id      = "Filename-point-id-te",
                                            type    = "text", 
                                            style   = Dict("textAlign" => "center") ,
                                            value   = "filename"   ),     
                                    ], width=4),
                                    dbc_col([    
                                        dbc_button("csv file", id="save-point-table-button-te", color="light",  n_clicks=0,
                                        style       = Dict( "textAlign"     => "center",
                                                            "font-size"     => "100%",
                                                            "border"        =>"1px grey solid")), 
                                        dbc_tooltip([
                                            html_div("Saving point data takes time and depends on the number of points"),
                                            html_div("Output path and progress are displayed in the Julia terminal")],target="save-point-table-button-te"),
                                        dcc_download(id="download-point-table-text-te"),  
                                    ]),
                                ]),
                                dbc_row([
                                    dbc_alert(
                                        "Successfully saved all data points information",
                                        id      ="data-point-table-save-te",
                                        is_open =false,
                                        duration=4000,
                                    ),
                                    dbc_alert(
                                        "Provide a valid filename (without extension)",
                                        color="danger",
                                        id      ="data-point-save-table-failed-te",
                                        is_open =false,
                                        duration=4000,
                                    ),
                                ]),
                                dbc_row([
                                    dbc_col([
                                        html_h1("Save all", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                    ], width=3),
                                    dbc_col([ 
                                        dbc_input(
                                            id      = "Filename-all-id-te",
                                            type    = "text", 
                                            style   = Dict("textAlign" => "center") ,
                                            value   = "filename"   ),     
                                    ], width=4),
                                    dbc_col([    
                                        dbc_button("csv file", id="save-all-table-button-te", color="light",  n_clicks=0,
                                        style       = Dict( "textAlign"     => "center",
                                                            "font-size"     => "100%",
                                                            "border"        =>"1px grey solid")), 
                                        dbc_tooltip([
                                            html_div("Saving all data takes time and depends on the number of points"),
                                            html_div("Output path and progress are displayed in the Julia terminal")],target="save-all-table-button-te"),
                                        dcc_download(id="download-all-table-text-te"),  
                                    ]),
                                ]),
                                dbc_row([
                                    dbc_alert(
                                        "Successfully saved all data points information",
                                        id      ="data-all-table-save-te",
                                        is_open =false,
                                        duration=4000,
                                    ),
                                    dbc_alert(
                                        "Provide a valid filename (without extension)",
                                        color="danger",
                                        id      ="data-all-save-table-failed-te",
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
                                            id      = "export-citation-id-te",
                                            type    = "text", 
                                            style   = Dict("textAlign" => "center") ,
                                            value   = "filename"   ),     
                                    ], width=4),
                                    dbc_col([    
                                        dbc_button("bibtex file", id="export-citation-button-te", color="light",  n_clicks=0,
                                        style       = Dict( "textAlign"     => "center",
                                                            "font-size"     => "100%",
                                                            "border"        =>"1px grey solid")), 
                                        dbc_tooltip([
                                            html_div("Saving list of citation for the computed phase diagram"),
                                            html_div("Output path and progress are displayed in the Julia terminal")],target="export-citation-button-te"),
                                    ]),
                                ]),

                                dbc_row([
                                    dbc_alert(
                                        "Successfully saved references",
                                        id      ="export-citation-save-te",
                                        is_open =false,
                                        duration=4000,
                                    ),
                                    dbc_alert(
                                        "Provide a valid filename (without extension)",
                                        color="danger",
                                        id      ="export-citation-failed-te",
                                        is_open =false,
                                        duration=4000,
                                    ),
                                ]),

                            ])),
                            id="collapse-display-options-te",
                            is_open=true,
                    ),

                    html_div("‎ "),
                    dbc_tabs([
                        dbc_tab(label="Display options", children=[
                            dbc_collapse(
                                dbc_card(dbc_cardbody([
                                html_h1("Select field to display", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                html_hr(),
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Field type", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    ], width=5),
                                    dbc_col([
                                        dcc_dropdown(   id      = "field-type-dropdown-te",
                                                        options = [
                                                            (label = "Zircon",              value = "zr"     ),
                                                            (label = "Trace element",       value = "te"     ),
                                                        ],
                                                        value="zr" ,
                                                        clearable   = false,
                                                        multi       = false),
                                    ]), 
                                ]),
                                html_div([
                                dbc_row([
                                    dbc_col([ 
                                        html_h1("Field", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    ], width=5),
                                    dbc_col([
                                        dcc_dropdown(   id      = "fields-dropdown-zr",
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
                                ], style = Dict("display" => "block"), id      = "show-zircon-id"), #none, bloc

                                html_div([

                                    dbc_row([
                                        html_h1("Available phases", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                    ]),
                                    dbc_row([
                                        dbc_card([
                                            dcc_markdown(   id          = "phase-te-info-id", 
                                                            children    = "",
                                                            style       = Dict("white-space" => "pre"))
                                        ])
                                    ]),

                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Field builder", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([
                                            dbc_input(
                                                id      = "input-te-id",
                                                type    = "text", 
                                                value   = "[M_Dy] / [M_Yb]"   ),
                                        ]), 
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("normalization", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([
                                            dcc_dropdown(   id          = "field-norm-te-id",
                                            options     =  ["none","bulk","chondrite"],
                                            value       = "none" ,
                                            clearable   =  false,
                                            multi       =  false),
                                        ]), 
                                    ]),
                                    dbc_row([
                                        dbc_button(
                                            "Compute and display", id="compute-display-te", color="light", className="me-2", n_clicks=0,
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"1px grey solid")), 
                                    ]),
                                ], style = Dict("display" => "none"), id      = "show-trace-element-id"), #none, bloc


                                html_h1("Diagram options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                html_hr(),
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
                                        html_h1("Show phase label", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    ], width=5),
                                    dbc_col([
                                        dcc_dropdown(   id          = "show-lbl-id-te",
                                                        options     =  ["true","false"],
                                                        value       = "true" ,
                                                        clearable   =  false,
                                                        multi       =  false),
                                    ]), 
                                ]),

                                html_div("‎ "),
                                html_h1("Color options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                html_hr(),
                                dbc_row([
                                        dbc_col([ 
                                            html_h1("Colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([
                                            dcc_dropdown(   id          = "colormaps_cross-te",
                                                            options     = ["blackbody","Blues","cividis","Greens","Greys","hot","jet","RdBu","Reds","viridis","YlGnBu","YlOrRd"],
                                                            value       = "RdBu",
                                                            clearable   = false,
                                                            placeholder = "Colormap")
                                        ]), 
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Value range", style = Dict("textAlign" => "center","font-size" => "120%",  "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([ 
                                            dbc_row([
                                            dbc_col([ 
                                                    dbc_input(
                                                        id      = "min-color-id-te",
                                                        type    = "number", 
                                                        min     = -1e50, 
                                                        max     = 1e50, 
                                                        value   = 800.0,
                                                        debounce = true   ),
                                                ]),
                                                dbc_col([ 
                                                    dbc_input(
                                                        id      = "max-color-id-te",
                                                        type    = "number", 
                                                        min     = -1e50, 
                                                        max     = 1e50, 
                                                        value   = 1400.0,
                                                        debounce = true   ),
                                                ]),
                                            ]),
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
                                            html_h1("Set min to white", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([
                                            dcc_dropdown(   id          = "set-min-white-te",
                                                            options     = ["true","false"],
                                                            value       = "false",
                                                            clearable   = false)
                                        ]), 
                                    ]),
                                    dbc_row([
                                        dbc_col([ 
                                            html_h1("Reverse colormap", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=5),
                                        dbc_col([
                                            dcc_dropdown(   id          = "reverse-colormap-te",
                                                            options     = ["true","false"],
                                                            value       = "true",
                                                            clearable   = false)
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
                                ])),id="collapse-display-option-te",is_open=true)]),
                            dbc_tab(label="Isopleths", children=[
                                dbc_collapse(
                                    dbc_card(dbc_cardbody([


                                    html_h1("Selection", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                    html_hr(),
                                    
                                            dbc_row([
                                                dbc_col([
                                                    html_h1("Field type", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                                ]),
                                                dbc_col([
                                                    dcc_dropdown(   id      = "field-type-te-dropdown",
                                                    options = [
                                                        (label = "Zircon",              value = "zrc"),
                                                        (label = "Trace element",       value = "te"),
                                                        ],
                                                    value       = "zrc",
                                                    clearable   = false,
                                                    multi       = false),
                                                ]),
                                            ]),

                                        html_div([
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Field", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ], width=5),
                                                dbc_col([
                                                    dcc_dropdown(   id      = "fields-dropdown-zr-te",
                                                                    options = [
                                                                        (label = "Sat_zr_liq",              value = "Sat_zr_liq"    ),
                                                                        (label = "Cliq_Zr",                 value = "Cliq_Zr"       ),
                                                                        (label = "zrc_wt",                  value = "zrc_wt"        ),
                                                                    ],
                                                                    value       = "Sat_zr_liq" ,
                                                                    clearable   =  false,
                                                                    multi       =  false ),
                                                ]), 
                                            ]),
                                        ], style = Dict("display" => "none"), id      = "fields-dropdown-zr-id-te"),
                                        html_div([
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Calculator", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ]),
                                                dbc_col([
                                                    dbc_input(
                                                        id      = "input-calc-id-te",
                                                        type    = "text", 
                                                        value   = "[M_Dy] / [M_Yb]"   ),
                                                ]), 
                                            ]),
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("normalization", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ]),
                                                dbc_col([
                                                    dcc_dropdown(   id          = "normalization-iso-te",
                                                                    options     =  ["bulk","chondrite","none"],
                                                                    value       = "none" ,
                                                                    clearable   =  false,
                                                                    multi       =  false),
                                                ]), 
                                            ]),
                                            dbc_row([
                                                dbc_col([ 
                                                    html_h1("Custom name", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                                ]),
                                                dbc_col([
                                                    dbc_input(
                                                        id      = "input-cust-id-te",
                                                        type    = "text", 
                                                        value   = "none"   ),
                                                ]), 
                                            ]),
                                        ], style = Dict("display" => "none"), id      = "calc-1-id-te"),
                                    
                                        html_div("‎ "),
                                        html_h1("Range", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        html_hr(),
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Min", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([ 
                                                dbc_input(
                                                    id      ="iso-min-id-te",
                                                    type    ="number", 
                                                    min     =-1e8, 
                                                    max     = 1e8, 
                                                    value   =0.0   ),
                                            ]),
                                        ]),
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Step", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]), 
                                            dbc_col([ 
                                                dbc_input(
                                                    id="iso-step-id-te",
                                                    type="number", 
                                                    min=-1e8, 
                                                    max= 1e8, 
                                                    value=1.0   ),
                                            ]),
                                        ]),
                                        dbc_row([  
                                            dbc_col([
                                                html_h1("Max", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([ 
                                                dbc_input(
                                                    id="iso-max-id-te",
                                                    type="number", 
                                                    min=-1e8, 
                                                    max= 1e8, 
                                                    value=10.0   ),
                                            ]),
                                        ]),
                                        html_div("‎ "),
                                        html_h1("Plotting options", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        html_hr(),
                                        dbc_row([    
                                            dbc_col([
                                                html_h1("Line style", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([ 
                                                dcc_dropdown(   id      = "line-style-dropdown-te",
                                                options = [
                                                    (label = "Solid",                   value = "solid"),
                                                    (label = "Dot",                     value = "dot"),
                                                    (label = "Dash",                    value = "dash"),
                                                    (label = "Longdash",                value = "longdash"),
                                                    (label = "Dashdot",                 value = "dashdot"),
                                                    (label = "Longdashdot",             value = "longdashdot"),
                                                ],
                                                value       = "solid",
                                                clearable   = false,
                                                multi       = false),
                                            ]),
                                        ]),
                                        dbc_row([    
                                            dbc_col([
                                                html_h1("Line width", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([ 
                                                dbc_input(
                                                id      = "iso-line-width-id-te",
                                                type    = "number", 
                                                min     = 0,  
                                                max     = 10,  
                                                value   = 1   ),
                                            ]),
                                        ]),
                                        dbc_row([
                                            dbc_col([
                                                html_h1("Color", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([ 
                                                dbc_input(
                                                    type    = "color",
                                                    id      = "colorpicker_isoL-te",
                                                    value   = "#000000",
                                                    style   = Dict("width" => 75, "height" => 25),
                                                ),
                                            ]),
                                    
                                        ]),
                                        dbc_row([    
                                            dbc_col([
                                                html_h1("Label size", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),    
                                            ]),
                                            dbc_col([ 
                                                dbc_input(
                                                id      = "iso-text-size-id-te",
                                                type    = "number", 
                                                min     = 6,  
                                                max     = 20,  
                                                value   = 10   ),
                                            ]),
                                        ]),

                                        html_div("‎ "),
                                        dbc_row([
                                            dbc_button("Add",id="button-add-isopleth-te", color="light",
                                            style       = Dict( "textAlign"     => "center",
                                                                "font-size"     => "100%",
                                                                "border"        =>"1px lightgray solid")),
                                        ]),  
                                    
                                        html_div("‎ "),
                                        html_h1("Isopleth list", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        html_hr(),

                                        dbc_row([

                                        dbc_col([
                                             html_h1("Displayed", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                             dbc_row([
                                                 html_div([
                                                     dcc_dropdown(   id      = "isopleth-dropdown-te",
                                                     options = [],
                                                     value       = nothing,
                                                     clearable   = false,
                                                     multi       = false),
                                                 ],  style       = Dict("display" => "block"), id      = "isopleth-1-id-te"),
                                             ]),
 
                                             html_div("‎ "),
                                             dbc_row([
                                             dbc_button("Hide",id="button-hide-isopleth-te", color="light",
                                                 style       = Dict( "textAlign"     => "center",
                                                                     "font-size"     => "100%",
                                                                     "border"        =>"1px lightgray solid")),
                                             ]), 
                                             dbc_row([
                                                 dbc_button("Hide all",id="button-hide-all-isopleth-te", color="light",
                                                 style       = Dict( "textAlign"     => "center",
                                                                     "font-size"     => "100%",
                                                                     "border"        =>"1px lightgray solid")),  
                                             ]),
                                             html_div("‎ "),
                                             dbc_row([
                                                 dbc_button("Remove",id="button-remove-isopleth-te", color="light",
                                                 style       = Dict( "textAlign"     => "center",
                                                                     "font-size"     => "100%",
                                                                     "border"        =>"1px lightgray solid")), 
                                             ]), 
                                             dbc_row([
                                                 dbc_button("Remove all",id="button-remove-all-isopleth-te", color="light",
                                                 style       = Dict( "textAlign"     => "center",
                                                                     "font-size"     => "100%",
                                                                     "border"        =>"1px lightgray solid")),
                                             ]), 
  
 
                                         ], width=6),
 
                                         dbc_col([
                                             html_h1("Hidden", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                             dbc_row([
                                                 html_div([
                                                     dcc_dropdown(   id      = "hidden-isopleth-dropdown-te",
                                                     options = [],
                                                     value       = nothing,
                                                     clearable   = false,
                                                     multi       = false),
                                                 ],  style       = Dict("display" => "block"), id      = "hidden-isopleth-1-id-te"),
                                             ]),
 
                                             html_div("‎ "),
                                             dbc_row([
                                                 dbc_button("Show",id="button-show-isopleth-te", color="light",
                                                     style       = Dict( "textAlign"     => "center",
                                                                         "font-size"     => "100%",
                                                                         "border"        =>"1px lightgray solid")),
                                             ]),
                                             dbc_row([
                                                 dbc_button("Show all",id="button-show-all-isopleth-te", color="light",
                                                 style       = Dict( "textAlign"     => "center",
                                                                     "font-size"     => "100%",
                                                                     "border"        =>"1px lightgray solid")), 
                                             ]),
 
                                         ], width=6),
 
                                     ]),

                                    ])),id="collapse-isopleths-te",is_open=true),
                            ]),

                        ])

                    ]),
                ]),
            ]),



        ], width=12)
    ])
end