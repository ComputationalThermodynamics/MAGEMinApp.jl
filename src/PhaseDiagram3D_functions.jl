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

mutable struct PD3D_state
    dtb         :: String
    oxi         :: Vector{String}
    bulk_L      :: Vector{Float64}
    bulk_R      :: Vector{Float64}
    Pv          :: Vector{Float64}
    Tv          :: Vector{Float64}
    Xv          :: Vector{Float64}
    Out         :: Vector{MAGEMin_C.gmin_struct{Float64, Int64}}
    field_cache :: Dict{String, Array{Float64,3}}
    t_total     :: Float64
    id          :: Int64
    solver      :: String
    buffer      :: String
    bufferN1    :: Float64
    bufferN2    :: Float64
    date        :: String
    act_sol     :: Vector{String}
    params      :: NamedTuple
end

const PD3D_POINT = Ref{Any}(nothing)

const PD3D = Ref{Union{Nothing,PD3D_state}}(nothing)

const PD3D_SEC_PER_POINT_THREAD = 0.05
const PD3D_KB_PER_POINT         = 32.0

diagram_type_2d(diagType) = diagType == "ptx3d" ? (isdefined(MAGEMinApp, :pd_fig_meta) ? pd_fig_meta.diagType : "pt") : diagType

pd3d_field_options() = [o for o in field_dropdown_options() if o.value != "Hash"]

function pd3d_estimate(nP, nT, nX)
    any(isnothing, (nP, nT, nX)) && return ""
    N   = Int(nP) * Int(nT) * Int(nX)
    t   = N * PD3D_SEC_PER_POINT_THREAD / Threads.nthreads()
    mem = N * PD3D_KB_PER_POINT / 1024
    return "$N points · ~$(ProgressMeter.durationstring(t)) · ~$(round(Int, mem)) MB"
end

function compute_phaseDiagram3D(    Prange,     Trange,     nP,         nT,         nX,
                                    dtb,        dataset,    custW,      scp,        solver,     phase_selection,
                                    cpx,        limOpx,     limOpxVal,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    seismicScheme, seismicWeightFactor,
                                    seismic_cor, aspect_ratio, seismic_water, shallow_cor, fluid_as_melt, anelastic_correction;
                                    optimizer   = "nlopt" )
    global CompProgress

    Pv = collect(range(Float64(Prange[1]), Float64(Prange[2]), length = nP))
    Tv = collect(range(Float64(Trange[1]), Float64(Trange[2]), length = nT))
    Xv = collect(range(0.0, 1.0, length = nX))
    N  = nP * nT * nX

    P  = Vector{Float64}(undef, N)
    T  = Vector{Float64}(undef, N)
    X  = Vector{Vector{Float64}}(undef, N)
    B  = Vector{Float64}(undef, N)
    li = LinearIndices((nP, nT, nX))
    for iX in 1:nX, iT in 1:nT, iP in 1:nP
        l     = li[iP, iT, iX]
        x     = Xv[iX]
        P[l]  = Pv[iP]
        T[l]  = Tv[iT]
        X[l]  = bulk_L .* (1.0 - x) .+ bulk_R .* x
        B[l]  = bufferN1 * (1.0 - x) + bufferN2 * x
    end

    CompProgress.title            = "Calculation Progress"
    CompProgress.stage            = "Initialize MAGEMin"
    CompProgress.refinement_level = 0
    CompProgress.total_levels     = 0
    CompProgress.current_point    = 0
    CompProgress.total_points     = N
    CompProgress.tinit            = time()
    CompProgress.tlast            = CompProgress.tinit

    mbCpx, limitCaOpx, CaOpxLim, sol = get_init_param(dtb, solver, cpx, limOpx, limOpxVal)
    MAGEMin_data = Initialize_MAGEMin(  dtb;
                                        verbose             = false,
                                        dataset             = dataset,
                                        limitCaOpx          = limitCaOpx,
                                        CaOpxLim            = CaOpxLim,
                                        mbCpx               = mbCpx,
                                        buffer              = bufferType,
                                        solver              = sol,
                                        optimizer           = get_optimizer(dtb, optimizer, sol),
                                        seismicScheme       = seismicScheme,
                                        seismicWeightFactor = seismicWeightFactor )

    Out     = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef, N)
    new_Ws  = get_custom_Ws(custW)
    n_plane = nP * nT
    t_total = @elapsed try
        set_magemin_buffer!(MAGEMin_data, bufferType)
        CompProgress.stage        = "Compute 3D grid ($nP × $nT × $nX), X plane"
        CompProgress.total_levels = nX
        CompProgress.tinit        = time()
        CompProgress.tlast        = CompProgress.tinit
        for iX in 1:nX
            CompProgress.refinement_level = iX
            offset = (iX - 1) * n_plane
            ids    = offset+1:offset+n_plane
            t = @elapsed Out[ids] = multi_point_minimization(P[ids], T[ids], MAGEMin_data;
                                                X = X[ids], B = B[ids], Xoxides = oxi, sys_in = "mol", scp = scp,
                                                rm_list = phase_selection, name_solvus = true, W = new_Ws,
                                                callback_fn = (c, n, tl) -> update_progress(offset + c, N, tl),
                                                seismic_cor = seismic_cor, aspect_ratio = aspect_ratio, seismic_water = seismic_water,
                                                shallow_correction = shallow_cor, fluid_as_melt = fluid_as_melt, anelastic_cor = anelastic_correction )
            println("Computed X plane $iX/$nX ($n_plane points) in $t seconds")
            sleep(0.05)
        end
    finally
        for i = 1:Threads.maxthreadid()
            finalize_MAGEMin(MAGEMin_data.gv[i], MAGEMin_data.DB[i], MAGEMin_data.z_b[i], MAGEMin_data.splx_data[i])
        end
    end

    prev_id = isnothing(PD3D[]) ? 0 : PD3D[].id
    date    = string(Dates.today()) * ", " * string(Dates.Time(Dates.now()))
    act_sol = String.(get_phase_infos(Out).act_sol)
    params  = ( dataset = dataset, custW = custW, scp = scp, phase_selection = phase_selection, optimizer = optimizer,
                cpx = cpx, limOpx = limOpx, limOpxVal = limOpxVal,
                seismicScheme = seismicScheme, seismicWeightFactor = seismicWeightFactor,
                seismic_cor = seismic_cor, aspect_ratio = aspect_ratio, seismic_water = seismic_water,
                shallow_cor = shallow_cor, fluid_as_melt = fluid_as_melt, anelastic_correction = anelastic_correction )
    return PD3D_state(  dtb, copy(oxi), copy(bulk_L), copy(bulk_R), Pv, Tv, Xv, Out, Dict{String,Array{Float64,3}}(), t_total, prev_id + 1,
                        solver, bufferType, bufferN1, bufferN2, date, act_sol, params )
