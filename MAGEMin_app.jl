using Base.Threads: @threads
using Dash  
using DashBootstrapComponents
using PlotlyJS, JSON3, Printf, Statistics, DataFrames, CSV, Dates, Base64
using UUIDs, Delaunay
# using ScatteredInterpolation
using GeometricalPredicates

# this activate the wrapper of MAGEMin dev branch
# using Pkg
# MAGEMin_dir = "../TC_calibration"
# Pkg.activate(MAGEMin_dir)
# Pkg.instantiate()
using MAGEMin_C


include("initialize_MAGEMin_AMR.jl")
include("appData.jl")
include("Tab_Simulation.jl")
include("Tab_PhaseDiagram.jl")
include("data_plot.jl")
include("functions.jl")

app         = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
app.title   = "MAGEMin app"
app.layout  = html_div() do
 
data_vert = []

    dbc_container([
        dbc_col([dbc_row([
                    dbc_col([
                        dbc_cardimg(    id = "jgu-img",
                                        src="assets/static/images/JGU_light.jpg",
                                        style = Dict("height" => 90, "width" => 315)),
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
                                id="id-dropdown-file",
                                color="secondary"),
                            ]),
                        ]),
                        dbc_row([
                            html_div("‎ "),
                        ]),


                        dbc_tabs(
                            [
                                dbc_tab(    tab_id="tab-Simulation",
                                            label="Simulation",
                                            children = [Tab_Simulation()],
                                        ),
                                dbc_tab(    tab_id="tab-phase-diagram",
                                            label="Phase Diagram",
                                            children = [Tab_PhaseDiagram()]
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