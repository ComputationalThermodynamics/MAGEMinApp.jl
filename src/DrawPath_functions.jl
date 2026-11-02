global diagram_ctx     = nothing
global draw_path_cache = nothing

"""
    DiagramContext

Settings a phase diagram was computed with, captured by [`diagram_context`](@ref) when the
diagram is computed or refined. Used to compute extra points consistent with the diagram
(Draw path intermediate points) after the sidebar may have changed.
"""
struct DiagramContext
    dtb                 :: String
    dataset             :: Int64
    diagType            :: String
    oxi                 :: Vector{String}
    bulk_L              :: Vector{Float64}
    bulk_R              :: Vector{Float64}
    bufferType          :: String
    bufferN1            :: Float64
    bufferN2            :: Float64
    fixT                :: Float64
    fixP                :: Float64
    ptx_P               :: Vector{Float64}
    ptx_T               :: Vector{Float64}
    pChip_wat
    pChip_T
    scp                 :: Int64
    solver              :: Int64
    optimizer           :: Int64
    mbCpx               :: Int64
    limitCaOpx          :: Int64
    CaOpxLim            :: Float64
    phase_selection     :: Union{Nothing,Vector{Int64}}
    Ws
    boost               :: Bool
    seismicScheme       :: String
    seismicWeightFactor :: Float64
    seismic_cor         :: Bool
    aspect_ratio        :: Float64
    seismic_water       :: Int64
    shallow_cor         :: Bool
    fluid_as_melt       :: Bool
    anelastic_cor       :: Bool
end

function diagram_context(   dtb,        dataset,    diagType,   oxi,
                            bulk_L,     bulk_R,     bufferType, bufferN1,   bufferN2,
                            fixT,       fixP,       PTpath,     pChip_wat,  pChip_T,
                            scp,        sol,        optimizer,  mbCpx,      limitCaOpx, CaOpxLim,
                            phase_selection,        custW,      boost,
                            seismicScheme,          seismicWeightFactor,
                            seismic_cor,            aspect_ratio,           seismic_water,
                            shallow_cor,            fluid_as_melt,          anelastic_cor )

    ptx_P, ptx_T = diagType == "ptx" ? ptx_path_PT(PTpath) : (Float64[], Float64[])

    return DiagramContext(  dtb,        dataset,    diagType,   oxi,
                            bulk_L,     bulk_R,     bufferType, bufferN1,   bufferN2,
                            fixT,       fixP,       ptx_P,      ptx_T,      pChip_wat,  pChip_T,
                            scp,        sol,        get_optimizer(dtb, optimizer, sol),
                            mbCpx,      limitCaOpx, CaOpxLim,   phase_selection,
                            get_custom_Ws(custW),   boost,
                            seismicScheme,          seismicWeightFactor,
                            seismic_cor,            aspect_ratio,           seismic_water,
                            shallow_cor,            fluid_as_melt,          anelastic_cor )
end

"""
    draw_path_smoothing_status(ctx)

`(available, message)`: whether Draw path intermediate points can be computed for the
current diagram, and why not otherwise.
"""
function draw_path_smoothing_status(ctx)
    ctx isa DiagramContext || return false, "Intermediate points: recompute the phase diagram to enable them"
    ctx.diagType in DIAGRAM_POINT_TYPES || return false, "Intermediate points are available for P-T, P-X, T-X and PTX diagrams"
    return true, ""
end

function draw_path_unique_ids(path_ids)
    global Out_XY
    ids = Int64[]
    for id in path_ids
        (1 <= id <= length(Out_XY)) || continue
        (isempty(ids) || ids[end] != id) && push!(ids, id)
    end
    return ids
end