end

function pd3d_compute_point(st::PD3D_state, P::Float64, T::Float64, x::Float64)
    q = st.params
    mbCpx, limitCaOpx, CaOpxLim, sol = get_init_param(st.dtb, st.solver, q.cpx, q.limOpx, q.limOpxVal)
    MAGEMin_data = Initialize_MAGEMin(  st.dtb;
                                        verbose             = false,
                                        dataset             = q.dataset,
                                        limitCaOpx          = limitCaOpx,
                                        CaOpxLim            = CaOpxLim,
                                        mbCpx               = mbCpx,
                                        buffer              = st.buffer,
                                        solver              = sol,
                                        optimizer           = get_optimizer(st.dtb, get(q, :optimizer, "nlopt"), sol),
                                        seismicScheme       = q.seismicScheme,
                                        seismicWeightFactor = q.seismicWeightFactor )
    try
        set_magemin_buffer!(MAGEMin_data, st.buffer)
        x = clamp(x, 0.0, 1.0)
        return multi_point_minimization([P], [T], MAGEMin_data;
                                        X = [st.bulk_L .* (1.0 - x) .+ st.bulk_R .* x], B = [st.bufferN1 * (1.0 - x) + st.bufferN2 * x],
                                        Xoxides = st.oxi, sys_in = "mol", scp = q.scp, rm_list = q.phase_selection, name_solvus = true,
                                        W = get_custom_Ws(q.custW), progressbar = false,
                                        seismic_cor = q.seismic_cor, aspect_ratio = q.aspect_ratio, seismic_water = q.seismic_water,
                                        shallow_correction = q.shallow_cor, fluid_as_melt = q.fluid_as_melt, anelastic_cor = q.anelastic_correction )[1]
    finally
        for i = 1:Threads.maxthreadid()
            finalize_MAGEMin(MAGEMin_data.gv[i], MAGEMin_data.DB[i], MAGEMin_data.z_b[i], MAGEMin_data.splx_data[i])
        end
    end
end

const PD3D_ISO_TYPES = [
    (label = "Pure phase",          value = "pp"),
    (label = "Solution phase",      value = "ss"),
    (label = "Other",               value = "of"),
]

const PD3D_SS_FIELDS = [
    (label = "Mode",                        value = "mode"),
    (label = "Oxide composition",           value = "oxComp"),
    (label = "Endmember mode",              value = "emMode"),
    (label = "Mg#",                         value = "MgNum"),
    (label = "Calculator oxides",           value = "calc_ox"),
    (label = "Calculator apfu",             value = "calc"),
    (label = "Calculator site fractions",   value = "calc_sf"),
]

const PD3D_UNITS_MODE = [(label = "mol", value = "mol"), (label = "wt", value = "wt"), (label = "vol", value = "vol")]
const PD3D_UNITS_COMP = [(label = "mol", value = "mol"), (label = "wt", value = "wt")]

function pd3d_ss_index(out, phase)
    id = findfirst(==(phase), out.ph)
    return (isnothing(id) || id > out.n_SS) ? nothing : id
end

function pd3d_formula_function(formula::String, names::Vector{String})
    expr = formula
    for j in sortperm(length.(names), rev = true)
        expr = replace(expr, names[j] => "x[$j]")
    end
    return eval(:( (x) -> $(Meta.parse(expr)) ))
end

function pd3d_mode_value(out, frac, phase, rmf::Bool)
    id = findfirst(==(phase), out.ph)
    isnothing(id) && return 0.0
    v = frac[id]
    if rmf
        for fl in ("H2O", "fl")
            jf = findfirst(==(fl), out.ph)
            isnothing(jf) || (v /= (1.0 - frac[jf]))
        end
    end
    return v
end

function pd3d_point_value(out, kind::String, phase::String, item::String; calc_fn = nothing)
    kind == "sys" && return get_other_field_value(out, item)
    rmf  = endswith(kind, "_rmf")
    base = rmf ? kind[1:end-4] : kind
    base == "ph_frac"     && return pd3d_mode_value(out, out.ph_frac,     phase, rmf)
    base == "ph_frac_wt"  && return pd3d_mode_value(out, out.ph_frac_wt,  phase, rmf)
    base == "ph_frac_vol" && return pd3d_mode_value(out, out.ph_frac_vol, phase, rmf)
    id = pd3d_ss_index(out, phase)
    isnothing(id) && return NaN
    ss = out.SS_vec[id]
    if kind == "mgnum"
        mg = ss.Comp_apfu[findfirst(==("MgO"), out.oxides)]
        fe = ss.Comp_apfu[findfirst(==("FeO"), out.oxides)]
        return mg / (mg + fe)
    elseif kind == "ox"
        return ss.Comp[findfirst(==(item), out.oxides)]
    elseif kind == "ox_wt"
        return ss.Comp_wt[findfirst(==(item), out.oxides)]
    elseif kind in ("em", "em_wt")
        ie = findfirst(==(item), ss.emNames)
        return isnothing(ie) ? NaN : (kind == "em" ? ss.emFrac[ie] : ss.emFrac_wt[ie])
    elseif kind == "calc"
        return Float64(Base.invokelatest(calc_fn, ss.Comp_apfu))
    elseif kind == "calc_ox"
        return Float64(Base.invokelatest(calc_fn, ss.Comp))
    elseif kind == "calc_ox_wt"
        return Float64(Base.invokelatest(calc_fn, ss.Comp_wt))
    elseif kind == "calc_sf"
        return Float64(Base.invokelatest(calc_fn, ss.siteFractions))
    end
    return NaN
end

function pd3d_site_names(st::PD3D_state, phase)
    phase isa AbstractString || return String[]
    for out in st.Out
        id = pd3d_ss_index(out, phase)
        isnothing(id) || return String.(out.SS_vec[id].siteFractionsNames)
    end
    return String[]
end

function pd3d_calc_names(st::PD3D_state, kind, phase)
    kind == "calc"                      && return String.(st.Out[1].elements)
    kind in ("calc_ox", "calc_ox_wt")   && return String.(st.Out[1].oxides)
    kind == "calc_sf"                   && return pd3d_site_names(st, phase)
    return String[]
end

