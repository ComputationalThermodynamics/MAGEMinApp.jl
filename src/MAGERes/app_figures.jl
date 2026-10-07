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

const MAGERES_FIELD_TITLES = Dict(:T        => "Temperature",
                                  :frac     => "Material (magma fraction)",
                                  :pressure => "Pressure",
                                  :level    => "Quadtree grid",
                                  :melt     => "Melt fraction",
                                  :material => "Material",
                                  :calc     => "Thermodynamic calculations")

"""
    mageres_field_figure(st::MAGEResState, field::Symbol; title = "", show_grid = true, preview = nothing,
                         height = 760, resolution = nothing, probe = nothing, pie_unit = 1, show_outline = true,
                         show_isotherms = true)

    PlotlyJS figure of the map field `field` of `st` with the injected / erupted logs and optional probe pie;
    an empty `title` is replaced by field name, time and cell count.
"""
function mageres_field_figure(st::MAGEResState, field::Symbol; title::AbstractString = "",
                              show_grid::Bool = true, preview = nothing, height::Int = 760, resolution = nothing,
                              probe = nothing, pie_unit::Int = 1, show_outline::Bool = true,
                              show_isotherms::Bool = true)
    t      = isempty(title) ? @sprintf("%s — t = %.0f yr — %d cells", MAGERES_FIELD_TITLES[field], st.t,
                                       mageres_ncells(st.grid)) : title
    traces = mageres_traces(st; field          = field,
                                show_grid      = show_grid,
                                preview        = preview,
                                resolution     = resolution,
                                probe          = probe,
                                pie_unit       = pie_unit,
                                show_outline   = show_outline,
                                show_isotherms = show_isotherms)
    k      = findfirst(tr -> get(tr.fields, :type, nothing) == "pie", traces)
    extra  = field == :material ? mageres_material_legend_height() : 0
    layout = mageres_layout(st; height       = height + extra,
                                title        = t,
                                probe        = probe,
                                pie_unit     = pie_unit,
                                pie_index    = k === nothing ? nothing : k - 1,
                                bottom_extra = extra)
    field == :material && mageres_add_material_legend!(layout, height - 80)
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_calc_figure(st::MAGEResState, nsteps::Int; title = "", probe = nothing, pie_unit = 1, show_grid = true,
                        show_outline = true, show_isotherms = true)

    Map of MAGEMin calculations per cell since the previous output, annotated with the totals over the last
    `nsteps` timesteps; a placeholder figure without MAGEMin thermodynamics.
"""
function mageres_calc_figure(st::MAGEResState, nsteps::Int; title::AbstractString = "", probe = nothing,
                             pie_unit::Int = 1, show_grid::Bool = true, show_outline::Bool = true,
                             show_isotherms::Bool = true)
    th = st.thermo
    th === nothing && return mageres_placeholder_figure("Thermodynamic calculations require MAGEMin thermodynamics")
    fig    = mageres_field_figure(st, :calc; title        = title,
                                             show_grid    = show_grid,
                                             probe        = probe,
                                             pie_unit     = pie_unit,
                                             show_outline = show_outline)
    total  = th.n_minimizations - th.n_min_reset
    other  = total - th.n_cell_calc
    ncells = count(>(0), th.calc_count)
    text   = @sprintf("<b>%d MAGEMin calculations</b> since the previous output (%d timestep%s)<br>\
                      cell updates: %d in %d cells, at most %d in one cell<br>\
                      not tied to a cell (host profile, injected magma, chamber mixing): %d",
                      total, nsteps, nsteps == 1 ? "" : "s", th.n_cell_calc, ncells,
                      maximum(th.calc_count; init = 0), other)
    note   = attr(text        = text,
                  xref        = "paper",
                  yref        = "paper",
                  x           = 0.01,
                  y           = MAGERES_MAP_DOMAIN[2] - 0.01,
                  xanchor     = "left",
                  yanchor     = "top",
                  align       = "left",
                  showarrow   = false,
                  bgcolor     = "rgba(255,255,255,0.85)",
                  bordercolor = "rgb(120,120,120)",
                  borderwidth = 1,
                  font        = attr(size = 12))
    push!(get!(fig.plot.layout.fields, :annotations, Any[]), note)
    return fig
end

"""
    mageres_placeholder_figure(message::AbstractString; height = 400)

    Empty PlotlyJS figure with hidden axes showing `message` in its centre.
"""
function mageres_placeholder_figure(message::AbstractString; height::Int = 400)
    layout = Layout(; height       = height,
                      xaxis        = attr(visible = false),
                      yaxis        = attr(visible = false),
                      plot_bgcolor = "white",
                      annotations  = [attr(text = message, showarrow = false, x = 0.5, y = 0.5, xref = "paper",
                                           yref = "paper", font = attr(size = 14, color = "grey"))])
    return PlotlyJS.plot(GenericTrace[scatter(; x = Float64[], y = Float64[])], layout)
end

"""
    mageres_series_layout(title::AbstractString, ylabel::AbstractString; height = 420, ylog = false)

    Layout of a time-series figure with time [yr] on x, `ylabel` on y (log scale when `ylog`) and a horizontal
    legend below.
"""
function mageres_series_layout(title::AbstractString, ylabel::AbstractString; height::Int = 420, ylog::Bool = false)
    ya = attr(title = ylabel, showline = true, linecolor = "black", mirror = true)
    ylog && (ya[:type] = "log"; ya[:exponentformat] = "power")
    return Layout(; title        = title,
                    height       = height,
                    plot_bgcolor = "white",
                    hovermode    = "x unified",
                    xaxis        = attr(title = "Time (yr)", showline = true, linecolor = "black", mirror = true),
                    yaxis        = ya,
                    legend       = attr(orientation = "h", y = -0.25))
end

"""
    mageres_vital_signs_figure(S::MAGEResSeries)

    Time series of mean and maximum chamber temperature, chamber thickness and, when available, mean chamber
    melt fraction.
