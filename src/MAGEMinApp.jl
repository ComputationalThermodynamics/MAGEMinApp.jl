# HELP:

module MAGEMinApp

using Dash
using DashBootstrapComponents
using PlotlyJS, JSON3, JSON, Printf, Statistics, DataFrames, CSV, XLSX, Dates, Base64
using UUIDs, HTTP
using JLD2, DelimitedFiles, Interpolations
using ConcaveHull,PolygonOps
using ProgressMeter
using PCHIPInterpolation
using Bibliography

using Images, PolygonInbounds, LazyGrids, Graphs
using MAGEMin_C

import Contour as CTR

pkg_dir = Base.pkgdir(MAGEMinApp)

export App

# include functions
include(joinpath(pkg_dir,"src","fetch.jl"))
include(joinpath(pkg_dir,"src","Progress.jl"))
include(joinpath(pkg_dir,"src","Progress_Callbacks.jl"))
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
include(joinpath(pkg_dir,"src","Tab_General_informations.jl"))
include(joinpath(pkg_dir,"src","MAGEMinApp_functions.jl"))

# Set of functions to extract field boundaries and field centers (by Antom Popov, JGU)
include(joinpath(pkg_dir,"src","Boundaries/center.jl"))
include(joinpath(pkg_dir,"src","Boundaries/poly.jl"))
include(joinpath(pkg_dir,"src","Boundaries/purge.jl"))
include(joinpath(pkg_dir,"src","Boundaries/utils.jl"))
include(joinpath(pkg_dir,"src","appData.jl"))
  

"""
    App(; host = HTTP.Sockets.localhost, port = 8050, max_num_user=10, debug=false)

Starts the MAGEMin App.
"""
function App(; host = HTTP.Sockets.localhost, port = 8050, max_num_user=10, debug=false)

    message     = fetch_message()
    message2    = fetch_message2()
    cur_dir     = pwd()                 # directory from where you started the GUI
    pkg_dir     = pkgdir(MAGEMinApp)   # package dir
    cd(pkg_dir)

    app         = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
    app.title   = "MAGEMinApp"
    app.layout  = html_div() do
 
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
                                ], width="auto" ),

                        dbc_col([
                            dcc_loading(
                                id          =   "loading-id",
                                type        =   "circle",
                                children    =   [html_div(id="output-loading-id")],
                                className   =   "custom-loading",
                            ),
                            dcc_loading(
                                id          =   "loading-id-isentropic",
                                type        =   "circle",
                                children    =   [html_div(id="output-loading-id-isentropic")],
                                className   =   "custom-loading",
                            ),
                            dcc_loading(
                                id          =   "loading-id-te",
                                type        =   "circle",
                                children    =   [html_div(id="output-loading-id-te")],
                                className   =   "custom-loading",
                            ),
                            dcc_loading(
                                id          =   "loading-id-ptx",
                                type        =   "circle",
                                children    =   [html_div(id="output-loading-id-ptx")],
                                className   =   "custom-loading",
                            ),
                        ], width="auto" ),
        
                    ], justify="between"),


                    dbc_row([
                        dbc_col([
                        ], width="auto" ),
                        dbc_col([
                        ], width="auto" ),
                        dbc_col([
                            dcc_interval(
                                id          = "interval-simulation_progress",
                                interval    =  1000,    # in milliseconds
                                n_intervals =  0,
                                disabled    =  true
                            ),
                            dbc_row([
                                diagram_progress_bar()
                            ]),
                        ], width=4 ),

                    ], justify="between"),

                    dbc_tabs([

                            dbc_tab(    tab_id      = "phase-diagrams",
                                        label       = "Phase diagrams",
                                        children    = [dbc_tabs([
                                                            dbc_tab(    tab_id      = "tab-Simulation",
                                                                        label       = "Setup",
                                                                        children    = [Tab_Simulation()],
                                                                    ),
                                                            dbc_tab(    tab_id      = "tab-phase-diagram",
                                                                        label       = "Diagram",
                                                                        children    = [Tab_PhaseDiagram()]
                                                                    ),
                                                            dbc_tab(    tab_id      = "tab-te",
                                                                        label       = "Trace-elements",
                                                                        children    = [Tab_TraceElement()],
                                                                    ),

                                                    ], id = "tabs"), ]
                                    ),

                            dbc_tab(    tab_id      = "tab-PTX-path",
                                        label       = "PTX path",
                                        children    = [Tab_PTXpaths()]
                                    ),
                            dbc_tab(    tab_id      = "tab-isentropic-path",
                                        label       = "Isentropic path",
                                        children    = [Tab_IsentropicPaths()]
                                    ),
                            dbc_tab(    tab_id      = "tab-general-info",
                                        label       = "General information",
                                        children    = [Tab_General_informations()]
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

        # determine how many cores you use and how many are available
        num_available_cores = Sys.CPU_THREADS
        nthreads = Threads.nthreads();

        str = "id=$(session_id);   MAGEMinApp GUI v=$(GUI_version);   using $nthreads/$num_available_cores threads"
        return String("$(session_id)"), str
    end

    app = MAGEMinApp_Callbacks(app)
    app = Tab_Simulation_Callbacks(app)
    app = Tab_PhaseDiagram_Callbacks(app)
    app = Tab_TraceElement_Callbacks(app)
    app = Tab_PTXpaths_Callbacks(app)
    app = Tab_isoSpaths_Callbacks(app)
    app = Progress_Callbacks(app)

    run_server(app, host, port, debug=debug)

    cd(cur_dir) # go back to directory

end


function main(ARGS)

    # By default, start with --threads auto if no thread flag is provided
    has_threads_flag = any(x -> x == "--threads" || x == "-t", ARGS)
    if !has_threads_flag
        n = Sys.CPU_THREADS
        if Threads.nthreads() != n
            println("Restarting with $n threads (auto)...")
            cmd = `$(Base.julia_cmd()) -t $n -m MAGEMinApp $(ARGS...)`
            run(cmd)
            return 0
        end
    end

    if length(ARGS) > 0

        # Check for --threads or -t flag
        i = 1
        while i <= length(ARGS)
            if (ARGS[i] == "--threads" || ARGS[i] == "-t") && i < length(ARGS)
                nstr = ARGS[i+1]
                if nstr == "auto"
                    n = Sys.CPU_THREADS
                else
                    n = parse(Int, nstr)
                end
                if Threads.nthreads() != n
                    println("Restarting with $n threads...")
                    # Remove the thread flag and its value from ARGS for restart
                    new_args = copy(ARGS)
                    splice!(new_args, i:i+1)
                    cmd = `$(Base.julia_cmd()) -t $n -m MAGEMinApp $(new_args...)`
                    run(cmd)
                    return 0
                end
            end
            i += 1
        end

        x = popfirst!(ARGS)
        if x == "run"
            println("Running MAGEMinApp, wait a bit...")
            App(; host = HTTP.Sockets.localhost, port = 8050, max_num_user=10, debug=false)
        end
    end

    return 0
end

@static if isdefined(Base, Symbol("@main"))
    @main
end

end