function pd3d_field(st::PD3D_state, kind::String, phase::String, item::String)
    return get!(st.field_cache, "$kind|$phase|$item") do
        A       = fill(NaN, length(st.Pv), length(st.Tv), length(st.Xv))
        calc_fn = nothing
        if startswith(kind, "calc")
            names = pd3d_calc_names(st, kind, phase)
            (isempty(strip(item)) || isempty(names)) && return A
            calc_fn = try pd3d_formula_function(item, names) catch; return A end
        end
        for l in eachindex(st.Out)
            v    = try pd3d_point_value(st.Out[l], kind, phase, item; calc_fn = calc_fn) catch; NaN end
            A[l] = v isa Real && isfinite(v) ? v : NaN
        end
        A
    end
end

pd3d_field(st::PD3D_state, fieldname::String) = pd3d_field(st, "sys", "", fieldname)

function pd3d_range(A::AbstractArray)
    v = filter(isfinite, vec(A))
    isempty(v) && return 0.0, 1.0
    return minimum(v), maximum(v)
end

pd3d_field_range(st::PD3D_state, fieldname::String) = pd3d_range(pd3d_field(st, fieldname))

pd3d_integer_spec(kind, item) = kind == "sys" && is_integer_field(item)

function pd3d_spec_label(kind, phase, item)
    kind == "sys" && return get(OTHER_FIELD_LABELS, item, item)
    ph   = display_ph_name(phase)
    rmf  = endswith(kind, "_rmf")
    base = rmf ? kind[1:end-4] : kind
    sfx  = rmf ? " (fluid-free)" : ""
    base == "ph_frac"     && return "$ph mode [mol]$sfx"
    base == "ph_frac_wt"  && return "$ph mode [wt]$sfx"
    base == "ph_frac_vol" && return "$ph mode [vol]$sfx"
    kind == "mgnum"       && return "$ph Mg#"
    kind == "ox"          && return "$ph $item [mol]"
    kind == "ox_wt"       && return "$ph $item [wt]"
    kind == "em"          && return "$ph $item [mol]"
    kind == "em_wt"       && return "$ph $item [wt]"
    kind == "calc"        && return "$ph $item [apfu]"
    kind == "calc_ox"     && return "$ph $item [mol]"
    kind == "calc_ox_wt"  && return "$ph $item [wt]"
    kind == "calc_sf"     && return "$ph $item"
    return "$kind $phase $item"
end

function pd3d_phases(st::PD3D_state; solution_only::Bool = false, pure_only::Bool = false)
    phs = Set{String}()
    for out in st.Out
        for i in eachindex(out.ph)
            is_ss = i <= out.n_SS
            (solution_only && !is_ss) && continue
            (pure_only && is_ss) && continue
            push!(phs, out.ph[i])
        end
    end
    return sort(collect(phs))
end

function pd3d_em_names(st::PD3D_state, phase)
    phase isa AbstractString || return String[]
    for out in st.Out
        id = pd3d_ss_index(out, phase)
        isnothing(id) || return String.(out.SS_vec[id].emNames)
    end
    return String[]
end

const PD3D_SURF_PRESETS = [
    (value = "melt_mg", label = "Melt Mg# = 0.7 · colour: melt fraction · lines: garnet mode", iso = 0.7,
        a = (type = "ss", phase = "liq", ssfield = "MgNum"),
        b = (type = "ss", phase = "liq", ssfield = "mode",   unit = "vol"),
        c = (type = "ss", phase = "g",   ssfield = "mode",   unit = "vol")),
    (value = "solidus", label = "Solidus (melt-in) · colour: H₂O activity · lines: garnet mode", iso = 0.001,
        a = (type = "ss", phase = "liq", ssfield = "mode",   unit = "vol"),
        b = (type = "of", offield = "aH2O"),
        c = (type = "ss", phase = "g",   ssfield = "mode",   unit = "vol")),
    (value = "garnet_in", label = "Garnet-in · colour: pyrope in garnet · lines: melt fraction", iso = 0.001,
        a = (type = "ss", phase = "g",   ssfield = "mode",   unit = "vol"),
        b = (type = "ss", phase = "g",   ssfield = "emMode", unit = "mol", em = "py"),
        c = (type = "ss", phase = "liq", ssfield = "mode",   unit = "vol")),
    (value = "density", label = "Density = 3000 kg/m³ · colour: melt fraction · lines: Vp", iso = 3000.0,
        a = (type = "of", offield = "rho"),
        b = (type = "of", offield = "frac_M_vol"),
        c = (type = "of", offield = "Vp")),
]

pd3d_surf_preset(value) = (i = findfirst(p -> p.value == value, PD3D_SURF_PRESETS); isnothing(i) ? nothing : PD3D_SURF_PRESETS[i])

function pd3d_spec_from_selector(type, phase, ssfield, offield, unit, rmf, ox, em, calc, calcox, calcsf)
    str(v)  = v isa AbstractString ? String(v) : ""
    phase   = str(phase)
    rmf_sfx = rmf == true ? "_rmf" : ""
    mode_k  = Dict("mol" => "ph_frac", "wt" => "ph_frac_wt", "vol" => "ph_frac_vol")
    comp_wt = unit == "wt"
    type == "of" && return ("sys", "", str(offield))
    type == "pp" && return (get(mode_k, unit, "ph_frac") * rmf_sfx, phase, "")
    ssfield == "mode"    && return (get(mode_k, unit, "ph_frac") * rmf_sfx, phase, "")
    ssfield == "oxComp"  && return (comp_wt ? "ox_wt" : "ox", phase, str(ox))
    ssfield == "emMode"  && return (comp_wt ? "em_wt" : "em", phase, str(em))
    ssfield == "MgNum"   && return ("mgnum", phase, "")
    ssfield == "calc"    && return ("calc", phase, str(calc))
    ssfield == "calc_ox" && return (comp_wt ? "calc_ox_wt" : "calc_ox", phase, str(calcox))
    ssfield == "calc_sf" && return ("calc_sf", phase, str(calcsf))
    return ("sys", "", "frac_M_vol")
end

function pd3d_default_iso(fieldname, lo, hi)
    if is_integer_field(fieldname)
        n = max(round(Int, hi) - round(Int, lo), 1)
        return round(lo) + 0.5, round(hi) - 0.5, n
    end
    d = (hi - lo) / 10
    return round(lo + d, sigdigits = 4), round(hi - d, sigdigits = 4), 5
end

pd3d_oxide_label(ox) = replace(String(ox), "2" => "₂", "3" => "₃")

