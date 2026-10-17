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

const pd_smooth_chaikin       = 2
const pd_smooth_sigma_default = 1.5
const pd_smooth_tube          = 0.5

pd_smooth_geom = nothing

function pd_domains(F::AbstractMatrix{<:Integer})
    nx, ny = size(F)
    D      = zeros(Int, nx, ny)
    nd     = 0
    stack  = Tuple{Int,Int}[]
    for j in 1:ny, i in 1:nx
        D[i, j] == 0 || continue
        nd += 1
        D[i, j] = nd
        push!(stack, (i, j))
        while !isempty(stack)
            a, b = pop!(stack)
            for (p, q) in ((a - 1, b), (a + 1, b), (a, b - 1), (a, b + 1))
                (1 <= p <= nx && 1 <= q <= ny && D[p, q] == 0 && F[p, q] == F[a, b]) || continue
                D[p, q] = nd
                push!(stack, (p, q))
            end
        end
    end
    return D, nd
end

function pd_relax_nodes(U0::Matrix{Float64}, nbr::Vector{Vector{Int}}, active::BitVector, slide::Vector{Int},
                        nx::Int, ny::Int, iters::Int, tube::Float64)
    U = copy(U0)
    V = similar(U)
    for _ in 1:iters
        for n in axes(U, 1)
            V[n, 1], V[n, 2] = U[n, 1], U[n, 2]
            (active[n] && slide[n] >= 0) || continue
            sx, sy = 0.0, 0.0
            for m in nbr[n]
                sx += U[m, 1]; sy += U[m, 2]
            end
            k  = length(nbr[n])
            vx = 0.5 * U[n, 1] + 0.5 * sx / k
            vy = 0.5 * U[n, 2] + 0.5 * sy / k
            slide[n] == 1 && (vx = U0[n, 1])
            slide[n] == 2 && (vy = U0[n, 2])
            ddx, ddy = vx - U0[n, 1], vy - U0[n, 2]
            d = hypot(ddx, ddy)
            if d > tube
                vx = U0[n, 1] + ddx * tube / d
                vy = U0[n, 2] + ddy * tube / d
            end
            V[n, 1] = clamp(vx, 0.0, nx - 1.0)
            V[n, 2] = clamp(vy, 0.0, ny - 1.0)
        end
        U, V = V, U
    end
    return U
end

function pd_chaikin(P::Matrix{Float64}, iters::Int, ring::Bool)
    for _ in 1:iters
        m = size(P, 1)
        m < 3 && break
        Q = Matrix{Float64}(undef, 2 * (m - 1) + (ring ? 1 : 2), 2)
        k = 0
        ring || (k += 1; Q[k, :] = P[1, :])
        for i in 1:m-1
            k += 1; Q[k, 1] = 0.75 * P[i, 1] + 0.25 * P[i+1, 1]; Q[k, 2] = 0.75 * P[i, 2] + 0.25 * P[i+1, 2]
            k += 1; Q[k, 1] = 0.25 * P[i, 1] + 0.75 * P[i+1, 1]; Q[k, 2] = 0.25 * P[i, 2] + 0.75 * P[i+1, 2]
        end
        k += 1
        Q[k, :] = ring ? Q[1, :] : P[m, :]
        P = Q
    end
    return P
end

