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

const _oxide_warr = Dict(
    "Spinel"           => "Spl",
    "Hercynite"        => "Hc",
    "Chromite"         => "Chr",
    "Magnesiochromite" => "Mchr",
    "Magnetite"        => "Mag",
    "Magnesioferrite"  => "Mfer",
    "Ulvöspinel"       => "Usp",
    "Qandilite"        => "Qan",
    "Ilmenite"         => "Ilm",
    "Hematite"         => "Hem",
    "Geikielite"       => "Gkl",
    "Pyrophanite"      => "Pyp",
)

"""
    oxide_label(name)

    Return the display label for an Fe-Ti oxide species name, honoring the
    global Legacy/Warr(2021) toggle (`use_warr_names[1]`, `appData.jl`).
"""
function oxide_label(name::String)
    isempty(name) && return name
    use_warr_names[1] && return get(_oxide_warr, name, name)
    return name
end

# ---------------------------------------------------------------------------
# Spinel group (AB2O4)
# ---------------------------------------------------------------------------

"""
    spinel_site_allocation(cat)

    Read off the trivalent (Al/Cr/Fe3+), tetravalent (Ti) and divalent
    (Mg/Fe2+/Mn) cation totals from a 4-oxygen-normalized spinel-group
    cation set (AB2O4, 3 cations total — verified by charge-balance identity
    against both normal spinel MgAl2O4 and inverse spinels like magnetite
    Fe2+Fe3+2O4).
"""
function spinel_site_allocation(cat::Dict{Symbol,Float64})
    return (Al = cat[:Al], Cr = cat[:Cr], Fe3 = cat[:Fe3], Ti = cat[:Ti],
             Mg = cat[:Mg], Fe2 = cat[:Fe2], Mn = cat[:Mn])
end

"""
    classify_spinel(f)

    Assign the spinel-group species. The dominant trivalent/tetravalent
    cation sets the series (Ti competes as 2*Ti against Al+Cr+Fe3+, since
    one Ti4+ charge-balances two trivalent-cation-equivalent positions via
    the ulvöspinel-type substitution), and Mg vs Fe2+(+Mn) dominance then
    picks between the paired species names:
    Al: Spinel/Hercynite; Cr: Magnesiochromite/Chromite;
    Fe3+: Magnesioferrite/Magnetite; Ti: Qandilite/Ulvöspinel.
"""
function classify_spinel(f)
    R3 = f.Al + f.Cr + f.Fe3
    mg_dominant = f.Mg >= (f.Fe2 + f.Mn)

    if (2.0 * f.Ti) > R3
        return mg_dominant ? "Qandilite" : "Ulvöspinel"
    end

    R3 <= 0.0 && return ""
    al_f  = f.Al  / R3
    cr_f  = f.Cr  / R3
    fe3_f = f.Fe3 / R3

    if al_f >= cr_f && al_f >= fe3_f
        return mg_dominant ? "Spinel" : "Hercynite"
    elseif cr_f >= al_f && cr_f >= fe3_f
        return mg_dominant ? "Magnesiochromite" : "Chromite"
    else
        return mg_dominant ? "Magnesioferrite" : "Magnetite"
    end
end

const _spinel_phase_names = ["spl", "sp", "smt", "cm", "usp", "mgt"]