function pd3d_bulk_relation(bL::AbstractVector, bR::AbstractVector; rtol = 1e-6)
    isapprox(bL, bR; rtol = rtol, atol = 1e-12) && return :identical, 0
    act = [i for i in eachindex(bL) if bL[i] > 0 || bR[i] > 0]
    for k in act
        rest = [i for i in act if i != k]
        any(i -> bL[i] == 0 || bR[i] == 0, rest) && continue
        r = [bR[i] / bL[i] for i in rest]
        all(x -> isapprox(x, r[1]; rtol = rtol), r) && return :single, k
    end
    return :multiple, 0
end

function pd3d_x_axis(oxi, bL, bR)
    rel, k = pd3d_bulk_relation(bL, bR)
    if rel == :single
        lab   = pd3d_oxide_label(oxi[k])
        xs    = collect(range(0.0, 1.0, length = 5))
        vals  = [100 * ((1 - x) * bL[k] + x * bR[k]) for x in xs]
        text  = [string(round(v, sigdigits = 3)) for v in vals]
        return (title = "$lab [mol%]", tickvals = xs, ticktext = text,
                info  = "$lab content, $(text[1]) → $(text[end]) mol% (other oxides in constant proportions)", relation = rel)
    elseif rel == :identical
        return (title = "Composition [X0 → X1]", tickvals = nothing, ticktext = nothing,
                info  = "identical X0 and X1 compositions (nothing varies along X)", relation = rel)
    end
    return (title = "Composition [X0 → X1]", tickvals = nothing, ticktext = nothing,
            info  = "linear mixing from X0 (X = 0) to X1 (X = 1)", relation = rel)
end

function pd3d_nearest(st::PD3D_state, p_kbar, t, x)
    iP = argmin(abs.(st.Pv .- p_kbar))
    iT = argmin(abs.(st.Tv .- t))
    iX = argmin(abs.(st.Xv .- x))
    return LinearIndices((length(st.Pv), length(st.Tv), length(st.Xv)))[iP, iT, iX], st.Xv[iX]
end

function pd3d_diagram_information(st::PD3D_state)
    nP, nT, nX = length(st.Pv), length(st.Tv), length(st.Xv)
    solv       = Dict("lp" => "LP (legacy)", "pge" => "PGE (default)", "hyb" => "Hybrid (PGE&LP)")
    unit       = pressure_unit_label()
    buf        = st.buffer != "none"
    comp(b)    = join(round.(b .* 100.0, digits = 3), " ")
    rng(a, b)  = "$(round(a, digits = 3)) → $(round(b, digits = 3))"
    meant      = round(sum(o.time_ms for o in st.Out) / length(st.Out), digits = 2)

    rows = Tuple{String,String}[
        ("Number of points",    "$nP (P) × $nT (T) × $nX (X) = $(length(st.Out))"),
        ("Date & time",         st.date),
        ("Database",            dba[(dba.acronym .== st.dtb), :].database[1] * "; " * st.Out[1].dataset),
        ("Solution names",      join(st.act_sol, ", ")),
        ("Diagram type",        "Pressure-Temperature-Composition (3D)"),
        ("X axis",              pd3d_x_axis(st.oxi, st.bulk_L, st.bulk_R).info),
        ("Solver",              get(solv, st.solver, st.solver) * (st.solver == "lp" && get_optimizer(st.dtb, get(st.params, :optimizer, "nlopt"), 0) == 1 ? ", nullspace optimizer" : "")),
        ("Oxide list",          join(replace.(st.oxi, "2" => "₂", "3" => "₃"), " ")),
    ]
    buf && push!(rows, ("Buffer", st.buffer))
    push!(rows, ("X0 comp [mol%]", comp(st.bulk_L)))
    buf && push!(rows, ("Buffer factor", string(st.bufferN1)))
    push!(rows, ("X1 comp [mol%]", comp(st.bulk_R)))
    buf && push!(rows, ("Buffer factor", string(st.bufferN2)))
    push!(rows, ("Pressure range [$unit]",   rng(display_pressure(st.Pv[1]), display_pressure(st.Pv[end]))))
    push!(rows, ("Temperature range [°C]",   rng(st.Tv[1], st.Tv[end])))
    push!(rows, ("Computation time",         "$(round(st.t_total, digits = 1)) s (mean $meant ms/point)"))

    rule   = "‾"^101
    labels = "3D phase diagram computed using MAGEMin $(MAGEMin_version) (MAGEMin_C v$(MAGEMin_C_version); GUI $(GUI_version))<br>" *
             rule * "<br>" * join(first.(rows), "<br>") * "<br>" * "_"^101
    values = "&nbsp;<br>&nbsp;<br>" * join(last.(rows), "<br>") * "<br>&nbsp;"
    return labels, values, length(rows)
end

const PD3D_INFO_LINE_PX = 13
const PD3D_SCENE_H      = 640
const PD3D_LOGO_H       = 70
const PD3D_LOGO_SRC     = "assets/static/images/MAGEMin.jpg"

const PD3D_CAMERAS = Dict(
    "iso" => (eye = (x = 1.23, y = -1.23, z = 0.77), up = (x = 0, y = 0, z = 1), proj = "perspective"),
    "pt"  => (eye = (x = 0.0,  y = 0.0,  z = -2.5), up = (x = 1, y = 0, z = 0), proj = "orthographic"),
    "px"  => (eye = (x = 0.0,  y = 2.5,  z = 0.0), up = (x = 1, y = 0, z = 0), proj = "orthographic"),
    "tx"  => (eye = (x = -2.5, y = 0.0,  z = 0.0), up = (x = 0, y = 1, z = 0), proj = "orthographic"),
)

pd3d_axes(st::PD3D_state) = (   range(st.Pv[1], st.Pv[end], length = length(st.Pv)),
                                range(st.Tv[1], st.Tv[end], length = length(st.Tv)),
                                range(st.Xv[1], st.Xv[end], length = length(st.Xv)) )

function pd3d_compact(verts, faces, extra = ())
    ok(k)  = all(isfinite, verts[k]) && all(e -> isfinite(e[k]), extra)
    faces  = [f for f in faces if all(ok, f)]
    used   = falses(length(verts))
    for f in faces, k in f
        used[k] = true
    end
    newid  = cumsum(used)
    return verts[used], [map(k -> newid[k], f) for f in faces], [e[used] for e in extra]
end

pd3d_isosurface(st::PD3D_state, A::AbstractArray, iso::Real) = Meshing.isosurface(A, Meshing.MarchingCubes(iso = Float64(iso)), pd3d_axes(st)...)

