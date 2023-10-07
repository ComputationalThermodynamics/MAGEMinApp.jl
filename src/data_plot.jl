
# This creates the cross-section plot
function diagram_plot()

    fig = plot()

    dcc_graph(
                id          = "phase-diagram",
                figure      = fig,
            )
end
