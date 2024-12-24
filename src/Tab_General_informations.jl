phase_deactivation = """
**Phase deactivation**

- When solution phases are not ticked for deactivation, the default solution phase combination is used. 
- As soon as one solution phase is unticked (for deactivation), the remaining ticked phases are all active. 
This implies that multiple solution phases for the same mineral can be active e.g., sp and mt or ilm and ilmm (for the metapelite database). 


"""


activity     = """
**Oxide activity is computed as**

\$a_{oxide}=\\exp{\\left(\\frac{\\mu_{oxide} - G_{pp}^0}{RT}\\right)}\$, 

where \$\\mu_{oxide}\$ is the chemical potential of the oxide and \$G_{pp}^0\$ is the Gibbs energy of the corresponding pure phase at given pressure and temperature conditions.

#### Used pure phases are:

- corundum for \$\\text{Al2O3}\$
- periclase for \$\\text{MgO}\$
- ferropericlase for \$\\text{FeO}\$
- rutile for \$\\text{TiO2}\$
- quartz/coesite for \$\\text{SiO2}\$
- dioxygen for \$\\text{O2}\$

"""

water_saturation = """
**Water saturation at solidus for P-T diagrams**

- First, for the given pressure range (and using 50 pressure steps), the water-saturated solidus is extracted using bisection method.
- Subsequently, the pressure-dependent solidus temperature is interpolated using PChip interpolant.
- At Tsuprasolidus = Tsolidus + 0.1 K, a second interpolation is used to retrieve the amount of water saturating the melt. The latter interpolant is then used to prescribe the water content of the bulk, ensuring pressure-dependent water saturation at solidus (+ 0.1 K). 

*Note that the provided water content needs to be large enough to ensure water saturation. This can be easily done by increasing the \$H_2O\$ content in the bulk table.*

"""

function Tab_General_informations(db_inf)
    html_div([
        html_div("‎ "),
        dbc_row([ 
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
                    ])
                ]),

            ],width=6),


        ]),
    ])

end

