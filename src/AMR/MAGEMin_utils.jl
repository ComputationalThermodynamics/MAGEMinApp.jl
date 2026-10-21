
"""
    compute_mumu_bounds(    fixP,           fixT,
                            bulk_ref,       oxi,
                            oxide1_idx,     oxide2_idx,
                            oxide1_min,     oxide1_max,
                            oxide2_min,     oxide2_max,
                            dtb,            bufferType, solver,
                            verbose,        bufferN,    phase_selection,
                            cpx,            limOpx,     limOpxVal   )

    Pre-pass for a mu-mu (chemical potential) diagram: at fixed P,T and the
    reference bulk composition, runs 4 single-point minimizations — oxide1
    at its min/max content bound (oxide2 held at its reference value), then
    oxide2 at its min/max bound (oxide1 held at its reference value) — and
    reads off the resulting chemical potentials (`Gamma`) for the varied
    oxide from each. This determines the μ-axis bounds a mu-mu grid should
    span (μ generally moves non-monotonically-predictably with which bound
    is "min"/"max" content, so the two evaluated values are sorted into
    (mu_min, mu_max) rather than assumed to correspond directly to
    (content_min, content_max)).

    Self-contained (own single-thread `init_MAGEMin` instance) so it can run
    standalone from a "Compute μ bounds" UI action before any AMR mesh or
    the main multi-threaded `MAGEMin_data` bundle exists — mirrors
    `get_wat_sat_function`'s pre-pass pattern below.

    Returns `(mu1_bounds, mu2_bounds, statuses, ok)` where `statuses` is the
    4 `gmin_struct.status` values (0 = converged, 5 = not converged) in
    (oxide1_min, oxide1_max, oxide2_min, oxide2_max) order, and `ok` is
    `all(statuses .== 0)`.
"""
function compute_mumu_bounds(   fixP            :: Float64,
                                fixT            :: Float64,
                                bulk_ref        :: Vector{Float64},
                                oxi             :: Vector{String},
                                oxide1_idx      :: Int64,
                                oxide2_idx      :: Int64,
                                oxide1_min      :: Float64,
                                oxide1_max      :: Float64,
                                oxide2_min      :: Float64,
                                oxide2_max      :: Float64,
                                dtb             :: String,
                                bufferType      :: String,
                                solver          :: String,
                                verbose,
                                bufferN         :: Float64,
                                phase_selection,
                                cpx,            limOpx,     limOpxVal;
                                optimizer       = "nlopt"   )

    mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb, solver, cpx, limOpx, limOpxVal )

    gv, z_b, DB, splx_data = init_MAGEMin(  dtb;
                                            verbose     = verbose,
                                            mbCpx       = mbCpx,
                                            limitCaOpx  = limitCaOpx,
                                            CaOpxLim    = CaOpxLim,
                                            buffer      = bufferType,
                                            solver      = sol,
                                            optimizer   = get_optimizer(dtb, optimizer, sol)    );

    sys_in  = "mol"

    function eval_gamma(content1, content2, target_idx)
        trial               = deepcopy(bulk_ref)
        trial[oxide1_idx]   = content1
        trial[oxide2_idx]   = content2
        gv2     = define_bulk_rock(gv, trial, oxi, sys_in, dtb)
        out     = deepcopy( point_wise_minimization(fixP, fixT, gv2, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
        return out.Gamma[target_idx], out.status
    end

    mu1_a, status_1a  = eval_gamma(oxide1_min, bulk_ref[oxide2_idx], oxide1_idx)
    mu1_b, status_1b  = eval_gamma(oxide1_max, bulk_ref[oxide2_idx], oxide1_idx)
    mu2_a, status_2a  = eval_gamma(bulk_ref[oxide1_idx], oxide2_min, oxide2_idx)
    mu2_b, status_2b  = eval_gamma(bulk_ref[oxide1_idx], oxide2_max, oxide2_idx)

    LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))

    mu1_bounds  = (min(mu1_a,mu1_b), max(mu1_a,mu1_b))
    mu2_bounds  = (min(mu2_a,mu2_b), max(mu2_a,mu2_b))
    statuses    = (status_1a, status_1b, status_2a, status_2b)
    ok          = all(statuses .== 0)

    return mu1_bounds, mu2_bounds, statuses, ok
end


"""
    SECTION_TYPES

    Diagram types computed at fixed entropy, volume and/or enthalpy with MAGEMin_C's `multi_point_section`:
    "ps" (S-P), "pv" (V-P), "ts" (T-S), "tv" (T-V), "sv" (S-V), "ph" (H-P), "sh" (S-H), "vh" (V-H) and "rh" (ρ-H). Axes
    follow `MAGEMin_C.SECTION_XY`; on screen S is in J/K/mol, V in cm³/mol, H in kJ/mol (per mol of bulk oxides) and ρ
    (system density) in kg/m³.
"""
const SECTION_TYPES     = ("ps", "pv", "ts", "tv", "sv", "ph", "sh", "vh", "rh")

"""
    SECTION_X_TYPES

    Section diagrams on the bulk mixing axis X (bulk(X) = (1 - X) bulk1 + X bulk2, as for T-X / P-X):
    "sx" (S-X at fixed pressure, temperature solved), "hx" (H-X at fixed pressure, temperature solved)
    and "vx" (V-X at fixed temperature, pressure solved). Each point is a P-S (`:ps`), P-H (`:ph`) or
    T-V (`:tv`) section at its own bulk.
"""
const SECTION_X_TYPES   = ("sx", "hx", "vx")

section_x_fixed_P(diagType) = diagType in ("sx", "hx")
section_x_prop(diagType)    = diagType == "sx" ? :S : diagType == "hx" ? :H : :V
section_x_mode(diagType)    = diagType == "sx" ? :ps : diagType == "hx" ? :ph : :tv
section_axis_title(c::Symbol) = c === :P ? "Pressure [$(pressure_unit_label())]" : c === :T ? "Temperature [Celsius]" :
                                c === :S ? "Entropy [J/K/mol]" : c === :H ? "Enthalpy [kJ/mol]" : c === :rho ? "Density [kg/m³]" : "Volume [cm³/mol]"
pressure_on_y_axis(diagType) = diagType in ("pt", "px", "ptx") || (diagType in SECTION_TYPES && MAGEMin_C.SECTION_XY[Symbol(diagType)][2] === :P)
const SECTION_VOID_HASH = hash("section-void")

function mask_section_void!(field, hashes)
    length(hashes) == length(field) || return field
    for i in eachindex(field)
        hashes[i] == SECTION_VOID_HASH && (field[i] = missing)
    end
    return field
end

section_from_display(c::Symbol, v) = c === :S ? Float64(v)/1000.0 : Float64(v)
section_to_display(c::Symbol, v)   = c === :S ? Float64(v)*1000.0 : Float64(v)

"""
    section_search_box(Pc, Tc; limits = nothing, widen = 3.0)

    Search box of the free pressure/temperature of a section diagram with P-T box `Pc = (P1, P2)`
    [kbar] and `Tc = (T1, T2)` [°C]. `limits = (Pmin, Pmax, Tmin, Tmax)` [kbar, °C] sets the bounds;
    an entry `nothing` is automatic: the box widened by `widen` times its span on that side,
    with P >= 0.001 kbar and T >= 25 °C. The search box always contains the P-T box.
"""
function section_search_box(Pc, Tc; limits = nothing, widen = 3.0)
    Plo, Phi = extrema(Float64.(Pc))
    Tlo, Thi = extrema(Float64.(Tc))
    dP, dT   = max(Phi - Plo, 1.0), max(Thi - Tlo, 50.0)
    lim      = isnothing(limits) ? (nothing, nothing, nothing, nothing) : limits
    pick(v, auto) = isnothing(v) ? auto : Float64(v)
    Pmin     = min(Plo, max(0.001, pick(lim[1], Plo - widen*dP)))
    Pmax     = max(Phi, pick(lim[2], Phi + widen*dP))
    Tmin     = min(Tlo, max(0.0, pick(lim[3], max(25.0, Tlo - widen*dT))))
    Tmax     = max(Thi, pick(lim[4], Thi + widen*dT))
    return (Pmin, Pmax), (Tmin, Tmax)
end