function pd_smooth_geometry(F::AbstractMatrix{<:Integer}, Xrange, Yrange, id2phases::Dict{Int,Vector{String}};
                             sigma::Real = pd_smooth_sigma_default)
    nx, ny = size(F)
    D, nd  = pd_domains(F)
    idof   = zeros(Int, nd)
    for j in 1:ny, i in 1:nx
        idof[D[i, j]] = F[i, j]
    end

    x0, x1 = Float64(Xrange[1]), Float64(Xrange[2])
    y0, y1 = Float64(Yrange[1]), Float64(Yrange[2])
    dx, dy = (x1 - x0) / (nx - 1), (y1 - y0) / (ny - 1)
    nnx    = nx + 1
    node(a, b) = a + 1 + b * nnx
    nxy(n)     = ((n - 1) % nnx, (n - 1) ÷ nnx)

    eu, ev, eL, eR = Int[], Int[], Int[], Int[]
    for a in 0:nx, j in 1:ny
        L = a >= 1 ? D[a, j] : 0
        R = a < nx ? D[a + 1, j] : 0
        L == R && continue
        push!(eu, node(a, j - 1)); push!(ev, node(a, j)); push!(eL, L); push!(eR, R)
    end
    for b in 0:ny, i in 1:nx
        below = b >= 1 ? D[i, b] : 0
        above = b < ny ? D[i, b + 1] : 0
        below == above && continue
        push!(eu, node(i - 1, b)); push!(ev, node(i, b)); push!(eL, above); push!(eR, below)
    end
    ne = length(eu)

    nnode = (nx + 1) * (ny + 1)
    inc   = [Int[] for _ in 1:nnode]
    for e in 1:ne
        push!(inc[eu[e]], e)
        push!(inc[ev[e]], e)
    end
    corner(n) = (a = nxy(n); (a[1] == 0 || a[1] == nx) && (a[2] == 0 || a[2] == ny))
    fixed     = [length(inc[n]) != 2 || corner(n) for n in 1:nnode]

    arcs = NamedTuple{(:nodes, :L, :R, :closed),Tuple{Vector{Int},Int,Int,Bool}}[]
    used = falses(ne)
    function walk(n0, e0)
        L, R  = eu[e0] == n0 ? (eL[e0], eR[e0]) : (eR[e0], eL[e0])
        nodes = [n0]
        n, e  = n0, e0
        while true
            used[e] = true
            n = eu[e] == n ? ev[e] : eu[e]
            push!(nodes, n)
            (fixed[n] || n == n0) && break
            e = inc[n][1] == e ? inc[n][2] : inc[n][1]
            used[e] && break
        end
        push!(arcs, (nodes = nodes, L = L, R = R, closed = nodes[1] == nodes[end]))
    end
    for n in 1:nnode
        fixed[n] || continue
        for e in inc[n]
            used[e] || walk(n, e)
        end
    end
    for e in 1:ne
        used[e] || walk(eu[e], e)
    end

    U0     = Matrix{Float64}(undef, nnode, 2)
    active = falses(nnode)
    slide  = zeros(Int, nnode)
    nbr    = [Int[] for _ in 1:nnode]
    for n in 1:nnode
        a, b     = nxy(n)
        U0[n, 1] = clamp(a - 0.5, 0.0, nx - 1.0)
        U0[n, 2] = clamp(b - 0.5, 0.0, ny - 1.0)
        isempty(inc[n]) && continue
        active[n] = true
        onx, ony  = a == 0 || a == nx, b == 0 || b == ny
        slide[n]  = onx && ony ? -1 : onx ? 1 : ony ? 2 : 0
        for e in inc[n]
            push!(nbr[n], eu[e] == n ? ev[e] : eu[e])
        end
    end
    U = pd_relax_nodes(U0, nbr, active, slide, nx, ny, round(Int, 2 * sigma^2), pd_smooth_tube)

    pts = Vector{Matrix{Float64}}(undef, length(arcs))
    for (k, arc) in enumerate(arcs)
        P = Matrix{Float64}(undef, length(arc.nodes), 2)
        for (i, n) in enumerate(arc.nodes)
            P[i, 1] = x0 + U[n, 1] * dx
            P[i, 2] = y0 + U[n, 2] * dy
        end
        if arc.L > 0 && arc.R > 0 && size(P, 1) > 2
            P = pd_chaikin(P, pd_smooth_chaikin, arc.closed && !fixed[arc.nodes[1]])
            P[:, 1] .= clamp.(P[:, 1], x0, x1)
            P[:, 2] .= clamp.(P[:, 2], y0, y1)
        end
        pts[k] = P
    end

    half = [Tuple{Int,Int,Matrix{Float64}}[] for _ in 1:nd]
    for (k, arc) in enumerate(arcs)
        arc.L > 0 && push!(half[arc.L], (arc.nodes[1], arc.nodes[end], pts[k]))
        arc.R > 0 && push!(half[arc.R], (arc.nodes[end], arc.nodes[1], pts[k][end:-1:1, :]))
    end

    shoelace(r) = 0.5 * sum(r[i, 1] * r[i % size(r, 1) + 1, 2] - r[i % size(r, 1) + 1, 1] * r[i, 2] for i in 1:size(r, 1))

    polys = NamedTuple{(:domain, :id, :rings, :area),Tuple{Int,Int,Vector{Matrix{Float64}},Float64}}[]
    for d in 1:nd
        hs    = half[d]
        isempty(hs) && continue
        bystart = Dict{Int,Vector{Int}}()
        for (k, h) in enumerate(hs)
            push!(get!(bystart, h[1], Int[]), k)
        end
        taken = falses(length(hs))
        rings = Matrix{Float64}[]
        for k0 in eachindex(hs)
            taken[k0] && continue
            taken[k0] = true
            ring  = [hs[k0][3]]
            start, cur = hs[k0][1], hs[k0][2]
            while cur != start
                cand = get(bystart, cur, Int[])
                k    = findfirst(i -> !taken[i], cand)
                k === nothing && break
                taken[cand[k]] = true
                push!(ring, hs[cand[k]][3][2:end, :])
                cur = hs[cand[k]][2]
            end
            r = reduce(vcat, ring)
            size(r, 1) >= 3 && push!(rings, r)
        end
        isempty(rings) && continue
        push!(polys, (domain = d, id = idof[d], rings = rings, area = maximum(abs(shoelace(r)) for r in rings)))
    end
    sort!(polys, by = p -> -p.area)

    byphase = Dict{String,Vector{Int}}()
    for (k, arc) in enumerate(arcs)
        (arc.L > 0 && arc.R > 0) || continue
        pl = get(id2phases, idof[arc.L], String[])
        pr = get(id2phases, idof[arc.R], String[])
        for ph in symdiff(pl, pr)
            push!(get!(byphase, ph, Int[]), k)
        end
    end

    phase_lines = Dict{String,Tuple{Vector{Union{Float64,Missing}},Vector{Union{Float64,Missing}}}}()
    for (ph, ks) in byphase
        x, y   = Union{Float64,Missing}[], Union{Float64,Missing}[]
        ends   = Dict{Int,Vector{Int}}()
        for k in ks
            arcs[k].closed && continue
            push!(get!(ends, arcs[k].nodes[1], Int[]), k)
            push!(get!(ends, arcs[k].nodes[end], Int[]), k)
        end
        done = Set{Int}()
        emit(P) = (isempty(x) || (push!(x, missing); push!(y, missing)); append!(x, P[:, 1]); append!(y, P[:, 2]))
        for k in ks
            arcs[k].closed || continue
            emit(pts[k])
            push!(done, k)
        end
        for k0 in ks
            k0 in done && continue
            push!(done, k0)
            chain = pts[k0]
            for dir in (1, 2)
                tip = dir == 1 ? arcs[k0].nodes[end] : arcs[k0].nodes[1]
                while length(ends[tip]) == 2
                    k = ends[tip][1] == k0 || ends[tip][1] in done ? ends[tip][2] : ends[tip][1]
                    k in done && break
                    push!(done, k)
                    P   = arcs[k].nodes[1] == tip ? pts[k] : pts[k][end:-1:1, :]
                    nxt = arcs[k].nodes[1] == tip ? arcs[k].nodes[end] : arcs[k].nodes[1]
                    chain = dir == 1 ? vcat(chain, P[2:end, :]) : vcat(P[end:-1:1, :][1:end-1, :], chain)
                    tip = nxt
                end
            end
            emit(chain)
        end
        phase_lines[ph] = (x, y)
    end

    return (polys = polys, phase_lines = phase_lines, sigma = Float64(sigma))
