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

const _leake_amp_warr = Dict(
    "Tremolite"             => "Tr",
    "Actinolite"            => "Act",
    "Ferro-actinolite"      => "Fact",
    "Magnesio-hornblende"   => "Mhbl",
    "Ferro-hornblende"      => "Fhbl",
    "Tschermakite"          => "Ts",
    "Ferro-tschermakite"    => "Fts",
    "Edenite"               => "Ed",
    "Ferro-edenite"         => "Fed",
    "Pargasite"             => "Prg",
    "Ferro-pargasite"       => "Fprg",
    "Magnesio-hastingsite"  => "Mhs",
    "Hastingsite"           => "Hs",
    "Sadanagaite"           => "Sdg",
    "Magnesio-sadanagaite"  => "Msdg",
    "Kaersutite"            => "Krs",
    "Ferro-kaersutite"      => "Fkrs",
)

"""
    ca_amp_label(name)

    Return the display label for a Ca-amphibole species name, honoring the
    global Legacy/Warr(2021) toggle (`use_warr_names[1]`, `appData.jl`).
"""
function ca_amp_label(name::String)
    isempty(name) && return name
    use_warr_names[1] && return get(_leake_amp_warr, name, name)
    return name
end

function ca_amp_label_join(names::Vector{String})
    return join(ca_amp_label.(names), " / ")
end

"""
    amphibole_cations_23O(wt)

    Recalculate an amphibole oxide-wt% composition to cations on the standard
    "23 oxygens, 2 OH" formula-unit basis (see `oxide_cations`,
    `Mineral_recalc_functions.jl`).
"""
function amphibole_cations_23O(wt::Dict{String,Float64})
    return oxide_cations(wt, 23.0)
end

"""
    amphibole_site_allocation(cat)

    Distribute a 22-oxygen-normalized cation set onto the standard amphibole
    sites T(8)-C(5)-B(2)-A(0-1), following the filling order of Leake et al.
    (1997): T = Si, then Al up to 8; C = remaining Al, Ti, Cr, Fe3+, then
    Mg-Fe2+-Mn up to 5; B = remaining Mg-Fe2+-Mn, then Ca, then Na up to 2;
    A = remaining Na, plus K.

    Mg/(Mg+Fe2+) is the bulk formula ratio (not site-restricted), matching
    Leake's diagram axis definition.
"""
function amphibole_site_allocation(cat::Dict{Symbol,Float64})

    Si   = cat[:Si]
    AlIV = min(cat[:Al], max(0.0, 8.0 - Si))
    AlVI = cat[:Al] - AlIV

    C_hfs     = AlVI + cat[:Ti] + cat[:Cr] + cat[:Fe3]
    C_remain  = max(0.0, 5.0 - C_hfs)

    mgfemn_total = cat[:Mg] + cat[:Fe2] + cat[:Mn]
    C_mgfemn     = min(mgfemn_total, C_remain)
    share        = mgfemn_total > 0.0 ? C_mgfemn / mgfemn_total : 0.0

    Mg_res  = cat[:Mg]  * (1.0 - share)
    Fe2_res = cat[:Fe2] * (1.0 - share)
    Mn_res  = cat[:Mn]  * (1.0 - share)
    B_mgfemn = Mg_res + Fe2_res + Mn_res

    B_remain = max(0.0, 2.0 - B_mgfemn)
    Ca_B     = min(cat[:Ca], B_remain)
    B_remain2 = max(0.0, B_remain - Ca_B)
    Na_B     = min(cat[:Na], B_remain2)

    Na_A = cat[:Na] - Na_B
    K_A  = cat[:K]

    MgNum = (cat[:Mg] + cat[:Fe2]) > 0.0 ? cat[:Mg] / (cat[:Mg] + cat[:Fe2]) : missing

    return (
        Si    = Si,
        AlIV  = AlIV,
        AlVI  = AlVI,
        Ti    = cat[:Ti],
        Fe3   = cat[:Fe3],
        MgNum = MgNum,
        NaK_A = Na_A + K_A,
        Ca_B  = Ca_B,
        Na_B  = Na_B,
    )
end

