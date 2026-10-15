const SUBD_YEAR_S  = 365.0 * 24.0 * 3600.0
const SUBD_G       = 9.81
const SUBD_TRACES  = Dict{String,Vector{GenericTrace}}("pd" => GenericTrace[], "te" => GenericTrace[])

function subd_erf(x::Float64)
    t = 1.0 / (1.0 + 0.5 * abs(x))
    τ = t * exp(-x * x - 1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 +
            t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))))
    return x >= 0.0 ? 1.0 - τ : τ - 1.0
end

function subd_T_slab(x, y, T0, T1, h, d, kappa, v)
    denom = sqrt(4 * y * kappa / v)
    a = x / denom
    b = (x - h) / denom
    e = (x + d) / denom
    f = a
    s = sqrt(kappa * y / (v * π))

    term1 = (x - h) / 2 * (subd_erf(-b) - subd_erf(-a)) - s * (exp(-b^2) - exp(-a^2))
    term2 = (x + d) / 2 * (subd_erf(-e) - subd_erf(-f)) - s * (exp(-e^2) - exp(-f^2))

    return T1 + ((T1 - T0) / h) * term1 + ((T1 - T0) / d) * term2
end

function subd_parse_velocities(str)
    str === nothing && return Float64[]
    vals = Float64[]
    for tok in split(string(str), r"[,;\s]+"; keepempty = false)
        v = tryparse(Float64, tok)
        v !== nothing && v > 0 && push!(vals, v)
    end
    return sort(unique(vals))
end

subd_num(x, default) = x isa Real ? Float64(x) : something(tryparse(Float64, string(x)), default)

function subd_color(k, n)
    t  = n == 1 ? 0.0 : (k - 1) / (n - 1)
    c1 = (178, 24, 43)
    c2 = (33, 102, 172)
    r, g, b = (round(Int, c1[i] + t * (c2[i] - c1[i])) for i in 1:3)
    return "rgb($r,$g,$b)"
end

function subduction_geotherm_traces(vels_str, dip, depth_km, T0, T1, h_km, d_km, kappa, rho, Xrange, Yrange; n = 300)
    vels  = subd_parse_velocities(vels_str)
    traces = GenericTrace[]
    isempty(vels) && return traces

    θ      = deg2rad(clamp(subd_num(dip, 30.0), 1.0, 89.0))
    d      = max(subd_num(d_km, 80.0), 1.0) * 1e3
    h      = max(subd_num(h_km, 20.0), 1.0) * 1e3
    o      = clamp(subd_num(depth_km, 0.0) * 1e3, 0.0, d)
    T0c    = subd_num(T0, 0.0)
    T1c    = subd_num(T1, 1300.0)
    κ      = max(subd_num(kappa, 1e-6), 1e-12)
    ρ      = max(subd_num(rho, 3300.0), 1.0)
    kbar_m = ρ * SUBD_G / 1e8

    xmin, xmax = minmax(Float64(Xrange[1]), Float64(Xrange[2]))
    pmin, pmax = minmax(Float64(Yrange[1]), Float64(Yrange[2]))
    zoff   = o * cos(θ)
    zmin   = max(pmin / kbar_m, zoff + 1.0)
    zmax   = pmax / kbar_m
    zmax <= zmin && return traces

    zs = range(zmin, zmax; length = n)
    ss = [(z - zoff) / sin(θ) for z in zs]

    for (k, vcm) in enumerate(vels)
        v  = vcm * 1e-2 / SUBD_YEAR_S
        T  = [subd_T_slab(-o, s, T0c, T1c, h, d, κ, v) for s in ss]
        P  = [z * kbar_m for z in zs]
        keep = findall(i -> xmin <= T[i] <= xmax, eachindex(T))
        isempty(keep) && continue
        Tk, Pk, zk = T[keep], P[keep], collect(zs)[keep]
        lbl  = fill("", length(Tk))
        lbl[end] = "$(subd_fmt(vcm)) cm/yr"
        hov  = ["v = $(subd_fmt(vcm)) cm/yr<br>depth into slab = $(subd_fmt(o / 1e3)) km<br>z = $(round(zk[i] / 1e3, digits = 1)) km<br>T = $(round(Tk[i], digits = 1)) °C"
                for i in eachindex(Tk)]
        col  = subd_color(k, length(vels))
        push!(traces, scatter(; x = Tk, y = Pk, mode = "lines+text", text = lbl, hovertext = hov, hoverinfo = "text",
                                textposition = "bottom right", textfont = attr(color = col, size = 11),
                                line = attr(color = col, width = 2, dash = "dash"),
                                name = "Geotherm $(subd_fmt(vcm)) cm/yr", showlegend = false))
    end
    return traces
