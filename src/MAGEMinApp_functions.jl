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

function pressure_unit_label()
    return use_GPa[1] ? "GPa" : "kbar"
end

# convert a pressure value from kbar (internal/MAGEMin unit) to the display unit
function display_pressure(P_kbar::Number)
    return use_GPa[1] ? round(P_kbar / 10.0, digits=10) : P_kbar
end
function display_pressure(P_kbar::AbstractArray)
    return use_GPa[1] ? [v isa Number ? round(v / 10.0, digits=10) : v for v in P_kbar] : P_kbar
end

# convert a pressure value from the display unit back to kbar (internal/MAGEMin unit)
function to_kbar_pressure(P_display::Number)
    return use_GPa[1] ? P_display * 10.0 : P_display
end
function to_kbar_pressure(P_display::AbstractArray)
    return use_GPa[1] ? P_display .* 10.0 : P_display
end

function display_ph_name(name::String)
    return use_warr_names[1] ? MAGEMin_C.get_Warr_name(name) : name
end

function display_ph_names(names::Vector{String})
    return use_warr_names[1] ? MAGEMin_C.get_Warr_names(names) : names
end

function ss_fname_lookup(dtb::String)
    db_in = retrieve_solution_phase_information(dtb)
    return Dict(s.ss_name => s.ss_fName for s in db_in.data_ss)
end

function display_ph_name_tagged(name::String, lookup::Dict{String,String})
    disp = display_ph_name(name)
    idx  = findfirst('_', name)
    if !isnothing(idx)
        tag = name[idx:end]
        occursin(tag, disp) && return disp
        startswith(name, disp) && return name
        return disp * tag
    end
    fname = get(lookup, name, name)
    idx2  = findfirst('_', fname)
    isnothing(idx2) && return disp
    tag = fname[idx2:end]
    occursin(tag, disp) && return disp
    return disp * tag
end

const TC_PRESET_PHASES = Dict(
    "mp"   => ["liq_W14", "fsp_H22", "bi_W14", "g_W14", "ep_H11", "ma_W14", "mu_W14", "opx_W14", "sa_W14", "cd_W14", "st_W14", "chl_W14", "ctd_W14", "sp_W02", "ilm_W00"],
    "mb"   => ["sp_W02", "opx_W14", "fsp_H22", "liq_G16", "mu_W14", "ilmm_W14", "ilm_W00", "ol_H11", "amp_G16", "ep_H11", "g_W14", "chl_W14", "bi_W14", "dio_G16", "aug_G16", "abc_H11", "spl_W02"],
    "ig"   => ["spl_T21", "bi_G25", "cd_G25", "cpx_W24", "ep_H11", "g_W24", "amp_G16", "ilm_W24", "liq_G25w", "ol_H18", "opx_W24", "fsp_H22", "fl_G25", "mu_W14", "fper", "chl_W14"],
    "igad" => ["spl_T21", "cpx_W24", "g_W24", "ilm_W24", "liq_S26", "ol_H18", "opx_W24", "fsp_H22", "lct_W24", "mel_W24", "nph_W24", "kals_W24"],
    "igd"  => ["spl_T21", "cpx_T21", "g_T21", "ilm_T21", "liq_S26", "ol_H18", "opx_T21", "fsp_H22op"],
    "um"   => ["fl_EF21", "ol_H11", "br_E13", "ch_EF21", "atg_EF21", "g_H18", "ta_EF21", "chl_W14", "spi_W02", "opx_W14", "po_E10", "anth_D07"],
)

const TC_PRESET_OPTIONS = [
    Dict("label" => "none",               "value" => "none"),
    Dict("label" => "Metapelite",         "value" => "mp"),
    Dict("label" => "Metabasite",         "value" => "mb"),
    Dict("label" => "Igneous",            "value" => "ig"),
    Dict("label" => "Igneous alkali-dry", "value" => "igad"),
    Dict("label" => "Igneous dry High-TiO2",        "value" => "igd"),
    Dict("label" => "Ultramafic",         "value" => "um"),
]

function preset_ss_selection(preset::String, available::Vector{String})
    return intersect(get(TC_PRESET_PHASES, preset, String[]), available)
end

"""
    preset_pp_selection(preset, available)

    Pure phases a preset keeps active: those the preset's own database defines, intersected
    with what the current database offers. Unlike `TC_PRESET_PHASES`, which is curated (it
    omits phases on purpose and picks the `fsp_H22op` feldspar for igd), this is read
    straight from the library - a pure phase belongs to a preset exactly when that database
    has it.

    Without this, a preset restricted only the solution phases and left every pure phase
    selected, so oxides no phase of the preset can host still looked covered: picking the
    "igd" preset in the "all" database left `law`, `H2O`, `zo`, `prl`, `mpm` and `pre`
    active, and `bulk_oxide_coverage_status` reported H2O as covered although igd has no
    H2O in its oxide set at all.
"""
function preset_pp_selection(preset::String, available::Vector{String})
    is_db(preset) || return available
    return intersect(available, retrieve_solution_phase_information(preset).data_pp)
end

function display_ph_names_tagged(names::Vector{String}, dtb::String)
    lookup = ss_fname_lookup(dtb)
    return [display_ph_name_tagged(n, lookup) for n in names]
end


function bulk_oxide_coverage_status(bulk_data, ss_selected, pp_selected)
    support = get_phase_oxide_support("all")

    needed = String[]
    for row in bulk_data
        frac = row["fraction"]
        (frac isa Number && frac > 0) && push!(needed, row["oxide"])
    end
    isempty(needed) && return ("success", "Bulk-rock covered by phase selection")

    selected = vcat(to_str_vec(ss_selected), to_str_vec(pp_selected))
    coverage_phases = Dict(ox => String[] for ox in needed)
    for ph in selected
        oxides = get(support, ph, Set{String}())
        for ox in needed
            (ox in oxides) && push!(coverage_phases[ox], ph)
        end
    end

    missing_ox = sort([ox for ox in needed if isempty(coverage_phases[ox])])
    single_ox  = sort([ox for ox in needed if length(coverage_phases[ox]) == 1])

    if !isempty(missing_ox)
        return ("danger", "Bulk-rock not covered by phase selection (missing: $(join(missing_ox, ", ")))")
    elseif !isempty(single_ox)
        single_desc = join(["$ox ($(coverage_phases[ox][1]))" for ox in single_ox], ", ")
        return ("warning", "Warning, only one selected phase covers: $single_desc")
    else
        return ("success", "Bulk-rock covered by phase selection")
    end
end

function keep_dataset(database_changed::Bool, current_dataset, db_in)
    (database_changed || !(current_dataset in db_in.dataset_opt)) && return db_in.db_dataset
    return current_dataset
end

function ds62_placeholder_alert(dtb, dataset, ss_selected)
    (isnothing(dtb) || isnothing(dataset)) && return (false, "")
    ds     = dataset isa Integer ? dataset : tryparse(Int, string(dataset))
    isnothing(ds) && return (false, "")
    phases = ds62_placeholder_phases(string(dtb), ds, to_str_vec(ss_selected))
    isempty(phases) && return (false, "")
    return (true, ds62_placeholder_warning(phases))
end

function to_str_vec(v::AbstractVector)
    return convert(Vector{String}, collect(v))
end
function to_str_vec(s::String)
    return String[s]
end
function to_str_vec(::Nothing)
    return String[]
end

"""
    round_sig(x; sig = 3, mindigits = 2)

    `x` rounded to `sig` significant digits, but never to fewer than `mindigits` decimals
    (so `1234.567` stays `1234.57` while `0.00012345` becomes `0.000123` instead of `0.0`).
    Used for the default colour and isopleth ranges, whose values can be tiny
    (e.g. the weight of zircon in the trace-element tab).
"""
function round_sig(x::Real; sig::Int = 3, mindigits::Int = 2)
    v = Float64(x)
    (v == 0.0 || !isfinite(v)) && return v
    return round(v, digits = max(mindigits, sig - 1 - floor(Int, log10(abs(v)))))
end

grid_min(g) = (v = skipmissing(g); isempty(v) ? 0.0 : minimum(v))
grid_max(g) = (v = skipmissing(g); isempty(v) ? 1.0 : maximum(v))

function iso_auto_range(vals::AbstractVector{<:Real})
    isempty(vals) && return nothing
    vmin, vmax = Float64.(extrema(vals))
    vmax - vmin > 1e-9 * max(abs(vmin), abs(vmax)) || return nothing
    e    = floor(Int, log10((vmax - vmin) / 10))
    m    = (vmax - vmin) / 10 / 10.0^e
    step = (m < 1.5 ? 1.0 : m < 3.5 ? 2.0 : m < 7.5 ? 5.0 : 10.0) * 10.0^e
    d    = max(0, -e + 1)
    return round(floor(vmin / step) * step, digits = d), round(step, digits = d), round(ceil(vmax / step) * step, digits = d)
end

function display_iso_label(label::String)
    !use_warr_names[1] && return label
    idx = findfirst('_', label)
    isnothing(idx) && return display_ph_name(label)
    phase = label[1:idx-1]
    suffix = label[idx:end]
    converted = MAGEMin_C.get_Warr_name(phase)
    endswith(converted, "*") && return label
    return converted * suffix
end

function display_em_label(label::String)
    !use_warr_names[1] && return label
    idx = findfirst(':', label)
    isnothing(idx) && return display_ph_name(label)
    phase = label[1:idx-1]
    suffix = label[idx:end]
    converted = MAGEMin_C.get_Warr_name(phase)
    endswith(converted, "*") && return label
    return converted * suffix
end

function display_em_labels(labels::Vector{String})
    return [display_em_label(l) for l in labels]
end

function display_phase_list(refType::String, out)
    if refType == "em"
        return display_em_labels(get_dominant_em(out.ph, out.n_SS, out.SS_vec))
    else
        return display_ph_names(out.ph)
    end
end

function sanitize_names(names::Vector{String})
    return [replace(replace(replace(replace(name, " " => "_"), "/" => "o"),"[" => ""),"]" => "") for name in names]
end

"""
    set_min_to_white(colormap; reverseColorMap = false)

    Colorscale stops of `colormap` with only the minimum of the range made white
    (transparent): a white stop at 0 followed, a hair above it, by the colormap's own
    first colour, so every value above the minimum keeps its colour. With
    `reverseColorMap` (Plotly's `reversescale` flips the stops) the white stop is put
    at 1 instead.
"""
function set_min_to_white(colormap; reverseColorMap = false)

    nc = length(colormap)
    if first(colormap) isa AbstractVector
        cust_color = [[colormap[i][1], colormap[i][2]] for i = 1:nc]
    else
        rgb255(c) = round(Int, 255 * clamp(c, 0, 1))
        cust_color = [ [(i-1)/(nc-1),"rgba($(rgb255(colormap[i].r)),$(rgb255(colormap[i].g)),$(rgb255(colormap[i].b)),1.0)"] for i = 1:nc]
    end

    white = "rgba(255,255,255,0.0)"
    eps   = 1e-4
    if reverseColorMap == false
        cust_color[1][1] = eps
        pushfirst!(cust_color, [0.0, white])
    else
        cust_color[end][1] = 1.0 - eps
        push!(cust_color, [1.0, white])
    end

    return cust_color
end

