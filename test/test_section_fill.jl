#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMinApp
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

using Test
using MAGEMin_C
using MAGEMinApp

oxi     = ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"]
bulk    = [50.081, 8.6901, 11.6698, 12.1438, 7.7832, 0.215, 2.4978, 1.0059, 0.467, 0.01, 5.4364]
bulk  ./= sum(bulk)
data    = Initialize_MAGEMin("ig", verbose = false)
PT      = [[(8.0, 900.0), (10.0, 950.0)], [(15.0, 1100.0)]]
groups  = [multi_point_minimization(first.(g), last.(g), data; X = bulk, Xoxides = oxi, sys_in = "mol", name_solvus = true, progressbar = false) for g in PT]

fresh   = MAGEMinApp.section_fresh_seeds(groups, data; X = bulk, Xoxides = oxi, B = 0.0, aspect_ratio = 0.3)
@test length.(fresh) == length.(groups)
for (g, f) in zip(groups, fresh), (a, b) in zip(g, f)
    @test b.P_kbar ≈ a.P_kbar
    @test b.T_C    ≈ a.T_C
    @test sort(b.ph) == sort(a.ph)
    @test isapprox(b.G_system, a.G_system; rtol = 1e-6)
end
@test MAGEMinApp.section_fresh_seeds([similar(groups[1], 0)], data; X = bulk, Xoxides = oxi) == [similar(groups[1], 0)]

Finalize_MAGEMin(data)
