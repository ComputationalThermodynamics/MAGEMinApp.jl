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

"""
    RADIOGENIC_SYSTEMS

    Radiogenic isotope systems followed along PTX paths: element, ratio label, ratios of the other isotopes to the
    reference isotope (from the IUPAC representative isotopic compositions, Berglund & Wieser, 2011; used to weight
    the mixing by the reference isotope), CHUR value for the ε notation (Bouvier et al., 2008; `NaN` when not used)
    and default initial and assimilant ratios.
"""
const RADIOGENIC_SYSTEMS = Dict(
    "Sr" => (element = "Sr", ratio = "⁸⁷Sr/⁸⁶Sr",   others = (0.056551, 8.378599),                                  chur = NaN,      eps = "",    R0 = 0.7030,  R_ass = 0.7150),
    "Nd" => (element = "Nd", ratio = "¹⁴³Nd/¹⁴⁴Nd", others = (1.140978, 0.348475, 0.722288, 0.241869, 0.236911),   chur = 0.512630, eps = "εNd", R0 = 0.51310, R_ass = 0.51200),
    "Hf" => (element = "Hf", ratio = "¹⁷⁶Hf/¹⁷⁷Hf", others = (0.008712, 1.467097, 0.732497, 1.886509),             chur = 0.282785, eps = "εHf", R0 = 0.28320, R_ass = 0.28250),
)

const RADIOGENIC_ORDER = ("Sr", "Nd", "Hf")

"""
    rad_ref_fraction(name, R)

    Atomic fraction of the reference isotope (⁸⁶Sr, ¹⁴⁴Nd, ¹⁷⁷Hf) at radiogenic ratio `R`.
"""
rad_ref_fraction(name::String, R::Float64) = 1.0 / (1.0 + R + sum(RADIOGENIC_SYSTEMS[name].others))

"""
    rad_mix(name, C_sys, C_ass, w, R_sys, R_ass)

    Radiogenic ratio after adding the mass fraction `w` of an assimilant to the system, weighted by the reference
    isotope of each end-member (`C` element concentrations in ppm).
"""
function rad_mix(name::String, C_sys::Float64, C_ass::Float64, w::Float64, R_sys::Float64, R_ass::Float64)
    n_sys = (1.0 - w) * C_sys * rad_ref_fraction(name, R_sys)
    n_ass = w * C_ass * rad_ref_fraction(name, R_ass)
    (n_sys + n_ass) > 0.0 || return R_sys
    return (n_sys * R_sys + n_ass * R_ass) / (n_sys + n_ass)
end

"""
    rad_assimilate!(R, systems, C_sys, C_ass, w)

    Update the ratios `R` (Dict system => ratio) of the radiogenic `systems` for the assimilation of the mass
    fraction `w`, with `C_sys` and `C_ass` the trace-element compositions (ppm) of the system before assimilation and
    of the assimilant.
"""
function rad_assimilate!(R::Dict{String,Float64}, systems, C_sys::Vector{Float64}, C_ass::Vector{Float64}, w::Float64)
    for s in systems
        R[s.name] = rad_mix(s.name, C_sys[s.id], C_ass[s.id], w, R[s.name], s.R_ass)
    end
    return R
end

"""
    rad_epsilon(name, R)

    ε notation of a ratio relative to CHUR (NaN for systems without ε notation).
"""
rad_epsilon(name::String, R::Float64) = (R / RADIOGENIC_SYSTEMS[name].chur - 1.0) * 1e4

"""
    rad_default_table()

    Rows of the PTX radiogenic isotope table (initial and assimilant ratios of each system).
"""
rad_default_table() = [Dict("system" => s, "ratio" => RADIOGENIC_SYSTEMS[s].ratio, "R0" => RADIOGENIC_SYSTEMS[s].R0, "R_ass" => RADIOGENIC_SYSTEMS[s].R_ass) for s in RADIOGENIC_ORDER]

"""
    rad_ptx_options(model, selected, table)

    Radiogenic systems of a PTX path from the PTX tab inputs, `nothing` when the model is off.
"""
function rad_ptx_options(model, selected, table)
    model == "true" || return nothing
    num(v, d) = v isa Real ? Float64(v) : (v isa AbstractString && !isnothing(tryparse(Float64, v)) ? parse(Float64, v) : d)
    rows = Dict(String(get(r, :system, get(r, "system", ""))) => r for r in something(table, []))
    sys  = NamedTuple[]
    for s in RADIOGENIC_ORDER
        s in String.(something(selected, String[])) || continue
        r = get(rows, s, Dict())
        g(k) = get(r, Symbol(k), get(r, k, nothing))
        push!(sys, (name = s, element = RADIOGENIC_SYSTEMS[s].element, R0 = num(g("R0"), RADIOGENIC_SYSTEMS[s].R0), R_ass = num(g("R_ass"), RADIOGENIC_SYSTEMS[s].R_ass)))
    end
    return isempty(sys) ? nothing : sys
end

"""
    rad_ptx_available()

    True when radiogenic isotope results exist for the current PTX path.
"""
function rad_ptx_available()
    isdefined(@__MODULE__, :Rad_PTX) && isdefined(@__MODULE__, :Out_PTX) || return false
    return !isempty(Rad_PTX) && all(length(v) == length(Out_PTX) for v in values(Rad_PTX))
end

