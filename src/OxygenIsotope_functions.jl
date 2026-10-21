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

const O18_QUANTITIES = [    (label = "δ18O of phase",           value = "d"     ),
                            (label = "Δ18O phase 1 - phase 2",  value = "D"     ),
                            (label = "δ18O melt",               value = "liq"   ),
                            (label = "δ18O fluid",              value = "fl"    ),
                            (label = "δ18O solid",              value = "sol"   ),
                            (label = "δ18O system",             value = "sys"   ),
                            (label = "δ18O virtual quartz",     value = "qz"    ),
                            (label = "Oxygen fraction of phase",value = "f"     ) ]

const O18_MELT_MODELS = [   (label = "CIPW norm (Bindeman, 2008)",      value = "norm"   ),
                            (label = "Oxide index (Zhao & Zheng, 2003)",value = "ZZ03"   ),
                            (label = "Melt end-members",                value = "liq_em" ) ]

const O18_UNMAPPED = [      (label = "exclude",                         value = "exclude"),
                            (label = "oxide index (Zhao & Zheng, 2003)",value = "index"  ) ]

"""
    o18_available()

    True when δ18O results exist for every point of the current phase diagram.
"""
function o18_available()
    isdefined(@__MODULE__, :Out_O18_XY) && isdefined(@__MODULE__, :Out_XY) || return false
    return !isempty(Out_O18_XY) && length(Out_O18_XY) == length(Out_XY)
end

"""
    o18_undefined(out, flag)

    δ18O result with every value undefined, used where `O18_prediction` cannot be evaluated
    (no mapped oxygen-bearing phase, anchor phase not stable).
"""
function o18_undefined(out::MAGEMin_C.gmin_struct{Float64, Int64}, flag::String)
    n = length(out.ph)
    return MAGEMin_C.out_O18(   out.T_C, NaN, NaN, 0.0, copy(out.ph), zeros(n), fill(NaN, n), fill(NaN, n), fill(NaN, n),
                                fill(NaN, n), [String[] for _ in 1:n], [Float64[] for _ in 1:n], NaN, NaN, NaN, 1.0, [flag])
end

"""
    o18_bulk_oxygen(bulk, oxi)

    Moles of oxygen per mole of oxides of a molar bulk composition.
"""
function o18_bulk_oxygen(bulk::Vector{Float64}, oxi::Vector{String})
    b = bulk ./ sum(bulk)
    return sum(b[j] * get(MAGEMin_C._O18_nu_O, oxi[j], 0.0) for j in eachindex(oxi))
end

"""
    o18_function(diagType, δ1, δ2, anchor, melt_model, unmapped, T_max, bulk_L, bulk_R, oxi)

    Oxygen isotope composition of every point of the current phase diagram (`Out_XY`).
    For diagrams with a compositional axis (T-X, P-X, PT-X and the S-X, H-X, V-X sections) the bulk δ18O is the
    oxygen-weighted mixture of `δ1` (bulk 1) and `δ2` (bulk 2) along the molar mixing coordinate X; all other
    diagrams (P-T, T-T, μ-μ, P/T-S/V/H sections) use `δ1`. With an `anchor` phase, `δ1` is the δ18O of that phase.

    Returns
    -------
    Out_O18_XY : Vector{MAGEMin_C.out_O18}
        δ18O results, one per point.
    all_O18_ph : Vector{String}
        Names of the phases holding oxygen somewhere in the diagram.
"""
function o18_function(  diagType    :: String,
                        δ1          :: Float64,
                        δ2          :: Float64,
                        anchor      :: String,
                        melt_model  :: String,
                        unmapped    :: String,
                        T_max       :: Float64,
                        bulk_L      :: Vector{Float64},
                        bulk_R      :: Vector{Float64},
                        oxi         :: Vector{String} )

    np          = length(Out_XY)
    Out_O18_XY  = Vector{MAGEMin_C.out_O18}(undef, np)
    all_O18_ph  = String[]
    mix         = (diagType in ("tx", "px", "ptx") || diagType in SECTION_X_TYPES) && isempty(anchor)
    O_L         = mix ? o18_bulk_oxygen(bulk_L, oxi) : 1.0
    O_R         = mix ? o18_bulk_oxygen(bulk_R, oxi) : 1.0
    db          = MAGEMin_C.get_O18_database()
    mapping     = MAGEMin_C.get_O18_mapping()

    for i = 1:np
        out     = Out_XY[i]
        x       = mix ? out.X[1] : 0.0
        δ       = isempty(anchor) ? ((1.0 - x) * O_L * δ1 + x * O_R * δ2) / ((1.0 - x) * O_L + x * O_R) : δ1
        Out_O18_XY[i] = try
            MAGEMin_C.O18_prediction(out, δ; db, mapping, anchor, melt_model, unmapped = Symbol(unmapped), T_max)
        catch e
            o18_undefined(out, sprint(showerror, e))
        end
        for (k, p) in enumerate(Out_O18_XY[i].ph)
            (Out_O18_XY[i].f_O[k] > 0.0 && !(p in all_O18_ph)) && push!(all_O18_ph, p)
        end
    end

    return Out_O18_XY, all_O18_ph
