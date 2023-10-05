# Does a refinement and plots the results with Plotly

using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ESSENTIAL, SC_LP_DEBUG
using T8code.Libt8: SC_LP_PRODUCTION


using StaticArrays, Statistics


include("./AMR_utils.jl")


# Initialize MPI. This has to happen before we initialize sc or t8code.
if !MPI.Initialized()
    mpiret  = MPI.Init()
    comm    = MPI.COMM_WORLD.val
end

t8code_package_id = t8_get_package_id()
if t8code_package_id<0
    # Initialize the sc library, has to happen before we initialize t8code.
    # It is important to set the second argument `catch_signals` to 0.
    # Otherwise, we get segfaults using multiple threads when running the GC.
    sc_init(comm, 0, 1, C_NULL, SC_LP_ESSENTIAL)

     # Initialize t8code with log level SC_LP_PRODUCTION. See sc.h for more info on the log levels.
    t8_init(SC_LP_PRODUCTION)

    T8code.Libt8.p4est_init(C_NULL, SC_LP_PRODUCTION)
end


# Create coarse mesh
Prange  = (0,50)
Trange  = (800,2000)        # in Paraview it looks a bit weird with actual values
cmesh   = t8_cmesh_quad_2d(comm, Trange, Prange)

# Refine coarse mesh (in a regular manner)
level   = 4
forest  = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, comm)

#
dPdT = diff([Prange...])[1]./diff([Trange...])[1]

#P = Trange.*dPdT + Prange[1]




# Refine the mesh along a curve
data   = get_element_data(forest);
Phase_ID    = Cint.(data.xc*dPdT .+ Prange[1] .> data.yc)
for irefine = 1:5
    global forest, data, Phase_ID

    refine_elements   = refine_phase_boundaries(forest, Phase_ID);

    # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    forest, data, ind_map  = adapt_forest(forest, refine_elements, data)

    Phase_ID    = Cint.((data.xc.-700)*dPdT .+ Prange[1] .> data.yc)

end

Phase_ID    = Cint.((data.xc.-700)*dPdT .+ Prange[1] .> data.yc)

# Write as vtk
t8_forest_write_vtk(forest, "AMR_ex4_quad")


# Scatter plotly of the grid
using PlotlyJS

data_plot = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, length(data.x))
for i = 1:length(data.x)


  data_plot[i] = scatter(x=data.x[i], y=data.y[i], mode="lines",
        fill="toself",fillcolor=Phase_ID[i], line_color="#000000", line_width=0.5,

        # customize what is shown upon hover:
        text ="Stable phases $(Phase_ID[i]) ",
        hoverinfo="text",

        showlegend=false)
end

plot(data_plot,
        Layout(
                title=attr(
                    text= "KLB",
                    x=0.5,
                    xanchor= "center",
                    yanchor= "top"
                ),
                xaxis_title="Temperature [Celcius]",
                yaxis_title="Pressure [kbar]",
                yaxis_range=[Prange...],
                xaxis_range=[Trange...],
                xaxis_showgrid=false, yaxis_showgrid=false,
            )
)
