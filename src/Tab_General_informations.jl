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
**Water saturation at solidus for P-T diagrams**

- First, for the given pressure range (and using 50 pressure steps), the water-saturated solidus is extracted using bisection method.
- Subsequently, the pressure-dependent solidus temperature is interpolated using PChip interpolant.
- At Tsuprasolidus = Tsolidus + 0.1 K, a second interpolation is used to retrieve the amount of water saturating the melt. The latter interpolant is then used to prescribe the water content of the bulk, ensuring pressure-dependent water saturation at solidus (+ 0.1 K). 

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
                    ]),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(heatCapacity;          mathjax=true, style = Dict("font-size" => "130%")),
                    ]),
                ]),

            ],width=6),


        ]),
    ])

end