function get_jet_colormap(n)

    jet256 = ["RGB(0,0,127)", "RGB(0,0,132)", "RGB(0,0,136)", "RGB(0,0,141)", "RGB(0,0,145)", "RGB(0,0,150)", "RGB(0,0,154)", "RGB(0,0,159)", "RGB(0,0,163)", "RGB(0,0,168)", "RGB(0,0,172)", "RGB(0,0,177)", "RGB(0,0,182)", "RGB(0,0,186)", "RGB(0,0,191)", "RGB(0,0,195)", "RGB(0,0,200)", "RGB(0,0,204)", "RGB(0,0,209)", "RGB(0,0,213)", "RGB(0,0,218)", "RGB(0,0,222)", "RGB(0,0,227)", "RGB(0,0,232)", "RGB(0,0,236)", "RGB(0,0,241)", "RGB(0,0,245)", "RGB(0,0,250)", "RGB(0,0,254)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,4,255)", "RGB(0,8,255)", "RGB(0,12,255)", "RGB(0,16,255)", "RGB(0,20,255)", "RGB(0,24,255)", "RGB(0,28,255)", "RGB(0,32,255)", "RGB(0,36,255)", "RGB(0,40,255)", "RGB(0,44,255)", "RGB(0,48,255)", "RGB(0,52,255)", "RGB(0,56,255)", "RGB(0,60,255)", "RGB(0,64,255)", "RGB(0,68,255)", "RGB(0,72,255)", "RGB(0,76,255)", "RGB(0,80,255)", "RGB(0,84,255)", "RGB(0,88,255)", "RGB(0,92,255)", "RGB(0,96,255)", "RGB(0,100,255)", "RGB(0,104,255)", "RGB(0,108,255)", "RGB(0,112,255)", "RGB(0,116,255)", "RGB(0,120,255)", "RGB(0,124,255)", "RGB(0,128,255)", "RGB(0,132,255)", "RGB(0,136,255)", "RGB(0,140,255)", "RGB(0,144,255)", "RGB(0,148,255)", "RGB(0,152,255)", "RGB(0,156,255)", "RGB(0,160,255)", "RGB(0,164,255)", "RGB(0,168,255)", "RGB(0,172,255)", "RGB(0,176,255)", "RGB(0,180,255)", "RGB(0,184,255)", "RGB(0,188,255)", "RGB(0,192,255)", "RGB(0,196,255)", "RGB(0,200,255)", "RGB(0,204,255)", "RGB(0,208,255)", "RGB(0,212,255)", "RGB(0,216,255)", "RGB(0,220,254)", "RGB(0,224,250)", "RGB(0,228,247)", "RGB(2,232,244)", "RGB(5,236,241)", "RGB(8,240,237)", "RGB(12,244,234)", "RGB(15,248,231)", "RGB(18,252,228)", "RGB(21,255,225)", "RGB(24,255,221)", "RGB(28,255,218)", "RGB(31,255,215)", "RGB(34,255,212)", "RGB(37,255,208)", "RGB(41,255,205)", "RGB(44,255,202)", "RGB(47,255,199)", "RGB(50,255,195)", "RGB(54,255,192)", "RGB(57,255,189)", "RGB(60,255,186)", "RGB(63,255,183)", "RGB(66,255,179)", "RGB(70,255,176)", "RGB(73,255,173)", "RGB(76,255,170)", "RGB(79,255,166)", "RGB(83,255,163)", "RGB(86,255,160)", "RGB(89,255,157)", "RGB(92,255,154)", "RGB(95,255,150)", "RGB(99,255,147)", "RGB(102,255,144)", "RGB(105,255,141)", "RGB(108,255,137)", "RGB(112,255,134)", "RGB(115,255,131)", "RGB(118,255,128)", "RGB(121,255,125)", "RGB(124,255,121)", "RGB(128,255,118)", "RGB(131,255,115)", "RGB(134,255,112)", "RGB(137,255,108)", "RGB(141,255,105)", "RGB(144,255,102)", "RGB(147,255,99)", "RGB(150,255,95)", "RGB(154,255,92)", "RGB(157,255,89)", "RGB(160,255,86)", "RGB(163,255,83)", "RGB(166,255,79)", "RGB(170,255,76)", "RGB(173,255,73)", "RGB(176,255,70)", "RGB(179,255,66)", "RGB(183,255,63)", "RGB(186,255,60)", "RGB(189,255,57)", "RGB(192,255,54)", "RGB(195,255,50)", "RGB(199,255,47)", "RGB(202,255,44)", "RGB(205,255,41)", "RGB(208,255,37)", "RGB(212,255,34)", "RGB(215,255,31)", "RGB(218,255,28)", "RGB(221,255,24)", "RGB(224,255,21)", "RGB(228,255,18)", "RGB(231,255,15)", "RGB(234,255,12)", "RGB(237,255,8)", "RGB(241,252,5)", "RGB(244,248,2)", "RGB(247,244,0)", "RGB(250,240,0)", "RGB(254,237,0)", "RGB(255,233,0)", "RGB(255,229,0)", "RGB(255,226,0)", "RGB(255,222,0)", "RGB(255,218,0)", "RGB(255,215,0)", "RGB(255,211,0)", "RGB(255,207,0)", "RGB(255,203,0)", "RGB(255,200,0)", "RGB(255,196,0)", "RGB(255,192,0)", "RGB(255,189,0)", "RGB(255,185,0)", "RGB(255,181,0)", "RGB(255,177,0)", "RGB(255,174,0)", "RGB(255,170,0)", "RGB(255,166,0)", "RGB(255,163,0)", "RGB(255,159,0)", "RGB(255,155,0)", "RGB(255,152,0)", "RGB(255,148,0)", "RGB(255,144,0)", "RGB(255,140,0)", "RGB(255,137,0)", "RGB(255,133,0)", "RGB(255,129,0)", "RGB(255,126,0)", "RGB(255,122,0)", "RGB(255,118,0)", "RGB(255,115,0)", "RGB(255,111,0)", "RGB(255,107,0)", "RGB(255,103,0)", "RGB(255,100,0)", "RGB(255,96,0)", "RGB(255,92,0)", "RGB(255,89,0)", "RGB(255,85,0)", "RGB(255,81,0)", "RGB(255,77,0)", "RGB(255,74,0)", "RGB(255,70,0)", "RGB(255,66,0)", "RGB(255,63,0)", "RGB(255,59,0)", "RGB(255,55,0)", "RGB(255,52,0)", "RGB(255,48,0)", "RGB(255,44,0)", "RGB(255,40,0)", "RGB(255,37,0)", "RGB(255,33,0)", "RGB(255,29,0)", "RGB(255,26,0)", "RGB(255,22,0)", "RGB(254,18,0)", "RGB(250,15,0)", "RGB(245,11,0)", "RGB(241,7,0)", "RGB(236,3,0)", "RGB(232,0,0)", "RGB(227,0,0)", "RGB(222,0,0)", "RGB(218,0,0)", "RGB(213,0,0)", "RGB(209,0,0)", "RGB(204,0,0)", "RGB(200,0,0)", "RGB(195,0,0)", "RGB(191,0,0)", "RGB(186,0,0)", "RGB(182,0,0)", "RGB(177,0,0)", "RGB(172,0,0)", "RGB(168,0,0)", "RGB(163,0,0)", "RGB(159,0,0)", "RGB(154,0,0)", "RGB(150,0,0)", "RGB(145,0,0)", "RGB(141,0,0)", "RGB(136,0,0)", "RGB(132,0,0)", "RGB(127,0,0)"]

    np    = length(jet256)

    step  = Int64(floor(np/n))
    if step == 0
        step = 1
    end

    return jet256[1:step:end]

end

function get_lines_colormap()

    color_lines = [ "RGB(182,69,91)",
                    "RGB(182,69,156)",
                    "RGB(174,69,182)",
                    "RGB(107,69,182)",
                    "RGB(69,84,182)",
                    "RGB(69,152,182)",
                    "RGB(69,182,152)",
                    "RGB(69,182,91)",
                    "RGB(107,182,69)",
                    "RGB(159,182,69)",
                    "RGB(182,156,69)",
                    "RGB(182,122,69)",
                    "RGB(182,76,69)"]

    return color_lines

end

function get_init_param(    dtb         :: String,
                            solver      :: String,
                            cpx,        
                            limOpx,    
                            limOpxVal   :: Float64 )   

        # set clinopyroxene for the metabasite database
        mbCpx = 0
        if cpx == true && (dtb =="mb" || dtb =="mbe"  )
            mbCpx = 1;
        end
        limitCaOpx  = 0
        CaOpxLim    = 1.0
        if limOpx == "ON" && (dtb =="mb" || dtb =="mbe" || dtb =="ig" || dtb =="igd" || dtb =="alk")
            limitCaOpx   = 1
            CaOpxLim     = limOpxVal
        end
        if solver == "pge"
            sol = 1
        elseif solver == "lp"
            sol = 0
        elseif solver == "hyb" 
            sol = 2         
        end

    return mbCpx,limitCaOpx,CaOpxLim,sol

end

"""
    has_ns_optimizer(dtb)

    True for the databases with a nullspace optimizer in MAGEMin: THERMOCALC, Stixrude & Lithgow-Bertelloni (sb11, sb21, sb24),
    MELTS (pMELTS, rMELTS) and Berman (po)
"""
function has_ns_optimizer(  dtb         :: String )

    return has_dataset_choice(dtb) || dtb in ("sb11", "sb21", "sb24", "pMELTS", "rMELTS", "po")

end

"""
    get_optimizer(dtb, optimizer, sol)

    Local optimizer passed to MAGEMin: 1 (nullspace) when "ns" is selected, the legacy solver is used (sol = 0)
    and the database has a nullspace optimizer (`has_ns_optimizer`), 0 (NLopt) otherwise
"""
function get_optimizer(     dtb         :: String,
                            optimizer,
                            sol         :: Int64 )

    return (optimizer == "ns" && sol == 0 && has_ns_optimizer(dtb)) ? 1 : 0

end

function string_vec_diff(solution_ph_selection, pure_ph_selection, dtb)

    ss_selection = string_vec_diff_ss(solution_ph_selection,    dtb)
    pp_selection = string_vec_diff_pp(pure_ph_selection,        dtb)

    if isnothing(ss_selection) && isnothing(pp_selection)
        return nothing
    elseif isnothing(ss_selection)
        return pp_selection
    elseif isnothing(pp_selection)
        return ss_selection
    else
        return vcat(ss_selection,pp_selection)
    end

end


"""
    Function to retrieve active set of solution phases
"""
function string_vec_diff_ss(phase_selection,dtb)

    db_in                           = retrieve_solution_phase_information(dtb)
    set_A                           = phase_selection
    set_B                           = db_in.ss_name
    phase_selection                 = setdiff(set_B, set_A)
    if isempty(phase_selection)
        phase_selection = nothing
    end

    return phase_selection
end

function build_kds_database(kds_mod::String)
    if kds_mod == "CO"
        return MAGEMin_C.get_CO_KDs_database()
    elseif kds_mod == "Yak25"
        return MAGEMin_C.get_TE_database("Yak25")
    else
        TE_models   = [AppData.KDs[i][4] for i in 1:length(AppData.KDs)]
        id_TE_model = findfirst(TE_models .== kds_mod)
        if isnothing(id_TE_model)
            error("Unknown KDs model: $kds_mod")
        end
        return MAGEMin_C.create_custom_KDs_database(AppData.KDs[id_TE_model][1], AppData.KDs[id_TE_model][2], AppData.KDs[id_TE_model][3]; info = AppData.KDs[id_TE_model][6])
    end
end

"""
    Function to retrieve active set of pure phases
"""
function string_vec_diff_pp(phase_selection,dtb)

    db_in                           = retrieve_solution_phase_information(dtb)
    set_A                           = phase_selection
    pp_all                          = db_in.data_pp
    set_B                           = setdiff(pp_all, AppData.hidden_pp)

    pure_phase_selection            = setdiff(set_B, set_A)
    if isempty(pure_phase_selection)
        pure_phase_selection = nothing
    end

    return pure_phase_selection
end


"""
    export_rho_for_LaMEM()
    This function export a density diagram in the the right format to be directly used in LaMEM
"""
function save_rho_for_LaMEM(    dtb         ::String,
                                sub         ::Int64,
                                refLvl      ::Int64,
                                Xrange,
                                Yrange,
                                bulk1                  )

    np          = length(Out_XY)

    field2save  = ["rho_M","rho_S","frac_M"]
    ncol        = length(field2save)
    field       = Matrix{Union{Float64,Missing}}(undef,np,ncol);

    for j=1:ncol
        for i=1:np
            field[i,j] = Float64(get_property(Out_XY[i], field2save[j]));
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    T            = vcat(x)
    P            = vcat(y)
    gridded      = Array{Union{Float64,Missing}}(undef,n,n,ncol);

    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    for l=1:ncol
        for k=1:np
            ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
            jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
            gridded[ii,jj,l]  = field[k,l] 
        end

        for i=1:length(data.cells)
            cell    = data.cells[i]
            tmp     = field[cell[1],l] 

            ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
            jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            for ii = ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
            end

            jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
            jj_ix = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

            for ii in ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
                for jj in jj_min+1:jj_max-1
                    gridded[ii, jj,l] = tmp
                end
            end

        end
    end

    # filter some potential iffy values
    gridded[gridded[:,:,2] .== 0.0,2] .= 3000.0
    gridded[isnan.(gridded[:,:,2]),2] .= 3000.0
    gridded[gridded[:,:,1] .== 0.0,1] .= 2000.0
    gridded[isnan.(gridded[:,:,1]),1] .= 2000.0
    gridded[gridded[:,:,3] .> 1.0,3]  .= 1.0

    # convert values
    T      .= T .+ 273.15            # --> to K
    P      .= P .* 1e3               # --> to bar

    nT      =  length(x)
    nP      =  length(y)
    dT      = (maximum(x)-minimum(x))/(nT-1);
    dP      = (maximum(y)-minimum(y))/(nP-1)*1000.0;

    # retrieve bulk rock composition and associated oxide list
    n_ox    = length(bulk1);
    bulk    = zeros(n_ox); 
    oxi     = Vector{String}(undef, n_ox)
    for i=1:n_ox
        tmp = bulk1[i][:fraction]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        bulk[i]   = tmp;
        oxi[i]    = bulk1[i][:oxide];
    end

    file        = ""
    file       *= @sprintf("5\n")
    file       *= @sprintf("\n")
    file       *= @sprintf("Phase diagram always needs this 5 columns:\n")
    file       *= @sprintf("       1               2                     3            4        5\n");
    file       *= @sprintf("rho_melt[kg/m3]   melt_fraction[wt]   rho_solid[kg/m3]   T[K]   P[bar]\n");
    file       *= @sprintf("1-49:  Comments\n");
    file       *= @sprintf("50:    Lowest T [K]\n");
    file       *= @sprintf("51:    T increment\n");
    file       *= @sprintf("52:    # of T values\n");
    file       *= @sprintf("53:    Lowest P [bar]\n");
    file       *= @sprintf("54:    P increment\n");
    file       *= @sprintf("55:    # of P values\n");

    for i=1:4
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("Phase diagram produced using MAGEMin v%s with database %5s\n",Out_XY[1].MAGEMin_ver,dtb)
    file       *= @sprintf("Bulk rock composition[mol fraction]\n")
    for i=1:n_ox
        file   *= @sprintf("%8s : %+5.10f\n",oxi[i],bulk[i])
    end
    for i=n_ox+1:11
        file   *= @sprintf("\n")
    end
    for i=1:19
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("[meltRho, rho, kg/m^3] [meltFrac, wtPercent, NoUnits] [rockRho, rho, kg/m^3] [Temperature, T, K] [Pressure, P, bar]   \n");
    file       *= @sprintf("%5.10f\n",minimum(T));
    file       *= @sprintf("%5.10f\n",dT);
    file       *= @sprintf("%d\n",nT);
    file       *= @sprintf("%5.10f\n",minimum(P));
    file       *= @sprintf("%5.10f\n",dP);
    file       *= @sprintf("%d\n",nP);
    for j=1:nP
        for i=1:nT
            file   *= @sprintf("%5.6f %5.6f %5.6f %5.6f %5.6f\n",gridded[i,j,1],gridded[i,j,3],gridded[i,j,2],T[i],P[j])
        end
    end


    return file
