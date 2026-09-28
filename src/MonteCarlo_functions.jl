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

using Random

"""
    load_mc_default_sigma()

    Read the per-oxide default relative 1σ [%] used to seed the Uncertainty
    tab's σ table, from `user_data/mc_default_sigma.csv`. Returns a
    Dict{String,Float64} mapping oxide name -> relative σ [%].
"""
function load_mc_default_sigma()
    path = joinpath(pkg_dir, "user_data", "mc_default_sigma.csv")
    df   = CSV.read(path, DataFrame)
    return Dict(String(r.oxide) => Float64(r.sigma_rel_pct) for r in eachrow(df))
end

"""
    mc_sigma_for_oxides(oxi::Vector{String}; fallback_pct = 5.0)

    Default relative σ [%] for each oxide in `oxi`, in the same order, read
    from `mc_default_sigma.csv`. Oxides missing from that file fall back to
    `fallback_pct`.
"""
function mc_sigma_for_oxides(oxi::Vector{String}; fallback_pct::Float64 = 5.0)
    defaults = load_mc_default_sigma()
    return [get(defaults, ox, fallback_pct) for ox in oxi]
end

"""
    mc_convert_absolute_sigma(bulk_from, sigma_from, oxi, to_wt::Bool)

    Convert a per-oxide *absolute* σ from one basis to the other - mol -> wt
    (`to_wt = true`, via `mol2wt`) or wt -> mol (`to_wt = false`, via
    `wt2mol`) - so the Uncertainty tab's σ column stays scientifically
    meaningful when its display unit is switched, and so an absolute σ
    entered/displayed in wt% can be converted to the mol basis a Monte Carlo
    run always uses internally (same trick `bulk_csv_to_db` uses for a CSV's
    own `_wds` columns).

    `bulk_from` and `sigma_from` must both already be expressed on the same
    scale (e.g. both mol% or both a 0-1 mol fraction) and the same oxide
    order as `oxi` - only their relative proportions matter, since
    `mol2wt`/`wt2mol` are scale-invariant on input. Each oxide is converted
    independently: perturb only that oxide's raw value by its own σ, holding
    every other oxide's raw value fixed, and diff the resulting
    `mol2wt`/`wt2mol` output - the same finite-difference approximation used
    throughout, valid for σ that is small relative to the bulk itself.

    An oxide with `sigma_from[i]` `NaN`, or `bulk_from[i] <= 0`, stays `NaN`.
"""
function mc_convert_absolute_sigma(bulk_from::Vector{Float64}, sigma_from::Vector{Float64}, oxi::Vector{String}, to_wt::Bool)
    n = length(bulk_from)
    @assert length(sigma_from) == n == length(oxi)
    transform = to_wt ? mol2wt : wt2mol
    base      = transform(bulk_from, oxi)
    sigma_to  = fill(NaN, n)
    for i in 1:n
        (isnan(sigma_from[i]) || bulk_from[i] <= 0.0) && continue
        perturbed   = copy(bulk_from); perturbed[i] += sigma_from[i]
        sigma_to[i] = abs(transform(perturbed, oxi)[i] - base[i])
    end
    return sigma_to
end

"""
    mc_relative_sigma(bulk::Vector{Float64}, sigma::Vector{Float64}, mode::Symbol)

    Convert the σ column entered in the Uncertainty tab to a per-oxide
    *relative* σ (a fraction, not a percent) suitable for `sample_mc_bulks`.

    `mode` is either `:relative` (σ is already in % of each oxide's own
    value) or `:absolute` (σ is in the same unit as `bulk`, i.e. mol or wt
    fraction/percent, whichever unit `bulk` is expressed in).

    Oxides at `bulk[i] == 0` always get relative σ 0 - a component that is
    absent from the reference bulk is kept absent in every realization.
"""
function mc_relative_sigma(bulk::Vector{Float64}, sigma::Vector{Float64}, mode::Symbol)
    n = length(bulk)
    @assert length(sigma) == n
    rel = zeros(Float64, n)
    for i in 1:n
        if bulk[i] <= 0.0
            rel[i] = 0.0
        elseif mode == :relative
            rel[i] = sigma[i] / 100.0
        elseif mode == :absolute
            rel[i] = sigma[i] / bulk[i]
        else
            error("mc_relative_sigma: mode must be :relative or :absolute, got $mode")
        end
    end
    return rel
end

"""
    sample_mc_bulks(bulk::Vector{Float64}, sigma_rel::Vector{Float64}, N::Int; seed = nothing)

    Draw `N` perturbed bulk-rock compositions around `bulk`, one row per
    realization (an `N x length(bulk)` Matrix{Float64}).

    Each oxide is perturbed in log space, `x_i' = x_i * exp(ε_i)` with
    `ε_i ~ N(0, sigma_rel[i])`, so perturbed values stay positive and the
    perturbation is symmetric in relative terms. Every realization is then
    renormalized to `sum(bulk)`, preserving closure. An oxide with
    `sigma_rel[i] == 0` (including any oxide absent from the reference bulk)
    is left unperturbed before renormalization.

    `seed`, when given, makes the draw reproducible (`Random.Xoshiro(seed)`).
    With `sigma_rel` all zero, every realization equals `bulk` exactly.
"""
function sample_mc_bulks(bulk::Vector{Float64}, sigma_rel::Vector{Float64}, N::Int; seed::Union{Nothing,Integer} = nothing)
    n = length(bulk)
    @assert length(sigma_rel) == n
    @assert all(sigma_rel .>= 0.0)

    rng    = isnothing(seed) ? Random.Xoshiro() : Random.Xoshiro(seed)
    total  = sum(bulk)
    bulks  = Matrix{Float64}(undef, N, n)

    for k in 1:N
        for i in 1:n
            if bulk[i] <= 0.0 || sigma_rel[i] == 0.0
                bulks[k, i] = bulk[i]
            else
                eps         = randn(rng) * sigma_rel[i] - sigma_rel[i]^2 / 2
                bulks[k, i] = bulk[i] * exp(eps)
            end
        end
        row_sum = sum(@view bulks[k, :])
        if row_sum > 0.0
            bulks[k, :] .*= total / row_sum
        end
    end

    return bulks
end

"""
    sample_mc_bulks(bulk, oxi, sigma, mode, N; seed = nothing)

    Convenience wrapper combining [`mc_relative_sigma`](@ref) and
    [`sample_mc_bulks`](@ref): `sigma` is the raw σ column as entered in the
    Uncertainty tab (either relative % or absolute, per `mode`), and `oxi` is
    only used to check `sigma` and `bulk` have matching length.
"""
function sample_mc_bulks(bulk::Vector{Float64}, oxi::Vector{String}, sigma::Vector{Float64}, mode::Symbol, N::Int; seed::Union{Nothing,Integer} = nothing)
    @assert length(bulk) == length(oxi) == length(sigma)
    sigma_rel = mc_relative_sigma(bulk, sigma, mode)
    return sample_mc_bulks(bulk, sigma_rel, N; seed = seed)
end

"""
    MC_ref_options

    The subset of a computed P-T phase diagram's own settings that a Monte
    Carlo run needs to reproduce the same physics as the reference - both to
    build its own `MAGEMin_Data` (a Monte Carlo run initializes and finalizes
    its own copy, rather than reusing the diagram's, which is already
    finalized by the time `compute_new_phaseDiagram` returns) and to match
    the reference's `refine_MAGEMin` settings. Everything left out (seismic
    corrections, display options, colors) only affects derived properties,
    not which phases are stable.
"""
struct MC_ref_options
    dtb             :: String
    dataset         :: Int64
    oxi             :: Vector{String}
    bufferType      :: String
    bufferN1        :: Float64
    scp             :: Int64
    solver          :: Int64
    mbCpx           :: Int64
    limitCaOpx      :: Int64
    CaOpxLim        :: Float64
    phase_selection :: Union{Nothing,Vector{Int64}}
    custW           :: Bool
end

