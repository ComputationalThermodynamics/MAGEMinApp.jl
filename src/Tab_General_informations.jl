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

SiteFractionCalculator = """
**Site Fraction calculator (isopleths)**

- When calculating isopleths using the 'Calculator (site fractions)' options for solution phases, the list of available mixing sites is displayed in a text box.
- Complete description of site mixing formulation and related activity-composition models (solution phase) can be found on the THERMOCALC website: https://hpxeosandthermocalc.org/downloads/

"""


phase_deactivation = """
**Phase deactivation**

- When solution phases are not ticked for deactivation, the default solution phase combination is used. 
    - For metapelites: sp and ilm are active (mt and ilmm deactivated)
    - For metabasites: ilm is active (ilmm deactivated)
- As soon as one solution phase is unticked (deactivated), the remaining ticked phases are all active. 
This implies that multiple solution phases for the same mineral can be active e.g., sp and mt or ilm and ilmm (for the metapelite database), and that the user needs to choose which one to activate.

"""


activity     = """
**Oxide activity is computed as**

\$a_{oxide}=\\exp{\\left(\\frac{\\mu_{oxide} - G_{pp}^0}{RT}\\right)}\$, 

where \$\\mu_{oxide}\$ is the chemical potential of the oxide and \$G_{pp}^0\$ is the Gibbs energy of the corresponding pure phase at given pressure and temperature conditions.

#### Used pure phases are:

- corundum for \${Al_2O_3}\$
- periclase for \${MgO}\$
- ferropericlase for \${FeO}\$
- rutile for \${TiO_2}\$
- quartz/coesite for \${SiO_2}\$
- dioxygen for \${O_2}\$

"""

water_saturation = """
**Water saturation at solidus (first liquid) for P-T diagrams**

- First, for the given pressure range (and using 50 pressure steps), the water-saturated solidus is extracted using bisection method.
- Subsequently, the pressure-dependent solidus temperature is interpolated using PChip interpolant.
- At Tsuprasolidus = Tsolidus + 0.01 K, a second interpolation is used to retrieve the amount of water saturating the melt. The latter interpolant is then used to prescribe the water content of the bulk, ensuring pressure-dependent water saturation at solidus (+ 0.1 K). 

*Note that the provided water content needs to be large enough to ensure water saturation. This can be easily done by increasing the \$H_2O\$ content in the bulk table.*

"""

heatCapacity = """
**Specific heat capacity**

- Heat capacity is computed as a second order derivative of the Gibbs energy with respect to temperature using numerical differentiation.

\$C_p = -T \\frac{\\partial ^2G}{\\partial T^2}\$

- There is two ways to retrieve the second order derivative:

    **1. Default option (Cp = G0, Solver = Hybrid)** Fixing the phase assemblage (phase proportions and compositions) and computing the Gibbs energy of the assemblage at T, T+eps and T-eps.

    **2. Full differentiation option (Cp = G_system, Solver = Legacy)** Computing three stable phase equilibrium at T, T+eps and T-eps.
    
*While the first method is computationally more efficient, it does not account for the latent heat of reaction.
When having correct heat budget is important it is therefore recommanded to employ the second approach.*
"""

