#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Dominguez, H., Moyen, J-F.
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

    dbs     = ["mp","mb","mbe","ig","igad","um","ume","mtl","mpe","sb11","sb21"]

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


# Function to generate a random color in hexadecimal format
function random_color()
    return "#" * join(rand(0:255, 3) .|> x -> string(x, base=16, pad=2))
end

# Function to create DEFAULT_MINERAL_STYLE with random colors
function create_default_mineral_style(mineral_names::Vector{String})
    mineral_style = Dict{String, Vector{Any}}()
    for mineral in mineral_names
        # Generate a random color and add the mineral to the dictionary
        mineral_style[mineral] = [random_color(), "solid", 1.0]
    end
    return mineral_style
end

function save_style(dict::Dict{String, Vector{Any}}; path::String="./user_data/mineral_style_used.json")
    open(path, "w") do io
        JSON3.write(io, dict; indent=2)
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