"""
    mc_ref_options(dtb, dataset, oxi, bufferType, bufferN1, scp, solver, cpx, limOpx,
                    limOpxVal, phase_selection, custW)

    Build an [`MC_ref_options`](@ref) the same way `compute_new_phaseDiagram`
    builds its own `MAGEMin_Data` init parameters (via `get_init_param`),
    from the diagram's own Setup-tab values (`solver` and `limOpx` as the raw
    dropdown strings, `cpx` the mb-cpx switch, matching `get_init_param`'s
    own argument names). `custW` is passed straight through to
    `refine_MAGEMin`, which builds its own custom-margules list from it and
    `AppData.customWs` internally.
"""
function mc_ref_options(dtb::String, dataset::Int64, oxi::Vector{String}, bufferType::String, bufferN1::Float64,
                         scp::Int64, solver::String, cpx, limOpx, limOpxVal::Float64,
                         phase_selection::Union{Nothing,Vector{Int64}}, custW::Bool)
    mbCpx, limitCaOpx, CaOpxLim, sol = get_init_param(dtb, solver, cpx, limOpx, limOpxVal)
    return MC_ref_options(dtb, dataset, oxi, bufferType, bufferN1, scp, sol, mbCpx, limitCaOpx, CaOpxLim,
                           phase_selection, custW)
end

"""
    mc_run_amr_realization(dtb, MAGEMin_data, oxi, bulk_k, opts, Xrange, Yrange,
                            sub, refLvl_mc, k, N)

    Compute one Monte Carlo realization's phase diagram for bulk `bulk_k`,
    using the exact same adaptive-mesh-refinement machinery the reference
    diagram itself was built with (`init_AMR`, `refine_MAGEMin`,
    `select_cells_to_split_and_keep`, `perform_AMR`): a coarse `sub`-level
    grid, then `refLvl_mc` refinement passes that split only the cells
    straddling a phase boundary - discovering *this bulk's own* boundary
    wherever it actually falls, rather than assuming it stays close to the
    reference's (which a fixed search band around the reference boundary
    would). `sub` and `refLvl_mc` are the reference diagram's own current
    initial subdivision and total refinement level (`refLvl + addedRefinementLvl`,
    i.e. including any "Refine uniformly"/"Refine phase boundaries" passes) -
    the Uncertainty tab exposes no separate resolution control, so a Monte
    Carlo run always matches whatever grid the diagram is currently showing.

    `refine_MAGEMin` also handles same-bulk warm-starting natively (its own
    split-cell initial-guess propagation, enabled by passing `boost = true`
    here): every point within one realization shares the one bulk `bulk_k`,
    so warm-starting a finer pass's point from a nearby coarser one of the
    same realization only ever differs in (P,T), never in composition - safe
    for the same reason the reference diagram's own AMR refinement is safe.
    This is different from, and does not use, warm-starting a point from the
    *reference's* solution (a different bulk composition), which was found
    to silently converge to the wrong assemblage and is not done anywhere in
    this file - see `notes/monte-carlo-warm-start-unsafe.md`.

    Mutates and restores the module-level `Out_XY`/`addedRefinementLvl`
    globals that `refine_MAGEMin` itself reads and writes (the same ones the
    currently displayed reference diagram uses): this realization gets its
    own, empty accumulator to build into, and the caller's diagram globals
    are restored to exactly what they were before this call once it returns
    (even on error, via `finally`).

    Returns `(data, Out_XY_k, Hash_XY_k)`: this realization's own AMR mesh,
    its per-point results, and their phase-assemblage hashes.
"""
function mc_run_amr_realization(dtb::String, MAGEMin_data, oxi::Vector{String}, bulk_k::Vector{Float64},
                                 opts::MC_ref_options, Xrange, Yrange, sub::Int, refLvl_mc::Int, k::Int, N::Int)

    global Out_XY, Hash_XY, addedRefinementLvl, CompProgress
    saved_Out_XY             = Out_XY
    saved_Hash_XY            = Hash_XY
    saved_addedRefinementLvl = addedRefinementLvl

    Out_XY             = MAGEMin_C.gmin_struct{Float64,Int64}[]
    Hash_XY             = UInt64[]
    addedRefinementLvl = 0

    data_k = init_AMR(Xrange, Yrange, sub)

    try
        CompProgress.title            = "Monte Carlo Progress"
        CompProgress.stage            = "Realization $k/$N - initial grid"
        CompProgress.refinement_level = 0
        CompProgress.total_levels     = refLvl_mc
        CompProgress.tinit            = time()
        CompProgress.total_points     = length(data_k.npoints)

        Out_XY, Hash_XY, _ = refine_MAGEMin(dtb, data_k, MAGEMin_data, opts.custW, "pt", nothing,
                                             opts.phase_selection, 0.0, 0.0,
                                             0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                             oxi, bulk_k, bulk_k,
                                             opts.bufferType, opts.bufferN1, opts.bufferN1,
                                             opts.scp, true, "ph",
                                             nothing, nothing,
                                             false, 0.3, 0, false, false, false)

        for irefine in 1:refLvl_mc
            CompProgress.stage            = "Realization $k/$N - refine grid level ->"
            CompProgress.refinement_level = irefine
            CompProgress.tinit            = time()

            data_k = select_cells_to_split_and_keep(data_k)
            data_k = perform_AMR(data_k)
            CompProgress.total_points = length(data_k.npoints)

            Out_XY, Hash_XY, _ = refine_MAGEMin(dtb, data_k, MAGEMin_data, opts.custW, "pt", nothing,
                                                 opts.phase_selection, 0.0, 0.0,
                                                 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                                 oxi, bulk_k, bulk_k,
                                                 opts.bufferType, opts.bufferN1, opts.bufferN1,
                                                 opts.scp, true, "ph",
                                                 nothing, nothing,
                                                 false, 0.3, 0, false, false, false)
        end

        return data_k, Out_XY, Hash_XY
    finally
        Out_XY             = saved_Out_XY
        Hash_XY            = saved_Hash_XY
        addedRefinementLvl = saved_addedRefinementLvl
    end
end

"""
    run_monte_carlo_pt(bulk_L, sigma_input, sigma_mode, N, Xrange, Yrange,
                        sub, refLvl_mc, opts; seed = nothing)

    Run a Monte Carlo bulk-uncertainty study of `N` realizations, each built
    with [`mc_run_amr_realization`](@ref) (the same AMR process the
    reference diagram itself used). `bulk_L` is the diagram's reference bulk
    (mol), `sigma_input`/`sigma_mode` the σ column from the Uncertainty tab
    (see [`mc_relative_sigma`](@ref)), `sub` the reference diagram's own
    initial subdivision, `refLvl_mc` how many refinement passes each
    realization gets, and `opts` an [`MC_ref_options`](@ref) (see
    [`mc_ref_options`](@ref)) capturing the diagram's own settings.

    Initializes and finalizes its own `MAGEMin_Data`, rather than reusing the
    diagram's own copy: `compute_new_phaseDiagram` finalizes that one (frees
    its per-thread database) as soon as it returns, so by the time a Monte
    Carlo run can start, it no longer refers to valid MAGEMin state.

    Returns a NamedTuple `(bulks, gridded_fields, id2phases, Xrange, Yrange,
    bulk_ref, oxides)`:
    - `bulks`: the `N x length(bulk_L)` sampled bulks;
    - `bulk_ref`/`oxides`: the reference bulk `bulk_L` and its oxide names
      (what the bulk-variation spider diagram is drawn against);
    - `gridded_fields`: a `Vector` of `N` rasterized assemblage-id grids, one
      per realization (each `2^(sub+refLvl_mc)+1` square, in that
      realization's own local id numbering - only meaningful through
      `compute_assemblage_boundaries`, not compared cell-by-cell against the
      reference or each other, since each realization's own AMR mesh, and
      therefore its raster's local id numbering, is independent);
    - `id2phases`: a `Vector` of `N` `Dict{Int,Vector{String}}`, one per
      realization, mapping that realization's own local ids (as used in its
      `gridded_fields` entry) to the sorted phase list they represent - what
      lets [`mc_field_polygons`](@ref) find "this field" across realizations
      whose id numbering is otherwise unrelated to each other's;
    - `Xrange`/`Yrange`: the domain every realization (and the reference)
      shares, kept alongside the result for convenience when plotting.
"""
function run_monte_carlo_pt(bulk_L::Vector{Float64}, sigma_input::Vector{Float64}, sigma_mode::Symbol, N::Int,
                             Xrange, Yrange, sub::Int, refLvl_mc::Int, opts::MC_ref_options;
                             seed::Union{Nothing,Integer} = nothing)

    MAGEMin_data = Initialize_MAGEMin(opts.dtb;
                                       verbose        = false,
                                       dataset        = opts.dataset,
                                       limitCaOpx     = opts.limitCaOpx,
                                       CaOpxLim       = opts.CaOpxLim,
                                       mbCpx          = opts.mbCpx,
                                       buffer         = opts.bufferType,
                                       solver         = opts.solver)

    for i in 1:Threads.maxthreadid()
        nb = min(ncodeunits(opts.bufferType), 9)
        unsafe_copyto!(MAGEMin_data.gv[i].buffer, Ptr{Cchar}(pointer(opts.bufferType)), nb)
        unsafe_store!(MAGEMin_data.gv[i].buffer, Cchar(0), nb + 1)
    end

    sigma_rel = mc_relative_sigma(bulk_L, sigma_input, sigma_mode)
    bulks     = sample_mc_bulks(bulk_L, sigma_rel, N; seed = seed)

    gridded_fields_all = Vector{Matrix{Int64}}(undef, N)
    id2phases_all       = Vector{Dict{Int,Vector{String}}}(undef, N)

    try
        for k in 1:N
            bulk_k = bulks[k, :]
            t_k = @elapsed begin
                data_k, Out_XY_k, Hash_XY_k = mc_run_amr_realization(opts.dtb, MAGEMin_data, opts.oxi, bulk_k,
                                                                      opts, Xrange, Yrange, sub, refLvl_mc, k, N)
                gridded_fields_all[k] = get_gridded_map("#Phases", "major", opts.oxi, Out_XY_k, nothing, Hash_XY_k,
                                                         sub, refLvl_mc, "ph", data_k, Xrange, Yrange)[3]
                id2phases_all[k] = mc_id_to_phases(Out_XY_k, Hash_XY_k)
            end
            println("Computed Monte Carlo realization $k/$N in $(round(t_k, digits=3)) seconds")
        end
    finally
        for i in 1:Threads.maxthreadid()
            finalize_MAGEMin(MAGEMin_data.gv[i], MAGEMin_data.DB[i], MAGEMin_data.z_b[i], MAGEMin_data.splx_data[i])
        end
    end

    return (bulks = bulks, gridded_fields = gridded_fields_all, id2phases = id2phases_all, Xrange = Xrange, Yrange = Yrange,
            bulk_ref = bulk_L, oxides = opts.oxi)
