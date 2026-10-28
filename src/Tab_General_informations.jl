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


SeismicVelocityMeltCorrection = """
**Seismic velocity corrections (\$V_{p,cor}\$, \$V_{s,cor}\$)**

When "Seismic correction" is set to *true*, MAGEMin computes melt-, anelastic- and shallow-corrected P- and S-wave velocities of the solid aggregate, in addition to the uncorrected elastic \$V_p\$ and \$V_s\$.

#### Melt correction

- Based on the reduction formulation of Clark et al. (2017), using the equilibrium geometry model for the solid skeleton of Takei (1997).
- The "Aspect ratio" parameter (0.0-1.0) describes the geometry/contiguity of the solid framework: 0.0 corresponds to layered melt, ~0.1 to grain-boundary melt, and 1.0 to melt trapped in isolated, separated pockets.
- The correction softens the solid bulk and shear moduli as a function of melt fraction, the solid/melt modulus contrast and the solid/melt density contrast, and reduces \$V_p\$ and \$V_s\$ accordingly.
- If \$\\phi_{melt} = 0\$, no melt correction is applied (\$V_{p,cor}=V_p\$, \$V_{s,cor}=V_s\$ before any anelastic/shallow correction).

#### Anelastic correction

- When "Anelastic correction" is set to *true*, an additional attenuation (anelastic) correction is applied to \$V_s\$ prior to the melt correction, following Behn et al. (2009) with frequency/grain-size terms from Cobden et al. (2018).
- The "Anelastic model" dropdown selects the water content of the mantle, which controls the strength of the attenuation:
    - **Dry mantle**: low water content, smallest reduction in \$V_s\$.
    - **Damp mantle**: intermediate water content.
    - **Wet mantle (saturated)**: highest water content, largest reduction in \$V_s\$.

#### Shallow correction

- When "Shallow correction" is set to *true*, an additional near-surface porosity correction is applied to \$V_s\$, using a fixed aspect ratio (0.25) and Poisson's ratio (0.25).
- The porosity fraction is estimated from pressure (depth), decreasing with depth, and is used to further reduce \$V_s\$ to account for the effect of shallow, fluid-filled porosity.

If "Seismic correction" is set to *false*, \$V_{p,cor}\$ and \$V_{s,cor}\$ are not computed (returned as `NaN`, displayed as 0 in the gridded maps).
"""


SlabGeotherms = raw"""
**Slab geotherms**

The "Slab geotherms" subtab (Phase diagram, Trace-element and 3D diagram tabs) overlays the pressure-temperature paths followed by a point of the downgoing slab, for one or several convergence velocities. In 2D the curves are only drawn on P-T diagrams. In the 3D P-T-X diagram a geotherm does not depend on X: it is drawn either as a translucent wall spanning the X axis, or as curves at chosen X values.

#### Thermal model

- Two plates are juxtaposed along the subduction interface $x = 0$: the upper plate of thickness $h$ on the $x > 0$ side and the subducting slab of thickness $d$ on the $x < 0$ side.
- Initially the interface is at the surface temperature $T_0$, and the temperature increases linearly to the mantle temperature $T_1$ at $x = h$ and $x = -d$.
- As the slab descends at the convergence velocity $v$, it is heated by conduction only. A point at distance $y$ along the slab has been subducting for $t = y / v$.

The temperature is

$$
\begin{aligned}
T(x,y) = T_1 &+ \frac{T_1 - T_0}{h}\left[\frac{x-h}{2}\left(\mathrm{erf}(-b) - \mathrm{erf}(-a)\right) - \sqrt{\frac{\kappa y}{\pi v}}\left(e^{-b^2} - e^{-a^2}\right)\right] \\
&+ \frac{T_1 - T_0}{d}\left[\frac{x+d}{2}\left(\mathrm{erf}(-c) - \mathrm{erf}(-a)\right) - \sqrt{\frac{\kappa y}{\pi v}}\left(e^{-c^2} - e^{-a^2}\right)\right]
\end{aligned}
$$

with

$$
a = \frac{x}{\sqrt{4 \kappa y / v}}, \qquad b = \frac{x-h}{\sqrt{4 \kappa y / v}}, \qquad c = \frac{x+d}{\sqrt{4 \kappa y / v}}
$$

#### Geometry and pressure

- "Depth into slab" $o$ selects the point followed: $o = 0$ is the slab top (the plate interface), $o = d$ is the base of the slab lithosphere. It is used as $x = -o$.
- For a slab dipping at angle $\delta$, a point at along-slab distance $y$ is at vertical depth $z = y \sin\delta + o \cos\delta$.
- Pressure is lithostatic: $P = \rho g z$, with $g = 9.81$ m/s$^2$.

#### Parameters (defaults)

| Parameter | Default |
|---|---|
| Velocities $v$ | 1, 2, 5, 10 cm/yr |
| Slab dip $\delta$ | 30° |
| Depth into slab $o$ | 0 km |
| Surface temperature $T_0$ | 0 °C |
| Mantle temperature $T_1$ | 1300 °C |
| Upper plate thickness $h$ | 20 km |
| Slab thickness $d$ | 80 km |
| Thermal diffusivity $\kappa$ | 1e-6 m$^2$/s |
| Density $\rho$ | 3300 kg/m$^3$ |

The last six are under "Advanced".

#### Notes

- Velocity and dip only enter through $y / v = (z - o\cos\delta) / (v \sin\delta)$: a steeper dip has the same effect as a faster convergence.
- The model is purely conductive with constant $\kappa$: no shear heating, no mantle-wedge corner flow, no radiogenic or latent heat.
- Each curve is labelled with its velocity and clipped to the diagram range. It is included in the 2D "Export SVG" and in all 3D exports: interactive HTML; PLY + STL (walls as surfaces, or tubes when rendered as lines); VTK, as a companion `<name>_geotherms.vtk` file of polylines in the same normalized cube as the grid, with T, P, X and velocity as point data.
"""


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