end


"""
save_rho_for_GeoModel()
    This function export parameters useful for geodynamic coupling -> P,T, rho_S, rho_M, Frac_M, Vp, Vs, s_cp
"""
function save_rho_for_GeoModel(     dtb         ::String,
                                    sub         ::Int64,
                                    refLvl      ::Int64,
                                    Xrange,
                                    Yrange,
                                    bulk1                  )

    np          = length(Out_XY)

    field2save  = ["rho_M","rho_S","frac_M","Vp","Vs","s_cp","alpha"]
    ncol        = length(field2save)
    field       = Matrix{Union{Float64,Missing}}(undef,np,ncol);

    for j=1:ncol
        if field2save[j] == "s_cp"
            for i=1:np
                field[i,j] = Out_XY[i].s_cp[1];
            end
        elseif field2save[j] == "alpha"
            for i=1:np
                field[i,j] = Out_XY[i].alpha[1];
            end
        else
            for i=1:np
                field[i,j] = Float64.(get_property(Out_XY[i], field2save[j]));
            end
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    T            = vcat(x)
    P            = vcat(y)
    gridded      = Array{Union{Float64,Missing}}(undef,n,n,ncol);

    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    for l=1:ncol
        for k=1:np
            ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
            jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
            gridded[ii,jj,l]  = field[k,l] 
        end

        for i=1:length(data.cells)
            cell    = data.cells[i]
            tmp     = field[cell[1],l] 

            ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
            jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            for ii = ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
            end

            jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
            jj_ix = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

            for ii in ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
                for jj in jj_min+1:jj_max-1
                    gridded[ii, jj,l] = tmp
                end
            end

        end
    end

    # filter some potential iffy values
    gridded[gridded[:,:,2] .== 0.0,2] .= 3000.0
    gridded[isnan.(gridded[:,:,2]),2] .= 3000.0
    gridded[gridded[:,:,1] .== 0.0,1] .= 2000.0
    gridded[isnan.(gridded[:,:,1]),1] .= 2000.0
    gridded[gridded[:,:,3] .> 1.0,3]  .= 1.0

    # convert values
    T      .= T .+ 273.15            # --> to K
    P      .= P .* 1e3 .* 1e5        # --> to Pa

    nT      =  length(x)
    nP      =  length(y)
    dT      = (maximum(x)-minimum(x))/(nT-1);
    dP      = (maximum(y)-minimum(y))/(nP-1).* 1e3 .* 1e5;        # --> to Pa

    # retrieve bulk rock composition and associated oxide list
    n_ox    = length(bulk1);
    bulk    = zeros(n_ox); 
    oxi     = Vector{String}(undef, n_ox)
    for i=1:n_ox
        tmp = bulk1[i][:fraction]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        bulk[i]   = tmp;
        oxi[i]    = bulk1[i][:oxide];
    end

    file        = ""
    file       *= @sprintf("8\n")
    file       *= @sprintf("\n\n")
    file       *= @sprintf("       1               2                     3                4        5             6       7        8\n");
    file       *= @sprintf("rho_melt[kg/m3]   melt_fraction[wt]   rho_solid[kg/m3]    Vp[km/s]  Vs[km/s]  s_cp[J/kg/K]  T[K]   P[Pa]  \n");
    file       *= @sprintf("1-49:  Comments\n");
    file       *= @sprintf("50:    Lowest T [K]\n");
    file       *= @sprintf("51:    T increment\n");
    file       *= @sprintf("52:    # of T values\n");
    file       *= @sprintf("53:    Lowest P [Pa]\n");
    file       *= @sprintf("54:    P increment\n");
    file       *= @sprintf("55:    # of P values\n");

    for i=1:4
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("Phase diagram produced using MAGEMin v%s with database %5s\n",Out_XY[1].MAGEMin_ver,dtb)
    file       *= @sprintf("Bulk rock composition[mol fraction]\n")
    for i=1:n_ox
        file   *= @sprintf("%8s : %+5.10f\n",oxi[i],bulk[i])
    end
    for i=n_ox+1:11
        file   *= @sprintf("\n")
    end
    for i=1:19
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("[meltRho, rho, kg/m^3] [meltFrac, wtPercent, NoUnits] [rockRho, rho, kg/m^3] [Vp, vp, km/s] [Vs, vs, km/s] [SpecificCp, scp, J/kg/K] [Temperature, T, K] [Pressure, P, Pa]   \n");
    file       *= @sprintf("%5.10f\n",minimum(T));
    file       *= @sprintf("%5.10f\n",dT);
    file       *= @sprintf("%d\n",nT);
    file       *= @sprintf("%5.10f\n",minimum(P));
    file       *= @sprintf("%5.10f\n",dP);
    file       *= @sprintf("%d\n",nP);
    for j=1:nP
        for i=1:nT
            file   *= @sprintf("%5.6f %5.6f %5.6f %5.6f %5.6f %5.6f %5.6f %5.6f\n",gridded[i,j,1],gridded[i,j,3],gridded[i,j,2],gridded[i,j,4],gridded[i,j,5],gridded[i,j,6],T[i],P[j])
        end
    end


    return file
end


"""
    save equilibrium function
"""
function save_equilibrium_to_file(  out::MAGEMin_C.gmin_struct{Float64, Int64}, dtb, mbCpx )

    file = ""
    file *= @sprintf("============================================================\n")
    for i=1:length(out.ph)
        file *= @sprintf(" %4s ",display_ph_name(out.ph[i]))
    end
    file *= @sprintf(" {%.4f %.4f} %s/°C\n\n",display_pressure(out.P_kbar),out.T_C,pressure_unit_label())

    file *= @sprintf("End-members fractions[wt fr]:\n")
    for i=1:out.n_SS
        for j=1:length(out.SS_vec[i].emNames)
            file *= @sprintf(" %8s",display_ph_name(out.SS_vec[i].emNames[j]))
        end
        file *= @sprintf("\n")
        for j=1:length(out.SS_vec[i].emFrac_wt)
            file *= @sprintf(" %8f",out.SS_vec[i].emFrac_wt[j])
        end
        file *= @sprintf("\n")        
    end
    file *= @sprintf("\n") 


    file *= @sprintf("Oxide compositions [wt fr]:\n")
    file *= @sprintf("% 8s"," ") 
    for i=1:length(out.oxides)
        file *= @sprintf(" %8s",out.oxides[i]) 
    end
    file *= @sprintf("\n")   
    file *= @sprintf(" %8s","SYS") 
    for i=1:length(out.bulk_wt)
        file *= @sprintf(" %8f",out.bulk_wt[i])
    end
    file *= @sprintf("\n")  
    file *= @sprintf(" %8s","SOL") 
    for i=1:length(out.bulk_S_wt)
        file *= @sprintf(" %8f",out.bulk_S_wt[i])
    end
    file *= @sprintf("\n")  
    for i=1:out.n_SS
        file *= @sprintf(" %8s",display_ph_name(out.ph[i]))
        for j=1:length(out.SS_vec[i].Comp_wt)
            file *= @sprintf(" %8f",out.SS_vec[i].Comp_wt[j])
        end
        file *= @sprintf("\n")
    end
    for i=1:out.n_PP
        file *= @sprintf(" %8s",display_ph_name(out.ph[i+out.n_SS]))
        for j=1:length(out.PP_vec[i].Comp_wt)
            file *= @sprintf(" %8f",out.PP_vec[i].Comp_wt[j])
        end
        file *= @sprintf("\n")
    end
    file *= @sprintf("\n")

    file *= @sprintf("Stable mineral assemblage:\n")    
    file *= @sprintf("%6s%15s %13s %17s %17s %12s %12s %12s %12s %12s %12s %12s %12s %12s\n","phase","fraction[wt]","G[kJ]" ,"V_molar[cm3/mol]","V_partial[cm3]" ,"Cp[kJ/K]","Rho[kg/m3]","Alpha[1/K]","Entropy[kJ/K]","Enthalpy[kJ/mol]","BulkMod[GPa]","ShearMod[GPa]","Vp[km/s]","Vs[km/s]")
   
    for i=1:out.n_SS
        file *= @sprintf("%6s",display_ph_name(out.ph[i]))
        file *= @sprintf("%+15.5f %+13.5f %+17.5f %+17.5f %+12.5f %+12.5f %+12.8f %+12.6f %+12.4f %+12.2f %+12.2f %+13.2f %+12.2f",
                        out.ph_frac_wt[i],
                        out.SS_vec[i].G,
                        out.SS_vec[i].V,
                        out.SS_vec[i].V*out.ph_frac[i]*out.SS_vec[i].f,
                        out.SS_vec[i].cp,
                        out.SS_vec[i].rho,
                        out.SS_vec[i].alpha,
                        out.SS_vec[i].entropy,
                        out.SS_vec[i].enthalpy,
                        out.SS_vec[i].bulkMod,
                        out.SS_vec[i].shearMod,
                        out.SS_vec[i].Vp,
                        out.SS_vec[i].Vs)
        file *= @sprintf("\n")  
    end

    for i=1:out.n_PP
        file *= @sprintf("%6s",display_ph_name(out.ph[i+out.n_SS]))
        file *= @sprintf("%+15.5f %+13.5f %+17.5f %+17.5f %+12.5f %+12.5f %+12.8f %+12.6f %+12.4f %+12.2f %+12.2f %+13.2f %+12.2f",
                        out.ph_frac_wt[i],
                        out.PP_vec[i].G,
                        out.PP_vec[i].V,
                        out.PP_vec[i].V*out.ph_frac[i+out.n_SS]*out.PP_vec[i].f,
                        out.PP_vec[i].cp,
                        out.PP_vec[i].rho,
                        out.PP_vec[i].alpha,
                        out.PP_vec[i].entropy,
                        out.PP_vec[i].enthalpy,
                        out.PP_vec[i].bulkMod,
                        out.PP_vec[i].shearMod,
                        out.PP_vec[i].Vp,
                        out.PP_vec[i].Vs)
        file *= @sprintf("\n")  
    end

    file *= @sprintf("%6s %14s %+13.5f %17s %+17.5f %+12.5f %+12.5f %12s %+12.6f %+12.4f %+12.5f %+12.5f %+13.5f %+12.5f\n",
                    "SYS",
                    " ",
                    out.G_system,
                    " ",    
                    0, #V
                    0, #cp
                    out.rho,
                    " ",  
                    out.entropy[1],
                    out.enthalpy[1],
                    out.bulkMod,
                    out.shearMod,
                    out.Vp,
                    out.Vs   )
    file *= @sprintf("\n")    

    file *= @sprintf("Gamma[J] (chemical potential of oxides):\n")  
    for i=1:length(out.oxides)
        file *= @sprintf(" %6s %8.3f\n",out.oxides[i],out.Gamma[i]) 
    end
    file *= @sprintf("\n") 

    file *= @sprintf("System fugacity:\n")  
    file *= @sprintf(" %6s %g\n","fO2",out.fO2)  
    file *= @sprintf(" %6s %g\n","dQFM",out.dQFM)  
    file *= @sprintf("\n\n") 

    file *= @sprintf("G-hyperplane distance[J]:\n")
    for i=1:out.n_SS
        file *= @sprintf(" %6s %12.8f\n",display_ph_name(out.ph[i]),out.SS_vec[i].deltaG)
    end
    file *= @sprintf("\n\n") 

    #for THERMOCALC
    if mbCpx == true; aug = 1;
    else  aug = 0; end

    # solution-phase label to use per stable phase; when the same underlying
    # solution model is stable more than once (solvus splitting into two
    # coexisting phases), THERMOCALC distinguishes the repeats with a numeral
    # suffix (e.g. "cpx", "cpx2")
    phs  = [get_ss_from_mineral(dtb, out.ph[i], aug, [out.sol_name[i]]) for i=1:out.n_SS]
    seen = Dict{String,Int}()
    for i=1:out.n_SS
        n_seen = get(seen, phs[i], 0) + 1
        seen[phs[i]] = n_seen
        if n_seen > 1
            phs[i] = phs[i] * string(n_seen)
        end
    end

    file *= @sprintf("Initial guess for THERMOCALC:\n")
    file *= @sprintf("%% ----------------------------------------------------------\n")
    file *= @sprintf("%% at P =  %12.8f, T = %12.8f, for: ",out.P_kbar,out.T_C)
    for i=1:out.n_SS
        file *= @sprintf("%s ",phs[i])
    end
    file *= @sprintf("\n")
    file *= @sprintf("%% ----------------------------------------------------------\n")
    file *= @sprintf("ptguess  %12.8f %12.8f\n",out.P_kbar,out.T_C)
    file *= @sprintf("%% ----------------------------------------------------------\n")
    n = 1;


    for i=1:out.n_SS
        for j=1:length(out.SS_vec[i].emFrac)-1
            file *= @sprintf(	"xyzguess %5s(%s) %10f\n", out.SS_vec[i].compVariablesNames[j],phs[i] ,out.SS_vec[i].compVariables[j])
        end
        if n < out.n_SS
            file *= @sprintf("%% -----------------------------\n");
        end
        n += 1
    end
    file *= @sprintf("%% —————————————————————————————\n");

    return file
end


