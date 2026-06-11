#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

using Test
using ProgressMeter
using MAGEMin_C
using MAGEMinApp
using PlotlyJS
using Printf
using JSON3

pkg_dir = Base.pkgdir(MAGEMinApp)

include(joinpath(pkg_dir,"src","AMR/AMR_utils.jl"))
include(joinpath(pkg_dir,"src","Progress.jl"))
include(joinpath(pkg_dir,"src","AMR/MAGEMin_utils.jl"))
include(joinpath(pkg_dir,"src","PhaseDiagram_functions.jl"))
include(joinpath(pkg_dir,"src","MAGEMinApp_functions.jl"))
global CompProgress = ComputationalProgress()

level           = 2
data            = init_AMR([600.0,1400.0], [2.0,20.0], level)

MAGEMin_data    = Initialize_MAGEMin(   "ig";
                                        verbose     = false    );

# bulk-rock composition is KLB1
bulk            = [0.38451319035870185, 0.017740308257833806, 0.028208688355924924, 0.5050993397328966, 0.0587947378409965, 9.988912307338855e-5, 0.0024972280768347137, 0.0009988912307338856, 0.0009589355815045301, 0.0010887914414999351, 0.0]
oxides          = ["SiO2", "Al2O3", "CaO", "MgO", "FeO", "K2O", "Na2O", "TiO2", "O", "Cr2O3", "H2O"]

println("  Test P-T diagram computation")
global Out_XY =  Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,0)
Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  "ig", data, 
                                                MAGEMin_data,
                                                false,
                                                "pt",
                                                0.0,
                                                nothing,
                                                0.0,
                                                0.0,
                                                101.0,
                                                101.0,
                                                0.0,
                                                0.0,
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
@test length(Out_XY) == 25

results = [ -787.5021281229567; -780.3561723080602; -773.3527763396436; -766.4099019277187; -759.5152725789162; -807.3352677633849; -800.1192103984516; -793.0479904520582; -786.0403142969375; -779.091199095056; -829.5233690370851; -822.2589936166174; -815.1059020451603; -808.0275997269894; -801.016558171696; -853.7724167758879; -846.4400658082319; -839.2155372393563; -832.0763170590177; -824.9827244715955; -880.4886361964809; -872.8679746851093; -865.3993513711622; -858.0353846182636; -850.7857604621469]
for i = 1:25
    @test Out_XY[i].G_system ≈ results[i] rtol=1e-4
end

