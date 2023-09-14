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

# read available colormaps
colormaps   = read_colormaps()  # colormaps
app         = dash()
app.title   = "MAGEMin app"
app.layout  = html_div() do

    dcc_location(id="url", refresh=false),
    html_link(
        id="active-css",
        rel="stylesheet",
        href="/assets/css/default.css"
    ),
    dbc_container([
        dbc_col([dbc_row([
                    dbc_col([
                        dbc_cardimg(    id = "jgu-img",
                                        src="assets/static/images/JGU_light.jpg",
                                        style = Dict("height" => 120, "width" => 420)),
                            ], width="auto" ),
                    dbc_col([
                        dbc_cardimg(    id = "magemin-img",
                                        src="assets/static/images/MAGEMin_light.jpg",
                                        style = Dict("height" => 120, "width" => 360)),
                            ], width="auto" )
                        ], justify="between"),
                html_div("‎ "),
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

                                            dbc_cardimg(    id = "sun-img",
                                            src="assets/static/images/sun.png",
                                            style = Dict("height" => 20, "width" => 20)),

                                        ], width=1),
                                        dbc_col([
                                            dbc_switch(label="",id="mode-display",  value=false),
                                        ], width=1),
                                        dbc_col([

                                            dbc_cardimg(    id = "moon-img",
                                            src="assets/static/images/moon.png",
                                            style = Dict("height" => 20, "width" => 20)),

                                        ], width=1),
                                    ],className="g-0",justify="end"),
                                ]),
                        ]),
                        dbc_row([
                            html_div("‎ "),
                        ]),


                        dbc_tabs(
                            [
                                dbc_tab(    tab_id="tab-Simulation",
                                            label="Simulation",
                                            children = [Tab_Simulation(db)],
                                        ),
                                dbc_tab(    tab_id="tab-phase-diagram",
                                            label="Phase Diagram",
                                            children = [Tab_PhaseDiagram(db)]
                                        ),
                                dbc_tab(tab_id="tab-PTX-path", label="PTX-path",        children = []),
                                dbc_tab(tab_id="tab-TEmodeling", label="TE-modeling",   children = []),
            
                            ],
                        id = "tabs", active_tab="tab-Simulation",
                        ),

                ], width=12),
    ])

end

include("./Tab_Simulation_Callbacks.jl")    
include("./Tab_PhaseDiagram_Callbacks.jl")    

run_server(app, debug=true)