"""
function mageres_vital_signs_figure(S::MAGEResSeries)
    isempty(S.t) && return mageres_placeholder_figure("No run yet")
    traces = GenericTrace[
        scatter(; x = S.t, y = mageres_finite_or_nothing(S.T_mean), name = "mean chamber T (°C)", mode = "lines"),
        scatter(; x = S.t, y = mageres_finite_or_nothing(S.T_max), name = "max T (°C)", mode = "lines",
                  line = attr(dash = "dot")),
        scatter(; x = S.t, y = mageres_finite_or_nothing(S.thickness), name = "chamber max thickness (m)",
                  mode = "lines", yaxis = "y2"),
    ]
    layout          = mageres_series_layout("Vital signs", "Temperature (°C)")
    layout[:yaxis2] = attr(title = "Thickness (m)", overlaying = "y", side = "right", rangemode = "tozero")
    if any(isfinite, S.melt_mean)
        push!(traces, scatter(; x = S.t, y = mageres_finite_or_nothing(S.melt_mean),
                                name = "mean chamber melt fraction", mode = "lines", yaxis = "y3"))
        layout[:yaxis3]         = attr(title = "Melt fraction", overlaying = "y", side = "right", range = [0, 1],
                                       anchor = "free", position = 1.0, showgrid = false)
        layout[:xaxis][:domain] = [0.0, 0.88]
    end
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_volume_figure(S::MAGEResSeries; dP_crit = nothing)

    Time series of cumulative injected and erupted magma area and area stored in the chamber [km²]; with
    `dP_crit` [MPa] (overpressure trigger), also the chamber overpressure and its critical value.
"""
function mageres_volume_figure(S::MAGEResSeries; dP_crit::Union{Nothing,Float64} = nothing)
    isempty(S.t) && return mageres_placeholder_figure("No run yet")
    traces = GenericTrace[
        scatter(; x = S.t, y = S.V_injected ./ 1e6, name = "injected (cumulative)", mode = "lines",
                  line = attr(shape = "hv")),
        scatter(; x = S.t, y = S.V_erupted ./ 1e6, name = "erupted (cumulative)", mode = "lines",
                  line = attr(shape = "hv")),
        scatter(; x = S.t, y = S.area ./ 1e6, name = "in chamber", mode = "lines"),
    ]
    layout = mageres_series_layout("Injected, erupted and stored magma", "Area (km²)")
    if dP_crit !== nothing
        push!(traces, scatter(; x = S.t, y = S.overpressure, name = "overpressure (MPa)", mode = "lines",
                                yaxis = "y2", line = attr(color = "rgb(200,40,40)")))
        push!(traces, scatter(; x = [S.t[1], S.t[end]], y = [dP_crit, dP_crit], name = "critical overpressure",
                                mode = "lines", yaxis = "y2", line = attr(color = "rgb(200,40,40)", dash = "dash")))
        layout[:yaxis2] = attr(title = "Overpressure (MPa)", overlaying = "y", side = "right", showgrid = false)
    end
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_energy_figure(S::MAGEResSeries)

    Time series of the cumulative energy budget terms [PJ/m]: injected, erupted, boundary conduction, host
    in/outflow and, when non-zero, re-equilibration and fluid removal.
"""
function mageres_energy_figure(S::MAGEResSeries)
    isempty(S.t) && return mageres_placeholder_figure("No run yet")
    sc     = 1e-15
    traces = GenericTrace[
        scatter(; x = S.t, y = S.E_injected .* sc, name = "injected", mode = "lines"),
        scatter(; x = S.t, y = -S.E_extracted .* sc, name = "erupted (−)", mode = "lines"),
        scatter(; x = S.t, y = S.E_boundary .* sc, name = "boundary conduction", mode = "lines"),
        scatter(; x = S.t, y = -S.E_net_outflow .* sc, name = "host in/outflow (net, −)", mode = "lines"),
    ]
    if any(!iszero, S.E_remin) || any(!iszero, S.E_fluid)
        push!(traces, scatter(; x = S.t, y = S.E_remin .* sc, name = "re-equilibration (apparent cp)", mode = "lines"))
        push!(traces, scatter(; x = S.t, y = -S.E_fluid .* sc, name = "fluid removed (−)", mode = "lines"))
    end
    return PlotlyJS.plot(traces, mageres_series_layout("Energy budget (cumulative, per metre along strike)",
                                                       "Energy (PJ/m)"))
end

"""
    mageres_diagnostics_figure(S::MAGEResSeries; te = false)

    Time series of the absolute relative conservation errors (log scale), including the trace-element masses
    when `te`, and of the cell count.
"""
function mageres_diagnostics_figure(S::MAGEResSeries; te::Bool = false)
    isempty(S.t) && return mageres_placeholder_figure("No run yet")
    fl(v) = mageres_finite_or_nothing(max.(abs.(v), 1e-17))
    traces = GenericTrace[
        scatter(; x = S.t, y = fl(S.energy_error), name = "energy (solver, E = C·T)", mode = "lines+markers",
                  marker = attr(size = 3)),
        scatter(; x = S.t, y = fl(S.enthalpy_error), name = "enthalpy", mode = "lines+markers",
                  marker = attr(size = 3)),
        scatter(; x = S.t, y = fl(S.mass_error), name = "oxide moles (worst)", mode = "lines+markers",
                  marker = attr(size = 3)),
        scatter(; x = S.t, y = fl(S.host_error), name = "host area", mode = "lines+markers", marker = attr(size = 3)),
        scatter(; x = S.t, y = fl(S.budget_error), name = "injected = chamber + erupted", mode = "lines+markers",
                  marker = attr(size = 3)),
        scatter(; x = S.t, y = Float64.(S.ncells), name = "cells", mode = "lines", yaxis = "y2"),
    ]
    te && insert!(traces, 4, scatter(; x      = S.t,
                                       y      = fl(S.te_error),
                                       name   = "trace elements, Zr in zircon included (worst)",
                                       mode   = "lines+markers",
                                       marker = attr(size = 3)))
    layout          = mageres_series_layout("Conservation diagnostics (relative error)", "|relative error|";
                                            ylog = true)
    layout[:yaxis2] = attr(title = "cells", overlaying = "y", side = "right", rangemode = "tozero")
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_convection_figure(S::MAGEResSeries)

    Time series of the Nusselt number (log scale) and of mobile body, percolated melt, settled crystal and
    cumulate areas [km²].
"""
function mageres_convection_figure(S::MAGEResSeries)
    (isempty(S.t) || all(==(0), S.body_area)) &&
        return mageres_placeholder_figure("No mobile body yet (requires MAGEMin thermodynamics)")
    traces = GenericTrace[
        scatter(; x = S.t, y = S.Nu, name = "Nusselt number", mode = "lines+markers", marker = attr(size = 3)),
        scatter(; x = S.t, y = S.body_area ./ 1e6, name = "mobile body area (km²)", mode = "lines", yaxis = "y2"),
        scatter(; x = S.t, y = S.percolated_area ./ 1e6, name = "percolated melt (km², cumulative)", mode = "lines",
                  yaxis = "y2", line = attr(dash = "dot")),
        scatter(; x = S.t, y = S.settled_area ./ 1e6, name = "settled crystals (km², cumulative)", mode = "lines",
                  yaxis = "y2", line = attr(dash = "dash")),
        scatter(; x = S.t, y = S.cumulate_area ./ 1e6, name = "cumulate (km²)", mode = "lines", yaxis = "y2"),
    ]
    layout          = mageres_series_layout("Pseudoconvection, percolation and settling", "Nu"; ylog = true)
    layout[:yaxis2] = attr(title = "Area (km²)", overlaying = "y", side = "right", rangemode = "tozero")
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_cumulate_figure(st::MAGEResState)

    Cumulate log: one horizontal bar per piling event (cumulate grouped by lock-up time interval), stacked from the
    oldest at the base, split into the vol% of each solid phase.