"""
    section_fresh_seeds(seeds, MAGEMin_data; X = nothing, B = nothing, Xoxides = String[], rm_list = nothing, W = nothing, scp = 0, kwargs...)

    Fresh point-wise minimizations at the P-T of each group of section results in `seeds` (one vector per target),
    for the bulk `X` (mol), buffer offset `B` and phase selection `rm_list`. Returns one vector of results per group.
"""
function section_fresh_seeds(seeds, MAGEMin_data; X = nothing, B = nothing, Xoxides = String[], rm_list = nothing, W = nothing, scp = 0, kwargs...)
    Ps      = Float64[s.P_kbar for sd in seeds for s in sd]
    Ts      = Float64[s.T_C    for sd in seeds for s in sd]
    isempty(Ps) && return [similar(sd, 0) for sd in seeds]
    Bv      = isnothing(B) ? nothing : fill(Float64(B isa Number ? B : first(B)), length(Ps))
    out     = MAGEMin_C.multi_point_minimization(Ps, Ts, MAGEMin_data; X = X, B = Bv, Xoxides = Xoxides, sys_in = "mol",
                                                 rm_list = rm_list, W = W, scp = scp, name_solvus = true, progressbar = false)
    off     = cumsum(vcat(0, length.(seeds)))
    return [out[off[m] + 1:off[m + 1]] for m in eachindex(seeds)]
end

"""
    section_fill_holes!(sec, npoints, outs, infos, MAGEMin_data, data; Pbox, Tbox, xrange, yrange, n_near = 8, min_ok = 6, n_seeds = 4, max_rounds = 3, tried, kwargs...)

    Re-solve the isolated failures of a section diagram after one AMR level: points (new, or failed at an earlier
    level) that failed while at least `min_ok` of their `n_near` nearest points (distances scaled by the diagram
    ranges) converged. Each is solved again from its `n_seeds` nearest converged points, with the 2-D log-P
    stepping of `MAGEMin_C.multi_point_section` (`log_P_2d`), their phase compositions as initial guess
    (`warm`) and up to 32 iterations, and replaced when it converges (new points in
    `outs`/`infos`, earlier points in `Out_XY`/`Sec_status_XY`). Points that still fail are solved once more
    from fresh minimizations at the P-T of the same neighbours ([`section_fresh_seeds`](@ref)). Recovered points
    count as converged neighbours in the next of up to `max_rounds` rounds, which reaches small clusters of
    failures; a point is tried again only when its converged neighbours changed. Failures at the border of the
    reachable domain have fewer converged neighbours and are left as they are. `tried` maps the coordinates of
    each point already tried to those of its converged neighbours; passing the same `Dict` at every AMR level
    skips the failures whose neighbourhood did not change.

    Returns the number of recovered points.
"""
function section_fill_holes!(   sec         :: Symbol,
                                npoints,
                                outs,
                                infos,
                                MAGEMin_data,
                                data;
                                Pbox, Tbox, xrange, yrange,
                                n_near      :: Int64 = 8,
                                min_ok      :: Int64 = 6,
                                n_seeds     :: Int64 = 4,
                                max_rounds  :: Int64 = 3,
                                tried       :: Dict{NTuple{2, Float64}, Vector{NTuple{2, Float64}}} = Dict{NTuple{2, Float64}, Vector{NTuple{2, Float64}}}(),
                                kwargs... )

    ax      = MAGEMin_C.SECTION_XY[sec]
    n_old   = length(Out_XY)
    coords  = vcat([Float64.(data.points[j][1:2]) for j in 1:n_old], [Float64.(p[1:2]) for p in npoints])
    ok      = vcat([j <= length(Sec_status_XY) && Sec_status_XY[j] == 0 for j in 1:n_old], [i.status == 0 for i in infos])
    res     = vcat([Out_XY[j] for j in 1:n_old], collect(outs))
    sx      = max(data.Xrange[2] - data.Xrange[1], eps())
    sy      = max(data.Yrange[2] - data.Yrange[1], eps())
    n_fill  = 0
    for _ in 1:max_rounds
        holes   = Int[]
        seeds   = Vector{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}}()
        for g in eachindex(coords)
            ok[g] && continue
            c   = coords[g]
            d   = [((q[1] - c[1]) / sx)^2 + ((q[2] - c[2]) / sy)^2 for q in coords]
            d[g] = Inf
            nn  = partialsortperm(d, 1:min(n_near, length(d) - 1))
            good = [j for j in nn if ok[j]]
            length(good) >= min_ok || continue
            key     = (c[1], c[2])
            near    = [(coords[j][1], coords[j][2]) for j in good]
            get(tried, key, NTuple{2, Float64}[]) == near && continue
            tried[key] = near
            push!(holes, g)
            push!(seeds, res[good[1:min(n_seeds, length(good))]])
        end
        isempty(holes) && break
        xs      = [section_from_display(ax[1], coords[g][1]) for g in holes]
        ys      = [section_from_display(ax[2], coords[g][2]) for g in holes]
        fill_solve(idx, sds) = MAGEMin_C.multi_point_section(sec, xs[idx], ys[idx], MAGEMin_data; Pbox = Pbox, Tbox = Tbox, seeds = sds, xrange = xrange, yrange = yrange,
                                                sys_in = "mol", name_solvus = true, log_P_2d = true, warm = true, maxit = 32, retry_passes = 0, progressbar = false, kwargs...)
        o2, i2  = fill_solve(eachindex(holes), seeds)
        rest    = [k for k in eachindex(holes) if i2[k].status != 0]
        if !isempty(rest)
            fresh   = section_fresh_seeds([seeds[k] for k in rest], MAGEMin_data; kwargs...)
            o3, i3  = fill_solve(rest, fresh)
            for (m, k) in enumerate(rest)
                i3[m].status == 0 || continue
                o2[k], i2[k] = o3[m], i3[m]
            end
        end
        n_round = 0
        for (k, g) in enumerate(holes)
            i2[k].status == 0 || continue
            if g > n_old
                outs[g - n_old]  = o2[k]
                infos[g - n_old] = i2[k]
            else
                Out_XY[g]        = o2[k]
                Sec_status_XY[g] = 0
            end
            ok[g], res[g] = true, o2[k]
            n_round += 1
        end
        n_fill += n_round
        n_round == 0 && break
    end
    return n_fill
end

"""
    SECTION_RANGE_MODES

    How the axis ranges of a section diagram (`SECTION_TYPES`) follow from its P-T box:
    "inscribed" (largest rectangle inside the image of the box, every target reachable),
    "reachable" (largest rectangle inside the image of the search box, inset by 2 %, so every target is
    reachable within the search limits), "bounding" (bounding box of the image) or "manual" (ranges entered
    by the user).
"""
const SECTION_RANGE_MODES = ("inscribed", "reachable", "bounding", "manual")

section_range_mode(mode) = mode in SECTION_RANGE_MODES ? String(mode) : "inscribed"
section_widen(mode)      = section_range_mode(mode) == "manual" ? 3.0 : 0.25

"""
    section_limits(Pbox, Tbox, limits, mode)

    Search box of a section diagram as a fully numeric `(Pmin, Pmax, Tmin, Tmax)` [kbar, °C]: the
    user `limits` (entries `nothing` are automatic) around the P-T box, widened by
    [`section_widen`](@ref) of the range `mode`.
"""
function section_limits(Pbox, Tbox, limits, mode)
    sP, sT = section_search_box(Pbox, Tbox; limits = limits, widen = section_widen(mode))
    return (sP[1], sP[2], sT[1], sT[2])
end

function section_box_boundary(Pbox, Tbox, n::Int64)
    Plo, Phi = extrema(Float64.(Pbox))
    Tlo, Thi = extrema(Float64.(Tbox))
    s        = collect(range(0.0, 1.0, length = n + 1))[1:n]
    P        = vcat(fill(Plo, n), Plo .+ s .* (Phi - Plo), fill(Phi, n), Phi .- s .* (Phi - Plo))
    T        = vcat(Tlo .+ s .* (Thi - Tlo), fill(Thi, n), Thi .- s .* (Thi - Tlo), fill(Tlo, n))
    return P, T
end

