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

const PD3D_EXPORT_SIZE = 100.0

pd3d_safe_name(s) = strip(replace(String(s), r"[^A-Za-z0-9_\-\.]+" => "_"), '_')

pd3d_ascii(s) = replace(String(s), r"[^\x20-\x7e]" => "_")

function pd3d_unit_coords(st::PD3D_state, v)
    s = PD3D_EXPORT_SIZE
    return (Float32(s * (v[1] - st.Pv[1]) / (st.Pv[end] - st.Pv[1])),
            Float32(s * (v[2] - st.Tv[1]) / (st.Tv[end] - st.Tv[1])),
            Float32(s * (v[3] - st.Xv[1]) / (st.Xv[end] - st.Xv[1])))
end

pd3d_rgb(c) = (round(UInt8, clamp(c[1], 0, 255)), round(UInt8, clamp(c[2], 0, 255)), round(UInt8, clamp(c[3], 0, 255)))

function pd3d_rgb(name::AbstractString)
    c = try Images.Colors.parse(Images.Colors.Colorant, name) catch; Images.Colors.RGB(0.5, 0.5, 0.5) end
    c = Images.Colors.RGB(c)
    return (round(UInt8, 255 * Float64(c.r)), round(UInt8, 255 * Float64(c.g)), round(UInt8, 255 * Float64(c.b)))
end

function pd3d_export_surfaces(st::PD3D_state, o)
    surfs = NamedTuple[]

    if "field" in o.layers
        A      = pd3d_field(st, o.f...)
        lo, hi = pd3d_range(A)
        if any(isfinite, A) && lo < hi
            intf        = pd3d_integer_spec(o.f[1], o.f[3]) ? o.f[3] : ""
            colorm, rev = get_colormap_prop(o.colormap, [1,9], o.reverse)
            cs, zr      = field_colorscale(intf, colorm, rev, "false", lo, hi)
            stops       = svg_colorscale(cs; reverse = rev)
            cmin, cmax  = Float64(get(zr, :zmin, lo)), Float64(get(zr, :zmax, hi))
            imin        = isnothing(o.isomin) ? lo : Float64(o.isomin)
            imax        = isnothing(o.isomax) ? hi : Float64(o.isomax)
            ns          = isnothing(o.nsurf)  ? 5  : Int(o.nsurf)
            levels      = ns == 1 ? [(imin + imax) / 2] : collect(range(imin, imax, length = ns))
            label       = pd3d_spec_label(o.f...)
            for (k, lev) in enumerate(levels)
                verts, faces, _ = pd3d_mesh(st, A, lev)
                isempty(faces) && continue
                col = pd3d_rgb(svg_color_at(stops, (lev - cmin) / (cmax - cmin)))
                push!(surfs, (  name  = "field_$(k)_$(label)_$(round(lev, sigdigits = 4))",
                                desc  = "Field isosurface: $label = $(round(lev, sigdigits = 4))",
                                verts = verts, faces = faces, rgb = fill(col, length(verts)) ))
            end
        end
    end

    if "surface" in o.layers
        verts, faces, Bv = pd3d_surface_mesh(st, o)
        if !isempty(faces)
            colorm, rev = get_colormap_prop(o.surf_colormap, [1,9], o.surf_reverse)
            stops       = svg_colorscale(colorm; reverse = rev)
            blo, bhi    = pd3d_range(Bv)
            rgb         = [pd3d_rgb(svg_color_at(stops, bhi > blo ? (b - blo) / (bhi - blo) : 0.5)) for b in Bv]
            push!(surfs, (  name  = "surface_$(pd3d_spec_label(o.a...))_$(o.iso)",
                            desc  = "Coloured surface: $(pd3d_spec_label(o.a...)) = $(o.iso), vertex colour = $(pd3d_spec_label(o.b...)) ($(round(blo, sigdigits = 4)) to $(round(bhi, sigdigits = 4)), $(o.surf_colormap))",
                            verts = verts, faces = faces, rgb = rgb ))
        end
    end

    if "phases" in o.layers
        for ph in something(o.phases, String[])
            verts, faces, _ = pd3d_mesh(st, pd3d_field(st, "ph_frac_vol", ph, ""), o.eps)
            isempty(faces) && continue
            col = pd3d_rgb(pd3d_phase_color(ph))
            push!(surfs, (  name  = "phase_$(ph)_in_out",
                            desc  = "Phase-in/out surface: $(display_ph_name(ph)) vol fraction = $(o.eps)",
                            verts = verts, faces = faces, rgb = fill(col, length(verts)) ))
        end
    end

    return surfs
