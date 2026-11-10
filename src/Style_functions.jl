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




function save_style(dict::Dict{String, Vector{Any}}; path::String="./user_data/mineral_style_user.json")
    open(path, "w") do io
        JSON3.write(io, dict; indent=2)
    end
end

# load mineral style
function load_mineral_style()
    try
        return load_style(joinpath(pkg_dir, "./user_data/mineral_style_user.json"))
        println("loading user-defined mineral style")
    catch
        return load_style(joinpath(pkg_dir, "./user_data/mineral_style_default.json"))
    end
end


# try to load user overrides if present
function load_style(json_path)
    if isfile(json_path)
        try
            return JSON3.read(open(json_path), Dict{String, Vector{Any}})
        catch
            @warn "Failed to parse existing colors JSON, using defaults" path=json_path
            return deepcopy(DEFAULT_MINERAL_STYLE)
        end
    else
        return deepcopy(DEFAULT_MINERAL_STYLE)
    end
end


function save_mineral_order(order::Vector{String}; path::String=joinpath(pkg_dir, "saved_states", "mineral_order_user.json"))
    mkpath(dirname(path))
    open(path, "w") do io
        JSON3.write(io, order)
    end
end

# try to load a user-saved mineral stacking order; falls back to alphabetical.
# keeps the saved relative order for known minerals and appends any new ones
# (not present in the saved file) sorted alphabetically at the end.
function load_mineral_order(all_minerals::Vector{String}; path::String=joinpath(pkg_dir, "saved_states", "mineral_order_user.json"))
    saved = String[]
    if isfile(path)
        try
            saved = collect(String, JSON3.read(open(path), Vector{String}))
        catch
            @warn "Failed to parse existing mineral order JSON, using default alphabetical order" path=path
        end
    end
    kept        = filter(m -> m in all_minerals, saved)
    missing_ph  = sort(setdiff(all_minerals, kept))
    return vcat(kept, missing_ph)
end

const REACTION_LINE_DEFAULT = ("solid",0.75,"#000000",10.0,"")

mageminapp_user_dir() = get(ENV, "MAGEMINAPP_USER_DIR", joinpath(first(DEPOT_PATH), "prefs", "MAGEMinApp"))

reaction_presets_path() = joinpath(mageminapp_user_dir(), "reaction_style_presets.json")

empty_reaction_presets() = Dict{String,Any}("version" => 2, "last" => nothing, "presets" => Dict{String,Any}())

function legacy_reaction_presets_paths()
    paths = String[joinpath(pkg_dir, "user_data", "reaction_style_presets.json")]
    for depot in DEPOT_PATH
        root = joinpath(depot, "packages", "MAGEMinApp")
        isdir(root) || continue
        for slug in readdir(root)
            push!(paths, joinpath(root, slug, "user_data", "reaction_style_presets.json"))
        end
    end
    return sort(unique(filter(isfile, paths)), by = mtime, rev = true)
end

function normalize_reaction_presets(raw)
    out = empty_reaction_presets()
    raw isa Dict || return out
    if haskey(raw, "presets") && get(raw, "version", 1) == 2
        raw["presets"] isa Dict && (out["presets"] = Dict{String,Any}(string(k) => v for (k, v) in raw["presets"] if v isa Dict))
        last = get(raw, "last", nothing)
        out["last"] = last isa AbstractString && (haskey(out["presets"], last) || is_file_preset_key(last)) ? String(last) : nothing
        return out
    end
    for dtb in sort(collect(keys(raw)))
        db = raw[dtb]
        db isa Dict || continue
        presets = get(db, "presets", nothing)
        presets isa Dict || continue
        for (name, entries) in presets
            entries isa Dict || continue
            key = haskey(out["presets"], name) ? "$(name) ($(dtb))" : String(name)
            out["presets"][key] = entries
        end
        last = get(db, "last", nothing)
        last isa AbstractString && haskey(out["presets"], last) && (out["last"] = String(last))
    end
    return out
end

function read_reaction_presets_file(path::String)
    try
        return normalize_reaction_presets(JSON.parsefile(path))
    catch
        @warn "Failed to parse reaction line style presets" path=path
        return nothing
    end
end

