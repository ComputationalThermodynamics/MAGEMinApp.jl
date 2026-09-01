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

const _cpx_warr = Dict(
    "Diopside"            => "Di",
    "Hedenbergite"        => "Hed",
    "Augite"              => "Aug",
    "Pigeonite"           => "Pig",
    "Clinoenstatite"      => "Cen",
    "Clinoferrosilite"    => "Cfs",
    "Omphacite"           => "Omp",
    "Jadeite"             => "Jd",
    "Aegirine"            => "Aeg",
)

"""
    cpx_label(name)

    Return the display label for a clinopyroxene species name, honoring the
    global Legacy/Warr(2021) toggle (`use_warr_names[1]`, `appData.jl`).
    "Aegirine-augite" has no discrete IMA symbol and is returned unchanged.
"""
function cpx_label(name::String)
    isempty(name) && return name
    use_warr_names[1] && return get(_cpx_warr, name, name)
    return name
end

"""
    cpx_site_allocation(cat)

    Distribute a 6-oxygen-normalized pyroxene cation set onto the standard
    T(2)-M1(1)-M2(1) sites: T = Si, then Al up to 2; M1 = remaining Al, Fe3+,
    Ti, Cr, then Mg-Fe2+ up to 1; M2 = remaining Mg-Fe2+-Mn, then Ca, Na up
    to 1.

    Returns the Morimoto et al. (1988) classification quantities: Q (Ca+Mg+
    Fe2+, quad component), J (2*Na, jadeite+aegirine component), the
    Wo/En/Fs ternary percentages (Quad pyroxenes only), and the M1 ferric
    ratio Fe3+/(Fe3+ + Al(VI)) used to split the Na-bearing groups.
"""
function cpx_site_allocation(cat::Dict{Symbol,Float64})

    Si   = cat[:Si]
    AlIV = min(cat[:Al], max(0.0, 2.0 - Si))
    AlVI = cat[:Al] - AlIV

    M1_hfs    = AlVI + cat[:Fe3] + cat[:Ti] + cat[:Cr]
    M1_remain = max(0.0, 1.0 - M1_hfs)

    mgfemn_total = cat[:Mg] + cat[:Fe2] + cat[:Mn]
    M1_mgfemn    = min(mgfemn_total, M1_remain)
    share        = mgfemn_total > 0.0 ? M1_mgfemn / mgfemn_total : 0.0

    Mg_M2  = cat[:Mg]  * (1.0 - share)
    Fe2_M2 = cat[:Fe2] * (1.0 - share)
    Mn_M2  = cat[:Mn]  * (1.0 - share)

    M2_remain = max(0.0, 1.0 - (Mg_M2 + Fe2_M2 + Mn_M2))
    Ca_M2     = min(cat[:Ca], M2_remain)
    Na_M2     = min(cat[:Na], max(0.0, M2_remain - Ca_M2))

    # Q uses total Ca/Mg/Fe2+ across M1+M2 (the standard Morimoto definition)
    Q_Mg  = cat[:Mg]
    Q_Fe2 = cat[:Fe2]
    Q_Ca  = Ca_M2

    Q = Q_Ca + Q_Mg + Q_Fe2
    J = 2.0 * Na_M2

    QEFS = Q > 0.0 ? 100.0 / Q : 0.0
    Wo = Q_Ca  * QEFS
    En = Q_Mg  * QEFS
    Fs = Q_Fe2 * QEFS

    Fe3ratio = (cat[:Fe3] + AlVI) > 0.0 ? cat[:Fe3] / (cat[:Fe3] + AlVI) : missing

    return (
        Q   = Q,
        J   = J,
        Wo  = Wo,
        En  = En,
        Fs  = Fs,
        Fe3ratio = Fe3ratio,
    )
end

"""
    classify_cpx(f)

    Assign a Morimoto et al. (1988) clinopyroxene species name and target
    diagram panel from a `cpx_site_allocation` NamedTuple:
      - :Quad  (J < 0.20)                      -> Wo-En-Fs quadrilateral species
      - :NaCa  (0.20 <= J <= 0.80)              -> Omphacite / Aegirine-augite
      - :Na    (J > 0.80)                       -> Jadeite / Aegirine
    The Na-bearing groups are split at Fe3+/(Fe3+ + Al(VI)) = 0.20.
"""
function classify_cpx(f)

    f.J < 0.20 && return classify_cpx_quad(f)

    ismissing(f.Fe3ratio) && return (:none, "")
    ferric = f.Fe3ratio >= 0.20

    if f.J <= 0.80
        name = ferric ? "Aegirine-augite" : "Omphacite"
    else
        name = ferric ? "Aegirine" : "Jadeite"
    end
    return (:Na, name)
