
# This creates the cross-section plot
function diagram_plot()

    fig = plot()

    dcc_graph(
                id          = "phase-diagram",
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

    layout_ree      =  Layout(
        font        = attr(size = 10),
        height      =  220,
        width       =  900,
        margin      = attr(autoexpand = false, l=12, r=16, b=8, t=32),
        autosize    = false,
        xaxis_title = "Rare Earth Element",
        yaxis_title = "Concentration [μg/g]",
        showlegend  = false,
    )

    fig = plot(layout_ree)

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