function load_reaction_style_presets(; path::String = reaction_presets_path(), migrate::Bool = true)
    if isfile(path)
        presets = read_reaction_presets_file(path)
        return something(presets, empty_reaction_presets())
    end
    migrate || return empty_reaction_presets()
    for legacy in legacy_reaction_presets_paths()
        presets = read_reaction_presets_file(legacy)
        (presets === nothing || isempty(presets["presets"])) && continue
        save_reaction_style_presets(presets; path = path) && println("Migrated phase boundary presets from $(legacy) to $(path)")
        return presets
    end
    return empty_reaction_presets()
end

function save_reaction_style_presets(presets::Dict{String,Any}; path::String = reaction_presets_path())
    try
        mkpath(dirname(path))
        tmp = path * ".tmp"
        open(tmp, "w") do io
            JSON.print(io, presets, 2)
        end
        mv(tmp, path; force = true)
        return true
    catch e
        @warn "Failed to save reaction line style presets" path=path exception=e
        return false
    end
end

function reaction_presets_store()
    store = AppData.reaction_style_presets[1]
    if !(get(store, "version", 1) == 2 && get(store, "presets", nothing) isa Dict)
        store = normalize_reaction_presets(store)
        AppData.reaction_style_presets[1] = store
    end
    return store
end

reaction_preset_names() = sort(collect(keys(reaction_presets_store()["presets"])))

is_file_preset_key(key) = key isa AbstractString && startswith(key, "file:")

function reaction_preset_entries()
    store = reaction_presets_store()["presets"]
    out   = Tuple{String,String,Dict}[]
    for name in sort(collect(keys(store)))
        push!(out, (name, name, store[name]))
    end
    user_data = abspath(joinpath(pkg_dir, "user_data"))
    for path in reaction_preset_files()
        file = basename(path)
        tag  = abspath(dirname(path)) == user_data ?
               (file == "reaction_style_presets.json" ? "user_data" : "user_data/$(file)") : file
        presets = reaction_preset_file_presets(path)["presets"]
        for name in sort(collect(keys(presets)))
            entries = presets[name]
            get(store, name, nothing) == entries && continue
            any(e -> e[3] == entries && endswith(e[1], "#" * name), out) && continue
            push!(out, ("file:$(path)#$(name)", "$(name) ($(tag))", entries))
        end
    end
    return out
end

reaction_preset_keys() = [e[1] for e in reaction_preset_entries()]

reaction_preset_options() = [Dict("label" => " " * e[2], "value" => e[1]) for e in reaction_preset_entries()]

function reaction_preset_entry(key)
    key isa AbstractString || return nothing
    if !is_file_preset_key(key)
        entries = get(reaction_presets_store()["presets"], key, nothing)
        return entries isa Dict ? entries : nothing
    end
    i = findlast('#', key)
    i === nothing && return nothing
    path, name = key[6:prevind(key, i)], key[nextind(key, i):end]
    presets = isfile(path) ? reaction_preset_file_presets(path) : nothing
    presets === nothing && return nothing
    entries = get(presets["presets"], name, nothing)
    return entries isa Dict ? entries : nothing
end

reaction_preset_plain_name(key) = is_file_preset_key(key) ? key[nextind(key, findlast('#', key)):end] : String(key)

function reaction_preset_last()
    last = get(reaction_presets_store(), "last", nothing)
    return reaction_preset_entry(last) === nothing ? nothing : last
end

function current_reaction_styles()
    global phase_infos
    styles = Dict{String,Tuple}()
    @isdefined(phase_infos) || return styles
    for (names, opts) in ((phase_infos.act_ss, phase_infos.reac_ss), (phase_infos.act_pp, phase_infos.reac_pp))
        for (ph, opt) in zip(names, opts)
            styles[ph] = opt
        end
    end
    return styles
end

is_styled_reaction(opt) = Tuple(opt[1:4]) != REACTION_LINE_DEFAULT[1:4]

function styled_reaction_phases()
    global phase_infos
    @isdefined(phase_infos) || return Tuple{String,Tuple}[]
    out = Tuple{String,Tuple}[]
    for (names, opts) in ((phase_infos.act_ss, phase_infos.reac_ss), (phase_infos.act_pp, phase_infos.reac_pp))
        for (ph, opt) in zip(names, opts)
            is_styled_reaction(opt) && push!(out, (String(ph), opt))
        end
    end
    return out
end

