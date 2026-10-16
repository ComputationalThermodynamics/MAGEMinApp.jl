const PD_PLOT_W   = 604.0
const PD_PLOT_H   = 590.0
const PD_LABEL_BG = "rgba(255,255,255,0.85)"
const PD_LABEL_RINGS  = (18.0, 28.0, 40.0, 55.0, 75.0, 100.0, 130.0, 170.0, 220.0)
const PD_LABEL_ANGLES = [-135.0 + 22.5 * k for k in 0:15]

mutable struct PDLabel
    field  :: Int
    kind   :: Symbol
    text   :: String
    fs     :: Float64
    w      :: Float64
    h      :: Float64
    anchor :: NTuple{2,Float64}
    cands  :: Vector{NTuple{2,Float64}}
    pos    :: NTuple{2,Float64}
end

function PDLabel(field, kind, text, fs, anchor, cands)
    w, h = pd_label_box(text, fs)
    return PDLabel(field, kind, text, fs, w, h, anchor, cands, anchor)
end

pd_label_text(t) = replace(strip(string(t)), r"(\s*<br\s*/?>\s*)+$" => "")

function pd_label_box(text, fs)
    lines = split(pd_label_text(text), r"<br\s*/?>")
    nch   = maximum(l -> length(strip(l)), lines; init = 1)
    return 0.6 * fs * max(nch, 1) + 4.0, 1.25 * fs * length(lines) + 2.0
end

pd_to_px(x, y, Xr, Yr) = ((x - Xr[1]) / (Xr[2] - Xr[1]) * PD_PLOT_W, (Yr[2] - y) / (Yr[2] - Yr[1]) * PD_PLOT_H)
pd_to_data(px, py, Xr, Yr) = (Xr[1] + px / PD_PLOT_W * (Xr[2] - Xr[1]), Yr[2] - py / PD_PLOT_H * (Yr[2] - Yr[1]))

function pd_field_candidates(mask, Yb, Xb, center, Xr, Yr; k = 12, sep = 0.025)
    out  = [(Float64(center[1]), Float64(center[2]))]
    dist = get_chessboard_distance(.!mask)
    cells = sort(vec(findall(dist .> 0)), by = c -> -dist[c])
    for c in cells
        length(out) >= k && break
        p = ((Xb[c[1]] + Xb[c[1]+1]) / 2.0, (Yb[c[2]] + Yb[c[2]+1]) / 2.0)
        far = all(q -> abs(p[1] - q[1]) / (Xr[2] - Xr[1]) > sep || abs(p[2] - q[2]) / (Yr[2] - Yr[1]) > sep, out)
        far && push!(out, p)
    end
    return out
end

pd_box(c, w, h) = (c[1] - w / 2, c[2] - h / 2, c[1] + w / 2, c[2] + h / 2)

pd_box_inside(b) = b[1] >= 0.0 && b[2] >= 0.0 && b[3] <= PD_PLOT_W && b[4] <= PD_PLOT_H

pd_overlap(a, b; m = 1.5) = max(0.0, min(a[3], b[3]) + m - max(a[1], b[1])) * max(0.0, min(a[4], b[4]) + m - max(a[2], b[2]))

function pd_seg_hits_box(p, q, b)
    n = max(2, ceil(Int, hypot(q[1] - p[1], q[2] - p[2]) / 3))
    for s in 1:n-1
        t = s / n
        x, y = p[1] + t * (q[1] - p[1]), p[2] + t * (q[2] - p[2])
        (b[1] <= x <= b[3] && b[2] <= y <= b[4]) && return true
    end
    return false
end

function pd_segs_cross(a, b, c, d)
    o(p, q, r) = sign((q[1] - p[1]) * (r[2] - p[2]) - (q[2] - p[2]) * (r[1] - p[1]))
    return o(a, b, c) * o(a, b, d) < 0 && o(c, d, a) * o(c, d, b) < 0
end

