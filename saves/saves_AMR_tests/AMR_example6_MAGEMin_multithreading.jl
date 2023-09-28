# coupling T8Code with multithreaded MAGEMin

using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ERROR, SC_LP_PRODUCTION, SC_LP_ESSENTIAL, SC_LP_DEBUG
using Statistics
using StaticArrays

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
MAGEMin_db = Initialize_MAGEMin("ig"; verbose = false) # only need to do this once/simulation

# Create coarse mesh
Prange  = (0.01,24.01)
Trange  = (800,1400)        # in Paraview it looks a bit weird with actual values
cmesh   = t8_cmesh_quad_2d(COMM, Trange, Prange)

# Refine coarse mesh (in a regular manner)
level   = 3
forest  = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, COMM)

data   = get_element_data(forest)

# MAGEMin optimizations:
# We will have to generalize this for chemistry
function Calculate_MAGEMin(data, MAGEMin_db::DataBase_DATA; ind_map=nothing, Out_PT_old=nothing, n_phase_PT_old=nothing)
    if isnothing(ind_map)
        ind_map = -ones(length(data.xc));
    end

    Out_PT = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.x))

    # Step 1: determine all points that have not been computed yet
    ind_new = findall( ind_map.< 0)
    n_new_points = length(ind_new)
    Out_PT_new   = []
    if n_new_points>0

        # create list of P/T values
        # (NOTE: if we later want to change chemistry as well, we will need to create a chemistry vector)
        Pvec = zeros(Float64,n_new_points)
        Tvec = zeros(Float64,n_new_points)
        for (i, new_ind) = enumerate(ind_new)
            Pvec[i] = data.yc[new_ind]
            Tvec[i] = data.xc[new_ind]
        end

        # compute, using multithreading
        Out_PT_new = Calculate_MAGEMin(Pvec, Tvec, MAGEMin_db)
    end

    # Step 2: Collect new and old results
    new_point = 0;
    for (i, map) = enumerate(ind_map)
        if map>0
            Out_PT[i] = Out_PT_old[map]
        else
            new_point += 1
            Out_PT[i] = Out_PT_new[new_point]
        end
    end

    Out_PT_new =[]

    # Compute hash for all points
    Hash_PT     = Vector{UInt64}(undef,length(data.x))
    n_phase_PT  = Vector{UInt64}(undef,length(data.x))
    for i=1:length(data.x)
        Hash_PT[i] = hash(sort(Out_PT[i].ph))
        n_phase_PT[i] = length(Out_PT[i].ph)
    end

    return Out_PT, Hash_PT, n_phase_PT
end


# initial optimization on regular grid
Out_PT, Hash_PT, n_phase_PT = Calculate_MAGEMin(data, MAGEMin_db)

# Refine the mesh along phase boundaries
for irefine = 1:5
    global forest, data, Hash_PT, Out_PT, n_phase_PT

    refine_elements   = refine_phase_boundaries(forest, Hash_PT);

    # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    forest_new, data_new, ind_map  = adapt_forest(forest, refine_elements, data)

    # recompute points that have not been computed before
    t = @elapsed Out_PT, Hash_PT, n_phase_PT = Calculate_MAGEMin(data_new, MAGEMin_db, ind_map=ind_map, Out_PT_old=Out_PT, n_phase_PT_old=n_phase_PT)

    println("Computed $(length(ind_map.<0)) new points in $t seconds")
    data = data_new
    forest = forest_new
end


# Write as vtk
# t8_forest_write_vtk(forest, "AMR_ex5_quad")


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

