using Test

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
@test length(Out_XY) == 16

results = [ -793.507476796513; -814.5314225719396; -786.4198598213416; -807.3608185564824; -837.7454922302667; -863.1027328483825; -830.5026234026736; -855.661064809689; -779.4056071550851; -800.2904063921558; -772.4548395043978; -793.271877227124; -823.3720345214499; -848.3891117825796; -816.279035791287; -841.228711264553]
for i = 1:16
    @test Out_XY[i].G_system ≈ results[i] rtol=1e-4
end


println("  Test refinement")
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
                                                            Out_XY_old      = Out_XY,
                                                            n_phase_XY_old  = n_phase_XY    ) # recompute points that have not been computed before

@test length(Out_XY) == 64

results = [ -790.4267196379019; -800.3409818959834; -786.8481933432261; -796.745728817367; -810.8654434334738; -821.955483431904; -807.2557154616948; -818.3322300046119; -783.3228996774053; -793.19328390195; -779.8140561269354; -789.6712250684224; -803.6774303024056; -814.7339608920137; -800.1404907867277; -811.1772369839407; -833.5735383870104; -845.6863873242623; -829.9361700343524; -842.0345181362214; -858.3752970290502; -871.7471266123807; -854.6482904551569; -867.9493234709076; -826.3209698642268; -838.4035784155129; -822.7433337221067; -834.8059340964213; -850.9782760747914; -864.1956718164059; -847.3497703291739; -860.4792601541598; -776.3123603071622; -786.1563107039786; -772.8291124317228; -782.6553973379239; -796.6121514685193; -807.635097102906; -793.0932919409626; -804.1003617169694; -769.3615579628517; -779.1731775954312; -765.9039062755974; -775.7021369554749; -789.5945398954112; -800.5819503527028; -786.1090799158005; -797.080713007881; -819.1870214026693; -831.2350856887427; -815.6383091697091; -827.6720476994808; -843.7514796680523; -856.7927845078791; -840.1732397350237; -853.1452630669069; -812.0989389397299; -824.1166970731238; -808.5794137176711; -820.5741152892948; -836.6034728197689; -849.5357533047683; -833.0414777162564; -845.9564466070392]
for i = 1:64
    @test Out_XY[i].G_system ≈ results[i] rtol=1e-4
end

for i = 1:Threads.nthreads()
    finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
end