pd3d_mesh(st::PD3D_state, A::AbstractArray, iso::Real) = pd3d_compact(pd3d_isosurface(st, A, iso)...)

function pd3d_cell(axis, v)
    n = length(axis)
    i = clamp(searchsortedlast(axis, v), 1, n - 1)
    t = clamp((v - axis[i]) / (axis[i+1] - axis[i]), 0.0, 1.0)
    return i, t
end

function pd3d_interp(st::PD3D_state, A::AbstractArray, verts)
    out = fill(NaN, length(verts))
    for (k, v) in enumerate(verts)
        all(isfinite, v) || continue
        (i, ti), (j, tj), (l, tl) = pd3d_cell(st.Pv, v[1]), pd3d_cell(st.Tv, v[2]), pd3d_cell(st.Xv, v[3])
        acc, wsum = 0.0, 0.0
        for di in 0:1, dj in 0:1, dl in 0:1
            a = A[i+di, j+dj, l+dl]
            isfinite(a) || continue
            w = (di == 0 ? 1 - ti : ti) * (dj == 0 ? 1 - tj : tj) * (dl == 0 ? 1 - tl : tl)
            acc += w * a; wsum += w
        end
        wsum > 1e-12 && (out[k] = acc / wsum)
    end
    return out
end

function pd3d_mesh_kw(verts, faces)
    return (    x = display_pressure([v[1] for v in verts]),
                y = [v[2] for v in verts],
                z = [v[3] for v in verts],
                i = [f[1] - 1 for f in faces],
                j = [f[2] - 1 for f in faces],
                k = [f[3] - 1 for f in faces] )
end

function pd3d_colorbar(cb, y)
    cb[:len]     = 0.375
    cb[:lenmode] = "fraction"
    cb[:x]       = 1.0
    cb[:y]       = y
    cb[:yanchor] = "middle"
    return cb
end

function pd3d_field_trace(st::PD3D_state, o)
    A          = pd3d_field(st, o.f...)
    lo, hi     = pd3d_range(A)
    Pd         = display_pressure(st.Pv)
    colorm, rev = get_colormap_prop(o.colormap, [1,9], o.reverse)
    cs, zr     = field_colorscale(pd3d_integer_spec(o.f[1], o.f[3]) ? o.f[3] : "", colorm, rev, "false", lo, hi)
    label      = pd3d_spec_label(o.f...)
    kw = (  x               = vec([p for p in Pd, t in st.Tv, x in st.Xv]),
            y               = vec([t for p in Pd, t in st.Tv, x in st.Xv]),
            z               = vec([x for p in Pd, t in st.Tv, x in st.Xv]),
            value           = vec(map(v -> isfinite(v) ? v : lo, A)),
            isomin          = isnothing(o.isomin)  ? lo  : Float64(o.isomin),
            isomax          = isnothing(o.isomax)  ? hi  : Float64(o.isomax),
            surface_count   = isnothing(o.nsurf)   ? 5   : Int(o.nsurf),
            opacity         = isnothing(o.opacity) ? 0.6 : Float64(o.opacity),
            colorscale      = cs,
            reversescale    = rev,
            cmin            = get(zr, :zmin, lo),
            cmax            = get(zr, :zmax, hi),
            caps            = attr(x_show = o.caps, y_show = o.caps, z_show = o.caps),
            colorbar        = pd3d_colorbar(field_colorbar(pd3d_integer_spec(o.f[1], o.f[3]) ? o.f[3] : label), o.cb_y),
            hovertemplate   = "P: %{x:.3f}<br>T: %{y:.1f}<br>X: %{z:.3f}<br>$label: %{value:.4g}<extra></extra>" )
    return o.mode == "volume" ? volume(; kw...) : isosurface(; kw...)
end

function pd3d_contours(verts, faces, C, levels, lw)
    traces = GenericTrace[]
    lx, ly, lz, lt = Float64[], Float64[], Float64[], String[]
    for level in levels
        xs, ys, zs = Union{Float64,Nothing}[], Union{Float64,Nothing}[], Union{Float64,Nothing}[]
        for f in faces
            pts = NTuple{3,Float64}[]
            for (a, b) in ((f[1], f[2]), (f[2], f[3]), (f[3], f[1]))
                ca, cb = C[a], C[b]
                if (ca - level) * (cb - level) < 0
                    t = (level - ca) / (cb - ca)
                    push!(pts, verts[a] .+ t .* (verts[b] .- verts[a]))
                end
            end
            if length(pts) == 2
                append!(xs, [pts[1][1], pts[2][1], nothing])
                append!(ys, [pts[1][2], pts[2][2], nothing])
                append!(zs, [pts[1][3], pts[2][3], nothing])
            end
        end
        isempty(xs) && continue
        lbl = string(round(level, sigdigits = 3))
        push!(traces, scatter3d(x = map(v -> isnothing(v) ? nothing : display_pressure(v), xs), y = ys, z = zs,
                                mode = "lines", line = attr(color = "black", width = lw),
                                hoverinfo = "text", text = lbl, showlegend = false))
        m = 3 * div(length(xs) ÷ 3, 2) + 1
        push!(lx, display_pressure(xs[m])); push!(ly, ys[m]); push!(lz, zs[m]); push!(lt, lbl)
    end
    return traces, (lx, ly, lz, lt)
end

const PD3D_MESH_CACHE     = Dict{Any,Any}()
const PD3D_MESH_CACHE_ID  = Ref(0)
const PD3D_MESH_CACHE_MAX = 200

function pd3d_cached(f, st::PD3D_state, key)
    if PD3D_MESH_CACHE_ID[] != st.id || length(PD3D_MESH_CACHE) >= PD3D_MESH_CACHE_MAX
        empty!(PD3D_MESH_CACHE)
        PD3D_MESH_CACHE_ID[] = st.id
    end
    return get!(f, PD3D_MESH_CACHE, key)
end

pd3d_mesh_cached(st::PD3D_state, spec, iso::Real) = pd3d_cached(st, (:mesh, spec, Float64(iso))) do
    pd3d_mesh(st, pd3d_field(st, spec...), iso)
end

function pd3d_surface_mesh(st::PD3D_state, o)
    return pd3d_cached(st, (:surface, o.a, Float64(o.iso), o.b)) do
        A            = pd3d_field(st, o.a...)
        verts, faces = pd3d_isosurface(st, A, o.iso)
        Bv           = pd3d_interp(st, pd3d_field(st, o.b...), verts)
        verts, faces, (Bv,) = pd3d_compact(verts, faces, (Bv,))
        (verts, faces, Bv)
    end
