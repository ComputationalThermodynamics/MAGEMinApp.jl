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

const PTXA = MAGEMinApp

function ptx_bulk(dtb, test)
    row = PTXA.db[(PTXA.db.db .== dtb) .& (PTXA.db.test .== test), :]
    oxi = String.(row.oxide[1])
    b   = Float64.(row.frac[1])
    return b ./ sum(b), oxi
end

function ptx_te_bulk(test)
    row = PTXA.AppData.dbte[(PTXA.AppData.dbte.test .== test), :]
    return Float64.(row.μg_g[1]), String.(row.elements[1])
end

function run_ptx(; dtb = "ig", test = 0, mode = "fc", points = [(10.0, 1500.0), (10.0, 1150.0)], nsteps = 6,
                   nCon = 0.0, nConRes = 0.0, nRes = 0.0, assim = false, add = [0.0, 0.0], assim_test = 1,
                   te = true, zr = "WH", p2o5 = "Klein26", calcUnit = "wt", optimizer = "ns")
    bulk_ini, oxi       = ptx_bulk(dtb, test)
    bulk_ass, _         = ptx_bulk(dtb, assim_test)
    te_ini, elem        = ptx_te_bulk(0)
    te_ass, _           = ptx_te_bulk(1)
    PTdata              = [Dict{Symbol,Any}(Symbol("col-1") => p[1], Symbol("col-2") => p[2], Symbol("col-3") => 100.0 * add[i]) for (i, p) in enumerate(points)]
    dataset             = MAGEMin_C.retrieve_solution_phase_information(dtb).db_dataset
    PTXA.compute_new_PTXpath(   nsteps, PTdata, mode, bulk_ini, bulk_ass, oxi, nothing,
                                assim ? "true" : "false", false,
                                dtb, dataset, "none", "lp",
                                -1, 0.0, 0,
                                false, "OFF", 0.0,
                                nCon, nConRes, nRes,
                                0.0, false,
                                "false", 0.0,
                                te ? "true" : "false", "OL", zr,
                                "none", p2o5, "none", "none",
                                te_ini, te_ass, elem,
                                "VRH", 0.5, false,
                                0.3, 0, false, false, false,
                                calcUnit, [], false; optimizer = optimizer )
    return bulk_ini, bulk_ass, oxi
end

wt_of(b, oxi) = (w = MAGEMin_C.mol2wt(b, oxi); w ./ sum(w))

function ptx_budget(; assim = false, add = [0.0, 0.0], nsteps = 6, bulk_ini = nothing, bulk_ass = nothing, oxi = nothing, unit = "wt", te = true)
    O, f, R = PTXA.Out_PTX, PTXA.fracEvol, PTXA.removedBulk
    n       = length(O)
    comp(o) = unit == "wt" ? o.bulk_wt : o.bulk
    B_ini   = unit == "wt" ? wt_of(bulk_ini, oxi) : bulk_ini
    B_ass   = unit == "wt" ? wt_of(bulk_ass, oxi) : bulk_ass
    T       = te ? PTXA.Out_TE_PTX : nothing

    M       = 1.0
    added   = 0.0
    if assim
        a      = add[1]
        added += M * a / (1.0 - a)
        M     += M * a / (1.0 - a)
    end
    B_out   = zeros(length(B_ini))
    C_out   = te ? zeros(length(T[1].C0)) : nothing
    step    = assim ? (add[2] / (1.0 - add[2])) / (nsteps + 1) : 0.0
    for k in 1:n-1
        if assim
            w      = step / (1.0 + step * k)
            added += M * w / (1.0 - w)
            M     += M * w / (1.0 - w)
        end
        rem = f[k, 1] > 0.0 ? 1.0 - f[k+1, 1] / f[k, 1] : 0.0
        if rem > 0.0
            B_out .+= M * rem .* R[k+1, :]
            te && (C_out .+= M * rem .* PTXA.C_ext_TE_PTX[k+1])
            M      *= (1.0 - rem)
        end
    end
    B_out .+= M .* comp(O[n])
    major_err = maximum(abs.(B_out .- (B_ini .+ added .* B_ass)))
    te || return major_err, NaN
    C_out .+= M .* T[n].C0
    return major_err, M, C_out, added
