
# This creates the cross-section plot
function diagram_plot(db)

    layout  = AppData.default_diagram_layout

    fig = plot(db, layout)

    dcc_graph(
                id          = "phase-diagram",
                figure      = fig,
            )
end
