global AppData

dark_diagram_layout = Layout(
    title=attr(
        text= "Phase diagram",
        y=0.95,
        x=0.5,
        xanchor= "center",
        yanchor= "top",
        font_color  = "#FFF",
        font_size = 18.0  ),
        barmode="stack",
    # xaxis_gridcolor   = "#282828",
    # yaxis_gridcolor   = "#393939",
    plot_bgcolor  = "#282828",
    paper_bgcolor = "#282828",
    font_color = "#FFF",
    xaxis_title= ""
)

default_diagram_layout = Layout(
    title=attr(
        text= "Phase diagram",
        y=0.95,
        x=0.5,
        xanchor= "center",
        yanchor= "top",
        font_color  = "#000000",
        font_size = 18.0  ),
    barmode="stack",
    # xaxis_gridcolor   = "#F0F0F0",
    # yaxis_gridcolor   = "#E8E8E8",
    plot_bgcolor  = "#F0F0F0",
    paper_bgcolor = "#F0F0F0",
    font_color = "#000000",
    xaxis_title= ""
)

AppData = ( dark_diagram_layout       = dark_diagram_layout,
            default_diagram_layout    = default_diagram_layout         )