"""
    draw_path_samples(xy, n_seg, interp, Xrange, Yrange)

Sample points along the path through the recorded points `xy` (diagram coordinates):
`n_seg` points inside each segment, on straight segments (`interp = "linear"`) or on a
PCHIP curve through the recorded points (`interp = "pchip"`). Both use the cumulative
chord length, each axis normalized by its range, as path parameter `t` ∈ [0, 1].
`rec[i]` is the index of the recorded point (0 for an intermediate point), `seg[i]` the
segment it belongs to.
"""
function draw_path_samples(xy::Vector{NTuple{2,Float64}}, n_seg::Int64, interp::String, Xrange, Yrange)
    m   = length(xy)
    sx  = Xrange[2] - Xrange[1]
    sy  = Yrange[2] - Yrange[1]

    tk  = zeros(Float64, m)
    for k = 2:m
        tk[k] = tk[k-1] + hypot((xy[k][1] - xy[k-1][1]) / sx, (xy[k][2] - xy[k-1][2]) / sy)
    end
    tk[end] > 0.0 && (tk ./= tk[end])

    pchip = interp == "pchip" && m >= 2 && n_seg > 0
    if pchip
        ix = Interpolator(tk, first.(xy))
        iy = Interpolator(tk, last.(xy))
    end
    xmin, xmax = extrema(Xrange)
    ymin, ymax = extrema(Yrange)

    x, y, t, rec, seg = Float64[], Float64[], Float64[], Int64[], Int64[]
    for k = 1:m
        push!(x, xy[k][1]); push!(y, xy[k][2]); push!(t, tk[k]); push!(rec, k); push!(seg, k)
        k == m && break
        for j = 1:n_seg
            f  = j / (n_seg + 1)
            tj = tk[k] + f * (tk[k+1] - tk[k])
            if pchip
                xj, yj = ix(tj), iy(tj)
            else
                xj = xy[k][1] + f * (xy[k+1][1] - xy[k][1])
                yj = xy[k][2] + f * (xy[k+1][2] - xy[k][2])
            end
            push!(x, clamp(xj, xmin, xmax)); push!(y, clamp(yj, ymin, ymax)); push!(t, tj); push!(rec, 0); push!(seg, k)
        end
    end

    return (x = x, y = y, t = t, rec = rec, seg = seg)
end

"""
    compute_draw_path_points(ctx, ids, smp)

Outputs at every sample of `smp` ([`draw_path_samples`](@ref)): recorded points reuse their
`Out_XY` entry, intermediate points are minimized in one batch with the settings of the
diagram (`ctx`), their inputs built by [`diagram_point_builder`](@ref) as the AMR mesh
points, seeded with the solutions of the two recorded points of their segment.
"""
function compute_draw_path_points(ctx::DiagramContext, ids::Vector{Int64}, smp)
    global Out_XY

    outs = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, length(smp.t))
    for (i, r) in enumerate(smp.rec)
        r > 0 && (outs[i] = Out_XY[ids[r]])
    end

    new_k = findall(==(0), smp.rec)
    isempty(new_k) && return outs

    n            = length(new_k)
    point_inputs = diagram_point_builder(   ctx.diagType,   ctx.oxi,        ctx.bulk_L,     ctx.bulk_R,
                                            ctx.bufferN1,   ctx.bufferN2,   ctx.fixT,       ctx.fixP,
                                            (ctx.ptx_P, ctx.ptx_T),         ctx.pChip_wat,  ctx.pChip_T )
    Pvec = zeros(Float64, n)
    Tvec = zeros(Float64, n)
    Xvec = Vector{Vector{Float64}}(undef, n)
    Bvec = zeros(Float64, n)
    for (i, k) in enumerate(new_k)
        Pvec[i], Tvec[i], Xvec[i], Bvec[i], _ = point_inputs(smp.x[k], smp.y[k])
    end

    if ctx.boost
        Gvec = Vector{Vector{LibMAGEMin.mSS_data}}(undef, n)
        for (i, k) in enumerate(new_k)
            Gvec[i] = vcat(Out_XY[ids[smp.seg[k]]].mSS_vec, Out_XY[ids[smp.seg[k]+1]].mSS_vec)
        end
        Ivec = fill(true, n)
    else
        Gvec = nothing
        Ivec = false
    end

    MAGEMin_data = Initialize_MAGEMin(  ctx.dtb;
                                        verbose             = false,
                                        dataset             = ctx.dataset,
                                        limitCaOpx          = ctx.limitCaOpx,
                                        CaOpxLim            = ctx.CaOpxLim,
                                        mbCpx               = ctx.mbCpx,
                                        buffer              = ctx.bufferType,
                                        solver              = ctx.solver,
                                        optimizer           = ctx.optimizer,
                                        seismicScheme       = ctx.seismicScheme,
                                        seismicWeightFactor = ctx.seismicWeightFactor )
    local new_outs
    try
        set_magemin_buffer!(MAGEMin_data, ctx.bufferType)
        new_outs = locked_multi_point_minimization( Pvec, Tvec, MAGEMin_data;
                                                    X = Xvec, B = Bvec, Xoxides = ctx.oxi, sys_in = "mol", G = Gvec, scp = ctx.scp,
                                                    rm_list = ctx.phase_selection, name_solvus = true,
                                                    fixed_bulk = diagram_fixed_bulk(ctx.diagType, ctx.dtb, ctx.pChip_wat),
                                                    iguess = Ivec, W = ctx.Ws,
                                                    seismic_cor = ctx.seismic_cor, aspect_ratio = ctx.aspect_ratio, seismic_water = ctx.seismic_water,
                                                    shallow_correction = ctx.shallow_cor, fluid_as_melt = ctx.fluid_as_melt, anelastic_cor = ctx.anelastic_cor )
    finally
        finalize_MAGEMin_data(MAGEMin_data)
    end

    for (i, k) in enumerate(new_k)
        ctx.diagType in ("tx", "px", "ptx") && (new_outs[i].X .= smp.x[k])
        outs[k] = new_outs[i]
    end

    return outs