csvBulkRockFormat = """
**MAGEMinApp bulk-rock input in CSV format**

The CSV file should have columns for each oxide and relevant metadata. The table below shows an example of the expected format.

#### Column descriptions:

- **title**: Sample name or identifier
- **comments**: Any comments or notes
- **db**: Thermodynamic database acronym (see below)
- **sysUnit**: Unit system (e.g., `mol`, `wt`)
- **Oxide columns** (e.g., SiO2, Al2O3, ...): Content of each oxide in the specified unit
- **Additional columns** (e.g., SiO2_frac2): Optional. Columns ending with `_frac2` are used to specify a second bulk-rock composition for P-X, T-X, or PT-X diagrams. When provided, the value in a `_frac2` column will override the corresponding oxide value from the main composition for that specific diagram calculation. This allows you to easily define compositional variations between two endmembers in a single file.

#### Notes:

- The CSV file must have a header row with column names.
- Missing values can be left empty; they will be treated as zero.
- You can add or remove oxide columns as needed, but the header must match the data.
- If one oxide included in the thermodynamic database is not provided in the bulk-rock input file, the content of the oxide will automatically be set to 0.0.
- Either `FeO` and `O` or `FeO` and `Fe2O3` can be provided. In the first case FeO = FeOt.
- To provide two bulk-rock compositions for P-X or T-X diagrams, simply add `_frac2` columns as shown above.
- If you want to use a different thermodynamic database for the same bulk rock, copy and paste the line and change the database acronym.

#### Thermodynamic dataset acronyms:

| Acronym | Description |
|---|---|
| mtl | mantle (Holland et al., 2013) |
| mp | metapelite (White et al., 2014) |
| mpmn | metapelite + Mn, solution models calibrated against phase-equilibrium experiments (Riel et al., 2026, in progress) |
| mb | metabasite (Green et al., 2016) |
| ig | igneous (Green et al., 2025) |
| igad | igneous alkaline dry (Weller et al., 2024) |
| igaw | igneous alkaline wet (Holland et al., 2026, in progress) |
| um | ultramafic (Evans & Frost, 2021) |
| sb11 | Stixrude & Lithgow-Bertelloni (2011) |
| sb21 | Stixrude & Lithgow-Bertelloni (2021) |
| sb24 | Stixrude & Lithgow-Bertelloni (2024) |
| ume | ultramafic extended (Green et al., 2016 + Evans & Frost, 2021) |
| mpe | extended metapelite (White et al., 2014 + Green et al., 2016 + ...) |
| mbe | extended metabasite (Green et al., 2016 + Diener et al., 2007 + ...) |
| all | global TC dataset (all `tc`-family solution models combined) |

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

OxygenIsotopes = """
**Oxygen isotope fractionation (δ¹⁸O)**