function set_reaction_style!(ph::String, opt::Tuple)
    global phase_infos
    @isdefined(phase_infos) || return false
    id = findfirst(==(ph), phase_infos.act_ss)
    if id !== nothing
        phase_infos.reac_ss[id] = opt
        return true
    end
    id = findfirst(==(ph), phase_infos.act_pp)
    id === nothing && return false
    phase_infos.reac_pp[id] = opt
    return true
end

function reaction_style_of(ph)
    global phase_infos
    @isdefined(phase_infos) || return REACTION_LINE_DEFAULT
    id = findfirst(==(ph), phase_infos.act_ss)
    id !== nothing && return phase_infos.reac_ss[id]
    id = findfirst(==(ph), phase_infos.act_pp)
    return id === nothing ? REACTION_LINE_DEFAULT : phase_infos.reac_pp[id]
end

function apply_last_reaction_preset!()
    last = reaction_preset_last()
    last === nothing && return false
    apply_reaction_preset!(last; remember = false)
    return true
end

function restore_reaction_styles_from_traces!(traces)
    global phase_infos
    @isdefined(phase_infos) || return
    all_ph = vcat(phase_infos.act_ss, phase_infos.act_pp)
    length(traces) == length(all_ph) || return
    for (ph, tr) in zip(all_ph, traces)
        ln = tr[:line]
        get_ln(k, d) = haskey(ln, k) && ln[k] !== nothing ? ln[k] : d
        opt = (string(get_ln(:dash, "solid")), Float64(get_ln(:width, 0.75)), string(get_ln(:color, "#000000")), REACTION_LINE_DEFAULT[4], String(ph))
        is_styled_reaction(opt) && set_reaction_style!(String(ph), opt)
    end
end

function preset_reaction_styles(name)
    styles  = Dict{String,Tuple}()
    entries = reaction_preset_entry(name)
    entries isa Dict || return styles
    for (ph, v) in entries
        try
            styles[ph] = (String(v[1]), Float64(v[2]), String(v[3]), Float64(v[4]), ph)
        catch
        end
    end
    return styles
end

function save_reaction_preset!(key)
    name = strip(reaction_preset_plain_name(key))
    isempty(name) && return "Type a preset name in the dropdown first", nothing
    name  = String(name)
    store = reaction_presets_store()
    existed = haskey(store["presets"], name)
    store["presets"][name] = Dict{String,Any}(ph => Any[opt[1], opt[2], opt[3], opt[4]] for (ph, opt) in styled_reaction_phases())
    store["last"] = name
    save_reaction_style_presets(store) || return "Could not write $(reaction_presets_path())", name
    return (existed ? "Updated preset '$(name)'" : "Saved preset '$(name)'"), name
end

reaction_preset_file_dirs() = unique([joinpath(pkg_dir, "user_data"), mageminapp_user_dir()])

function reaction_preset_file_presets(path::String)
    raw = try
        JSON.parsefile(path)
    catch
        return nothing
    end
    presets = normalize_reaction_presets(raw)
    return isempty(presets["presets"]) ? nothing : presets
end

function reaction_preset_files()
    store = abspath(reaction_presets_path())
    files = String[]
    for dir in reaction_preset_file_dirs()
        isdir(dir) || continue
        for f in sort(readdir(dir))
            path = joinpath(dir, f)
            endswith(lowercase(f), ".json") && isfile(path) && abspath(path) != store || continue
            reaction_preset_file_presets(path) === nothing || push!(files, path)
        end
    end
    return files
end

function remove_preset_from_raw!(raw, name)
    raw isa Dict || return false
    if haskey(raw, "presets") && get(raw, "version", 1) == 2
        presets = raw["presets"]
        presets isa Dict && haskey(presets, name) || return false
        delete!(presets, name)
        get(raw, "last", nothing) == name && (raw["last"] = nothing)
        return true
    end
    for dtb in sort(collect(keys(raw)))
        db = raw[dtb]
        db isa Dict && get(db, "presets", nothing) isa Dict || continue
        for key in (name, endswith(name, " ($(dtb))") ? chop(name; tail = length(" ($(dtb))")) : nothing)
            key !== nothing && haskey(db["presets"], key) || continue
            delete!(db["presets"], key)
            get(db, "last", nothing) == key && delete!(db, "last")
            return true
        end
    end
    return false
end

