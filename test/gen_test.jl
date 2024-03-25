
using MAGEMin_C
using MAGEMinApp
using PlotlyJS

pkg_dir = Base.pkgdir(MAGEMinApp)

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

println("  Test P-T diagram computation")
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
                                                0,
                                                "ph"    )

res = "";
res *= "results = [";
for i=1:15
	res *=" $(Out_XY[i].G_system);";
end
res *=" $(Out_XY[16].G_system)";
res *="]";

print("$res\n")

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
                                                            0,
                                                            "ph", 
                                                            ind_map         = ind_map,
                                                            Out_XY_old      = Out_XY  ) # recompute points that have not been computed before

res = "";
res *= "results = [";
for i=1:63
	res *=" $(Out_XY[i].G_system);";
end
res *=" $(Out_XY[64].G_system)";
res *="]";

print("$res\n")