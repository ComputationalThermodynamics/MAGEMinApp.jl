
using MAGEMin_C
using MAGEMinApp
using PlotlyJS
using ProgressMeter

pkg_dir = Base.pkgdir(MAGEMinApp)

include(joinpath(pkg_dir,"src","AMR/AMR_utils.jl"))
include(joinpath(pkg_dir,"src","AMR/MAGEMin_utils.jl"))
include(joinpath(pkg_dir,"src","PhaseDiagram_functions.jl"))

level           = 2
data = init_AMR([600.0,1400.0], [2.0,20.0],level)

MAGEMin_data    = Initialize_MAGEMin(   "ig";
                                        verbose     = false    );

# bulk-rock composition is KLB1
bulk            = [0.38451319035870185, 0.017740308257833806, 0.028208688355924924, 0.5050993397328966, 0.0587947378409965, 9.988912307338855e-5, 0.0024972280768347137, 0.0009988912307338856, 0.0009589355815045301, 0.0010887914414999351, 0.0]
oxides          = ["SiO2", "Al2O3", "CaO", "MgO", "FeO", "K2O", "Na2O", "TiO2", "O", "Cr2O3", "H2O"]

println("  Test P-T diagram computation")
global Out_XY =  Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,0)
Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  data, 
                                                MAGEMin_data,
                                                "pt",
                                                0.0,
                                                nothing,
                                                false,
                                                0.0,
                                                0.0,
                                                101.0,
                                                101.0,
                                                0.0,
                                                0.0,
                                                oxides,
                                                bulk,
                                                bulk,
                                                "NONE",
                                                0.0,
                                                0.0,
                                                0,
                                                false,
                                                "ph",
                                                nothing,
                                                nothing    )

res = "";
res *= "results = [";
for i=1:24
	res *=" $(Out_XY[i].G_system);";
end
res *=" $(Out_XY[25].G_system)";
res *="]";

print("$res\n")
data    = select_cells_to_split_and_keep(data)
data    = perform_AMR(data)

Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(   data,
                                                MAGEMin_data,
                                                "pt",
                                                0.0,
                                                nothing,
                                                false,
                                                0.0,
                                                0.0,
                                                101.0,
                                                101.0,
                                                0.0,
                                                0.0,
                                                oxides,
                                                bulk,
                                                bulk,
                                                "NONE",
                                                0.0,
                                                0.0,
                                                0,
                                                false,
                                                "ph",
                                                nothing,
                                                nothing ) # recompute points that have not been computed before


res = "";
res *= "results = [";
for i=1:80
	res *=" $(Out_XY[i].G_system);";
end
res *=" $(Out_XY[81].G_system)";
res *="]";

print("$res\n")