end

"""
    o18_diagram(o18, diagType, δ1, δ2, anchor, δ_anchor, melt_model, unmapped, T_max, bulk_L, bulk_R, oxi)

    Setup-tab entry point: parses the δ18O inputs and runs [`o18_function`](@ref) when `o18 == "true"`,
    otherwise returns empty results so that stale δ18O data are never displayed with a new diagram.
"""
function o18_diagram(o18, diagType, δ1, δ2, anchor, δ_anchor, melt_model, unmapped, T_max, bulk_L, bulk_R, oxi)
    o18 == "true" || return MAGEMin_C.out_O18[], String[]
    num(v, d) = v isa Real ? Float64(v) : (v isa AbstractString && !isnothing(tryparse(Float64, v)) ? parse(Float64, v) : d)
    anchor    = String(strip(something(anchor, "")))
    isempty(anchor) || (δ1 = δ2 = num(δ_anchor, 10.0))
    return o18_function(    diagType, num(δ1, 6.0), num(δ2, num(δ1, 6.0)), anchor,
                            String(something(melt_model, "norm")), String(something(unmapped, "exclude")), num(T_max, 900.0),
                            bulk_L, bulk_R, oxi )
end

"""
    is_o18_field(fieldname)

    True for a δ18O field of the phase diagram ("o18:" followed by an [`o18_fieldname`](@ref) code).
"""
is_o18_field(fieldname) = fieldname isa AbstractString && startswith(fieldname, "o18:")

"""
    o18_field_name(fieldname)

    [`o18_fieldname`](@ref) code of a phase-diagram δ18O field.
"""
o18_field_name(fieldname::AbstractString) = String(chop(fieldname, head = 4, tail = 0))

"""
    o18_main_fieldname(field, q, p1, p2)

    Field name used by the phase diagram: the δ18O selection when the "Field" dropdown is "o18", otherwise `field`.
"""
o18_main_fieldname(field, q, p1, p2) = field == "o18" ? "o18:" * o18_fieldname(q, p1, p2) : field

"""
    field_color_range(fieldname, gridded)

    Default colour range of a phase-diagram field: min/max of the gridded field, or for δ18O fields of the values
    defined at the computed points ((0, 1) when the field is defined nowhere).
"""
function field_color_range(fieldname, gridded)
    is_o18_field(fieldname) || return round_sig(grid_min(gridded)), round_sig(grid_max(gridded))
    vals = o18_available() ? o18_field_values(fieldname) : Float64[]
    isempty(vals) && return 0.0, 1.0
    return round_sig(minimum(vals)), round_sig(maximum(vals))
end