end

function pd3d_write_ply(path, verts, faces, rgb)
    open(path, "w") do io
        write(io, "ply\nformat binary_little_endian 1.0\ncomment MAGEMinApp 3D diagram surface\n" *
                  "element vertex $(length(verts))\nproperty float x\nproperty float y\nproperty float z\n" *
                  "property uchar red\nproperty uchar green\nproperty uchar blue\n" *
                  "element face $(length(faces))\nproperty list uchar int vertex_indices\nend_header\n")
        for (v, c) in zip(verts, rgb)
            write(io, htol(v[1]), htol(v[2]), htol(v[3]), c[1], c[2], c[3])
        end
        for f in faces
            write(io, UInt8(3), htol(Int32(f[1] - 1)), htol(Int32(f[2] - 1)), htol(Int32(f[3] - 1)))
        end
    end
end

function pd3d_write_stl(path, verts, faces, title)
    open(path, "w") do io
        write(io, codeunits(rpad(first(pd3d_ascii("MAGEMinApp " * title), 80), 80)))
        write(io, htol(UInt32(length(faces))))
        for f in faces
            a, b, c = verts[f[1]], verts[f[2]], verts[f[3]]
            u, w    = b .- a, c .- a
            n       = (u[2]*w[3] - u[3]*w[2], u[3]*w[1] - u[1]*w[3], u[1]*w[2] - u[2]*w[1])
            l       = sqrt(sum(abs2, n))
            n       = l > 0 ? n ./ l : (0f0, 0f0, 0f0)
            write(io, htol.(Float32.(n))..., htol.(a)..., htol.(b)..., htol.(c)..., htol(UInt16(0)))
        end
    end
end

function pd3d_export_meshes(st::PD3D_state, o, dir)
    surfs = pd3d_export_surfaces(st, o)
    isempty(surfs) && return 0
    mkpath(dir)
    lines = String[]
    for s in surfs
        fname = pd3d_safe_name(s.name)
        verts = [pd3d_unit_coords(st, v) for v in s.verts]
        pd3d_write_ply(joinpath(dir, fname * ".ply"), verts, s.faces, s.rgb)
        pd3d_write_stl(joinpath(dir, fname * ".stl"), verts, s.faces, s.desc)
        push!(lines, "$(fname).ply / .stl : $(s.desc) ($(length(s.faces)) triangles)")
    end
    unit = pressure_unit_label()
    open(joinpath(dir, "README.txt"), "w") do io
        println(io, "MAGEMinApp 3D P-T-X diagram surfaces ($(st.date), database $(st.dtb), $(length(st.Pv)) x $(length(st.Tv)) x $(length(st.Xv)) grid)")
        println(io)
        println(io, "Coordinates are normalized to a $(Int(PD3D_EXPORT_SIZE)) x $(Int(PD3D_EXPORT_SIZE)) x $(Int(PD3D_EXPORT_SIZE)) cube (data orientation, axis reversals of the view not applied):")
        println(io, "  x = 0 -> $(Int(PD3D_EXPORT_SIZE)) : P = $(round(display_pressure(st.Pv[1]), digits = 3)) -> $(round(display_pressure(st.Pv[end]), digits = 3)) $unit")
        println(io, "  y = 0 -> $(Int(PD3D_EXPORT_SIZE)) : T = $(st.Tv[1]) -> $(st.Tv[end]) C")
        println(io, "  z = 0 -> $(Int(PD3D_EXPORT_SIZE)) : X = $(st.Xv[1]) -> $(st.Xv[end]) (bulk X0 -> X1)")
        println(io)
        println(io, "PLY files carry per-vertex RGB colours (same colour scales as the app); STL files are geometry only.")
        println(io, "They overlay exactly on the VTK grid export of the same diagram.")
        println(io)
        foreach(l -> println(io, l), lines)
    end
    return length(surfs)