When "δ18O model" is set to *true* (Setup → Oxygen isotopes), the δ¹⁸O of every stable phase is computed at each point of the phase diagram from the MAGEMin equilibrium (phases, compositions, end-member fractions, T). The calculation does not depend on the trace-element model. Results are displayed in the phase diagram tab ("Field" → δ18O, isopleths → δ18O, and the δ18O panel of the clicked point).

#### Fractionation factors

- Quartz-referenced fractionation factors of the internally consistent database DBOxygen 2.0.3 (Vho et al., 2019), 153 minerals and pure H₂O:

\$\$1000 \\ln \\alpha_{Qz-i} = A_i \\frac{10^6}{T^2} + B_i \\frac{10^3}{T} + C_i \\qquad (T \\text{ in K}, \\; C_i = 0)\$\$

- The fractionation between two phases follows by difference: \$\\Delta^{18}O_{i-j} = \\delta^{18}O_i - \\delta^{18}O_j \\approx 1000 \\ln \\alpha_{Qz-j} - 1000 \\ln \\alpha_{Qz-i}\$.
- DBOxygen is calibrated between 0 and 900 °C. Above the "1/T² above" temperature (default 900 °C) every fractionation is continued as \$1/T^2\$ from its value at that temperature, the high-temperature limit of isotope exchange theory. This avoids the overestimate obtained by extrapolating the \$B/T\$ term.
- The pressure effect is neglected (< 0.2 ‰ at 1 GPa, Vho et al., 2019).

#### Solid solutions

- Each MAGEMin end-member is mapped onto one or a combination of DBOxygen phases (e.g. py → pyrope, ann → annite, ordered end-members split between their end-members).
- The parameters of a solution phase are the oxygen-weighted mean of its end-member parameters (Vho et al., 2019, Eq. 7-11):

\$\$A_i = \\sum_k w_k A_k, \\qquad w_k = \\frac{X_k N_{O,k}}{\\sum_k X_k N_{O,k}}\$\$

with \$X_k\$ the end-member fraction and \$N_{O,k}\$ its number of oxygens (same for \$B\$ and \$C\$).

#### Melt

DBOxygen does not include melts. Three options are available:

- **CIPW norm (default)**: the melt is treated as the mixture of its CIPW normative minerals (Q, Or, Ab, An, Ne, Lc, Ac, Di/Hd, En/Fs, Fo/Fa, Wo, Mt, Hm, Il, Ru), each weighted by its share of the melt oxygen (normative-mineral approach, Bindeman, 2008). Dissolved H₂O is treated as water. This works for every melt model and stays consistent with the DBOxygen minerals.
- **Oxide index**: oxygen isotope index of the melt from its oxide composition, \$1000 \\ln \\alpha_{Qz-melt} = (1 - I_{melt}) \\, 11.83 \\cdot 10^6 / T^2\$ (Zhao & Zheng, 2003).
- **Melt end-members**: the end-members of the melt model are mapped onto normative minerals (q4L → quartz, abL → albite, ...).

#### Mass balance

Each phase is written as \$\\delta^{18}O_i = \\delta^{18}O_{Qz} - 1000 \\ln \\alpha_{Qz-i}\$, where \$\\delta^{18}O_{Qz}\$ is the value of a (virtual) quartz in equilibrium with the assemblage. Oxygen mass balance (Vho et al., 2019, Eq. 20),

\$\$\\delta^{18}O_{sys} = \\sum_i f_i \\, \\delta^{18}O_i, \\qquad f_i = \\frac{n_{O,i}}{\\sum_i n_{O,i}}\$\$

gives \$\\delta^{18}O_{Qz} = \\delta^{18}O_{sys} + \\sum_i f_i \\, 1000 \\ln \\alpha_{Qz-i}\$, with \$f_i\$ the fraction of the system oxygen held by phase \$i\$ (from the phase fractions and oxide compositions).