function delete_file_reaction_preset!(key)
    i    = findlast('#', key)
    path = key[6:prevind(key, i)]
    name = key[nextind(key, i):end]
    isfile(path) || return "File not found: $(path)", false
    raw = try
        JSON.parsefile(path)
    catch
        return "Could not read $(path)", false
    end
    remove_preset_from_raw!(raw, name) || return "Preset '$(name)' not found in $(path)", false
    try
        open(path, "w") do io
            JSON.print(io, raw, 2)
        end
    catch
        return "Could not write $(path) (read-only?)", false
    end
    forget = get(reaction_presets_store(), "last", nothing) == key
    forget && forget_reaction_preset_last!()
    return "Deleted preset '$(name)' from $(basename(path))", true
end

function delete_reaction_preset!(name)
    is_file_preset_key(name) && return delete_file_reaction_preset!(name)
    store = reaction_presets_store()
    haskey(store["presets"], name) || return "No saved preset '$(name)'", false
    delete!(store["presets"], name)
    get(store, "last", nothing) == name && (store["last"] = nothing)
    ok = save_reaction_style_presets(store)
    return ok ? ("Deleted preset '$(name)'", true) : ("Could not write $(reaction_presets_path())", false)
end

function apply_reaction_preset!(name; remember::Bool = true)
    global phase_infos
    @isdefined(phase_infos) || return
    styles = preset_reaction_styles(name)
    for (names, opts) in ((phase_infos.act_ss, phase_infos.reac_ss), (phase_infos.act_pp, phase_infos.reac_pp))
        for i in eachindex(names)
            opts[i] = get(styles, names[i], REACTION_LINE_DEFAULT)
        end
    end
    if remember
        store = reaction_presets_store()
        store["last"] = name
        save_reaction_style_presets(store)
    end
end

function forget_reaction_preset_last!()
    store = reaction_presets_store()
    get(store, "last", nothing) === nothing && return false
    store["last"] = nothing
    return save_reaction_style_presets(store)
end

function reset_reaction_styles!()
    global phase_infos
    @isdefined(phase_infos) || return false
    for opts in (phase_infos.reac_ss, phase_infos.reac_pp)
        fill!(opts, REACTION_LINE_DEFAULT)
    end
    forget_reaction_preset_last!()
    return true
end

# sort ph_list according to the rank of each name in `order`; names absent from
# `order` are sorted alphabetically and placed after all ranked names.
function order_phases(ph_list, order::Vector{String}=AppData.mineral_order[1])
    rank(ph) = something(findfirst(==(ph), order), length(order) + 1)
    return sort(collect(ph_list), by = ph -> (rank(ph), ph))
end

function get_phase_color(ph::String; default::String="grey")
    style = AppData.mineral_style[1]
    return haskey(style, ph) ? style[ph][1] : default
end


# Function to dynamically create dbc_input for each mineral
function create_ph_names(style::Dict{String, Vector{Any}})
    inputs = []
    for mineral in sort(collect(keys(style)))
        push!(inputs, dbc_row([
            dbc_col(html_label(mineral, style=Dict("font-weight" => "bold")), width=12),
        ], id="row-name-$mineral", style=Dict("margin-bottom" => "0px", "height" => "24px", "display" => "block")))
    end
    return inputs
end

function create_color_table(style::Dict{String, Vector{Any}}; id::String = "color-table-id")

    data = [
        Dict("Mineral" => mineral, "Color" => style[mineral][1])
        for mineral in sort(collect(keys(style)))
    ]
    columns = [
        Dict("name" => "Mineral",   "id" => "Mineral",  "width" => "30%"),
        Dict("name" => "Color",     "id" => "Color",    "width" => "70%")
    ]

    color_list = [style[mineral][1] for mineral in sort(collect(keys(style)))]
    row_conditionals = [
        Dict("if" => Dict("row_index" => i-1, "column_id" => "Color"), "background-color" => color_list[i])
        for i in 1:length(color_list)
    ]

    return dash_datatable(
        id                          = id,
        data                        =  data,
        columns                     =  columns,
        style_table                 =  Dict("margin" => "0", "padding" => "0", "table-layout" => "fixed"),
        style_cell                  =  Dict("margin" => "0", "padding" => "0", "height" => "24px", "line-height" => "24px", "text-align" => "center"),
        style_data                  =  Dict("background-color" => "white"), 
        style_data_conditional      =  row_conditionals,
        editable                    =  false,  
        row_deletable               =  false,
        cell_selectable             =  false,
        filter_action               = "none",
        sort_action                 = "none",
        page_action                 = "none"  
    )
end