end

function pd3d_field_levels(o, lo, hi)
    imin = isnothing(o.isomin) ? lo : Float64(o.isomin)
    imax = isnothing(o.isomax) ? hi : Float64(o.isomax)
    ns   = isnothing(o.nsurf)  ? 5  : Int(o.nsurf)
    return ns == 1 ? [(imin + imax) / 2] : collect(range(imin, imax, length = ns))
end

const PD3D_PTX_MAX_LEVELS = 200

function pd3d_levels(lo, hi, vmin, vmax, step, values_str)
    lo, hi = minmax(Float64(lo), Float64(hi))
    tol    = 1e-9 * max(hi - lo, eps())
    lev    = Float64[]
    trunc  = false
    if all(v -> v isa Real && isfinite(v), (vmin, vmax, step)) && step > 0 && vmax >= vmin
        n     = floor(Int, (vmax - vmin) / step + 1e-9) + 1
        trunc = n > PD3D_PTX_MAX_LEVELS
        append!(lev, Float64(vmin) .+ Float64(step) .* (0:min(n, PD3D_PTX_MAX_LEVELS) - 1))
    end
    if values_str isa AbstractString
        for s in split(values_str, r"[,;\s]+"; keepempty = false)
            v = tryparse(Float64, s)
            isnothing(v) || isfinite(v) && push!(lev, v)
        end
    end
    sort!(filter!(v -> lo - tol <= v <= hi + tol, lev))
    out = Float64[]
    for v in lev
        (isempty(out) || v - out[end] > tol) && push!(out, clamp(v, lo, hi))
    end
    trunc |= length(out) > PD3D_PTX_MAX_LEVELS
    return first(out, PD3D_PTX_MAX_LEVELS), trunc
end

function pd3d_nice_range(lo, hi; n = 6)
    lo, hi = minmax(Float64(lo), Float64(hi))
    hi - lo <= 0 && return lo, hi, 1.0
    raw  = (hi - lo) / n
    mag  = 10.0^floor(log10(raw))
    step = first(m * mag for m in (1, 2, 5, 10) if m * mag >= raw)
    vmin = ceil(lo / step - 1e-9) * step
    vmax = floor(hi / step + 1e-9) * step
    return round(vmin, sigdigits = 12), round(vmax, sigdigits = 12), round(step, sigdigits = 12)
end

function pd3d_ptx_defaults(st::PD3D_state)
    P = pd3d_nice_range(display_pressure(st.Pv[1]), display_pressure(st.Pv[end]))
    T = pd3d_nice_range(st.Tv[1], st.Tv[end])
    xlo, xhi = minmax(st.Xv[1], st.Xv[end])
    X = (ceil(xlo * 10 - 1e-9) / 10, floor(xhi * 10 + 1e-9) / 10, 0.1)
    return P, T, X
end

function pd3d_ptx_lines(meshes, k, levels, shown)
    xs, ys, zs, tx = Union{Float64,Nothing}[], Union{Float64,Nothing}[], Union{Float64,Nothing}[], String[]
    lx, ly, lz, lt = Float64[], Float64[], Float64[], String[]
    prep = map(meshes) do (verts, faces)
        C = [v[k] for v in verts]
        (verts, faces, C, [min(C[f[1]], C[f[2]], C[f[3]]) for f in faces], [max(C[f[1]], C[f[2]], C[f[3]]) for f in faces])
    end
    for (level, lbl) in zip(levels, shown)
        n0 = length(xs)
        for (verts, faces, C, fmin, fmax) in prep, (i, f) in enumerate(faces)
            (fmin[i] < level <= fmax[i]) || continue
            pts = NTuple{3,Float64}[]
            for (a, b) in ((f[1], f[2]), (f[2], f[3]), (f[3], f[1]))
                ca, cb = C[a], C[b]
                if (ca >= level) != (cb >= level)
                    t = (level - ca) / (cb - ca)
                    push!(pts, Tuple(verts[a] .+ t .* (verts[b] .- verts[a])))
                end
            end
            length(pts) == 2 || continue
            append!(xs, [display_pressure(pts[1][1]), display_pressure(pts[2][1]), nothing])
            append!(ys, [pts[1][2], pts[2][2], nothing])
            append!(zs, [pts[1][3], pts[2][3], nothing])
            append!(tx, [lbl, lbl, ""])
        end
        length(xs) > n0 || continue
        m = n0 + 3 * ((length(xs) - n0) ÷ 6) + 1
        push!(lx, xs[m]); push!(ly, ys[m]); push!(lz, zs[m]); push!(lt, lbl)
    end
    return (xs, ys, zs, tx), (lx, ly, lz, lt)
end

function pd3d_ptx_meshes(st::PD3D_state, o)
    meshes  = Tuple{Any,Any}[]
    targets = something(o.ptx.targets, String[])
    if "surface" in targets && "surface" in o.layers
        verts, faces, _ = pd3d_surface_mesh(st, o)
        isempty(faces) || push!(meshes, (verts, faces))
    end
    if "field" in targets && "field" in o.layers && o.mode == "isosurface"
        A      = pd3d_field(st, o.f...)
        lo, hi = pd3d_range(A)
        if any(isfinite, A) && lo < hi
            for lev in pd3d_field_levels(o, lo, hi)
                verts, faces, _ = pd3d_mesh_cached(st, o.f, lev)
                isempty(faces) || push!(meshes, (verts, faces))
            end
        end
    end
    if "phases" in targets && "phases" in o.layers
        for ph in something(o.phases, String[])
            verts, faces, _ = pd3d_mesh_cached(st, ("ph_frac_vol", ph, ""), o.eps)
            isempty(faces) || push!(meshes, (verts, faces))
        end
    end
    return meshes
end

pd3d_cross(a, b) = [a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]]

