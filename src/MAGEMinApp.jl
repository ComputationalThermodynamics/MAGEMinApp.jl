# HELP:

module MAGEMinApp

using Dash
using DashBootstrapComponents
using PlotlyJS, JSON3, Printf, Statistics, DataFrames, CSV, Dates, Base64
using UUIDs, HTTP
using JLD2, DelimitedFiles, Interpolations
using ConcaveHull,PolygonOps
using ProgressMeter
using PCHIPInterpolation
using Bibliography
            
using MAGEMin_C

pkg_dir = Base.pkgdir(MAGEMinApp)

export App
# include helper functions
include(joinpath(pkg_dir,"src","fetch.jl"))
include(joinpath(pkg_dir,"src","AMR/MAGEMin_utils.jl"))
include(joinpath(pkg_dir,"src","AMR/AMR_utils.jl"))
include(joinpath(pkg_dir,"src","PhaseDiagram_functions.jl"))
include(joinpath(pkg_dir,"src","TraceElement_functions.jl"))
include(joinpath(pkg_dir,"src","Tab_Simulation.jl"))
include(joinpath(pkg_dir,"src","Tab_PhaseDiagram.jl"))
include(joinpath(pkg_dir,"src","Tab_Classification.jl"))
include(joinpath(pkg_dir,"src","Tab_TraceElement.jl"))
include(joinpath(pkg_dir,"src","Tab_PTXpaths.jl"))
include(joinpath(pkg_dir,"src","data_plot.jl"))
include(joinpath(pkg_dir,"src","MAGEMinApp_Callbacks.jl"))   
include(joinpath(pkg_dir,"src","Tab_Simulation_Callbacks.jl"))    
include(joinpath(pkg_dir,"src","Tab_PhaseDiagram_Callbacks.jl"))
include(joinpath(pkg_dir,"src","Tab_TraceElement_Callbacks.jl"))
include(joinpath(pkg_dir,"src","PTXpaths_functions.jl"))   
include(joinpath(pkg_dir,"src","Tab_PTXpaths_Callbacks.jl")) 
include(joinpath(pkg_dir,"src","Tab_isentropic.jl"))
include(joinpath(pkg_dir,"src","Tab_isentropic_Callbacks.jl"))
include(joinpath(pkg_dir,"src","IsentropicPaths_functions.jl"))
include(joinpath(pkg_dir,"src","MAGEMinApp_functions.jl"))

"""
    App(; host = HTTP.Sockets.localhost, port = 8050, max_num_user=10, debug=false)

Starts the MAGEMin App.
"""
function App(; host = HTTP.Sockets.localhost, port = 8050, max_num_user=10, debug=false)
    message     = fetch_message()
    message2    = fetch_message2()
    GUI_version = "0.5.3"   
    cur_dir     = pwd()                 # directory from where you started the GUI
    pkg_dir     = pkgdir(MAGEMinApp)   # package dir
    
    include(joinpath(pkg_dir,"src","appData.jl"))
  
    db_inf      = retrieve_solution_phase_information("ig");
    cd(pkg_dir)

    app         = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
    app.title   = "MAGEMin app"
    app.layout  = html_div() do
 
        pkg_dir       = pkgdir(MAGEMinApp)
        dbc_container(fluid=false, [
            dbc_col([
            dbc_row([
                        dbc_col([
                            dbc_cardimg(    id      = "jgu-img",
                                            src     = "assets/static/images/ERC_JGU_light.jpg",
                                            style   = Dict("height" => 55, "width" => 230)),
                                ], width="auto" ),
                        dbc_col([
                            dbc_row([
                                html_div("‎ "),
                                html_div(message, style = Dict("textAlign" => "center","font-size" => "120%")),    
                            ]),
                            dbc_row([
                                html_div("‎ "),
                                html_div(message2, style = Dict("textAlign" => "center","font-size" => "120%")),    
                            ]),
                        ], width="auto" ),
                        dbc_col([
                            dbc_cardimg(    id      = "magemin-img",
                                            src     = "assets/static/images/MAGEMin_light.jpg",
                                            style   = Dict("height" => 70, "width" => 190)),
                                ], width="auto" )

                    ], justify="between"),
                    
                    
                            dbc_tabs([

                                    dbc_tab(    tab_id      = "phase-diagrams",
                                                label       = "Phase diagrams",
                                                children    = [dbc_tabs([
                                                                    dbc_tab(    tab_id      = "tab-Simulation",
                                                                                label       = "Setup",
                                                                                children    = [Tab_Simulation(db_inf)],
                                                                            ),
                                                                    dbc_tab(    tab_id      = "tab-phase-diagram",
                                                                                label       = "Diagram",
                                                                                children    = [
                                                                                    Tab_PhaseDiagram()
                                                                                            #     children    = [dbc_tabs([
                                                                                            #             dbc_tab(    tab_id      = "tab-pd-info",
                                                                                            #                         label       = "Information",
                                                                                            #                         children    = [Tab_PD_info(db_inf)],
                                                                                            #                     ),
                                                                                            #             dbc_tab(    tab_id      = "tab-pd-isopleth",
                                                                                            #                         label       = "Isopleths",
                                                                                            #                         children    = [Tab_PD_isopleth()]
                                                                                            #                     ),
                                                                                            #             dbc_tab(    tab_id      = "tab-pd-display",
                                                                                            #                         label       = "Display option",
                                                                                            #                         children    = [Tab_PD_display()],
                                                                                            #                     ),
                                                                                            #     ], id = "tabs_PD"), ]
                                                                                            ]
                                                                            ),
                                                                    # dbc_tab(    tab_id      = "tab-classification",
                                                                    #             label       = "Classification",
                                                                    #             children    = [Tab_Classification()],
                                                                    #     ),
                                                                    dbc_tab(    tab_id      = "tab-te",
                                                                                label       = "Trace-elements",
                                                                                children    = [Tab_TraceElement()],
                                                                            ),

                                                            ], id = "tabs"), ]
                                            ),

                                    dbc_tab(    tab_id      = "tab-PTX-path",
                                                label       = "PTX path",
                                                children    = [Tab_PTXpaths(db_inf)]
                                            ),
                                    dbc_tab(    tab_id      = "tab-isentropic-path",
                                                label       = "Isentropic path",
                                                children    = [Tab_IsentropicPaths(db_inf)]
                                            ),

                                ],
                             active_tab="phase-diagrams",
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
        str = "id=$(session_id), MAGEMinApp GUI v=$(GUI_version)"
        return String("$(session_id)"), str
    end
    app = MAGEMinApp_Callbacks(app)
    app = Tab_Simulation_Callbacks(app)
    app = Tab_PhaseDiagram_Callbacks(app)
    app = Tab_TraceElement_Callbacks(app)
    app = Tab_PTXpaths_Callbacks(app)
    app = Tab_isoSpaths_Callbacks(app)
    
    run_server(app, host, port, debug=debug)

    cd(cur_dir) # go back to directory

end

# App( debug=true ) #### trick  to have hot reloading: first launch normaly then quit and go to src and run julia -t 5 MAGEMinApp.jl

end # module MAGEMinApp