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

const ISO = MAGEMinApp

@testset verbose=true "radiogenic constants" begin
    @test ISO.rad_epsilon("Nd", 0.512630) == 0.0
    @test ISO.rad_epsilon("Hf", 0.282785) == 0.0
    @test ISO.rad_ref_fraction("Sr", 0.070015 / 0.098566) ≈ 0.098566  rtol=1e-4
    @test ISO.rad_ref_fraction("Nd", 0.12173 / 0.23798)   ≈ 0.23798   rtol=1e-4
    @test ISO.rad_ref_fraction("Hf", 0.052604 / 0.185953) ≈ 0.185953  rtol=1e-4
    @test ISO.rad_mix("Sr", 300.0, 200.0, 0.0, 0.7030, 0.7200) == 0.7030
    @test ISO.rad_mix("Sr", 300.0, 200.0, 1.0, 0.7030, 0.7200) ≈ 0.7200
    @test 0.7030 < ISO.rad_mix("Sr", 300.0, 200.0, 0.3, 0.7030, 0.7200) < 0.7200
end

@testset verbose=true "AFC benchmark (DePaolo, 1981, Eq. 6a and 15a)" begin
    for (r, D, Cm0, Ca, R0, Ra) in ((0.2, 0.1, 400.0, 300.0, 0.7030, 0.7150), (0.5, 1.5, 400.0, 150.0, 0.7030, 0.7200), (0.3, 3.0, 25.0, 30.0, 0.51310, 0.51180))
        z       = (r + D - 1.0) / (r - 1.0)
        M, C, R = 1.0, Cm0, R0
        dMc     = 1e-5
        while M > 0.6
            C_cr  = D * C
            M_l   = M - dMc
            C     = (M * C - dMc * C_cr) / M_l
            dMa   = r * dMc
            w     = dMa / (M_l + dMa)
            R     = ISO.rad_mix(R0 < 0.6 ? "Nd" : "Sr", C, Ca, w, R, Ra)
            C     = (1.0 - w) * C + w * Ca
            M     = M_l + dMa
        end
        F       = M
        C_an    = Cm0 * (F^(-z) + (r / (r - 1.0 + D)) * (Ca / Cm0) * (1.0 - F^(-z)))
        A       = (r / (r - 1.0)) * (Ca / z) * (1.0 - F^(-z))
        R_an    = (A * Ra + Cm0 * F^(-z) * R0) / (A + Cm0 * F^(-z))
        @test C ≈ C_an  rtol=1e-3
        @test R ≈ R_an  atol=5e-5 * abs(Ra - R0) + 1e-7
    end
end

@testset verbose=true "δ18O PTX bookkeeping" begin
    data    = Initialize_MAGEMin("ig", verbose=-1, solver=0)
    out     = single_point_minimization(5.0, 1280.0, data, test=0)
    o       = MAGEMin_C.O18_prediction(out, 6.0)
    for (ex, kS, kM) in ((true, 1.0, 0.0), (true, 0.0, 1.0), (true, 0.7, 0.3), (false, 1.0, 1.0))
        Nr, δr, No, δo = ISO.o18_extract_step(o, ex, kS, kM)
        @test Nr + No ≈ 1.0  rtol=1e-12
        @test (Nr * δr + (No > 0.0 ? No * δo : 0.0)) ≈ o.δ_sys  rtol=1e-12
    end
    Nr, δr, No, δo   = ISO.o18_extract_step(o, true, 1.0, 0.0)
    @test δo > δr
    i                = findfirst(==("ol"), o.ph)
    Nr2, δr2, No2, δo2 = ISO.o18_remove_phase(o, [i], 0.4, Nr, δr, No, δo)
    @test Nr2 + No2 ≈ 1.0  rtol=1e-12
    @test Nr2 * δr2 + No2 * δo2 ≈ o.δ_sys  rtol=1e-12
    δm, gain         = ISO.o18_mix_assim([0.5, 0.5], [0.5, 0.5], 0.2, 6.0, 12.0, ["SiO2", "MgO"], "mol")
    @test δm ≈ 7.2
    @test gain ≈ 1.25
    Finalize_MAGEMin(data)
