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

const _garnet_warr = Dict(
    "Pyrope"      => "Prp",
    "Almandine"   => "Alm",
    "Spessartine" => "Sps",
    "Grossular"   => "Grs",
)

"""
    garnet_label(name)

    Return the display label for a garnet species name, honoring the global
    Legacy/Warr(2021) toggle (`use_warr_names[1]`, `appData.jl`).
"""
function garnet_label(name::String)
    isempty(name) && return name
    use_warr_names[1] && return get(_garnet_warr, name, name)
    return name
end

"""
    garnet_site_allocation(cat)

    Read off the X-site (8-coordinated, divalent: Mg/Fe2+/Mn/Ca) occupancy
    from a 12-oxygen-normalized garnet cation set. Unlike amphibole/pyroxene,
    garnet's divalent cations have only one possible site to occupy (they
    never compete with the trivalent Y-site cations for placement), so no
    site-filling procedure is needed — the totals are read directly.
"""
function garnet_site_allocation(cat::Dict{Symbol,Float64})
    return (Mg = cat[:Mg], Fe2 = cat[:Fe2], Mn = cat[:Mn], Ca = cat[:Ca])
end

"""
    classify_garnet(f)

    Assign the garnet species by dominant X-site divalent cation: Pyrope
    (Mg), Almandine (Fe2+), Spessartine (Mn), Grossular (Ca).
"""
function classify_garnet(f)
    tot = f.Mg + f.Fe2 + f.Mn + f.Ca
    tot <= 0.0 && return ""

    if f.Mg >= f.Fe2 && f.Mg >= f.Mn && f.Mg >= f.Ca
        return "Pyrope"
    elseif f.Fe2 >= f.Mg && f.Fe2 >= f.Mn && f.Fe2 >= f.Ca
        return "Almandine"
    elseif f.Mn >= f.Mg && f.Mn >= f.Fe2 && f.Mn >= f.Ca
        return "Spessartine"
    else
        return "Grossular"
    end
end

const _garnet_phase_names = ["g"]

"""
    compute_garnet_points()

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the garnet phase composition where stable, and return per-point
    Pyrope-Almandine-Grossular ternary coordinates (Mg/Fe2+/Ca, renormalized
    to 100% — Spessartine is folded out of the plotted axes since Mn-dominant
    garnet is rare, but each point's exact species name, including
    Spessartine when it genuinely is dominant, is still computed correctly
    and carried in the label), display label, pressure (for marker color)
    and phase wt fraction (for marker size).
"""
function compute_garnet_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    Prp_v = Vector{Union{Float64,Missing}}(missing, n_tot)
    Alm_v = Vector{Union{Float64,Missing}}(missing, n_tot)
    Grs_v = Vector{Union{Float64,Missing}}(missing, n_tot)
    label = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_garnet_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = oxide_cations(wt, 12.0)
        isnothing(cat) && continue

        f    = garnet_site_allocation(cat)
        name = classify_garnet(f)
        isempty(name) && continue

        tot3 = f.Mg + f.Fe2 + f.Ca
        tot3 <= 0.0 && continue

        Prp_v[j] = 100.0 * f.Mg  / tot3
        Alm_v[j] = 100.0 * f.Fe2 / tot3
        Grs_v[j] = 100.0 * f.Ca  / tot3
        label[j] = garnet_label(name)
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return Prp_v, Alm_v, Grs_v, label, P_v, wt_v
end

"""
    Retrieve garnet classification diagram: Pyrope-Almandine-Grossular
    ternary (X-site Mg/Fe2+/Ca), point labels carry the exact species
    (including Spessartine where it is genuinely dominant).
"""
function get_Garnet_diagram()

    Prp_v, Alm_v, Grs_v, label_v, P_v, wt_v = compute_garnet_points()

    n = length(Prp_v)
    colormap = get_jet_colormap(max(n,1))
    points = scatterternary(
        a       = Prp_v,
        b       = Alm_v,
        c       = Grs_v,
        mode    = "markers",
        hoverinfo   = "text",
        hovertext   = label_v,
        opacity     = 0.6,
        marker  = attr(     size        = wt_v .*20.0 .+ 2.0,
                            color       = P_v,
                            colorscale  = colormap,
                            line        = attr( width = 0.75, color = "black" )    ),
        name    = "Sample Points"
    )

    layout = Layout(
        title= attr(
            text    = "Garnet",
            x       = 0.2,
            xanchor = "center",
            yanchor = "top"
        ),
        ternary=attr(
            sum     = 100,
            aaxis   = attr(title=garnet_label("Pyrope"),    gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            baxis   = attr(title=garnet_label("Almandine"), gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            caxis   = attr(title=garnet_label("Grossular"), gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            bgcolor = "#FFF",
            width       = 640,
            height      = 400,
        ),
        paper_bgcolor = "#FFF",
    )

    return [points], layout
end