"""
function mageres_cumulate_figure(st::MAGEResState)
    cells = findall(mageres_cumulate(st))
    (st.thermo === nothing || isempty(cells)) && return mageres_placeholder_figure("No cumulate yet"; height = 360)
    pts    = st.thermo.points
    A      = st.grid.area
    dt     = max(st.opts.output_every_yr, st.opts.thermal_dt_yr)
    tb     = Dict(c => dt * round(st.cumulate_t[c] / dt) for c in cells)
    times  = sort(unique(values(tb)))
    phases = sort(unique(p for c in cells for p in pts[c].solid_ph))
    area   = [sum(A[c] for c in cells if tb[c] == t) for t in times]
    frac   = Dict(ph => zeros(length(times)) for ph in phases)
    for (i, t) in enumerate(times), c in cells
        tb[c] == t || continue
        for (ph, f) in zip(pts[c].solid_ph, pts[c].solid_frac)
            frac[ph][i] += 100 * f * A[c] / area[i]
        end
    end
    n      = length(times)
    rows   = collect(1:n)
    labels = [@sprintf("t = %.0f yr", t) for t in times]
    info   = [@sprintf("t = %.0f yr, %.3f km²", t, MAGERES_SYMMETRY * a / 1e6) for (t, a) in zip(times, area)]
    traces = GenericTrace[bar(; y             = rows,
                                x             = frac[ph],
                                orientation   = "h",
                                name          = ph,
                                text          = info,
                                textposition  = "none",
                                hovertemplate = "%{x:.1f} vol%<br>%{text}<extra>$(ph)</extra>") for ph in phases]
    layout = Layout(; title        = @sprintf("Cumulate log: modal assemblage per piling event (%.3f km²)",
                                              MAGERES_SYMMETRY * sum(A[cells]) / 1e6),
                      height       = clamp(120 + 24 * n, 360, 900),
                      plot_bgcolor = "white",
                      barmode      = "stack",
                      bargap       = 0,
                      hovermode    = "closest",
                      xaxis        = attr(title = "vol% of solids", range = [0, 100], showline = true,
                                          linecolor = "black", mirror = true),
                      yaxis        = attr(title = "Piling event (oldest at the base)", tickmode = "array",
                                          tickvals = rows, ticktext = labels, range = [0.5, n + 0.5],
                                          showline = true, linecolor = "black", mirror = true),
                      legend       = attr(orientation = "h", y = -0.18))
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_composition_figure(times::Vector{Float64}, comps::Vector{Vector{Float64}}, oxides::Vector{String};
                               title = "Composition", anhydrous = false)

    Time series of the normalised oxide contents [mol%] of the non-empty compositions `comps`, skipping oxides
    that never exceed 0.05 mol%. With `anhydrous = true`, H2O is left out and the other oxides are renormalised.
"""
function mageres_composition_figure(times::Vector{Float64}, comps::Vector{Vector{Float64}}, oxides::Vector{String};
                                    title::AbstractString = "Composition", anhydrous::Bool = false)
    keep = [i for i in eachindex(comps) if !isempty(comps[i])]
    isempty(keep) && return mageres_placeholder_figure("$(title): nothing recorded yet"; height = 360)
    use  = [k for k in eachindex(oxides) if !(anhydrous && oxides[k] == "H2O")]
    tot  = Dict(i => sum(comps[i][k] for k in use) for i in keep)
    traces = GenericTrace[]
    for k in use
        y = [tot[i] > 0 ? 100 * comps[i][k] / tot[i] : 0.0 for i in keep]
        maximum(y) > 0.05 || continue
        push!(traces, scatter(; x      = times[keep],
                                y      = y,
                                name   = oxides[k],
                                mode   = "lines+markers",
                                marker = attr(size = 4)))
    end
    return PlotlyJS.plot(traces, mageres_series_layout(title, anhydrous ? "mol% (anhydrous)" : "mol%"; height = 360))
end

"""
    mageres_layer_times(c::MAGEResColumn)

    Time [yr] of every layer of column `c`.
"""
mageres_layer_times(c::MAGEResColumn) = [l.t for l in c.layers]

const MAGERES_TAS_FIELDS = (
    [35.0 0; 41 0; 41 7; 45 9.4; 48.4 11.5; 52.5 14; 48 16; 35 16; 35 0],
    [41.0 0; 45 0; 45 3; 41 3; 41 0],
    [41.0 3; 45 3; 45 5; 49.4 7.3; 45 9.4; 41 7; 41 3],
    [49.4 7.3; 53 9.3; 48.4 11.5; 45 9.4; 49.4 7.3],
    [53.0 9.3; 57.6 11.7; 52.5 14; 48.4 11.5; 53 9.3],
    [52.5 14; 57.6 11.7; 65 16; 48 16; 52.5 14],
    [45.0 0; 52 0; 52 5; 45 5; 45 0],
    [45.0 5; 52 5; 49.4 7.3; 45 5],
    [52.0 5; 57 5.9; 53 9.3; 49.4 7.3; 52 5],
    [57.0 5.9; 63 7; 57.6 11.7; 53 9.3; 57 5.9],
    [63.0 7; 69 8; 69 16; 65 16; 57.6 11.7; 63 7],
    [52.0 0; 57 0; 57 5.9; 52 5; 52 0],
    [57.0 0; 63 0; 63 7; 57 5.9; 57 0],
    [63.0 0; 77 0; 69 8; 63 7; 63 0],
    [77.0 0; 85 0; 85 16; 69 16; 69 8; 77 0],
)
const MAGERES_TAS_NAMES = ("foidite", "picrobasalt", "basanite", "phonotephrite", "tephriphonolite", "phonolite",
                           "basalt", "trachybasalt", "basaltic<br>trachyandesite", "trachyandesite", "trachyte",
                           "basaltic<br>andesite", "andesite", "dacite", "rhyolite")
const MAGERES_TAS_LABEL_SHIFT = Dict(1 => (-4.0, 3.0), 3 => (0.0, 1.0), 6 => (2.0, 0.0), 8 => (0.0, -0.25),
                                     9 => (0.0, 0.25))