"""
    section_inscribed_rect(xs, ys; n = 200)

    Largest axis-aligned rectangle inside the closed polygon `(xs, ys)`, in coordinates normalized
    by the polygon extents. The polygon is rasterized on an `n × n` grid (even-odd rule at the cell
    centres) and the largest all-inside block is found row by row with a histogram stack; its bounds
    are the centres of its outer cells. Returns `(xrange, yrange, ok)`.
"""
function section_inscribed_rect(xs::Vector{Float64}, ys::Vector{Float64}; n::Int64 = 200)
    xlo, xhi = extrema(xs)
    ylo, yhi = extrema(ys)
    (length(xs) >= 3 && xhi > xlo && yhi > ylo) || return (xlo, xhi), (ylo, yhi), false
    u        = (xs .- xlo) ./ (xhi - xlo)
    v        = (ys .- ylo) ./ (yhi - ylo)
    m        = length(u)
    inside   = falses(n, n)
    xc       = Float64[]
    for iy in 1:n
        yc = (iy - 0.5) / n
        empty!(xc)
        for k in 1:m
            k2 = k == m ? 1 : k + 1
            (v[k] > yc) != (v[k2] > yc) || continue
            push!(xc, u[k] + (yc - v[k]) * (u[k2] - u[k]) / (v[k2] - v[k]))
        end
        sort!(xc)
        for j in 1:2:length(xc)-1
            i0 = max(1, ceil(Int64, xc[j] * n + 0.5))
            i1 = min(n, floor(Int64, xc[j+1] * n + 0.5))
            i0 <= i1 && (inside[iy, i0:i1] .= true)
        end
    end
    h        = zeros(Int64, n)
    stack    = Int64[]
    best     = 0
    br       = (1, 1, 1, 1)
    for iy in 1:n
        for ix in 1:n
            h[ix] = inside[iy, ix] ? h[ix] + 1 : 0
        end
        empty!(stack)
        for ix in 1:n+1
            cur = ix <= n ? h[ix] : 0
            while !isempty(stack) && h[stack[end]] >= cur
                top    = pop!(stack)
                left   = isempty(stack) ? 1 : stack[end] + 1
                area   = h[top] * (ix - left)
                if area > best
                    best = area
                    br   = (left, ix - 1, iy - h[top] + 1, iy)
                end
            end
            push!(stack, ix)
        end
    end
    (br[2] > br[1] && br[4] > br[3]) || return (xlo, xhi), (ylo, yhi), false
    cx(i) = xlo + (i - 0.5) / n * (xhi - xlo)
    cy(i) = ylo + (i - 0.5) / n * (yhi - ylo)
    return (cx(br[1]), cx(br[2])), (cy(br[3]), cy(br[4])), true
end

"""
    section_box_image(diagType, Pbox, Tbox, bulk_ref, oxi, dtb, bufferType, solver, bufferN, phase_selection, cpx, limOpx, limOpxVal; optimizer="nlopt", dataset=nothing, n_edge=16)

    Image of the boundary of the P-T box `Pbox` [kbar] x `Tbox` [°C] in the axes of a section diagram
    (`SECTION_TYPES`): point minimizations at `n_edge` points per edge, counter-clockwise from
    (Pmin, Tmin). Points that failed (status >= 3) are dropped. A jump across a univariant reaction is
    closed by the straight segment between its two sides, the two-phase states the section solver
    reaches. Returns `(xs, ys)` in display units (S in J/K/mol, V in cm³/mol, H in kJ/mol, P in kbar).
"""
function section_box_image( diagType        :: String,
                            Pbox, Tbox,
                            bulk_ref        :: Vector{Float64},
                            oxi             :: Vector{String},
                            dtb             :: String,
                            bufferType      :: String,
                            solver          :: String,
                            bufferN         :: Float64,
                            phase_selection,
                            cpx,            limOpx,     limOpxVal;
                            optimizer       = "nlopt",
                            dataset         = nothing,
                            n_edge          :: Int64 = 16 )

    mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb, solver, cpx, limOpx, limOpxVal )
    ax      = MAGEMin_C.SECTION_XY[Symbol(diagType)]
    P, T    = section_box_boundary(Pbox, Tbox, n_edge)
    outs    = nothing
    MAGEMin_data = nothing
    try
        MAGEMin_data = Initialize_MAGEMin(  dtb;
                                            verbose     = false,
                                            dataset     = dataset,
                                            mbCpx       = mbCpx,
                                            limitCaOpx  = limitCaOpx,
                                            CaOpxLim    = CaOpxLim,
                                            buffer      = bufferType,
                                            solver      = sol,
                                            optimizer   = get_optimizer(dtb, optimizer, sol)    )
        outs    = multi_point_minimization( P, T, MAGEMin_data;
                                            X           = bulk_ref,
                                            B           = fill(bufferN, length(P)),
                                            Xoxides     = oxi,
                                            sys_in      = "mol",
                                            rm_list     = phase_selection,
                                            name_solvus = true,
                                            progressbar = false )
    finally
        isnothing(MAGEMin_data) || Finalize_MAGEMin(MAGEMin_data)
    end
    good    = [o for o in outs if o.status < 3]
    xs      = [section_to_display(ax[1], MAGEMin_C.section_value(o, ax[1])) for o in good]
    ys      = [section_to_display(ax[2], MAGEMin_C.section_value(o, ax[2])) for o in good]
    return xs, ys
end

"""
    section_box_ranges(diagType, Pbox, Tbox, bulk_ref, oxi, dtb, bufferType, solver, bufferN, phase_selection, cpx, limOpx, limOpxVal; mode="inscribed", optimizer="nlopt", dataset=nothing)

    Axis ranges of a section diagram (`SECTION_TYPES`) from the image of its P-T box
    ([`section_box_image`](@ref)): the largest inscribed rectangle (`mode = "inscribed"`) or the
    bounding box (`"bounding"`). Returns `(Xrange, Yrange, (xs, ys), ok)` in display units, with
    `(xs, ys)` the image polygon; `ok` is false when too few boundary points converged or the
    rectangle is degenerate.
"""
function section_box_ranges(diagType        :: String,
                            Pbox, Tbox,
                            bulk_ref        :: Vector{Float64},
                            oxi             :: Vector{String},
                            dtb             :: String,
                            bufferType      :: String,
                            solver          :: String,
                            bufferN         :: Float64,
                            phase_selection,
                            cpx,            limOpx,     limOpxVal;
                            mode            = "inscribed",
                            limits          = nothing,
                            optimizer       = "nlopt",
                            dataset         = nothing  )

    xs, ys  = section_box_image(diagType, Pbox, Tbox, bulk_ref, oxi, dtb, bufferType, solver, bufferN, phase_selection,
                                cpx, limOpx, limOpxVal; optimizer = optimizer, dataset = dataset)
    length(xs) >= 3 || return (NaN, NaN), (NaN, NaN), (xs, ys), false
    if section_range_mode(mode) == "bounding"
        rx, ry  = extrema(xs), extrema(ys)
        ok      = rx[2] > rx[1] && ry[2] > ry[1]
    elseif section_range_mode(mode) == "reachable"
        lim     = section_limits(Pbox, Tbox, something(limits, (nothing, nothing, nothing, nothing)), mode)
        sxs, sys = section_box_image(diagType, (lim[1], lim[2]), (lim[3], lim[4]), bulk_ref, oxi, dtb, bufferType, solver, bufferN, phase_selection,
                                     cpx, limOpx, limOpxVal; optimizer = optimizer, dataset = dataset)
        length(sxs) >= 3 || return (NaN, NaN), (NaN, NaN), (xs, ys), false
        rx, ry, ok = section_inscribed_rect(sxs, sys)
        inset(r) = (r[1] + 0.02*(r[2] - r[1]), r[2] - 0.02*(r[2] - r[1]))
        ok && ((rx, ry) = (inset(rx), inset(ry)))
    else
        rx, ry, ok = section_inscribed_rect(xs, ys)
    end
    return rx, ry, (xs, ys), ok
end

"""
    section_manual_ranges(diagType, xmin, xmax, ymin, ymax)

    Axis ranges of a section diagram entered by the user in display units (P in the display pressure
    unit). Returns `(Xrange, Yrange, ok)` with P in kbar.
"""
function section_manual_ranges(diagType::String, xmin, xmax, ymin, ymax)
    all(v -> v isa Number, (xmin, xmax, ymin, ymax)) || return (NaN, NaN), (NaN, NaN), false
    ax      = MAGEMin_C.SECTION_XY[Symbol(diagType)]
    cv(v, c) = c === :P ? to_kbar_pressure(Float64(v)) : Float64(v)
    rx      = extrema((cv(xmin, ax[1]), cv(xmax, ax[1])))
    ry      = extrema((cv(ymin, ax[2]), cv(ymax, ax[2])))
    return rx, ry, rx[2] > rx[1] && ry[2] > ry[1]
end