function pd_place_labels!(labels)
    boxes   = NTuple{4,Float64}[]
    owners  = Int[]
    leaders = Tuple{NTuple{2,Float64},NTuple{2,Float64}}[]
    obst    = [(l.anchor[1] - 3, l.anchor[2] - 3, l.anchor[1] + 3, l.anchor[2] + 3) for l in labels if l.kind == :arrow]
    obst_ow = [k for (k, l) in enumerate(labels) if l.kind == :arrow]

    clear(b, k) = !any(j -> owners[j] != k && pd_overlap(b, boxes[j]) > 0, eachindex(boxes)) &&
                  !any(j -> obst_ow[j] != k && pd_overlap(b, obst[j]; m = 0.0) > 0, eachindex(obst))

    for kind in (:full, :num), k in eachindex(labels)
        l = labels[k]
        l.kind == kind || continue
        placed = false
        for c in l.cands
            b = pd_box(c, l.w, l.h)
            if pd_box_inside(b) && clear(b, k)
                l.pos = c; push!(boxes, b); push!(owners, k); placed = true
                break
            end
        end
        if !placed
            if kind == :full
                l.pos = l.cands[1]; push!(boxes, pd_box(l.cands[1], l.w, l.h)); push!(owners, k)
            else
                l.kind = :arrow; l.fs = 9.0
                l.w, l.h = pd_label_box(l.text, 9.0)
                push!(obst, (l.anchor[1] - 3, l.anchor[2] - 3, l.anchor[1] + 3, l.anchor[2] + 3)); push!(obst_ow, k)
            end
        end
    end

    arrows = [k for k in eachindex(labels) if labels[k].kind == :arrow]
    crowd(k) = count(j -> j != k && hypot(labels[j].anchor[1] - labels[k].anchor[1], labels[j].anchor[2] - labels[k].anchor[2]) < 40.0, arrows)
    sort!(arrows, by = k -> -crowd(k))

    for k in arrows
        l    = labels[k]
        a    = l.anchor
        best = (Inf, a, pd_box(a, l.w, l.h))
        for r in PD_LABEL_RINGS, (m, θ) in enumerate(PD_LABEL_ANGLES)
            c = (a[1] + r * cosd(θ), a[2] + r * sind(θ))
            b = pd_box(c, l.w, l.h)
            pd_box_inside(b) || continue
            ov  = sum((pd_overlap(b, boxes[j]) for j in eachindex(boxes) if owners[j] != k); init = 0.0) +
                  sum((pd_overlap(b, obst[j]; m = 0.0) for j in eachindex(obst) if obst_ow[j] != k); init = 0.0)
            hit = count(j -> owners[j] != k && pd_seg_hits_box(a, c, boxes[j]), eachindex(boxes))
            crs = count(s -> pd_segs_cross(a, c, s[1], s[2]), leaders)
            dev = min(m - 1, 16 - (m - 1))
            sc  = ov == 0 ? r + 25.0 * hit + 12.0 * crs + 1.5 * dev : 1e4 + ov + r
            sc < best[1] && (best = (sc, c, b))
        end
        l.pos = best[2]
        push!(boxes, best[3]); push!(owners, k)
        push!(leaders, (a, best[2]))
    end
    return labels
end

function pd_number_order(labels, ids; bands = 10)
    band(k) = floor(Int, (PD_PLOT_H - labels[k].anchor[2]) / (PD_PLOT_H / bands))
    return sort(ids, by = k -> (band(k), labels[k].anchor[1]))
end

function pd_apply_label_bg!(annotations, on::Bool)
    for ann in annotations
        f = ann.fields
        (get(f, :xref, "") == "x" && get(f, :yref, "") == "y") || continue
        if on && !isempty(string(get(f, :text, "")))
            f[:bgcolor]   = PD_LABEL_BG
            f[:borderpad] = 1
        else
            delete!(f, :bgcolor); delete!(f, :borderpad)
        end
    end
    return annotations
end