end

subd_fmt(x) = isinteger(x) ? string(Int(x)) : string(round(x, digits = 2))

function subduction_geotherm_update!(key, show, vels_str, dip, depth_km, T0, T1, h_km, d_km, kappa, rho, Xrange, Yrange, diagType)
    SUBD_TRACES[key] = (show == "true" && diagType == "pt") ?
        subduction_geotherm_traces(vels_str, dip, depth_km, T0, T1, h_km, d_km, kappa, rho, Xrange, Yrange) : GenericTrace[]
    return SUBD_TRACES[key]
end

function subd_svg_lines(traces, yconv)
    out = NamedTuple[]
    for t in traces
        ln = t[:line]
        push!(out, (name  = string(t[:name]), x = collect(Float64, t[:x]), y = [yconv(v) for v in t[:y]],
                    color = string(ln[:color]), dash = string(ln[:dash]), width = Float64(ln[:width]),
                    label = string(t[:text][end])))
    end
    return out
end

subd_ids(sfx) = (show  = "subd-show"*sfx,  vel   = "subd-vel"*sfx,   dip   = "subd-dip"*sfx,   depth = "subd-depth"*sfx,
                 adv   = "subd-adv-btn"*sfx, coll = "subd-adv-collapse"*sfx,
                 T0    = "subd-T0"*sfx,    T1    = "subd-T1"*sfx,    h     = "subd-h"*sfx,     d     = "subd-d"*sfx,
                 kappa = "subd-kappa"*sfx, rho   = "subd-rho"*sfx)

subd_inputs(sfx)  = (ids = subd_ids(sfx); [Input(ids.show, "value"), Input(ids.vel, "value"), Input(ids.dip, "value"), Input(ids.depth, "value"),
                                            Input(ids.T0, "value"), Input(ids.T1, "value"), Input(ids.h, "value"), Input(ids.d, "value"),
                                            Input(ids.kappa, "value"), Input(ids.rho, "value")])

subd_input_ids(sfx) = (ids = subd_ids(sfx); [ids.show, ids.vel, ids.dip, ids.depth, ids.T0, ids.T1, ids.h, ids.d, ids.kappa, ids.rho])

function subd_row(label, control)
    return dbc_row([
        dbc_col([html_h1(label, style = Dict("textAlign" => "center", "font-size" => "120%", "marginTop" => 8))], width = 5),
        dbc_col([control]),
    ])
end

subd_number(id, value; min = nothing, max = nothing, step = "any") =
    dbc_input(id = id, type = "number", value = value, min = min, max = max, step = step, debounce = true)

function subduction_geotherm_ui(sfx)
    ids = subd_ids(sfx)
    return html_div([
        html_h1("Slab geotherms", style = Dict("textAlign" => "center", "font-size" => "120%", "marginTop" => 8)),
        html_hr(),
        subd_row("Show geotherms", dcc_dropdown(id = ids.show, options = ["true", "false"], value = "false", clearable = false, multi = false)),
        subd_row("Velocities [cm/yr]", dbc_input(id = ids.vel, type = "text", value = "1, 2, 5, 10", debounce = true)),
        subd_row("Slab dip [°]", subd_number(ids.dip, 30; min = 1, max = 89)),
        subd_row("Depth into slab [km]", subd_number(ids.depth, 0; min = 0)),
        dbc_row([
            dbc_button("Advanced", id = ids.adv, color = "light", className = "me-2", n_clicks = 0,
                        style = Dict("textAlign" => "center", "font-size" => "100%", "border" => "1px grey solid", "width" => "50%", "marginTop" => 8)),
        ], justify = "center"),
        dbc_collapse(html_div([
            subd_row("Surface T [°C]",      subd_number(ids.T0, 0)),
            subd_row("Mantle T [°C]",       subd_number(ids.T1, 1300)),
            subd_row("Upper plate h [km]",  subd_number(ids.h, 20; min = 1)),
            subd_row("Slab thickness d [km]", subd_number(ids.d, 80; min = 1)),
            subd_row("κ [m²/s]",            subd_number(ids.kappa, 1e-6; min = 0)),
            subd_row("ρ [kg/m³]",           subd_number(ids.rho, 3300; min = 1)),
        ]), id = ids.coll, is_open = false),
    ])