"""
    section_x_ranges(diagType, fixv, bnd, bulk_L, bulk_R, bufferN1, bufferN2, oxi, dtb, bufferType, solver, phase_selection, cpx, limOpx, limOpxVal; optimizer="nlopt", dataset=nothing)

    Y-axis range of an S-X or H-X (`fixv` = fixed P [kbar], `bnd` = (T_lo, T_hi) [°C]) or V-X (`fixv` =
    fixed T [°C], `bnd` = (P_lo, P_hi) [kbar]) diagram by the corner approach: point minimizations at
    X = 0 and 1 at both bounds of the free variable; the range spans the four corner values (S and H
    rise with T, V falls with P). Returns `(Yrange, ok)` in display units (S in J/K/mol, V in cm³/mol,
    H in kJ/mol).
"""
function section_x_ranges(  diagType        :: String,
                            fixv            :: Float64,
                            bnd,
                            bulk_L          :: Vector{Float64},
                            bulk_R          :: Vector{Float64},
                            bufferN1        :: Float64,
                            bufferN2        :: Float64,
                            oxi             :: Vector{String},
                            dtb             :: String,
                            bufferType      :: String,
                            solver          :: String,
                            phase_selection,
                            cpx,            limOpx,     limOpxVal;
                            optimizer       = "nlopt",
                            dataset         = nothing  )

    mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb, solver, cpx, limOpx, limOpxVal )
    gv, z_b, DB, splx_data = init_MAGEMin(  dtb;
                                            verbose     = -1,
                                            dataset     = dataset,
                                            mbCpx       = mbCpx,
                                            limitCaOpx  = limitCaOpx,
                                            CaOpxLim    = CaOpxLim,
                                            buffer      = bufferType,
                                            solver      = sol,
                                            optimizer   = get_optimizer(dtb, optimizer, sol)    );
    prop    = section_x_prop(diagType)
    lo, hi  = extrema(Float64.(bnd))
    vals    = Dict{Tuple{Float64,Float64},Float64}()
    ok      = true
    try
        for X in (0.0, 1.0), f in (lo, hi)
            gv      = define_bulk_rock(gv, bulk_L .* (1.0 - X) .+ bulk_R .* X, oxi, "mol", dtb)
            P, T    = section_x_fixed_P(diagType) ? (fixv, f) : (f, fixv)
            o       = deepcopy(point_wise_minimization(P, T, gv, z_b, DB, splx_data;
                                                       buffer_n = bufferN1*(1.0 - X) + bufferN2*X, rm_list = phase_selection, name_solvus = true))
            ok     &= o.status < 3
            vals[(X, f)] = section_to_display(prop, MAGEMin_C.section_value(o, prop))
        end
    finally
        LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))
    end
    yr  = extrema(collect(values(vals)))
    return yr, ok && yr[2] > yr[1]
end

function section_x_column_seeds(grid, gX, X::Float64, target::Float64, prop::Symbol)
    isempty(grid) && return MAGEMin_C.gmin_struct{Float64,Int64}[]
    dx      = minimum(abs.(gX .- X))
    col     = [k for k in eachindex(grid) if abs(gX[k] - X) <= dx + 1e-12 && grid[k].status < 3]
    isempty(col) && return MAGEMin_C.gmin_struct{Float64,Int64}[]
    v       = [MAGEMin_C.section_value(grid[k], prop) for k in col]
    below   = [col[k] for k in eachindex(col) if v[k] <= target]
    above   = [col[k] for k in eachindex(col) if v[k] >  target]
    sd      = Int[]
    isempty(below) || push!(sd, below[argmax([MAGEMin_C.section_value(grid[k], prop) for k in below])])
    isempty(above) || push!(sd, above[argmin([MAGEMin_C.section_value(grid[k], prop) for k in above])])
    isempty(sd) && (sd = col[partialsortperm(abs.(v .- target), 1:min(2, length(col)))])
    return [grid[k] for k in sd]
end

