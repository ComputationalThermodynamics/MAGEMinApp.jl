using PyCall
go = pyimport("plotly.graph_objects")
subplots = pyimport("plotly.subplots")

z1, z2, z3 = rand(7,7),rand(7,7),rand(7,7)
customdata = [z2; z3]
fig = subplots.make_subplots(1, 2, subplot_titles=["z1", "z2"])
fig.add_trace(go.Heatmap(
    z=z1,
    customdata=[z2; z3],
    hovertemplate="<b>z1:%{z:.3f}</b><br>z2:%{customdata[0]:.3f} <br>z3: %{customdata[1]:.3f} ",
    coloraxis="coloraxis1", name=""),
    1, 1)
fig.add_trace(go.Heatmap(
    z=z2,
    customdata=[z1; z3],
    hovertemplate="z1:%{customdata[0]:.3f} <br><b>z2:%{z:.3f}</b><br>z3: %{customdata[1]:.3f} ",
    coloraxis="coloraxis1", name=""),
    1, 2)
fig.update_layout(title_text="Hover to see the value of z1, z2 and z3 together")
fig.show()