"""
    Function to restrict colormap range
"""
function restrict_colorMapRange(    colorMap    ::String,
                                    rangeColor  :: Union{JSON3.Array{Int64, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}},Vector{Int64}} )

    n       = rangeColor[2]-rangeColor[1]
    colorm  = Vector{Vector{Any}}(undef,10)

    rin     = zeros(n+1)
    gin     = zeros(n+1)
    bin     = zeros(n+1)
    xin     = zeros(n+1)

    m       = length(colors[Symbol(colorMap)])
    cor     = Int64(floor(m/9))

    k = 1
    for i=rangeColor[1]*cor:cor:rangeColor[2]*cor
        rin[k] = colors[Symbol(colorMap)][i].r
        gin[k] = colors[Symbol(colorMap)][i].g
        bin[k] = colors[Symbol(colorMap)][i].b
        xin[k] = i
        k += 1
    end

    r_interp    = linear_interpolation(xin, rin)
    g_interp    = linear_interpolation(xin, gin)
    b_interp    = linear_interpolation(xin, bin)
    xmid        = vcat( (rangeColor[1]*cor) : (rangeColor[2]-rangeColor[1])/9.0*cor : (rangeColor[2]*cor) )

    rout        = r_interp(xmid)
    gout        = g_interp(xmid)
    bout        = b_interp(xmid)

    for i = 1:10
        ix          = 1.0/9.0 * Float64(i) - 1.0/9.0
        clr         = "rgb("*string(Int64(round(rout[i]*255)))*","*string(Int64(round(gout[i]*255)))*","*string(Int64(round(bout[i]*255)))*")"
        colorm[i]   = [ix, clr]
    end

    return colorm
end

function get_phase_infos(       Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}})

    np          = length(Out_XY)
    
    # here we also get information about the phases that are stable accross the diagram and their potential solvus
    act_ss      = []
    act_pp      = []

    reac_ss     = []
    reac_pp     = []

    def         = ("solid",0.75,"#000000",10.0,"")

    act_sol     = []
    for i = 1:np
        n_ph = length(Out_XY[i].ph)
        n_SS = Out_XY[i].n_SS
        for k in Out_XY[i].sol_name[1:n_SS]
            if k in act_sol
            else 
                push!(act_sol, k) 
            end
        end
        for k in Out_XY[i].ph[1:n_SS]
            if k in act_ss
            else 
                push!(reac_ss, def) 
                push!(act_ss, k) 
            end
        end
        if n_ph > n_SS
            for k in Out_XY[i].ph[1+n_SS:n_ph]
                if k in act_pp
                else
                    push!(reac_pp, def) 
                    push!(act_pp, k)
                end
            end
        end

    end

    phase_infos = ( act_pp       = act_pp,
                    act_ss       = act_ss,
                    reac_pp      = reac_pp,
                    reac_ss      = reac_ss,
                    act_sol      = act_sol  )
    return phase_infos
end

"""
    Function to retrieve the field labels
"""
function get_diagram_labels(    Out_XY      :: Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                                Hash_XY     :: Vector{UInt64},
                                refType     :: String,
                                data        :: MAGEMinApp.AMR_data,
                                PT_infos    :: Vector{String};
                                field_size  :: Int64 = 4 )

    global n_lbl, gridded_fields, phase_infos
    print("Get phase diagram labels ..."); t0 = time();

    np          = length(data.points)
    ph          = Vector{String}(undef,np)
    phd         = Vector{String}(undef,np)
    fac         = (data.Xrange[2]-data.Xrange[1])*(data.Yrange[2]-data.Yrange[1])

    if refType == "ph"
        for i = 1:np
            phd[i]      = ""
            for k=1:length(Out_XY[i].ph)
                phd[i] *= display_ph_name(Out_XY[i].ph[k])*" "
                if k % 3 == 0
                    phd[i] *= "<br>"
                end
            end
            ph[i]       = join(display_ph_names(Out_XY[i].ph)," ")
        end

    elseif refType == "em"
        for i = 1:np
            ph_em = get_dominant_em(    Out_XY[i].ph,
                                        Out_XY[i].n_SS,
                                        Out_XY[i].SS_vec)
            phd[i]      = ""
            for k=1:length(ph_em)
                phd[i] *= display_em_label(ph_em[k])*" "
                if k % 3 == 0
                    phd[i] *= "<br>"
                end
            end
            ph[i]       = join(display_em_labels(ph_em)," ")
        end
    end

    hull            = unique(Hash_XY)
    n_hull          = length(hull)
    area            = Vector{Any}(undef,    n_hull)
    n_pix           = Vector{Int64}(undef,    n_hull)
    ph_list         = Vector{String}(undef, n_hull)
    phd_list        = Vector{String}(undef, n_hull)
    raw_field_id    = Vector{Int64}(undef, n_hull)     # compacted field index -> raw gridded_fields id
    id          = 0
    coor        = []
    cands       = Vector{Vector{NTuple{2,Float64}}}()

    hull_id     = Dict(h => k for (k, h) in enumerate(hull))
    members     = [Int64[] for _ in 1:n_hull]
    for (k, h) in enumerate(Hash_XY)
        push!(members[hull_id[h]], k)
    end
    for i = 1:n_hull

        field_tmp   = members[i]
        np          = length(field_tmp)
        if np > 4
            id             += 1
            ph_list[id]     = ph[field_tmp[1]]
            phd_list[id]    = phd[field_tmp[1]]
            raw_field_id[id]= i

            mask, bnds      = reduce_matrix(ifelse.(gridded_fields .!= i, 0, 1))
            mask            = BitArray(expand_with_zeros(mask))

            dx              = (data.Xrange[2]-data.Xrange[1])/(size(gridded_fields,1)-1)
            dy              = (data.Yrange[2]-data.Yrange[1])/(size(gridded_fields,2)-1)
            
            minX            = data.Xrange[1] + dx*(bnds[1]-1) - dx/2
            maxX            = data.Xrange[1] + dx*(bnds[2]-1) + dx/2
            minY            = data.Yrange[1] + dy*(bnds[3]-1) - dy/2
            maxY            = data.Yrange[1] + dy*(bnds[4]-1) + dy/2
            n_pix[id]       = Float64(sum(mask))
            area[id]        = n_pix[id]*dx*dy/fac
            Yb              = range(minY, maxY, size(mask,2)+1)
            Xb              = range(minX, maxX, size(mask,1)+1)
            centers         = select_point(mask, Yb, Xb)

            push!(coor,centers)
            push!(cands, pd_field_candidates(mask, Yb, Xb, centers, data.Xrange, data.Yrange))
        end
    end

    n_trace     = id;
    traces      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,n_trace+1);
    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,n_trace+2)

    txt_list            = ""
    assemblage_rows     = Vector{Dict{String,String}}()   # one row per numbered txt_list entry, for the phase-assemblage table
    list_compacted_idx  = Vector{Int64}()                 # same order: compacted field index (1:n_trace, matches data_plot slot i+1)
    for i=1:n_trace
        traces[i+1] = scatter(; x           =  nothing,
                                y           =  nothing,
                                fill        = "toself",
                                fillcolor   = "transparent",
                                line_width  =  0.0,
                                mode        = "lines",
                                hoverinfo   = "text",
                                showlegend  = false,
                                text        = ph_list[i]        );
    end

    Xr, Yr      = data.Xrange, data.Yrange
    shown       = [i for i in 1:n_trace if n_pix[i] > field_size]
    n_num       = count(i -> area[i] <= 0.03, shown)
    num_txt     = "8"^length(string(max(n_num, 1)))
    labels      = PDLabel[]
    for i in shown
        anchor  = pd_to_px(coor[i][1], coor[i][2], Xr, Yr)
        pxc     = [pd_to_px(c[1], c[2], Xr, Yr) for c in cands[i]]
        if area[i] < 0.004
            push!(labels, PDLabel(i, :arrow, num_txt, 9.0, anchor, pxc))
        elseif area[i] > 0.03
            push!(labels, PDLabel(i, :full, pd_label_text(phd_list[i]), 10.0, anchor, pxc))
        else
            push!(labels, PDLabel(i, :num, num_txt, 10.0, anchor, pxc))
        end
    end
    pd_place_labels!(labels)

    for i=1:n_trace
        annotations[i] = attr(  xref        = "x",
                                yref        = "y",
                                align       = "left",
                                valign      = "top",
                                x           = coor[i][1],
                                y           = coor[i][2],
                                text        = "",
                                showarrow   = false,
                                visible     = false,
                                font        = attr( size = 10, color = "#212121"),
                            )
    end

    for l in labels
        l.kind == :full || continue
        x, y = pd_to_data(l.pos[1], l.pos[2], Xr, Yr)
        annotations[l.field] = attr(    xref        = "x",
                                        yref        = "y",
                                        align       = "left",
                                        valign      = "top",
                                        x           = x,
                                        y           = y,
                                        text        = l.text,
                                        showarrow   = false,
                                        visible     = true,
                                        font        = attr( size = 10, color = "#212121"),
                                    )
    end

    numbered = pd_number_order(labels, [k for k in eachindex(labels) if labels[k].kind != :full])
    for (cnt, k) in enumerate(numbered)
        l = labels[k]
        i = l.field
        if l.kind == :arrow
            annotations[i] = attr(  xref        = "x",
                                    yref        = "y",
                                    x           = coor[i][1],
                                    y           = coor[i][2],
                                    ax          = l.pos[1] - l.anchor[1],
                                    ay          = l.pos[2] - l.anchor[2],
                                    text        = string(cnt),
                                    showarrow   = true,
                                    arrowhead   = 1,
                                    visible     = true,
                                    font        = attr( size = 9, color = "#212121"),
                                )
        else
            x, y = pd_to_data(l.pos[1], l.pos[2], Xr, Yr)
            annotations[i] = attr(  xref        = "x",
                                    yref        = "y",
                                    align       = "left",
                                    valign      = "top",
                                    x           = x,
                                    y           = y,
                                    text        = string(cnt),
                                    showarrow   = false,
                                    visible     = true,
                                    font        = attr( size = 10, color = "#212121"),
                                )
        end
        txt_list *= string(cnt)*") "*ph_list[i]*"\n"
        push!(assemblage_rows, Dict("N" => string(cnt), "Assemblage" => ph_list[i]))
        push!(list_compacted_idx, i)
    end

    annotations[n_trace+1] =   attr(    xref        = "paper",
                                        yref        = "paper",
                                        align       = "left",
                                        valign      = "top",
                                        x           = 0.0,
                                        y           = 0.0,
                                        yshift      = -250,
                                        text        = PT_infos[1],
                                        showarrow   = false,
                                        clicktoshow = false,
                                        visible     = true,
                                        font        = attr( size = 10),
                                        )   

    annotations[n_trace+2] =   attr(    xref        = "paper",
                                        yref        = "paper",
                                        align       = "left",
                                        valign      = "top",
                                        x           = 0.2,
                                        y           = 0.0,
                                        yshift      = -250,
                                        text        = PT_infos[2],
                                        showarrow   = false,
                                        clicktoshow = false,
                                        visible     = true,
                                        font        = attr( size = 10),
                                        )   

    n_lbl = n_trace
    println("\rGet phase diagram labels $(round(time()-t0, digits=3)) seconds");

    return traces, annotations, txt_list, assemblage_rows, list_compacted_idx, raw_field_id
end

"""
    compute_assemblage_boundaries(gridded_fields, Xrange, Yrange; nit=2)

    Trace the boundary polygon of every phase-assemblage field in `gridded_fields`
    (the same per-pixel raster built by `get_gridded_map`), using the boundary
    tracer in `src/Boundaries/poly.jl`. Returns `(phases, pcoor)`: `phases[k]` is the
    raw field id (matching `gridded_fields`'s values, and `get_diagram_labels`'s
    `list_field_ids`) of domain `k`, `pcoor[k]` its ordered (x,y) boundary polygon.
    Meant to be called once per diagram build (compute/refine), not per selection.
"""
function compute_assemblage_boundaries(gridded_fields::Matrix{Int64}, Xrange, Yrange; nit::Int64 = 2)
    nr, nc  = size(gridded_fields)
    dx      = (Xrange[2]-Xrange[1])/(nr-1)
    dy      = (Yrange[2]-Yrange[1])/(nc-1)
    Xnodes  = range(Xrange[1]-dx/2, Xrange[2]+dx/2, length=nr+1)
    Ynodes  = range(Yrange[1]-dy/2, Yrange[2]+dy/2, length=nc+1)

    # get_poly(phase, P, T, nit) builds nodes as [T[I] P[J]] with I indexing rows (nr+1)
    # and J indexing columns (nc+1) of `phase` -- so P must be the column-length (Ynodes)
    # array and T the row-length (Xnodes) array for nodes to come out as (x,y) pairs.
    try
        _, _, _, pcoor, phases = get_poly(gridded_fields, Ynodes, Xnodes, nit)
        return phases, pcoor
    catch e
        # boundary tracing is best-effort (some field topologies aren't resolvable into a
        # single simple polygon) -- fall back to "no boundaries available" rather than
        # letting a highlighting failure take down the whole diagram build
        println("Could not trace phase-assemblage boundaries: $e")
        return Int64[], Matrix{Float64}[]
    end
end