"""
    rad_ptx_quantities()

    Quantities available for the radiogenic isotope plots of the current PTX path: ratios, ε values, melt and
    bulk concentrations and their inverse, and δ18O when the δ18O model was active.
"""
function rad_ptx_quantities()
    q = NamedTuple[]
    for s in RADIOGENIC_ORDER
        haskey(Rad_PTX, s) || continue
        S = RADIOGENIC_SYSTEMS[s]
        push!(q, (label = S.ratio, value = "R|$s"))
        isfinite(S.chur) && push!(q, (label = S.eps, value = "E|$s"))
        push!(q, (label = "$s melt [ppm]", value = "Cliq|$s"))
        push!(q, (label = "1/$s melt [1/ppm]", value = "iCliq|$s"))
        push!(q, (label = "$s bulk [ppm]", value = "C0|$s"))
    end
    if o18_ptx_available()
        push!(q, (label = "δ¹⁸O melt [‰]", value = "O|liq"))
        push!(q, (label = "δ¹⁸O system [‰]", value = "O|sys"))
    end
    push!(q, (label = "Path step", value = "step"))
    push!(q, (label = "Temperature [°C]", value = "T"))
    return q
end

"""
    rad_ptx_series(key)

    Values of a quantity of [`rad_ptx_quantities`](@ref) along the PTX path, NaN where undefined.
"""
function rad_ptx_series(key::String)
    n = length(Out_PTX)
    key == "step" && return Float64.(1:n)
    key == "T"    && return [o.T_C for o in Out_PTX]
    kind, s = split(key, '|')
    s = String(s)
    if kind == "R"
        return Rad_PTX[s]
    elseif kind == "E"
        return [rad_epsilon(s, R) for R in Rad_PTX[s]]
    elseif kind in ("Cliq", "iCliq", "C0")
        te_ok = isdefined(@__MODULE__, :Out_TE_PTX) && length(Out_TE_PTX) == n
        te_ok || return fill(NaN, n)
        v = Float64[]
        for te in Out_TE_PTX
            j = te.elements isa Vector ? findfirst(==(s), te.elements) : nothing
            c = isnothing(j) ? NaN : (kind == "C0" ? te.C0[j] : te.Cliq[j])
            push!(v, kind == "iCliq" ? (c > 0.0 ? 1.0 / c : NaN) : c)
        end
        return v
    elseif kind == "O"
        o18_ptx_available() || return fill(NaN, n)
        return s == "liq" ? [o.δ_liq for o in Out_O18_PTX] : [o.δ_sys for o in Out_O18_PTX]
    end
    return fill(NaN, n)
end

rad_ptx_label(key::String) = something(get(Dict(String(q.value) => q.label for q in rad_ptx_quantities()), key, nothing), key)

"""
    get_rad_ptx_plot(xkey, ykeys)

    Radiogenic isotope plot of the PTX path: the quantities `ykeys` against `xkey`, the path step in the hover.
"""
function get_rad_ptx_plot(xkey, ykeys)
    x       = rad_ptx_series(String(xkey))
    n       = length(x)
    hover   = ["step $k, P = $(round(display_pressure(Out_PTX[k].P_kbar), digits = 3)) $(pressure_unit_label()), T = $(round(Out_PTX[k].T_C, digits = 1)) °C" for k in 1:n]
    fin(v)  = [isfinite(a) ? a : nothing for a in v]
    data    = GenericTrace[]
    for yk in something(ykeys, String[])
        y = rad_ptx_series(String(yk))
        push!(data, scatter(x = fin(x), y = fin(y), mode = "lines+markers", name = rad_ptx_label(String(yk)),
                            text = hover, hoverinfo = "x+y+text", marker = attr(size = 5)))
        push!(data, scatter(x = fin(x[1:1]), y = fin(y[1:1]), mode = "markers", showlegend = false, hoverinfo = "skip",
                            marker = attr(size = 10, symbol = "star", color = "black")))
    end
    ytitle  = length(something(ykeys, [])) == 1 ? rad_ptx_label(String(ykeys[1])) : ""
    layout  = Layout(   xaxis_title     = rad_ptx_label(String(xkey)),
                        yaxis_title     = ytitle,
                        height          = 380,
                        plot_bgcolor    = "#FFF",
                        paper_bgcolor   = "#FFF",
                        margin          = attr(l = 80, r = 20, t = 20, b = 50),
                        xaxis           = attr(showline = true, linecolor = "black", mirror = true, ticks = "inside", zeroline = false, exponentformat = "none"),
                        yaxis           = attr(showline = true, linecolor = "black", mirror = true, ticks = "inside", zeroline = false, exponentformat = "none"),
                        legend          = attr(orientation = "h", y = -0.25) )
    return plot(data, layout)
end

"""
    rad_ptx_export_csv(fileout)

    Write the radiogenic ratios (and ε values), the melt and bulk concentrations and, when available, δ18O of the
    melt and system at every step of the PTX path to a CSV file.
"""
function rad_ptx_export_csv(fileout::String)
    unit  = use_GPa[1] ? "P_GPa" : "P_kbar"
    keys  = [String(q.value) for q in rad_ptx_quantities() if !(q.value in ("step", "T"))]
    cols  = [rad_ptx_series(k) for k in keys]
    f(v)  = isfinite(v) ? string(round(v, sigdigits = 8)) : ""
    names = [replace(rad_ptx_label(k), "," => ";") for k in keys]
    open(fileout, "w") do io
        println(io, "# radiogenic isotopes along the PTX path: no mass-dependent fractionation, assimilation mixing weighted by the reference isotope; ε relative to CHUR (Bouvier et al., 2008)")
        println(io, join(vcat(["step", unit, "T_C"], names), ","))
        for k in eachindex(Out_PTX)
            P = round(display_pressure(Out_PTX[k].P_kbar), digits = 6)
            println(io, join(vcat([string(k), string(P), string(Out_PTX[k].T_C)], [f(c[k]) for c in cols]), ","))
        end
    end
    println("PTX radiogenic isotope table saved in $fileout")
    return fileout
end