end

"""
    mc_id_to_phases(Out_XY_k, Hash_XY_k)

    Map a realization's own local assemblage ids (as `get_gridded_map`
    numbers them: `enumerate(unique(Hash_XY_k))`, first-occurrence order) to
    the sorted phase-name list each one represents, by looking up the first
    point in `Out_XY_k` with that hash. Used to find a target field's ids
    within a realization whose id numbering is otherwise meaningless outside
    that one realization (see [`run_monte_carlo_pt`](@ref)'s `id2phases`).
"""
function mc_id_to_phases(Out_XY_k, Hash_XY_k::Vector{UInt64})
    hashes    = unique(Hash_XY_k)
    id2phases = Dict{Int,Vector{String}}()
    for (i, h) in enumerate(hashes)
        idx           = findfirst(==(h), Hash_XY_k)
        id2phases[i]  = sort(String.(Out_XY_k[idx].ph))
    end
    return id2phases
end

"""
    mc_field_match(phases, target, strict)

    Whether a realization's stable assemblage `phases` counts as an instance
    of `target`: `strict` requires the exact same phase set; otherwise
    `target` only has to be a subset of `phases` (other phases may also be
    stable).
"""
function mc_field_match(phases::Vector{String}, target::Vector{String}, strict::Bool)
    return strict ? Set(phases) == Set(target) : issubset(Set(target), Set(phases))
end

"""
    mc_field_polygons(gridded_fields_k, id2phases_k, Xrange, Yrange, target, strict)

    The boundary polygons (in physical (T,P) coordinates, via
    `compute_assemblage_boundaries`) of one realization's regions matching
    `target` (see [`mc_field_match`](@ref)) - empty if the field is absent
    from that realization entirely.
"""
function mc_field_polygons(gridded_fields_k::Matrix{Int64}, id2phases_k::Dict{Int,Vector{String}},
                            Xrange, Yrange, target::Vector{String}, strict::Bool)
    ids, pcoor = compute_assemblage_boundaries(gridded_fields_k, Xrange, Yrange)
    keep       = [haskey(id2phases_k, id) && mc_field_match(id2phases_k[id], target, strict) for id in ids]
    return pcoor[keep]
end

"""
    mc_polygon_area(poly)

    Area enclosed by `poly` (an `Nx2` matrix of (T,P) vertices, as returned
    by `compute_assemblage_boundaries`), via the shoelace formula. Works
    whether or not the polygon is explicitly closed (last vertex repeating
    the first).
"""
function mc_polygon_area(poly::AbstractMatrix{Float64})
    n = size(poly, 1)
    n < 3 && return 0.0
    area2 = 0.0
    for i in 1:n
        j = i == n ? 1 : i + 1
        area2 += poly[i, 1] * poly[j, 2] - poly[j, 1] * poly[i, 2]
    end
    return abs(area2) / 2
end

"""
    mc_field_largest_polygon(gridded_fields_k, id2phases_k, Xrange, Yrange, target, strict)

    The single largest-area polygon (by [`mc_polygon_area`](@ref)) among one
    realization's regions matching `target`, or `nothing` if the field is
    absent from that realization. A field's stability region can fracture
    into many small polygons that are largely minimization/rasterization
    artifacts rather than real disjoint occurrences - using only the
    largest one is a deliberate choice to ignore that noise (see
    [`mc_field_polygons`](@ref) for every matching polygon, unfiltered).
"""
function mc_field_largest_polygon(gridded_fields_k::Matrix{Int64}, id2phases_k::Dict{Int,Vector{String}},
                                   Xrange, Yrange, target::Vector{String}, strict::Bool)
    polys = mc_field_polygons(gridded_fields_k, id2phases_k, Xrange, Yrange, target, strict)
    isempty(polys) && return nothing
    return polys[argmax(mc_polygon_area.(polys))]
end

"""
    mc_field_largest_polygons(gridded_fields_k, id2phases_k, Xrange, Yrange, target, strict)

    Like [`mc_field_largest_polygon`](@ref), but one polygon per matching
    assemblage instead of one overall: the largest-area polygon of each
    distinct assemblage id matching `target`. A loose `target` (a phase
    subset) matches several assemblages at once, each with its own
    stability region, so keeping only the single largest polygon overall
    would drop the others' regions entirely; keeping the largest per
    assemblage still discards each assemblage's own fragmentation noise.
    For a strict `target` this is the same single polygon
    `mc_field_largest_polygon` returns (as a one-element vector). Empty if
    the field is absent.
"""
function mc_field_largest_polygons(gridded_fields_k::Matrix{Int64}, id2phases_k::Dict{Int,Vector{String}},
                                    Xrange, Yrange, target::Vector{String}, strict::Bool)
    ids, pcoor = compute_assemblage_boundaries(gridded_fields_k, Xrange, Yrange)
    return mc_largest_polygons_per_assemblage(ids, pcoor, id2phases_k, target, strict)
end

"""
    mc_largest_polygons_per_assemblage(ids, pcoor, id2phases_k, target, strict)

    The selection step of [`mc_field_largest_polygons`](@ref) on already
    traced boundaries (`ids`/`pcoor` as returned by
    `compute_assemblage_boundaries`), so several targets can share one
    boundary tracing per realization, which is the expensive part.
"""
function mc_largest_polygons_per_assemblage(ids, pcoor, id2phases_k::Dict{Int,Vector{String}},
                                             target::Vector{String}, strict::Bool)
    best = Dict{Int,Tuple{Float64,Int}}()
    for (i, id) in enumerate(ids)
        (haskey(id2phases_k, id) && mc_field_match(id2phases_k[id], target, strict)) || continue
        a = mc_polygon_area(pcoor[i])
        if !haskey(best, id) || a > best[id][1]
            best[id] = (a, i)
        end
    end
    return [pcoor[best[id][2]] for id in sort(collect(keys(best)))]
end

"""
    mc_all_assemblages(mc_res)

    Every distinct phase-list assemblage seen across all realizations of
    `mc_res` (sorted phase names, deduplicated), for populating a target-field
    picker.
"""
function mc_all_assemblages(mc_res)
    seen = Set{Vector{String}}()
    for id2phases_k in mc_res.id2phases
        for phases in values(id2phases_k)
            push!(seen, phases)
        end
    end
    return sort(collect(seen))
