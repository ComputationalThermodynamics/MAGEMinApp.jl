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

data  = Initialize_MAGEMin("mp", verbose = false)
out   = single_point_minimization(6.0, 650.0, data; test = 0, name_solvus = true)
Finalize_MAGEMin(data)

entry = MAGEMinApp.pd_minipie_entry(out, 650.0, 6.0, true, "mp")
@test entry["x"] == 650.0 && entry["y"] == 6.0 && entry["py"] == true
@test length(entry["phases"]) == length(entry["values"]) == length(entry["colors"]) == length(entry["labels"])
@test all(>(0.0), entry["values"])
@test issorted(entry["values"]; rev = true)
@test isapprox(sum(entry["values"]), 100.0; atol = 1e-2)
@test entry["colors"] == [MAGEMinApp.get_phase_color(ph; default = "#808080") for ph in entry["phases"]]

w = MAGEMinApp.pd_pie_wedges(100.0, 100.0, 20.0, [50.0, 25.0, 25.0])
@test length(w) == 3
@test all(p -> p[1] == (100.0, 100.0), w)
@test all(isapprox(hypot(x - 100.0, y - 100.0), 20.0; atol = 1e-9) for p in w for (x, y) in p[2:end])
@test w[1][2][1] ≈ 100.0 && w[1][2][2] ≈ 80.0
@test w[1][end][1] ≈ 100.0 && w[1][end][2] ≈ 120.0
@test length(MAGEMinApp.pd_pie_wedges(0.0, 0.0, 1.0, [100.0])) == 1
@test isempty(MAGEMinApp.pd_pie_wedges(0.0, 0.0, 1.0, [0.0]))

svgp = MAGEMinApp.pd_svg_pies([entry], false)[1]
@test svgp.phases == entry["phases"] && svgp.y == 6.0