"""
    compute_spinel_points()

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the spinel-group phase composition where stable, and return
    per-point Al-Cr-Fe3+ ternary coordinates, display label, pressure (for
    marker color) and phase wt fraction (for marker size).

    MAGEMin's own coarse solvus disambiguation already splits the spinel
    solution models into `"cm"/"usp"/"mgt"/"spl"` (ig-family) or
    `"sp"/"smt"` (mp-family) in `Out_XY[i].ph` itself — all buckets are
    matched here so every spinel-group point reaches this module's own
    classification (computed independently from the recalculated structural
    formula, not from MAGEMin's coarse bucket). Points whose trivalent-cation
    budget is ~0 (rare, near-pure Ti-Fe2+ end-member) have no meaningful
    Al-Cr-Fe3+ ternary position and are skipped from this diagram.
"""
function compute_spinel_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    Al_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Cr_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Fe3_v = Vector{Union{Float64,Missing}}(missing, n_tot)
    label = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_spinel_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = oxide_cations(wt, 4.0)
        isnothing(cat) && continue

        f    = spinel_site_allocation(cat)
        name = classify_spinel(f)
        isempty(name) && continue

        R3 = f.Al + f.Cr + f.Fe3
        R3 <= 0.0 && continue

        Al_v[j]  = 100.0 * f.Al  / R3
        Cr_v[j]  = 100.0 * f.Cr  / R3
        Fe3_v[j] = 100.0 * f.Fe3 / R3
        label[j] = oxide_label(name)
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return Al_v, Cr_v, Fe3_v, label, P_v, wt_v
end