end

function pd_get_smooth_geometry(sigma::Real)
    global pd_smooth_geom, gridded_fields, Out_XY, Hash_XY, data
    (@isdefined(gridded_fields) && @isdefined(Out_XY) && @isdefined(Hash_XY) && @isdefined(data)) || return nothing
    pd_smooth_geom !== nothing && pd_smooth_geom.sigma == Float64(sigma) && pd_smooth_geom.fields === gridded_fields &&
        pd_smooth_geom.out === Out_XY && return pd_smooth_geom.geom
    try
        t = @elapsed g = pd_smooth_geometry(gridded_fields, data.Xrange, data.Yrange, mc_id_to_phases(Out_XY, Hash_XY); sigma = sigma)
        println("Smoothed phase boundaries ($(length(g.polys)) fields) in $(round(t, digits = 3)) s")
        pd_smooth_geom = (sigma = Float64(sigma), fields = gridded_fields, out = Out_XY, geom = g)
        return g
    catch e
        println("Could not smooth phase boundaries: ", sprint(showerror, e))
        pd_smooth_geom = nothing
        return nothing
    end
end

function pd_smooth_reaction(reaction, geom)
    global phase_infos
    all_ph = vcat(phase_infos.act_ss, phase_infos.act_pp)
    length(reaction) == length(all_ph) || return reaction
    out = similar(reaction)
    for (i, t) in enumerate(reaction)
        tr      = deepcopy(t)
        x, y    = get(geom.phase_lines, all_ph[i], (Union{Float64,Missing}[], Union{Float64,Missing}[]))
        tr[:x]  = x
        tr[:y]  = y
        tr[:mode] = "lines"
        out[i]  = tr
    end
    return out
end

