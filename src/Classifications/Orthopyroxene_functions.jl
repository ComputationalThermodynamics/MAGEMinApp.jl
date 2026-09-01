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

const _opx_warr = Dict(
    "Enstatite"   => "En",
    "Ferrosilite" => "Fs",
)

"""
    opx_label(name)

    Return the display label for an orthopyroxene species name, honoring the
    global Legacy/Warr(2021) toggle (`use_warr_names[1]`, `appData.jl`).
"""
function opx_label(name::String)
    isempty(name) && return name
    use_warr_names[1] && return get(_opx_warr, name, name)
    return name
end

"""
    classify_opx(f)

    Assign the current IMA (Morimoto et al. 1988) orthopyroxene species name
    from a `cpx_site_allocation` NamedTuple (the T-M1-M2 6-oxygen pyroxene
    normalization is shared with clinopyroxene — see `Clinopyroxene_functions.jl`):
    Enstatite (Mg >= Fe2+) or Ferrosilite (Fe2+ > Mg). Orthopyroxene is
    identified upstream by MAGEMin's own "opx" phase name, so no Wo/J
    gatekeeping is needed here (unlike clinopyroxene's Ca-Na variety).
"""
function classify_opx(f)
    ismissing(f.En) && return ""
    return f.En >= f.Fs ? "Enstatite" : "Ferrosilite"
end

const _opx_phase_names = ["opx", "opx_W14", "opx_W24", "opx_T21", "opx_H13", "opx_MELTS"]

"""
    compute_opx_points()

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the orthopyroxene phase composition where stable, and return
    plot coordinates (Wo/En/Fs), display label, pressure (for marker color)
    and phase wt fraction (for marker size).
"""
function compute_opx_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    Wo_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    En_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Fs_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    label = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_opx_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = oxide_cations(wt, 6.0)
        isnothing(cat) && continue

        f    = cpx_site_allocation(cat)
        name = classify_opx(f)
        isempty(name) && continue

        Wo_v[j]  = f.Wo
        En_v[j]  = f.En
        Fs_v[j]  = f.Fs
        label[j] = opx_label(name)
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return Wo_v, En_v, Fs_v, label, P_v, wt_v
end

"""
    Retrieve orthopyroxene classification diagram: Wo-En-Fs quadrilateral
    position, split at En = Fs into Enstatite / Ferrosilite (Morimoto et al.
    1988 current IMA nomenclature).
"""
function get_OpxQuad_diagram()

    Wo_v, En_v, Fs_v, label_v, P_v, wt_v = compute_opx_points()

    boundary = scatterternary(
        a           = [0.0, 100.0],
        b           = [50.0, 0.0],
        c           = [50.0, 0.0],
        mode        = "lines",
        hoverinfo   = "skip",
        showlegend  = false,
        line        = attr(color = "black", width = 0.75),
    )

    n = length(En_v)
    colormap = get_jet_colormap(max(n,1))
    points = scatterternary(
        a       = Wo_v,
        b       = En_v,
        c       = Fs_v,
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
            text    = "Orthopyroxene [En-Fs]",
            x       = 0.2,
            xanchor = "center",
            yanchor = "top"
        ),
        ternary=attr(
            sum     = 100,
            aaxis   = attr(title="Wo", gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            baxis   = attr(title="En", gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            caxis   = attr(title="Fs", gridcolor = "darkgray", showline = true, linecolor = "darkgray"),
            bgcolor = "#FFF",
            width       = 640,
            height      = 400,
        ),
        paper_bgcolor = "#FFF",
    )

    return [boundary, points], layout
end