function create_color_selec(style::Dict{String, Vector{Any}}; id::String = "color-table-change-id")
    data = [
        Dict("Change" => " ")
        for mineral in sort(collect(keys(style)))
    ]
    columns = [
        Dict("name" => "Change", "id" => "Change")
    ]

    return dash_datatable(
        id                          = id,
        data                        =  data,
        columns                     =  columns,
        style_table                 =  Dict("margin" => "0", "padding" => "0", "table-layout" => "fixed"),
        style_cell                  =  Dict("margin" => "0", "padding" => "0", "height" => "24px", "line-height" => "24px", "text-align" => "center"),
        style_data                  =  Dict("background-color" => "white"),
        editable                    =  false, 
        row_deletable               =  false,
        cell_selectable             =  true,
        filter_action               = "none",
        sort_action                 = "none",
        page_action                 = "none"
    )
end


# Builds the row data (top-to-bottom) for the "Phase order" table. `visible` are
# the mineral keys currently relevant (e.g. active phases for the current path).
#
# `order_phases` ranks phases in stacking order, i.e. the order traces are added
# to the plot: first trace = bottom of the stack. Plotly's legend for stacked
# area/bar plots is reversed by default (topmost legend entry = last trace added
# = top of the visual stack), so the table is displayed reversed to match what
# the user actually sees in the legend, top-to-bottom.
function phase_order_rows(order::Vector{String}, visible)
    ordered = reverse(order_phases(String.(visible), order))
    return [
        Dict("Mineral" => display_ph_name(mineral), "LegacyMineral" => mineral)
        for mineral in ordered
    ]
end

function create_assemblage_table(rows::Vector{Dict{String,String}}; id::String = "phase-assemblage-table-id")
    columns = [
        Dict("name" => "#",           "id" => "N"),
        Dict("name" => "Assemblage",  "id" => "Assemblage"),
    ]

    return dash_datatable(
        id                          = id,
        data                        =  rows,
        columns                     =  columns,
        style_table                 =  Dict("margin" => "0", "padding" => "0", "max-height" => "640px", "overflow-y" => "auto"),
        style_cell                  =  Dict("margin" => "0", "padding" => "2px", "textAlign" => "left", "whiteSpace" => "pre"),
        style_data                  =  Dict("background-color" => "white"),
        style_data_conditional      =  [
            Dict("if" => Dict("row_index" => "odd"), "background-color" => "#f7f7f7"),
        ],
        editable                    =  false,
        row_deletable               =  false,
        cell_selectable             =  true,
        filter_action               = "none",
        sort_action                 = "none",
        page_action                 = "none"
    )
end

function create_order_table(order::Vector{String}, visible)

    data = phase_order_rows(order, visible)
    columns = [
        Dict("name" => "Mineral", "id" => "Mineral"),
    ]

    return dash_datatable(
        id                          = "phase-order-table-id",
        data                        =  data,
        columns                     =  columns,
        style_table                 =  Dict("margin" => "0", "padding" => "0", "table-layout" => "fixed"),
        style_cell                  =  Dict("margin" => "0", "padding" => "0", "height" => "24px", "line-height" => "24px", "text-align" => "center"),
        style_data                  =  Dict("background-color" => "white"),
        style_data_conditional      =  [
            Dict("if" => Dict("row_index" => "odd"), "background-color" => "#f7f7f7"),
        ],
        editable                    =  false,
        row_deletable               =  false,
        cell_selectable             =  true,
        filter_action               = "none",
        sort_action                 = "none",
        page_action                 = "none"
    )
end


# Function to dynamically create dbc_input for each mineral
function create_dropdown_inputs(style::Dict{String, Vector{Any}})
    inputs = []
    for mineral in sort(collect(keys(style)))
        push!(inputs, dbc_row([
            dbc_col(dbc_select(
                id = "dropdown-$mineral",
                options=[
                    Dict("label" => "Solid", "value" => "solid"),
                    Dict("label" => "Dashed", "value" => "dashed"),
                    Dict("label" => "Dotted", "value" => "dotted"),
                    Dict("label" => "DashDot", "value" => "dashdot")
                ],
                value=style[mineral][2],  # Default linestyle
                style=Dict( "padding" => "0", "margin" => "0" )
            ))
        ], id="row-linestyle-$mineral", style=Dict("margin-bottom" => "0px", "height" => "24px", "display" => "block")))
    end
    return inputs
end
