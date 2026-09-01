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

const _mica_warr = Dict(
    "Muscovite"       => "Ms",
    "Paragonite"      => "Pg",
    "Margarite"       => "Mrg",
    "Celadonite"      => "Cel",
    "Ferroceladonite" => "Fcel",
)

"""
    mica_label(name)

    Return the display label for a dioctahedral mica species name, honoring
    the global Legacy/Warr(2021) toggle (`use_warr_names[1]`, `appData.jl`).
"""
function mica_label(name::String)
    isempty(name) && return name
    use_warr_names[1] && return get(_mica_warr, name, name)
    return name
end

"""
    mica_site_allocation(cat)

    Distribute an 11-oxygen-normalized dioctahedral mica cation set: T = Si,
    then Al up to 4 (tetrahedral); interlayer K/Na/Ca are read directly (no
    other site can host them in this composition space). Mg/(Mg+Fe2+) is the
    bulk formula ratio, matching the amphibole/pyroxene diagram convention.
"""
function mica_site_allocation(cat::Dict{Symbol,Float64})

    Si = cat[:Si]

    MgNum = (cat[:Mg] + cat[:Fe2]) > 0.0 ? cat[:Mg] / (cat[:Mg] + cat[:Fe2]) : missing

    return (
        Si    = Si,
        K     = cat[:K],
        Na    = cat[:Na],
        Ca    = cat[:Ca],
        MgNum = MgNum,
    )
end

"""
    classify_mica_interlayer(f)

    Assign the dioctahedral mica species by dominant interlayer cation
    (Rieder et al. 1998): Muscovite(-series) if K is dominant, Paragonite if
    Na is dominant, Margarite if Ca is dominant.
"""
function classify_mica_interlayer(f)
    tot = f.K + f.Na + f.Ca
    tot <= 0.0 && return ""
    if f.K >= f.Na && f.K >= f.Ca
        return "Muscovite"
    elseif f.Na >= f.K && f.Na >= f.Ca
        return "Paragonite"
    else
        return "Margarite"
    end
end

"""
    classify_mica_celadonite(f)

    Within the K-dominant (Muscovite-series) group, split by the celadonite
    (Tschermak) substitution: Muscovite (Si < 3.5, low substitution) vs
    Celadonite/Ferroceladonite (Si >= 3.5, split at Mg/(Mg+Fe2+) = 0.5).
    Returns "" for compositions outside the K-dominant group.
"""
function classify_mica_celadonite(f)
    classify_mica_interlayer(f) != "Muscovite" && return ""
    f.Si < 3.5 && return "Muscovite"
    ismissing(f.MgNum) && return ""
    return f.MgNum >= 0.5 ? "Celadonite" : "Ferroceladonite"
end

const _mica_phase_names = ["mu", "pat"]

"""
    compute_mica_points()

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the muscovite-group phase composition where stable, and return
    per-point interlayer ternary coordinates (K/Na/Ca), celadonite-diagram
    coordinates (Si, Mg/(Mg+Fe2+)), display labels for both diagrams,
    pressure (for marker color) and phase wt fraction (for marker size).

    MAGEMin's own coarse solvus disambiguation (`get_mineral_name` in
    MAGEMin_C, applied before results ever reach the app) already splits the
    `mu` solution model into `"mu"/"pat"` in `Out_XY[i].ph` itself (its own
    Na vs K threshold) — the raw `"mu"`/`"mu_W14"` solution-phase short names
    only ever survive for the K-rich bucket, so `"pat"` (its Na-rich bucket)
    must be matched too, or every Paragonite-dominant point silently
    disappears from this module's own, finer K-Na-Ca interlayer
    classification (Rieder et al. 1998), which is computed independently
    from the recalculated structural formula, not from MAGEMin's bucket.
"""
function compute_mica_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    K_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    Na_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Ca_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Si_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Mg_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    label_interlayer = fill("", n_tot)
    label_celadonite = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_mica_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = oxide_cations(wt, 11.0)
        isnothing(cat) && continue

        f = mica_site_allocation(cat)
        name_il = classify_mica_interlayer(f)
        isempty(name_il) && continue

        K_v[j]   = f.K
        Na_v[j]  = f.Na
        Ca_v[j]  = f.Ca
        Si_v[j]  = f.Si
        Mg_v[j]  = f.MgNum
        label_interlayer[j] = mica_label(name_il)
        label_celadonite[j] = mica_label(classify_mica_celadonite(f))
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return K_v, Na_v, Ca_v, Si_v, Mg_v, label_interlayer, label_celadonite, P_v, wt_v
end

