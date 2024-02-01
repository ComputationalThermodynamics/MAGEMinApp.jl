using Test

using MAGEMin_C
using MAGEMin_app
using PlotlyJS

pkg_dir = Base.pkgdir(MAGEMin_app)

include(joinpath(pkg_dir,"src","initialize_MAGEMin_AMR.jl"))
include(joinpath(pkg_dir,"src","PhaseDiagram_functions.jl"))

# Initialite AMR
COMM            = Initialize_AMR()

# Create coarse mesh
cmesh           = t8_cmesh_quad_2d(MPI.COMM_WORLD, [600.0,1400.0], [2.0,20.0])

# Refine coarse mesh (in a regular manner)
level           = 2
forest          = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, MPI.COMM_WORLD)
data            = get_element_data(forest)

MAGEMin_data    = Initialize_MAGEMin(   "ig";
                                        verbose     = false    );

# bulk-rock composition is KLB1
bulk            = [0.38451319035870185, 0.017740308257833806, 0.028208688355924924, 0.5050993397328966, 0.0587947378409965, 9.988912307338855e-5, 0.0024972280768347137, 0.0009988912307338856, 0.0009589355815045301, 0.0010887914414999351, 0.0]
oxides          = ["SiO2", "Al2O3", "CaO", "MgO", "FeO", "K2O", "Na2O", "TiO2", "O", "Cr2O3", "H2O"]

# test low resolution grid computation
Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  data, 
                                                MAGEMin_data,
                                                "pt",
                                                0.0,
                                                0.0,
                                                oxides,
                                                bulk,
                                                bulk,
                                                "NONE",
                                                0.0,
                                                0.0,
                                                "ph"    )

# test refinenement
for irefine = 1:2
    refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
    forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    t = @elapsed Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(  data_new,
                                                                MAGEMin_data,
                                                                "pt",
                                                                0.0,
                                                                0.0,
                                                                oxides,
                                                                bulk,
                                                                bulk,
                                                                "NONE",
                                                                0.0,
                                                                0.0,
                                                                "ph", 
                                                                ind_map         = ind_map,
                                                                Out_XY_old      = Out_XY,
                                                                n_phase_XY_old  = n_phase_XY    ) # recompute points that have not been computed before

    data    = data_new
    forest  = forest_new
end

# @test out.G_system ≈ -797.7491824683576
# @test out.ph == ["opx", "ol", "cpx", "spn"]
# @test all(abs.(out.ph_frac - [ 0.24226960158631541, 0.5880694152724345, 0.1416697366114075,  0.027991246529842587])  .< 1e-4)

# # print more detailed info about this point:
# print_info(out)

for i = 1:Threads.nthreads()
    finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
end