"""
    mageres_tas_point(moles::Vector{Float64}, oxides::Vector{String})

    Anhydrous wt% of SiO2 and of Na2O + K2O for the oxide moles `moles`, or `nothing` when the composition is empty.
"""
function mageres_tas_point(moles::Vector{Float64}, oxides::Vector{String})
    isempty(moles) && return nothing
    wt  = [moles[k] * get(MAGERES_OXIDE_MOLAR_MASS, oxides[k], 0.0) for k in eachindex(oxides)]
    dry = sum(wt[k] for k in eachindex(oxides) if oxides[k] != "H2O")
    dry > 0 || return nothing
    pct(name) = (k = findfirst(==(name), oxides); k === nothing ? 0.0 : 100 * wt[k] / dry)
    return pct("SiO2"), pct("Na2O") + pct("K2O")
end

"""
    mageres_tas_figure(sources, oxides::Vector{String})

    Total alkali–silica (TAS) diagram, anhydrous wt%, of the composition series `sources`, a list of
    `(name, times, compositions, symbol, colour, line)` tuples; the chamber series is coloured by time.
"""
function mageres_tas_figure(sources, oxides::Vector{String})
    traces = GenericTrace[scatter(; x           = f[:, 1],
                                    y           = f[:, 2],
                                    mode        = "lines",
                                    hoverinfo   = "skip",
                                    legendgroup = "TAS fields",
                                    showlegend  = false,
                                    line        = attr(color = "black", width = 0.75)) for f in MAGERES_TAS_FIELDS]
    notes  = Any[]
    for (k, f) in enumerate(MAGERES_TAS_FIELDS)
        dx, dy = get(MAGERES_TAS_LABEL_SHIFT, k, (0.0, 0.0))
        push!(notes, attr(x         = sum(f[1:end-1, 1]) / (size(f, 1) - 1) + dx,
                          y         = sum(f[1:end-1, 2]) / (size(f, 1) - 1) + dy,
                          xref      = "x",
                          yref      = "y",
                          text      = MAGERES_TAS_NAMES[k],
                          showarrow = false,
                          font      = attr(size = 10, color = "#212121")))
    end
    for (name, times, comps, symbol, colour, line) in sources
        pts  = [(t, mageres_tas_point(c, oxides)) for (t, c) in zip(times, comps)]
        pts  = [(t, p) for (t, p) in pts if p !== nothing]
        isempty(pts) && continue
        tt   = [t for (t, _) in pts]
        mk   = colour === nothing ?
               attr(size = 8, symbol = symbol, color = tt, colorscale = "Viridis", showscale = true,
                    colorbar = attr(title = attr(text = "Chamber: time (yr)", side = "right"), thickness = 12,
                                    len = 0.6, x = 1.02)) :
               attr(size = 9, symbol = symbol, color = colour, line = attr(color = "black", width = 0.5))
        push!(traces, scatter(; x             = [p[1] for (_, p) in pts],
                                y             = [p[2] for (_, p) in pts],
                                mode          = line ? "lines+markers" : "markers",
                                name          = name,
                                text          = [@sprintf("%s, t = %.0f yr", name, t) for t in tt],
                                hovertemplate = "%{text}<br>SiO2 %{x:.1f} wt%<br>Na2O+K2O %{y:.2f} wt%<extra></extra>",
                                line          = attr(color = "rgb(120,120,120)", width = 1),
                                marker        = mk))
    end
    layout = Layout(; height       = 420,
                      title        = attr(text = "TAS diagram (anhydrous)", y = 0.98, yanchor = "top",
                                          font = attr(size = 14)),
                      xaxis        = attr(title = "SiO2 (wt%)", range = [35.0, 85.0], fixedrange = true,
                                          showline = true, linecolor = "black", mirror = true),
                      yaxis        = attr(title = "Na2O + K2O (wt%)", range = [0.0, 16.0], fixedrange = true,
                                          showline = true, linecolor = "black", mirror = true),
                      annotations  = notes,
                      legend       = attr(x = 0.01, y = 0.99, xanchor = "left", yanchor = "top",
                                          bgcolor = "rgba(255,255,255,0.85)", bordercolor = "#ccc", borderwidth = 1),
                      plot_bgcolor = "white",
                      margin       = attr(l = 60, r = 90, t = 36, b = 50))
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_layer_comps(c::MAGEResColumn)

    Oxide moles of every layer of column `c`.
"""
mageres_layer_comps(c::MAGEResColumn) = [l.moles for l in c.layers]

const MAGERES_REE           = ["La", "Ce", "Pr", "Nd", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"]
const MAGERES_TE_CHONDRITE  = ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm",
                               "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc", "Cs", "K", "Ti"]
const MAGERES_PPM_CHONDRITE = [2.3, 2.41, 0.029, 0.0074, 0.24, 0.0136, 0.237, 0.613, 2.47, 0.0928, 7.25, 0.457, 3.82,
                               0.103, 0.148, 0.0563, 0.199, 0.0361, 0.246, 1.57, 0.0546, 0.160, 0.0247, 0.161, 0.0246,
                               56.0, 5.92, 0.188, 558.0, 436.0]

"""
    mageres_eruption_te_figure(st::MAGEResState; t_from = -Inf, show = "ree", norm = "chondrite")

    Trace-element spectrum of the eruptions of `st` after `t_from` [yr], merged into one (bulk erupted material, Zr in
    zircon included), with the first injected magma dashed. `show` selects the rare earth elements ("ree") or
    all elements with a chondrite value ("all"); `norm` normalises to chondrite ("chondrite") or to the injected magma
    ("bulk"), on a log scale.