end

subduction_geotherm_tab(sfx) = dbc_tab(label = "Slab geotherms", children = [
    dbc_card(dbc_cardbody([subduction_geotherm_ui(sfx)])),
])

function subduction_geotherm_callbacks!(app, sfx)
    ids = subd_ids(sfx)
    callback!(
        app,
        Output(ids.coll, "is_open"),
        Input(ids.adv,   "n_clicks"),
        State(ids.coll,  "is_open"),
        prevent_initial_call = true,
    ) do n, is_open
        return n > 0 ? is_open == 0 : is_open
    end
    return app
end

subd_3d_ids() = (render = "subd-render-3d", xvals = "subd-xvals-3d", opacity = "subd-opacity-3d")

function subduction_geotherm_tab_3d()
    ids = subd_3d_ids()
    return dbc_tab(label = "Slab geotherms", tab_id = "pd3d-tab-geotherm", children = [
        dbc_card(dbc_cardbody([
            subduction_geotherm_ui("-3d"),
            html_hr(),
            subd_row("Render as", dcc_dropdown(id = ids.render, options = [(label = "Wall across X", value = "wall"), (label = "Lines at X values", value = "lines")],
                                               value = "wall", clearable = false)),
            subd_row("X values", dbc_input(id = ids.xvals, type = "text", value = "", debounce = true, placeholder = "e.g. 0, 0.5, 1 (empty: X ends)")),
            subd_row("Wall opacity", subd_number(ids.opacity, 0.25; min = 0.05, max = 1.0, step = 0.05)),
        ])),
    ])
end

subd_inputs_3d() = (ids = subd_3d_ids(); vcat(subd_inputs("-3d"), [Input(ids.render, "value"), Input(ids.xvals, "value"), Input(ids.opacity, "value")]))

function subduction_geotherm_traces_3d(st, show, vels_str, dip, depth_km, T0, T1, h_km, d_km, kappa, rho, render, xvals_str, opacity)
    show == "true" || return GenericTrace[]
    tr2d = subduction_geotherm_traces(vels_str, dip, depth_km, T0, T1, h_km, d_km, kappa, rho,
                                      (st.Tv[1], st.Tv[end]), (st.Pv[1], st.Pv[end]))
    x0, x1 = minmax(st.Xv[1], st.Xv[end])
    xs     = filter(x -> x0 <= x <= x1, subd_parse_values(xvals_str))
    isempty(xs) && (xs = [x0, x1])
    wall   = render != "lines"
    wall && (xs = [x0, x1])
    α      = clamp(subd_num(opacity, 0.25), 0.05, 1.0)
    out    = GenericTrace[]
    for t in tr2d
        T, P = collect(Float64, t[:x]), display_pressure(collect(Float64, t[:y]))
        n    = length(T)
        col  = t[:line][:color]
        name = replace(string(t[:name]), "Geotherm " => "")
        grp  = "geotherm_" * name
        hov  = t[:hovertext]
        if wall && n >= 2
            push!(out, mesh3d(x = vcat(P, P), y = vcat(T, T), z = vcat(fill(x0, n), fill(x1, n)),
                              i = vcat([k - 1 for k in 1:n-1], [k for k in 1:n-1]),
                              j = vcat([k for k in 1:n-1], [n + k for k in 1:n-1]),
                              k = vcat([n + k - 1 for k in 1:n-1], [n + k - 1 for k in 1:n-1]),
                              color = col, opacity = α, flatshading = true, hoverinfo = "skip",
                              legendgroup = grp, showlegend = false, name = "Geotherm $name"))
        end
        for (m, xv) in enumerate(xs)
            push!(out, scatter3d(x = P, y = T, z = fill(xv, n), mode = "lines", line = attr(color = col, width = 5),
                                 hovertext = hov, hoverinfo = "text", legendgroup = grp, showlegend = m == 1,
                                 name = "Geotherm $name"))
        end
        push!(out, scatter3d(x = [P[end]], y = [T[end]], z = [xs[end]], mode = "text", text = [name],
                             textposition = "top center", textfont = attr(color = col, size = 11),
                             hoverinfo = "skip", legendgroup = grp, showlegend = false))
    end
    return out
end

function subd_parse_values(str)
    str === nothing && return Float64[]
    vals = Float64[]
    for tok in split(string(str), r"[,;\s]+"; keepempty = false)
        v = tryparse(Float64, tok)
        v !== nothing && push!(vals, v)
    end
    return sort(unique(vals))
end