end

"""
    mc_line_crossings(poly, axis, value)

    Where the edges of `poly` (an `Nx2` matrix of (T,P) vertices, as
    returned by `compute_assemblage_boundaries`) cross the line
    `axis = value` - `axis = :P` for a fixed-pressure (horizontal) line,
    giving the crossing temperatures, or `axis = :T` for a fixed-temperature
    (vertical) line, giving the crossing pressures. Every crossing is
    reported without distinguishing "entering" from "exiting" the field
    (that needs knowing the polygon's winding direction, not assumed here) -
    for a field with one contiguous stability range along the chosen line,
    this pools two, and the resulting distribution's low/high sides are the
    field's "-in" and "-out" boundaries respectively; a field crossed more
    than twice (a re-entrant shape) will pool more of them. `poly === nothing`
    (the field absent from this realization) returns an empty vector.
"""
function mc_line_crossings(poly, axis::Symbol, value::Float64)
    axis in (:P, :T) || error("mc_line_crossings: axis must be :P or :T, got $axis")
    crossings = Float64[]
    poly === nothing && return crossings
    n = size(poly, 1)
    n < 2 && return crossings
    for i in 1:n
        j  = i == n ? 1 : i + 1
        x1, y1 = poly[i, 1], poly[i, 2]
        x2, y2 = poly[j, 1], poly[j, 2]
        a1, a2, b1, b2 = axis == :P ? (y1, y2, x1, x2) : (x1, x2, y1, y2)
        if (a1 <= value < a2) || (a2 <= value < a1)
            t = (value - a1) / (a2 - a1)
            push!(crossings, b1 + t * (b2 - b1))
        end
    end
    return crossings
end

"""
    mc_boundary_crossing_distribution(mc_res, target, strict, axis, value)

    The [`mc_line_crossings`](@ref) of `target`'s [`mc_field_largest_polygon`](@ref)
    (see [`mc_field_match`](@ref) for `strict`) against the fixed-`axis` line
    at `value`, pooled over every realization of `mc_res`. Only the largest
    matching polygon per realization is used, not every polygon
    `mc_field_polygons` would find, to avoid pooling in minimization/
    rasterization fragments as if they were real disjoint occurrences of the
    field. Returns a NamedTuple `(crossings, per_realization, n_present,
    n_total)`: `crossings` is every crossing value pooled; `per_realization`
    is one crossings vector per realization (empty where the field doesn't
    cross that line, whether because it's absent from that realization or
    just doesn't reach this particular P/T); `n_present` how many
    realizations had at least one crossing; `n_total` the realization count.
"""
function mc_boundary_crossing_distribution(mc_res, target::Vector{String}, strict::Bool, axis::Symbol, value::Float64)
    N = length(mc_res.gridded_fields)
    per_realization = Vector{Vector{Float64}}(undef, N)
    for k in 1:N
        poly = mc_field_largest_polygon(mc_res.gridded_fields[k], mc_res.id2phases[k], mc_res.Xrange, mc_res.Yrange,
                                         target, strict)
        per_realization[k] = mc_line_crossings(poly, axis, value)
    end
    crossings = reduce(vcat, per_realization; init = Float64[])
    n_present = count(!isempty, per_realization)
    return (crossings = crossings, per_realization = per_realization, n_present = n_present, n_total = N)
end

"""
    mc_crossing_stats(crossings)

    Summary statistics (median and 68%/95% percentile bounds) of a
    [`mc_boundary_crossing_distribution`](@ref)'s pooled `crossings`, or
    `nothing` if it's empty.
"""
function mc_crossing_stats(crossings::Vector{Float64})
    isempty(crossings) && return nothing
    return (
        median = median(crossings),
        p2_5   = quantile(crossings, 0.025),
        p16    = quantile(crossings, 0.16),
        p84    = quantile(crossings, 0.84),
        p97_5  = quantile(crossings, 0.975),
        n      = length(crossings),
    )
end

"""
    mc_probability_grids(mc_res, specs; max_n = 257)

    Per-node probability that a point lies inside each field of `specs` (a
    vector of `(target, strict)` pairs, see [`mc_field_match`](@ref)): on
    one common query grid (`Xrange`/`Yrange` of `mc_res`, `n x n` nodes with
    `n` = the realizations' own raster size capped at `max_n`, independent of
    any realization's own AMR mesh), the fraction of realizations in which
    the node lies inside the field, taken as the union of the
    [`mc_field_largest_polygons`](@ref) (largest polygon per matching
    assemblage, so fragmentation noise is excluded as in the
    boundary-crossing distribution, without dropping the other assemblages a
    loose target also matches). Each realization's boundaries are traced
    once and shared by all `specs`. Point-in-polygon is one vectorised
    `inpoly2` call per polygon over the whole grid; nodes on a polygon edge
    count as inside. Returns `(x, y, probs, n_present, n_total)`: `x`/`y`
    the node coordinates (T, P in kbar), `probs` one `length(y) x length(x)`
    matrix in [0, 1] (heatmap orientation) per spec, `n_present` how many
    realizations have each field at all (one count per spec).
"""
function mc_probability_grids(mc_res, specs::Vector{<:Tuple{Vector{String},Bool}}; max_n::Int = 257)
    N   = length(mc_res.gridded_fields)
    n   = min(size(mc_res.gridded_fields[1], 1), max_n)
    xs  = collect(range(mc_res.Xrange[1], mc_res.Xrange[2], length = n))
    ys  = collect(range(mc_res.Yrange[1], mc_res.Yrange[2], length = n))
    pts = [repeat(xs, inner = n) repeat(ys, outer = n)]

    ns        = length(specs)
    counts    = [zeros(Int, n * n) for _ in 1:ns]
    n_present = zeros(Int, ns)
    for k in 1:N
        ids, pcoor = compute_assemblage_boundaries(mc_res.gridded_fields[k], mc_res.Xrange, mc_res.Yrange)
        for (j, (target, strict)) in enumerate(specs)
            polys = mc_largest_polygons_per_assemblage(ids, pcoor, mc_res.id2phases[k], target, strict)
            isempty(polys) && continue
            n_present[j] += 1
            inside = falses(n * n)
            for poly in polys
                nodes = Matrix{Float64}(poly)
                size(nodes, 1) > 1 && nodes[1, :] == nodes[end, :] && (nodes = nodes[1:end-1, :])
                size(nodes, 1) < 3 && continue
                stat    = inpoly2(pts, nodes)
                inside .|= stat[:, 1] .| stat[:, 2]
            end
            counts[j] .+= inside
        end
    end

    probs = [reshape(c ./ N, n, n) for c in counts]
    return (x = xs, y = ys, probs = probs, n_present = n_present, n_total = N)
end

"""
    mc_probability_grid(mc_res, target, strict; max_n = 257)

    [`mc_probability_grids`](@ref) for a single field: `(x, y, prob,
    n_present, n_total)` with `prob` its probability matrix.
"""
function mc_probability_grid(mc_res, target::Vector{String}, strict::Bool; max_n::Int = 257)
    g = mc_probability_grids(mc_res, [(target, strict)]; max_n = max_n)
    return (x = g.x, y = g.y, prob = g.probs[1], n_present = g.n_present[1], n_total = g.n_total)
end

"""
    mc_smooth_mask(mask, sigma)

    Gaussian blur of a raster `mask` with standard deviation `sigma` (in
    cells), applied along each axis in turn, with the edge value replicated
    beyond the raster so boundaries that reach the domain edge keep running to
    it. `sigma <= 0` returns `mask` unchanged.
"""
function mc_smooth_mask(mask::AbstractMatrix{<:Real}, sigma::Real)
    sigma <= 0 && return Float64.(mask)
    r      = max(1, ceil(Int, 3 * sigma))
    w      = [exp(-(k^2) / (2 * sigma^2)) for k in -r:r]
    w    ./= sum(w)
    nx, ny = size(mask)
    tmp    = zeros(Float64, nx, ny)
    for j in 1:ny, i in 1:nx
        acc = 0.0
        for k in -r:r
            acc += w[k + r + 1] * mask[clamp(i + k, 1, nx), j]
        end
        tmp[i, j] = acc
    end
    out = zeros(Float64, nx, ny)
    for j in 1:ny, i in 1:nx
        acc = 0.0
        for k in -r:r
            acc += w[k + r + 1] * tmp[i, clamp(j + k, 1, ny)]
        end
        out[i, j] = acc
    end
    return out