"""
    get_wat_sat_function(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                dtb,        bufferType, solver,
                                verbose,    bufferN,
                                cpx,        limOpx,     limOpxVal)

    Computes water-saturation at sub-solidus

"""
function get_wat_sat_function(     Yrange,     bulk_ini,   oxi,    phase_selection,
                                    dtb,        bufferType, solver,
                                    verbose,    bufferN,
                                    cpx,        limOpx,     limOpxVal, watsat_val;
                                    optimizer   = "nlopt")
   
    id_h2o      = findfirst(oxi .== "H2O")
    hydrated    = 1;
    watsat_val  = watsat_val/100.0

    if isnothing(id_h2o) || bulk_ini[id_h2o] == 0.0
        hydrated = 0;
    end

    liq = 1;
    if ~isnothing(phase_selection) && "liq" in phase_selection
        liq = 0;
    end

    if liq == 1 && hydrated == 1                                
        println("Computing water-saturation at sub-solidus. Make sure you provided enough water to oversaturate below solidus.")
        stp     = (Yrange[2] - Yrange[1])/31.0                        
        Prange  = Vector(Yrange[1]:stp:Yrange[2])

        # prepare flags
        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 

        # initialize single thread MAGEMin 

        gv, z_b, DB, splx_data = init_MAGEMin(  dtb;
                                                verbose     = verbose,
                                                mbCpx       = mbCpx,
                                                limitCaOpx  = limitCaOpx,
                                                CaOpxLim    = CaOpxLim,
                                                buffer      = bufferType,
                                                solver      = sol,
                                                optimizer   = get_optimizer(dtb, optimizer, sol)    );

        sys_in      = "mol"
        gv          =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);

        Tmin        = 500.0;
        Tliq        = 2200.0;
        tolerance   = 1e-4;      

        Tsol        = zeros(Float64,length(Prange))
        SatSol      = zeros(Float64,length(Prange))

        @showprogress 1 "Computing sub-solidus water-saturating curve..." for i = 1:length(Prange)

            pressure    = Prange[i]
            out         = deepcopy( point_wise_minimization(pressure, Tliq, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
            n_max       = 64
            a           = Tmin
            b           = Tliq
            n           = 1
            conv        = 0
            n           = 0
            sign_a      = -1

            while n < n_max && conv == 0
                c       = (a+b)/2.0
                out     = deepcopy( point_wise_minimization(pressure, c, gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

                if "liq" in out.ph
                    result = 1;
                else
                    result = -1;
                end

                sign_c  = sign(result)

                if abs(b-a) < tolerance
                    conv = 1
                else
                    if  sign_c == sign_a
                        a = c
                        sign_a = sign_c
                    else
                        b = c
                    end
                    
                end
                n += 1
            end

            Tsol[i]     = (a+b)/2.0
            out         = deepcopy( point_wise_minimization(pressure, (a+b)/2.0 + 0.01 , gv, z_b, DB, splx_data, sys_in;buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

            id_dry      = findall(out.oxides .!= "H2O")
            id_h2o      = findall(out.oxides .== "H2O")[1]

            tmp_bulk    = deepcopy(out.bulk)

            # extracting excess water
            if "H2O" in out.ph
                id = findfirst(out.ph .== "H2O")
                tmp_bulk .-= out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
            elseif "fl" in out.ph
                id = findfirst(out.ph .== "fl")
                tmp_bulk .-= out.SS_vec[id].Comp .* out.ph_frac[id]
            end            
            tmp_bulk ./= sum(tmp_bulk)              # normalize to 100%

            if watsat_val > 0.0
                tmp_bulk[id_h2o] += watsat_val/(1.0 - watsat_val)
                tmp_bulk ./= sum(tmp_bulk) 
            end

            tmp_bulk ./= sum(tmp_bulk[id_dry])      # normalize on anhydrous basis, to get water content
            SatSol[i]  = tmp_bulk[id_h2o]
            
        end

        # println("SatSol $SatSol")
        pChip_wat   = Interpolator(Prange, SatSol)
        pChip_T     = Interpolator(Prange, Tsol)
        LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))
    else
        println("To compute water-saturation at sub-solidus liq must be part of the solution phase model and the bulk composition must contain water")
        println("Phase diagram will be computed without water-saturation at sub-solidus...")
        pChip_wat, pChip_T = nothing, nothing
    end

    return pChip_wat, pChip_T
end


"""
    MAGEMin_data2table( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}})

    Transform MAGEMin output into a table

"""
function MAGEMin_data2table( out:: Union{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}, MAGEMin_C.gmin_struct{Float64, Int64}},dtb)

    db_in     = retrieve_solution_phase_information(dtb)
    datetoday = string(Dates.today())
    rightnow  = string(Dates.Time(Dates.now()))

    if typeof(out) == MAGEMin_C.gmin_struct{Float64, Int64}
        out = [out]
    end
    np      = length(out)

    table   = "# MAGEMin " * " $(out[1].MAGEMin_ver);" * datetoday * ", " * rightnow * "; using database " * AppData.db_inf.db_info * "\n"
    table   *=   "point[#] X[0.0-1.0] P[kbar] T[°C]" *" phase" * " mode[mol%]" * " mode[wt%]" * " log10(fO2)" * " log10(dQFM)" * " aH2O" * " aSiO2" * " aTiO2" *  " aAl2O3" *  " aMgO" *  " aFeO" * 
                " density[kg/m3]" * " volume[cm3/mol]" * " heatCapacity[kJ/K]" * " alpha[1/K]" * " Entropy[kJ/K]" * " Enthalpy[kJ/mol]" *
                " Vp[km/s]" * " Vs[km/s]" * " Vp_S[km/s]" * " Vs_S[km/s]" *" BulkMod[GPa]" * " ShearMod[GPa]" *
                " " *join(out[1].oxides.*"[mol%]", " ") * " " *join(out[1].oxides.*"[wt%]", " ") *"\n"
    for k=1:np
        np  = length(out[k].ph)
        nss = out[k].n_SS
        npp = out[k].n_PP
        table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " system" * " 100.0" * " 100.0" * prt(out[k].fO2[1]) * prt(out[k].dQFM[1]) *prt(out[k].aH2O) *prt(out[k].aSiO2) *prt(out[k].aTiO2) *prt(out[k].aAl2O3) *prt(out[k].aMgO) *prt(out[k].aFeO) *
        prt(out[k].rho) * prt(out[k].V) * prt(out[k].s_cp[1]) * prt(out[k].alpha) * prt(out[k].entropy) * prt(out[k].enthalpy) *
        prt(out[k].Vp) * prt(out[k].Vs) *prt(out[k].Vp_S) * prt(out[k].Vs_S) *prt(out[k].bulkMod) * prt(out[k].shearMod) *
        prt(out[k].bulk.*100.0) * prt(out[k].bulk_wt.*100.0) * "\n"
        for i=1:nss
            table *= "$k" * prt(out[k].X[1])* prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[i] * prt(out[k].ph_frac[i].*100.0) * prt(out[k].ph_frac_wt[i].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
            prt(out[k].SS_vec[i].rho) * prt(out[k].SS_vec[i].V) * prt(out[k].SS_vec[i].cp) * prt(out[k].SS_vec[i].alpha) * prt(out[k].SS_vec[i].entropy) * prt(out[k].SS_vec[i].enthalpy) *
            prt(out[k].SS_vec[i].Vp) * prt(out[k].SS_vec[i].Vs) * " -" * " -" *prt(out[k].SS_vec[i].bulkMod) * prt(out[k].SS_vec[i].shearMod) *
            prt(out[k].SS_vec[i].Comp.*100.0) * prt(out[k].SS_vec[i].Comp_wt.*100.0) * "\n"
        end

        if npp > 0
            for i=1:npp
                pos = i + nss
                table *= "$k" * prt(out[k].X[1]) * prt(out[k].P_kbar) * prt(out[k].T_C) * " "*out[k].ph[pos] * prt(out[k].ph_frac[pos].*100.0) * prt(out[k].ph_frac_wt[pos].*100.0) * " -" *" -" * " -" *" -" * " -" *" -" * " -" *" -" *
                prt(out[k].PP_vec[i].rho) * prt(out[k].PP_vec[i].V) * prt(out[k].PP_vec[i].cp) * prt(out[k].PP_vec[i].alpha) * prt(out[k].PP_vec[i].entropy) * prt(out[k].PP_vec[i].enthalpy) *
                prt(out[k].PP_vec[i].Vp) * prt(out[k].PP_vec[i].Vs) * " -" * " -" * prt(out[k].PP_vec[i].bulkMod) * prt(out[k].PP_vec[i].shearMod) *
                prt(out[k].PP_vec[i].Comp.*100.0) * prt(out[k].PP_vec[i].Comp_wt.*100.0) * "\n"
            end
        end

    end


    return table
end


# find_dominant_em_ids
function find_dominant_em_ids(  SS_vec )
    n_ph    = length(SS_vec)
    ids     = ()
    for i=1:n_ph
        f    = SS_vec[i].emFrac
        ids  = (ids..., findfirst(f .== maximum(f)))
    end
    
    return ids
end

function get_dominant_em(   ph,
                            n_SS,
                            SS_vec)
    n_ph  = length(ph)
    ph_em = Vector{String}(undef,n_ph)
    for i=1:n_SS
        f = SS_vec[i].emFrac
        id = findall(f .== maximum(f))[1]
        em = SS_vec[i].emNames[id]
        ph_em[i] = ph[i]*":"*em
    end
    for i=n_SS+1:n_ph
        ph_em[i] = ph[i]
    end

    return ph_em
end

function get_data_thread( MAGEMin_db :: MAGEMin_Data )

    id          = Threads.threadid()
    gv          = MAGEMin_db.gv[id]
    z_b         = MAGEMin_db.z_b[id]
    DB          = MAGEMin_db.DB[id]
    splx_data   = MAGEMin_db.splx_data[id]

   return (gv, z_b, DB, splx_data)
end

"""
    multi_point_mumu(     target_mu1,     target_mu2,
                        oxide1_idx,     oxide2_idx,
                        bulk_ref,       oxi,
                        fixP,           fixT,       dtb,
                        MAGEMin_data;
                        bufferN, phase_selection, tol )

    For a mu-mu (chemical potential) diagram: given `n = length(target_mu1)`
    target (μ1,μ2) grid points, compute — independently per point, in
    parallel — the equilibrium at each target via MAGEMin_C's native
    chemical-potential-fixing mechanism (`mu_fix_idx`/`mu_fix_val`): one
    `point_wise_minimization` call per point with
    `mu_fix_val=[target_mu1[i], target_mu2[i]]`, no search loop. Requires
    `MAGEMin_data` to have been built with
    `mu_fix_idx=[oxi[oxide1_idx],oxi[oxide2_idx]]` at `Initialize_MAGEMin`
    time (see `refine_MAGEMin`'s "mumu" branch and
    `compute_new_phaseDiagram`/`refine_phaseDiagram`, which build it this
    way whenever `diagType=="mumu"`).

    The trial bulk composition is `bulk_ref` with both mu-mu oxides
    unconditionally overridden to `100.0` (mol%, pre-normalization) — the
    bulk-rock table's own entries for those two oxides are irrelevant here
    (locked/greyed in the UI) and never read. MAGEMin_C's docs for
    `mu_fix_val` require each fixed oxide's bulk content to be set
    "generously in excess" of what its target implies, or the underlying
    fictive-phase mechanism may not reliably activate; `100.0` is used
    unconditionally for both oxides so this always holds regardless of P,T
    or the rest of the bulk composition, without needing user input.
    MAGEMin_C explicitly does not itself verify the target was hit, so this
    still checks `out.Gamma` against `(target_mu1[i],target_mu2[i])` before
    reporting a point converged.

    Mirrors `multi_point_minimization`'s own `@threads :static` outer loop
    over grid points and per-thread buffer pattern (`get_data_thread`) —
    NOT a modification of `multi_point_minimization` itself.

    Returns `(results, status)`: `results` is a `Vector{gmin_struct}` (for
    direct storage into `Out_XY`/`Hash_XY`/`n_phase_XY` like any other
    diagram type), `status` is `0` (both targets hit within `tol`) or `5`
    (not hit — e.g. a target outside what any real phase in the database
    can support at this P,T) per point, same convention as
    `gmin_struct.status`.
"""
function multi_point_mumu(     target_mu1      :: Vector{Float64},
                                target_mu2      :: Vector{Float64},
                                oxide1_idx      :: Int64,
                                oxide2_idx      :: Int64,
                                bulk_ref        :: Vector{Float64},
                                oxi             :: Vector{String},
                                fixP            :: Float64,
                                fixT            :: Float64,
                                dtb             :: String,
                                MAGEMin_data    :: MAGEMin_Data;
                                bufferN         :: Float64 = 0.0,
                                phase_selection = nothing,
                                tol             :: Float64 = 1e-3    )

    n           = length(target_mu1)
    results     = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, n)
    status      = Vector{Int64}(undef, n)
    sys_in      = "mol"

    trial_seed              = deepcopy(bulk_ref)
    trial_seed[oxide1_idx]  = 100.0
    trial_seed[oxide2_idx]  = 100.0

    count = Threads.Atomic{Int}(0)

    @showprogress desc="Computing $n points..." @threads :static for i in eachindex(target_mu1)

        gv, z_b, DB, splx_data = get_data_thread(MAGEMin_data)

        gv2 = define_bulk_rock(gv, trial_seed, oxi, sys_in, dtb)
        out = deepcopy( point_wise_minimization(fixP, fixT, gv2, z_b, DB, splx_data, sys_in;
                                                    buffer_n=bufferN, rm_list=phase_selection, name_solvus=true,
                                                    mu_fix_val=[target_mu1[i], target_mu2[i]]    ) )

        conv        = abs(out.Gamma[oxide1_idx] - target_mu1[i]) < tol &&
                      abs(out.Gamma[oxide2_idx] - target_mu2[i]) < tol

        results[i]  = out
        status[i]   = conv ? 0 : 5

        update_progress(Threads.atomic_add!(count, 1) + 1, n, time())
    end

    return results, status
end

function get_custom_Ws(custW::Bool)
    if custW == true && !isempty(AppData.customWs)
        df     = AppData.customWs
        new_Ws = Vector{MAGEMin_C.W_data{Float64,Int64}}(undef, size(df,1))
        for i=1:size(df,1)
            n_Ws      = df[i, :n_Ws]
            Ws        = reshape(parse.(Float64, split(df[i, :Ws], ";")), n_Ws, 3)
            new_Ws[i] = MAGEMin_C.W_data(df[i, :dtb], df[i, :id], n_Ws, Ws)
        end
        return new_Ws
    end
    return nothing
end

function set_magemin_buffer!(MAGEMin_data::MAGEMin_Data, bufferType::String)
    for i in 1:Threads.maxthreadid()
        # copy bufferType's bytes into gv.buffer's existing (C-malloc'd, 10-byte)
        # buffer in place, rather than repointing gv.buffer at bufferType's own
        # memory - the latter left gv.buffer aliasing Julia-GC-owned memory
        # (a Julia String is not something C should ever free()), which caused
        # a SIGABRT when MAGEMin's FreeDatabases tried to free(gv.buffer)
        n = min(ncodeunits(bufferType), 9)
        unsafe_copyto!(MAGEMin_data.gv[i].buffer, Ptr{Cchar}(pointer(bufferType)), n)
        unsafe_store!(MAGEMin_data.gv[i].buffer, Cchar(0), n+1)
    end
    return nothing
end

function refine_MAGEMin(dtb,data,
                        MAGEMin_data    :: MAGEMin_Data, 
                        custW           :: Bool,
                        diagType        :: String,
                        PTpath,
                        phase_selection :: Union{Nothing,Vector{Int64}},
                        fixT            :: Float64,
                        fixP            :: Float64,
                        e1_liq          :: Float64,
                        e2_liq          :: Float64,
                        e1_remain_wat       :: Float64,
                        e2_remain_wat       :: Float64,
                        e1_remain       :: Float64,
                        e2_remain       :: Float64,
                        oxi             :: Vector{String},
                        bulk_L          :: Vector{Float64},
                        bulk_R          :: Vector{Float64},
                        bufferType      :: String,
                        bufferN1        :: Float64,
                        bufferN2        :: Float64,
                        scp             :: Int64,
                        boost           :: Bool,
                        refType         :: String,
                        pChip_wat       ,
                        pChip_T         ,
                        seismic_cor     :: Bool,
                        aspect_ratio    :: Float64,
                        seismic_water   :: Int64,
                        shallow_cor     :: Bool,
                        fluid_as_melt   :: Bool,
                        anelastic_correction :: Bool;
                        mumu_oxide1_idx     :: Int64                   = 0,
                        mumu_oxide2_idx     :: Int64                   = 0,
                        sec_Pbox            = nothing,
                        sec_Tbox            = nothing,
                        sec_limits          = nothing    )
    global Out_XY, addedRefinementLvl, Sec_status_XY, Sec_seed_grid, Sec_seed_X, Sec_fill_tried;

    if isempty(Out_XY) || !@isdefined(Sec_status_XY)
        Sec_status_XY = Int64[]
    end
    if isempty(Out_XY) || !@isdefined(Sec_fill_tried)
        Sec_fill_tried = Dict{NTuple{2, Float64}, Vector{NTuple{2, Float64}}}()
    end
    if isempty(Out_XY) && diagType in SECTION_X_TYPES
        Sec_seed_grid = MAGEMin_C.gmin_struct{Float64,Int64}[]
        Sec_seed_X    = Float64[]
    end

    new_Ws = get_custom_Ws(custW)

    if isempty(data.split_cell_list) && isempty(Out_XY)
        Out_XY_new      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.points))
        n_new_points    = length(data.points)
        npoints         = data.points
    else
        Out_XY_new      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,length(data.npoints))
        n_new_points    = length(data.npoints)
        npoints         = data.npoints
    end

    set_magemin_buffer!(MAGEMin_data, bufferType)

    if n_new_points > 0
        Tvec = zeros(Float64,n_new_points);
        Pvec = zeros(Float64,n_new_points);
        Xvec = Vector{Vector{Float64}}(undef,n_new_points);
        Bvec = zeros(Float64,n_new_points);

        if !isempty(data.split_cell_list) && boost == true
            Gvec = Vector{Vector{LibMAGEMin.mSS_data}}(undef,n_new_points);
            Ivec = Vector{Bool}(undef,n_new_points) .= true;
        else
            Ivec = false
            Gvec = nothing;
        end

        if diagType in SECTION_TYPES

            sec     = Symbol(diagType)
            ax      = MAGEMin_C.SECTION_XY[sec]
            xs      = [section_from_display(ax[1], npoints[i][1]) for i = 1:n_new_points]
            ys      = [section_from_display(ax[2], npoints[i][2]) for i = 1:n_new_points]
            xr      = section_from_display.(ax[1], data.Xrange)
            yr      = section_from_display.(ax[2], data.Yrange)
            seeds   = nothing
            if !isempty(data.split_cell_list)
                seeds = [ [Out_XY[j] for j in data.npoints_ig[i] if j <= length(Sec_status_XY) && Sec_status_XY[j] == 0] for i = 1:n_new_points ]
            end

            search_P, search_T = section_search_box(sec_Pbox, sec_Tbox; limits = sec_limits)
            Out_XY_new, sec_info = MAGEMin_C.multi_point_section(  sec, xs, ys, MAGEMin_data;
                                                        Pbox        = search_P,
                                                        Tbox        = search_T,
                                                        seed_Pbox   = extrema(Float64.(sec_Pbox)),
                                                        seed_Tbox   = extrema(Float64.(sec_Tbox)),
                                                        seeds       = seeds,
                                                        xrange      = xr,
                                                        yrange      = yr,
                                                        X           = bulk_L,
                                                        B           = bufferN1,
                                                        Xoxides     = oxi,
                                                        sys_in      = "mol",
                                                        rm_list     = phase_selection,
                                                        W           = new_Ws,
                                                        scp         = scp,
                                                        name_solvus = true,
                                                        progressbar = true,
                                                        callback_fn = update_progress,
                                                        seismic_cor = seismic_cor, aspect_ratio = aspect_ratio, seismic_water = seismic_water,
                                                        shallow_correction = shallow_cor, fluid_as_melt = fluid_as_melt, anelastic_cor = anelastic_correction )
            n_fill = section_fill_holes!(   sec, npoints, Out_XY_new, sec_info, MAGEMin_data, data;
                                            Pbox = search_P, Tbox = search_T, xrange = xr, yrange = yr, tried = Sec_fill_tried,
                                            X = bulk_L, B = bufferN1, Xoxides = oxi, rm_list = phase_selection, W = new_Ws, scp = scp,
                                            seismic_cor = seismic_cor, aspect_ratio = aspect_ratio, seismic_water = seismic_water,
                                            shallow_correction = shallow_cor, fluid_as_melt = fluid_as_melt, anelastic_cor = anelastic_correction )
            n_fill > 0 && println("Section diagram: $n_fill isolated point(s) recovered from their converged neighbours.")
            append!(Sec_status_XY, [x.status for x in sec_info])

            n_void = count(x -> x.status != 0, sec_info)
            if n_void > 0
                println("Section diagram: $n_void / $n_new_points point(s) not reached within P $(round.(search_P, sigdigits = 4)) kbar, T $(round.(search_T, sigdigits = 4)) °C or not resolved (left blank).")
            end

        elseif diagType in SECTION_X_TYPES

            mode    = section_x_mode(diagType)
            prop    = section_x_prop(diagType)
            fixv    = section_x_fixed_P(diagType) ? fixP : fixT
            bnd     = section_x_fixed_P(diagType) ? extrema(Float64.(sec_Tbox)) : extrema(Float64.(sec_Pbox))
            search_P, search_T = section_search_box(sec_Pbox, sec_Tbox; limits = sec_limits)
            Xmix    = [Float64(npoints[i][1]) for i = 1:n_new_points]
            yv      = [section_from_display(prop, npoints[i][2]) for i = 1:n_new_points]
            Xvec_s  = [bulk_L .* (1.0 - X) .+ bulk_R .* X for X in Xmix]
            Bvec_s  = [bufferN1*(1.0 - X) + bufferN2*X for X in Xmix]

            if isempty(data.split_cell_list) || !@isdefined(Sec_seed_grid) || isempty(Sec_seed_grid)
                Xn      = sort(unique(Float64.(first.(data.points))))
                length(Xn) > 65 && (Xn = collect(range(Xn[1], Xn[end], length = 65)))
                fn      = collect(range(bnd[1], bnd[2], length = length(Xn)))
                gX      = vec([x for x in Xn, f in fn])
                gF      = vec([f for x in Xn, f in fn])
                gP      = section_x_fixed_P(diagType) ? fill(fixv, length(gF)) : gF
                gT      = section_x_fixed_P(diagType) ? gF : fill(fixv, length(gF))
                println("Section diagram: seed grid of $(length(gX)) points (X x $(section_x_fixed_P(diagType) ? "T" : "P") between the bounds)")
                Sec_seed_grid = multi_point_minimization(   gP, gT, MAGEMin_data;
                                                            X = [bulk_L .* (1.0 - x) .+ bulk_R .* x for x in gX], B = [bufferN1*(1.0 - x) + bufferN2*x for x in gX],
                                                            Xoxides = oxi, sys_in = "mol", rm_list = phase_selection, name_solvus = true, W = new_Ws, scp = scp,
                                                            seismic_cor = seismic_cor, aspect_ratio = aspect_ratio, seismic_water = seismic_water,
                                                            shallow_correction = shallow_cor, fluid_as_melt = fluid_as_melt, anelastic_cor = anelastic_correction)
                Sec_seed_X    = gX
            end

            seeds = Vector{Vector{MAGEMin_C.gmin_struct{Float64,Int64}}}(undef, n_new_points)
            for i = 1:n_new_points
                sd = MAGEMin_C.gmin_struct{Float64,Int64}[]
                if !isempty(data.split_cell_list)
                    sd = [Out_XY[j] for j in data.npoints_ig[i] if j <= length(Sec_status_XY) && Sec_status_XY[j] == 0]
                end
                isempty(sd) && (sd = section_x_column_seeds(Sec_seed_grid, Sec_seed_X, Xmix[i], yv[i], prop))
                seeds[i] = sd
            end

            xs, ys  = section_x_fixed_P(diagType) ? (yv, fill(fixv, n_new_points)) : (fill(fixv, n_new_points), yv)
            yr      = section_from_display.(prop, data.Yrange)
            Out_XY_new, sec_info = MAGEMin_C.multi_point_section(  mode, xs, ys, MAGEMin_data;
                                                        Pbox        = search_P,
                                                        Tbox        = search_T,
                                                        seeds       = seeds,
                                                        xrange      = section_x_fixed_P(diagType) ? yr : (fixv - 1.0, fixv + 1.0),
                                                        yrange      = section_x_fixed_P(diagType) ? (fixv - 1.0, fixv + 1.0) : yr,
                                                        retry_xy    = (Xmix, yv),
                                                        X           = Xvec_s,
                                                        B           = Bvec_s,
                                                        Xoxides     = oxi,
                                                        sys_in      = "mol",
                                                        rm_list     = phase_selection,
                                                        W           = new_Ws,
                                                        scp         = scp,
                                                        name_solvus = true,
                                                        progressbar = true,
                                                        callback_fn = update_progress,
                                                        seismic_cor = seismic_cor, aspect_ratio = aspect_ratio, seismic_water = seismic_water,
                                                        shallow_correction = shallow_cor, fluid_as_melt = fluid_as_melt, anelastic_cor = anelastic_correction )
            for i = 1:n_new_points
                Out_XY_new[i].X .= Xmix[i]
            end
            append!(Sec_status_XY, [x.status for x in sec_info])

            n_void = count(x -> x.status != 0, sec_info)
            if n_void > 0
                println("Section diagram: $n_void / $n_new_points point(s) not reached within $(section_x_fixed_P(diagType) ? "T $(round.(search_T, sigdigits = 4)) °C" : "P $(round.(search_P, sigdigits = 4)) kbar") or not resolved (left blank).")
            end

        elseif diagType == "mumu"

            target_mu1 = zeros(Float64,n_new_points)
            target_mu2 = zeros(Float64,n_new_points)
            for i = 1:n_new_points
                target_mu1[i] = npoints[i][1]
                target_mu2[i] = npoints[i][2]
            end

            Out_XY_new, mumu_status = multi_point_mumu(
                                            target_mu1,     target_mu2,
                                            mumu_oxide1_idx, mumu_oxide2_idx,
                                            bulk_L,         oxi,
                                            fixP,           fixT,           dtb,
                                            MAGEMin_data;
                                            bufferN         = bufferN1,
                                            phase_selection = phase_selection    )

            n_failed = count(==(5), mumu_status)
            if n_failed > 0
                println("Warning: $n_failed / $n_new_points mu-mu grid point(s) did not converge (status=5) — check your oxide content bounds.")
            end

        elseif diagType != "tt"
            if diagType == "tx"

                for i = 1:n_new_points
                    Pvec[i] = fixP;
                    Tvec[i] = npoints[i][2];
                    Xvec[i] = bulk_L*(1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            elseif diagType == "px"

                for i = 1:n_new_points
                    Tvec[i] = fixT;
                    Pvec[i] = npoints[i][2];
                    Xvec[i] = bulk_L*(1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            elseif diagType == "pt"

                if "H2O" in oxi
                    id_h2o      = findfirst(oxi .== "H2O")
                    id_dry      = findall(oxi .!= "H2O")
                end

                for i = 1:n_new_points
                    Tvec[i] = npoints[i][1];
                    Pvec[i] = npoints[i][2];
                    Bvec[i] = bufferN1;
                    
                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end

                    # here we check if the water need to be saturated at sub-solidus
                    if ~isnothing(pChip_wat)
                        TsatSol     = pChip_T(Pvec[i])
                        waterSat    = pChip_wat(Pvec[i])

                        if Tvec[i] > TsatSol        # if we are above the solidus then we use the water content from the sub-solidus curve
                            tmp_bulk              = deepcopy(bulk_L)
                            tmp_bulk            ./= sum(tmp_bulk[id_dry])
                            tmp_bulk[id_h2o]      = waterSat
                            tmp_bulk            ./= sum(tmp_bulk)

                            if !isempty(data.ncorners) && boost == true # Here we roughly check if the bulk composition is feasible with respect to initial guess
                                check_bulk = vcat([Out_XY[data.npoints_ig[i][j]].bulk[id_h2o] for j=1:length(data.npoints_ig[i])]...)
                                if tmp_bulk[id_h2o] > maximum(check_bulk) || tmp_bulk[id_h2o] < minimum(check_bulk)
                                    Ivec[i] = false
                                end
                            end   

                            Xvec[i]               = tmp_bulk
                        else
                            Xvec[i] = bulk_L;
                        end
                    else
                        Xvec[i] = bulk_L;
                    end
                end
            elseif diagType == "ptx"

                ptx_data    = copy(PTpath)
                np          = length(ptx_data)
                Pres        = zeros(Float64,np)
                Temp        = zeros(Float64,np)
                x           = zeros(Float64,np)
                for i=1:np
                    Pres[i] = to_kbar_pressure(ptx_data[i][Symbol("col-1")])
                    Temp[i] = ptx_data[i][Symbol("col-2")]
                    x[i]    = (i-1)*(1.0/(np-1))
                end
                pChipInterp_P = Interpolator(x, Pres)
                pChipInterp_T = Interpolator(x, Temp)

                for i = 1:n_new_points
                    Tvec[i] = pChipInterp_T(npoints[i][2]); 
                    Pvec[i] = pChipInterp_P(npoints[i][2]);
                    Xvec[i] = bulk_L*(  1.0 - npoints[i][1]) + bulk_R*npoints[i][1];
                    Bvec[i] = bufferN1*(1.0 - npoints[i][1]) + bufferN2*npoints[i][1];
                    if !isempty(data.split_cell_list) && boost == true

                        n_ph = [ length(Out_XY[data.npoints_ig[i][j]].ph) for j=1:length(data.npoints_ig[i])]
                        ids  = sortperm(n_ph, rev=true)

                        tmp = [Out_XY[data.npoints_ig[i][ids[j]]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end
            end
            if diagType == "pt" && dtb != "sb11" && dtb != "sb21"  && dtb != "sb24" && dtb != "rMELTS" && dtb != "pMELTS" && isnothing(pChip_wat) == true
                fixed_bulk = true
            else
                fixed_bulk = false
            end
            Out_XY_new  =   multi_point_minimization(   Pvec, Tvec, MAGEMin_data;
                                                        X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol", G=Gvec, scp=scp,
                                                        rm_list=phase_selection, name_solvus=true, fixed_bulk=fixed_bulk, iguess=Ivec, callback_fn = update_progress, W=new_Ws,
                                                        seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction);
        else
            # if TT diagram does not exist, compute it
            id_h2o = findfirst(oxi .== "H2O") # check if H2O is in the oxides
            if isempty(data.split_cell_list)    
                n           = Int64(sqrt(n_new_points))
                Out_col_1   = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n)
                start_bulk  = deepcopy(bulk_L)
                for i=1:n
                    out     = single_point_minimization(    fixP, npoints[i][2], MAGEMin_data;
                                                            X=start_bulk, B=bufferN1, Xoxides=oxi, sys_in="mol",  scp=scp,
                                                            rm_list=phase_selection, name_solvus=true,
                                                            seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)
                    
                    if "fl" in out.ph || "H2O" in out.ph || "liq" in out.ph
                        if "fl" in out.ph
                            id               = findfirst(out.ph .== "fl")
                            start_bulk      .= out.bulk .- out.SS_vec[id].Comp .* out.ph_frac[id]
                            start_bulk     .+= e1_remain_wat .* out.SS_vec[id].Comp;
                        end
                        if "H2O" in out.ph
                            id               = findfirst(out.ph .== "H2O")
                            start_bulk      .= out.bulk .- out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
                            start_bulk[id_h2o]  += e1_remain_wat;
                        end
                        if "liq" in out.ph
                            id = findfirst(out.ph .== "liq")

                            if  out.ph_frac_vol[id] > e1_liq/100.0
                                ratio        = (out.ph_frac_vol[id] - e1_remain/100.0)/out.ph_frac_vol[id]
                                start_bulk  .= out.bulk .- out.SS_vec[id].Comp .* (out.ph_frac[id]*ratio)
                            end
                        end
                        start_bulk ./= sum(start_bulk)
        
                        out         = single_point_minimization(    fixP, npoints[i][2], MAGEMin_data;
                                                                    X=start_bulk, B=bufferN1, Xoxides=oxi, sys_in="mol",  scp=scp,
                                                                    rm_list=phase_selection, name_solvus=true, W=new_Ws,
                                                                    seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)
            
                        Out_col_1[i] = deepcopy(out)
                        Out_col_1[i].X .= npoints[i][2]
                    else
                        Out_col_1[i] = deepcopy(out)
                        Out_col_1[i].X .= npoints[i][2]
                    end
                    
                end

                Out_rows    = Vector{Vector{MAGEMin_C.gmin_struct{Float64, Int64}}}(undef, n);
                progr       = Progress(n, desc="Computing $n Polymetamorphic paths...") # progress meter
                @threads :static for i=1:n

                    Out_PT      = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, n)
                    P_          = fixP
                    T_          = collect(range(data.Xrange[1], stop=data.Xrange[2], length=n))
                    bulk_       = deepcopy(Out_col_1[i].bulk)
                    X           = Out_col_1[i].X[1]

                    gv, z_b, DB, splx_data = get_data_thread(MAGEMin_data)
                    gv          = define_bulk_rock(gv, bulk_, oxi, "mol",unsafe_string(gv.db))
                    for j=1:n 

                        out     = point_wise_minimization(  P_, T_[j], gv, z_b, DB, splx_data;
                                                            buffer_n=bufferN1, name_solvus=true, scp=scp, rm_list=phase_selection, W=new_Ws,
                                                            seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)

                        if "fl" in out.ph || "H2O" in out.ph || "liq" in out.ph
                            if "fl" in out.ph
                                id              = findfirst(out.ph .== "fl")
                                bulk_          .= out.bulk .- out.SS_vec[id].Comp .* out.ph_frac[id]
                                bulk_           .+= e2_remain_wat .* out.SS_vec[id].Comp;
                            end
                            if "H2O" in out.ph
                                id              = findfirst(out.ph .== "H2O")
                                bulk_          .= out.bulk .- out.PP_vec[id - out.n_SS].Comp .* out.ph_frac[id]
                                bulk_[id_h2o]  += e2_remain_wat;
                            end
                            if "liq" in out.ph
                                id = findfirst(out.ph .== "liq")
                                if  out.ph_frac_vol[id] > e2_liq/100.0
                                    ratio        = (out.ph_frac_vol[id] - e2_remain/100.0)/out.ph_frac_vol[id]
                                    bulk_       .= out.bulk .- out.SS_vec[id].Comp .* (out.ph_frac[id]*ratio)
                                end
                            end
                            gv      = define_bulk_rock(gv, bulk_, oxi, "mol",unsafe_string(gv.db))
                            out     = point_wise_minimization(  P_, T_[j], gv, z_b, DB, splx_data;
                                                                buffer_n=bufferN1, name_solvus=true, scp=scp, rm_list=phase_selection, W=new_Ws,
                                                                seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction)

                            Out_PT[j] = deepcopy(out)
                            Out_PT[j].X .= X
                        else
                            Out_PT[j] = deepcopy(out)
                            Out_PT[j].X .= X
                        end
                    end
                    Out_rows[i] = Out_PT
                    next!(progr)
                end
                finish!(progr)

                for i=1:n
                    for j=1:n
                        Out_XY_new[(i-1)*n+j] = Out_rows[j][i]
                    end
                end

            else #refinement of the TT diagram
                for i = 1:n_new_points
                    tmp     = [Out_XY[data.npoints_ig[i][j]].X[1] for j=1:length(data.npoints_ig[i])]

                    Tvec[i] = npoints[i][1];
                    Pvec[i] = fixP;
                    Bvec[i] = bufferN1;

                    tmp_bulk = zeros(length(oxi))
                    for j=1:length(data.ncorners[i])
                        tmp_bulk .+= Out_XY[data.ncorners[i][j]].bulk
                    end
                    tmp_bulk  ./= Float64(length(data.ncorners[i]))
                    Xvec[i]     = tmp_bulk

                    if !isempty(data.split_cell_list) && boost == true
                        tmp = [Out_XY[data.npoints_ig[i][j]].mSS_vec for j=1:length(data.npoints_ig[i])]
                        Gvec[i] = vcat(tmp...)
                    end
                end

                Out_XY_new  =   multi_point_minimization(   Pvec, Tvec, MAGEMin_data;
                                                            X=Xvec, B=Bvec, Xoxides=oxi, sys_in="mol", G=Gvec, scp=scp,
                                                            rm_list=phase_selection, name_solvus=true, iguess=boost, callback_fn = update_progress, W=new_Ws,
                                                            seismic_cor=seismic_cor, aspect_ratio=aspect_ratio, seismic_water=seismic_water, shallow_correction=shallow_cor, fluid_as_melt=fluid_as_melt, anelastic_cor=anelastic_correction);

                for i=1:n_new_points
                    Out_XY_new[i].X .= data.npoints[i][2]  
                end
                
            end
        end
    else
        println("There is no new point to compute...")
    end
    Out_XY      = vcat(Out_XY, Out_XY_new)

    # Compute hash for all points
    n_points    = length(Out_XY)
    Hash_XY     = Vector{UInt64}(undef,n_points)
    n_phase_XY  = Vector{Int64}(undef,n_points)

    if refType == "ph"
        for i=1:n_points
            Hash_XY[i]      = hash(sort(Out_XY[i].ph))
            n_phase_XY[i]   = length(Out_XY[i].ph)
        end
    elseif refType == "em"
        for i=1:n_points
            ph_em = get_dominant_em(    Out_XY[i].ph,
                                        Out_XY[i].n_SS,
                                        Out_XY[i].SS_vec)

            Hash_XY[i]      = hash(sort(ph_em))
            n_phase_XY[i]   = length(ph_em)
        end
    end

    if (diagType in SECTION_TYPES || diagType in SECTION_X_TYPES) && length(Sec_status_XY) == n_points
        for i=1:n_points
            if Sec_status_XY[i] != 0
                Hash_XY[i] = SECTION_VOID_HASH
            end
        end
    end

    if diagType == "tx" || diagType == "px" || diagType == "ptx" || diagType in SECTION_X_TYPES
        for i=1:n_points
            Out_XY[i].X .= data.points[i][1]
        end
    end

    return Out_XY, Hash_XY, n_phase_XY  
end

