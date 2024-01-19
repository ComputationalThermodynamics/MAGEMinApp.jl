module MAGEMin_app

using Dash
using DashBootstrapComponents
using PlotlyJS, JSON3, Printf, Statistics, DataFrames, CSV, Dates, Base64
using UUIDs, HTTP
using JLD2, DelimitedFiles, Interpolations
using ConcaveHull,PolygonOps
using ProgressMeter

using MAGEMin_C

pkg_dir = Base.pkgdir(MAGEMin_app)


export App

# include helper functions
include(joinpath(pkg_dir,"src","initialize_MAGEMin_AMR.jl"))
include(joinpath(pkg_dir,"src","PhaseDiagram_functions.jl"))
include(joinpath(pkg_dir,"src","appData.jl"))
include(joinpath(pkg_dir,"src","Tab_Simulation.jl"))
include(joinpath(pkg_dir,"src","Tab_PhaseDiagram.jl"))
include(joinpath(pkg_dir,"src","Tab_PTXpaths.jl"))
include(joinpath(pkg_dir,"src","data_plot.jl"))
include(joinpath(pkg_dir,"src","MAGEMin_app_functions.jl"))
include(joinpath(pkg_dir,"src","MAGEMin_app_Callbacks.jl"))   
include(joinpath(pkg_dir,"src","Tab_Simulation_Callbacks.jl"))    
include(joinpath(pkg_dir,"src","Tab_PhaseDiagram_Callbacks.jl"))
include(joinpath(pkg_dir,"src","PTXpaths_functions.jl"))   
include(joinpath(pkg_dir,"src","Tab_PTXpaths_Callbacks.jl")) 

"""
    App(; host = HTTP.Sockets.localhost, port = 8050, max_num_user=10, debug=false)

Starts the MAGEMin App.
"""
function App(; host = HTTP.Sockets.localhost, port = 8050, max_num_user=10, debug=false)
    GUI_version = "0.1.1"   
    cur_dir     = pwd()                 # directory from where you started the GUI
    pkg_dir     = pkgdir(MAGEMin_app)   # package dir
    cd(pkg_dir)
    # Initialize MPI and T8Code
    COMM = Initialize_AMR()

    app         = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
    app.title   = "MAGEMin app"
    app.layout  = html_div() do
 
        pkg_dir       = pkgdir(MAGEMin_app)
        dbc_container(fluid=false, [
            dbc_col([
            dbc_row([
                        dbc_col([
                            dbc_cardimg(    id      = "jgu-img",
                                            src     = "assets/static/images/ERC_JGU_light.jpg",
                                            style   = Dict("height" => 55, "width" => 230)),
                                ], width="auto" ),
                        dbc_col([
                            dbc_cardimg(    id      = "magemin-img",
                                            src     = "assets/static/images/MAGEMin_light.jpg",
                                            style   = Dict("height" => 70, "width" => 190)),
                                ], width="auto" )
                            ], justify="between"),
                    
                    dbc_row([
                            dbc_col([
                                dbc_dropdownmenu(
                                    [   dbc_dropdownmenuitem("Load state", disabled=true),
                                        dbc_dropdownmenuitem("Save state", disabled=true),
                                        dbc_dropdownmenuitem(divider=true),
                                        dbc_dropdownmenuitem(                 "Export ρ for LaMEM", 
                                                                id          = "export-to-lamem",
                                                                disabled    = false                 ), 
                                        dbc_dropdownmenuitem(                 "Export phase diagram", 
                                                                id          = "export-figure",
                                                                disabled    = false                 ),           
                                    ],
                                    label="File",
                                    id="id-dropdown-file",
                                    color="secondary"),
                                    dcc_download(id="download-lamem-in"),  
                                    dcc_download(id="download-figure"), 
                                    dbc_tooltip("Note that 3-4 refinement levels are more that necessary",target="export-to-lamem"),
                                ]),
                            ]),
                            dbc_col([
                                dbc_alert(
                                    "Density diagram saved for LaMEM",
                                    id      ="export-to-lamem-text",
                                    is_open =false,
                                    duration=4000,
                                ),
                                dbc_alert(
                                    "Phase diagrams for LaMEM have to be PT",
                                    color="danger",
                                    id      ="export-to-lamem-text-failed",
                                    is_open =false,
                                    duration=4000,
                                ),
                            ]),
                            # dbc_col([
                            #     html_div(id="export-to-lamem-text"),
                            # ]),

                            dbc_row([
                                html_div("‎ "),

                            ]),

                            dbc_tabs(
                                [
                                    dbc_tab(    tab_id      = "tab-Simulation",
                                                label       = "Simulation",
                                                children    = [Tab_Simulation()],
                                            ),
                                    dbc_tab(    tab_id      = "tab-phase-diagram",
                                                label       = "Phase Diagram",
                                                children    = [Tab_PhaseDiagram()]
                                            ),
                                    dbc_tab(    tab_id      = "tab-PTX-path",
                                                label       = "PTX path",
                                                children    = [Tab_PTXpaths()]
                                        ),
                                    dbc_tab(tab_id="tab-TEmodeling", label="TE-modeling",   children = []),
                
                                ],
                            id = "tabs", active_tab="tab-Simulation",
                            ),

                    ], width=12),

        dcc_store(id="session-id", data =  "")     # gives a unique number of our session

        ])

    end
    
    # This creates an initial session id that is unique for this session
    # it will run on first start 
    callback!(app, 
        Dash.Output("session-id", "data"),
        Dash.Output("label-id", "children"),
        Input("session-id", "data")
    ) do session_id

        session_id = UUIDs.uuid4()
        str = "id=$(session_id), MAGEMin_app GUI v=$(GUI_version)"
        return String("$(session_id)"), str
    end
    app = MAGEMin_app_Callbacks(app)
    app = Tab_Simulation_Callbacks(app)
    app = Tab_PhaseDiagram_Callbacks(app)
    app = Tab_PTXpaths_Callbacks(app)

    run_server(app, host, port, debug=debug)

    cd(cur_dir) # go back to directory

end

# App( debug=true ) #### trick  to have hot reloading: first launch normaly then quit and go to src and run julia -t 5 MAGEMin_app.jl

end # module MAGEMin_app