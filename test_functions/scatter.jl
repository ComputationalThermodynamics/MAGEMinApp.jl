# MWE to generate a 2D unstructured mesh with field(s) attached to it.
# Here we use plotly and scatter

include("scatter_functions.jl")

np   = 2048;              #number of points to be triangulated
data = generator_scatter_traces();

plot(data, Layout(;height=768, width=1024, showlegend=false))

@benchmark plot(data, Layout(;height=768, width=1024, showlegend=false))

