#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

function Tab_GeneralSetup()
    html_div([
        dbc_row([
            html_div("‎ "),
            dbc_col([
                dbc_row([
                    dbc_button("General parameters",id="button-general-setup-parameters",color="primary"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([
                            dbc_row([
                                dbc_col([
                                    html_h1("Mineral names", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                ], width=4),
                                dbc_col([
                                    dcc_dropdown(
                                        id        = "mineral-naming-dropdown",
                                        options   = [
                                            Dict("label" => "Legacy",      "value" => "legacy"),
                                            Dict("label" => "Warr (2021)", "value" => "warr"),
                                        ],
                                        value     = "legacy",
                                        clearable = false,
                                        multi     = false,
                                    ),
                                ]),
                            ]),
                            html_div(id="warr-naming-dummy", style=Dict("display"=>"none")),
                            html_div("‎ "),
                            dbc_row([
                                dbc_col([
                                    html_h1("Pressure unit", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                ], width=4),
                                dbc_col([
                                    dcc_dropdown(
                                        id        = "pressure-unit-dropdown",
                                        options   = [
                                            Dict("label" => "kbar", "value" => "kbar"),
                                            Dict("label" => "GPa",  "value" => "gpa"),
                                        ],
                                        value     = "kbar",
                                        clearable = false,
                                        multi     = false,
                                    ),
                                ]),
                            ]),
                            html_div(id="pressure-unit-dummy", style=Dict("display"=>"none")),
                            html_div(id="pressure-unit-prev", children="kbar", style=Dict("display"=>"none")),
                            html_div(id="pressure-unit-prev-ptx", children="kbar", style=Dict("display"=>"none")),
                            html_div(id="pressure-unit-prev-ptx-solidus", children="kbar", style=Dict("display"=>"none")),
                            html_div("‎ "),
                            dbc_row([
                                dbc_col([
                                    html_h1("Output directory", style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                ], width=4),
                                dbc_col([
                                    dbc_input(
                                        id          ="state-directory2",
                                        type        = "text",
                                        value       = output_dir[1],
                                        style       = Dict("textAlign" => "center","font-size" => "120%", "width"=> "100%")
                                    ),
                                ]),
                                dbc_col([
                                    dbc_button("Apply", id="apply-output-dir-button", color="primary", n_clicks=0),
                                ], width="auto"),
                            ]),
                            dbc_row([
                                dbc_col([
                                    html_small(id="output-dir-feedback", children="", style=Dict("color"=>"grey")),
                                ]),
                            ]),



                        ])),
                        id="collapse-general-setup-parameters",
                        is_open=true,
                    ),
                ]),
                dbc_row([
                    dbc_button("Contributors",id="button-contributors",color="primary"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([

                            dbc_row([
                                dbc_col([
                                    dcc_markdown(       id          = "debug-info-id",
                                                        children    = AppData.contribs[1],
                                                        style       = Dict("white-space" => "pre"))
                                ], width=6),
                                dbc_col([
                                    dcc_markdown(       id          = "app-info-id",
                                                        children    = AppData.contribs[2],
                                                        style       = Dict("white-space" => "pre"))
                                ], width=6),
                            ]),
                        ])),
                        id      =   "collapse-contributors",
                        is_open =    false,
                    ),
                ]),
            ], width=4),

            dbc_col([
            ]),

            dbc_col([
                dbc_row([
                    dbc_button("External libraries",id="button-external-libraries",color="primary"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([
                            html_div("‎ "),
                            dbc_table(
                                html_tbody(
                                    html_tr([
                                        html_td(
                                            html_img(src="assets/static/images/Logo-IntersecT.png",
                                                style=Dict("height"=>"100px", "width"=>"100px", "object-fit"=>"contain")),
                                            style=Dict("verticalAlign"=>"middle", "width"=>"110px"),
                                        ),
                                        html_td(
                                            dcc_markdown("[IntersecT](https://doi.org/10.1016/j.cageo.2025.105949)",
                                                style=Dict("white-space" => "pre", "font-size" => "120%")),
                                            style=Dict("verticalAlign"=>"middle", "width"=>"160px"),
                                        ),
                                        html_td(
                                            dcc_markdown(
                                                "IntersecT is an open-source Python package developped by S. Nerone for statistically quantifying the quality of fit in isopleth thermobarometry using thermodynamic model outputs",
                                                style=Dict("white-space" => "pre-wrap", "font-size" => "120%")),
                                            style=Dict("verticalAlign"=>"middle"),
                                        ),
                                    ]),
                                ),
                                style=Dict("table-layout"=>"fixed"),
                                bordered=false, hover=false, responsive=true, size="sm",
                            ),

                        ])),
                        id="collapse-external-libraries",
                        is_open=true,
                    ),
                ]),
                dbc_row([
                    dbc_button("Help and contact",id="button-contact",color="primary"),
                    dbc_collapse(
                        dbc_card(dbc_cardbody([
                            html_div("‎ "),
                            dbc_table(
                                html_tbody(
                                    vcat(
                                        [html_tr([
                                                html_td(
                                                if i == 1
                                                    html_img(src="assets/static/images/doc_MAGEMin.png",
                                                        style=Dict("height"=>"100px", "width"=>"100px", "object-fit"=>"contain"))
                                                elseif i == 2
                                                    html_img(src="assets/static/images/github_issue.jpg",
                                                        style=Dict("height"=>"100px", "width"=>"100px", "object-fit"=>"contain"))
                                                elseif i == 3
                                                    html_img(src="assets/static/images/github_logo.png",
                                                        style=Dict("height"=>"100px", "width"=>"100px", "object-fit"=>"contain"))
                                                elseif i == 4
                                                    html_img(src="assets/static/images/discord.png",
                                                        style=Dict("height"=>"100px", "width"=>"100px", "object-fit"=>"contain"))
                                                else
                                                    []
                                                end,
                                                style=Dict("verticalAlign"=>"middle", "width"=>"110px"),
                                            ),
                                            html_td(dcc_markdown(link, style=Dict("white-space" => "pre", "font-size" => "120%")),
                                                    style=Dict("verticalAlign"=>"middle", "width"=>"160px")),
                                            html_td(dcc_markdown(info, style=Dict("white-space" => "pre", "font-size" => "120%")),
                                                    style=Dict("verticalAlign"=>"middle")),

                                        ]) for (i,(link,info)) in enumerate(zip(split(AppData.contribs[3],"\n"), split(AppData.contribs[4],"\n")))],
                                    )
                                ),
                                style=Dict("table-layout"=>"fixed"),
                                bordered=false, hover=false, responsive=true, size="sm",
                            ),

                        ])),
                        id="collapse-contact",
                        is_open=true,
                    ),
                ]),
            ], width=7),

            # dbc_col([ 
            # ]),
            
            # dbc_col([
            # ], width=3),

        ]),
    ])
end