function pd3d_tube_mesh(xs, ys, zs, tx, spans, r)
    X, Y, Z, T = Float64[], Float64[], Float64[], String[]
    I, J, K    = Int[], Int[], Int[]
    s          = collect(spans)
    for a in 1:3:length(xs) - 2
        p0 = [xs[a],   ys[a],   zs[a]]   ./ s
        p1 = [xs[a+1], ys[a+1], zs[a+1]] ./ s
        d  = p1 .- p0
        n  = sqrt(sum(abs2, d))
        n > 1e-12 || continue
        d ./= n
        ref = abs(d[1]) < 0.9 ? [1.0, 0.0, 0.0] : [0.0, 1.0, 0.0]
        u   = pd3d_cross(d, ref); u ./= sqrt(sum(abs2, u))
        w   = pd3d_cross(d, u)
        base = length(X)
        for p in (p0, p1), j in 0:3
            ang = j * pi / 2 + pi / 4
            q   = (p .+ r .* (cos(ang) .* u .+ sin(ang) .* w)) .* s
            push!(X, q[1]); push!(Y, q[2]); push!(Z, q[3]); push!(T, tx[a])
        end
        for j in 0:3
            jn = (j + 1) % 4
            push!(I, base + j);  push!(J, base + jn);     push!(K, base + 4 + j)
            push!(I, base + jn); push!(J, base + 4 + jn); push!(K, base + 4 + j)
        end
    end
    return X, Y, Z, T, I, J, K
end

function pd3d_ptx_traces(st::PD3D_state, o)
    q      = o.ptx
    traces = GenericTrace[]
    meshes = pd3d_ptx_meshes(st, o)
    isempty(meshes) && return traces, "P-T-X lines: no surface to draw them on (check the targets and layers)"
    parts  = String[]
    Pd     = display_pressure(st.Pv)
    spans  = max.((abs(Pd[end] - Pd[1]), abs(st.Tv[end] - st.Tv[1]), abs(st.Xv[end] - st.Xv[1])), 1e-12)
    for (ax, k, name) in ((q.p, 1, "P"), (q.t, 2, "T"), (q.x, 3, "X"))
        isempty(ax.levels) && continue
        shown      = k == 1 ? display_pressure(ax.levels) : ax.levels
        lbls       = [string(round(v, sigdigits = 6)) for v in shown]
        (xyz, lab) = pd3d_ptx_lines(meshes, k, ax.levels, lbls)
        any(!isnothing, xyz[1]) || (push!(parts, "$name 0 visible"); continue)
        unit = k == 1 ? " $(pressure_unit_label())" : (k == 2 ? " °C" : "")
        text = [isempty(t) ? "" : "$name = $t$unit" for t in xyz[4]]
        if q.style == "tube"
            X, Y, Z, T, I, J, K = pd3d_tube_mesh(xyz[1], xyz[2], xyz[3], text, spans, q.radius / 100)
            push!(traces, mesh3d(x = X, y = Y, z = Z, i = I, j = J, k = K, text = T, hoverinfo = "text",
                                 color = ax.color, flatshading = true, lighting = attr(ambient = 0.8, diffuse = 0.4, specular = 0.0),
                                 name = "$name contours", legendgroup = "ptx_$name", showlegend = true))
        else
            push!(traces, scatter3d(x = xyz[1], y = xyz[2], z = xyz[3], text = text,
                                    mode = "lines", line = attr(color = ax.color, width = q.lw, dash = q.dash),
                                    hoverinfo = "text", name = "$name contours", legendgroup = "ptx_$name", showlegend = true))
        end
        if q.labels && !isempty(lab[1])
            push!(traces, scatter3d(x = lab[1], y = lab[2], z = lab[3], text = lab[4], mode = "text",
                                    textposition = "top center", legendgroup = "ptx_$name", showlegend = false, hoverinfo = "skip",
                                    textfont = attr(color = ax.color, size = q.lsize)))
        end
        push!(parts, "$name $(length(ax.levels))" * (ax.trunc ? " (truncated)" : ""))
    end
    return traces, isempty(parts) ? "P-T-X lines: no level selected" : "P-T-X lines: " * join(parts, ", ") * " levels"
end

pd3d_phase_color(ph) = string(get(AppData.mineral_style[1], ph, Any["grey"])[1])

function pd3d_surface_traces(st::PD3D_state, o)
    verts, faces, Bv = pd3d_surface_mesh(st, o)
    isempty(faces) && return GenericTrace[], "no surface found for $(pd3d_spec_label(o.a...)) = $(o.iso)"

    labelB       = pd3d_spec_label(o.b...)
    colorm, rev  = get_colormap_prop(o.surf_colormap, [1,9], o.surf_reverse)
    blo, bhi     = pd3d_range(Bv)
    traces       = GenericTrace[mesh3d(; pd3d_mesh_kw(verts, faces)...,
                                        intensity    = Bv,
                                        colorscale   = colorm,
                                        reversescale = rev,
                                        cmin         = blo,
                                        cmax         = bhi,
                                        opacity      = isnothing(o.surf_opacity) ? 0.8 : Float64(o.surf_opacity),
                                        colorbar     = pd3d_colorbar(attr(title = attr(text = labelB, side = "right"), thicknessmode = "fraction", thickness = 0.02), o.cb_y_surf),
                                        hovertemplate = "P: %{x:.3f}<br>T: %{y:.1f}<br>X: %{z:.3f}<br>$labelB: %{intensity:.4g}<extra></extra>",
                                        showlegend   = false )]

    msg = "Surface: $(pd3d_spec_label(o.a...)) = $(o.iso), coloured by $labelB"
    if o.show_contours && !isnothing(o.nlev) && o.nlev > 0
        Cv          = pd3d_interp(st, pd3d_field(st, o.c...), verts)
        clo, chi    = pd3d_range(Cv)
        levels      = collect(range(clo, chi, length = Int(o.nlev) + 2))[2:end-1]
        lines, lbls = pd3d_contours(verts, faces, Cv, levels, something(o.lw, 3))
        append!(traces, lines)
        isempty(lbls[1]) || push!(traces, scatter3d(x = lbls[1], y = lbls[2], z = lbls[3], text = lbls[4], mode = "text",
                                                    textposition = "top center", showlegend = false, hoverinfo = "skip",
                                                    textfont = attr(color = "black", size = something(o.lsize, 10))))
        msg *= "; black lines: $(pd3d_spec_label(o.c...))"
    end
    return traces, msg
end

function pd3d_phase_traces(st::PD3D_state, phases, eps, opacity, Pd)
    traces = GenericTrace[]
    for ph in phases
        verts, faces, _ = pd3d_mesh_cached(st, ("ph_frac_vol", ph, ""), eps)
        isempty(faces) && continue
        col  = pd3d_phase_color(ph)
        name = display_ph_name(ph)
        push!(traces, mesh3d(; pd3d_mesh_kw(verts, faces)..., color = col, opacity = opacity, flatshading = false,
                                name = name, legendgroup = "phase_$ph", showlegend = false, hovertemplate = "$name in/out<extra></extra>"))
        push!(traces, scatter3d(x = [nothing], y = [nothing], z = [nothing], mode = "markers", legendgroup = "phase_$ph",
                                marker = attr(color = col, size = 8), name = "$name in/out", showlegend = true))
    end
    return traces