"""
    Function to generate the frame of the diagrams,
    This includes MAGEMin logo, outline and ticks
"""
function get_plot_frame(Xrange, Yrange, ticks)

    frame   = Array{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}, 1}(undef, 1+4+ticks*6)
    # frame   = Array{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}, 1}(undef, 1+4+1)

    outline = [ attr(
        source  =  "assets/static/images/MAGEMin.jpg",
        xref    = "paper",
        yref    = "paper",
        x       =  0.05,
        y       =  1.01,
        sizex   =  0.1, 
        sizey   =  0.1,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_v.png",
        xref    = "paper",
        yref    = "paper",
        x       =  0.0,
        y       =  0.0,
        sizex   =  0.002, 
        sizey   =  1.0,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_v.png",
        xref    = "paper",
        yref    = "paper",
        x       =  1.0,
        y       =  0.0,
        sizex   =  0.002, 
        sizey   =  1.0,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_h.png",
        xref    = "paper",
        yref    = "paper",
        x       =  1.0,
        y       =  0.0,
        sizex   =  1.0, 
        sizey   =  0.002,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_h.png",
        xref    = "paper",
        yref    = "paper",
        x       =  1.0,
        y       =  1.0,
        sizex   =  1.0, 
        sizey   =  0.002,
        xanchor = "right", 
        yanchor = "bottom"
    )]

    frame[1:5] .= outline

    dx = 1.0/(ticks+1)
    dy = 1.0/(ticks+1)


    frame[6] = attr(        source  = "assets/static/images/img_h_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            x       =  0.0,
                            y       =  dy,
                            sizex   =  0.005, 
                            sizey   =  0.002,
                            xanchor = "right", 
                            yanchor = "bottom"  )  

  

    n = 6
    for i=0:(ticks+1)

        frame[n] = attr(    source  = "assets/static/images/img_h_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            # x       =  0.005,
                            x       =  0.0,
                            y       =  dy*i,

                            sizex   =  0.005, 
                            sizey   =  0.002,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1
        frame[n] = attr(    source  = "assets/static/images/img_h_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            # x       =  1.0,
                            x       =  1.005,
                            y       =  dy*i,

                            sizex   =  0.005, 
                            sizey   =  0.002,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1
        frame[n] = attr(    source  = "assets/static/images/img_v_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            x       =  dx*i,
                            # y       =  0.0,
                            y       =  -0.005,

                            sizex   =  0.002, 
                            sizey   =  0.005,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1
        frame[n] = attr(    source  = "assets/static/images/img_v_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            x       =  dx*i,
                            # y       =  0.995,
                            y       =  1.0,

                            sizex   =  0.002, 
                            sizey   =  0.005,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1

    end
    
    return frame
end


"""
    Function interpolate AMR grid to regular grid
"""
function get_gridded_map(   fieldname   ::String,
                            type        ::String,
                            oxi         ::Vector{String},
                            Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                            Out_TE_XY   ::Union{Nothing,Vector{MAGEMin_C.out_tepm}},
                            Hash_XY     ::Vector{UInt64},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            refType     ::String,
                            data        ::MAGEMinApp.AMR_data,
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64} )

    print("Interpolate data on grid ..."); t0 = time()
    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing,Nothing}}(undef,np);
 
    npoints     = np

    meant       = 0.0
    for i=1:np
        meant  += Out_XY[i].time_ms
    end
    meant      /= npoints
    meant       = round(meant; digits = 3)

    if type == "zrc"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "sulf"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "fapt"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "co2sat"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "mnz"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    else
        if fieldname == "#Phases"
            for i=1:np
                field[i] = Float64(length(Out_XY[i].ph));
            end
        elseif fieldname == "Hash"
            for i=1:np
                field[i] = Hash_XY[i];
            end 
        elseif fieldname == "Variance"
            for i=1:np
                field[i] = Float64(len_ox - n_phase_XY[i] + 2.0);
            end
        elseif fieldname == "s_cp"
            for i=1:np
                field[i] = Out_XY[i].s_cp[1];
            end
        elseif fieldname == "entropy"
            for i=1:np
                field[i] = Out_XY[i].entropy[1];
            end
        elseif fieldname == "enthalpy"
            for i=1:np
                field[i] = Out_XY[i].enthalpy[1];
            end
        elseif fieldname == "alpha"
            for i=1:np
                field[i] = Out_XY[i].alpha[1];
            end
        elseif fieldname == "eta_M"
            for i=1:np
                field[i] = log10(Out_XY[i].eta_M);
            end
            field[isnan.(field) .|| isinf.(field)] .= 0.0
        elseif fieldname == "Vp/Vs"
            for i=1:np
                field[i] = Out_XY[i].Vp / Out_XY[i].Vs;
            end
            field[isnan.(field)] .= missing
        elseif fieldname == "Vp_S/Vs_S"
            for i=1:np
                field[i] = Out_XY[i].Vp_S / Out_XY[i].Vs_S;
            end
            field[isnan.(field)] .= missing
        elseif fieldname == "Delta_rho"
            for i=1:np
                field[i] = 0.0
                if (Out_XY[i].frac_M > 0.0 && Out_XY[i].frac_S > 0.0)
                    field[i] = Out_XY[i].rho_S - Out_XY[i].rho_M
                end
            end
        else
            for i=1:np
                field[i] = Float64(get_property(Out_XY[i], fieldname));
            end

            field[isnan.(field)] .= 0.0
            field[isinf.(field)] .= 0.0
            if fieldname == "frac_M" || fieldname == "rho_M" || fieldname == "rho_S" || fieldname == "Delta_rho"
                field[isless.(field, 1e-8)] .= 0.0              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
            end
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);
    gridded_info = Matrix{Union{String,Missing}}(fill(missing,n,n)); 

    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded[ii,jj]  = field[k] 

        tmp                 = replace(string(display_phase_list(refType, Out_XY[k])), "\""=>"", "]"=>"", "["=>"", ","=>"")
        gridded_info[ii,jj] = "#"*string(k)*"# "*tmp

    end

    for i=1:length(data.cells)
        cell   = data.cells[i]
        tmp    = "#"*string(cell[1])*"# "*replace(string(display_phase_list(refType, Out_XY[cell[1]])), "\""=>"", "]"=>"", "["=>"", ","=>"")

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            gridded_info[ii, jj_ix] = tmp
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_info[ii_ix, jj] = tmp
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_info[ii_ix, jj] = tmp
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

        for ii in ii_min+1:ii_max-1
            gridded_info[ii, jj_ix] = tmp
            for jj in jj_min+1:jj_max-1
                gridded_info[ii, jj] = tmp
            end
        end

    end

    println("\rInterpolate data on grid $(round(time()-t0, digits=3)) seconds"); 


    # test Anton functions
    f           = unique(Hash_XY)
    f_id        = Dict(h => i for (i,h) in enumerate(f))
    int_vector  = [f_id[h] for h in Hash_XY]
    gridded_fields = Matrix{Int64}(undef,n,n);

    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded_fields[ii,jj]  = int_vector[k] 
    end

    for i=1:length(data.cells)
        cell   = data.cells[i]
        tmp    = int_vector[cell[1]]

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            gridded_fields[ii, jj_ix] = tmp
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_fields[ii_ix, jj] = tmp
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_fields[ii_ix, jj] = tmp
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

        for ii in ii_min+1:ii_max-1
            gridded_fields[ii, jj_ix] = tmp
            for jj in jj_min+1:jj_max-1
                gridded_fields[ii, jj] = tmp
            end
        end

    end

    return gridded, gridded_info, gridded_fields, X, Y, npoints, meant
end



const te_chondrite_names = ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc"]
const te_chondrite_ppm   = [2.3, 2.41, 0.029, 0.0074, 0.24, 0.0136, 0.237, 0.613, 2.47, 0.0928, 7.25, 0.457, 3.82, 0.103, 0.148, 0.0563, 0.199, 0.0361, 0.246, 1.57, 0.0546, 0.160, 0.0247, 0.161, 0.0246, 56, 5.92]

function te_chondrite_norm(el::AbstractString)
    id = findfirst(==(el), te_chondrite_names)
    return isnothing(id) ? 1.0 : te_chondrite_ppm[id]
end

struct TEFormula
    fn          :: Any
    terms       :: Vector{Tuple{String,String}}
    needs_sol   :: Bool
end

"""
    compile_te_formula(varBuilder)

    Compiles a trace-element field formula such as `"[M_Dy] / [S_Yb]"` once into a
    function of the vector of its bracketed term values, to be evaluated per point
    with [`eval_te_formula`](@ref).
"""
function compile_te_formula(varBuilder::String)
    terms   = unique([m.captures[1] for m in eachmatch(r"\[([^\]]+)\]", varBuilder)])
    parsed  = Tuple{String,String}[]
    expr    = varBuilder
    for (k, term) in enumerate(terms)
        st = String.(split(term, "_"))
        if length(st) != 2
            println("warning: underscore to split (M,S ph) and (element), has to be added")
            return TEFormula(nothing, parsed, false)
        end
        push!(parsed, (st[1], st[2]))
        expr = replace(expr, "[" * term * "]" => "(t[$k])")
    end
    fn = try
        eval(:( (t) -> $(Meta.parse(expr)) ))
    catch
        nothing
    end
    return TEFormula(fn, parsed, occursin("S_", varBuilder))
end

te_melt_present(te) = any(v -> isfinite(v) && v != 0.0, te.Cliq)

function te_term_value(te, kind::String, el::String, norm::String; defined_only::Bool = false)
    id_el = findfirst(e -> string(e) == el, te.elements)
    isnothing(id_el) && return nothing
    defined_only && kind == "M" && !te_melt_present(te) && return nothing
    nrm   = norm == "bulk" ? te.C0[id_el] : norm == "chondrite" ? te_chondrite_norm(el) : 1.0
    if kind == "S"
        v = te.Csol[id_el]
    elseif kind == "M"
        v = te.Cliq[id_el]
    elseif kind == "C0"
        v = te.C0[id_el]
    else
        ph_te = te.ph_TE
        id_ph = isnothing(ph_te) ? nothing : findfirst(ph -> string(ph) == kind, ph_te)
        if isnothing(id_ph) && !isnothing(ph_te) && use_warr_names[1]
            id_ph = findfirst(ph -> MAGEMin_C.get_Warr_name(ph) == kind, ph_te)
        end
        isnothing(id_ph) && return nothing
        v = te.Cmin[id_ph, id_el]
    end
    return v / nrm
end

"""
    eval_te_formula(f, te, norm; strict_liq = true)

    Evaluates a compiled trace-element formula on one `out_tepm` point. Returns `NaN`
    when a term cannot be resolved at that point (unknown element, absent phase),
    when no solid is present for an `S_` term, or when the melt composition is
    undefined (any NaN with `strict_liq`, all NaN otherwise). With `defined_only`,
    `M_` terms are also undefined where there is no melt (MAGEMin_C reports a zero
    melt composition there), which is what range finding needs.
"""
function eval_te_formula(f::TEFormula, te, norm::String; strict_liq::Bool = true, defined_only::Bool = false)
    f.fn === nothing && return NaN
    (strict_liq ? any(isnan, te.Cliq) : all(isnan, te.Cliq)) && return NaN
    (f.needs_sol && all(isnan, te.Csol)) && return NaN
    t = Vector{Float64}(undef, length(f.terms))
    for (k, (kind, el)) in enumerate(f.terms)
        v = te_term_value(te, kind, el, norm; defined_only = defined_only)
        isnothing(v) && return NaN
        t[k] = v
    end
    return try
        Base.invokelatest(f.fn, t)
    catch
        NaN
    end
end

"""
    te_field_values(type, fieldname, varBuilder, norm)

    The values of a trace-element field at the computed points where it is
    defined: a formula (`type == "te"`) evaluated with `defined_only`, or an
    accessory-phase property, where melt-only quantities (`*_liq`) are skipped at
    points without melt.
"""
function te_field_values(type::String, fieldname::String, varBuilder::String, norm::String)
    global Out_TE_XY
    vals = Float64[]
    if type == "te"
        f = compile_te_formula(varBuilder)
        for te in Out_TE_XY
            v = eval_te_formula(f, te, norm; defined_only = true)
            (v isa Real && isfinite(v)) && push!(vals, Float64(v))
        end
    else
        melt_only = endswith(fieldname, "_liq")
        for te in Out_TE_XY
            v = get_property(te, fieldname)
            (v isa Real && isfinite(v)) || continue
            (melt_only && !te_melt_present(te)) && continue
            push!(vals, Float64(v))
        end
    end
    return vals
end

"""
    te_color_range(type, fieldname, varBuilder, norm, gridded)

    Default colour range of a trace-element field: min/max over the points where it
    is defined ([`te_field_values`](@ref)), falling back to the whole displayed grid
    when it is defined nowhere.
"""
function te_color_range(type::String, fieldname::String, varBuilder::String, norm::String, gridded)
    vals = try
        te_field_values(type, fieldname, varBuilder, norm)
    catch
        Float64[]
    end
    isempty(vals) && return round_sig(grid_min(gridded)), round_sig(grid_max(gridded))
    return round_sig(minimum(vals)), round_sig(maximum(vals))
end