"""
function mageres_eruption_te_figure(st::MAGEResState; t_from::Float64 = -Inf, show::AbstractString = "ree",
                                    norm::AbstractString = "chondrite")
    te = mageres_te(st)
    te === nothing && return mageres_placeholder_figure("Trace elements are disabled"; height = 360)
    sel   = [l for l in st.pluton.layers if l.t > t_from]
    isempty(sel) && return mageres_placeholder_figure("No eruption during this output"; height = 360)
    Mox   = st.thermo.Mox
    names = show == "ree" ? MAGERES_REE : MAGERES_TE_CHONDRITE
    x     = [e for e in names if e in te.elements]
    idx   = [findfirst(==(e), te.elements) for e in x]
    C_inj = isempty(st.source.layers) ? te.C_injection[idx] : mageres_layer_te(st.source.layers[1], te, Mox)[idx]
    C_ref = norm == "bulk" ? C_inj : MAGERES_PPM_CHONDRITE[[findfirst(==(e), MAGERES_TE_CHONDRITE) for e in x]]
    ratio(C) = mageres_finite_or_nothing([r > 0 ? c / r : NaN for (c, r) in zip(C, C_ref)])
    traces = GenericTrace[scatter(; x = x, y = ratio(C_inj), name = "injected magma", mode = "lines",
                                    line = attr(color = "black", dash = "dash", width = 2))]
    l = MAGEResLayer(sel[end].t, sum(l.area for l in sel), sel[end].T, reduce(+, (l.moles for l in sel)),
                     reduce(+, (l.tracers for l in sel)))
    push!(traces, scatter(; x      = x,
                            y      = ratio(mageres_layer_te(l, te, Mox)[idx]),
                            name   = mageres_eruption_label(sel[1].t, l.t, length(sel)),
                            mode   = "lines+markers",
                            marker = attr(size = 5),
                            line   = attr(color = "rgb(204,102,20)", width = 1.5)))
    layout = Layout(; title        = "Erupted trace elements (bulk erupted material, Zr in zircon included)",
                      height       = 460,
                      plot_bgcolor = "white",
                      xaxis        = attr(title = show == "ree" ? "Rare Earth Elements" : "Trace Elements",
                                          showline = true, linecolor = "black", mirror = true),
                      yaxis        = attr(title = norm == "bulk" ? "C / injected magma" : "C / chondrite",
                                          type = "log", exponentformat = "power", showline = true, linecolor = "black",
                                          mirror = true),
                      legend       = attr(orientation = "v", x = 1.02, y = 1.0))
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_kde(x::Vector{Float64}, grid::AbstractVector{Float64}, h::Float64)

    Gaussian kernel density of the samples `x` with bandwidth `h` on `grid`.
"""
mageres_kde(x::Vector{Float64}, grid::AbstractVector{Float64}, h::Float64) =
    [sum(exp(-0.5 * ((g - xi) / h)^2) for xi in x; init = 0.0) / (length(x) * h * sqrt(2π)) for g in grid]

"""
    mageres_zircon_output_samples(st::MAGEResState, t_from::Float64)

    The eruptions of `st` after `t_from` [yr] that carry zircon, merged into one sample (in a vector) with ages before
    the reference time `t_ref` [yr], or a placeholder figure when zircon is not modelled or there is none.
"""
function mageres_zircon_output_samples(st::MAGEResState, t_from::Float64, t_ref::Float64)
    te = mageres_te(st)
    (te === nothing || !te.zircon) &&
        return mageres_placeholder_figure("Zircon requires trace elements with a Zr saturation model"; height = 360)
    samples = [s for s in mageres_zircon_samples(st; t_ref = t_ref) if s.t > t_from && s.inherited + sum(s.mass) > 0]
    isempty(samples) &&
        return mageres_placeholder_figure("No eruption carrying zircon during this output"; height = 360)
    return [mageres_combine_zircon_samples(samples, st.opts.zircon_synthetic_grains)]
end

"""
    mageres_age_panels_figure(samples, bin::Float64, title::AbstractString, groups::Function, note::Function;
                              bw = nothing, xlabel = "Age (kyr)", eruption = nothing)

    One panel per zircon sample against age before eruption [kyr]: histogram of the ages returned by `groups(s)` as
    `(name, colour, ages)` series, stacked and binned by `bin` [kyr] (number, left axis), with the kernel density of
    all of them (relative probability, right axis; bandwidth `bw` [kyr], or Silverman's rule kept within bin/4–bin)
    and the panel label `note(s)`. `eruption(s)` gives the age range [kyr] of the sample's eruptions, shaded in grey.
"""
function mageres_age_panels_figure(samples, bin::Float64, title::AbstractString, groups::Function, note::Function;
                                   bw::Union{Nothing,Float64} = nothing, xlabel::AbstractString = "Age (kyr)",
                                   eruption = nothing)
    series = [groups(s) for s in samples]
    allage = [reduce(vcat, (g[3] for g in gs); init = Float64[]) for gs in series]
    x_lo   = bin * (floor(min(0.0, minimum(minimum(a; init = 0.0) for a in allage)) / bin) - 1)
    x_max  = bin * (floor(maximum(maximum(a; init = 0.0) for a in allage) / bin) + 2)
    edges  = collect(x_lo:bin:x_max)
    mids   = edges[1:end-1] .+ bin / 2
    grid   = collect(range(x_lo, x_max; length = 400))
    n      = length(samples)
    gap    = n > 1 ? 0.06 / (n - 1) * (n > 4 ? 2 : 1) : 0.0
    h_p    = (1 - gap * (n - 1)) / n
    ax(i)  = i == 1 ? "" : string(i)
    multi  = maximum(length.(series)) > 1
    traces = GenericTrace[]
    layout = Layout(; title        = title,
                      height       = clamp(120 + 230 * n, 360, 4000),
                      plot_bgcolor = "white",
                      bargap       = 0.0,
                      barmode      = "stack",
                      showlegend   = multi,
                      legend       = attr(orientation = "h", y = -60 / clamp(120 + 230 * n, 360, 4000)),
                      margin       = attr(l = 70, r = 80, t = 50, b = 70),
                      xaxis        = attr(title = xlabel, range = [x_lo, x_max], showline = true,
                                          linecolor = "black", mirror = true, ticks = "outside",
                                          anchor = "y$(ax(2n-1))"))
    notes  = []
    shapes = []
    shown  = Set{String}()
    for (k, s) in enumerate(samples)
        a, b = 2k - 1, 2k
        top  = 1 - (k - 1) * (h_p + gap)
        if eruption !== nothing
            lo, hi = eruption(s)
            push!(shapes, attr(type = "rect", name = "Eruptions", xref = "x", yref = "paper",
                               x0 = lo - 0.002 * (x_max - x_lo),
                               x1 = hi + 0.002 * (x_max - x_lo), y0 = top - h_p, y1 = top, line = attr(width = 0),
                               fillcolor = "rgba(200,40,40,0.25)", layer = "below"))
        end
        for (name, col, ages) in series[k]
            cnt = [count(g -> edges[j] <= g < edges[j+1], ages) for j in eachindex(mids)]
            push!(traces, bar(; x = mids, y = cnt, width = bin, xaxis = "x", yaxis = "y$(ax(a))", name = name,
                                legendgroup = name, showlegend = multi && !(name in shown),
                                marker = attr(color = col, line = attr(color = "rgb(20,20,20)", width = 0.8)),
                                hovertemplate = "%{x:.2f} kyr: %{y}<extra>$(name)</extra>"))
            push!(shown, name)
        end
        g = allage[k]
        if length(g) >= 2
            m  = sum(g) / length(g)
            sd = sqrt(sum((g .- m) .^ 2) / (length(g) - 1))
            h  = bw === nothing ? clamp(1.06 * sd * length(g)^(-0.2), bin / 4, bin) : bw
            d  = mageres_kde(g, grid, h)
            maximum(d) > 0 && (d ./= maximum(d))
            push!(traces, scatter(; x = grid, y = d, mode = "lines", xaxis = "x", yaxis = "y$(ax(b))",
                                    name = "kernel density", showlegend = false,
                                    line = attr(color = "black", width = 1.5), hoverinfo = "skip"))
        end
        layout[Symbol("yaxis$(ax(a))")] = attr(title = "Number", domain = [top - h_p, top], rangemode = "tozero",
                                               showline = true, linecolor = "black", ticks = "outside",
                                               anchor = "x")
        layout[Symbol("yaxis$(ax(b))")] = attr(title = "Relative probability", overlaying = "y$(ax(a))",
                                               side = "right", range = [0.0, 1.1], showgrid = false,
                                               showline = true, linecolor = "black", ticks = "outside")
        push!(notes, attr(x = 0.99, xref = "paper", xanchor = "right", y = top - 0.01, yref = "paper",
                          yanchor = "top", showarrow = false, align = "right", bgcolor = "rgba(255,255,255,0.85)",
                          bordercolor = "#ccc", borderwidth = 1, font = attr(size = 11), text = note(s)))
    end
    layout[:annotations] = notes
    layout[:shapes]      = shapes
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_age_axis(t_ref::Float64)

    Label of the age axis: kyr before the reference time `t_ref` [yr].