"""
    o18_gridded_display(gridded, data, fieldname)

    Gap-filled heatmap field ([`pd_fill_gridded`](@ref)). δ18O fields carry NaN where they are undefined
    (phase absent) and `missing` at grid nodes the AMR interpolation leaves empty. The defined/undefined indicator
    is gap-filled the same way and cells where it falls below 1/2 are left empty, so absent-phase regions are not
    painted by the fill.
"""
function o18_gridded_display(gridded::AbstractMatrix, data, fieldname)
    filled = pd_fill_gridded(gridded, data)
    is_o18_field(fieldname) || return filled
    defined = Matrix{Union{Float64,Missing}}([ismissing(v) ? missing : (isnan(v) ? 0.0 : 1.0) for v in gridded])
    ind     = svg_fill_gaps(defined)
    filled[[ismissing(v) || v < 0.5 for v in ind]] .= missing
    return filled
end

"""
    o18_fieldname(q, p1, p2)

    Encode a δ18O field selection as a string: "d|phase", "f|phase", "D|phase1|phase2" or the
    subsystem name ("liq", "fl", "sol", "sys", "qz").
"""
function o18_fieldname(q, p1, p2)
    q   = String(something(q, "d"))
    p1  = String(something(p1, ""))
    p2  = String(something(p2, ""))
    q in ("d", "f") && return "$q|$p1"
    q == "D"        && return "D|$p1|$p2"
    return q
end

"""
    o18_value(o, fieldname)

    Value of an encoded δ18O field ([`o18_fieldname`](@ref)) for one point, NaN when undefined.
"""
function o18_value(o::MAGEMin_C.out_O18, fieldname::String)
    parts   = split(fieldname, '|')
    q       = parts[1]
    ph_id(p) = findfirst(==(p), o.ph)
    if q == "d" || q == "f"
        i = ph_id(parts[2])
        isnothing(i) && return NaN
        return q == "d" ? o.δ_ph[i] : (o.f_O[i] > 0.0 ? o.f_O[i] : NaN)
    elseif q == "D"
        return MAGEMin_C.Δ18O(o, String(parts[2]), String(parts[3]))
    elseif q == "liq"
        return o.δ_liq
    elseif q == "fl"
        return o.δ_fl
    elseif q == "sol"
        return o.δ_sol
    elseif q == "sys"
        return o.δ_sys
    elseif q == "qz"
        return o.δ_qz
    end
    return NaN
end

"""
    o18_field_values(fieldname)

    Finite values of an encoded δ18O field over the points of the current diagram.
"""
o18_field_values(fieldname::String) = Float64[v for v in (o18_value(o, is_o18_field(fieldname) ? o18_field_name(fieldname) : fieldname) for o in Out_O18_XY) if isfinite(v)]

"""
    o18_field_label(fieldname)

    Display label of an encoded δ18O field, used as colorbar title and isopleth name.
"""
function o18_field_label(fieldname::String)
    is_o18_field(fieldname) && (fieldname = o18_field_name(fieldname))
    parts = split(fieldname, '|')
    q     = parts[1]
    q == "d"   && return "δ¹⁸O " * display_ph_name(String(parts[2])) * " [‰]"
    q == "f"   && return "f_O " * display_ph_name(String(parts[2]))
    q == "D"   && return "Δ¹⁸O " * display_ph_name(String(parts[2])) * "-" * display_ph_name(String(parts[3])) * " [‰]"
    q == "liq" && return "δ¹⁸O melt [‰]"
    q == "fl"  && return "δ¹⁸O fluid [‰]"
    q == "sol" && return "δ¹⁸O solid [‰]"
    q == "sys" && return "δ¹⁸O system [‰]"
    q == "qz"  && return "δ¹⁸O virtual quartz [‰]"
    return fieldname
end

"""
    o18_phase_options()

    Dropdown options listing the phases holding oxygen in the current diagram.
"""
function o18_phase_options()
    o18_available() || return Dict{String,String}[]
    return [Dict("label" => display_ph_name(p), "value" => p) for p in all_O18_ph]