"""
    Function interpolate AMR grid to regular grid
"""
function get_gridded_map_no_lbl(    fieldname   ::String,
                                    type        ::String,
                                    varBuilder  ::String,
                                    norm        ::String,    
                                    oxi         ::Vector{String},
                                    Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                                    Out_TE_XY   ::Union{Nothing,Vector{MAGEMin_C.out_tepm}},
                                    Hash_XY     ::Vector{UInt64},
                                    sub         ::Int64,
                                    refLvl      ::Int64,
                                    refType     ::String,
                                    data        ::MAGEMinApp.AMR_data,
                                    Xrange      ::Tuple{Float64, Float64},
                                    Yrange      ::Tuple{Float64, Float64} )

    print("Interpolate data on grid ..."); t0 = time()
    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing,Nothing}}(undef,np);
 
    npoints     = np

    meant       = 0.0
    for i=1:np
        meant  += Out_XY[i].time_ms
    end
    meant      /= npoints
    meant       = round(meant; digits = 3)
    if type == "zrc"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "fapt"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "sulf"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "co2sat"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "mnz"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end
        field[isnan.(field)] .= 0.0
    elseif type == "te"
        te_f = compile_te_formula(varBuilder)
        for i=1:np
            field[i] = eval_te_formula(te_f, Out_TE_XY[i], norm)
        end
        field[isnan.(field)] .= 0.0
    else
        if fieldname == "#Phases"
            for i=1:np
                field[i] = Float64(length(Out_XY[i].ph));
            end
        elseif fieldname == "Hash"
            for i=1:np
                field[i] = Hash_XY[i];
            end 
        elseif fieldname == "Variance"
            for i=1:np
                field[i] = Float64(len_ox - n_phase_XY[i] + 2.0);
            end
        elseif fieldname == "s_cp"
            for i=1:np
                field[i] = Out_XY[i].s_cp[1];
            end
        elseif fieldname == "entropy"
            for i=1:np
                field[i] = Out_XY[i].entropy[1];
            end
        elseif fieldname == "enthalpy"
            for i=1:np
                field[i] = Out_XY[i].enthalpy[1];
            end
        elseif fieldname == "alpha"
            for i=1:np
                field[i] = Out_XY[i].alpha[1];
            end
        elseif fieldname == "eta_M"
            for i=1:np
                field[i] = log10(Out_XY[i].eta_M);
            end
            field[isnan.(field) .|| isinf.(field)] .= 0.0
        elseif fieldname == "Vp/Vs"
            for i=1:np
                field[i] = Out_XY[i].Vp / Out_XY[i].Vs;
            end
            field[isnan.(field)] .= missing
        elseif fieldname == "Vp_S/Vs_S"
            for i=1:np
                field[i] = Out_XY[i].Vp_S / Out_XY[i].Vs_S;
            end
            field[isnan.(field)] .= missing
        elseif fieldname == "Delta_rho"
            for i=1:np
                field[i] = 0.0
                if (Out_XY[i].frac_M > 0.0 && Out_XY[i].frac_S > 0.0)
                    field[i] = Out_XY[i].rho_S - Out_XY[i].rho_M
                end
            end
        else
            for i=1:np
                field[i] = Float64(get_property(Out_XY[i], fieldname));
            end

            field[isnan.(field)] .= 0.0
            field[isinf.(field)] .= 0.0
            if fieldname == "frac_M" || fieldname == "rho_M" || fieldname == "rho_S"
                field[isless.(field, 1e-8)] .= 0.0              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
            end
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);



    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded[ii,jj]  = field[k] 
    end



    println("\rInterpolate data on grid $(round(time()-t0, digits=3)) seconds"); 
    return gridded, X, Y, npoints, meant
end


"""
    Function interpolate AMR grid to regular grid
"""
function get_isopleth_map(  mod         ::String, 
                            ss          ::String, 
                            em          ::String,
                            ox          ::String,
                            of          ::String,
                            ot          ::String,
                            calc        ::String,
                            calc_sf     ::String,
                            calc_ox     ::String,
                            rmf         ::Bool,
                            oxi         ::Vector{String},
                            Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            data        ::MAGEMinApp.AMR_data,
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64};
                            absent      ::Float64 = 0.0 )

    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing}}(missing,np);

    if mod == "ph_frac" 
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id) 
                field[i] = Out_XY[i].ph_frac[id[1] ]

                if rmf == true 
                    if "H2O" in Out_XY[i].ph
                        id = findfirst(Out_XY[i].ph .== "H2O")
                        field[i] = field[i] / (1.0 - Out_XY[i].ph_frac[id])
                    end
                    if "fl" in Out_XY[i].ph
                        id = findfirst(Out_XY[i].ph .== "fl")
                        field[i] = field[i] / (1.0 - Out_XY[i].ph_frac[id])
                    end
                end

            else
                field[i] = 0.0
            end
        end
    elseif mod == "ph_frac_wt" 
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                if ~isempty(id)  
                    field[i] = Out_XY[i].ph_frac_wt[id[1] ]

                    if rmf == true 
                        if "H2O" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "H2O")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_wt[id])
                        end
                        if "fl" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "fl")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_wt[id])
                        end
                    end

                else
                    field[i] = 0.0
                end
            end
        elseif mod == "ph_frac_vol" 
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                if ~isempty(id)  
                    field[i] = Out_XY[i].ph_frac_vol[id[1] ]

                    if rmf == true 
                        if "H2O" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "H2O")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_vol[id])
                        end
                        if "fl" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "fl")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_vol[id])
                        end
                    end
                else
                    field[i] = 0.0
                end
            end
    elseif mod == "ss_MgNum"
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)  
                mg_id   = findfirst( Out_XY[i].oxides .== "MgO");
                fe_id   = findfirst( Out_XY[i].oxides .== "FeO");
                mg      =  Out_XY[i].SS_vec[id[1]].Comp_apfu[mg_id];
                fe      =  Out_XY[i].SS_vec[id[1]].Comp_apfu[fe_id];
                field[i] = mg / (mg + fe);
            else
                field[i] = absent
            end
        end 
    elseif mod == "ss_calc"
        el          = Out_XY[1].elements
        replacements = Dict("Si" => "si", "Ca" => "ca", "Al" => "al")
        for (old, new) in replacements
            el      = replace(el,   old => new)
            calc    = replace(calc, old => new)
        end

        n_el        = length(el)

        # build and compile the formula once (it does not depend on the point index),
        # then evaluate it per point on Comp_apfu via a fast compiled call
        cmd2eval    = calc
        for j = 1:n_el
            if occursin(el[j], calc)
                cmd2eval = replace(cmd2eval, el[j] => "x[$j]")
            end
        end
        calc_fn = eval(:( (x) -> $(Meta.parse(cmd2eval)) ))

        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)
                field[i] = Base.invokelatest(calc_fn, Out_XY[i].SS_vec[id[1]].Comp_apfu)
            else
                field[i] = absent
            end
        end
    elseif mod == "ss_calc_sf"

        # build and compile the formula once, using the site fraction names of the
        # first point where the phase is present (ordering is constant for a given phase)
        calc_fn = nothing
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)

            if ~isempty(id)

                id          = id[1]

                if calc_fn === nothing
                    sf       = Out_XY[i].SS_vec[id].siteFractionsNames
                    n_sf     = length(sf)

                    cmd2eval = calc_sf
                    for j = 1:n_sf
                        if occursin(sf[j], calc_sf)
                            cmd2eval = replace(cmd2eval, sf[j] => "x[$j]")
                        end
                    end
                    calc_fn = eval(:( (x) -> $(Meta.parse(cmd2eval)) ))
                end

                field[i] = Base.invokelatest(calc_fn, Out_XY[i].SS_vec[id].siteFractions)

            else
                field[i] = absent
            end
        end
    elseif mod == "ss_calc_ox_mol" || mod == "ss_calc_ox_wt"
        el          = Out_XY[1].oxides
        n_el        = length(el)

        O_id        = findfirst(Out_XY[1].oxides .== "O")
        if !isnothing(O_id)
            el[O_id]    = "o"   # put to lower case to avoid issue when evaluating the command
        end

        # build and compile the formula once (it does not depend on the point index),
        # then evaluate it per point on Comp/Comp_wt via a fast compiled call
        cmd2eval = calc_ox
        for j = 1:n_el
            if occursin(el[j], calc_ox)
                cmd2eval = replace(cmd2eval, el[j] => "x[$j]")
            end
        end
        calc_fn = eval(:( (x) -> $(Meta.parse(cmd2eval)) ))

        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)
                id  = id[1]
                x   = mod == "ss_calc_ox_mol" ? Out_XY[i].SS_vec[id].Comp : Out_XY[i].SS_vec[id].Comp_wt
                field[i] = Base.invokelatest(calc_fn, x)
            else
                field[i] = absent
            end
        end  
        elseif mod == "em_frac"
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                if ~isempty(id)  
                    idem     = findall(Out_XY[i].SS_vec[id[1]].emNames .== em)
                    field[i] = Out_XY[i].SS_vec[id[1]].emFrac[idem[1]]
                else
                    field[i] = absent
                end
            end 
        elseif mod == "em_frac_wt"
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                if ~isempty(id)  
                    idem     = findall(Out_XY[i].SS_vec[id[1]].emNames .== em)
                    field[i] = Out_XY[i].SS_vec[id[1]].emFrac_wt[idem[1]]
                else
                    field[i] = absent
                end
            end 
        elseif mod == "ox_comp"
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                ox_id    = findfirst(Out_XY[i].oxides .== ox)
                if ~isempty(id)  
                    field[i] = Out_XY[i].SS_vec[id[1]].Comp[ox_id]
                else
                    field[i] = absent
                end
            end 
        elseif mod == "ox_comp_wt"
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                ox_id    = findfirst(Out_XY[i].oxides .== ox)
                if ~isempty(id)  
                    field[i] = Out_XY[i].SS_vec[id[1]].Comp_wt[ox_id]
                else
                    field[i] = absent
                end
            end 
        elseif mod == "of_mod"
            if of == "s_cp"
                for i=1:np
                    field[i] = Out_XY[i].s_cp[1];
                end
            elseif of == "entropy"
                for i=1:np
                    field[i] = Out_XY[i].entropy[1];
                end
            elseif of == "enthalpy"
                for i=1:np
                    field[i] = Out_XY[i].enthalpy[1];
                end
            elseif of == "alpha"
                for i=1:np
                    field[i] = Out_XY[i].alpha[1];
                end
            elseif of == "eta_M"
                for i=1:np
                    field[i] = log10(Out_XY[i].eta_M);
                end
                field[isnan.(field) .|| isinf.(field)] .= 0.0
            elseif of == "Vp/Vs"
                for i=1:np
                    field[i] = Out_XY[i].Vp / Out_XY[i].Vs;
                end
            elseif of == "Vp_S/Vs_S"
                for i=1:np
                    field[i] = Out_XY[i].Vp_S / Out_XY[i].Vs_S;
                end
            elseif of == "Delta_rho"
                for i=1:np
                    field[i] = 0.0
                    if (Out_XY[i].frac_M > 0.0 && Out_XY[i].frac_S > 0.0)
                        field[i] = Out_XY[i].rho_S - Out_XY[i].rho_M
                    end
                end
            else
                for i=1:np
                    field[i] = Float64(get_property(Out_XY[i], of));
                end
        end

        field[isnan.(field)] .= missing
        field[isinf.(field)] .= missing
        if of == "frac_M" || of == "rho_M" || of == "rho_S"
            field[isless.(field, 1e-8)] .= 0.0              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
        end 
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);


    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded[ii,jj]  = field[k] 
    end

    for i=1:length(data.cells)
        cell   = data.cells[i]

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            f = (ii - ii_min)/ (ii_max - ii_min)
            gridded[ii, jj_ix] = field[cell[2]]*(1.0 - f) + field[cell[3]]*f
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj = jj_min+1:jj_max-1
            f = (jj - jj_min)/ (jj_max - jj_min)
            gridded[ii_ix, jj] = field[cell[1]]*(1.0 - f) + field[cell[2]]*f
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            f = (jj - jj_min)/ (jj_max - jj_min)
            gridded[ii_ix, jj] = field[cell[4]]*(1.0 - f) + field[cell[3]]*f
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

        for ii = ii_min+1:ii_max-1
            f = (ii - ii_min)/ (ii_max - ii_min)
            gridded[ii, jj_ix] = field[cell[1]]*(1.0 - f) + field[cell[4]]*f

            bot = field[cell[1]]*(1.0 - f) + field[cell[4]]*f
            top = field[cell[2]]*(1.0 - f) + field[cell[3]]*f
            for jj = jj_min+1:jj_max-1
                g = (jj - jj_min)/ (jj_max - jj_min)
                gridded[ii, jj] = bot*(1.0 -g) + top*g
            end
        end

    end
    return gridded, X, Y
end



"""
    Function interpolate AMR grid to regular grid
"""
function get_isopleth_map_te(   mod         ::String, 
                                field       ::String, 
                                acces_name  ::String,
                                calc        ::String,
                                norm_te     ::String,
                                oxi         ::Vector{String},
                                Out_TE_XY   ::Vector{MAGEMin_C.out_tepm},
                                sub         ::Int64,
                                refLvl      ::Int64,
                                data        ::MAGEMinApp.AMR_data,
                                Xrange      ::Tuple{Float64, Float64},
                                Yrange      ::Tuple{Float64, Float64};
                                absent      ::Float64 = 0.0,
                                defined_only::Bool    = false )

    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Nothing}}(nothing,np);

    if mod == "calc"
        te_f = compile_te_formula(calc)
        for i=1:np
            field[i] = eval_te_formula(te_f, Out_TE_XY[i], norm_te; defined_only = defined_only)
        end
        field[isnan.(field)] .= absent
    elseif mod == "zrc"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], acces_name);
        end
        field[isnan.(field)] .= absent
    elseif mod == "fapt"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], acces_name);
        end
        field[isnan.(field)] .= absent
    elseif mod == "sulf"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], acces_name);
        end
        field[isnan.(field)] .= absent
    elseif mod == "co2sat"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], acces_name);
        end
        field[isnan.(field)] .= absent
    elseif mod == "mnz"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], acces_name);
        end
        field[isnan.(field)] .= absent
    end
    if defined_only && mod != "calc" && endswith(acces_name, "_liq")
        for i=1:np
            te_melt_present(Out_TE_XY[i]) || (field[i] = absent)
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded_TE   = Matrix{Union{Float64,Missing}}(missing,n,n);

    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded_TE[ii,jj]  = field[k] 
    end

    for i=1:length(data.cells)
        cell   = data.cells[i]

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            f = (ii - ii_min)/ (ii_max - ii_min)
            gridded_TE[ii, jj_ix] = field[cell[2]]*(1.0 - f) + field[cell[3]]*f
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj = jj_min+1:jj_max-1
            f = (jj - jj_min)/ (jj_max - jj_min)
            gridded_TE[ii_ix, jj] = field[cell[1]]*(1.0 - f) + field[cell[2]]*f
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            f = (jj - jj_min)/ (jj_max - jj_min)
            gridded_TE[ii_ix, jj] = field[cell[4]]*(1.0 - f) + field[cell[3]]*f
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

        for ii = ii_min+1:ii_max-1
            f = (ii - ii_min)/ (ii_max - ii_min)
            gridded_TE[ii, jj_ix] = field[cell[1]]*(1.0 - f) + field[cell[4]]*f

            bot = field[cell[1]]*(1.0 - f) + field[cell[4]]*f
            top = field[cell[2]]*(1.0 - f) + field[cell[3]]*f
            for jj = jj_min+1:jj_max-1
                g = (jj - jj_min)/ (jj_max - jj_min)
                gridded_TE[ii, jj] = bot*(1.0 -g) + top*g
            end
        end

    end
    return gridded_TE, X, Y
