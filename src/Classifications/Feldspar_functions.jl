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

const _feldspar_warr = Dict(
    "Albite"          => "Ab",
    "Oligoclase"      => "Olg",
    "Andesine"        => "Ans",
    "Labradorite"     => "Lab",
    "Bytownite"       => "Byt",
    "Anorthite"       => "An",
    "Alkali feldspar" => "Afs",
)

"""
    feldspar_label(name)

    Return the display label for a feldspar species/group name, honoring
    the global Legacy/Warr(2021) toggle (`use_warr_names[1]`, `appData.jl`).
"""
function feldspar_label(name::String)
    isempty(name) && return name
    use_warr_names[1] && return get(_feldspar_warr, name, name)
    return name
end

"""
    feldspar_site_allocation(cat)

    Read off the large-cation (Na/Ca/K) occupancy from an 8-oxygen-normalized
    feldspar cation set. Feldspar's Al-Si tetrahedral framework doesn't need
    a site-filling procedure for classification purposes (unlike amphibole's
    competing C/B sites) — the large cations are unambiguous.
"""
function feldspar_site_allocation(cat::Dict{Symbol,Float64})
    return (Na = cat[:Na], Ca = cat[:Ca], K = cat[:K])
end

"""
    classify_feldspar(f)

    Assign the feldspar species by Or-Ab-An proportions. Alkali feldspar
    polymorphs (sanidine/orthoclase/microcline) are distinguished by
    structural state (Al-Si order), not bulk composition, so the K-dominant
    (Or >= 50%) side is reported generically as "Alkali feldspar" rather
    than guessing a polymorph. The Na-Ca-dominant side is classified by the
    standard 6-fold plagioclase An% series.
"""
function classify_feldspar(f)
    tot = f.Na + f.Ca + f.K
    tot <= 0.0 && return ""

    or = 100.0 * f.K / tot
    or >= 50.0 && return "Alkali feldspar"

    an = 100.0 * f.Ca / (f.Na + f.Ca)
    an < 10.0  && return "Albite"
    an < 30.0  && return "Oligoclase"
    an < 50.0  && return "Andesine"
    an < 70.0  && return "Labradorite"
    an < 90.0  && return "Bytownite"
    return "Anorthite"
end

const _feldspar_phase_names = ["fsp", "afs", "pl"]

"""
    compute_feldspar_points()

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the feldspar phase composition where stable, and return per-point
    Ab/Or/An ternary coordinates, display label, pressure (for marker color)
    and phase wt fraction (for marker size).

    MAGEMin's own coarse solvus disambiguation already splits the `fsp`
    solution model into `"afs"`/`"pl"` in `Out_XY[i].ph` itself — both are
    matched here so every feldspar point reaches this module's own Ab-An-Or
    classification (computed independently from the recalculated structural
    formula, not from MAGEMin's coarse bucket).
"""
function compute_feldspar_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    Ab_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Or_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    An_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    label = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_feldspar_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = oxide_cations(wt, 8.0)
        isnothing(cat) && continue

        f    = feldspar_site_allocation(cat)
        name = classify_feldspar(f)
        isempty(name) && continue

        tot = f.Na + f.Ca + f.K
        Ab_v[j]  = 100.0 * f.Na / tot
        Or_v[j]  = 100.0 * f.K  / tot
        An_v[j]  = 100.0 * f.Ca / tot
        label[j] = feldspar_label(name)
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return Ab_v, Or_v, An_v, label, P_v, wt_v
end

"""
    Retrieve feldspar classification diagram: Ab-Or-An ternary, split into
    Alkali feldspar (Or >= 50%) and the 6-fold plagioclase An% series.
"""
function get_Feldspar_diagram()

    Ab_v, Or_v, An_v, label_v, P_v, wt_v = compute_feldspar_points()

    an_bounds = (10.0, 30.0, 50.0, 70.0, 90.0)
    traces = GenericTrace{Dict{Symbol, Any}}[]
    for k in an_bounds
        b_end = min(50.0, 100.0 - k)
        a_end = 100.0 - k - b_end
        push!(traces, _mica_ternary_field([100.0-k, a_end], [0.0, b_end], [k, k]))
    end
    push!(traces, _mica_ternary_field([50.0, 0.0], [50.0, 50.0], [0.0, 50.0]))

    n = length(Ab_v)
    colormap = get_jet_colormap(max(n,1))
    push!(traces, scatterternary(
        a       = Ab_v,
        b       = Or_v,
        c       = An_v,
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
            text    = "Feldspar",
            x       = 0.2,
            xanchor = "center",
            yanchor = "top"
        ),
        ternary=attr(
            sum     = 100,
            aaxis   = attr(title="Ab", gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            baxis   = attr(title="Or", gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            caxis   = attr(title="An", gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            bgcolor = "#FFF",
            width       = 640,
            height      = 400,
        ),
        paper_bgcolor = "#FFF",
    )

    return traces, layout
end