end

"""
    o18_default_phases()

    Default phase pair of the δ18O selectors: quartz (or the first oxygen-bearing phase) and garnet
    (or the next phase).
"""
function o18_default_phases()
    o18_available() && !isempty(all_O18_ph) || return nothing, nothing
    p1 = "q" in all_O18_ph ? "q" : all_O18_ph[1]
    rest = [p for p in all_O18_ph if p != p1]
    p2 = "g" in rest ? "g" : (isempty(rest) ? p1 : rest[1])
    return p1, p2
end

"""
    o18_selector(suffix)

    Field selector (quantity, phase 1, phase 2) of the δ18O fields; `suffix` separates the
    "Select field to display" ("-pd") and isopleth ("-iso") panels of the phase diagram tab.
"""
function o18_selector(suffix::String)
    w = suffix == "-pd" ? 5 : 6
    row(title, id, options, value) = dbc_row([
                                        dbc_col([
                                            html_h1(title, style = Dict("textAlign" => "center","font-size" => "120%", "marginTop" => 8)),
                                        ], width=w),
                                        dbc_col([
                                            dcc_dropdown(   id          = id,
                                                            options     = options,
                                                            value       = value,
                                                            clearable   = false,
                                                            multi       = false),
                                        ]),
                                    ])
    return [    row("Quantity", "fields-dropdown-o18-q"  * suffix, O18_QUANTITIES, "d"),
                html_div([row("Phase 1", "fields-dropdown-o18-p1" * suffix, Dict{String,String}[], nothing)], id = "o18-p1-row" * suffix),
                html_div([row("Phase 2", "fields-dropdown-o18-p2" * suffix, Dict{String,String}[], nothing)], style = Dict("display" => "none"), id = "o18-p2-row" * suffix) ]
end

"""
    o18_phase_rows_style(q)

    Display style of the phase 1 and phase 2 selectors for quantity `q`: phase 1 for the δ18O and oxygen fraction
    of a phase and for Δ18O, phase 2 for Δ18O only.
"""
function o18_phase_rows_style(q)
    vis(b) = Dict("display" => b ? "block" : "none")
    return vis(q in ("d", "f", "D")), vis(q == "D")
end

"""
    get_o18_point_plot(o)

    δ18O of the stable phases of one point, sorted, with marker size scaled by the oxygen fraction
    and the system value as a dashed line; an `Int64` argument is a point of the current phase diagram.
"""
get_o18_point_plot(point_id::Int64) = get_o18_point_plot(Out_O18_XY[point_id])

function get_o18_point_plot(o::MAGEMin_C.out_O18)
    idx     = [i for i in eachindex(o.ph) if o.f_O[i] > 0.0 && isfinite(o.δ_ph[i])]
    idx     = idx[sortperm(o.δ_ph[idx])]
    names   = [display_ph_name(o.ph[i]) for i in idx]
    data    = [ scatter(    x           = o.δ_ph[idx],
                            y           = names,
                            mode        = "markers",
                            marker      = attr(size = 8 .+ 30 .* sqrt.(o.f_O[idx]), color = "#2a6f97", line = attr(width = 1, color = "black")),
                            text        = ["f_O = $(round(100 * o.f_O[i], digits = 1)) %" for i in idx],
                            hoverinfo   = "x+y+text",
                            showlegend  = false ) ]
    if isfinite(o.δ_sys)
        push!(data, scatter(x = [o.δ_sys, o.δ_sys], y = isempty(names) ? [nothing, nothing] : [names[1], names[end]],
                            mode = "lines", line = attr(color = "black", dash = "dash", width = 1),
                            name = "system", showlegend = false, hoverinfo = "skip"))
    end
    layout  = Layout(   xaxis_title     = "δ¹⁸O [‰ VSMOW]",
                        height          = 320,
                        margin          = attr(l = 80, r = 20, t = 20, b = 50),
                        plot_bgcolor    = "#FFF",
                        paper_bgcolor   = "#FFF",
                        xaxis           = attr(showline = true, linecolor = "black", mirror = true, ticks = "inside", zeroline = false),
                        yaxis           = attr(showline = true, linecolor = "black", mirror = true, ticks = "inside") )
    return plot(data, layout)