end


"""
    Function to extract values from structure using structure's member name
"""
function get_property(x, name::String)
    s = Symbol(name)
    return getproperty(x, s)
end



"""
    convertBulk4App(bulk_in, bulk_in_ox, sys_in, db; ns = false, oxMinGuard = true)

    App-side copy of MAGEMin_C's `convertBulk4MAGEMin` (MAGEMin v2.1.0) used when loading bulk-rock files.
    Converts `bulk_in` (`sys_in` = "mol" or "wt") to MAGEMin's oxide order for `db`, normalized to 100 mol%.
    With `ns = false` core oxides below 1e-4 are raised to 1e-4, as in MAGEMin_C. With `ns = true`
    (nullspace optimizer) only SiO2 is raised to 1e-4; every other oxide is kept as given, values within
    ±2e-5 being set to 0 when `oxMinGuard` is true.
"""
function convertBulk4App(   bulk_in     :: AbstractVector{Float64},
                            bulk_in_ox  :: AbstractVector{<:AbstractString},
                            sys_in      :: AbstractString,
                            db          :: AbstractString;
                            ns          :: Bool = false,
                            oxMinGuard  :: Bool = true )

    bulk_in_ox      = String.(bulk_in_ox)
    sys_in          = String(sys_in)
    db              = String(db)
    bulk_in         = MAGEMin_C.normalize(bulk_in)

    ref_ox          = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "Fe2O3"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "MnO"; "H2O"; "CO2"; "S"; "Fe"];
    ref_MolarMass   = [60.08; 101.96; 56.08; 40.30; 71.85; 159.69; 94.2; 61.98; 79.88; 16.0; 151.99; 70.937; 18.015; 44.01; 32.06; 55.85];

    MAGEMin_ox      = get_oxide_list(db)

    keep_mask       = in(MAGEMin_ox).(bulk_in_ox) .| in(["Fe", "FeO", "Fe2O3"]).(bulk_in_ox)
    bulk_in_ox      = bulk_in_ox[keep_mask]
    bulk_in         = bulk_in[keep_mask]

    MAGEMin_bulk    = zeros(length(MAGEMin_ox))

    ox_indices      = findfirst.(isequal.(bulk_in_ox), Ref(ref_ox))

    if sys_in == "wt"
        bulk = bulk_in ./ ref_MolarMass[ox_indices]
    elseif sys_in == "mol"
        bulk = copy(bulk_in)
    else
        println("System unit not implemented -> use 'mol' or 'wt' -> falling back to 'mol'")
        bulk = copy(bulk_in)
    end

    Xox_cp = copy(bulk_in_ox)
    (db == "sb24") && (MAGEMin_C.FeO2Fe_O!(bulk, Xox_cp))
    bulk = MAGEMin_C.normalize(bulk)

    for i in eachindex(MAGEMin_ox)
        idx = findfirst(isequal(MAGEMin_ox[i]), Xox_cp)
        if !isnothing(idx)
            MAGEMin_bulk[i] = bulk[idx]
        end
    end

    idx_Fe2O3 = findfirst(isequal("Fe2O3"), Xox_cp)
    if !isnothing(idx_Fe2O3) && db != "sb24"
        idx_FeO = findfirst(isequal("FeO"), MAGEMin_ox)
        idx_O   = findfirst(isequal("O"), MAGEMin_ox)
        if !isnothing(idx_FeO)
            MAGEMin_bulk[idx_FeO] += bulk[idx_Fe2O3] * 2.0
        end
        if !isnothing(idx_O)
            MAGEMin_bulk[idx_O] += bulk[idx_Fe2O3]
        end
    end

    MAGEMin_bulk .= MAGEMin_C.normalize(MAGEMin_bulk)

    idx_FeO_ox  = findfirst(isequal("FeO"), MAGEMin_ox)
    idx_O_ox    = findfirst(isequal("O"),   MAGEMin_ox)
    if !isnothing(idx_FeO_ox) && !isnothing(idx_O_ox) && MAGEMin_bulk[idx_O_ox] > 0.0 && MAGEMin_bulk[idx_FeO_ox] < (oxMinGuard ? 2e-5 : eps(Float64))
        @warn "FeO is absent from the bulk-rock composition: O (ferric iron) is set to 0.0" maxlog=1
        MAGEMin_bulk[idx_O_ox] = 0.0
        MAGEMin_bulk .= MAGEMin_C.normalize(MAGEMin_bulk)
    end

    oxide_config = Dict(
        "sb11"   => (core=["SiO2", "Al2O3", "FeO", "MgO"],
                   optional=[ "CaO", "Na2O"]),
        "sb21"   => (core=["SiO2", "Al2O3", "FeO", "MgO"],
                   optional=[ "CaO", "Na2O"]),
        "sb24"   => (core=["SiO2", "Al2O3", "MgO", "O", "Fe"],
                   optional=["CaO", "Na2O", "Cr2O3"]),
        "xMELTS" => (core=["FeO"],
                   optional=["SiO2","Al2O3","CaO","MgO","K2O","Na2O","TiO2","O","MnO","Cr2O3","H2O","CO2"]),
        "rMELTS" => (core=["FeO"],
                   optional=["SiO2","Al2O3","CaO","MgO","K2O","Na2O","TiO2","O","MnO","Cr2O3","H2O","CO2"]),
        "pMELTS" => (core=["FeO"],
                   optional=["SiO2","Al2O3","CaO","MgO","K2O","Na2O","TiO2","O","MnO","Cr2O3","H2O"]),
        "po"     => (core=["SiO2", "Al2O3", "MgO", "FeO"],
                   optional=["K2O", "Na2O", "H2O", "CaO", "TiO2", "O"]),
    )

    if is_db(db) && get_db(db).research_group == "tc"
        EM_db   = get_db(db).EM_database
        c       = findall(ox -> MAGEMin_C.LibMAGEMin.is_core_oxide("tc", EM_db, ox) == 1, MAGEMin_ox)
        d       = setdiff(eachindex(MAGEMin_ox), c)
    else
        config  = get(oxide_config, db, (core=MAGEMin_ox, optional=String[]))
        c       = findall(in(config.core).(MAGEMin_ox))
        d       = findall(in(config.optional).(MAGEMin_ox))
    end

    if ns
        c       = findall(isequal("SiO2"), MAGEMin_ox)
        d       = setdiff(eachindex(MAGEMin_ox), c)
    end

    id0 = findall(MAGEMin_bulk[c] .< 1e-4)
    if !isempty(id0)
        MAGEMin_bulk[c[id0]] .= 1e-4
    end

    if oxMinGuard
        id1 = findall(MAGEMin_bulk[d] .< 2e-5 .&& MAGEMin_bulk[d] .> -2e-5)
        if !isempty(id1)
            MAGEMin_bulk[d[id1]] .= 0.0
        end
    end

    MAGEMin_bulk .= MAGEMin_C.normalize(MAGEMin_bulk) .* 100.0

    return MAGEMin_bulk, MAGEMin_ox
end


"""
    function to parse bulk-rock composition file
"""
function bulk_file_to_db(datain; ns::Bool = false)

    global db;
    
    db = db[(db.bulk .== "predefined"), :];

    for i=2:size(datain,1)
        bulk   		= "custom";

        idx 		= findall(datain[1,:] .== "title")[1];
        title   	= string(datain[i,idx]);

        idx 		= findall(datain[1,:] .== "comments")[1];
        comments   	= string(datain[i,idx]);

        idx 		= findall(datain[1,:] .== "db")[1];
        dbin   		= lowercase(datain[i,idx]);

        test 		= length(db[(db.db .== dbin), :].test);

        idx 		= findall(datain[1,:] .== "sysUnit")[1];
        sysUnit   	= lowercase(datain[i,idx]);

        idx 		= findall(datain[1,:] .== "oxide")[1];
        oxide   	= rsplit(datain[i,idx],",");
        oxide 		= strip.(convert.(String,oxide));
        oxide 		= replace.(oxide,r"\]"=>"",r"\["=>"");

        idx 		= findall(datain[1,:] .== "frac")[1];
        frac   		= rsplit(datain[i,idx],",");
        frac 		= strip.(convert.(String,frac));
        frac 		= replace.(frac,r"\]"=>"",r"\["=>"");
        frac 		= parse.(Float64,frac);

        idx 		= findall(datain[1,:] .== "frac2")[1];
        bulkrock, MAGEMin_ox    = convertBulk4App(frac,oxide,String(sysUnit),String(dbin); ns = ns)
        bulkrock   .= round.(bulkrock; digits = 4)


        if ~isempty(datain[i,idx])
            frac2  		= rsplit(datain[i,idx],",");
            frac2 		= strip.(convert.(String,frac2));
            frac2 		= replace.(frac2,r"\]"=>"",r"\["=>"");
            frac2		= parse.(Float64,frac2);
            bulkrock2, MAGEMin_ox   = convertBulk4App(frac2,oxide,String(sysUnit),String(dbin); ns = ns)
            bulkrock2  .= round.(bulkrock2; digits = 4)
        else
            bulkrock2   = deepcopy(bulkrock)
        end

        oxide           = get_oxide_list(String(dbin))

        bulkrock_wt     = round.(mol2wt(bulkrock, oxide),digits=6)
        bulkrock2_wt    = round.(mol2wt(bulkrock2, oxide),digits=6)

        push!(db,Dict(  :bulk       => bulk,
                        :title      => title,
                        :comments   => comments,
                        :db         => dbin,
                        :test       => test,
                        :sysUnit    => sysUnit,
                        :oxide      => oxide,
                        :frac       => bulkrock,
                        :frac2      => bulkrock2,
                        :frac_wt    => bulkrock_wt,
                        :frac2_wt   => bulkrock2_wt,
                    ), cols=:union)
    end

end


"""
    function to parse bulk-rock composition CSV file

    CSV format:
        title,comments,db,sysUnit,SiO2,CaO,Al2O3,FeO,MgO,Na2O
        Basalt_Xu08,c,sb21,mol,0.5175,0.1388,0.1019,0.0706,0.1494,0.0218

    For frac2, add columns with _frac2 suffix:
        title,comments,db,sysUnit,SiO2,CaO,...,SiO2_frac2,CaO_frac2,...
"""
function strip_bom(s::AbstractString)
    return startswith(s, "\ufeff") ? s[nextind(s, 1):end] : s
end

