# This creates the cross-section plot

function progress_bar_fig(; percent=0, an1="", an2="")

    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,2)

    annotations[1] =   attr(            xref        = "paper",
                                        yref        = "paper",
                                        align       = "left",
                                        valign      = "top",
                                        x           = 0.0,
                                        y           = 0.0,
                                        yshift      = 11,
                                        text        = an1,
                                        showarrow   = false,
                                        clicktoshow = false,
                                        visible     = true,
                                        font        = attr( size = 10),
                                        )

    annotations[2] =   attr(            xref        = "paper",
                                        yref        = "paper",
                                        align       = "left",
                                        valign      = "top",
                                        x           = 0.0,
                                        y           = 0.0,
                                        yshift      = -16,
                                        text        = an2,
                                        showarrow   = false,
                                        clicktoshow = false,
                                        visible     = true,
                                        font        = attr( size = 10),
                                        )

    fig = plot(Layout(      
                            height              = 38,   
                            # width               = 256,
                            plot_bgcolor        = "white", 
                            paper_bgcolor       = "white", 

                            title               = "",
                            xaxis=attr(
                                range           =  [0,100],
                                showgrid        =    false,
                                zeroline        =    false,
                                showticklabels  =    false,
                                linecolor       =   "rgba(0,0,0,0)"
                            ),
                            yaxis=attr(
                                range           =  [0,1],
                                showgrid        =    false,
                                zeroline        =    false,
                                showticklabels  =    false,
                                linecolor       =   "rgba(0,0,0,0)"
                            ),
                            # autosize    = false,
                            margin      = attr(autoexpand = false, l=0, r=0, b=13, t=13, pad=0),
                            annotations = annotations,
                            shapes=[
                                rect(
                                    x0=0, y0=0, x1=100, y1=1,
                                    line=attr(
                                        color="rgba(225, 225, 225, 0.66)",
                                        width=1,
                                    ),
                                    fillcolor="rgba(225, 225, 225, 0.66)",
                                    xref='x', yref='y'
                                ),
                        
                                rect(
                                    x0=0, y0=0, x1=percent, y1=1,
                                    line=attr(
                                        color="#d3f2ce",
                                        width=1,
                                    ),
                                    fillcolor="#d3f2ce",
                                    xref='x', yref='y'
                                )
                            ]
            ))
    return fig
end

function diagram_progress_bar()
    fig = progress_bar_fig()
    dcc_graph(
                id          = "pd-progress-bar",
                figure      = fig,
                config      = Dict("displayModeBar" => false, "staticPlot" => true)
            )
end

function diagram_legend()

    fig = plot(Layout(      height          =  30,        
                            plot_bgcolor    = "white", 
                            paper_bgcolor   = "white", 
                            title           = "",
                            xaxis           = attr(showticklabels=false),
                            yaxis           = attr(showticklabels=false),    ))

    dcc_graph(
                id          = "pd-legend",
                figure      = fig,
            )
end

function diagram_legend_te()

    fig = plot(Layout(      height          =  30,        
                            plot_bgcolor    = "white", 
                            paper_bgcolor   = "white", 
                            title           = "",
                            xaxis           = attr(showticklabels=false),
                            yaxis           = attr(showticklabels=false),    ))

    dcc_graph(
                id          = "pd-legend-te",
                figure      = fig,
            )
end
function diagram_plot()

    fig = plot()

    dcc_graph(
                id          = "phase-diagram",
                figure      = fig,
            )
end
function pie_plot()

    fig = plot( Layout( height= 220 ) )

    dcc_graph(
                id          = "pie-diagram",
                figure      = fig,
            )
end

function diagram_plot_te()

    fig = plot()

    dcc_graph(
                id          = "phase-diagram-te",
                figure      = fig,
            )
end

function spectrum_plot_te()


    fig = plot(     Layout( height= 220 ))

    dcc_graph(
                id          = "ree-spectrum-te",
                figure      = fig,
            )
end
function PTX_frac_plot()

    fig =  plot(    Layout( height= 360 ))

    dcc_graph(
                id          = "ptx-frac-plot",
                figure      = fig,
            )
end


function PTX_plot()

    fig =  plot(    Layout( height= 360 ))

    dcc_graph(
                id          = "ptx-plot",
                figure      = fig,
            )
end

function TAS_plot()

    fig =  plot(    Layout(     width       = 740,
                                height      = 400 ))

    dcc_graph(
                id          = "TAS-plot",
                figure      = fig,
            )
end

function TAS_plot_pd()

    fig =  plot(    Layout(     width       = 640,
                                height      = 400 ))

    dcc_graph(
                id          = "TAS-plot-pd",
                figure      = fig,
            )
end

function AFM_plot_pd()

    fig =  plot(    Layout(     width       = 640,
                                height      = 400 ))

    dcc_graph(
                id          = "AFM-plot-pd",
                figure      = fig,
            )
end

function isoS_frac_plot()

    fig =  plot(    Layout( height= 360 ))

    dcc_graph(
                id          = "isoS-frac-plot",
                figure      = fig,
            )
end


function isoS_plot()

    fig =  plot(    Layout( height= 360 ))

    dcc_graph(
                id          = "isoS-plot",
                figure      = fig,
            )
end


function path_plot()

    fig = plot(    Layout( height= 220 ))

    dcc_graph(
                id          = "path-plot",
                figure      = fig,
            )
end

function path_isoS_plot()

    fig = plot(    Layout( height= 220 ))

    dcc_graph(
                id          = "path-isoS-plot",
                figure      = fig,
            )
end

"""
    plot_diagram(data_plot,layout)

Plots the phase diagram along with info in the REPL
"""
function plot_diagram(data_plot,layout)

    print("Updating plot ..."); t0 = time()     
    fig = plot(data_plot,layout)
    print("\rUpdated plots in $(round(time()-t0,digits=2)) seconds \n\n")           

    return fig
end

