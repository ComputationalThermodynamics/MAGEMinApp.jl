
# This creates the cross-section plot
function diagram_plot()

    fig = plot()

    dcc_graph(
                id          = "phase-diagram",
                figure      = fig,
            )
end

function PTX_plot()

    fig =  plot(    Layout( height= 320 ))

    dcc_graph(
                id          = "ptx-plot",
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