end

@testset "PTX mass conservation (majors and traces)" begin
    PTXA.use_GPa[1] = false

    cases = [
        (name = "fc, full solid extraction",          kw = (mode = "fc", nRes = 0.0)),
        (name = "fc, residual solid 10%",             kw = (mode = "fc", nRes = 10.0)),
        (name = "fm, connectivity 0",                 kw = (mode = "fm", points = [(10.0, 1250.0), (10.0, 1600.0)])),
        (name = "fm, connectivity 5% / residual 2%",  kw = (mode = "fm", points = [(10.0, 1250.0), (10.0, 1600.0)], nCon = 5.0, nConRes = 2.0)),
        (name = "eq",                                 kw = (mode = "eq",)),
    ]
    for c in cases
        @testset "$(c.name)" begin
            bulk_ini, bulk_ass, oxi = run_ptx(; c.kw...)
            C_ini = PTXA.Out_TE_PTX[1].C0
            major_err, M, C_out, _ = ptx_budget(; bulk_ini = bulk_ini, bulk_ass = bulk_ass, oxi = oxi)
            @test major_err < 1e-4
            rel = maximum(abs.(C_out .- C_ini) ./ C_ini)
            @test rel < 1e-8
            @test all(k -> all(isfinite, PTXA.Out_TE_PTX[k].Csol), eachindex(PTXA.Out_TE_PTX))
        end
    end

    @testset "fc with assimilation (open system)" begin
        add = [0.05, 0.20]
        bulk_ini, bulk_ass, oxi = run_ptx(; mode = "fc", assim = true, add = add, assim_test = 1)
        te_ini, _ = ptx_te_bulk(0)
        te_ass, _ = ptx_te_bulk(1)
        KDs       = PTXA.build_kds_database("OL")
        _, elem   = ptx_te_bulk(0)
        C_i       = MAGEMin_C.adjust_chemical_system(KDs, te_ini, elem)
        C_a       = MAGEMin_C.adjust_chemical_system(KDs, te_ass, elem)
        major_err, M, C_out, added = ptx_budget(; assim = true, add = add, bulk_ini = bulk_ini, bulk_ass = bulk_ass, oxi = oxi)
        @test added > 0.0
        @test major_err < 1e-4
        expected = C_i .+ added .* C_a
        @test maximum(abs.(C_out .- expected) ./ expected) < 1e-8
    end

    @testset "eq with assimilation: traces mix with the same mass fraction as majors" begin
        add = [0.0, 0.30]
        bulk_ini, bulk_ass, oxi = run_ptx(; mode = "eq", assim = true, add = add, assim_test = 1, calcUnit = "mol",
                                            points = [(10.0, 900.0), (10.0, 900.0)])
        KDs       = PTXA.build_kds_database("OL")
        te_ini, elem = ptx_te_bulk(0)
        te_ass, _ = ptx_te_bulk(1)
        C_i       = MAGEMin_C.adjust_chemical_system(KDs, te_ini, elem)
        C_a       = MAGEMin_C.adjust_chemical_system(KDs, te_ass, elem)
        B_i, B_a  = wt_of(bulk_ini, oxi), wt_of(bulk_ass, oxi)
        d         = B_a .- B_i
        for k in eachindex(PTXA.Out_PTX)
            a  = sum((PTXA.Out_PTX[k].bulk_wt .- B_i) .* d) / sum(d .* d)
            @test maximum(abs.(PTXA.Out_PTX[k].bulk_wt .- (B_i .+ a .* d))) < 1e-8
            Ck = PTXA.Out_TE_PTX[k].C0
            @test maximum(abs.(Ck .- ((1.0 - a) .* C_i .+ a .* C_a)) ./ max.(Ck, 1e-12)) < 1e-6
        end
    end

    @testset "majors only, mol units, fc" begin
        bulk_ini, bulk_ass, oxi = run_ptx(; mode = "fc", te = false, calcUnit = "mol")
        major_err, _ = ptx_budget(; bulk_ini = bulk_ini, bulk_ass = bulk_ass, oxi = oxi, unit = "mol", te = false)
        @test major_err < 1e-4
    end
end
