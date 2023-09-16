# first integration with MAGEMin (through the MAGEMin_C interface)

using MPI
using T8code
using T8code.Libt8: sc_init
using T8code.Libt8: sc_finalize
using T8code.Libt8: SC_LP_ESSENTIAL, SC_LP_DEBUG
using T8code.Libt8: SC_LP_PRODUCTION


using StaticArrays, Statistics
using MAGEMin_C

include("./AMR/AMR_utils.jl")
include("./colormaps.jl")
colormaps   = read_colormaps() 

# Initialize MPI. This has to happen before we initialize sc or t8code.
if !MPI.Initialized()
    mpiret  = MPI.Init()
    comm    = MPI.COMM_WORLD.val
end

t8code_package_id = t8_get_package_id()
if t8code_package_id<0
    # Initialize the sc library, has to happen before we initialize t8code.
    sc_init(comm, 1, 1, C_NULL, SC_LP_ESSENTIAL)
    
     # Initialize t8code with log level SC_LP_PRODUCTION. See sc.h for more info on the log levels.
    t8_init(SC_LP_PRODUCTION)

    T8code.Libt8.p4est_init(C_NULL, SC_LP_PRODUCTION)
end


# Create coarse mesh
Prange  = (0,50)
Trange  = (800,2000)        # in Paraview it looks a bit weird with actual values
cmesh   = t8_cmesh_quad_2d(comm, Trange, Prange)

# Refine coarse mesh (in a regular manner)
level   = 3
forest  = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, comm)
data    = get_element_data(forest);



# MAGEMin optimizations:
function Calculate_MAGEMin(data; ind_map=nothing, Out_PT_old=nothing, n_phase_old=nothing)
    if isnothing(ind_map)
        ind_map = -ones(length(data.xc));
    end

    Out_PT = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.x))
    Hash_PT = Vector{UInt64}(undef,length(data.x))
    n_phase = Vector{Int64}(undef,length(data.x))

    db          = "ig"  # database: ig, igneous (Holland et al., 2018); mp, metapelite (White et al 2014b)
    gv, z_b, DB, splx_data      = init_MAGEMin(db);

    test        = 0;
    sys_in      = "mol"     #default is mol, if wt is provided conversion will be done internally (MAGEMin works on mol basis)
    gv          = use_predefined_bulk_rock(gv, test, db);

    for i=1:length(data.x)
        if ind_map[i]< 0

            P = data.yc[i]
            T = data.xc[i]
            Out_PT[i] = point_wise_minimization(P,T, gv, z_b, DB, splx_data, sys_in)

            if mod(128,i) == 0
                GC.gc()
            end

        else
            # This Pointy already exist; transfer data from old array
            Out_PT[i]   = Out_PT_old[ind_map[i]]
        end

    end

    finalize_MAGEMin(gv,DB)

    # Compute has
    for i=1:length(data.x)
        Hash_PT[i]  = hash(sort(Out_PT[i].ph))
        n_phase[i]     = length(Out_PT[i].ph)
    end

    return Out_PT, Hash_PT, n_phase

end


# initial optimization on regular grid
Out_PT, Hash_PT, n_phase = Calculate_MAGEMin(data)


# Refine the mesh along a curve
for irefine = 1:3
    global forest, data, Hash_PT, Out_PT, n_phase

    refine_elements                 = refine_phase_boundaries(forest, Hash_PT);

    # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    forest_new, data_new, ind_map   = adapt_forest(forest, refine_elements, data)

    # recompute points that have not been computed before
    Out_PT, Hash_PT, n_phase        = Calculate_MAGEMin(data_new, ind_map=ind_map, Out_PT_old=Out_PT, n_phase_old=n_phase)

    data    = data_new
    forest  = forest_new
end


# Write as vtk
# t8_forest_write_vtk(forest, "AMR_ex5_quad")


# Scatter plotly of the grid
using PlotlyJS

idx = Vector{Int64}(undef,length(n_phase))
idx = ((n_phase.-minimum(n_phase))./(maximum(n_phase).-minimum(n_phase)).*255).+ 1.0;
idx = [floor(Int,x) for x in idx]

data_plot = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, length(data.x))
for i = 1:length(data.x)

        data_plot[i] = scatter( x           = data.x[i],
                                y           = data.y[i],
                                mode        = "lines",

                                fill        = "toself",
                                fillcolor   = colormaps.roma[idx[i]][2],
                                line_color  = "#FFF",
                                line_width  = 0.0,

        # customize what is shown upon hover:
        text        = "Stable phases $(Out_PT[i].ph) ",
        hoverinfo   = "text",
        showlegend  = false)
end

plot(data_plot, 
        Layout(
                title=attr(
                    text        = "KLB",
                    x           = 0.5,
                    xanchor     = "center",
                    yanchor     = "top"
                ),
                xaxis_title     = "Temperature [Celcius]",
                yaxis_title     = "Pressure [kbar]",
                yaxis_range     = [Prange...],
                xaxis_range     = [Trange...],
                xaxis_showgrid  = false,
                yaxis_showgrid  = false,
            )
)