end

"""
    mc_chaikin_xy(x, y, iterations)

    Chaikin corner cutting of the polylines in `(x, y)` (separated by
    `nothing`): every segment is replaced by the points at 1/4 and 3/4 of its
    length, `iterations` times. The curve stays inside the original one's hull
    (each pass moves it by at most a quarter of a segment), open lines keep their
    two end points (so lines that end on the domain edge still do), and closed
    lines (first point equal to last) stay closed.
"""
function mc_chaikin_xy(x::AbstractVector, y::AbstractVector, iterations::Int)
    iterations <= 0 && return x, y
    xo = Union{Float64,Nothing}[]
    yo = Union{Float64,Nothing}[]
    i  = 1
    n  = length(x)
    while i <= n
        j = i
        while j <= n && x[j] !== nothing
            j += 1
        end
        px = Float64[x[k] for k in i:j-1]
        py = Float64[y[k] for k in i:j-1]
        for _ in 1:iterations
            length(px) < 3 && break
            closed = px[1] == px[end] && py[1] == py[end]
            nx, ny = Float64[], Float64[]
            closed || (push!(nx, px[1]); push!(ny, py[1]))
            for k in 1:length(px)-1
                push!(nx, 0.75 * px[k] + 0.25 * px[k+1]); push!(ny, 0.75 * py[k] + 0.25 * py[k+1])
                push!(nx, 0.25 * px[k] + 0.75 * px[k+1]); push!(ny, 0.25 * py[k] + 0.75 * py[k+1])
            end
            if closed
                push!(nx, nx[1]); push!(ny, ny[1])
            else
                push!(nx, px[end]); push!(ny, py[end])
            end
            px, py = nx, ny
        end
        isempty(xo) || (push!(xo, nothing); push!(yo, nothing))
        append!(xo, px)
        append!(yo, py)
        i = j + 1
    end
    return xo, yo
end

"""
    mc_phase_boundary_xy(gridded_fields_k, id2phases_k, Xrange, Yrange, ph; smooth = 0)

    The boundary of `ph`'s whole stability region in one raster (`gridded_fields_k`
    with its `id2phases_k`, indexed `[x, y]`), as `get_phase_boundary` gives
    for the reference diagram: a contour at 0.5 of the mask "this phase is
    stable" over the raster. The raster is that mask's own n x n grid (the
    reference mask is built by filling the same grid from the AMR mesh), so a
    realization, which keeps only its raster, gets the same kind of outline as
    the main diagram's reaction lines. That contour has vertices only at cell-edge
    midpoints, so it runs in steps of one raster cell; `smooth > 0` blurs the mask
    by that many cells ([`mc_smooth_mask`](@ref)) before contouring, which puts the
    line at its sub-cell position instead, and `chaikin > 0` then rounds the
    remaining corners ([`mc_chaikin_xy`](@ref)). Returns `(x, y)` with the lines
    separated by `nothing` (empty if `ph` is nowhere or everywhere).
"""
function mc_phase_boundary_xy(gridded_fields_k::Matrix{Int64}, id2phases_k::Dict{Int,Vector{String}},
                               Xrange, Yrange, ph::String; smooth::Real = 0, chaikin::Int = 0)
    nx, ny = size(gridded_fields_k)
    has    = Dict(id => ph in phases for (id, phases) in id2phases_k)
    mask   = [get(has, id, false) ? 1.0 : 0.0 for id in gridded_fields_k]
    smooth > 0 && (mask = mc_smooth_mask(mask, smooth))
    xs     = range(Xrange[1], Xrange[2], length = nx)
    ys     = range(Yrange[1], Yrange[2], length = ny)
    cl     = CTR.contours(xs, ys, mask, [0.5])
    x      = Union{Float64,Nothing}[]
    y      = Union{Float64,Nothing}[]
    for line in CTR.lines(CTR.levels(cl)[1])
        xy = CTR.coordinates(line)
        isempty(x) || (push!(x, nothing); push!(y, nothing))
        append!(x, xy[1])
        append!(y, xy[2])
    end
    return chaikin > 0 ? mc_chaikin_xy(x, y, chaikin) : (x, y)
end

"""
    mc_reference_phase_boundaries(phases, n)

    The reference diagram's own boundary of each phase in `phases`, extracted
    exactly as the main diagram's "Show reaction lines" -> "Update" does
    (`show_hide_reaction_lines`): `get_phase_boundary` contours a mask of
    "this phase is stable" over the reference mesh (`data`/`Out_XY`, `n` = its
    raster size), giving the outline of the phase's whole stability region,
    not the individual assemblage polygons inside it. Returns `(x, y)` with
    every phase's lines pooled into one `nothing`-separated pair of vectors
    (empty if none of the phases has a boundary).
"""
function mc_reference_phase_boundaries(phases::Vector{String}, n::Int)
    global data, Out_XY
    phase = Vector{Int}(undef, length(data.points))
    mask  = zeros(Int, n, n)
    x     = Union{Float64,Nothing}[]
    y     = Union{Float64,Nothing}[]
    for ph in phases
        cl = get_phase_boundary(ph, n, phase, mask, data, Out_XY)
        for line in CTR.lines(CTR.levels(cl)[1])
            xy = CTR.coordinates(line)
            isempty(x) || (push!(x, nothing); push!(y, nothing))
            append!(x, xy[1])
            append!(y, xy[2])
        end
    end
    return x, y
end

"""
    mc_phase_probability(mc_res, ph)

    Per-node probability that phase `ph` is stable, on the realizations' own
    common raster grid (`[x, y]`, `Xrange` x `Yrange`, every realization has the
    same one): the mean over realizations of the binary mask "`ph` is stable"
    built from each realization's `gridded_fields`/`id2phases`. That is the mask
    the main diagram's `get_phase_boundary` contours at 0.5 (see
    [`mc_phase_boundary_xy`](@ref)), so for a single realization the 0.5
    contour of this probability is exactly that realization's phase boundary,
    and the other levels are the same statistic over the ensemble.
"""
function mc_phase_probability(mc_res, ph::String)
    N   = length(mc_res.gridded_fields)
    acc = zeros(Float64, size(mc_res.gridded_fields[1]))
    for k in 1:N
        has  = Dict(id => ph in phases for (id, phases) in mc_res.id2phases[k])
        rast = mc_res.gridded_fields[k]
        for i in eachindex(acc)
            acc[i] += get(has, rast[i], false)
        end
    end
    return acc ./ N
end

"""
    mc_contour_xy(xs, ys, z, level)

    The `level` contour of `z` (`[x, y]`, `length(xs) x length(ys)`) as `(x, y)`
    vectors with the separate lines split by `nothing` (empty if the level is
    not crossed).
"""
function mc_contour_xy(xs, ys, z::AbstractMatrix, level::Real)
    cl = CTR.contours(xs, ys, z, [level])
    x  = Union{Float64,Nothing}[]
    y  = Union{Float64,Nothing}[]
    for line in CTR.lines(CTR.levels(cl)[1])
        xy = CTR.coordinates(line)
        isempty(x) || (push!(x, nothing); push!(y, nothing))
        append!(x, xy[1])
        append!(y, xy[2])
    end
    return x, y
end

"""
    mc_percent_label(fraction)

    `fraction` as a percentage label without a trailing `.0` ("50%", "2.5%").
"""
function mc_percent_label(fraction::Real)
    pct = round(fraction * 100, digits = 1)
    return (isinteger(pct) ? string(Int(pct)) : string(pct)) * "%"
end

