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

rad_num(v, d) = v isa Real ? Float64(v) : (v isa AbstractString && !isnothing(tryparse(Float64, v)) ? parse(Float64, v) : d)

function rad_options(model, selected, r1, r2)
    model == "true" || return nothing
    sel = String.(something(selected, String[]))
    r1  = something(r1, fill(nothing, length(RADIOGENIC_ORDER)))
    r2  = something(r2, fill(nothing, length(RADIOGENIC_ORDER)))
    sys = NamedTuple[]
    for (k, s) in enumerate(RADIOGENIC_ORDER)
        s in sel || continue
        push!(sys, (name = s, element = RADIOGENIC_SYSTEMS[s].element,
                    R0 = rad_num(r1[k], RADIOGENIC_SYSTEMS[s].R0), R_ass = rad_num(r2[k], RADIOGENIC_SYSTEMS[s].R_ass)))
    end
    return isempty(sys) ? nothing : sys
end

rad_ptx_options(model, selected, r1, r2) = rad_options(model, selected, r1, r2)

const RAD_KDS_ELEMENTS = Dict{String,Vector{String}}()

function rad_kds_elements(kds_mod)
    kds_mod isa AbstractString && !isempty(kds_mod) || return String[]
    return get!(RAD_KDS_ELEMENTS, String(kds_mod)) do
        try
            String.(build_kds_database(String(kds_mod)).element_name)
        catch
            String[]
        end
    end
end

function rad_te_gate(te_model, kds_mod, dtb)
    te_on = te_model == "true" && !(dtb in ("um", "ume", "mtl", "po"))
    els   = te_on ? rad_kds_elements(kds_mod) : String[]
    opts  = [Dict("label" => " " * RADIOGENIC_SYSTEMS[s].ratio * (te_on && !(RADIOGENIC_SYSTEMS[s].element in els) ? " (not in $(kds_mod))" : ""),
                  "value" => s, "disabled" => !(te_on && RADIOGENIC_SYSTEMS[s].element in els)) for s in RADIOGENIC_ORDER]
    note  = te_on ? "" : "Requires the trace-element model (TE predictive model = true, with a Kd database containing Sr, Nd or Hf)."
    return te_on, opts, note
end

function rad_ratio_rows(suffix::String, which::String; label_suffix::String = "")
    rows = []
    for s in RADIOGENIC_ORDER
        S  = RADIOGENIC_SYSTEMS[s]
        id = "rad-$(which)-$(s)$(suffix)"
        push!(rows, html_div([
            html_div("‎ "),
            dbc_row([
                dbc_col([
                    html_h1(S.ratio * label_suffix, style = Dict("textAlign" => "center","font-size" => "120%")),
                ]),
                dbc_col([
                    dbc_input(id = id, type = "number", step = "any", value = which == "r0" ? S.R0 : S.R_ass),
                ]),
            ]),
        ], style = Dict("display" => "none"), id = id * "-row"))
    end
    return rows
end

function rad_usable_systems(selected, te_model, kds_mod, dtb)
    te_on, opts, _ = rad_te_gate(te_model, kds_mod, dtb)
    te_on || return String[]
    ok = [o["value"] for o in opts if !o["disabled"]]
    return [String(v) for v in something(selected, String[]) if String(v) in ok]
end

rad_row_styles(model, selected) = [Dict("display" => (model == "true" && s in String.(something(selected, String[]))) ? "block" : "none") for s in RADIOGENIC_ORDER]

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

function rad_ptx_default_axes()
    haskey(Rad_PTX, "Sr") && haskey(Rad_PTX, "Nd") && return "R|Sr", ["E|Nd"]
    haskey(Rad_PTX, "Sr") && o18_ptx_available()   && return "R|Sr", ["O|liq"]
    return "step", ["R|$s" for s in RADIOGENIC_ORDER if haskey(Rad_PTX, s)]
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
