# coupling T8Code with multithreaded MAGEMin
using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ERROR, SC_LP_PRODUCTION, SC_LP_ESSENTIAL, SC_LP_DEBUG
using Statistics
using StaticArrays

# using Pkg
# MAGEMin_dir = "../TC_calibration"
# Pkg.activate(MAGEMin_dir)
# Pkg.offline(true)
using MAGEMin_C

include("./AMR_utils.jl")
include("./MAGEMiN_utils.jl")
include("../colormaps.jl")

colormaps = read_colormaps(dir_colormaps = "../assets/colormaps/")

# Initialize MPI. This has to happen before we initialize sc or t8code.
if !MPI.Initialized()
    mpiret  = MPI.Init(threadlevel = MPI.THREAD_FUNNELED, finalize_atexit = true)
    @assert mpiret>=MPI.THREAD_FUNNELED "MPI library with insufficient threading support"
end

const COMM = MPI.COMM_WORLD

t8code_package_id = t8_get_package_id()
if t8code_package_id<0
    # Initialize the sc library, has to happen before we initialize t8code.
    sc_init(COMM, 1, 1, C_NULL, SC_LP_ERROR)

    if T8code.Libt8.p4est_is_initialized() == 0
        T8code.Libt8.p4est_init(C_NULL, SC_LP_ERROR)
    end

    t8_init(SC_LP_ERROR)
end

# Initialize MAGEMin:
db              =   "ig" 
MAGEMin_data    =   Initialize_MAGEMin(db, verbose=false);

# Create coarse mesh
Prange      = (0.01,24.01)
Trange      = (800,1400)        # in Paraview it looks a bit weird with actual values
cmesh       = t8_cmesh_quad_2d(COMM, Trange, Prange)

# Refine coarse mesh (in a regular manner)
level       = 3
forest      = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, COMM)
data        = get_element_data(forest)


# initial optimization on regular grid
Out_PT, Hash_PT, n_phase_PT = refine_MAGEMin(data, MAGEMin_data)

# Refine the mesh along phase boundaries
for irefine = 1:2
    global forest, data, Hash_PT, Out_PT, n_phase_PT

    refine_elements                          = refine_phase_boundaries(forest, Hash_PT);
    forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    t = @elapsed Out_PT, Hash_PT, n_phase_PT = refine_MAGEMin(data_new, MAGEMin_data, ind_map=ind_map, Out_PT_old=Out_PT, n_phase_PT_old=n_phase_PT) # recompute points that have not been computed before

    println("Computed $(length(ind_map.<0)) new points in $t seconds")
    data    = data_new
    forest  = forest_new
end

# Scatter plotly of the grid
using PlotlyJS
idx         = Vector{Int64}(undef,length(n_phase_PT));
idx         = ((n_phase_PT.-minimum(n_phase_PT))./(maximum(n_phase_PT).-minimum(n_phase_PT)).*224).+ 32.0;
idx         = [floor(Int,x) for x in idx];
data_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, length(data.x));

for i = 1:length(data.x)
        data_plot[i] = scatter( x           = data.x[i],
                                y           = data.y[i],
                                mode        = "lines",
                                fill        = "toself",
                                fillcolor   = colormaps.roma[idx[i]][2],
                                line_color  = "#000000",
                                line_width  = 1.0,

        # customize what is shown upon hover:
        text        = "Stable phases $(Out_PT[i].ph) ",
        hoverinfo   = "text",
        showlegend  = false     )
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