end

"""
    get_o18_point_info(o)

    Markdown table of the δ18O of the stable phases of one point, with the subsystem values and flags; an `Int64`
    argument is a point of the current phase diagram.
"""
get_o18_point_info(point_id::Int64) = get_o18_point_info(Out_O18_XY[point_id])

function get_o18_point_info(o::MAGEMin_C.out_O18)
    r(v)    = isfinite(v) ? string(round(v, digits = 2)) : "-"
    infos   = "\n| Phase &nbsp;| δ¹⁸O [‰] &nbsp;| f_O [%] &nbsp;|\n|-------|------|------|\n"
    for i in eachindex(o.ph)
        o.f_O[i] > 0.0 || continue
        infos *= "| $(display_ph_name(o.ph[i])) | $(r(o.δ_ph[i])) | $(round(100 * o.f_O[i], digits = 1)) |\n"
    end
    infos *= "| system | $(r(o.δ_sys)) | 100 |\n"
    isfinite(o.δ_liq) && (infos *= "| melt | $(r(o.δ_liq)) | |\n")
    isfinite(o.δ_fl)  && (infos *= "| fluid | $(r(o.δ_fl)) | |\n")
    isfinite(o.δ_sol) && (infos *= "| solid | $(r(o.δ_sol)) | |\n")
    o.f_O_unmapped > 0.0 && (infos *= "\nunmapped oxygen: $(round(100 * o.f_O_unmapped, digits = 2)) %\n")
    for f in o.flags
        infos *= "\n- $f"
    end
    return infos
end

"""
    o18_export_csv(ids, fileout)

    Write the δ18O of the stable phases of the points `ids` of the current diagram to a CSV file, one row per
    phase holding oxygen, with the system, virtual quartz, melt, fluid and solid values and the flags of each point.
"""
function o18_export_csv(ids::Vector{Int64}, fileout::String)
    unit = use_GPa[1] ? "P_GPa" : "P_kbar"
    f(v) = isfinite(v) ? string(round(v, digits = 4)) : ""
    open(fileout, "w") do io
        println(io, "# δ18O [‰ VSMOW], DBOxygen 2.0.3 (Vho et al., 2019); f_O: fraction of the system oxygen held by the phase")
        println(io, "point,$unit,T_C,X,phase,d18O,f_O,d18O_system,d18O_virtual_quartz,d18O_melt,d18O_fluid,d18O_solid,unmapped_O_fraction,flags")
        for i in ids
            o, out = Out_O18_XY[i], Out_XY[i]
            P      = round(display_pressure(out.P_kbar), digits = 6)
            flags  = "\"" * replace(join(o.flags, "; "), "\"" => "'") * "\""
            for k in eachindex(o.ph)
                o.f_O[k] > 0.0 || continue
                println(io, join((i, P, out.T_C, out.X[1], display_ph_name(o.ph[k]), f(o.δ_ph[k]), f(o.f_O[k]),
                                  f(o.δ_sys), f(o.δ_qz), f(o.δ_liq), f(o.δ_fl), f(o.δ_sol), f(o.f_O_unmapped), flags), ","))
            end
        end
    end
    println("δ18O table saved in $fileout")
    return fileout
end