"""
mageres_age_axis(t_ref::Float64) = @sprintf("Age before t = %.1f kyr (kyr)", t_ref / 1e3)

"""
    mageres_eruption_ages(s::MAGEResZirconSample, t_ref::Float64)

    Age range [kyr] of the eruptions of sample `s` before the reference time `t_ref` [yr].
"""
mageres_eruption_ages(s::MAGEResZirconSample, t_ref::Float64) = ((t_ref - s.t) / 1e3, (t_ref - s.t_first) / 1e3)

"""
    mageres_eruption_band(s::MAGEResZirconSample, t_ref::Float64)

    Horizontal band (y = age) marking the eruptions of `s` on an age axis before `t_ref` [yr].
"""
mageres_eruption_band(s::MAGEResZirconSample, t_ref::Float64) =
    ((lo, hi) = mageres_eruption_ages(s, t_ref);
     attr(type = "rect", name = "Eruptions", xref = "paper", yref = "y", x0 = 0, x1 = 1, y0 = lo - 0.05, y1 = hi + 0.05,
          line = attr(width = 0), fillcolor = "rgba(200,40,40,0.25)", layer = "below"))

"""
    mageres_method_label(o::MAGEResOptions)

    Name and 1σ uncertainty of the synthetic dating method of `o`.
"""
mageres_method_label(o::MAGEResOptions) =
    o.zircon_method == "SIMS_UTh" ? @sprintf("SIMS U-Th, 1σ = %.1f kyr", o.zircon_sigma_kyr) :
    o.zircon_method == "LA_UPb"   ? @sprintf("LA-ICP-MS U-Pb, 1σ = 1 %% of %.2f Ma", o.zircon_eruption_age_Ma) :
                                    @sprintf("CA-ID-TIMS U-Pb, 1σ = 0.05 %% of %.2f Ma", o.zircon_eruption_age_Ma)

"""
    mageres_weighted_mean(x::Vector{Float64}, s::Vector{Float64})

    Inverse-variance weighted mean of `x` with 1σ `s`, its 1σ uncertainty and the MSWD.
"""
function mageres_weighted_mean(x::Vector{Float64}, s::Vector{Float64})
    w  = 1 ./ s .^ 2
    mu = sum(w .* x) / sum(w)
    return mu, 1 / sqrt(sum(w)), length(x) > 1 ? sum(w .* (x .- mu) .^ 2) / (length(x) - 1) : NaN
end

"""
    mageres_zircon_rank_figure(st::MAGEResState; t_from = -Inf, t_ref = st.t)

    Rank-order plot of the synthetic single-spot zircon ages of the eruptions of `st` after `t_from` [yr]: ages before
    the reference time `t_ref` [yr] (the latest output) sorted from youngest to oldest with 2σ analytical error bars,
    the eruptions shaded, and the weighted mean with its MSWD.
"""
function mageres_zircon_rank_figure(st::MAGEResState; t_from::Float64 = -Inf, t_ref::Float64 = st.t)
    samples = mageres_zircon_output_samples(st, t_from, t_ref)
    samples isa Vector || return samples
    s = samples[1]
    isempty(s.grains) && return mageres_placeholder_figure("Only inherited zircon in this output"; height = 360)
    o          = st.opts
    p          = sortperm(s.grains)
    x          = collect(1:length(p))
    mu, se, ms = mageres_weighted_mean(s.grains, s.sigma)
    traces = GenericTrace[
        scatter(; x = [0.5, length(p) + 0.5], y = [mu, mu], mode = "lines", name = "weighted mean",
                  line = attr(color = "rgb(200,40,40)", dash = "dash")),
        scatter(; x = x, y = s.grains[p], mode = "markers", name = "single spots",
                  marker = attr(color = "rgb(0,114,189)", size = 6, line = attr(color = "black", width = 0.5)),
                  error_y = attr(type = "data", array = 2 .* s.sigma[p], visible = true, color = "rgb(90,90,90)",
                                 thickness = 1, width = 0),
                  hovertemplate = "%{y:.2f} kyr<extra></extra>"),
    ]
    note = mageres_eruption_label(s.t_first, s.t, s.n_eruptions) *
           @sprintf("<br>%d grains + %d inherited (%.0f Ma)<br>weighted mean %.2f ± %.2f kyr (2σ), MSWD = %.1f",
                    length(s.grains), s.n_inherited, o.zircon_inherited_age_Ma, mu, 2se, ms)
    title  = "Zircon rank-order plot (synthetic single spots, $(mageres_method_label(o)), error bars 2σ)"
    layout = Layout(; title        = title,
                      height       = 460,
                      plot_bgcolor = "white",
                      showlegend   = true,
                      legend       = attr(orientation = "h", y = -0.18),
                      xaxis        = attr(title = "Rank", showline = true, linecolor = "black", mirror = true,
                                          ticks = "outside", zeroline = false),
                      yaxis        = attr(title = mageres_age_axis(t_ref), showline = true, linecolor = "black",
                                          mirror = true, ticks = "outside", zeroline = false),
                      shapes       = [mageres_eruption_band(s, t_ref)],
                      annotations  = [attr(x = 0.01, xref = "paper", xanchor = "left", y = 0.99, yref = "paper",
                                           yanchor = "top", showarrow = false, align = "left", text = note,
                                           bgcolor = "rgba(255,255,255,0.85)", bordercolor = "#ccc", borderwidth = 1,
                                           font = attr(size = 11))])
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_zircon_age_figure(st::MAGEResState; t_from = -Inf, t_ref = st.t)

    Histogram and kernel density of the synthetic single-spot zircon ages of the eruptions of `st` after `t_from` [yr],
    before the reference time `t_ref` [yr], binned by twice the median analytical 1σ, with a kernel bandwidth of one
    median 1σ; the eruptions are shaded.
"""
function mageres_zircon_age_figure(st::MAGEResState; t_from::Float64 = -Inf, t_ref::Float64 = st.t)
    samples = mageres_zircon_output_samples(st, t_from, t_ref)
    samples isa Vector || return samples
    inh = st.opts.zircon_inherited_age_Ma
    sg  = sort(samples[1].sigma)
    sm  = isempty(sg) ? mageres_te(st).bin_yr / 1e3 : sg[(length(sg) + 1) ÷ 2]
    return mageres_age_panels_figure(samples, 2sm,
                                     "Zircon age distribution (synthetic single spots, bins 2σ, kernel bandwidth 1σ)",
                                     s -> [("grains", "rgb(0,114,189)", s.grains)],
                                     s -> mageres_eruption_label(s.t_first, s.t, s.n_eruptions) *
                                          @sprintf("<br>%d grains, %d inherited (%.0f Ma)",
                                                   length(s.grains) + s.n_inherited, s.n_inherited, inh);
                                     bw       = sm,
                                     xlabel   = mageres_age_axis(t_ref),
                                     eruption = s -> mageres_eruption_ages(s, t_ref))