- **Bulk δ¹⁸O**: set below each bulk-rock composition. For diagrams with a compositional axis (X) the system δ¹⁸O is the oxygen-weighted mixture of bulk 1 and bulk 2.
- **Anchor phase**: when a phase is given, its δ¹⁸O is set to "Anchor δ18O" and the system value is calculated instead (e.g. from a measured garnet or zircon). Points where the anchor phase is not stable are undefined.

#### PTX paths

With "δ18O model" set to *true* in the PTX path tab (Oxygen isotopes), δ¹⁸O is followed along the path as an open system. The starting δ¹⁸O is set below the bulk-rock composition and the δ¹⁸O of the assimilant below the assimilant composition.

- At each step the stable assemblage is computed and δ¹⁸O is partitioned among the phases as above, using the current bulk δ¹⁸O.
- Material extracted at the step (fractional melting or crystallization, fluid, per-phase thresholds) leaves with its own δ¹⁸O (oxygen-weighted mean of the extracted melt, solids and fluid), and the δ¹⁸O of the material carried to the next step is updated by mass balance:

\$\$\\delta^{18}O_{ret} = \\frac{N_{O} \\, \\delta^{18}O_{sys} - N_{O,ext} \\, \\delta^{18}O_{ext}}{N_{O} - N_{O,ext}}\$\$

- Assimilation mixes the δ¹⁸O of the system and of the assimilant weighted by their oxygen.
- The δ18O results tab shows the evolution of the δ¹⁸O of phases, melt, fluid, solid, system and of the extracted material (per step and cumulative), the δ¹⁸O of the phases at a selected step, and exports the table as csv.
- Water added to reach saturation and activity buffers are assumed to carry the δ¹⁸O of the system.

#### Unmapped phases

Phases or end-members without a DBOxygen analogue (e.g. sapphirine, scapolite, carpholite, ferropericlase, CO₂ in fluids, aqueous species other than H₂O) are either excluded from the oxygen budget ("exclude", default) or given parameters from their oxide index ("oxide index", Zhao & Zheng, 2003). The excluded oxygen fraction and all warnings are reported in the δ18O panel of each point and in the exported tables.

#### Displayed fields

- δ¹⁸O of a phase, Δ¹⁸O between two phases (independent of the bulk δ¹⁸O, useful for thermometry), δ¹⁸O of the melt, fluid, solid, system and virtual quartz, and the oxygen fraction of a phase.
- Regions where the selected phase is absent are left blank.
- "Save all" / "Save point" (csv) also write a `_O18.csv` table with the δ¹⁸O of every phase.

#### References

- Vho, A., Lanari, P. & Rubatto, D. (2019). An internally-consistent database for oxygen isotope fractionation between minerals. *Journal of Petrology* 60, 2101-2129. doi:10.1093/petrology/egaa001
- Vho, A., Lanari, P., Rubatto, D. & Hermann, J. (2020). Tracing fluid transfers in subduction zones: an integrated thermodynamic and δ¹⁸O fractionation modelling approach. *Solid Earth* 11, 307-328. doi:10.5194/se-11-307-2020
- Zhao, Z.-F. & Zheng, Y.-F. (2003). Calculation of oxygen isotope fractionation in magmatic rocks. *Chemical Geology* 193, 59-80. doi:10.1016/S0009-2541(02)00226-7
- Bindeman, I. (2008). Oxygen isotopes in mantle and crustal magmas as revealed by single crystal analysis. *Reviews in Mineralogy and Geochemistry* 69, 445-478. doi:10.2138/rmg.2008.69.12
"""


RadiogenicIsotopes = """
**Radiogenic isotopes (Sr, Nd, Hf) along PTX paths**

With "Radiogenic isotopes" set to *true* in the PTX path tab (Setup → Radiogenic isotopes), the ⁸⁷Sr/⁸⁶Sr, ¹⁴³Nd/¹⁴⁴Nd and ¹⁷⁶Hf/¹⁷⁷Hf ratios of the system are followed along the path. They are meant for assimilation–fractional crystallization (AFC) diagnostics such as εNd vs ⁸⁷Sr/⁸⁶Sr, δ¹⁸O vs ⁸⁷Sr/⁸⁶Sr or ⁸⁷Sr/⁸⁶Sr vs 1/Sr.

Radiogenic ratios are not offered for phase diagrams: at fixed bulk composition and isotopic equilibrium every phase, including the melt at suprasolidus conditions, carries the bulk ratio, so a phase-diagram field would only reflect the input values (or a trivial two-component mixing along X).

