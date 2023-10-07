# MWE to generate a 2D unstructured mesh with field(s) attached to it.
# This example uses Delaunay triangulation to generate a list of faces and vertices and arbitrary scalar fields
# The generated mesh is then formatted to a vtk_polydata format
# colorBar cannot be displayed natively with Dash-vtk.jl (although the master version of the python version has this option)
# cannot set position of the camera closer :/
# cannot display axis grid?


include("vtk_functions.jl")

np      = 1000;
c       = rand(np, 2);
mesh    = delaunay(c);

points, lines, polys, vertc, vertbw = get_mesh_data(mesh)


content = vtk_view([

    vtk_geometryrepresentation([
        vtk_polydata(
            points      = points,
            polys       = polys,
            children    = [
                vtk_pointdata([
                    vtk_dataarray(
                        registration="setScalars", # To activate field
                        name="onPoints",
                        values=vertc,
                    )
                ]),

            ],
        ),
    ],

    colorDataRange = [0,1],
    colorMapPreset = "Cool to Warm (Extended)", 

    ),

    vtk_geometryrepresentation([
        vtk_polydata(
            points      = points,
            lines       = lines,
            children    = [
                vtk_pointdata([
                    vtk_dataarray(
                        registration="setScalars", # To activate field
                        name="onPoints",
                        values=vertbw,
                    )
                ]),

            ],
        ),
    ],

    colorDataRange = [0,1],
    colorMapPreset = "Grayscale", 

    ),
], 
id="vtk-view",
background=[0.9,0.9,0.9],               # RGB array of floating point values between 0 and 1.
cameraParallelProjection=false,         # Should we see our 3D work with perspective or flat with no depth perception
pickingModes=["click","hover"],
interactorSettings=[(button=1, action= ""),
                    (button=3, action= "Zoom", scrollEnabled=true),
                    (button=1, action= "Pan",   shift=true)         ], 
);

# Dash setup
app = dash()

app.layout = html_div(
    style=Dict("width" => "800px", "height" => "800px"),
    children=[content],
);

run_server(app, "0.0.0.0", debug = true)






# vtk_view(
#   id="vtk-view",
#   background=[0, 0, 0],           # RGB array of floating point values between 0 and 1.
#   interactorSettings=[...],       # Binding of mouse events to camera action (Rotate, Pan, Zoom...)
#   cameraPosition=[x,y,z],         # Where the camera should be initially placed in 3D world
#   cameraViewUp=[dx, dy, dz],      # Vector to use as your view up for your initial camera
#   cameraParallelProjection=false, # Should we see our 3D work with perspective or flat with no depth perception
#   triggerRender=0,                # Timestamp meant to trigger a render when different
#   triggerResetCamera=0,           # Timestamp meant to trigger a reset camera when different
#   # clickInfo,                    # Read-only property to retrieve picked representation id and picking information
#   # hoverInfo                     # Read-only property to retrieve picked representation id and picking information
# )


# vtk_celldata([
#     vtk_dataarray(
#         registration    = "setScalars", # To activate field
#         name            = "onCells",
#         values          = cellV,
#     )
# ]),

# interactorSettings=[
#   {
#     button: 1,
#     action: "Rotate",
#   }, {
#     button: 2,
#     action: "Pan",
#   }, {
#     button: 3,
#     action: "Zoom",
#     scrollEnabled: true,
#   }, {
#     button: 1,
#     action: "Pan",
#     shift: true,
#   }, {
#     button: 1,
#     action: "Zoom",
#     alt: true,
#   }, {
#     button: 1,
#     action: "ZoomToMouse",
#     control: true,
#   }, {
#     button: 1,
#     action: "Roll",
#     alt: true,
#     shift: true,
#   }
# ],