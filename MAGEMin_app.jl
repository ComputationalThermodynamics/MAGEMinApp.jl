using Dash  
using DashBootstrapComponents
using PlotlyJS, JSON3, Printf, Statistics, DataFrames, CSV, Dates
using UUIDs, Delaunay

# include helper functions
include("colormaps.jl")
include("Tab_Simulation.jl")
include("Tab_PhaseDiagram.jl")
include("data_plot.jl")
include("database.jl")
include("appData.jl")

app         = dash()
app.title   = "MAGEMin app"
  
app.layout = html_div() do

    dcc_location(id="url", refresh=false),
    html_link(
        id="active-css",
        rel="stylesheet",
        href="/assets/css/default.css"
    ),
    dbc_container([
        dbc_col([dbc_row([
                    dbc_cardimg(    id = "banner-img",
                                    src="assets/static/images/Logos_MAGEMin_light_noERC.jpg",
                                    style = Dict("height" => 140, "width" => 1100)),
                        ]),
                dbc_row([
                        dbc_col([
                                dbc_dropdownmenu(
                                    [dbc_dropdownmenuitem("Load state", disabled=true),
                                    dbc_dropdownmenuitem("Save state", disabled=true),
                                    dbc_dropdownmenuitem(divider=true),
                                    ],
                                    label="File",
                                    id="id-dropdown-file"),
                                ]),
                                dbc_col([
                                    dbc_row([
                                        dbc_col([
                                            html_img(src="assets/static/images/sun.png", style = Dict("height" => 20, "width" => 20)),
                                        ], width=1),
                                        dbc_col([
                                            dbc_switch(label="",id="mode-display",  value=false),
                                        ], width=1),
                                        dbc_col([
                                            html_img(src="assets/static/images/moon.png", style = Dict("height" => 20, "width" => 20)),
                                        ], width=1),
                                    ],className="g-0",),
                                ]),
                        ]),
                    dbc_row([
                        html_div("‎ "),
                        html_div("Web application to compute phase diagrams using MAGEMin"),
                        html_div("‎ ")
                    ]),
                ]),


            dbc_tabs(
                [
                    dbc_tab(tab_id="tab-Simulation",label="Simulation",     children = [Tab_Simulation(db)]),
                    dbc_tab(tab_id="tab-PhaseDiagram",label="PhaseDiagram", children = [Tab_PhaseDiagram(db)]),
                    dbc_tab(tab_id="tab-PTX-path", label="PTX-path",        children = []),
                    dbc_tab(tab_id="tab-TEmodeling", label="TE-modeling",   children = []),

                ],
            id = "tabs", active_tab="tab-Simulation",
        ),
            
        dcc_store(id="session-id", data =  "")     # gives a unique number of our session
    ])

end

    
include("./Tab_Simulation_Callbacks.jl")    

run_server(app, debug=true)