_mica_ternary_field(a, b, c) = scatterternary(
    a           = a,
    b           = b,
    c           = c,
    mode        = "lines",
    hoverinfo   = "skip",
    showlegend  = false,
    line        = attr(color = "black", width = 0.75),
)

"""
    Retrieve mica interlayer-cation classification diagram: K-Na-Ca ternary,
    dominant-cation split into Muscovite(-series) / Paragonite / Margarite
    (Rieder et al. 1998).
"""
function get_MicaInterlayer_diagram()

    K_v, Na_v, Ca_v, Si_v, Mg_v, label_il, label_cel, P_v, wt_v = compute_mica_points()

    # Dominant-cation partition: the 3 boundaries (K=Na, Na=Ca, K=Ca) are the
    # ternary medians, which meet at the centroid — drawing the 3 half-median
    # segments from the centroid out to each edge midpoint fully delineates
    # the 3 dominant-cation wedges.
    c = 100.0 / 3.0
    traces = GenericTrace{Dict{Symbol, Any}}[
        _mica_ternary_field([c, 50.0], [c, 50.0], [c,  0.0]),  # centroid -> mid(K,Na)
        _mica_ternary_field([c,  0.0], [c, 50.0], [c, 50.0]),  # centroid -> mid(Na,Ca)
        _mica_ternary_field([c, 50.0], [c,  0.0], [c, 50.0]),  # centroid -> mid(K,Ca)
    ]

    n = length(K_v)
    colormap = get_jet_colormap(max(n,1))
    push!(traces, scatterternary(
        a       = K_v,
        b       = Na_v,
        c       = Ca_v,
        mode    = "markers",
        hoverinfo   = "text",
        hovertext   = label_il,
        opacity     = 0.6,
        marker  = attr(     size        = wt_v .*20.0 .+ 2.0,
                            color       = P_v,
                            colorscale  = colormap,
                            line        = attr( width = 0.75, color = "black" )    ),
        name    = "Sample Points"
    ))

    layout = Layout(
        title= attr(
            text    = "Mica interlayer cation",
            x       = 0.2,
            xanchor = "center",
            yanchor = "top"
        ),
        ternary=attr(
            sum     = 100,
            aaxis   = attr(title=mica_label("Muscovite"),  gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            baxis   = attr(title=mica_label("Paragonite"), gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            caxis   = attr(title=mica_label("Margarite"),  gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            bgcolor = "#FFF",
            width       = 640,
            height      = 400,
        ),
        paper_bgcolor = "#FFF",
    )

    return traces, layout
end

"""
    Retrieve mica celadonite-substitution classification diagram (K-dominant
    group only): Si vs Mg/(Mg+Fe2+), split into Muscovite / Celadonite /
    Ferroceladonite.
"""
function get_MicaCeladonite_diagram()

    K_v, Na_v, Ca_v, Si_v, Mg_v, label_il, label_cel, P_v, wt_v = compute_mica_points()

    fields = [
        (mica_label("Muscovite"),       _amp_rect(3.00, 3.50, 0.00, 1.00)),
        (mica_label("Celadonite"),      _amp_rect(3.50, 4.00, 0.50, 1.00)),
        (mica_label("Ferroceladonite"), _amp_rect(3.50, 4.00, 0.00, 0.50)),
    ]

    traces = _amp_field_traces(fields)

    idx = findall(label_cel .!= "")
    n   = length(idx)
    colormap = get_jet_colormap(max(n,1))
    push!(traces, scatter(  x           = Si_v[idx],
                            y           = Mg_v[idx],
                            mode        = "markers",
                            opacity     = 0.6,
                            showscale   = false,
                            showlegend  = false,
                            hoverinfo   = "text",
                            hovertext   = label_cel[idx],
                            marker      = attr(     size        = wt_v[idx] .*20.0 .+ 2.0,
                                                    color       = P_v[idx],
                                                    colorscale  = colormap,
                                                    line        = attr( width = 0.75, color = "black" )    ) ))

    layout = Layout(
        title       = attr( text = "Muscovite-celadonite substitution", x = 0.5, xanchor = "center", yanchor = "top" ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=40),
        hoverlabel  = attr( bgcolor = "#566573", bordercolor = "#f8f9f9" ),
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "Si (apfu)",
        yaxis_title = "Mg / (Mg + Fe²⁺)",
        xaxis_range = [3.0, 4.0],
        yaxis_range = [0.0, 1.0],
        width       = 640,
        height      = 400,
        xaxis       = attr(fixedrange = true),
        yaxis       = attr(fixedrange = true),
    )
    layout.fields[:annotations] = _amp_field_annotations(fields)

    return traces, layout
end