end

const MAGERES_SPOT_COUNT_COLORS = ["rgb(0,114,189)", "rgb(230,180,30)", "rgb(60,160,60)", "rgb(210,80,80)"]

"""
    mageres_zircon_spot_figure(st::MAGEResState; t_from = -Inf, t_ref = st.t)

    Core-to-rim spot analyses of the synthetic zoned grains erupted after `t_from` [yr] (spots of the analytical spot
    size): one column per grain, ranked by core age, its spots joined from core (circle) to rim (diamond) with 2σ
    error bars, coloured by the number of spots on the grain, ages before the reference time `t_ref` [yr] with the
    eruptions shaded. Spots dominated by inherited zircon are counted in the label.
"""
function mageres_zircon_spot_figure(st::MAGEResState; t_from::Float64 = -Inf, t_ref::Float64 = st.t)
    samples = mageres_zircon_output_samples(st, t_from, t_ref)
    samples isa Vector || return samples
    s      = samples[1]
    gr     = [g for g in s.zoned if any(isfinite, g.ages)]
    isempty(gr) && return mageres_placeholder_figure("No dated zoned grain in this output"; height = 360)
    core(g) = (i = findfirst(isfinite, g.ages); g.ages[i])
    gr     = sort(gr; by = g -> -core(g))
    label  = ["1 spot per grain", "2 spots per grain", "3 spots per grain", "≥ 4 spots per grain"]
    traces = GenericTrace[]
    shown  = falses(4)
    for (k, g) in enumerate(gr)
        c  = min(length(g.ages), 4)
        ok = findall(isfinite, g.ages)
        push!(traces, scatter(; x = fill(k, length(ok)), y = g.ages[ok], mode = "lines+markers",
                                name = label[c], legendgroup = label[c], showlegend = !shown[c],
                                line = attr(color = MAGERES_SPOT_COUNT_COLORS[c], width = 1),
                                marker = attr(color = MAGERES_SPOT_COUNT_COLORS[c], size = 6,
                                              symbol = [i == ok[1] ? "circle" : "diamond" for i in ok],
                                              line = attr(color = "black", width = 0.5)),
                                error_y = attr(type = "data", array = 2 .* g.sigma[ok], visible = true,
                                               color = MAGERES_SPOT_COUNT_COLORS[c], thickness = 1, width = 0),
                                hovertemplate = "%{y:.2f} kyr<extra>grain $(k)</extra>"))
        shown[c] = true
    end
    nsp  = sum(length(g.ages) for g in s.zoned; init = 0)
    ninh = sum(count(isnan, g.ages) for g in s.zoned; init = 0)
    note = mageres_eruption_label(s.t_first, s.t, s.n_eruptions) *
           @sprintf("<br>%d grains, %d spots, %d inherited or mixed", length(s.zoned), nsp, ninh)
    layout = Layout(; title        = @sprintf("Zircon core-to-rim analyses (%.0f µm spots, %s, error bars 2σ)",
                                              st.opts.zircon_spot_um, mageres_method_label(st.opts)),
                      height       = 460,
                      plot_bgcolor = "white",
                      legend       = attr(orientation = "h", y = -0.18),
                      xaxis        = attr(title = "Grain (ranked by core age)", showline = true, linecolor = "black",
                                          mirror = true, ticks = "outside", zeroline = false),
                      yaxis        = attr(title = mageres_age_axis(t_ref), showline = true, linecolor = "black",
                                          mirror = true, ticks = "outside", zeroline = false),
                      shapes       = [mageres_eruption_band(s, t_ref)],
                      annotations  = [attr(x = 0.99, xref = "paper", xanchor = "right", y = 0.99, yref = "paper",
                                           yanchor = "top", showarrow = false, align = "right", text = note,
                                           bgcolor = "rgba(255,255,255,0.85)", bordercolor = "#ccc", borderwidth = 1,
                                           font = attr(size = 11))])
    return PlotlyJS.plot(traces, layout)
end

"""
    mageres_zircon_outline(x0::Float64, y0::Float64, w::Float64, l::Float64)

    SVG path of a zircon outline (prism with pyramidal ends) of half-width `w` and half-length `l` centred at
    (`x0`, `y0`).
"""
function mageres_zircon_outline(x0::Float64, y0::Float64, w::Float64, l::Float64)
    p = [(0.0, l), (w, l - w), (w, -(l - w)), (0.0, -l), (-w, -(l - w)), (-w, l - w)]
    return "M " * join((@sprintf("%.3f %.3f", x0 + x, y0 + y) for (x, y) in p), " L ") * " Z"
end

