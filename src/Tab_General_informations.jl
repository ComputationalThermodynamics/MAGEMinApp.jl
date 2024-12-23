activity     = """
Oxide activity is computed as:

\$a_{oxide}=\\exp{\\left(\\frac{\\mu_{oxide} - G_{pp}^0}{RT}\\right)}\$, 

where \$\\mu_{oxide}\$ is the chemical potential of the oxide and \$G_{pp}^0\$ is the Gibbs energy of the corresponding pure phase at given pressure and temperature conditions.

Used pure phases are:

- corundum for \$\\text{Al2O3}\$
- periclase for \$\\text{MgO}\$
- ferropericlase for \$\\text{FeO}\$
- rutile for \$\\text{TiO2}\$
- quartz/coesite for \$\\text{SiO2}\$
- dioxygen for \$\\text{O2}\$

"""

function Tab_General_informations(db_inf)
    html_div([
        html_div("‎ "),
        dbc_row([ 
            dbc_col([ 

                dbc_row([
                    html_h1("Calculation details", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                    html_hr(),
                    dbc_card([
                        dcc_markdown(activity;    mathjax=true, style = Dict("font-size" => "130%")),
                    ])
                ]),

            ],width=6),


        ]),
    ])

end