"""
    o18_ptx_options(model, δ, δ_ass, melt_model, unmapped, T_max)

    δ18O options of a PTX path from the PTX tab inputs, `nothing` when the δ18O model is off.
"""
function o18_ptx_options(model, δ, δ_ass, melt_model, unmapped, T_max)
    model == "true" || return nothing
    num(v, d) = v isa Real ? Float64(v) : (v isa AbstractString && !isnothing(tryparse(Float64, v)) ? parse(Float64, v) : d)
    return (δ = num(δ, 6.0), δ_ass = num(δ_ass, num(δ, 6.0)), melt_model = String(something(melt_model, "norm")),
            unmapped = String(something(unmapped, "exclude")), T_max = num(T_max, 900.0))
end

"""
    o18_point(out, δ, opts)

    `O18_prediction` of one PTX path point with the PTX δ18O options `opts` (`melt_model`, `unmapped`, `T_max`),
    or an undefined result when it cannot be evaluated.
"""
function o18_point(out::MAGEMin_C.gmin_struct{Float64, Int64}, δ::Float64, opts)
    try
        return MAGEMin_C.O18_prediction(out, δ; melt_model = opts.melt_model, unmapped = Symbol(opts.unmapped), T_max = opts.T_max)
    catch e
        return o18_undefined(out, sprint(showerror, e))
    end
end

"""
    o18_groups(o)

    Oxygen fractions and δ18O of the solid, melt and fluid parts of a δ18O result.

    Returns
    -------
    (N_S, δ_S, N_M, δ_M, N_F, δ_F) : NTuple{6,Float64}
        Oxygen fractions (summing to 1) and oxygen-weighted δ18O of each part (0 for an absent part).
"""
function o18_groups(o::MAGEMin_C.out_O18)
    N = zeros(3)
    D = zeros(3)
    for i in eachindex(o.ph)
        (o.f_O[i] > 0.0 && isfinite(o.δ_ph[i])) || continue
        g     = o.ph[i] == "liq" ? 2 : (o.ph[i] in MAGEMin_C._O18_fluid_names ? 3 : 1)
        N[g] += o.f_O[i]
        D[g] += o.f_O[i] * o.δ_ph[i]
    end
    δ = [N[g] > 0.0 ? D[g] / N[g] : 0.0 for g in 1:3]
    return N[1], δ[1], N[2], δ[2], N[3], δ[3]
end

"""
    o18_extract_step(o, extract, keep_S, keep_M)

    Oxygen isotope bookkeeping of one PTX extraction step (fractional melting / crystallization): the extracted
    solid `(1 - keep_S)`, melt `(1 - keep_M)` and the whole fluid leave with their own δ18O.

    Returns
    -------
    N_ret, δ_ret : Float64
        Oxygen fraction and δ18O of the material carried to the next step.
    N_out, δ_out : Float64
        Oxygen fraction and δ18O of the extracted material.
"""
function o18_extract_step(o::MAGEMin_C.out_O18, extract::Bool, keep_S::Float64, keep_M::Float64)
    isfinite(o.δ_sys) || return 1.0, NaN, 0.0, NaN
    extract || return 1.0, o.δ_sys, 0.0, NaN
    N_S, δ_S, N_M, δ_M, N_F, δ_F = o18_groups(o)
    N_ret = keep_S * N_S + keep_M * N_M
    N_out = (1.0 - keep_S) * N_S + (1.0 - keep_M) * N_M + N_F
    δ_ret = N_ret > 0.0 ? (keep_S * N_S * δ_S + keep_M * N_M * δ_M) / N_ret : o.δ_sys
    δ_out = N_out > 0.0 ? ((1.0 - keep_S) * N_S * δ_S + (1.0 - keep_M) * N_M * δ_M + N_F * δ_F) / N_out : NaN
    return N_ret, δ_ret, N_out, δ_out
end

