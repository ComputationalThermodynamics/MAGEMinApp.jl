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
    Retrieve layout for rare earth elements figure
"""
function get_layout_ree(norm        :: String,
                        show_type   :: String,
                        kds_db      :: String)

    if kds_db == "OL" || kds_db == "CO" || kds_db == "Yak25"
        if show_type == "ree"
            xaxis_title = "Rare Earth Elements"
        elseif show_type == "all"
            xaxis_title = "Trace Elements"
        end
        yaxis_title = "C"*show_type*"/"*norm*" log10[μg/g]"
    else#if kds_db == "EODC"
        xaxis_title = "Trace Elements"
        yaxis_title = "Cte log10[μg/g]"
    end

    layout_ree      =  Layout(
        font        = attr(size = 10),
        height      = 240,
        margin      = attr(autoexpand = false, l=12, r=12, b=8, t=32),
        autosize    = false,
        xaxis_title = xaxis_title,
        yaxis_title = yaxis_title,
        yaxis_type  = "log",
        showlegend  = true,
        dragmode    = false,

        xaxis       = attr(     fixedrange    = true,
                            ),
        yaxis       = attr(     fixedrange    = true,
                            ),
    )

    return layout_ree
end


function get_data_ree_plot(point_id_te, norm, show_type, kds_db)

    ree             = ["La", "Ce", "Pr", "Nd", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"]
    te_chondrite    = ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc", "Cs", "K", "Ti"]
    ppm_chondrite   = [2.3, 2.41,0.029,0.0074,0.24,0.0136,0.237,0.613,2.47,0.0928,7.25,0.457,3.82,0.103,0.148,0.0563,0.199,0.0361,0.246,1.57,0.0546,0.160,0.0247,0.161,0.0246,56,5.92,0.188,558.0,436.0]

    if kds_db == "OL" || kds_db == "CO" || kds_db == "Yak25"
        if show_type == "ree"
            mask    = [!isnothing(findfirst(isequal(x), Out_TE_XY[point_id_te].elements)) for x in ree]
            te      = ree[mask]
            te_idx  = [findfirst(isequal(x), Out_TE_XY[point_id_te].elements) for x in te]
        elseif show_type == "all"
            mask    = [!isnothing(findfirst(isequal(x), Out_TE_XY[point_id_te].elements)) for x in te_chondrite]
            te      = te_chondrite[mask]
            te_idx  = [findfirst(isequal(x), Out_TE_XY[point_id_te].elements) for x in te]
        end
    else#if kds_db == "EODC"
        te      = Out_TE_XY[point_id_te].elements
        te_idx  = [1:length(te);]
    end


    n_ree   = length(te_idx)

    Cph, C0, Csol, Cliq = 0,0,0,0
    n_traces = 0
    if ~isnothing(Out_TE_XY[point_id_te].ph_TE)
        n_ph_TE = length(Out_TE_XY[point_id_te].ph_TE)
        n_traces += n_ph_TE
        Cph    = 1
    end  

    # if ~isnothing(Out_TE_XY[point_id_te].C0)
    if all(!isnan, Out_TE_XY[point_id_te].C0)
        n_traces += 1
        C0    = 1
    end  
    # if ~isnothing(Out_TE_XY[point_id_te].Cliq)
    if all(!isnan, Out_TE_XY[point_id_te].Cliq)
        n_traces += 1
        Cliq  = 1
    end
    # if ~isnothing(Out_TE_XY[point_id_te].Csol)
    if all(!isnan, Out_TE_XY[point_id_te].Csol)
        n_traces += 1
        Csol  = 1
    end

    data_ree_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_traces);
    names           = Vector{Union{String,Missing}}(undef, n_traces)
    compo_matrix    = Matrix{Union{Float64,Missing}}(undef, n_traces, n_ree) .= missing
    colormap        = get_lines_colormap()

    # te_idx   = [findfirst(isequal(x), Out_TE_XY[point_id_te].elements) for x in ree];
    k = 1
    if kds_db == "OL" || kds_db == "CO" || kds_db == "Yak25"
        chon_idx = [findfirst(isequal(x), te_chondrite) for x in te]
        if show_type == "ree"
            if norm == "chondrite"
                C_norm = copy(ppm_chondrite[chon_idx])
            elseif norm == "bulk"
                C_norm = copy(Out_TE_XY[point_id_te].C0[te_idx])
            end
        elseif show_type == "all"
            if norm == "chondrite"
                C_norm = copy(ppm_chondrite[chon_idx])
            elseif norm == "bulk"
                C_norm = copy(Out_TE_XY[point_id_te].C0[te_idx])
            end
        end
    else#if kds_db == "EODC"
        C_norm = 1;
    end


    if Cph == 1
        for i=1:n_ph_TE
            names[i]            = display_ph_name(Out_TE_XY[point_id_te].ph_TE[i])
            compo_matrix[i,:]   = Out_TE_XY[point_id_te].Cmin[i,te_idx]

            data_ree_plot[k] =  scatter(;   x           = te,
                                            y           = compo_matrix[k,:]./C_norm,
                                            name        = names[k],
                                            mode        = "markers+lines",
                                            marker      = attr(     size    = 4.0,
                                                                    color   = colormap[k]),

                                            line        = attr(     width   = 1.0,
                                                                    color   = colormap[k])  )

            k += 1
        end
    end

    if C0 == 1
        names[k]            = "C0"
        compo_matrix[k,:]   = Out_TE_XY[point_id_te].C0[te_idx]

        data_ree_plot[k] =  scatter(;   x           = te,
                                        y           = compo_matrix[k,:]./C_norm,
                                        name        = names[k],
                                        mode        = "lines",
                                        line        = attr( dash    = "dash",
                                                            color   = "black", 
                                                            width   = 2.0)                ) 

        k += 1
    end
    if Cliq == 1
        names[k]            = "Cliq"
        compo_matrix[k,:]   = Out_TE_XY[point_id_te].Cliq[te_idx]

        data_ree_plot[k] =  scatter(;   x           = te,
                                        y           = compo_matrix[k,:]./C_norm,
                                        name        = names[k],
                                        mode        = "markers+lines",

                                        marker          = attr(     size    = 6.0,
                                                                    color   = "RGB(176,0,0)"),
                                        line            = attr( color   = "RGB(176,0,0)", 
                                                                width   = 2.0)                ) 

        k += 1
    end
    if Csol == 1
        names[k]            = "Csol"
        compo_matrix[k,:]   = Out_TE_XY[point_id_te].Csol[te_idx]

        data_ree_plot[k] =  scatter(;   x           = te,
                                        y           = compo_matrix[k,:]./C_norm,
                                        name        = names[k],
                                        mode        = "markers+lines",

                                        marker          = attr(     size    = 6.0,
                                                                    color   = "black"),
                                        line            = attr( color   = "black", 
                                                                width   = 2.0)                ) 

        k += 1
    end


    return data_ree_plot
end

const TE_FIELD_TYPES = [    (label = "Formula",         value = "te"     ),
                            (label = "Zircon",          value = "zrc"    ),
                            (label = "Sulfide",         value = "sulf"   ),
                            (label = "Fluorapatite",    value = "fapt"   ),
                            (label = "CO2 saturation",  value = "co2sat" ),
                            (label = "Monazite",        value = "mnz"    ) ]

const TE_ACCESSORY_FIELDS = Dict(   "zrc"    => ["Sat_Zr_liq",   "zrc_wt"   ],
                                    "sulf"   => ["Sat_S_liq",    "sulf_wt"  ],
                                    "fapt"   => ["Sat_P2O5_liq", "fapt_wt"  ],
                                    "co2sat" => ["Sat_CO2_liq",  "fl_CO2_wt"],
                                    "mnz"    => ["Sat_LREE_liq", "mnz_wt"   ] )

const TE_DEFAULT_FORMULA = "[M_Dy] / [M_Yb]"

function te_available()
    isdefined(@__MODULE__, :Out_TE_XY) && isdefined(@__MODULE__, :Out_XY) || return false
    return Out_TE_XY isa AbstractVector && !isempty(Out_TE_XY) && length(Out_TE_XY) == length(Out_XY)
end

is_te_field(fieldname) = fieldname isa AbstractString && startswith(fieldname, "te:")

te_field_key(type, name, norm) = "te:" * String(type) * "|" * String(norm) * "|" * String(name)

function te_field_parts(fieldname::AbstractString)
    parts = split(chop(fieldname, head = 3, tail = 0), '|'; limit = 3)
    length(parts) == 3 || return ("te", "none", "")
    return (String(parts[1]), String(parts[2]), String(parts[3]))
end

function te_main_fieldname(field, type, name, formula, norm)
    field == "te" || return field
    type = String(something(type, "te"))
    if type == "te"
        f = strip(String(something(formula, "")))
        return te_field_key("te", isempty(f) ? TE_DEFAULT_FORMULA : f, String(something(norm, "none")))
    end
    names = get(TE_ACCESSORY_FIELDS, type, String[])
    name  = name isa AbstractString && name in names ? String(name) : (isempty(names) ? "" : names[1])
    return te_field_key(type, name, "none")
end

function te_field_label(fieldname::AbstractString)
    type, norm, name = te_field_parts(fieldname)
    type == "te" || return name
    return norm == "none" ? name : name * " (" * norm * ")"
end

function te_field_column(fieldname::AbstractString)
    type, norm, name = te_field_parts(fieldname)
    np    = length(Out_TE_XY)
    field = Vector{Union{Float64,Missing,Nothing}}(undef, np)
    if type == "te"
        f = compile_te_formula(name)
        for i = 1:np
            field[i] = eval_te_formula(f, Out_TE_XY[i], norm)
        end
    else
        for i = 1:np
            field[i] = get_property(Out_TE_XY[i], name)
        end
    end
    field[isnan.(field)] .= 0.0
    return field
end

function te_field_color_range(fieldname::AbstractString, gridded)
    type, norm, name = te_field_parts(fieldname)
    return type == "te" ? te_color_range("te", "", name, norm, gridded) : te_color_range(type, name, "", "none", gridded)
end

function te_isopleth_grid(fieldname::AbstractString, oxi, sub, refLvl, data, Xrange, Yrange)
    type, norm, name = te_field_parts(fieldname)
    mod = type == "te" ? "calc" : type
    return get_isopleth_map_te( mod, type, name, name, norm, oxi, Out_TE_XY, sub, refLvl, data, Xrange, Yrange;
                                absent = NaN, defined_only = true )
end

function te_phase_list()
    te_available() && isdefined(@__MODULE__, :all_TE_ph) || return ""
    return "**C0 M S " * join(display_ph_names(to_str_vec(all_TE_ph)), " ") * "**"
end

function te_selector(suffix::String)
    w = suffix == "-pd" ? 5 : 6
    title(t) = html_h1(t, style = Dict("textAlign" => "center", "font-size" => "120%", "marginTop" => 8))
    row(t, content) = dbc_row([dbc_col([title(t)], width = w), dbc_col([content])])
    formula_rows = Any[
        dbc_row([dbc_card([dcc_markdown(id = "te-phases" * suffix, children = "", style = Dict("white-space" => "pre"))])]),
        row("Formula",       dbc_input(id = "te-formula" * suffix, type = "text", value = TE_DEFAULT_FORMULA, debounce = true)),
        row("Normalization", dcc_dropdown(id = "te-norm" * suffix, options = ["none", "bulk", "chondrite"], value = "none", clearable = false, multi = false)),
    ]
    if suffix == "-pd"
        push!(formula_rows, dbc_row([dbc_button("Display", id = "te-display-pd", color = "light", className = "me-2", n_clicks = 0,
                                                style = Dict("textAlign" => "center", "font-size" => "100%", "border" => "1px grey solid"))]))
    else
        push!(formula_rows, row("Custom name", dbc_input(id = "te-cust" * suffix, type = "text", value = "none")))
    end
    return [
        row("Type", dcc_dropdown(id = "te-type" * suffix, options = TE_FIELD_TYPES, value = "te", clearable = false, multi = false)),
        html_div([row("Field", dcc_dropdown(id = "te-name" * suffix, options = [], value = nothing, clearable = false, multi = false))],
                 style = Dict("display" => "none"), id = "te-name-row" * suffix),
        html_div(formula_rows, style = Dict("display" => "block"), id = "te-formula-row" * suffix),
    ]
end

function te_selector_state(type)
    vis(b) = Dict("display" => b ? "block" : "none")
    names  = get(TE_ACCESSORY_FIELDS, String(something(type, "te")), String[])
    opts   = [Dict("label" => n, "value" => n) for n in names]
    return vis(!isempty(names)), vis(isempty(names)), opts, isempty(names) ? nothing : names[1]
end

function te_spectrum_figure(point_id::Int, norm::String, show_type::String, kds_db::String)
    layout = get_layout_ree(norm, show_type, kds_db)
    layout[:height]        = 340
    layout[:autosize]      = true
    layout[:margin]        = attr(autoexpand = true, l = 50, r = 10, b = 40, t = 10)
    layout[:font]          = attr(size = 10)
    layout[:legend]        = attr(orientation = "h", x = 0.0, xanchor = "left", y = -0.25, yanchor = "top", font = attr(size = 9))
    layout[:plot_bgcolor]  = "#FFF"
    layout[:paper_bgcolor] = "#FFF"
    layout[:xaxis]         = attr(fixedrange = true, tickangle = show_type == "all" ? -60 : 0, dtick = 1, tickfont = attr(size = show_type == "all" ? 8 : 10),
                                  showline = true, linecolor = "black", mirror = true, ticks = "inside")
    layout[:yaxis]         = attr(fixedrange = true, type = "log", showline = true, linecolor = "black", mirror = true, ticks = "inside")
    return plot(get_data_ree_plot(point_id, norm, show_type, kds_db), layout)
end

function te_bib_infos(kds, zrsat, ssat, P2O5sat, mnzsat)
    te_available() || return String[]
    return String[string(x) for x in (zrsat, ssat, P2O5sat, mnzsat, kds) if x !== nothing && string(x) != "none"]
end

function te_export_csv(points, dtb, fileout)
    te_available() || return false
    out    = points === nothing ? Out_XY : Out_XY[points]
    out_te = points === nothing ? Out_TE_XY : Out_TE_XY[points]
    MAGEMin_dataTE2dataframe(out, out_te, dtb, fileout * "_TE"; use_Warr2021 = use_warr_names[1], use_GPA = use_GPa[1])
    return true
end

function te_type_available(type::String)
    type == "te" && return true
    te_available() || return false
    names = get(TE_ACCESSORY_FIELDS, type, String[])
    for te in Out_TE_XY, n in names
        v = get_property(te, n)
        v isa Real && isfinite(v) && v != 0 && return true
    end
    return false
end

te_type_options() = [o for o in TE_FIELD_TYPES if te_type_available(o.value)]