end

function pd3d_export_vtk(st::PD3D_state, o, path)
    nP, nT, nX = length(st.Pv), length(st.Tv), length(st.Xv)
    fields     = Pair{String, Array{Float64,3}}[]
    push!(fields, "P_kbar" => [p for p in st.Pv, t in st.Tv, x in st.Xv])
    push!(fields, "T_C"    => [t for p in st.Pv, t in st.Tv, x in st.Xv])
    push!(fields, "X"      => [x for p in st.Pv, t in st.Tv, x in st.Xv])
    for opt in pd3d_field_options()
        push!(fields, "sys_" * pd3d_safe_name(opt.value) => pd3d_field(st, opt.value))
    end
    for ph in pd3d_phases(st)
        push!(fields, "mode_vol_" * pd3d_safe_name(ph) => pd3d_field(st, "ph_frac_vol", ph, ""))
    end
    for (tag, spec) in (("Field", o.f), ("SurfaceA", o.a), ("ColourB", o.b), ("ContourC", o.c))
        push!(fields, tag * "_" * pd3d_safe_name(pd3d_spec_label(spec...)) => pd3d_field(st, spec...))
    end

    s = PD3D_EXPORT_SIZE
    open(path, "w") do io
        write(io, "# vtk DataFile Version 3.0\n")
        write(io, pd3d_ascii("MAGEMinApp 3D P-T-X diagram $(st.dtb) $(st.date); cube 0-$(Int(s)): x=P y=T z=X; real P [kbar], T [C], X in point data") * "\n")
        write(io, "BINARY\nDATASET STRUCTURED_POINTS\n")
        write(io, "DIMENSIONS $nP $nT $nX\nORIGIN 0 0 0\nSPACING $(s / (nP - 1)) $(s / (nT - 1)) $(s / (nX - 1))\n")
        write(io, "POINT_DATA $(nP * nT * nX)\n")
        for (name, A) in fields
            write(io, "SCALARS $(pd3d_ascii(name)) float 1\nLOOKUP_TABLE default\n")
            write(io, hton.(Float32.(vec(A))))
            write(io, "\n")
        end
    end
    return length(fields)
end

function pd3d_export_html(st::PD3D_state, o, path)
    logo  = "data:image/jpeg;base64," * base64encode(read(joinpath(pkg_dir, PD3D_LOGO_SRC)))
    fig   = pd3d_figure(st, o; logo_src = logo)
    data  = replace(JSON.json(fig.plot), "</" => "<\\/")
    title = pd3d_ascii("MAGEMinApp 3D diagram - $(st.dtb) - $(st.date)")
    open(path, "w") do io
        write(io, "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<title>$title</title>\n<script type=\"text/javascript\">\n")
        write(io, read(PlotlyJS._js_path, String))
        write(io, "\n</script>\n</head>\n<body style=\"margin:0\">\n<div id=\"pd3d\"></div>\n<script type=\"text/javascript\">\n")
        write(io, "var fig = ", data, ";\n")
        write(io, "Plotly.newPlot('pd3d', fig.data, fig.layout, {displaylogo: false, toImageButtonOptions: {format: 'png', filename: 'MAGEMin_3D_diagram', scale: 2}});\n")
        write(io, "</script>\n</body>\n</html>\n")
    end
    return filesize(path)
end