function pd_domain_values(geom, gridded::AbstractMatrix)
    global gridded_fields
    D, nd = pd_domains(gridded_fields)
    val   = fill(NaN, nd)
    for i in eachindex(D)
        v = gridded[i]
        (v !== missing && v isa Real && isfinite(v) && isnan(val[D[i]])) && (val[D[i]] = Float64(v))
    end
    return [val[p.domain] for p in geom.polys]
end

function pd_fill_colors(heat_map, values::Vector{Float64})
    global gridded
    zvals = collect(skipmissing(gridded))
    zmin  = haskey(heat_map, :zmin) ? Float64(heat_map[:zmin]) : minimum(zvals)
    zmax  = haskey(heat_map, :zmax) ? Float64(heat_map[:zmax]) : maximum(zvals)
    stops = svg_colorscale(heat_map[:colorscale]; reverse = haskey(heat_map, :reversescale) && heat_map[:reversescale] == true)
    return [isnan(v) ? nothing : svg_color_at(stops, zmax == zmin ? 0.0 : (v - zmin) / (zmax - zmin)) for v in values]
end

pd_rgba(c) = "rgba($(round(Int, c[1])),$(round(Int, c[2])),$(round(Int, c[3])),$(round(c[4], digits = 3)))"

function pd_fill_traces(geom, heat_map, gridded)
    cols   = pd_fill_colors(heat_map, pd_domain_values(geom, gridded))
    traces = GenericTrace{Dict{Symbol,Any}}[]
    for (p, c) in zip(geom.polys, cols)
        c === nothing && continue
        x, y = Union{Float64,Nothing}[], Union{Float64,Nothing}[]
        for r in p.rings
            isempty(x) || (push!(x, nothing); push!(y, nothing))
            append!(x, r[:, 1]); push!(x, r[1, 1])
            append!(y, r[:, 2]); push!(y, r[1, 2])
        end
        col = pd_rgba(c)
        push!(traces, scatter(; x = x, y = y, fill = "toself", fillcolor = col, mode = "lines",
                                line = attr(color = col, width = 0.5), hoverinfo = "skip", showlegend = false))
    end
    return traces
end

function pd_domain_rings(geom, raw_id::Integer)
    px, py = Union{Float64,Nothing}[], Union{Float64,Nothing}[]
    for p in geom.polys
        p.id == raw_id || continue
        for r in p.rings
            isempty(px) || (push!(px, nothing); push!(py, nothing))
            append!(px, r[:, 1]); push!(px, r[1, 1])
            append!(py, r[:, 2]); push!(py, r[1, 2])
        end
    end
    return px, py
end

function pd_isopleth_overlay(data_isopleth, Xr, Yr)
    traces = GenericTrace{Dict{Symbol,Any}}[]
    anns   = PlotlyBase.PlotlyAttribute[]
    for iso in pd_isopleth_sets(data_isopleth, identity)
        x, y = Union{Float64,Nothing}[], Union{Float64,Nothing}[]
        for (lvl, polys) in iso.levels
            txt = svg_tick_label(round_sig(lvl; sig = 4, mindigits = 0))
            for p in polys
                isempty(x) || (push!(x, nothing); push!(y, nothing))
                append!(x, first.(p)); append!(y, last.(p))
                px  = [pd_to_px(a, b, Xr, Yr) for (a, b) in p]
                seg = [hypot(px[k+1][1] - px[k][1], px[k+1][2] - px[k][2]) for k in 1:length(px)-1]
                tot = sum(seg; init = 0.0)
                tot < 40 && continue
                acc, k = 0.0, 1
                while acc + seg[k] < tot / 2
                    acc += seg[k]; k += 1
                end
                w   = seg[k] == 0 ? 0.0 : (tot / 2 - acc) / seg[k]
                ang = atand(px[k+1][2] - px[k][2], px[k+1][1] - px[k][1])
                ang > 90 && (ang -= 180); ang < -90 && (ang += 180)
                push!(anns, attr(xref = "x", yref = "y", x = p[k][1] + w * (p[k+1][1] - p[k][1]), y = p[k][2] + w * (p[k+1][2] - p[k][2]),
                                 text = txt, showarrow = false, textangle = ang, name = "pd-iso-label",
                                 font = attr(size = iso.label_size, color = iso.color), bgcolor = "rgba(255,255,255,0.7)", borderpad = 0))
            end
        end
        push!(traces, scatter(; x = x, y = y, mode = "lines", hoverinfo = "skip", showlegend = false,
                                line = attr(color = iso.color, dash = iso.dash, width = iso.width)))
    end
    return traces, anns
end