"""
    classify_ca_amphibole(f)

    Assign a Leake et al. (1997) Ca-amphibole species name and target diagram
    panel (:A, :B or :C) from a site-allocation NamedTuple. Returns
    `(:none, "")` for compositions outside the calcic-amphibole group
    ((Ca+Na)_B < 1.34 or Na_B >= 0.67) or outside all three panels' domains.

    The pargasite/hastingsite distinction within Panel B uses Leake's
    Al(VI)+Fe3++2Ti vs Al(IV)-(Na+K)_A criterion; the sadanagaite/
    magnesio-sadanagaite fields use his Al(IV) >= 1.75 criterion.
"""
function classify_ca_amphibole(f)

    ismissing(f.MgNum) && return (:none, "")
    (f.Ca_B + f.Na_B) < 1.34 && return (:none, "")
    f.Na_B >= 0.67          && return (:none, "")

    mg = f.MgNum
    si = f.Si

    if f.NaK_A < 0.50
        if si >= 7.50
            name = mg >= 0.90 ? "Tremolite" : mg >= 0.50 ? "Actinolite" : "Ferro-actinolite"
        elseif si >= 6.50
            name = mg >= 0.50 ? "Magnesio-hornblende" : "Ferro-hornblende"
        else
            name = mg >= 0.50 ? "Tschermakite" : "Ferro-tschermakite"
        end
        return (:A, name)
    end

    if f.Ti >= 0.50 && f.Ca_B >= 1.50
        name = mg >= 0.50 ? "Kaersutite" : "Ferro-kaersutite"
        return (:C, name)
    end

    f.Ti >= 0.50 && return (:none, "")

    if si >= 6.50
        name = mg >= 0.50 ? "Edenite" : "Ferro-edenite"
    elseif f.AlIV >= 1.75
        name = mg >= 0.50 ? "Magnesio-sadanagaite" : "Sadanagaite"
    else
        hastingsitic = (f.AlVI + f.Fe3 + 2.0*f.Ti) >= (f.AlIV - f.NaK_A)
        if hastingsitic
            name = mg >= 0.50 ? "Magnesio-hastingsite" : "Hastingsite"
        else
            name = mg >= 0.50 ? "Pargasite" : "Ferro-pargasite"
        end
    end
    return (:B, name)
end

const _amp_phase_names = ["gl", "act", "cumm", "tr", "amp"]

"""
    compute_ca_amp_points()

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the amphibole phase composition where stable, and return
    per-point panel routing, plot coordinates, display label, pressure (for
    marker color) and phase wt fraction (for marker size).

    MAGEMin's own coarse solvus disambiguation (`get_mineral_name` in
    MAGEMin_C, applied before results ever reach the app) already splits the
    single `amp` solution model into `"gl"/"act"/"cumm"/"tr"/"amp"` in
    `Out_XY[i].ph` itself — the raw `"amp"`/`"amp_G16"` solution-phase short
    names never survive to `.ph`. All five buckets must be matched here so
    every amphibole point reaches this module's own, finer Leake et al.
    (1997) classification (computed independently from the recalculated
    structural formula, not from MAGEMin's coarse bucket).
"""
function compute_ca_amp_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    panel = fill(:none, n_tot)
    si_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    mg_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    label = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_amp_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = amphibole_cations_23O(wt)
        isnothing(cat) && continue

        f          = amphibole_site_allocation(cat)
        pnl, name  = classify_ca_amphibole(f)
        pnl == :none && continue

        panel[j] = pnl
        si_v[j]  = f.Si
        mg_v[j]  = f.MgNum
        label[j] = ca_amp_label(name)
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return panel, si_v, mg_v, label, P_v, wt_v
end

_amp_rect(x0, x1, y0, y1) = [x0 y0; x1 y0; x1 y1; x0 y1; x0 y0]

function _amp_field_traces(fields)
    traces = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, length(fields))
    for i in eachindex(fields)
        box = fields[i][2]
        traces[i] = scatter(   x           = box[:,1],
                                y           = box[:,2],
                                hoverinfo   = "skip",
                                mode        = "lines",
                                showscale   = false,
                                showlegend  = false,
                                line        = attr( color = "black", width = 0.75) )
    end
    return traces
end

function _amp_field_annotations(fields)
    n = length(fields)
    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef, n)
    for i = 1:n
        box   = fields[i][2]
        xc    = sum(box[1:end-1,1]) / (size(box,1)-1.0)
        yc    = sum(box[1:end-1,2]) / (size(box,1)-1.0)
        annotations[i] = attr(  xref      = "x",
                                yref      = "y",
                                x         = xc,
                                y         = yc,
                                text      = fields[i][1],
                                showarrow = false,
                                visible   = true,
                                font      = attr(size = 9, color = "#212121") )
    end
    return annotations
end

function _amp_point_trace(si_v, mg_v, label_v, P_v, wt_v, panel_v, target)

    idx = findall(panel_v .== target)
    n   = length(idx)
    colormap = get_jet_colormap(max(n,1))

    return scatter(     x           = si_v[idx],
                        y           = mg_v[idx],
                        mode        = "markers",
                        opacity     = 0.6,
                        showscale   = false,
                        showlegend  = false,
                        hoverinfo   = "text",
                        hovertext   = label_v[idx],
                        marker      = attr(     size        = wt_v[idx] .*20.0 .+ 2.0,
                                                color       = P_v[idx],
                                                colorscale  = colormap,
                                                line        = attr( width = 0.75, color = "black" )    ) )
