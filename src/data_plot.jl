
# This creates the cross-section plot
function diagram_plot()

    fig = plot()

    dcc_graph(
                id          = "phase-diagram",
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