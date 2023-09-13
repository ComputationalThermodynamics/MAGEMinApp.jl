using ReadVTK, Dash, DashVtk, DashHtmlComponents, Delaunay


filepath ="cow-nonormals2.txt"
txt_content = read(filepath, String);
content = vtk_view([
    vtk_geometryrepresentation([
        vtk_reader(
            vtkClass="vtkOBJReader",
            parseAsText=txt_content,
        ),

    ]),
]);
# Dash setup
app = dash()

app.layout = html_div(
    style=Dict("width" => "50%", "height" => "400px"),
    children=[content],
);

run_server(app, "0.0.0.0", debug = true)


# points=[
# 0,0,0,
# 1,0,0,
# 0,1,0,
# 1,1,0,
# ],

# import dash_vtk

# # Get it here: https://github.com/plotly/dash-vtk/blob/master/demos/data/cow-nonormals.obj
# obj_file = "datasets/cow-nonormals.obj"


# txt_content = None
# with open(obj_file, 'r') as file:
#   txt_content = file.read()

# content = dash_vtk.View([
#     dash_vtk.GeometryRepresentation([
#         dash_vtk.Reader(
#             vtkClass="vtkOBJReader",
#             parseAsText=txt_content,
#         ),
#     ]),