"""
    mc_probability_parts(mc_res, ref_gridded_fields, target, strict; levels = (0.025, 0.5, 0.975))

    Everything the probability map shows, as data, in the selected pressure unit:
    `(grid, x, y, prob, phases, reference, levels, xrange, yrange, ticks, title,
    xtitle, ytitle, target, strict)`. `grid` is the target field's own
    [`mc_probability_grid`](@ref) (`x`, `y` in kbar, `prob` `[iy, ix]`, `n_present`,
    `n_total`); `x`/`y`/`prob` repeat it with `y` converted; `phases` holds, per
    phase of `target`, `(ph, label, color, lines)` with `lines` the
    `(level, x, y)` contours of [`mc_phase_probability`](@ref) at `levels` that
    exist (`nothing`-separated segments, the mean of the same "phase is stable"
    mask the main diagram's `get_phase_boundary` contours, in the phase's own
    preset color); `reference` holds, per target phase, the reference diagram's
    own boundary `(ph, label, x, y)` ([`mc_reference_phase_boundaries`](@ref);
    `ref_gridded_fields` only supplies the reference raster size). Both the screen
    figure ([`mc_probability_traces`](@ref)) and the SVG export
    ([`mc_export_probability_svg`](@ref)) are built from this, so they cannot
    drift apart.
"""
function mc_probability_parts(mc_res, ref_gridded_fields, target::Vector{String}, strict::Bool;
                               levels = (0.025, 0.5, 0.975))
    grid   = mc_probability_grid(mc_res, target, strict)
    nx, ny = size(mc_res.gridded_fields[1])
    xs     = range(mc_res.Xrange[1], mc_res.Xrange[2], length = nx)
    ys     = range(mc_res.Yrange[1], mc_res.Yrange[2], length = ny)
    disp(y) = [isnothing(v) ? nothing : display_pressure(v) for v in y]

    phases = NamedTuple[]
    for ph in target
        prob  = mc_phase_probability(mc_res, ph)
        lines = NamedTuple{(:level, :x, :y),Tuple{Float64,Vector{Union{Float64,Nothing}},Vector{Union{Float64,Nothing}}}}[]
        for lvl in levels
            x, y = mc_contour_xy(xs, ys, prob, lvl)
            isempty(x) && continue
            push!(lines, (level = Float64(lvl), x = x, y = disp(y)))
        end
        push!(phases, (ph = ph, label = display_ph_name(ph), color = get_phase_color(ph), lines = lines))
    end

    n_ref     = size(ref_gridded_fields, 1)
    reference = NamedTuple[]
    for ph in target
        rx, ry = mc_reference_phase_boundaries([ph], n_ref)
        isempty(rx) && continue
        push!(reference, (ph = ph, label = display_ph_name(ph), x = rx, y = disp(ry)))
    end

    return (grid = grid, x = grid.x, y = display_pressure(grid.y), prob = grid.prob, phases = phases, reference = reference,
            levels = Tuple(Float64.(levels)), xrange = collect(Float64.(mc_res.Xrange)),
            yrange = [display_pressure(Float64(v)) for v in mc_res.Yrange], ticks = 4,
            title = string(mc_diagram_title("Probability - ")[:text]),
            xtitle = "Temperature [Celsius]", ytitle = "Pressure [$(pressure_unit_label())]",
            target = target, strict = strict)
end

const mc_level_dash  = Dict(0.025 => "dot", 0.5 => "solid", 0.975 => "dash")
const mc_level_width = Dict(0.025 => 1.2,   0.5 => 2.0,     0.975 => 1.2)

"""
    mc_probability_traces_from_parts(parts)

    The probability map's Plotly traces for [`mc_probability_parts`](@ref): the
    P(field) heatmap (x, y and z as three flat vectors of equal length, since
    Dash.jl serializes a `z` matrix flattened and Plotly then cannot draw it - the
    same reason the main diagram passes flat `X`/`Y`), a legend key for the three
    line styles ("P(phase)": dotted lowest level, heavy solid middle level, dashed
    highest level), each phase's contour lines (grouped per phase in the legend,
    the middle level's entry shown) and the reference boundaries pooled into one
    thin black trace.
"""
function mc_probability_traces_from_parts(parts)
    n      = length(parts.x)
    traces = GenericTrace[]

    push!(traces, heatmap(x = repeat(parts.x, n), y = repeat(parts.y, inner = n), z = vec(permutedims(parts.prob)),
                           zmin = 0.0, zmax = 1.0,
                           colorscale = [[0.0, "rgb(255,255,255)"], [1.0, "rgb(200,30,30)"]],
                           colorbar = attr(title = "P(field)", thickness = 12, len = 0.4, y = 1.0, yanchor = "top"),
                           hovertemplate = "T: %{x:.1f}<br>P: %{y:.3g}<br>probability: %{z:.2f}<extra></extra>"))

    mid_level = parts.levels[cld(length(parts.levels), 2)]
    for lvl in parts.levels
        push!(traces, scatter(x = [nothing], y = [nothing], mode = "lines", hoverinfo = "skip",
                               showlegend = true, legendgroup = "levels",
                               legendgrouptitle = attr(text = "P(phase)"),
                               line = attr(color = "#444444", width = get(mc_level_width, lvl, 1.2),
                                           dash = get(mc_level_dash, lvl, "solid")),
                               name = "$(mc_percent_label(lvl))"))
    end

    for set in parts.phases, l in set.lines
        push!(traces, scatter(x = l.x, y = l.y, mode = "lines", hoverinfo = "skip",
                               showlegend = l.level == mid_level, legendgroup = set.ph,
                               line = attr(color = set.color, width = get(mc_level_width, l.level, 1.2),
                                           dash = get(mc_level_dash, l.level, "solid")),
                               name = set.label))
    end

    if !isempty(parts.reference)
        rx = Union{Float64,Nothing}[]
        ry = Union{Float64,Nothing}[]
        for r in parts.reference
            isempty(rx) || (push!(rx, nothing); push!(ry, nothing))
            append!(rx, r.x)
            append!(ry, r.y)
        end
        push!(traces, scatter(x = rx, y = ry, mode = "lines", hoverinfo = "skip", showlegend = false,
                               line = attr(color = "black", width = 0.75), name = "reference"))
    end
    return traces
end

"""
    mc_probability_traces(mc_res, ref_gridded_fields, target, strict; levels = (0.025, 0.5, 0.975))

    [`mc_probability_traces_from_parts`](@ref) of [`mc_probability_parts`](@ref),
    returned with the target field's own `grid` as `(traces, grid)`.
"""
function mc_probability_traces(mc_res, ref_gridded_fields, target::Vector{String}, strict::Bool;
                                levels = (0.025, 0.5, 0.975))
    parts = mc_probability_parts(mc_res, ref_gridded_fields, target, strict; levels = levels)
    return mc_probability_traces_from_parts(parts), parts.grid
end

mc_result = nothing
mc_shown_phases = nothing
mc_shown_max = nothing
const mc_default_max_lines = 64
const mc_smooth_sigma      = 0.75
const mc_smooth_chaikin    = 2
mc_probability_last = nothing

"""
    mc_phases_to_draw()

    The phases to draw one spaghetti color for: the reference diagram's own
    active solution and pure phases (`phase_infos.act_ss`/`act_pp`, the same
    list "Show reaction lines" on the main diagram itself uses), or, if that
    global isn't available, every phase seen anywhere in the last Monte
    Carlo run (see [`mc_all_assemblages`](@ref)) as a fallback.
"""
function mc_phases_to_draw(mc_res)
    global phase_infos
    if @isdefined(phase_infos) && phase_infos !== nothing
        return vcat(phase_infos.act_ss, phase_infos.act_pp)
    end
    return sort(unique(reduce(vcat, mc_all_assemblages(mc_res); init = String[])))
end

"""
    mc_primary_phases()

    Every phase the primary diagram has a phase boundary for: its active solution
    phases then pure phases (`phase_infos.act_ss`/`act_pp`), the same list and
    order as its `data_reaction` traces.
"""
mc_primary_phases() = Vector{String}(vcat(phase_infos.act_ss, phase_infos.act_pp))