#### Requirements

- The trace-element model must be on (TE predictive model = *true*), with a Kd database that contains the element: OL12 and CO include Sr, Nd and Hf; Yak25 includes Nd only. Otherwise the radiogenic switch is disabled, and systems missing from the Kd database are greyed out.
- The element concentrations of the starting composition and of the assimilant are those of the trace-element compositions.

#### Model

- **No mass-dependent fractionation**: at each step all phases (melt, solids, fluid) and the extracted material carry the ratio of the system. Fractional melting, fractional crystallization and extraction thresholds change the element concentrations but not the ratio.
- **Assimilation** is the only source term. With \$w\$ the mass fraction of assimilant added at the step (the same weight as for the trace-element bulk), \$C\$ the element concentration (ppm) and \$f_{ref}(R)\$ the atomic fraction of the reference isotope (⁸⁶Sr, ¹⁴⁴Nd, ¹⁷⁷Hf) at ratio \$R\$:

\$\$n_{sys} = (1 - w) \\, C_{sys} \\, f_{ref}(R_{sys}), \\qquad n_{ass} = w \\, C_{ass} \\, f_{ref}(R_{ass})\$\$

\$\$R_{new} = \\frac{n_{sys} R_{sys} + n_{ass} R_{ass}}{n_{sys} + n_{ass}}\$\$

- The mixing is weighted by the reference isotope, so it is exact rather than an elemental-concentration approximation. \$f_{ref}\$ is computed from the natural abundance ratios of the non-radiogenic isotopes (Berglund & Wieser, 2011).
- Without assimilation the ratios stay constant along the path.
- **ε notation**: \$\\varepsilon Nd = (R / 0.512630 - 1) \\cdot 10^4\$ and \$\\varepsilon Hf = (R / 0.282785 - 1) \\cdot 10^4\$ (CHUR, Bouvier et al., 2008).
- **Not modelled**: radioactive decay and ingrowth (no time axis), disequilibrium assimilation, recharge, Pb isotopes.

#### Inputs

- Setup → Radiogenic isotopes: on/off and the systems to follow (⁸⁷Sr/⁸⁶Sr, ¹⁴³Nd/¹⁴⁴Nd, ¹⁷⁶Hf/¹⁷⁷Hf).
- The initial ratio of each selected system is set below the bulk-rock composition, and the assimilant ratio below the assimilant composition (visible when assimilation is on).

#### Results

The "Radiogenic isotopes" results tab plots any of the following against any other: ratios, ε values, melt and bulk concentrations, 1/C of the melt, δ¹⁸O of the melt and system (when the δ18O model is on), path step and temperature. The default x–y diagram is εNd vs ⁸⁷Sr/⁸⁶Sr (δ¹⁸O vs ⁸⁷Sr/⁸⁶Sr when Nd is not followed and δ18O is on). The table of all quantities at every step can be saved as csv.

#### References

