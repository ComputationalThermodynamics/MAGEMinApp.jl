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


function create_ph_style()

    dict_ss = Dict{String, Any}()
    dict_ss["sp"] = "spinel",[ "sp" "spinel";
                                "mt" "magnetite" ] 

    dict_ss["spl"] = "spinel",[ "spl" "spinel";
                                "cm" "chromite";
                                "usp" "uvospinel";
                                "mgt" "magnetite" ] 

    dict_ss["fsp"] = "feldspar",[   "afs" "alkali-feldspar";
                                    "pl" "plagioclase" ] 

    dict_ss["mu"] = "muscovite",[   "pat" "paragonite";
                                    "mu" "muscovite" ] 

    dict_ss["amp"] = "amphibole",[  "gl" "glaucophane";
                                    "act" "actinolite";
                                    "cumm" "cummingtonite";
                                    "tr" "tremolite";
                                    "amp" "amphibole" ] 

    dict_ss["ilm"] = "ilmenite",[   "hem" "hematite";
                                    "ilm" "ilmenite" ] 

    dict_ss["ilmm"] = "ilmenite",[   "hemm" "hematite";
                                    "ilmm" "ilmenite" ] 

    dict_ss["nph"] = "nepheline",[  "K-nph" "K-rich nepheline";
                                    "nph" "nepheline" ] 

    dict_ss["cpx"] = "clinopyroxene",[  "pig" "pigeonite";
                                        "Na-cpx" "Na-rich clinopyroxene";
                                        "cpx" "clinopyroxene" ] 

    dict_ss["dio"] = "diopside",[   "dio" "diopside";
                                    "omph" "omphacite";
                                    "jd" "jadeite" ] 

    dict_ss["occm"] = "carbonate",[ "sid" "siderite";
                                    "ank" "ankerite";
                                    "mag" "magnesite";
                                    "cc" "calcite"] 
    dict_ss["ta"]  = "talc",[ "ta" "talc"] 
    dict_ss["oamp"] = "orthoamhibole",[ "anth" "anthophyllite";
                                        "ged" "gedrite" ]
    dict_ss["opx"]  = "orthopyroxene",[ "opx" "orthopyroxene"] 

    solvus_ss = keys(dict_ss)
    
    pp_list = String[]
    ss_list = String[]

    dbs     = ["mp","mb","mbe","ig","igd","igad","um","ume","mtl","mpe","sb11","sb21","sb24","rMELTS","pMELTS"] #"cs","igm",

    for db in dbs
        ph = retrieve_solution_phase_information(db)
        pp = ph.data_pp
        ss = ph.ss_name

        for i in pp
            if !(i in pp_list)
                push!(pp_list, i)
            end
        end
        for i in ss
            if !(i in ss_list)
                push!(ss_list, i)
            end
        end
    end
   
    solvus_ss = keys(dict_ss)
    for ph in solvus_ss
         n = size(dict_ss[ph][2],1)
         for i = 1:n
             ss = dict_ss[ph][2][i,1]
             if !(ss in ss_list)
                 push!(ss_list, ss)
             end
         end
    end

    return sort(vcat(pp_list, ss_list))
end


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

function create_color_table(style::Dict{String, Vector{Any}})

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
        id                          = "color-table-id",
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


function create_color_selec(style::Dict{String, Vector{Any}})
    data = [
        Dict("Change" => " ")
        for mineral in sort(collect(keys(style)))
    ]
    columns = [
        Dict("name" => "Change", "id" => "Change")
    ]

    return dash_datatable(
        id                          = "color-table-change-id",  
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