"""
    o18_remove_phase(o, idx, frac, N_ret, δ_ret, N_out, δ_out)

    Remove the fraction `frac` of the phases `idx` of a δ18O result (per-phase extraction threshold) from the
    retained material and add it to the extracted material.
"""
function o18_remove_phase(o::MAGEMin_C.out_O18, idx, frac::Float64, N_ret::Float64, δ_ret::Float64, N_out::Float64, δ_out::Float64)
    isfinite(δ_ret) || return N_ret, δ_ret, N_out, δ_out
    ids   = [i for i in idx if o.f_O[i] > 0.0 && isfinite(o.δ_ph[i])]
    isempty(ids) && return N_ret, δ_ret, N_out, δ_out
    dN    = min(frac * sum(o.f_O[ids]), N_ret)
    dN > 0.0 || return N_ret, δ_ret, N_out, δ_out
    δ_ph  = sum(o.f_O[ids] .* o.δ_ph[ids]) / sum(o.f_O[ids])
    N_r   = N_ret - dN
    δ_r   = N_r > 0.0 ? (N_ret * δ_ret - dN * δ_ph) / N_r : δ_ret
    N_o   = N_out + dN
    δ_o   = (N_out > 0.0 && isfinite(δ_out) ? N_out * δ_out : 0.0) + dN * δ_ph
    return N_r, δ_r, N_o, δ_o / N_o
end

"""
    o18_mix_assim(bulk_calc, assim_calc, w, δ, δ_ass, oxi, calcUnit)

    δ18O of the PTX system after assimilation of the weight (or mole) fraction `w` of the assimilant, weighted by
    the oxygen of both end-members (`bulk_calc` and `assim_calc` in the `calcUnit` basis of the path).

    Returns
    -------
    δ : Float64
        δ18O of the mixture.
    gain : Float64
        Ratio of the oxygen of the mixture to that of the system before assimilation.
"""
function o18_mix_assim(bulk_calc, assim_calc, w, δ, δ_ass, oxi, calcUnit)
    O(v) = sum(v[j] * get(MAGEMin_C._O18_nu_O, oxi[j], 0.0) / (calcUnit == "wt" ? MAGEMin_C.get_molar_mass(oxi[j]) : 1.0) for j in eachindex(oxi))
    O_c, O_a = (1.0 - w) * O(bulk_calc), w * O(assim_calc)
    (O_c + O_a) > 0.0 || return δ, 1.0
    return (O_c * δ + O_a * δ_ass) / (O_c + O_a), (O_c + O_a) / ((1.0 - w) * O(bulk_calc))
end

"""
    o18_ptx_available()

    True when δ18O results exist for every point of the current PTX path.
"""
function o18_ptx_available()
    isdefined(@__MODULE__, :Out_O18_PTX) && isdefined(@__MODULE__, :Out_PTX) || return false
    return !isempty(Out_O18_PTX) && length(Out_O18_PTX) == length(Out_PTX)
end

"""
    get_o18_ptx_phase_options()

    Options of the δ18O evolution plot: the oxygen-bearing phases of the path and the system, melt, fluid,
    solid and extracted (step and cumulative) values.
"""
function get_o18_ptx_phase_options()
    fixed = [   (label = "system",                  value = "sys"),
                (label = "melt",                    value = "liq_sub"),
                (label = "fluid",                   value = "fl_sub"),
                (label = "solid",                   value = "sol_sub"),
                (label = "extracted (step)",        value = "ext"),
                (label = "extracted (cumulative)",  value = "ext_cum") ]
    return vcat(fixed, [(label = display_ph_name(p), value = p) for p in all_O18_ph_ptx])
end

"""
    get_o18_ptx_series(key)

    δ18O along the PTX path for one option of [`get_o18_ptx_phase_options`](@ref), NaN where undefined.
"""
function get_o18_ptx_series(key::String)
    n = length(Out_O18_PTX)
    key == "sys"     && return [o.δ_sys for o in Out_O18_PTX]
    key == "liq_sub" && return [o.δ_liq for o in Out_O18_PTX]
    key == "fl_sub"  && return [o.δ_fl  for o in Out_O18_PTX]
    key == "sol_sub" && return [o.δ_sol for o in Out_O18_PTX]
    if key == "ext" || key == "ext_cum"
        v = fill(NaN, n)
        N, D = 0.0, 0.0
        for k in 1:n
            dN, δ = O18_ext_PTX[k]
            if dN > 0.0 && isfinite(δ)
                N += dN
                D += dN * δ
                v[k] = key == "ext" ? δ : D / N
            elseif key == "ext_cum" && N > 0.0
                v[k] = D / N
            end
        end
        return v
    end
    return [(i = findfirst(==(key), o.ph); isnothing(i) || o.f_O[i] <= 0.0 ? NaN : o.δ_ph[i]) for o in Out_O18_PTX]