end

function pd3d_cloud_trace(st::PD3D_state, stride::Int, size)
    nP, nT, nX = length(st.Pv), length(st.Tv), length(st.Xv)
    li         = LinearIndices((nP, nT, nX))
    ids        = vec([li[iP, iT, iX] for iP in 1:stride:nP, iT in 1:stride:nT, iX in 1:stride:nX])
    Pd         = display_pressure(st.Pv)
    ci         = CartesianIndices((nP, nT, nX))
    var        = [length(st.Out[l].oxides) - length(st.Out[l].ph) + 2 for l in ids]
    txt        = [join(display_ph_names(st.Out[l].ph), " + ") * "<br>variance $(v)" for (l, v) in zip(ids, var)]
    return scatter3d(   x = [Pd[ci[l][1]] for l in ids], y = [st.Tv[ci[l][2]] for l in ids], z = [st.Xv[ci[l][3]] for l in ids],
                        mode = "markers", text = vec(txt), hovertemplate = "P: %{x:.3f}<br>T: %{y:.1f}<br>X: %{z:.3f}<br>%{text}<extra></extra>",
                        marker = attr(size = size, color = vec(var), colorscale = "Portland", showscale = false, opacity = 0.8),
                        name = "grid", showlegend = false )
end

function pd3d_zaxis(st::PD3D_state)
    xa = pd3d_x_axis(st.oxi, st.bulk_L, st.bulk_R)
    isnothing(xa.tickvals) && return attr(title = xa.title, range = [st.Xv[1], st.Xv[end]])
    return attr(title = xa.title, range = [st.Xv[1], st.Xv[end]], tickmode = "array", tickvals = xa.tickvals, ticktext = xa.ticktext)
end

const PD3D_LAST_OPTS = Ref{Any}(nothing)

function pd3d_figure(st::PD3D_state, o; logo_src = PD3D_LOGO_SRC)
    PD3D_LAST_OPTS[] = o
    Pd     = display_pressure(st.Pv)
    traces = GenericTrace[]
    msgs   = String[]
    both   = "field" in o.layers && "surface" in o.layers
    o      = merge(o, (cb_y = both ? 0.77 : 0.5, cb_y_surf = both ? 0.27 : 0.5))
    labels, values, nrows = pd3d_diagram_information(st)
    info_h = (nrows + 4) * PD3D_INFO_LINE_PX

    if "field" in o.layers
        flo, fhi = pd3d_range(pd3d_field(st, o.f...))
        if !any(isfinite, pd3d_field(st, o.f...))
            push!(msgs, "Field: no data for $(pd3d_spec_label(o.f...))")
        elseif flo == fhi
            push!(msgs, "Field: $(pd3d_spec_label(o.f...)) is constant ($(round(flo, sigdigits = 4))) over the diagram")
        else
            push!(traces, pd3d_field_trace(st, o))
        end
    end
    if "surface" in o.layers
        tr, msg = try pd3d_surface_traces(st, o) catch e; GenericTrace[], "surface failed: $(sprint(showerror, e))" end
        append!(traces, tr); push!(msgs, msg)
    end
    "phases" in o.layers && append!(traces, pd3d_phase_traces(st, something(o.phases, String[]), o.eps, o.phase_opacity, Pd))
    if "ptx" in o.layers
        tr, msg = try pd3d_ptx_traces(st, o) catch e; GenericTrace[], "P-T-X lines failed: $(sprint(showerror, e))" end
        append!(traces, tr); push!(msgs, msg)
    end
    "cloud"  in o.layers && push!(traces, pd3d_cloud_trace(st, max(1, Int(something(o.stride, 1))), something(o.msize, 3)))
    isempty(traces) && push!(traces, scatter3d(x = [Pd[1]], y = [st.Tv[1]], z = [st.Xv[1]], mode = "markers", marker = attr(size = 0.1), showlegend = false, hoverinfo = "skip"))

    cam    = PD3D_CAMERAS[o.camera]
    info   = (xref = "paper", yref = "paper", y = 0.0, yshift = -30, xanchor = "left", yanchor = "top", align = "left", valign = "top",
              showarrow = false, font = attr(size = 10))
    layout = Layout(
                width           = 900,
                height          = PD3D_LOGO_H + PD3D_SCENE_H + info_h,
                autosize        = false,
                paper_bgcolor   = "#FFF",
                margin          = attr(l = 0, r = 0, b = info_h + 30, t = PD3D_LOGO_H),
                images          = [attr(source = logo_src, xref = "paper", yref = "paper", x = 0.0, y = 1.0, sizex = 0.1, sizey = 0.1,
                                        xanchor = "left", yanchor = "bottom")],
                uirevision      = o.uirev,
                legend          = attr(x = 0.9, y = 0.0, xanchor = "right", yanchor = "bottom", bgcolor = "rgba(255,255,255,0.7)"),
                annotations     = [ attr(text = join(msgs, "<br>"), xref = "paper", yref = "paper", x = 0.12, y = 1.0, yshift = 8,
                                         xanchor = "left", yanchor = "bottom", align = "left", showarrow = false, font = attr(size = 11)),
                                    attr(; info..., x = 0.0,  text = labels),
                                    attr(; info..., x = 0.22, text = values) ],
                scene           = attr(
                    xaxis       = attr(title = "Pressure [$(pressure_unit_label())]", range = o.reverseP ? [Pd[end], Pd[1]] : [Pd[1], Pd[end]]),
                    yaxis       = attr(title = "Temperature [°C]", range = o.reverseT ? [st.Tv[end], st.Tv[1]] : [st.Tv[1], st.Tv[end]]),
                    zaxis       = pd3d_zaxis(st),
                    aspectmode  = "cube",
                    domain      = attr(x = [0.02, 0.9], y = [0.0, 1.0]),
                    camera      = attr(eye = attr(; cam.eye...), up = attr(; cam.up...), center = attr(x = 0, y = 0, z = cam.proj == "perspective" ? -0.16 : 0.0), projection = attr(type = cam.proj)),
                ),
            )

    return plot(traces, layout)
end

function pd3d_empty_figure()
    return plot(Layout( width = 900, height = 800, autosize = false, paper_bgcolor = "#FFF",
                        scene = attr(   xaxis = attr(title = "Pressure"), yaxis = attr(title = "Temperature [°C]"),
                                        zaxis = attr(title = "Composition [X0 → X1]"), aspectmode = "cube")))
end