end

function _amp_panel_layout(title)
    return Layout(
        title       = attr( text = title, x = 0.5, xanchor = "center", yanchor = "top" ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=40),
        hoverlabel  = attr( bgcolor = "#566573", bordercolor = "#f8f9f9" ),
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "Si (apfu)",
        yaxis_title = "Mg / (Mg + Fe²⁺)",
        xaxis_range = [8.0, 5.5],
        yaxis_range = [0.0, 1.0],
        width       = 640,
        height      = 400,
        xaxis       = attr(fixedrange = true),
        yaxis       = attr(fixedrange = true),
    )
end

"""
    Retrieve Ca-amphibole classification diagram, Leake et al. (1997) Panel A:
    (Na+K)_A < 0.50 — tremolite/actinolite/hornblende/tschermakite series.
"""
function get_CaAmpPanelA_diagram()

    panel_v, si_v, mg_v, label_v, P_v, wt_v = compute_ca_amp_points()

    fields = [
        ("Tremolite",              _amp_rect(8.00, 7.50, 0.90, 1.00)),
        (ca_amp_label("Actinolite"),         _amp_rect(8.00, 7.50, 0.50, 0.90)),
        (ca_amp_label("Ferro-actinolite"),   _amp_rect(8.00, 7.50, 0.00, 0.50)),
        (ca_amp_label("Magnesio-hornblende"),_amp_rect(7.50, 6.50, 0.50, 1.00)),
        (ca_amp_label("Ferro-hornblende"),   _amp_rect(7.50, 6.50, 0.00, 0.50)),
        (ca_amp_label("Tschermakite"),       _amp_rect(6.50, 5.50, 0.50, 1.00)),
        (ca_amp_label("Ferro-tschermakite"), _amp_rect(6.50, 5.50, 0.00, 0.50)),
    ]
    fields[1] = (ca_amp_label("Tremolite"), fields[1][2])

    traces = _amp_field_traces(fields)
    push!(traces, _amp_point_trace(si_v, mg_v, label_v, P_v, wt_v, panel_v, :A))

    layout = _amp_panel_layout("Ca-amphibole [(Na+K)ᴬ < 0.50]")
    layout.fields[:annotations] = _amp_field_annotations(fields)

    return traces, layout
end

"""
    Retrieve Ca-amphibole classification diagram, Leake et al. (1997) Panel B:
    (Na+K)_A >= 0.50, Ti < 0.50 — edenite/pargasite/hastingsite/sadanagaite series.
"""
function get_CaAmpPanelB_diagram()

    panel_v, si_v, mg_v, label_v, P_v, wt_v = compute_ca_amp_points()

    fields = [
        (ca_amp_label("Edenite"),        _amp_rect(8.00, 6.50, 0.50, 1.00)),
        (ca_amp_label("Ferro-edenite"),  _amp_rect(8.00, 6.50, 0.00, 0.50)),
        (ca_amp_label_join(["Pargasite","Magnesio-hastingsite"]), _amp_rect(6.50, 6.25, 0.50, 1.00)),
        (ca_amp_label_join(["Ferro-pargasite","Hastingsite"]),    _amp_rect(6.50, 6.25, 0.00, 0.50)),
        (ca_amp_label("Magnesio-sadanagaite"), _amp_rect(6.25, 5.50, 0.50, 1.00)),
        (ca_amp_label("Sadanagaite"),          _amp_rect(6.25, 5.50, 0.00, 0.50)),
    ]

    traces = _amp_field_traces(fields)
    push!(traces, _amp_point_trace(si_v, mg_v, label_v, P_v, wt_v, panel_v, :B))

    layout = _amp_panel_layout("Ca-amphibole [(Na+K)ᴬ ≥ 0.50, Ti < 0.50]")
    layout.fields[:annotations] = _amp_field_annotations(fields)

    return traces, layout
end

"""
    Retrieve Ca-amphibole classification diagram, Leake et al. (1997) Panel C:
    Ti >= 0.50, Ca_B >= 1.50 — kaersutite/ferro-kaersutite.
"""
function get_CaAmpPanelC_diagram()

    panel_v, si_v, mg_v, label_v, P_v, wt_v = compute_ca_amp_points()

    fields = [
        (ca_amp_label("Kaersutite"),       _amp_rect(8.00, 5.50, 0.50, 1.00)),
        (ca_amp_label("Ferro-kaersutite"), _amp_rect(8.00, 5.50, 0.00, 0.50)),
    ]

    traces = _amp_field_traces(fields)
    push!(traces, _amp_point_trace(si_v, mg_v, label_v, P_v, wt_v, panel_v, :C))

    layout = _amp_panel_layout("Ca-amphibole [Ti ≥ 0.50]")
    layout.fields[:annotations] = _amp_field_annotations(fields)

    return traces, layout
end