"""
    Retrieve spinel-group classification diagram: Al-Cr-Fe3+ dominant-cation
    ternary (Spinel-series/Chromite-series/Magnetite-series), each point's
    exact species (including the Mg-vs-Fe2+ and Ti-vs-trivalent resolution)
    carried in the hover label.
"""
function get_Spinel_diagram()

    Al_v, Cr_v, Fe3_v, label_v, P_v, wt_v = compute_spinel_points()

    c = 100.0 / 3.0
    traces = GenericTrace{Dict{Symbol, Any}}[
        _mica_ternary_field([c, 50.0], [c, 50.0], [c,  0.0]),
        _mica_ternary_field([c,  0.0], [c, 50.0], [c, 50.0]),
        _mica_ternary_field([c, 50.0], [c,  0.0], [c, 50.0]),
    ]

    n = length(Al_v)
    colormap = get_jet_colormap(max(n,1))
    push!(traces, scatterternary(
        a       = Al_v,
        b       = Cr_v,
        c       = Fe3_v,
        mode    = "markers",
        hoverinfo   = "text",
        hovertext   = label_v,
        opacity     = 0.6,
        marker  = attr(     size        = wt_v .*20.0 .+ 2.0,
                            color       = P_v,
                            colorscale  = colormap,
                            line        = attr( width = 0.75, color = "black" )    ),
        name    = "Sample Points"
    ))

    layout = Layout(
        title= attr(
            text    = "Spinel group",
            x       = 0.2,
            xanchor = "center",
            yanchor = "top"
        ),
        ternary=attr(
            sum     = 100,
            aaxis   = attr(title="Al",  gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            baxis   = attr(title="Cr",  gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            caxis   = attr(title="Fe³⁺",gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            bgcolor = "#FFF",
            width       = 640,
            height      = 400,
        ),
        paper_bgcolor = "#FFF",
    )

    return traces, layout
end

# ---------------------------------------------------------------------------
# Ilmenite-hematite series (ABO3)
# ---------------------------------------------------------------------------

"""
    ilmenite_site_allocation(cat)

    Read off the divalent (Mg/Fe2+/Mn), trivalent (Fe3+) and tetravalent
    (Ti) cation totals from a 3-oxygen-normalized ilmenite-hematite cation
    set (ABO3, 2 cations total — verified by charge-balance identity against
    both ilmenite FeTiO3 and hematite Fe2O3).
"""
function ilmenite_site_allocation(cat::Dict{Symbol,Float64})
    return (Mg = cat[:Mg], Fe2 = cat[:Fe2], Mn = cat[:Mn], Fe3 = cat[:Fe3], Ti = cat[:Ti])
end

"""
    classify_ilmenite(f)

    Assign the ilmenite-hematite series species: Hematite if the Fe2O3
    (hematite) component is >= 50% (Fe3+/2 >= 0.5, since pure hematite has
    Fe3+ = 2 pfu); otherwise the ilmenite-series divalent cation dominance
    picks Ilmenite (Fe2+), Geikielite (Mg) or Pyrophanite (Mn).
"""
function classify_ilmenite(f)
    (f.Fe3 / 2.0) >= 0.5 && return "Hematite"

    tot = f.Mg + f.Fe2 + f.Mn
    tot <= 0.0 && return ""

    if f.Fe2 >= f.Mg && f.Fe2 >= f.Mn
        return "Ilmenite"
    elseif f.Mg >= f.Fe2 && f.Mg >= f.Mn
        return "Geikielite"
    else
        return "Pyrophanite"
    end
end

const _ilmenite_phase_names = ["ilm", "ilmm", "hem", "hemm"]

"""
    compute_ilmenite_points()

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the ilmenite-hematite phase composition where stable, and
    return per-point plot coordinates (hematite mol% vs Mg/(Mg+Fe2++Mn)),
    display label, pressure (for marker color) and phase wt fraction (for
    marker size).

    MAGEMin's own coarse solvus disambiguation already splits the `ilm`/
    `ilmm` solution models into `"hem"/"ilm"` and `"hemm"/"ilmm"` in
    `Out_XY[i].ph` itself — all four buckets are matched here so every
    ilmenite-hematite point reaches this module's own classification
    (computed independently from the recalculated structural formula, not
    from MAGEMin's coarse bucket).
"""
function compute_ilmenite_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    Hem_v = Vector{Union{Float64,Missing}}(missing, n_tot)
    Mg_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    label = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_ilmenite_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = oxide_cations(wt, 3.0)
        isnothing(cat) && continue

        f    = ilmenite_site_allocation(cat)
        name = classify_ilmenite(f)
        isempty(name) && continue

        divtot = f.Mg + f.Fe2 + f.Mn
        Hem_v[j] = 100.0 * (f.Fe3 / 2.0)
        Mg_v[j]  = divtot > 0.0 ? f.Mg / divtot : missing
        label[j] = oxide_label(name)
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return Hem_v, Mg_v, label, P_v, wt_v
end

"""
    Retrieve ilmenite-hematite classification diagram: hematite mol% vs
    Mg/(Mg+Fe2++Mn), split into Ilmenite-series / Hematite, each point's
    exact species (including Geikielite/Pyrophanite) carried in the hover
    label.
"""
function get_Ilmenite_diagram()

    Hem_v, Mg_v, label_v, P_v, wt_v = compute_ilmenite_points()

    fields = [
        ("Ilmenite-series", _amp_rect(0.0, 50.0, 0.0, 1.0)),
        ("Hematite",         _amp_rect(50.0, 100.0, 0.0, 1.0)),
    ]

    traces = _amp_field_traces(fields)

    n = length(Hem_v)
    colormap = get_jet_colormap(max(n,1))
    push!(traces, scatter(  x           = Hem_v,
                            y           = Mg_v,
                            mode        = "markers",
                            opacity     = 0.6,
                            showscale   = false,
                            showlegend  = false,
                            hoverinfo   = "text",
                            hovertext   = label_v,
                            marker      = attr(     size        = wt_v .*20.0 .+ 2.0,
                                                    color       = P_v,
                                                    colorscale  = colormap,
                                                    line        = attr( width = 0.75, color = "black" )    ) ))

    layout = Layout(
        title       = attr( text = "Ilmenite-hematite series", x = 0.5, xanchor = "center", yanchor = "top" ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=40),
        hoverlabel  = attr( bgcolor = "#566573", bordercolor = "#f8f9f9" ),
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "Hematite [Fe2O3, mol%]",
        yaxis_title = "Mg / (Mg + Fe²⁺ + Mn)",
        xaxis_range = [0.0, 100.0],
        yaxis_range = [0.0, 1.0],
        width       = 640,
        height      = 400,
        xaxis       = attr(fixedrange = true),
        yaxis       = attr(fixedrange = true),
    )
    layout.fields[:annotations] = _amp_field_annotations(fields)

    return traces, layout
end