"""
    mc_reference_reaction_traces(phases, ref_gridded_fields, Xrange, Yrange; smooth = false)

    The primary diagram's own phase boundaries ("reaction lines") for `phases`,
    exactly as the main phase diagram shows them: the `data_reaction` global,
    one trace per phase (active solution phases then pure phases, the order of
    `phase_infos.act_ss`/`act_pp`) that `show_hide_reaction_lines` builds with
    `get_phase_boundary` and the per-phase line style set in its "Show reaction
    lines" options (dash/width/color, black solid 0.75 by default), refreshed
    whenever the diagram is computed, refined or "Update"d. Returns copies of
    the traces of the requested `phases` only, each named after its phase (the
    main diagram leaves the name empty). With `smooth`, each line's
    geometry is replaced by the same smoothed boundary the realizations get
    (`mc_smooth_sigma`/`mc_smooth_chaikin`, from the reference raster
    `ref_gridded_fields`, whose mask is the one `get_phase_boundary` contours),
    keeping the trace's style. If `data_reaction` is missing or does not match
    `phase_infos`, falls back to plain black lines from the reference raster.
"""
function mc_reference_reaction_traces(phases::Vector{String}, ref_gridded_fields::Matrix{Int64}, Xrange, Yrange;
                                       smooth::Bool = false)
    global phase_infos, Out_XY, Hash_XY
    all_ph = Vector{String}(vcat(phase_infos.act_ss, phase_infos.act_pp))
    keep   = findall(in(phases), all_ph)
    i2p    = mc_id_to_phases(Out_XY, Hash_XY)
    sm, ch = smooth ? (mc_smooth_sigma, mc_smooth_chaikin) : (0.0, 0)

    if @isdefined(data_reaction) && length(data_reaction) == length(all_ph)
        traces = GenericTrace[deepcopy(data_reaction[i]) for i in keep]
        for (t, i) in zip(traces, keep)
            t[:name] = display_ph_name(all_ph[i])
            if smooth
                x, y = mc_phase_boundary_xy(ref_gridded_fields, i2p, Xrange, Yrange, all_ph[i]; smooth = sm, chaikin = ch)
                t[:x] = x
                t[:y] = y
            end
        end
        return traces
    end

    traces = GenericTrace[]
    for i in keep
        x, y = mc_phase_boundary_xy(ref_gridded_fields, i2p, Xrange, Yrange, all_ph[i]; smooth = sm, chaikin = ch)
        isempty(x) && continue
        push!(traces, scatter(x = x, y = y, mode = "lines", hoverinfo = "skip", showlegend = false,
                               line = attr(color = "black", width = 0.75), name = display_ph_name(all_ph[i])))
    end
    return traces
end

"""
    mc_spaghetti_sets(mc_res, Xrange, Yrange; max_realizations = mc_default_max_lines,
                       phases = nothing, smooth = false)

    The realization boundary lines of a Monte Carlo run, one entry per phase in
    [`mc_phases_to_draw`](@ref) (or the subset `phases`, `nothing` = all, empty =
    none) that has any: `(ph, label, color, lines)`, where `lines` holds one
    `(k, x, y)` per drawn realization (`k` its number, `x`/`y` its boundary of that
    phase, [`mc_phase_boundary_xy`](@ref), `nothing`-separated segments) - the
    grouping [`mc_spaghetti_traces`](@ref) pools away and the SVG export needs.
    Only the first `max_realizations` realizations are drawn; `smooth` removes the
    raster's one-cell steps. The color is the phase's own preset (`get_phase_color`).
"""
function mc_spaghetti_sets(mc_res, Xrange, Yrange; max_realizations::Int = mc_default_max_lines,
                            phases::Union{Nothing,Vector{String}} = nothing, smooth::Bool = false)
    sets      = NamedTuple[]
    n_draw    = min(length(mc_res.gridded_fields), max_realizations)
    draw_list = Vector{String}(mc_phases_to_draw(mc_res))
    isnothing(phases) || (draw_list = filter(in(phases), draw_list))

    for ph in draw_list
        lines = NamedTuple{(:k, :x, :y),Tuple{Int,Vector{Union{Float64,Nothing}},Vector{Union{Float64,Nothing}}}}[]
        for k in 1:n_draw
            xk, yk = mc_phase_boundary_xy(mc_res.gridded_fields[k], mc_res.id2phases[k], Xrange, Yrange, ph;
                                          smooth = smooth ? mc_smooth_sigma : 0.0, chaikin = smooth ? mc_smooth_chaikin : 0)
            isempty(xk) && continue
            push!(lines, (k = k, x = xk, y = yk))
        end
        isempty(lines) && continue
        push!(sets, (ph = ph, label = display_ph_name(ph), color = get_phase_color(ph), lines = lines))
    end
    return sets
end

"""
    mc_spaghetti_trace(set)

    One pooled Plotly trace for a [`mc_spaghetti_sets`](@ref) entry: every
    realization's lines in a single `nothing`-separated trace at full opacity,
    the phase's color, width 0.5, legend entry shown (so the swatch shows which
    color is which phase). One trace per phase keeps the trace count independent
    of the number of realizations.
"""
function mc_spaghetti_trace(set)
    x_all = Union{Float64,Nothing}[]
    y_all = Union{Float64,Nothing}[]
    for l in set.lines
        isempty(x_all) || (push!(x_all, nothing); push!(y_all, nothing))
        append!(x_all, l.x)
        append!(y_all, l.y)
    end
    return scatter(x = x_all, y = y_all, mode = "lines", hoverinfo = "skip", showlegend = true,
                   line = attr(color = set.color, width = 0.5), name = set.label)
end

"""
    mc_spaghetti_traces(mc_res, Xrange, Yrange;
                         max_realizations = mc_default_max_lines, phases = nothing, smooth = false)

    Boundary-line traces for a Monte Carlo run's own panel: one pooled trace per
    phase ([`mc_spaghetti_trace`](@ref)) built from [`mc_spaghetti_sets`](@ref),
    which documents the arguments. The lines are every realization's outline of
    the phase's whole stability region, not the polygons of the individual
    assemblages inside it.
"""
function mc_spaghetti_traces(mc_res, Xrange, Yrange; max_realizations::Int = mc_default_max_lines,
                              phases::Union{Nothing,Vector{String}} = nothing, smooth::Bool = false)
    sets = mc_spaghetti_sets(mc_res, Xrange, Yrange; max_realizations = max_realizations, phases = phases, smooth = smooth)
    return GenericTrace[mc_spaghetti_trace(set) for set in sets]
end

"""
    mc_export_svg(mc_res, path; show_labels = false, phases = nothing, max_lines = mc_default_max_lines,
                   show_boundaries = true, smooth_lines = false)

    Write the Uncertainty diagram to `path` as a clean, layered SVG meant to be
    opened in Illustrator (see `src/SVG_export.jl`). What is drawn is exactly what
    [`mc_figure_parts`](@ref) gives the screen figure (same arguments), on the
    writer's own canvas: a 554 x 590 plot area (the screen plot area) inside
    64 / 140 / 48 / 62 margins (left / right / top / bottom). Top-level layers, in
    paint order (each becomes a layer of the same name in Illustrator):

    - `MC_<phase>`: one layer per shown phase, one path per realization
      (`MC_<phase>_017`), stroke color and width on the layer;
    - `Reference_boundaries`: the primary diagram's own phase boundaries, one path
      per phase (`Ref_<phase>`) with the dash/width/color of its main-diagram style;
    - `Labels`: the field labels (real text) and their leader lines, if shown;
    - `Layout`: outline, tick marks on all four sides, tick labels, axis titles and
      the figure title;
    - `Legend`: a swatch line and name per shown phase, in the right margin.

    Lines are clipped to the plot area in Julia, so the file contains no clip
    path, mask, filter, image, pattern or `<defs>`; every path is straight `M`/`L`
    segments. Returns `(path, bytes, n_paths)`.
"""
function mc_export_svg(mc_res, path::AbstractString; show_labels::Bool = false,
                        phases::Union{Nothing,Vector{String}} = nothing, max_lines::Int = mc_default_max_lines,
                        show_boundaries::Bool = true, smooth_lines::Bool = false)
    parts = mc_figure_parts(mc_res; show_labels = show_labels, phases = phases, max_lines = max_lines,
                             show_boundaries = show_boundaries, smooth_lines = smooth_lines)
    xr, yr = parts.xrange, parts.yrange
    c      = SVGCanvas(758.0, 700.0, 64.0, 140.0, 48.0, 62.0, xr[1], xr[2], yr[1], yr[2])
    pw, ph = svg_plot_width(c), svg_plot_height(c)
    left, right, top, bottom = c.ml, c.ml + pw, c.mt, c.mt + ph
    font   = "Helvetica, Arial, sans-serif"
    ink    = "#333333"
    seen   = Set{String}()
    io     = IOBuffer()
    n_paths = 0

    clipped(x, y) = reduce(vcat, [svg_clip_polyline(l, xr[1], xr[2], yr[1], yr[2]) for l in svg_split_polylines(x, y)];
                           init = Vector{Vector{Tuple{Float64,Float64}}}())
    style_of(t, key, default) = (haskey(t[:line], key) && t[:line][key] !== nothing) ? t[:line][key] : default

    svg_open(io, c)

    for set in parts.sets
        svg_group_open(io, svg_id(seen, "MC_" * set.label); stroke = set.color, width = 0.5, fill = "none", rounded = true)
        for l in set.lines
            d = svg_path_data(c, clipped(l.x, l.y))
            isempty(d) && continue
            svg_path(io, svg_id(seen, "MC_$(set.label)_$(lpad(l.k, 3, '0'))"), d)
            n_paths += 1
        end
        svg_group_close(io)
    end

    if !isempty(parts.reference)
        svg_group_open(io, svg_id(seen, "Reference_boundaries"); fill = "none", rounded = true)
        for t in parts.reference
            d = svg_path_data(c, clipped(t[:x], t[:y]))
            isempty(d) && continue
            w = Float64(style_of(t, :width, 0.75))
            svg_path(io, svg_id(seen, "Ref_" * string(t[:name])), d;
                     stroke = string(style_of(t, :color, "#000000")), width = w, dash = svg_dasharray(style_of(t, :dash, nothing), w))
            n_paths += 1
        end
        svg_group_close(io)
    end

    svg_annotation_layer(io, c, seen, parts.annotations; font = font)

    nt = parts.ticks + 1
    svg_layout_layers(io, c, seen; xticks = [xr[1] + k * (xr[2] - xr[1]) / nt for k in 0:nt],
                       yticks = [yr[1] + k * (yr[2] - yr[1]) / nt for k in 0:nt],
                       xtitle = parts.xtitle, ytitle = parts.ytitle, title = parts.title, font = font, ink = ink)

    if !isempty(parts.sets)
        svg_group_open(io, svg_id(seen, "Legend"); font_family = font, font_size = 11, fill = ink)
        for (i, set) in enumerate(parts.sets)
            y = top + 12 + (i - 1) * 19
            svg_path(io, svg_id(seen, "Legend_swatch_$(set.label)"), "M$(svg_num(right + 16)) $(svg_num(y)) L$(svg_num(right + 36)) $(svg_num(y))";
                     stroke = set.color, width = 1.5)
            svg_text(io, right + 42, y, set.label; id = svg_id(seen, "Legend_text_$(set.label)"), anchor = "start")
        end
        svg_group_close(io)
    end

    svg_close(io)
    bytes = take!(io)
    write(path, bytes)
    return (path = String(path), bytes = length(bytes), n_paths = n_paths)