end

"""
    get_o18_ptx_evolution_plot(keys)

    δ18O of the selected phases and subsystems along the PTX path (x: path step, hover: P-T).
"""
function get_o18_ptx_evolution_plot(keys)
    n       = length(Out_O18_PTX)
    steps   = collect(1:n)
    hover   = ["P = $(round(display_pressure(Out_PTX[k].P_kbar), digits = 3)) $(pressure_unit_label()), T = $(round(Out_PTX[k].T_C, digits = 1)) °C" for k in 1:n]
    labels  = Dict(String(o.value) => o.label for o in get_o18_ptx_phase_options())
    data    = GenericTrace[]
    for key in something(keys, String[])
        key = String(key)
        v   = get_o18_ptx_series(key)
        push!(data, scatter(x = steps, y = [isfinite(x) ? x : nothing for x in v], mode = "lines+markers", name = get(labels, key, key),
                            text = hover, hoverinfo = "y+text+name", marker = attr(size = 4),
                            line = attr(dash = key in ("ext", "ext_cum") ? "dot" : "solid")))
    end
    layout  = Layout(   xaxis_title     = "Path step",
                        yaxis_title     = "δ¹⁸O [‰ VSMOW]",
                        height          = 360,
                        plot_bgcolor    = "#FFF",
                        paper_bgcolor   = "#FFF",
                        margin          = attr(l = 70, r = 20, t = 20, b = 50),
                        xaxis           = attr(showline = true, linecolor = "black", mirror = true, ticks = "inside", zeroline = false),
                        yaxis           = attr(showline = true, linecolor = "black", mirror = true, ticks = "inside", zeroline = false),
                        legend          = attr(orientation = "h", y = -0.25) )
    return plot(data, layout)
end

"""
    o18_ptx_export_csv(fileout)

    Write the δ18O of every phase at every step of the PTX path to a CSV file, with the system value and the
    δ18O and oxygen fraction of the material extracted at each step.
"""
function o18_ptx_export_csv(fileout::String)
    unit = use_GPa[1] ? "P_GPa" : "P_kbar"
    f(v) = isfinite(v) ? string(round(v, digits = 4)) : ""
    open(fileout, "w") do io
        println(io, "# δ18O [‰ VSMOW] along the PTX path, DBOxygen 2.0.3 (Vho et al., 2019); f_O: fraction of the system oxygen held by the phase")
        println(io, "step,$unit,T_C,phase,d18O,f_O,d18O_system,d18O_melt,d18O_fluid,d18O_solid,d18O_extracted,O_extracted,flags")
        for k in eachindex(Out_O18_PTX)
            o, out  = Out_O18_PTX[k], Out_PTX[k]
            dN, δe  = O18_ext_PTX[k]
            P       = round(display_pressure(out.P_kbar), digits = 6)
            flags   = "\"" * replace(join(o.flags, "; "), "\"" => "'") * "\""
            for i in eachindex(o.ph)
                o.f_O[i] > 0.0 || continue
                println(io, join((k, P, out.T_C, display_ph_name(o.ph[i]), f(o.δ_ph[i]), f(o.f_O[i]), f(o.δ_sys),
                                  f(o.δ_liq), f(o.δ_fl), f(o.δ_sol), f(δe), f(dN), flags), ","))
            end
        end
    end
    println("PTX δ18O table saved in $fileout")
    return fileout
end
