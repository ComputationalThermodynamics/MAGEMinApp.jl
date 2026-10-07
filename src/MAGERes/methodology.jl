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

const MAGERES_METHODOLOGY_MD = raw"""
### Overview

The MAGEMin Reservoir (MAGERes) model follows a two-dimensional (plane-strain) section of crust in which a magma chamber grows by
periodic injection of sills, cools by conduction and parameterised convection, crystallises, exchanges melt with its wall
rock, accumulates crystals as cumulates and loses magma by eruption. Phase equilibria and thermodynamic properties are
computed with MAGEMin (Riel et al., 2022) using the igneous database (Holland et al., 2018), which is built on the
internally consistent dataset of Holland & Powell (2011). The energy-constrained, open-system approach follows the
philosophy of the Magma Chamber Simulator (Bohrson et al., 2014), here on a spatially resolved grid.

### 1. Domain and mesh

- The domain is a fixed (Eulerian) box extending from the surface to the domain bottom depth. The chamber is centred
  and horizontal, so the section is symmetric about the vertical axis through the chamber centre: only the left half is
  computed (no-flux symmetry boundary on the axis) and mirrored for display. Reported areas and volumes refer to the
  full section.
- The mesh is a quadtree: base cells of the coarsest size are refined down to the finest size towards the chamber
  boundary and towards the internal material boundaries (host, mush, mobile body, cumulate, partially molten host); a
  cell is refined while its size exceeds finest size + grading × distance to the nearest boundary, with at most one
  level of difference between neighbours. The mesh is rebuilt at every event (injection, eruption, chamber growth by
  percolation) and whenever a material boundary moves into a cell coarser than the finest size.
- Each cell carries extensive contents: heat content E, heat capacity C, enthalpy H and the number of moles of every
  oxide. The temperature is T = E / C.

### 2. Chamber geometry and kinematics

- The chamber is an ellipse (or parabola) described by fixed stations along its axis. Each injection opens it by the
  area of an elliptical lens (chamber length × injected lens thickness), shared between roof uplift and floor
  subsidence according to the opening mode.
- The surrounding host rock is displaced exactly by column shear; material leaving or entering the box through its top
  and bottom is accounted for as outflow and inflow.
- Injections (and melt percolating from the wall rock) are emplaced as a sill at the centre plane of the chamber: the
  chamber contents above that plane are lifted rigidly with the roof and those below it are lowered rigidly with the
  floor, and the opened lens is filled with the new material. Eruptions close the chamber by the erupted volume, with
  the interior compressed uniformly.
- At every event the cell contents are transferred by a conservative geometric remap: each new cell is mapped back
  through the analytic inverse of the deformation and clipped against the old mesh (Sutherland & Hodgman, 1974), so that
  mass, energy and enthalpy are conserved to round-off.

### 3. Heat transport

- Conduction is solved implicitly (backward Euler) with a cell-centred finite-volume scheme, two-point fluxes and
  harmonic-mean conductivities across faces.
- Cell conductivity is the magma and host conductivities weighted by the magma fraction of the cell, multiplied by the
  Nusselt number inside the mobile body (Section 6).
- Boundary conditions: fixed surface temperature at the top, constant basal heat flux (host conductivity × geothermal
  gradient) at the bottom, no flux across the sides. The initial temperature is the linear geotherm.

### 4. Thermodynamics (MAGEMin coupling)

- Pressure is lithostatic, P = ρ_host · g · depth.
- The host rock is initialised from MAGEMin calculations along the geotherm, and the injected magma from a calculation at
  the injection temperature and the pressure of the chamber centre.
- A cell is re-equilibrated when its temperature has changed by more than the ΔT tolerance since its last calculation,
  or its specific enthalpy by more than 3 kJ/kg/K × ΔT tolerance (above the sub-solidus temperature, or while it still
  contains melt), or when its composition has changed by more than the ΔX tolerance. The enthalpy criterion keeps cells
  crossing sharp (near-eutectic) phase transitions, where the apparent heat capacity is very large, from overshooting.
  All cells requiring an update during a timestep are computed in a single batched multi-point minimisation. In Boost
  mode (on by default) each host-rock calculation at least one cell away from the chamber starts from the previous
  solutions of the cell and of its host-rock neighbours, unless its composition has changed significantly. Chamber cells, whose composition changes by
  injection, settling and percolation, are always computed without an initial guess.
- The heat capacity used by the conduction solver is the apparent heat capacity returned by MAGEMin, which includes the
  latent heat of reaction, limited to 3 kJ/kg/K. After each calculation the cell temperature is corrected so that its
  enthalpy content matches the MAGEMin enthalpy of its current composition: T ← T + (H/m − h) / c_p. Latent heat that
  the limited heat capacity does not release during a timestep is therefore returned through this correction, which
  keeps cells at their crystallisation temperature across sharp phase transitions.
- The enthalpy of each stable phase (melt, solids, fluid) is taken from MAGEMin, H_i = G_i − T ∂G_i/∂T at fixed phase
  composition, with the full solution model including mixing terms. Any material moved between cells (melt,
  crystals, fluid) therefore carries its own enthalpy at its source temperature.
- When the fluid treatment is "removed", exsolved fluid leaves the system together with its enthalpy.

### 5. Injection and mixing

- Magma is supplied as periodic lenses at the centre of the chamber. The default (a 20 m lens every 500 years, i.e. a
  vertical accretion rate of 4 cm/yr) lies in the range where incrementally emplaced sills can build an eruptible
  reservoir over 10⁴–10⁵ years, rather than the much slower rates of long-term pluton growth (Annen et al., 2006;
  Annen, 2009).
- New magma, with the injection composition and temperature, fills the opened sill. Optionally only the melt is
  injected: the injection bulk is equilibrated at the chamber-centre pressure and the injection temperature, and its
  melt composition is used instead of the bulk. With the injection target "in
  place" the sill stays where it is emplaced; it joins the mobile body only if it is connected to it. With "mobile body"
  (default) the sill content that lands outside an existing mobile body is exchanged, at constant volume, for the same
  volume of mobile-body magma, so that the injected magma feeds the body directly; without a mobile body the sill stays
  in place. Cells receiving magma are brought to thermodynamic equilibrium at constant enthalpy (Newton iterations on
  temperature).
- The mobile body is then homogenised: its composition and enthalpy are pooled, and the common temperature is obtained by
  solving h(T, X) = H / m with MAGEMin.
- Mush and cumulate reheated by the injection give their extra melt back to the mobile body over the compaction
  timescale (Section 7), not instantaneously.

### 6. Mobile body and parameterised convection

- The mobile body is the largest connected region of chamber cells (at least half inside the chamber outline) whose melt
  fraction, melt / (melt + solids) by volume, exceeds the lock-up melt fraction φ_lock (Marsh, 1981; Lejeune & Richet,
  1995). Partially molten host rock is never part of it: its melt joins the chamber by percolation. Smaller isolated melt-rich
  pockets (for example a fresh sill emplaced below the cumulate pile) are not part of it: they do not convect, mix or
  settle, and crystallise in place or drain by percolation.
- Convection is represented by an effective conductivity k · Nu inside the body, with Nu = (Ra / Ra_crit)^β for
  Ra > Ra_crit and Nu = 1 otherwise, and Ra = ρ g α ΔT L³ / (κ η) (Turcotte & Schubert, 2014).
- ΔT and L are the temperature range and vertical extent of the body, α is the thermal expansivity of the melt,
  κ = k / (ρ c_p), and η is the bulk viscosity: the melt viscosity (Giordano et al., 2008, as computed by MAGEMin)
  corrected for crystals with the Einstein–Roscoe relation η = η_melt · (1 − φ_x / (1 − φ_lock))^−2.5 (Roscoe, 1952),
  φ_x being the crystal fraction.

### 7. Melt percolation and compaction

- Cells outside the mobile body that hold more melt than the percolation threshold φ_perc (melt connectivity threshold;
  Rosenberg & Handy, 2005) and are connected to the body through partially molten cells lose melt to it by
  buoyancy-driven porous flow through the crystal framework (McKenzie, 1984). Melt can cross drained restite near the
  threshold, because texturally equilibrated partially molten rock has no connectivity threshold (Cheadle et al., 2004). The Darcy flux is q = k Δρ g / η_melt with the permeability
  k = d² φ³ / 270 (Wark & Watson, 1998), d being the crystal size, φ the melt fraction, Δρ the solid–melt density
  contrast and η_melt the melt viscosity.
- Below the mobile body (mush and cumulate pile), compaction is resolved column by column at the finest grid spacing:
  across every horizontal face, melt rises from the lower cell at the Darcy rate q(φ_lower) Δt and the same volume of
  crystals moves down from the upper cell, so cell volumes, mass and enthalpy are conserved exactly. The top cell of the
  pile gives its melt to the mobile body. The base of the pile rests on the chamber floor and only loses melt, so
  compaction proceeds from the bottom up: the compacted cumulate forms at the base and a compaction front rises
  through the pile, while young cumulate on top stays melt-rich (cumulate mush). A column drains on the timescale
  φ L / q, L being its thickness (hundreds of years for 10 mm crystals and fresh mush, 10⁴–10⁵ years for millimetre
  grains; Bachmann & Bergantz, 2004).
- Elsewhere (roof and side mush, partially molten host rock) a cell loses the melt fraction min(φ − φ_perc, q Δt / L)
  per timestep, L being the thickness of the connected partially molten column it belongs to.
- Melt extracted from mush inside the chamber is added to the mobile body without changing the chamber size. Melt
  extracted from the host rock outside the chamber enlarges the chamber by its volume.

### 8. Crystal settling and cumulates

- Crystals settle in the mobile body at the hindered Stokes velocity v = 2 Δρ g r² / (9 η_melt) · (1 − φ_x)^n
  (Richardson & Zaki, 1954, reprinted 1997). In a convecting body the fraction of crystals deposited during a timestep
  is 1 − exp(−v Δt / H) (Martin & Nokes, 1988, 1989), H being the height of the body in the column.
- Settling crystals accumulate at the base of the mobile body, where the convective velocity vanishes and the deposition
  flux per unit floor area is uniform (Martin & Nokes, 1989): in each column they exchange their volume with melt from
  the lowest body cell, or from the next one up once that cell has reached the lock-up melt fraction. Crystals that
  find no room stay in suspension, except where the body is a single cell thick, where they go into the cell beneath
  it. Freshly deposited
  cumulates hold 40–60 % melt (Shirley, 1986; Tegner et al., 2009), so a cell joins the pile at φ_lock and is then
  drained towards φ_perc by melt percolation (Section 7), in line with the low trapped-liquid fractions of layered
  intrusions (Tegner et al., 2009). Columns are traced at the finest grid spacing, so a coarse body cell spreads its crystals over all
  the columns below it. A cell that has received settled crystals becomes cumulate once it leaves the mobile body, so
  the top of the pile is the floor of the mobile body and rises uniformly as crystals accumulate.
- The surface of the pile cannot be steeper than one cell per column (angle of repose): where the floor of the mobile
  body is two or more cells higher in one finest-grid column than in its neighbour, the top cumulate cell of the higher
  column exchanges its content with the lowest body cell of the lower one. The exchange is between cells of equal size,
  so mass, enthalpy and volume are conserved exactly.
- The cumulate is tracked as a volume fraction that is remapped through the same area overlaps as the conserved
  quantities, ignoring newly injected magma; a cell counts as cumulate when this fraction is at least 0.5. The cumulate
  boundary therefore follows the actual displacement of the material and not whole-cell jumps.

### 9. Eruption

- An eruption is triggered when the mean melt fraction of the mobile body exceeds the eruptible melt fraction φ_erupt and
  the chamber has been recharged since the previous eruption.
- Each eruption removes a fraction (erupted fraction per event) of the mobile-body volume, in the 10–30 % range of
  caldera-forming eruptions (Druitt & Sparks, 1984). Each body cell gives the same fraction f of its melt and fluid and
  the fraction f · χ of its crystals, χ being the erupted crystal fraction (0: crystal-poor melt, 1: bulk magma with all
  its suspended crystals); f is set so that the erupted volume matches the target. The chamber closes by the erupted
  volume.

- Optional overpressure trigger (Jellinek & DePaolo, 2003; Degruyter & Huber, 2014). The melt fraction then only sets
  whether the body can erupt. The chamber overpressure is driven by:
  - recharge, spread over the injection period by default;
  - percolated melt;
  - crystallisation, melting and fluid exsolution in the magma. Exsolved fluid pressurises the chamber before it is
    removed.

  It acts against the compressibility of the magma (from the MAGEMin bulk moduli) and the wall rock (1/μ), and relaxes
  by viscous creep of the wall rock. Its effective viscosity is the Arrhenius viscosity averaged over a shell around the
  chamber, weighted toward the contact as for a viscous shell around a cylindrical cavity. The chamber erupts when the overpressure exceeds the critical value and the body is eruptible, releasing it;
  otherwise the overpressure is capped there (the wall fails without an eruption). A chamber in warm crust relaxes in
  years and can keep growing without erupting.

### 10. Trace elements and zircon

- With trace elements on, every cell carries the mass of each element of the KD model (as in the PTX path tab). At each
  MAGEMin point, `TE_prediction` gives the solid/melt concentration ratio of every element, and the melt and crystals
  that move apart (settling, compaction, percolation, eruption) take their own concentrations. Fluids carry none.
- With a Zr saturation model (Watson & Harrison, 1983; Boehnke et al., 2013; Crisp & Berry, 2022), zircon nucleates in
  supersaturated melt, then grows or dissolves at the rate set by Zr diffusion through the melt boundary layer around
  the grains (Zhang & Xu, 2016, Eqs. 9 and 14–18; Kerr, 1995). The melt Zr relaxes exponentially toward saturation
  over each step, so Zr is conserved exactly. The saturation follows the cell temperature between minimisations.
- Zircon mass is stored by crystallisation-age bin in separate families: inherited host-rock zircon and the grains
  nucleated in successive epochs. Each family keeps its own grain size and zoning through mixing. Growth fills the
  current bin; dissolution removes the youngest zircon first (rims before cores). Zircon moves with the crystals.
- Each eruption records the zircon it carries. Synthetic analyses carry the analytical uncertainty of the chosen
  method (SIMS U-Th, LA-ICP-MS or CA-ID-TIMS U-Pb). For the eruptions of the selected output, the Eruption → Zircon
  ages tab shows:
  - a rank-order plot of single-spot ages with 2σ error bars, the weighted mean and its MSWD;
  - core-to-rim analyses of zoned grains, coloured by the number of spots per grain;
  - the age histogram (bins 2σ) with its kernel density;
  - one representative zoned grain per family.
- The Trace elements tab shows the erupted REE or all trace elements, normalised to chondrite or to the injected
  magma.

### 11. Conservation and diagnostics

- Energy, enthalpy, the moles of every oxide and, when enabled, the mass of every trace element (Zr in zircon
  included) are tracked through all fluxes and events, together with the area budgets (host rock + outflow = initial
  host; injected + percolated = chamber + erupted). All balances close to round-off; they are shown in the Diagnostics
  tab.

### Limitations

- Two-dimensional plane-strain geometry; lithostatic pressure computed with a constant host density.
- Drained cells keep their area (no compaction); cells straddling the chamber boundary hold a single temperature and a
  mixed magma–host composition.

### References

- Annen, C. (2009). From plutons to magma chambers: thermal constraints on the accumulation of eruptible silicic
  magma in the upper crust. *Earth and Planetary Science Letters*, 284, 409–416.
  [doi:10.1016/j.epsl.2009.05.006](https://doi.org/10.1016/j.epsl.2009.05.006)
- Annen, C., Blundy, J. D., & Sparks, R. S. J. (2006). The genesis of intermediate and silicic magmas in deep crustal
  hot zones. *Journal of Petrology*, 47, 505–539. [doi:10.1093/petrology/egi084](https://doi.org/10.1093/petrology/egi084)
- Bachmann, O., & Bergantz, G. W. (2004). On the origin of crystal-poor rhyolites: extracted from batholithic crystal
  mushes. *Journal of Petrology*, 45, 1565–1582. [doi:10.1093/petrology/egh019](https://doi.org/10.1093/petrology/egh019)
- Boehnke, P., Watson, E. B., Trail, D., Harrison, T. M., & Schmitt, A. K. (2013). Zircon saturation re-visited.
  *Chemical Geology*, 351, 324–334. [doi:10.1016/j.chemgeo.2013.05.028](https://doi.org/10.1016/j.chemgeo.2013.05.028)
- Bohrson, W. A., Spera, F. J., Ghiorso, M. S., Brown, G. A., Creamer, J. B., & Mayfield, A. (2014). Thermodynamic model
  for energy-constrained open-system evolution of crustal magma bodies undergoing simultaneous recharge, assimilation
  and crystallization: the Magma Chamber Simulator. *Journal of Petrology*, 55, 1685–1717.
  [doi:10.1093/petrology/egu036](https://doi.org/10.1093/petrology/egu036)
- Cheadle, M. J., Elliott, M. T., & McKenzie, D. (2004). Percolation threshold and permeability of crystallizing
  igneous rocks: the importance of textural equilibrium. *Geology*, 32, 757–760.
  [doi:10.1130/G20495.1](https://doi.org/10.1130/G20495.1)
- Crisp, L. J., & Berry, A. J. (2022). A new model for zircon saturation in silicate melts. *Contributions to
  Mineralogy and Petrology*, 177. [doi:10.1007/s00410-022-01925-6](https://doi.org/10.1007/s00410-022-01925-6)
- Degruyter, W., & Huber, C. (2014). A model for eruption frequency of upper crustal silicic magma chambers. *Earth
  and Planetary Science Letters*, 403, 117–130. [doi:10.1016/j.epsl.2014.06.047](https://doi.org/10.1016/j.epsl.2014.06.047)
- Druitt, T. H., & Sparks, R. S. J. (1984). On the formation of calderas during ignimbrite eruptions. *Nature*, 310,
  679–681. [doi:10.1038/310679a0](https://doi.org/10.1038/310679a0)
- Giordano, D., Russell, J. K., & Dingwell, D. B. (2008). Viscosity of magmatic liquids: a model. *Earth and Planetary
  Science Letters*, 271, 123–134. [doi:10.1016/j.epsl.2008.03.038](https://doi.org/10.1016/j.epsl.2008.03.038)
- Holland, T. J. B., & Powell, R. (2011). An improved and extended internally consistent thermodynamic dataset for phases
  of petrological interest, involving a new equation of state for solids. *Journal of Metamorphic Geology*, 29,
  333–383. [doi:10.1111/j.1525-1314.2010.00923.x](https://doi.org/10.1111/j.1525-1314.2010.00923.x)
- Holland, T. J. B., Green, E. C. R., & Powell, R. (2018). Melting of peridotites through to granites: a simple
  thermodynamic model in the system KNCFMASHTOCr. *Journal of Petrology*, 59, 881–900.
  [doi:10.1093/petrology/egy048](https://doi.org/10.1093/petrology/egy048)
- Jellinek, A. M., & DePaolo, D. J. (2003). A model for the origin of large silicic magma chambers: precursors of
  caldera-forming eruptions. *Bulletin of Volcanology*, 65, 363–381.
  [doi:10.1007/s00445-003-0277-y](https://doi.org/10.1007/s00445-003-0277-y)
- Kerr, R. C. (1995). Convective crystal dissolution. *Contributions to Mineralogy and Petrology*, 121, 237–246.
  [doi:10.1007/BF02688239](https://doi.org/10.1007/BF02688239)
- Lejeune, A.-M., & Richet, P. (1995). Rheology of crystal-bearing silicate melts: an experimental study at high
  viscosities. *Journal of Geophysical Research: Solid Earth*, 100, 4215–4229.
  [doi:10.1029/94JB02985](https://doi.org/10.1029/94JB02985)
- Marsh, B. D. (1981). On the crystallinity, probability of occurrence, and rheology of lava and magma. *Contributions to
  Mineralogy and Petrology*, 78, 85–98. [doi:10.1007/BF00371146](https://doi.org/10.1007/BF00371146)
- Martin, D., & Nokes, R. (1988). Crystal settling in a vigorously convecting magma chamber. *Nature*, 332, 534–536.
  [doi:10.1038/332534a0](https://doi.org/10.1038/332534a0)
- Martin, D., & Nokes, R. (1989). A fluid-dynamical study of crystal settling in convecting magmas. *Journal of
  Petrology*, 30, 1471–1500. [doi:10.1093/petrology/30.6.1471](https://doi.org/10.1093/petrology/30.6.1471)
- McKenzie, D. (1984). The generation and compaction of partially molten rock. *Journal of Petrology*, 25, 713–765.
  [doi:10.1093/petrology/25.3.713](https://doi.org/10.1093/petrology/25.3.713)
- Richardson, J. F., & Zaki, W. N. (1954). Sedimentation and fluidisation: Part I. *Transactions of the Institution of
  Chemical Engineers*, 32, 35–53. Reprinted (1997) in *Chemical Engineering Research and Design*, 75, S82–S100.
  [doi:10.1016/S0263-8762(97)80006-8](https://doi.org/10.1016/S0263-8762(97)80006-8)
- Riel, N., Kaus, B. J. P., Green, E. C. R., & Berlie, N. (2022). MAGEMin, an efficient Gibbs energy minimizer:
  application to igneous systems. *Geochemistry, Geophysics, Geosystems*, 23, e2022GC010427.
  [doi:10.1029/2022GC010427](https://doi.org/10.1029/2022GC010427)
- Roscoe, R. (1952). The viscosity of suspensions of rigid spheres. *British Journal of Applied Physics*, 3, 267–269.
  [doi:10.1088/0508-3443/3/8/306](https://doi.org/10.1088/0508-3443/3/8/306)
- Rosenberg, C. L., & Handy, M. R. (2005). Experimental deformation of partially melted granite revisited: implications
  for the continental crust. *Journal of Metamorphic Geology*, 23, 19–28.
  [doi:10.1111/j.1525-1314.2005.00555.x](https://doi.org/10.1111/j.1525-1314.2005.00555.x)
- Shirley, D. N. (1986). Compaction of igneous cumulates. *The Journal of Geology*, 94, 795–809.
  [doi:10.1086/629088](https://doi.org/10.1086/629088)
- Sutherland, I. E., & Hodgman, G. W. (1974). Reentrant polygon clipping. *Communications of the ACM*, 17, 32–42.
  [doi:10.1145/360767.360802](https://doi.org/10.1145/360767.360802)
- Tegner, C., Thy, P., Holness, M. B., Jakobsen, J. K., & Lesher, C. E. (2009). Differentiation and compaction in the
  Skaergaard intrusion. *Journal of Petrology*, 50, 813–840.
  [doi:10.1093/petrology/egp020](https://doi.org/10.1093/petrology/egp020)
- Turcotte, D. L., & Schubert, G. (2014). *Geodynamics* (3rd ed.). Cambridge University Press.
  [doi:10.1017/CBO9780511843877](https://doi.org/10.1017/CBO9780511843877)
- Wark, D. A., & Watson, E. B. (1998). Grain-scale permeabilities of texturally equilibrated, monomineralic rocks.
  *Earth and Planetary Science Letters*, 164, 591–605.
  [doi:10.1016/S0012-821X(98)00252-0](https://doi.org/10.1016/S0012-821X(98)00252-0)
- Watson, E. B., & Harrison, T. M. (1983). Zircon saturation revisited: temperature and composition effects in a
  variety of crustal magma types. *Earth and Planetary Science Letters*, 64, 295–304.
  [doi:10.1016/0012-821X(83)90211-X](https://doi.org/10.1016/0012-821X(83)90211-X)
- Zhang, Y., & Xu, Z. (2016). Zircon saturation and Zr diffusion in rhyolitic melts, and zircon growth
  geospeedometer. *American Mineralogist*, 101, 1252–1267. [doi:10.2138/am-2016-5462](https://doi.org/10.2138/am-2016-5462)
"""
