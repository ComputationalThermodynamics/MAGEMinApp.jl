
# This creates the cross-section plot
function diagram_plot()

    fig = plot()

    dcc_graph(
                id          = "phase-diagram",
                figure      = fig,
            )
end

function PTX_plot()

    fig = plot()

    dcc_graph(
                id          = "ptx-plot",
                figure      = fig,
            )
end

function path_plot()

    fig = plot()

    dcc_graph(
                id          = "path-plot",
                figure      = fig,
            )
end