end

function classify_cpx_quad(f)
    wo = f.Wo
    mgrich = f.En >= f.Fs
    if wo >= 45.0
        name = mgrich ? "Diopside" : "Hedenbergite"
    elseif wo >= 20.0
        name = "Augite"
    elseif wo >= 5.0
        name = "Pigeonite"
    else
        name = mgrich ? "Clinoenstatite" : "Clinoferrosilite"
    end
    return (:Quad, name)
end

const _cpx_phase_names = ["cpx", "pig", "Na-cpx", "dio", "omph", "jd", "aug"]

"""
    compute_cpx_points()

    MAGEMin's own coarse solvus disambiguation (`get_mineral_name` in
    MAGEMin_C, applied before results ever reach the app) already splits the
    `cpx` solution model into `"pig"/"Na-cpx"/"cpx"` and the `dio` solution
    model into `"dio"/"omph"/"jd"` in `Out_XY[i].ph` itself — the raw
    `"cpx"`/`"dio"` solution-phase names only ever survive for the
    residual/least-substituted bucket. `aug` (a separate, undisambiguated
    solution model) is unaffected. All buckets must be matched here so every
    clinopyroxene point reaches this module's own, finer Morimoto et al.
    (1988) classification (computed independently from the recalculated
    structural formula, not from MAGEMin's coarse bucket).

    Loop over the currently computed point set (`points_in_idx`, `Out_XY`),
    pick up the clinopyroxene phase composition where stable (across the
    "cpx"/"dio"/"aug" naming used by the different databases), and return
    per-point panel routing, plot coordinates, display label, pressure (for
    marker color) and phase wt fraction (for marker size).
"""
function compute_cpx_points()

    global points_in_idx, Out_XY

    n_tot  = length(points_in_idx)
    oxides = Out_XY[1].oxides

    panel = fill(:none, n_tot)
    Q_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    J_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    Wo_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    En_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    Fs_v  = Vector{Union{Float64,Missing}}(missing, n_tot)
    fe3_v = Vector{Union{Float64,Missing}}(missing, n_tot)
    label = fill("", n_tot)
    P_v   = Vector{Union{Float64,Missing}}(missing, n_tot)
    wt_v  = Vector{Union{Float64,Missing}}(missing, n_tot)

    for j = 1:n_tot
        out = Out_XY[points_in_idx[j]]
        id  = findall(in(_cpx_phase_names), out.ph)
        isempty(id) && continue

        comp = out.SS_vec[id[1]].Comp_wt .* 100.0
        wt   = Dict(oxides[k] => comp[k] for k in eachindex(oxides))

        cat = oxide_cations(wt, 6.0)
        isnothing(cat) && continue

        f          = cpx_site_allocation(cat)
        pnl, name  = classify_cpx(f)
        pnl == :none && continue

        panel[j] = pnl
        Q_v[j]   = f.Q
        J_v[j]   = f.J
        Wo_v[j]  = f.Wo
        En_v[j]  = f.En
        Fs_v[j]  = f.Fs
        fe3_v[j] = f.Fe3ratio
        label[j] = cpx_label(name)
        P_v[j]   = out.P_kbar
        wt_v[j]  = out.ph_frac_wt[id[1]]
    end

    return panel, Q_v, J_v, Wo_v, En_v, Fs_v, fe3_v, label, P_v, wt_v
end