end

"""
    draw_path_data(path_ids, n_seg, interp)

The recorded Draw path, optionally densified with `n_seg` MAGEMin points per segment
([`compute_draw_path_points`](@ref)), and a status message. Computed intermediate points
are cached until the path, the settings or the diagram change.
"""
function draw_path_data(path_ids, n_seg::Int64, interp::String)
    global Out_XY, data, diagram_ctx, draw_path_cache

    ids         = draw_path_unique_ids(path_ids)
    ok, msg     = draw_path_smoothing_status(diagram_ctx)
    n_use       = (ok && n_seg > 0) ? n_seg : 0
    xy          = [(Float64(data.points[id][1]), Float64(data.points[id][2])) for id in ids]
    smp         = draw_path_samples(xy, n_use, interp, data.Xrange, data.Yrange)
    status      = n_seg > 0 ? msg : ""

    if n_use == 0
        outs = [Out_XY[ids[r]] for r in smp.rec]
    else
        key = (copy(ids), n_use, interp, objectid(Out_XY), objectid(diagram_ctx))
        if !isnothing(draw_path_cache) && draw_path_cache.key == key
            outs, status = draw_path_cache.outs, draw_path_cache.status
        else
            t      = @elapsed outs = compute_draw_path_points(diagram_ctx, ids, smp)
            status = "$(count(==(0), smp.rec)) intermediate points computed in $(round(t, digits = 2)) s"
            println(status)
            draw_path_cache = (key = key, outs = outs, status = status)
        end
    end

    return (ids = ids, x = smp.x, y = smp.y, t = smp.t, rec = smp.rec, outs = outs), status
end

function draw_path_label(diagType, out, xd)
    xl       = diagType in ("pmu", "tmu") ? "μ" : "X"
    diagType = section_x_fixed_P(diagType) || diagType == "tmu" ? "tx" : diagType in ("vx", "pmu") ? "px" : diagType
    P = round(display_pressure(out.P_kbar), digits=2)
    T = round(out.T_C, digits=2)
    if diagType == "px" || diagType == "tx"
        X = round(xd, digits=4)
        return diagType == "px" ? "$(xl)=$(X); P=$(P)" : "$(xl)=$(X); T=$(T)"
    else
        return "T=$(T); P=$(P)"
    end
end

draw_path_labels(diagType, path) = [draw_path_label(diagType, path.outs[i], path.x[i]) for i in eachindex(path.outs)]

function draw_path_ticks(diagType, path)
    rec = findall(>(0), path.rec)
    return path.t[rec], [draw_path_label(diagType, path.outs[i], path.x[i]) for i in rec]
end