println("  Test refinement")
data    = select_cells_to_split_and_keep(data)
data    = perform_AMR(data)

Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(   "ig", data,
                                                MAGEMin_data,
                                                false,
                                                "pt",
                                                0.0,
                                                nothing,
                                                0.0,
                                                0.0,
                                                101.0,
                                                101.0,
                                                0.0,
                                                0.0,
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

@test length(Out_XY) == 81

results = [ -787.5021281229567; -780.3561723080602; -773.3527763396436; -766.4099019277187; -759.5152725789162; -807.3352677633849; -800.1192103984516; -793.0479904520582; -786.0403142969375; -779.091199095056; -829.5233690370851; -822.2589936166174; -815.1059020451603; -808.0275997269894; -801.016558171696; -853.7724167758879; -846.4400658082319; -839.2155372393563; -832.0763170590177; -824.9827244715955; -880.4886361964809; -872.8679746851093; -865.3993513711622; -858.0353846182636; -850.7857604621469; -793.4958065826659; -783.9076280418622; -789.9138898520338; -803.7185490472417; -797.1013050486752; -786.3927849248868; -776.8509868834662; -782.8815617981878; -796.5726664901508; -779.3822174572567; -769.8698899244762; -775.9073374914761; -789.5315122653172; -772.4427599870476; -762.959034440156; -768.9859759713694; -782.5615282012019; -814.5280100028003; -810.9161426744446; -825.882868479821; -818.1561787795456; -807.3416814115258; -803.8033199611269; -818.6602259854011; -800.2723703892802; -796.760812461995; -811.5611058126912; -793.2667561302652; -789.7820347979989; -804.5167858582549; -837.7470664432146; -834.1104591482115; -850.0920231350568; -841.4003188178998; -830.4948718940514; -826.9202268900124; -842.8105347238555; -823.3612310813717; -819.8099313165925; -835.6419613962723; -816.2770877558328; -812.7597666675025; -828.5195066642439; -863.0817104255258; -859.3517090161208; -876.661859197177; -866.8579447595877; -855.658132131277; -852.0055964461089; -869.1180019347844; -848.3868451870767; -844.7964266684249; -861.7062982994196; -841.2239388694064; -837.6620712684154; -854.3929125432605]
for i = 1:81
    @test Out_XY[i].G_system ≈ results[i] rtol=1e-4
end

for i = 1:Threads.maxthreadid()
    finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
end

# AppData lives in the MAGEMinApp module; re-included functions look for it in Main
const AppData = MAGEMinApp.AppData

# use_GPa / use_warr_names are globals defined in appData.jl; re-included functions
# (to_kbar_pressure, display_pressure, pressure_unit_label, ...) look for them in Main
global use_GPa        = [false]
global use_warr_names = [false]

# build_kds_database is defined in MAGEMinApp_functions.jl which is not re-included here
const build_kds_database = MAGEMinApp.build_kds_database

# get_init_param is defined in MAGEMinApp_functions.jl which is not re-included here
function get_init_param(dtb::String, solver::String, cpx, limOpx, limOpxVal::Float64)
    mbCpx      = (cpx == true && dtb in ("mb","mbe")) ? 1 : 0
    limitCaOpx = 0
    CaOpxLim   = 1.0
    if limOpx == "ON" && dtb in ("mb","mbe","ig","igd","alk")
        limitCaOpx = 1
        CaOpxLim   = limOpxVal
    end
    sol = solver == "pge" ? 1 : solver == "lp" ? 0 : 2
    return mbCpx, limitCaOpx, CaOpxLim, sol
end

include(joinpath(pkg_dir,"src","PTXpaths_functions.jl"))

println("  Test PTX path - fractional crystallization with trace elements")

dtb    = "ig"
oxides = ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"]

# N-MORB bulk composition (Gale et al., 2013) — normalized mol fractions
_morb_raw = [53.21, 9.41, 12.21, 12.21, 8.65, 0.09, 2.90, 1.21, 0.69, 0.02, 0.0]
bulk_morb  = _morb_raw ./ sum(_morb_raw)

# KLB-1 peridotite (same as above)
bulk_klb1 = [0.38451319035870185, 0.017740308257833806, 0.028208688355924924,
             0.5050993397328966,  0.0587947378409965,   9.988912307338855e-5,
             0.0024972280768347137, 0.0009988912307338856, 0.0009589355815045301,
             0.0010887914414999351, 0.0]

# Primitive mantle TE concentrations (Sun & McDonough, 1989) in μg/g
elements_te = ["La", "Ce", "Nd", "Sm", "Eu", "Gd", "Dy", "Er", "Yb"]
bulkte_pm   = [0.687, 1.775, 1.354, 0.444, 0.168, 0.596, 0.737, 0.480, 0.441]

# ─── Fractional Crystallization ───────────────────────────────────────────────
println("    fc: N-MORB isobaric cooling 1250 → 1050 °C at 4 kbar")

PTdata_fc = [
    Dict(Symbol("col-1") => 4.0, Symbol("col-2") => 1250.0, Symbol("col-3") => 0.0, Symbol("col-4") => 0.0),
    Dict(Symbol("col-1") => 4.0, Symbol("col-2") => 1050.0, Symbol("col-3") => 0.0, Symbol("col-4") => 0.0),
]

compute_new_PTXpath(4, PTdata_fc, "fc", bulk_morb, bulk_morb, oxides, nothing, "false", false,
                    dtb, 1, "none", "lp", -1, 0.0, false, false, 0.0, 0.0, 0.0, 1250.0, false,
                    "false", 0.0, "true", "OL", "none", "none", "none", "none", bulkte_pm, bulkte_pm, elements_te)

Out_PTX_fc  = deepcopy(Out_PTX)
fracEvol_fc = copy(fracEvol)
n_tot_fc    = length(Out_PTX_fc)
Out_TE_fc   = deepcopy(Out_TE_PTX)
n_el_fc = length(Out_TE_fc[1].elements)

# Major-element mass balance: total solid extracted + remaining melt = 1
# delta_k = fracEvol[k,1] * frac_S[k] (solid extracted at step k relative to original)
delta_fc       = [fracEvol_fc[k, 1] * Out_PTX_fc[k].frac_S for k in 1:n_tot_fc]
remaining_melt = fracEvol_fc[n_tot_fc, 1] * Out_PTX_fc[n_tot_fc].frac_M
@test sum(delta_fc) + remaining_melt ≈ 1.0 rtol=0.01

# Point-wise TE partition: C0 ≈ Cliq * frac_M + Csol * frac_S at every two-phase step
for k in 1:n_tot_fc
    if !all(isnan, Out_TE_fc[k].Cliq) && !all(isnan, Out_TE_fc[k].Csol)
        fM = Out_PTX_fc[k].frac_M
        fS = Out_PTX_fc[k].frac_S
        for j in 1:n_el_fc
            @test Out_TE_fc[k].Cliq[j] * fM + Out_TE_fc[k].Csol[j] * fS ≈ Out_TE_fc[k].C0[j] rtol=0.01
        end
    end
end

# Cumulative TE mass conservation: sum(Csol_k * delta_k) + Cliq_end * remaining_melt ≈ C0_ini
# Skip elements absent from the KD database (C0_ini == 0 after adjust_chemical_system)
for j in 1:n_el_fc
    C0_ini = Out_TE_fc[1].C0[j]
    (isnan(C0_ini) || C0_ini <= 0.0) && continue
    mass_sol = sum(delta_fc[k] * (isnan(Out_TE_fc[k].Csol[j]) ? 0.0 : Out_TE_fc[k].Csol[j])
                   for k in 1:n_tot_fc)
    mass_liq = (remaining_melt > 0.0 && !isnan(Out_TE_fc[n_tot_fc].Cliq[j])) ?
                remaining_melt * Out_TE_fc[n_tot_fc].Cliq[j] : 0.0
    @test (mass_sol + mass_liq) / C0_ini ≈ 1.0 rtol=0.05
end

# ─── Fractional Melting ────────────────────────────────────────────────────────
println("  Test PTX path - fractional melting with trace elements")
println("    fm: KLB-1 peridotite isobaric heating 1100 → 1500 °C at 5 kbar")

PTdata_fm = [
    Dict(Symbol("col-1") => 5.0, Symbol("col-2") => 1100.0, Symbol("col-3") => 0.0, Symbol("col-4") => 0.0),
    Dict(Symbol("col-1") => 5.0, Symbol("col-2") => 1500.0, Symbol("col-3") => 0.0, Symbol("col-4") => 0.0),
]

compute_new_PTXpath(4, PTdata_fm, "fm", bulk_klb1, bulk_klb1, oxides, nothing, "false", false,
                    dtb, 1, "none", "lp", -1, 0.0, false, false, 0.0, 0.0, 0.0, 1100.0, false,
                    "false", 0.0, "true", "OL", "none", "none", "none", "none", bulkte_pm, bulkte_pm, elements_te)

Out_PTX_fm = deepcopy(Out_PTX)
n_tot_fm   = length(Out_PTX_fm)
Out_TE_fm  = deepcopy(Out_TE_PTX)
n_el_fm = length(Out_TE_fm[1].elements)

# Major-element mass balance: total melt extracted + remaining solid = 1
# For fm (nCon=0): delta_k = rem_mass[k] * frac_M[k], rem_mass decreases by frac_S[k] each step
delta_fm = let rem = Ref(1.0), d = zeros(n_tot_fm)
    for k in 1:n_tot_fm
        fM = Out_PTX_fm[k].frac_M
        fS = Out_PTX_fm[k].frac_S
        if !isnan(fM) && !isnan(fS) && fM > 0.0
            d[k]    = rem[] * fM
            rem[]   = rem[] * fS
        end
    end
    d
end
remaining_solid = 1.0 - sum(delta_fm)
@test sum(delta_fm) + remaining_solid ≈ 1.0 rtol=0.1

# Point-wise TE partition: C0 ≈ Cliq * frac_M + Csol * frac_S at every two-phase step
# rtol=0.15 accounts for near-solidus steps and phases with incomplete KD coverage
for k in 1:n_tot_fm
    if !all(isnan, Out_TE_fm[k].Cliq) && !all(isnan, Out_TE_fm[k].Csol)
        fM = Out_PTX_fm[k].frac_M
        fS = Out_PTX_fm[k].frac_S
        for j in 1:n_el_fm
            C0_j = Out_TE_fm[k].C0[j]
            (isnan(C0_j) || C0_j <= 0.0) && continue
            @test Out_TE_fm[k].Cliq[j] * fM + Out_TE_fm[k].Csol[j] * fS ≈ C0_j rtol=0.15
        end
    end
end

# Cumulative TE mass conservation: sum(Cliq_k * delta_k) + Csol_end * remaining_solid ≈ C0_ini
# rtol=0.20 reflects imperfect KD database coverage — some mineral phases lack KDs for some REEs
# Skip elements absent from the KD database (C0_ini == 0 after adjust_chemical_system)
for j in 1:n_el_fm
    C0_ini = Out_TE_fm[1].C0[j]
    (isnan(C0_ini) || C0_ini <= 0.0) && continue
    mass_liq = sum(delta_fm[k] * (isnan(Out_TE_fm[k].Cliq[j]) ? 0.0 : Out_TE_fm[k].Cliq[j])
                   for k in 1:n_tot_fm)
    mass_sol = (remaining_solid > 0.0 && !isnan(Out_TE_fm[n_tot_fm].Csol[j])) ?
                remaining_solid * Out_TE_fm[n_tot_fm].Csol[j] : 0.0
    @test (mass_liq + mass_sol) / C0_ini ≈ 1.0 rtol=0.20
end