"""
    Retrieve clinopyroxene classification diagram, Morimoto et al. (1988)
    Q-J diagram: gatekeeper splitting Quad / Na-Ca / Na pyroxene groups.
"""
function get_CpxQJ_diagram()

    panel_v, Q_v, J_v, Wo_v, En_v, Fs_v, fe3_v, label_v, P_v, wt_v = compute_cpx_points()

    fields = [
        ("Quad pyroxenes",       _amp_rect(0.00, 0.20, 0.00, 2.00)),
        ("Na-Ca pyroxenes",      _amp_rect(0.20, 0.80, 0.00, 2.00)),
        ("Na pyroxenes",         _amp_rect(0.80, 2.00, 0.00, 2.00)),
    ]

    traces = _amp_field_traces(fields)

    n = length(J_v)
    colormap = get_jet_colormap(max(n,1))
    push!(traces, scatter(  x           = J_v,
                            y           = Q_v,
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
        title       = attr( text = "Clinopyroxene Q-J diagram", x = 0.5, xanchor = "center", yanchor = "top" ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=40),
        hoverlabel  = attr( bgcolor = "#566573", bordercolor = "#f8f9f9" ),
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "J = 2 x Na (apfu)",
        yaxis_title = "Q = Ca + Mg + Fe²⁺ (apfu)",
        xaxis_range = [0.0, 2.0],
        yaxis_range = [0.0, 2.0],
        width       = 640,
        height      = 400,
        xaxis       = attr(fixedrange = true),
        yaxis       = attr(fixedrange = true),
    )
    layout.fields[:annotations] = _amp_field_annotations(fields)

    return traces, layout
end

"""
    Retrieve clinopyroxene classification diagram, Morimoto et al. (1988)
    Wo-En-Fs quadrilateral (Quad-pyroxene group, J < 0.20).
"""
function get_CpxQuad_diagram()

    panel_v, Q_v, J_v, Wo_v, En_v, Fs_v, fe3_v, label_v, P_v, wt_v = compute_cpx_points()

    idx = findall(panel_v .== :Quad)
    n   = length(idx)
    colormap = get_jet_colormap(max(n,1))

    quad = scatterternary(
        a       = Wo_v[idx],
        b       = En_v[idx],
        c       = Fs_v[idx],
        mode    = "markers",
        hoverinfo   = "text",
        hovertext   = label_v[idx],
        opacity     = 0.6,
        marker  = attr(     size        = wt_v[idx] .*20.0 .+ 2.0,
                            color       = P_v[idx],
                            colorscale  = colormap,
                            line        = attr( width = 0.75, color = "black" )    ),
        name    = "Sample Points"
    )

    layout = Layout(
        title= attr(
            text    = "Pyroxene quadrilateral",
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

    return [quad], layout
end

"""
    Retrieve clinopyroxene classification diagram, Morimoto et al. (1988)
    Na-bearing pyroxenes (J >= 0.20): Omphacite/Aegirine-augite (Na-Ca group)
    and Jadeite/Aegirine (Na group), split at Fe3+/(Fe3+ + Al(VI)) = 0.20.
"""
function get_CpxNaPx_diagram()

    panel_v, Q_v, J_v, Wo_v, En_v, Fs_v, fe3_v, label_v, P_v, wt_v = compute_cpx_points()

    fields = [
        (cpx_label("Omphacite"),        _amp_rect(0.20, 0.80, 0.00, 0.20)),
        (cpx_label("Aegirine-augite"),  _amp_rect(0.20, 0.80, 0.20, 1.00)),
        (cpx_label("Jadeite"),          _amp_rect(0.80, 2.00, 0.00, 0.20)),
        (cpx_label("Aegirine"),         _amp_rect(0.80, 2.00, 0.20, 1.00)),
    ]

    traces = _amp_field_traces(fields)

    idx = findall(panel_v .== :Na)
    n   = length(idx)
    colormap = get_jet_colormap(max(n,1))
    push!(traces, scatter(  x           = J_v[idx],
                            y           = fe3_v[idx],
                            mode        = "markers",
                            opacity     = 0.6,
                            showscale   = false,
                            showlegend  = false,
                            hoverinfo   = "text",
                            hovertext   = label_v[idx],
                            marker      = attr(     size        = wt_v[idx] .*20.0 .+ 2.0,
                                                    color       = P_v[idx],
                                                    colorscale  = colormap,
                                                    line        = attr( width = 0.75, color = "black" )    ) ))

    layout = Layout(
        title       = attr( text = "Na-bearing clinopyroxene [J ≥ 0.20]", x = 0.5, xanchor = "center", yanchor = "top" ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=40),
        hoverlabel  = attr( bgcolor = "#566573", bordercolor = "#f8f9f9" ),
        plot_bgcolor  = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "J = 2 x Na (apfu)",
        yaxis_title = "Fe³⁺ / (Fe³⁺ + Al(VI))",
        xaxis_range = [0.20, 2.0],
        yaxis_range = [0.0, 1.0],
        width       = 640,
        height      = 400,
        xaxis       = attr(fixedrange = true),
        yaxis       = attr(fixedrange = true),
    )
    layout.fields[:annotations] = _amp_field_annotations(fields)

    return traces, layout
end