end

function iso_run_ptx(; mode = "fc", assim = false, add = [0.0, 0.0], o18 = nothing, rad = nothing, nsteps = 6)
    row(t)      = ISO.db[(ISO.db.db .== "ig") .& (ISO.db.test .== t), :]
    bulk_ini    = Float64.(row(0).frac[1]);  bulk_ini ./= sum(bulk_ini)
    bulk_ass    = Float64.(row(1).frac[1]);  bulk_ass ./= sum(bulk_ass)
    oxi         = String.(row(0).oxide[1])
    te(t)       = (r = ISO.AppData.dbte[(ISO.AppData.dbte.test .== t), :]; (Float64.(r.μg_g[1]), String.(r.elements[1])))
    te_ini, elem = te(0)
    te_ass, _   = te(1)
    PTdata      = [Dict{Symbol,Any}(Symbol("col-1") => 10.0, Symbol("col-2") => T, Symbol("col-3") => 100.0 * add[i]) for (i, T) in enumerate((1500.0, 1150.0))]
    dataset     = MAGEMin_C.retrieve_solution_phase_information("ig").db_dataset
    ISO.compute_new_PTXpath(nsteps, PTdata, mode, bulk_ini, bulk_ass, oxi, nothing, assim ? "true" : "false", false,
                            "ig", dataset, "none", "lp", -1, 0.0, 0, false, "OFF", 0.0, 0.0, 0.0, 0.0, 0.0, false, "false", 0.0,
                            "true", "OL", "none", "none", "none", "none", "none", te_ini, te_ass, elem,
                            "VRH", 0.5, false, 0.3, 0, false, false, false, "wt", [], false;
                            optimizer = "ns", o18 = o18, rad = rad)
end

@testset verbose=true "PTX path δ18O and radiogenic isotopes" begin
    o18 = ISO.o18_ptx_options("true", 6.0, 12.0, "norm", "exclude", 900.0)
    rad = ISO.rad_ptx_options("true", ["Sr", "Nd"], ISO.rad_default_table())

    iso_run_ptx(; mode = "fc", o18 = o18, rad = rad)
    @test ISO.o18_ptx_available()
    @test ISO.rad_ptx_available()
    ext     = ISO.O18_ext_PTX
    N_out   = sum(first(e) for e in ext)
    D_out   = sum(e[1] * e[2] for e in ext if e[1] > 0.0)
    δ_fin   = ISO.Out_O18_PTX[end].δ_sys
    @test D_out + (1.0 - N_out) * δ_fin ≈ 6.0  rtol=1e-8
    @test all(≈(0.7030), ISO.Rad_PTX["Sr"])
    @test all(≈(0.51310), ISO.Rad_PTX["Nd"])

    iso_run_ptx(; mode = "fc", assim = true, add = [0.0, 0.3], o18 = o18, rad = rad)
    Sr  = ISO.Rad_PTX["Sr"]
    Nd  = ISO.Rad_PTX["Nd"]
    @test all(isfinite, Sr) && all(isfinite, Nd)
    @test Sr[1] ≈ 0.7030
    @test all(diff(Sr) .>= -1e-12) && Sr[end] > Sr[1] && Sr[end] < 0.7150
    @test all(diff(Nd) .<= 1e-12)  && Nd[end] < Nd[1] && Nd[end] > 0.51200
    @test ISO.Out_O18_PTX[end].δ_sys > ISO.Out_O18_PTX[1].δ_sys
    @test length(ISO.rad_ptx_series("E|Nd")) == length(ISO.Out_PTX)
    @test all(isfinite, ISO.rad_ptx_series("Cliq|Sr"))
end
