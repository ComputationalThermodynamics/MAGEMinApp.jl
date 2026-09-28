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
using JLD2
using MAGEMinApp

pkg_dir  = dirname(@__DIR__)
src      = read(joinpath(pkg_dir, "src", "Tab_Simulation_Callbacks.jl"), String)

starts   = [m.offset for m in eachmatch(r"callback!\(", src)]
blocks   = [src[starts[i]:(i < length(starts) ? starts[i+1]-1 : end)] for i in eachindex(starts)]

is_load  = b -> occursin(r"Input\(\s*\"load-state-diagram-button\"", b)
is_save  = b -> occursin("@save file ", b)

@testset "save/load state wiring" begin
    load_blocks = filter(is_load, blocks)
    save_blocks = filter(is_save, blocks)

    @test length(load_blocks) >= 6
    @test length(save_blocks) == 1

    @testset "load callbacks read the load filename field" begin
        for b in load_blocks
            @test !occursin("save-state-filename-id", b)
        end
    end

    @testset "save callback reads the save filename field" begin
        for b in save_blocks
            @test occursin("save-state-filename-id", b)
            @test !occursin("load-state-filename-id", b)
        end
    end

    @testset "every loaded option key is saved" begin
        save_line = only(m.captures[1] for m in eachmatch(r"@save file ([^\n]+)", src))
        saved     = Set(split(strip(save_line)))

        loaded = Set{String}()
        for b in load_blocks, m in eachmatch(r"state_read\(file,((?:\s*\"\w+\"\s*,?)+)", b)
            union!(loaded, [c.captures[1] for c in eachmatch(r"\"(\w+)\"", m.captures[1])])
        end

        @test !isempty(loaded)
        @test isempty(setdiff(loaded, saved))
    end

    @testset "diagram fields include PT_infos" begin
        @test "PT_infos" in MAGEMinApp.STATE_DIAGRAM_FIELDS
    end
end

@testset "save/load state helpers" begin
    @testset "file name validation" begin
        @test isnothing(MAGEMinApp.state_base_path(nothing))
        @test isnothing(MAGEMinApp.state_base_path(""))
        @test isnothing(MAGEMinApp.state_base_path("   "))
        @test isnothing(MAGEMinApp.state_base_path(".."))
        @test isnothing(MAGEMinApp.state_base_path("../escape"))
        @test isnothing(MAGEMinApp.state_base_path("a/b"))
        @test isnothing(MAGEMinApp.state_base_path("a\\b"))
        @test isnothing(MAGEMinApp.state_base_path("C:x"))
        base = MAGEMinApp.state_base_path("  my_diagram ")
        @test basename(base) == "my_diagram"
        @test dirname(base) == MAGEMinApp.state_dir()
        @test isnothing(MAGEMinApp.state_options_file("__definitely_not_saved__"))
    end

    @testset "reading required and optional keys" begin
        f = tempname() * ".jld2"
        a, b, c = 1, nothing, [Dict{String,Any}("col-1" => 7.5)]
        @save f a b c
        @test MAGEMinApp.state_read(f, "a", "b", "c", "z"; optional = ("z",)) == (1, nothing, c, nothing)
        @test_throws KeyError MAGEMinApp.state_read(f, "a", "z"; optional = ())
        rm(f)
    end

    @testset "pressure unit round trip" begin
        @test MAGEMinApp.state_pressure_kbar(1.5, "gpa")  == 15.0
        @test MAGEMinApp.state_pressure_kbar(15,  "kbar") == 15.0
        @test MAGEMinApp.state_pressure_kbar(15,  nothing) == 15.0
    end

    @testset "table rows become plain dicts" begin
        rows = MAGEMinApp.state_plain_rows([Dict(:oxide => "SiO2", :fraction => 50.0)])
        @test rows == [Dict{String,Any}("oxide" => "SiO2", "fraction" => 50.0)]
        @test isnothing(MAGEMinApp.state_plain_rows(nothing))
    end
end