"""
    mageres_zircon_family_figure(st::MAGEResState; t_from = -Inf, t_ref = st.t)

    Illustration of the zircon families erupted after `t_from` [yr]: one representative grain per family (from the
    latest eruption carrying it), drawn to scale as a prism with its growth zones shaded like a CL image, the
    analysed spots with their ages, and a 100 µm scale bar.
"""
function mageres_zircon_family_figure(st::MAGEResState; t_from::Float64 = -Inf, t_ref::Float64 = st.t)
    samples = mageres_zircon_output_samples(st, t_from, t_ref)
    samples isa Vector || return samples
    te   = mageres_te(st)
    d    = st.opts.zircon_spot_um
    reps = Dict{Int,MAGEResZirconGrain}()
    for s in samples, g in s.zoned
        reps[g.family] = g
    end
    isempty(reps) && return mageres_placeholder_figure("No zoned grain in this output"; height = 360)
    fams   = sort(collect(keys(reps)))
    shapes = []
    notes  = []
    x0     = 0.0
    y_min  = 0.0
    y_max  = 0.0
    for f in fams
        g     = reps[f]
        a     = g.radius
        gname = "Grain_" * replace(mageres_zircon_family_label(te, f), r"[^A-Za-z0-9.]+" => "_")
        L  = 2a
        xc = x0 + a
        rs = g.zones
        for j in length(rs):-1:1
            (j == 1 || rs[j] > rs[j-1] + 1e-9) || continue
            sc = rs[j] / a
            v  = j == 1 && f == 1 ? 45 : round(Int, 95 + 110 * (j - 1) / max(length(rs) - 1, 1) + (isodd(j) ? 22 : -22))
            v  = clamp(v, 20, 235)
            push!(shapes, attr(type = "path", name = gname, path = mageres_zircon_outline(xc, 0.0, sc * a, sc * L),
                               fillcolor = "rgb($v,$v,$v)", line = attr(color = "rgba(30,30,30,0.35)", width = 0.4)))
        end
        push!(shapes, attr(type = "path", name = gname, path = mageres_zircon_outline(xc, 0.0, a, L),
                           fillcolor = "rgba(0,0,0,0)",
                           line = attr(color = "black", width = 1.2)))
        for (k, r) in enumerate(g.spot_r)
            yc = r / a * L
            rr = min(d / 2, a)
            push!(shapes, attr(type = "circle", name = gname, x0 = xc - rr, x1 = xc + rr, y0 = yc - rr, y1 = yc + rr,
                               line = attr(color = "rgb(220,30,30)", width = 2, dash = "dash")))
            push!(notes, attr(name = gname, x = xc + a + 4, y = yc, xanchor = "left", showarrow = false,
                              font = attr(size = 10),
                              text = isnan(g.ages[k]) ? "inherited" : @sprintf("%.2f kyr", g.ages[k])))
        end
        push!(notes, attr(name = gname, x = xc, y = -L - 6, yanchor = "top", showarrow = false, font = attr(size = 11),
                          text = @sprintf("<b>%s</b><br>r = %.0f µm", mageres_zircon_family_label(te, f), a)))
        x0   += 2a + max(70.0, 0.6 * a)
        y_min = min(y_min, -L)
        y_max = max(y_max, L)
    end
    sb_y = y_min - 45
    push!(shapes, attr(type = "line", name = "Scale", x0 = x0 - 100 - 20, x1 = x0 - 20, y0 = sb_y, y1 = sb_y,
                       line = attr(color = "black", width = 3)))
    push!(notes, attr(name = "Scale", x = x0 - 70, y = sb_y - 4, yanchor = "top", showarrow = false, text = "100 µm"))
    push!(shapes, attr(type = "circle", name = "Scale", x0 = 0, x1 = d, y0 = sb_y - d / 2, y1 = sb_y + d / 2,
                       line = attr(color = "rgb(220,30,30)", width = 2, dash = "dash")))
    push!(notes, attr(name = "Scale", x = d + 4, y = sb_y, xanchor = "left", showarrow = false,
                      text = @sprintf("= analytical spot (%.0f µm)", d)))
    layout = Layout(; title        = "Zircon families (one representative grain per family, zones shaded as in CL)",
                      height       = 560,
                      plot_bgcolor = "white",
                      shapes       = shapes,
                      annotations  = notes,
                      showlegend   = false,
                      margin       = attr(l = 20, r = 20, t = 50, b = 20),
                      xaxis        = attr(visible = false, range = [-20.0, x0 + 20]),
                      yaxis        = attr(visible = false, range = [sb_y - 30, y_max + 20], scaleanchor = "x"))
    return PlotlyJS.plot([scatter(; name = "Anchor", x = [0.0], y = [0.0], mode = "markers", marker = attr(opacity = 0),
                                    hoverinfo = "skip")], layout)
end

"""
    mageres_svg_cells(st::MAGEResState, field::Symbol)

    Underlay of the SVG export of the map of `field`: every model cell, and its mirror image across the symmetry axis,
    as a rectangle coloured like the map and clipped to the axes. Returns a function `(io, X, Y, seen) -> count`.
"""
function mageres_svg_cells(st::MAGEResState, field::Symbol)
    v, (zmin, zmax), _, cs, rev = mageres_field_values(st, field)
    stops = svg_colorscale(cs; reverse = rev)
    g     = st.grid
    ax    = mageres_axis_x(st.opts)
    return function (io, X, Y, seen)
        xlo, xhi = min(X.lo, X.hi), max(X.lo, X.hi)
        ylo, yhi = min(Y.lo, Y.hi), max(Y.lo, Y.hi)
        n = 0
        for c in 1:mageres_ncells(g)
            x0, x1, y0, y1 = mageres_cell_bounds(g, g.leaves[c])
            d0, d1 = mageres_depth_km(st, y1), mageres_depth_km(st, y0)
            (d1 <= ylo || d0 >= yhi) && continue
            rc   = svg_color_at(stops, clamp((v[c] - zmin) / max(zmax - zmin, 1e-300), 0.0, 1.0))
            fill = "rgb($(round(Int, rc[1])),$(round(Int, rc[2])),$(round(Int, rc[3])))"
            for (a1, a2) in ((x0 / 1e3, x1 / 1e3), ((2ax - x1) / 1e3, (2ax - x0) / 1e3))
                (a2 <= xlo || a1 >= xhi) && continue
                p1, p2 = gaxis_px(X, clamp(a1, xlo, xhi)), gaxis_px(X, clamp(a2, xlo, xhi))
                q1, q2 = gaxis_px(Y, clamp(d0, ylo, yhi)), gaxis_px(Y, clamp(d1, ylo, yhi))
                println(io, "<rect x=\"$(svg_num(min(p1, p2)))\" y=\"$(svg_num(min(q1, q2)))\" ",
                            "width=\"$(svg_num(abs(p2 - p1) + 0.2))\" height=\"$(svg_num(abs(q2 - q1) + 0.2))\" ",
                            "fill=\"$(fill)\"/>")
                n += 1
            end
        end
        return n
    end
end