function Tab_General_informations()
    html_div([
        html_div("‎ "),
        dbc_row([ 


        dbc_col([
            dbc_row([
                html_h1("Solution phase information", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                dash_datatable(
                    id="table-solution-phases",
                    columns=(  [    Dict("id" =>  "ss",         "name" =>  "solution name",     "editable" => false),
                                    Dict("id" =>  "ss_abrev",   "name" =>  "abbreviation",      "editable" => false),
                                    Dict("id" =>  "solvus",     "name" =>  "solvus",            "editable" => false)     
                                ]
                    ),
                    data        =   [Dict(  "ss"         => AppData.dict_ss[i][1],
                                            "ss_abrev"   => i,
                                            "solvus"     => join(map((x, y) -> "$x, $y", AppData.dict_ss[i][2][2], AppData.dict_ss[i][2][1]), "; ") )
                                                for i in keys(AppData.dict_ss) ],

                    style_cell  = (textAlign="center", fontSize="120%",),
                    style_header= (fontWeight="bold",),
                    editable    = false,
                    page_size   = 16,
                    filter_action="native"
                ),
                html_div("‎ "),
            ]),
            dbc_row([
                html_h1("End-members information", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                dash_datatable(
                    id="table-endmember-phases",
                    columns=(  [    Dict("id" =>  "em",         "name" =>  "end-member name",   "editable" => false),
                                    Dict("id" =>  "em_abrev",   "name" =>  "abbreviation",      "editable" => false),
                                    Dict("id" =>  "compo",      "name" =>  join(vcat(AppData.dict_em["_header_"][3]...),", "),       "editable" => false)     
                                ]
                    ),
                    data        =   [Dict(  "em"         => AppData.dict_em[i][2],
                                            "em_abrev"   => i,
                                            "compo"      => join(vcat(AppData.dict_em[i][3]...),", ") )
                                                for i in keys(AppData.dict_em) if i != "_header-"],

                    style_cell  = (textAlign="center", fontSize="120%",),
                    style_header= (fontWeight="bold",),
                    editable    = false,
                    page_size   = 16,
                    filter_action="native"
                ),
                html_div("‎ "),
            ]),
            dbc_row([

                html_h1("Trace-Elements partitioning coefficients (O. Laurent, 2012)", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
            dbc_tabs([
                dbc_tab(label="SiO2 < 52 wt%", children=[
                    dbc_row([   
                        
                        dash_datatable(
                            id          ="table-ol12-l52",
                            columns=(  [    Dict("id" =>  vcat("Element",string.(keys(AppData.dict_OL12_KDs_l52["Rb"])))[i], "name" =>  vcat("Element",string.(keys(AppData.dict_OL12_KDs_l52["Rb"])))[i], "editable" => false) for i in 1:length(vcat("Element",string.(keys(AppData.dict_OL12_KDs_l52["Rb"])))) ]),
                            data = [
                                merge(Dict("Element" => string.(keys(AppData.dict_OL12_KDs_l52))[i]), Dict(vcat("Element",string.(keys(AppData.dict_OL12_KDs_l52["Rb"])))[j] => round(AppData.dict_OL12_KDs_l52[string.(keys(AppData.dict_OL12_KDs_l52))[i]][vcat("Element",string.(keys(AppData.dict_OL12_KDs_l52["Rb"])))[j]],digits=5) for j in 2:length(vcat("Element",string.(keys(AppData.dict_OL12_KDs_l52["Rb"]))))))
                                for i in 1:length(string.(keys(AppData.dict_OL12_KDs_l52)))
                            ],
                            style_cell  = Dict(
                                "textAlign" => "center",
                                "fontSize" => "120%",
                                "userSelect" => "text"  # <-- This makes cell content selectable
                            ),
                            style_header= (fontWeight="bold",),
                            style_data_conditional = [
                                Dict("if" => Dict("column_id" => "Element"), "fontWeight" => "bold")
                            ],
                            editable    = false,
                            page_size   = 32,
                            filter_action="native"
                        ),
                    ]),
                ]),
                dbc_tab(label="52 wt% <= SiO2 < 63 wt%", children=[
                    dbc_row([   
                        html_h1("Trace-Elements partitioning coefficients (Laurent, 2012)", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                        dash_datatable(
                            id          ="table-ol12-g53l63",
                            columns=(  [    Dict("id" =>  vcat("Element",string.(keys(AppData.dict_OL12_KDs_g52l63["Rb"])))[i], "name" =>  vcat("Element",string.(keys(AppData.dict_OL12_KDs_g52l63["Rb"])))[i], "editable" => false) for i in 1:length(vcat("Element",string.(keys(AppData.dict_OL12_KDs_g52l63["Rb"])))) ]),
                            data = [
                                merge(Dict("Element" => string.(keys(AppData.dict_OL12_KDs_g52l63))[i]), Dict(vcat("Element",string.(keys(AppData.dict_OL12_KDs_g52l63["Rb"])))[j] => round(AppData.dict_OL12_KDs_g52l63[string.(keys(AppData.dict_OL12_KDs_g52l63))[i]][vcat("Element",string.(keys(AppData.dict_OL12_KDs_g52l63["Rb"])))[j]],digits=5) for j in 2:length(vcat("Element",string.(keys(AppData.dict_OL12_KDs_g52l63["Rb"]))))))
                                for i in 1:length(string.(keys(AppData.dict_OL12_KDs_g52l63)))
                            ],
                            style_cell  = Dict(
                                "textAlign" => "center",
                                "fontSize" => "120%",
                                "userSelect" => "text"  # <-- This makes cell content selectable
                            ),
                            style_header= (fontWeight="bold",),
                            style_data_conditional = [
                                Dict("if" => Dict("column_id" => "Element"), "fontWeight" => "bold")
                            ],
                            editable    = false,
                            page_size   = 32,
                            filter_action="native"
                        ),
                    ]),
                ]),
                dbc_tab(label="63 wt% <= SiO2 ", children=[
                    dbc_row([   
                        html_h1("Trace-Elements partitioning coefficients (Laurent, 2012)", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                        dash_datatable(
                            id          ="table-ol12-g63",
                            columns=(  [    Dict("id" =>  vcat("Element",string.(keys(AppData.dict_OL12_KDs_g63["Rb"])))[i], "name" =>  vcat("Element",string.(keys(AppData.dict_OL12_KDs_g63["Rb"])))[i], "editable" => false) for i in 1:length(vcat("Element",string.(keys(AppData.dict_OL12_KDs_g63["Rb"])))) ]),
                            data = [
                                merge(Dict("Element" => string.(keys(AppData.dict_OL12_KDs_g63))[i]), Dict(vcat("Element",string.(keys(AppData.dict_OL12_KDs_g63["Rb"])))[j] => round(AppData.dict_OL12_KDs_g63[string.(keys(AppData.dict_OL12_KDs_g63))[i]][vcat("Element",string.(keys(AppData.dict_OL12_KDs_g63["Rb"])))[j]],digits=5) for j in 2:length(vcat("Element",string.(keys(AppData.dict_OL12_KDs_g63["Rb"]))))))
                                for i in 1:length(string.(keys(AppData.dict_OL12_KDs_g63)))
                            ],
                            style_cell  = Dict(
                                "textAlign" => "center",
                                "fontSize" => "120%",
                                "userSelect" => "text"  # <-- This makes cell content selectable
                            ),
                            style_header= (fontWeight="bold",),
                            style_data_conditional = [
                                Dict("if" => Dict("column_id" => "Element"), "fontWeight" => "bold")
                            ],
                            editable    = false,
                            page_size   = 32,
                            filter_action="native"
                        ),
                    ]),
                ]),

            ]),
        ]),

        ],width=6),

            dbc_col([ 

                dbc_row([
                    html_h1("Calculation details", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                    # html_hr(),
                    dbc_card([
                        dcc_markdown(phase_deactivation;    mathjax=true, style = Dict("font-size" => "130%")),
                    ]),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(activity;              mathjax=true, style = Dict("font-size" => "130%")),
                    ]),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(water_saturation;      mathjax=true, style = Dict("font-size" => "130%")),
                    ]),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(heatCapacity;          mathjax=true, style = Dict("font-size" => "130%")),
                    ]),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(SiteFractionCalculator;          mathjax=true, style = Dict("font-size" => "130%")),
                    ]),
                ]),

            ],width=6),




        ]),
    ])

end