- Berglund, M. & Wieser, M. E. (2011). Isotopic compositions of the elements 2009 (IUPAC Technical Report). *Pure and Applied Chemistry* 83, 397-410. doi:10.1351/PAC-REP-10-06-02
- Bouvier, A., Vervoort, J. D. & Patchett, P. J. (2008). The Lu-Hf and Sm-Nd isotopic composition of CHUR. *Earth and Planetary Science Letters* 273, 48-57. doi:10.1016/j.epsl.2008.06.010
- Langmuir, C. H., Vocke, R. D., Hanson, G. N. & Hart, S. R. (1978). A general mixing equation with applications to Icelandic basalts. *Earth and Planetary Science Letters* 37, 380-392. doi:10.1016/0012-821X(78)90053-5
- DePaolo, D. J. (1981). Trace element and isotopic effects of combined wallrock assimilation and fractional crystallization. *Earth and Planetary Science Letters* 53, 189-202. doi:10.1016/0012-821X(81)90153-9
- Taylor, H. P. (1980). The effects of assimilation of country rocks by magmas on ¹⁸O/¹⁶O and ⁸⁷Sr/⁸⁶Sr systematics in igneous rocks. *Earth and Planetary Science Letters* 47, 243-254. doi:10.1016/0012-821X(80)90040-0
"""

function Tab_General_informations()
    html_div([
        html_div("‎ "),
        dbc_tabs([
            dbc_tab(label="Phases", children=[
                html_div([
                html_h1("Solution phase information", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                dash_datatable(
                    id="table-solution-phases",
                    columns=(  [    Dict("id" =>  "ss",         "name" =>  "solution name",     "editable" => false),
                                    Dict("id" =>  "ss_abrev",   "name" =>  "abbreviation",      "editable" => false),
                                    Dict("id" =>  "warr",       "name" =>  "Warr (2021)",        "editable" => false),
                                    Dict("id" =>  "solvus",     "name" =>  "solvus",            "editable" => false)
                                ]
                    ),
                    data        =   [Dict(  "ss"         => (n = AppData.dict_ss[i][1]; isempty(n) ? "-" : n),
                                            "ss_abrev"   => i,
                                            "warr"       => (w = MAGEMin_C.get_Warr_name(i); endswith(w, "*") ? "-" : w),
                                            "solvus"     => (f = AppData.dict_ss[i][2][1];
                                                             f == [i] ? "-" :
                                                             join(map((x, y) -> "$x, $y", AppData.dict_ss[i][2][2], f), "; ")) )
                                                for i in sort(collect(keys(AppData.dict_ss))) ],

                    style_cell  = (textAlign="center", fontSize="120%",),
                    style_header= (fontWeight="bold",),
                    editable    = false,
                    page_size   = 16,
                    filter_action="native"
                ),
                html_div("‎ "),
                html_h1("End-members information", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                dash_datatable(
                    id="table-endmember-phases",
                    columns=(  [    Dict("id" =>  "em",         "name" =>  "end-member name",   "editable" => false),
                                    Dict("id" =>  "em_abrev",   "name" =>  "abbreviation",      "editable" => false),
                                    Dict("id" =>  "warr",       "name" =>  "Warr (2021)",        "editable" => false),
                                    Dict("id" =>  "compo",      "name" =>  join(vcat(AppData.dict_em["_header_"][3]...),", "),       "editable" => false)
                                ]
                    ),
                    data        =   [Dict(  "em"         => AppData.dict_em[i][2],
                                            "em_abrev"   => i,
                                            "warr"       => (w = MAGEMin_C.get_Warr_name(i); endswith(w, "*") ? "-" : w),
                                            "compo"      => join(vcat(AppData.dict_em[i][3]...),", ") )
                                                for i in sort(collect(keys(AppData.dict_em))) if !startswith(i, "_")],

                    style_cell  = (textAlign="center", fontSize="120%",),
                    style_header= (fontWeight="bold",),
                    editable    = false,
                    page_size   = 16,
                    filter_action="native"
                ),
                ], style = Dict("padding" => "12px")),
            ]),
            dbc_tab(label="Bulk-rock CSV format", children=[
                html_div([
                html_h1("CSV bulk-rock input format — example", style = Dict("textAlign" => "center","font-size" => "130%", "marginTop" => 4)),
                dash_datatable(
                    id          = "table-csv-bulk-format",
                    columns     = [ Dict("id" => c, "name" => c, "editable" => false)
                                    for c in ["title","comments","db","sysUnit","SiO2","Al2O3","CaO","MgO","FeO","Fe2O3","K2O","Na2O","TiO2","O","MnO","H2O","SiO2_frac2"] ],
                    data        = [
                        Dict("title"=>"Basalt_Xu08",  "comments"=>"bulk test", "db"=>"sb21", "sysUnit"=>"mol",
                             "SiO2"=>0.5175, "Al2O3"=>0.1019, "CaO"=>0.1388, "MgO"=>0.1494, "FeO"=>0.0706, "Fe2O3"=>0.0218,
                             "K2O"=>"", "Na2O"=>"", "TiO2"=>"", "O"=>"", "MnO"=>"", "H2O"=>"", "SiO2_frac2"=>55),
                        Dict("title"=>"Basalt_Xu08l", "comments"=>"testy",     "db"=>"sb21", "sysUnit"=>"mol",
                             "SiO2"=>0.5175, "Al2O3"=>0.1019, "CaO"=>0.1388, "MgO"=>0.1494, "FeO"=>0.0706, "Fe2O3"=>0.0218,
                             "K2O"=>"", "Na2O"=>"", "TiO2"=>"", "O"=>"", "MnO"=>"", "H2O"=>"", "SiO2_frac2"=>55),
                        Dict("title"=>"title1",       "comments"=>"comment,2l", "db"=>"um",   "sysUnit"=>"wt",
                             "SiO2"=>35.66, "Al2O3"=>6.51, "CaO"=>5.12, "MgO"=>26.62, "FeO"=>14.56, "Fe2O3"=>0.08,
                             "K2O"=>0.04, "Na2O"=>3.78, "TiO2"=>0.52, "O"=>"", "MnO"=>0.47, "H2O"=>"", "SiO2_frac2"=>32),
                        Dict("title"=>"Renato_2",     "comments"=>"test2",     "db"=>"mb",   "sysUnit"=>"wt",
                             "SiO2"=>50.91, "Al2O3"=>10.1, "CaO"=>11.56, "MgO"=>13.89, "FeO"=>11.02, "Fe2O3"=>0.09,
                             "K2O"=>1.4, "Na2O"=>0.77, "TiO2"=>0.06, "O"=>0.19, "MnO"=>0, "H2O"=>"", "SiO2_frac2"=>45),
                    ],
                    style_cell  = Dict("textAlign" => "center", "fontSize" => "110%", "userSelect" => "text"),
                    style_header= (fontWeight="bold",),
                    style_data_conditional = [
                        Dict("if" => Dict("column_id" => "title"),    "fontWeight" => "bold"),
                        Dict("if" => Dict("column_id" => "SiO2_frac2"), "backgroundColor" => "#f0f4ff"),
                    ],
                    style_table = Dict("overflowX" => "auto"),
                    editable    = false,
                    page_size   = 10,
                ),
                html_div("\u200E "),
                dbc_card([
                    dcc_markdown(csvBulkRockFormat; mathjax=true, style = Dict("font-size" => "130%")),
                ]),
                ], style = Dict("padding" => "12px")),
            ]),
            dbc_tab(label="Trace-element Kd", children=[
                html_div([
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
                            style_table = Dict("overflowX" => "auto"),
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
                            style_table = Dict("overflowX" => "auto"),
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
                            style_table = Dict("overflowX" => "auto"),
                            editable    = false,
                            page_size   = 32,
                            filter_action="native"
                        ),
                    ]),
                ]),

            ]),
                ], style = Dict("padding" => "12px")),
            ]),
            dbc_tab(label="Calculation details", children=[
                html_div([
                    dbc_card([
                        dcc_markdown(phase_deactivation; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(activity; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(water_saturation; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(heatCapacity; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                    html_div("‎ "),
                    dbc_card([
                        dcc_markdown(SiteFractionCalculator; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                ], style = Dict("padding" => "12px", "maxWidth" => "1100px", "margin" => "auto")),
            ]),
            dbc_tab(label="Seismic velocities", children=[
                html_div([
                    dbc_card([
                        dcc_markdown(SeismicVelocityMeltCorrection; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                ], style = Dict("padding" => "12px", "maxWidth" => "1100px", "margin" => "auto")),
            ]),
            (ENABLE_O18 ? [dbc_tab(label="δ18O", children=[
                html_div([
                    dbc_card([
                        dcc_markdown(OxygenIsotopes; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                ], style = Dict("padding" => "12px", "maxWidth" => "1100px", "margin" => "auto")),
            ])] : [])...,
            # dbc_tab(label="Radiogenic isotopes", children=[
            #     html_div([
            #         dbc_card([
            #             dcc_markdown(RadiogenicIsotopes; mathjax=true, style = Dict("font-size" => "130%")),
            #         ], style = Dict("overflowX" => "auto")),
            #     ], style = Dict("padding" => "12px", "maxWidth" => "1100px", "margin" => "auto")),
            # ]),
            dbc_tab(label="Slab geotherms", children=[
                html_div([
                    dbc_card([
                        dcc_markdown(SlabGeotherms; mathjax=true, style = Dict("font-size" => "130%")),
                    ], style = Dict("overflowX" => "auto")),
                ], style = Dict("padding" => "12px", "maxWidth" => "1100px", "margin" => "auto")),
            ]),
        ]),
    ])

end