function bulk_csv_to_db(datain; ns::Bool = false)

    global db;

    db = db[(db.bulk .== "predefined"), :];

    headers = strip.(datain[1, :])

    # Check required headers
    for req in ("title","comments","db","sysUnit")
        if isnothing(findfirst(headers .== req))
            error("Missing required column '$req' in CSV header. " *
                  "Expected columns: title, comments, db, sysUnit, <oxide columns>")
        end
    end

    # Find standard column indices
    idx_title    = findfirst(headers .== "title")
    idx_comments = findfirst(headers .== "comments")
    idx_db       = findfirst(headers .== "db")
    idx_sysUnit  = findfirst(headers .== "sysUnit")

    # Separate oxide columns from frac2 (suffix _frac2) and WDS uncertainty (suffix _wds) columns
    standard_cols = Set(["title", "comments", "db", "sysUnit"])
    oxide_indices = Int[]
    frac2_map     = Dict{String,Int}()
    wds_map       = Dict{String,Int}()

    for j in 1:length(headers)
        h = headers[j]
        if h in standard_cols || isempty(h)
            continue
        elseif endswith(h, "_frac2")
            ox_name = replace(h, "_frac2" => "")
            frac2_map[ox_name] = j
        elseif endswith(h, "_wds")
            ox_name = replace(h, "_wds" => "")
            wds_map[ox_name] = j
        else
            push!(oxide_indices, j)
        end
    end

    has_frac2_cols = !isempty(frac2_map)
    has_wds_cols   = !isempty(wds_map)

    for i = 2:size(datain, 1)
        bulk     = "custom"
        title    = string(datain[i, idx_title])
        comments = string(datain[i, idx_comments])
        dbin     = lowercase(strip(string(datain[i, idx_db])))
        sysUnit  = lowercase(strip(string(datain[i, idx_sysUnit])))

        valid_sysunit = ("mol","wt")

        if !is_db(dbin) && !(dbin in DB_STAGED)
            error("Row $i ('$title'): unknown database '$dbin'. " *
                  "Valid acronyms: $(join(vcat(get_db_list(), collect(DB_STAGED)), ", "))")
        end
        if sysUnit ∉ valid_sysunit
            error("Row $i ('$title'): invalid sysUnit '$sysUnit'. Must be 'mol' or 'wt'")
        end

        test     = length(db[(db.db .== dbin), :].test)

        # Extract oxide names and frac values from oxide columns
        oxide = String[]
        frac  = Float64[]
        for j in oxide_indices
            val_str = strip(string(datain[i, j]))
            if !isempty(val_str)
                val = tryparse(Float64, val_str)
                if isnothing(val)
                    error("Row $i ('$title'), column '$(headers[j])': " *
                          "cannot parse '$val_str' as a number")
                end
                push!(oxide, string(headers[j]))
                push!(frac, val)
            end
        end

        if isempty(oxide)
            error("Row $i ('$title'): no oxide values found. At least one oxide column must be non-empty")
        end

        bulkrock, MAGEMin_ox = convertBulk4App(frac, oxide, sysUnit, dbin; ns = ns)
        bulkrock .= round.(bulkrock; digits = 4)

        frac2 = copy(frac)
        if has_frac2_cols
            up_oxides = string.(keys(frac2_map))
            for j in up_oxides
                if j in oxide
                    idx_oxide = findfirst(oxide .== j)
                    val_str = strip(string(datain[i, frac2_map[j]]))
                    if !isempty(val_str)
                        val = tryparse(Float64, val_str)
                        if isnothing(val)
                            error("Row $i ('$title'), column '$(j)_frac2': " *
                                  "cannot parse '$val_str' as a number")
                        end
                        frac2[idx_oxide] = val
                    end
                end
            
            end
        end
        bulkrock2, _ = convertBulk4App(frac2, oxide, sysUnit, dbin; ns = ns)
        bulkrock2   .= round.(bulkrock2; digits = 4)

        # Per-oxide WDS 1-sigma, converted to absolute mol% (matching the Uncertainty
        # tab's "value [mol%]" column) by finite-differencing the same raw-value -> mol%
        # transform used for the bulk itself just above (plain renormalization for a
        # mol-basis row, wt2mol for a wt-basis row): perturb only that oxide's raw value
        # by its _wds number, holding every other raw value fixed. This lets a _wds
        # column be given in the row's own sysUnit, same as its oxide columns, instead
        # of forcing every CSV to pre-convert to mol%. Oxides without a _wds column, or
        # that don't survive into the database's own oxide list (e.g. Fe2O3 speciated
        # into FeO/O), are left NaN.
        wds_by_name = Dict{String,Float64}()
        if has_wds_cols
            up_oxides = string.(keys(wds_map))
            for j in up_oxides
                if j in oxide
                    idx_oxide = findfirst(oxide .== j)
                    val_str = strip(string(datain[i, wds_map[j]]))
                    if !isempty(val_str)
                        val = tryparse(Float64, val_str)
                        if isnothing(val)
                            error("Row $i ('$title'), column '$(j)_wds': " *
                                  "cannot parse '$val_str' as a number")
                        end

                        perturbed = copy(frac); perturbed[idx_oxide] += val
                        if sysUnit == "mol"
                            mol_base = frac      ./ sum(frac)      .* 100.0
                            mol_pert = perturbed ./ sum(perturbed) .* 100.0
                        else # wt
                            mol_base = wt2mol(frac,      oxide)
                            mol_pert = wt2mol(perturbed, oxide)
                        end
                        wds_by_name[j] = abs(mol_pert[idx_oxide] - mol_base[idx_oxide])
                    end
                end
            end
        end

        oxide        = get_oxide_list(dbin)
        wds          = [get(wds_by_name, oxide[k], NaN) for k in eachindex(oxide)]

        bulkrock_wt  = round.(mol2wt(bulkrock, oxide), digits=6)
        bulkrock2_wt = round.(mol2wt(bulkrock2, oxide), digits=6)

        push!(db, Dict( :bulk       => bulk,
                        :title      => title,
                        :comments   => comments,
                        :db         => dbin,
                        :test       => test,
                        :sysUnit    => sysUnit,
                        :oxide      => oxide,
                        :frac       => bulkrock,
                        :frac2      => bulkrock2,
                        :frac_wt    => bulkrock_wt,
                        :frac2_wt   => bulkrock2_wt,
                        :wds        => wds,
                    ), cols=:union)
    end

end


function parse_bulk_rock(contents, filename; ns::Bool = false)
    try
        content_type, content_string = split(contents, ',');
        decoded = base64decode(content_string);
        input   = strip_bom(String(decoded));

        if endswith(lowercase(filename), ".csv")
            first_line = split(input, '\n')[findfirst(l -> !startswith(strip(l), '#') && !isempty(strip(l)), split(input, '\n'))]
            delim = occursin(';', first_line) ? ';' : ','
            datain  = strip.(string.(readdlm(IOBuffer(input), delim, comments=true, comment_char='#')));
            bulk_csv_to_db(datain; ns = ns);
        else
            datain  = strip.(string.(readdlm(IOBuffer(input), ';', comments=true, comment_char='#')));
            bulk_file_to_db(datain; ns = ns);
        end

        return 1, ""
    catch e
        return 0, sprint(showerror, e)
    end

end


"""
    Parse a drag-and-dropped P-T(-X) path CSV/text file into DataTable rows.
    `header_map` maps an uppercased column header (e.g. "P", "T", "ASSIM", "BUFFER")
    to the DataTable column id it fills ("col-1", "col-2", ...); `required`
    lists the col ids that must be present in the file; `optional` lists col
    ids that are backfilled with 0.0 on every row when their column is absent
    from the file (matching the 0.0 default "Add new point" uses for them).
    Pressure is always given in kbar in the file and converted to the
    currently displayed pressure unit here, matching how "Add new point"
    inserts rows.
"""
function parse_path_csv(contents, filename, header_map::Dict{String,String}, required::Vector{String}, optional::Vector{String}=String[])
    try
        content_type, content_string = split(contents, ',');
        decoded = base64decode(content_string);
        input   = strip_bom(String(decoded));

        lines     = split(input, '\n');
        first_idx = findfirst(l -> !startswith(strip(l), '#') && !isempty(strip(l)), lines);
        isnothing(first_idx) && return 0, "File is empty or contains no header line", nothing

        delim  = occursin(';', lines[first_idx]) ? ';' : ',';
        datain = strip.(string.(readdlm(IOBuffer(input), delim, comments=true, comment_char='#')));
        size(datain,1) < 2 && return 0, "No data rows found below the header", nothing

        header  = uppercase.(datain[1,:]);
        col_idx = Dict{String,Int}();
        for (i,h) in enumerate(header)
            haskey(header_map, h) && (col_idx[header_map[h]] = i)
        end

        missing_cols = setdiff(required, keys(col_idx));
        ~isempty(missing_cols) && return 0, "Missing required column(s): "*join(missing_cols, ", "), nothing

        absent_optional = setdiff(optional, keys(col_idx));

        nrows = size(datain,1) - 1;
        rows  = Vector{Dict{Symbol,Float64}}(undef, nrows);
        for r = 1:nrows
            row = Dict{Symbol,Float64}();
            for (col_id, idx) in col_idx
                val = tryparse(Float64, string(datain[r+1,idx]));
                isnothing(val) && return 0, "Non-numeric value in row $(r+1)", nothing
                row[Symbol(col_id)] = col_id == "col-1" ? display_pressure(val) : val;
            end
            for col_id in absent_optional
                row[Symbol(col_id)] = 0.0;
            end
            rows[r] = row;
        end

        return 1, "", rows
    catch e
        return 0, sprint(showerror, e), nothing
    end
end


function parse_bulk_te(contents, filename, kdsDB)
    try
        content_type, content_string = split(contents, ',');
        decoded = base64decode(content_string);
        input   = strip_bom(String(decoded));

        if endswith(lowercase(filename), ".csv")
            datain = strip.(string.(readdlm(IOBuffer(input), ',', comments=true, comment_char='#')));
            te_bulk_csv_to_db(datain, kdsDB);
        else
            datain = strip.(string.(readdlm(IOBuffer(input), ';', comments=true, comment_char='#')));
            te_bulk_file_to_db(datain, kdsDB);
        end

        return 1
    catch e
        return 0
    end

end

"""
    function to parse trace-element bulk composition CSV file

    CSV format:
        title,comments,Li,Be,B,Sc,...
        Basalt,comment,29.14,0.43,29.69,38.24,...

    For frac2, add columns with _frac2 suffix to override specific elements:
        title,comments,Li,Be,...,Li_frac2,Be_frac2,...
    Missing _frac2 values default to the frac value.
"""
function te_bulk_csv_to_db(datain, kds_mod)

    global dbte;

    dbte = dbte[(dbte.composition .== "predefined"), :];

    KDs_dtb = build_kds_database(kds_mod)

    headers = strip.(datain[1, :])

    for req in ("title", "comments")
        if isnothing(findfirst(headers .== req))
            error("Missing required column '$req' in CSV header.")
        end
    end

    idx_title    = findfirst(headers .== "title")
    idx_comments = findfirst(headers .== "comments")

    standard_cols  = Set(["title", "comments"])
    elem_indices   = Int[]
    frac2_map      = Dict{String,Int}()

    for j in 1:length(headers)
        h = headers[j]
        if h in standard_cols || isempty(h)
            continue
        elseif endswith(h, "_frac2")
            el_name = replace(h, "_frac2" => "")
            frac2_map[el_name] = j
        else
            push!(elem_indices, j)
        end
    end

    has_frac2_cols = !isempty(frac2_map)

    for i = 2:size(datain, 1)
        composition = "custom"
        test        = length(dbte.test)
        title       = string(datain[i, idx_title])
        comments    = string(datain[i, idx_comments])

        elements = String[]
        frac     = Float64[]
        for j in elem_indices
            val_str = strip(string(datain[i, j]))
            if !isempty(val_str)
                val = tryparse(Float64, val_str)
                if isnothing(val)
                    error("Row $i ('$title'), column '$(headers[j])': cannot parse '$val_str' as a number")
                end
                push!(elements, string(headers[j]))
                push!(frac, val)
            end
        end

        if isempty(elements)
            error("Row $i ('$title'): no element values found.")
        end

        bulkte  = MAGEMin_C.adjust_chemical_system(KDs_dtb, frac, elements)
        bulkte .= round.(bulkte; digits = 4)

        frac2 = copy(frac)
        if has_frac2_cols
            for el in keys(frac2_map)
                idx_el = findfirst(elements .== el)
                if !isnothing(idx_el)
                    val_str = strip(string(datain[i, frac2_map[el]]))
                    if !isempty(val_str)
                        val = tryparse(Float64, val_str)
                        if isnothing(val)
                            error("Row $i ('$title'), column '$(el)_frac2': cannot parse '$val_str' as a number")
                        end
                        frac2[idx_el] = val
                    end
                end
            end
        end

        bulkte2  = MAGEMin_C.adjust_chemical_system(KDs_dtb, frac2, elements)
        bulkte2 .= round.(bulkte2; digits = 4)

        elements = KDs_dtb.element_name

        push!(dbte, Dict(   :composition    => composition,
                            :title          => title,
                            :comments       => comments,
                            :test           => test,
                            :elements       => elements,
                            :μg_g           => bulkte,
                            :μg_g2          => bulkte2,
                    ), cols=:union)
    end

end

"""
  function to parse bulk-te composition file
"""
function te_bulk_file_to_db(datain, kds_mod)

    global dbte;

    dbte = dbte[(dbte.composition .== "predefined"), :];

    KDs_dtb = build_kds_database(kds_mod)

    id_title 		= findfirst(datain[1,:] .== "title")
    id_comments		= findfirst(datain[1,:] .== "comments")
    id_elements		= findfirst(datain[1,:] .== "elements")
    id_frac         = findfirst(datain[1,:] .== "frac")
    id_frac2        = findfirst(datain[1,:] .== "frac2")

    for i=2:size(datain, 1)
        composition = "custom"
        test 		= length(dbte.test)
        title   	= string(datain[i,id_title])

        comments    = string(datain[i,id_comments])
        elements    = rsplit(datain[i,id_elements],",")
        elements 	= strip.(convert.(String,elements))
        elements 	= replace.(elements,r"\]"=>"",r"\["=>"")

        frac   	    = rsplit(datain[i,id_frac],",")
        frac 		= strip.(convert.(String,frac))
        frac 		= replace.(frac,r"\]"=>"",r"\["=>"")
        frac 		= parse.(Float64,frac)

        bulkte      = MAGEMin_C.adjust_chemical_system( KDs_dtb, frac, elements)
        bulkte     .= round.(bulkte; digits = 4)

        if ~isempty(datain[i,id_frac2])
            frac2  		= rsplit(datain[i,id_frac2],",");
            frac2 		= strip.(convert.(String,frac2));
            frac2 		= replace.(frac2,r"\]"=>"",r"\["=>"");
            frac2		= parse.(Float64,frac2);
            bulkte2     = MAGEMin_C.adjust_chemical_system( KDs_dtb, frac2, elements);
            bulkte2    .= round.(bulkte2; digits = 4)
        else
            bulkte2     = deepcopy(bulkte)
        end

        elements        = KDs_dtb.element_name

        push!(dbte,Dict(    :composition    => composition,
                            :title          => title,
                            :comments       => comments,
                            :test           => test,
                            :elements       => elements,
                            :μg_g           => bulkte,
                            :μg_g2          => bulkte2,
                    ), cols=:union)
    end

end


function read_xlsx_KDs( filename  :: String;
                        sheet_name :: String = "KDs" )

    if !isfile(filename)
        error("File $filename does not exist.")
        return nothing
    else
        info, name    = "", ""
        status  = 0
        XLSX.openxlsx(filename) do xf
            if sheet_name in XLSX.sheetnames(xf)
                sheet   = xf[sheet_name]
                acr     = sheet[1, 1]  
                name    = sheet[1, 2]  
                info    = sheet[1, 3]  

                data    = XLSX.readtable(filename, sheet_name; first_row=2) |> DataFrame

                el      = names(data)[2:end]
                ph      = string.(data[!, "Phase"])
                KDs     = Matrix{String}(string.(data[:, 2:end]))

                return (el, ph, KDs, acr, name, info)
            else
                error("Sheet 'KDs' not found in $filename.")
                return nothing
            end
        end
    end

end

function parse_contents(contents, filename)
    # We need to extract the base64 part and decode it
    content_string  = split(contents, ",")[2]
    file_bytes      = base64decode(content_string)

    # Save to a temporary file
    temp_filename = tempname() * ".xlsx"
    open(temp_filename, "w") do f
        write(f, file_bytes)
    end
    KDs         = read_xlsx_KDs(temp_filename)

    return KDs
end