end

"""
    mc_export_probability_svg(parts, path)

    Write the probability map to `path` as a clean, layered SVG for Illustrator,
    from [`mc_probability_parts`](@ref), on the same canvas as
    [`mc_export_svg`](@ref) (758 x 700, 554 x 590 plot area) so the two files line
    up. Layers, in paint order:

    - `Heatmap`: one embedded PNG `<image>` (`P_field_raster`) covering the plot
      area, the P(field) heatmap rasterised by [`svg_heatmap_png`](@ref) (cells
      stay crisp blocks, exact zeros transparent);
    - `P_<phase>`: one per target phase, one path per level (`P_pl_2_5pct` dotted,
      `_50pct` solid and heavy, `_97_5pct` dashed), the phase's color on the layer;
    - `Reference_boundaries`: the reference diagram's own boundary of each target
      phase (`Ref_<phase>`), thin black;
    - `Layout`: outline, ticks, tick labels, axis titles, figure title;
    - `Colorbar`: a gradient bar (the file's only `<defs>`), its 0-1 ticks and title;
    - `Legend`: the line-style key, then a swatch and name per target phase.

    Lines are clipped to the plot area in Julia (no clip path); every path is
    straight `M`/`L` segments. Returns `(path, bytes, n_paths)`.
"""
function mc_export_probability_svg(parts, path::AbstractString)
    xr, yr = parts.xrange, parts.yrange
    c      = SVGCanvas(758.0, 700.0, 64.0, 140.0, 48.0, 62.0, xr[1], xr[2], yr[1], yr[2])
    pw, ph = svg_plot_width(c), svg_plot_height(c)
    left, right, top, bottom = c.ml, c.ml + pw, c.mt, c.mt + ph
    font   = "Helvetica, Arial, sans-serif"
    ink    = "#333333"
    seen   = Set{String}()
    io     = IOBuffer()
    n_paths = 0

    clipped(x, y) = reduce(vcat, [svg_clip_polyline(l, xr[1], xr[2], yr[1], yr[2]) for l in svg_split_polylines(x, y)];
                           init = Vector{Vector{Tuple{Float64,Float64}}}())
    pct_id(lvl)   = replace(mc_percent_label(lvl), "." => "_", "%" => "pct")

    svg_open(io, c; xlink = true)

    png, _, _ = svg_heatmap_png(parts.prob)
    svg_group_open(io, svg_id(seen, "Heatmap"))
    svg_image(io, svg_id(seen, "P_field_raster"), c, png)
    svg_group_close(io)

    for set in parts.phases
        isempty(set.lines) && continue
        svg_group_open(io, svg_id(seen, "P_" * set.label); stroke = set.color, fill = "none", rounded = true)
        for l in set.lines
            d = svg_path_data(c, clipped(l.x, l.y))
            isempty(d) && continue
            w = get(mc_level_width, l.level, 1.2)
            svg_path(io, svg_id(seen, "P_$(set.label)_$(pct_id(l.level))"), d; width = w,
                     dash = svg_dasharray(get(mc_level_dash, l.level, "solid"), w))
            n_paths += 1
        end
        svg_group_close(io)
    end

    if !isempty(parts.reference)
        svg_group_open(io, svg_id(seen, "Reference_boundaries"); stroke = "#000000", width = 0.75, fill = "none", rounded = true)
        for r in parts.reference
            d = svg_path_data(c, clipped(r.x, r.y))
            isempty(d) && continue
            svg_path(io, svg_id(seen, "Ref_" * r.label), d)
            n_paths += 1
        end
        svg_group_close(io)
    end

    nt = parts.ticks + 1
    svg_layout_layers(io, c, seen; xticks = [xr[1] + k * (xr[2] - xr[1]) / nt for k in 0:nt],
                       yticks = [yr[1] + k * (yr[2] - yr[1]) / nt for k in 0:nt],
                       xtitle = parts.xtitle, ytitle = parts.ytitle, title = parts.title, font = font, ink = ink)

    bar_x, bar_w, bar_h = right + 16, 12.0, 0.4 * ph
    svg_group_open(io, svg_id(seen, "Colorbar"); font_family = font, font_size = 10, fill = ink)
    svg_text(io, bar_x, top - 10, "P(field)"; id = svg_id(seen, "Colorbar_title"), size = 11, anchor = "start")
    svg_gradient_bar(io, svg_id(seen, "Colorbar_bar"), bar_x, top, bar_w, bar_h, "rgb(255,255,255)", "rgb(200,30,30)")
    for (k, v) in enumerate(0.0:0.2:1.0)
        svg_text(io, bar_x + bar_w + 5, top + bar_h * (1 - v), svg_tick_label(v); id = svg_id(seen, "Colorbar_tick_$(k)"), anchor = "start")
    end
    svg_group_close(io)

    svg_group_open(io, svg_id(seen, "Legend"); font_family = font, font_size = 11, fill = ink)
    y = top + bar_h + 34
    svg_text(io, right + 16, y, "P(phase)"; id = svg_id(seen, "Legend_key_title"), anchor = "start", size = 11, weight = "bold")
    for lvl in parts.levels
        y += 19
        w  = get(mc_level_width, lvl, 1.2)
        svg_path(io, svg_id(seen, "Legend_key_$(pct_id(lvl))"), "M$(svg_num(right + 16)) $(svg_num(y)) L$(svg_num(right + 36)) $(svg_num(y))";
                 stroke = "#444444", width = w, dash = svg_dasharray(get(mc_level_dash, lvl, "solid"), w))
        svg_text(io, right + 42, y, mc_percent_label(lvl); id = svg_id(seen, "Legend_key_text_$(pct_id(lvl))"), anchor = "start")
    end
    y += 8
    for set in parts.phases
        y += 19
        svg_path(io, svg_id(seen, "Legend_swatch_$(set.label)"), "M$(svg_num(right + 16)) $(svg_num(y)) L$(svg_num(right + 36)) $(svg_num(y))";
                 stroke = set.color, width = 2)
        svg_text(io, right + 42, y, set.label; id = svg_id(seen, "Legend_text_$(set.label)"), anchor = "start")
    end
    svg_group_close(io)

    svg_close(io)
    bytes = take!(io)
    write(path, bytes)
    return (path = String(path), bytes = length(bytes), n_paths = n_paths)
end
