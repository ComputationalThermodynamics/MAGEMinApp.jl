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

reaction_presets_path() = joinpath(pkg_dir, "user_data", "reaction_style_presets.json")

function load_reaction_style_presets(; path::String = reaction_presets_path())
    isfile(path) || return Dict{String,Any}()
    try
        presets = JSON.parsefile(path)
        return presets isa Dict{String,Any} ? presets : Dict{String,Any}()
    catch
        @warn "Failed to parse reaction line style presets, starting without presets" path=path
        return Dict{String,Any}()
    end
end

function save_reaction_style_presets(presets::Dict{String,Any}; path::String = reaction_presets_path())
    try
        mkpath(dirname(path))
        tmp = path * ".tmp"
        open(tmp, "w") do io
            JSON.print(io, presets, 2)
        end
        mv(tmp, path; force = true)
    catch e
        @warn "Failed to save reaction line style presets" path=path exception=e
    end
end

function reaction_presets_of(dtb)
    db = get(AppData.reaction_style_presets[1], string(dtb), nothing)
    return db isa Dict ? db : Dict{String,Any}("last" => nothing, "presets" => Dict{String,Any}())
end

reaction_preset_names(dtb) = sort(collect(keys(get(reaction_presets_of(dtb), "presets", Dict{String,Any}()))))

function reaction_preset_last(dtb)
    last = get(reaction_presets_of(dtb), "last", nothing)
    return last in reaction_preset_names(dtb) ? last : nothing
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

function preset_reaction_styles(dtb, name)
    styles  = Dict{String,Tuple}()
    entries = get(get(reaction_presets_of(dtb), "presets", Dict{String,Any}()), string(something(name, "")), nothing)
    entries isa Dict || return styles
    for (ph, v) in entries
        styles[ph] = (String(v[1]), Float64(v[2]), String(v[3]), Float64(v[4]), ph)
    end
    return styles
end

function save_reaction_preset!(dtb, name)
    db      = get!(AppData.reaction_style_presets[1], string(dtb), Dict{String,Any}())
    presets = get!(db, "presets", Dict{String,Any}())
    presets[name] = Dict{String,Any}(ph => Any[opt[1], opt[2], opt[3], opt[4]]
                                        for (ph, opt) in current_reaction_styles() if opt[1:4] != REACTION_LINE_DEFAULT[1:4])
    db["last"] = name
    save_reaction_style_presets(AppData.reaction_style_presets[1])
end

function delete_reaction_preset!(dtb, name)
    db = get(AppData.reaction_style_presets[1], string(dtb), nothing)
    db isa Dict || return
    presets = get(db, "presets", nothing)
    presets isa Dict && delete!(presets, name)
    get(db, "last", nothing) == name && (db["last"] = nothing)
    save_reaction_style_presets(AppData.reaction_style_presets[1])
end

function apply_reaction_preset!(dtb, name)
    global phase_infos
    @isdefined(phase_infos) || return
    styles = preset_reaction_styles(dtb, name)
    for (names, opts) in ((phase_infos.act_ss, phase_infos.reac_ss), (phase_infos.act_pp, phase_infos.reac_pp))
        for i in eachindex(names)
            opts[i] = get(styles, names[i], REACTION_LINE_DEFAULT)
        end
    end
    db = get!(AppData.reaction_style_presets[1], string(dtb), Dict{String,Any}())
    db["last"] = name
    save_reaction_style_presets(AppData.reaction_style_presets[1])
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
