# MAGERes — MAGEMin Reservoir: methodology

MAGERes simulates how a crustal magma reservoir grows, cools, crystallises, separates crystals from melt and erupts.
New magma arrives as repeated sills. Phase equilibria, densities, heat capacities and latent heat come from MAGEMin.
This document explains every part of the model in plain language and gives the equations exactly as they are
implemented. File names in brackets (e.g. *thermal.jl*) point to the source files in this folder.

---

## Contents

1. [Overview](#1-overview)
2. [Notation](#2-notation)
3. [Domain, coordinates and symmetry](#3-domain-coordinates-and-symmetry)
4. [The adaptive quadtree grid](#4-the-adaptive-quadtree-grid)
5. [What each cell stores](#5-what-each-cell-stores)
6. [Initial state](#6-initial-state)
7. [Chamber geometry](#7-chamber-geometry)
8. [Kinematics: how material moves at an event](#8-kinematics-how-material-moves-at-an-event)
9. [The conservative remap](#9-the-conservative-remap)
10. [Heat conduction](#10-heat-conduction)
11. [Thermodynamics with MAGEMin](#11-thermodynamics-with-magemin)
12. [Injection of new magma](#12-injection-of-new-magma)
13. [The mobile body](#13-the-mobile-body)
14. [Parameterised convection](#14-parameterised-convection)
15. [Crystal settling](#15-crystal-settling)
16. [Cumulate tracking](#16-cumulate-tracking)
17. [Melt percolation and compaction](#17-melt-percolation-and-compaction)
18. [Eruption](#18-eruption)
19. [Trace elements and zircon](#19-trace-elements-and-zircon)
20. [Time stepping and event order](#20-time-stepping-and-event-order)
21. [Conservation and diagnostics](#21-conservation-and-diagnostics)
22. [Outputs and display](#22-outputs-and-display)
23. [Constant-property mode](#23-constant-property-mode)
24. [Parameters](#24-parameters)
25. [Assumptions and limitations](#25-assumptions-and-limitations)
26. [References](#26-references)

---

## 1. Overview

The model follows a vertical two-dimensional slice of crust, 20 km wide and 30 km thick by default. A sill-shaped
chamber sits at a chosen depth and grows as magma is injected periodically. Between injections:

- heat **conducts** through rock and magma; convection inside the molten part is mimicked by a raised conductivity;
- every cell whose temperature or composition has changed is sent to **MAGEMin** to update its mineral assemblage,
  melt fraction, density, heat capacity and enthalpy;
- **crystals settle** from the molten, convecting part (the *mobile body*) and pile up as **cumulate** at its base;
- **melt percolates** out of mush, cumulate and partially molten wall rock and joins the mobile body;
- when the mobile body is melt-rich enough, it **erupts** part of its volume.

All transfers conserve mass (each oxide), heat capacity and enthalpy exactly. Whenever the geometry changes (injection,
eruption, percolation from the wall rock, remeshing), the cell contents are moved by an exact conservative geometric
**remap**.

One thermal timestep proceeds as follows (details in [Section 20](#20-time-stepping-and-event-order)):

```
conduction ─► settling ─► slumping ─► eruption ─► percolation/compaction ─► MAGEMin batch
           ─► mobile body + convection update ─► remeshing if needed
```

At each scheduled injection: emplace the sill (remap), route it, re-equilibrate, mix the mobile body.

---

## 2. Notation

| Symbol | Meaning | Unit |
|---|---|---|
| $x, y$ | horizontal and vertical coordinates ($y$ negative below the surface) | m |
| $h$ | cell edge length; $h_{min}$, $h_{max}$ finest and coarsest | m |
| $A = h^2$ | cell area (in 2-D, "volume" means area per unit length out of plane) | m² |
| $f$ | chamber fraction of a cell (area inside the chamber outline / cell area) | – |
| $T$, $T_K$ | temperature, $T_K = T + 273.15$ | °C, K |
| $E$ | stored "conduction energy" $E = C\,T_K$ | J |
| $C$ | heat capacity of a cell | J/K |
| $H$ | true (thermodynamic) enthalpy of a cell | J |
| $n_k$ | moles of oxide $k$ in a cell | mol |
| $m$ | mass of a cell, $m = \sum_k n_k M_k$ | kg |
| $M_k$ | molar mass of oxide $k$ | kg/mol |
| $h = H/m$ | specific enthalpy | J/kg |
| $c_p^{s}$ | apparent specific heat capacity from MAGEMin (includes latent heat) | J/kg/K |
| $\rho$, $\rho_M$, $\rho_S$ | bulk, melt and solid densities | kg/m³ |
| $\phi$ | melt fraction, by volume, of melt + solids (fluid excluded) | – |
| $\phi_{lock}$, $\phi_{perc}$, $\phi_{erupt}$ | lock-up, percolation and eruptible melt fractions | – |
| $\eta_M$, $\eta$ | melt and bulk (crystal-bearing) viscosity | Pa s |
| $k$ | thermal conductivity | W/m/K |
| $g$ | gravitational acceleration | m/s² |
| $\Delta t$ | thermal timestep | s |
| $L$ | chamber (lens) length | m |
| $s$, $\xi$ | coordinates along and across the chamber axis | m |

---

## 3. Domain, coordinates and symmetry

- The domain is a rectangle of width $W$ (`domain_width_km`) and thickness $D$ (`domain_thickness_km`). The top
  is the Earth's surface ($y = 0$) and the bottom is at $y = -D$.
- The chamber is centred on the vertical axis $x = W/2$, at depth `lens_depth_km`, and is horizontal.
- Because the chamber and all processes are symmetric about this axis, **only the left half**
  $x \in [0, W/2]$ is computed. The axis is a no-flux (mirror) boundary. All reported areas and volumes refer to the
  **full** section: half-domain quantities are multiplied by the symmetry factor $S = 2$. The maps are drawn
  mirrored.
- Pressure is lithostatic, computed with the host density:

$$
P\;[\mathrm{kbar}] = \max\!\left(10^{-3},\; \frac{\rho_{host}\, g\, \max(-y, 0)}{10^{8}}\right).
$$

---

## 4. The adaptive quadtree grid

*quadtree.jl*

The half-domain is first covered by square root cells of size $h_{max}$ (`grid_h_max_m`). Each cell can be split
into four children, down to level $L_{max} = \lceil \log_2(h_{max}/h_{min}) \rceil$, which gives the finest size
$h_{min} = h_{max}/2^{L_{max}}$.

**Refinement around the chamber.** A cell of size $h$ whose centre is at distance $d$ from the chamber outline
(minus half its diagonal) is split when

$$
h > h_{min} + G\, d,
$$

with the grading factor $G$ (`grid_grading`). Cells touching the chamber are therefore at $h_{min}$, and the
size grows linearly away from it.

**Refinement around internal boundaries.** Cells that touch a change of material class are also refined down to
$h_{min}$. The classes are host, mush, mobile body, cumulate, and partially molten host (see
[Section 22](#22-outputs-and-display)). The refinement extends over the same graded distance
$r = (h - h_{min})/G + h/\sqrt2$.

**Balance.** The tree is 2:1 balanced: neighbouring leaves differ by at most one level. This keeps the
finite-volume fluxes accurate.

**Chamber fraction.** For every leaf the chamber outline polygon is clipped against the cell square, giving
$f \in [0,1]$.

**Remeshing.** The grid is rebuilt at every geometric event. It is also rebuilt, through a zero-displacement remap,
whenever an interface cell is coarser than $h_{min}$; this keeps moving internal boundaries resolved.

---

## 5. What each cell stores

*materials.jl, state.jl*

Each cell carries a **content vector** of extensive (additive) quantities:

$$
\mathbf{Q} = \big(E,\; C,\; H,\; n_1, \dots, n_{N_{ox}}\big),
$$

- $C$ is the heat capacity used by the conduction solver and $E = C\,T_K$ defines the cell temperature,
  $T = E/C - 273.15$;
- $H$ is the true enthalpy, which MAGEMin relates to temperature and composition;
- $n_k$ are the oxide moles (default system: SiO₂, Al₂O₃, CaO, MgO, FeO, K₂O, Na₂O, TiO₂, O, Cr₂O₃, H₂O);
- with trace elements on, the element masses and the zircon rows follow the oxides (Section 19).

Because every entry is extensive, mixing two parcels is a plain sum, and the remap can redistribute every entry by
area overlap.

Each cell also keeps its last **thermodynamic point**, i.e. the MAGEMin result for its current state:
- temperature $T_{last}$ and pressure;
- density $\rho$, apparent $c_p^{s}$, thermal expansivity;
- melt, solid and fluid fractions (by mole, weight and volume) with their compositions, densities and specific
  enthalpies ($h_M$, $h_S$, $h_F$);
- the melt viscosity $\eta_M$, the phase list and proportions;
- optionally the solution vectors used as initial guesses.

Per-cell bookkeeping completes the state:
- the cumulate fraction and lock-up time (Section 16);
- the melt moved out by settling in the current step (`melt_out`);
- a donor flag for display;
- the mobile-body mask.

---

## 6. Initial state

*thermo.jl, state.jl*

- **Geotherm:** $T(y) = T_{surf} - G_T\, y$ with $G_T$ = `geotherm_gradient_C_km`/1000.
- **Host-rock profile:** MAGEMin is run once on the host bulk composition at regularly spaced depths, spaced so
  that consecutive temperatures differ by $\Delta T_{tol}/2$. Fluid released at a depth is removed and that depth
  is recomputed, up to 3 times. This gives, at every depth, the host density and a full **content density** per
  unit volume:

$$
\mathbf{q}(y) = \Big(C\,T_K,\; C,\; m\,h,\; \mathbf{n}\Big)\Big/\mathrm{m^3}, \qquad
\mathbf{n} = \frac{\rho}{M_{sys}}\,\hat{\mathbf{x}}, \quad m = \sum_k n_k M_k, \quad C = m\, \min(c_p^{s},\, 3000).
$$

  Here $\hat{\mathbf x}$ is the normalised molar bulk and $M_{sys}$ the molar mass of the system. Each cell starts
  with $\mathbf Q = \mathbf q(y_c)\,A$ and with the thermodynamic point of the nearest profile depth.
- **Injected magma:** the injection composition (the magma bulk by default) is equilibrated once at the injection
  temperature and at the pressure of the chamber centre. That gives the content density of new magma, $\mathbf
  q_{inj}$. With *Injected material = Equilibrated melt* (`injection_melt_only`), only the melt of that equilibrium
  is injected: its composition is re-equilibrated at the same pressure and temperature and replaces the bulk. The
  run stops with an error if the bulk has no melt at those conditions.
- The chamber is closed at $t = 0$. The first injection (at `first_injection_yr`) opens it.

---

## 7. Chamber geometry

*chamber.jl*

The chamber is described in a frame centred on the axis at the lens depth: $s$ runs along the chamber and $\xi$
upward. Its outline is defined by **stations** $s_i$ (`lens_n_segments`+1 points) over $[-L/2, L/2]$, with a
shape function

$$
w(s) = \sqrt{1 - (2s/L)^2}\quad\text{(ellipse)},\qquad w(s) = 1 - (2s/L)^2\quad\text{(parabola)},
$$

set to zero at both tips and interpolated linearly between stations ($\hat w$). The chamber has a single thickness
parameter $T_c$. Its roof and floor are

$$
\xi_{roof}(s) = a\,T_c\,\hat w(s), \qquad \xi_{floor}(s) = -(1-a)\,T_c\,\hat w(s),
$$

The **opening share** $a$ is 0.5 for `split` (the roof rises and the floor sinks equally), 1 for `up` and 0 for
`down`. The chamber area and maximum thickness are

$$
A_{ch} = T_c\, I, \qquad I = \int \hat w\, ds \;(\text{trapezoid rule}), \qquad \text{thickness} = T_c \max \hat w.
$$

**Injected volume per event** (full section):

$$
V_{inj} = \frac{\pi}{4}\, L\, w_{lens}\;(\text{ellipse}), \qquad V_{inj} = \frac{2}{3}\, L\, w_{lens}\;(\text{parabola}),
$$

with $w_{lens}$ = `lens_thickness_m`. Each injection raises $T_c$ by $\Delta T_c = V_{inj}/I$. That is exactly
$w_{lens}$ at the chamber centre, so the vertical accretion rate there is $w_{lens}$/`injection_period_yr`.

---

## 8. Kinematics: how material moves at an event

*remap.jl*

An event changes the chamber thickness from $T_0$ to $T_1 = T_0 + \Delta T_c$. The displacement field is exact and
piecewise linear between stations ($\hat w$ is linear in each segment).

**Host rock (outside the chamber), column shear.** Within the chamber's horizontal extent:

$$
\text{above the roof:}\; \xi \to \xi + a\,\Delta T_c\, \hat w(s), \qquad
\text{below the floor:}\; \xi \to \xi - (1-a)\,\Delta T_c\, \hat w(s).
$$

Beyond the tips the rock does not move. Material pushed above the top of the box leaves as **outflow**. Material
needed at the bottom enters as **inflow**, with the host content density of the depth it comes from.

**Inside the chamber, injection ($\Delta T_c > 0$): sill insertion.** The chamber contents above the centre plane are
lifted rigidly with the roof, those below are lowered rigidly with the floor, and the opened band

$$
-(1-a)\,\Delta T_c\,\hat w(s) \;\le\; \xi \;\le\; a\,\Delta T_c\,\hat w(s)
$$

is filled entirely with the new material. The new magma therefore arrives as a hot sill at the centre plane. Melt
percolating in from the wall rock (Section 17) uses the same insertion with its own composition.

**Inside the chamber, eruption ($\Delta T_c < 0$): uniform closure.** The chamber interior is compressed uniformly,
$\xi \to \xi\, T_1/T_0$. The erupted material is removed beforehand (Section 18), so nothing is lost here.

---

## 9. The conservative remap

*remap.jl, events.jl*

After an event a new grid is built and every new cell is filled from the old grid:

1. The new cell square is cut into pieces by the station lines, the roof and floor lines and, for an injection, the
   sill-band lines.
2. Each piece is mapped back through the **analytic inverse** of the displacement (Section 8), giving its pre-image
   polygon.
3. The pre-image is clipped against every old cell it overlaps (Sutherland–Hodgman polygon clipping). Each overlap
   area $a_{mo}$ transfers the fraction $a_{mo}/A_o$ of old cell $o$'s content vector:

$$
\mathbf Q^{new}_n = \sum_{o} \frac{a_{no}}{A_o}\,\mathbf Q^{old}_o \;+\; A^{inj}_n\,\mathbf q_{inj} \;+\; \sum_{\text{inflow}} A^{in}\,\mathbf q(y^{in}).
$$

   - $A^{inj}_n$ is the part of the new cell with no pre-image inside the chamber (new magma).
   - Pre-image parts outside the box are filled with inflow host content.

4. A **ledger** records what was pulled from the old grid, injected, flowed in, flowed out and extracted, so that
   the totals can be checked (Section 21).
5. For quantities that are not extensive, each new cell takes the value of the old cell with the largest overlap
   (its *dominant source*). These are the thermodynamic point, the per-step flags, and the label "injection" or
   "inflow".
   - A cell is flagged for a new MAGEMin calculation when its composition differs from that point's composition.
   - It is also flagged when it touches a neighbour whose dominant source had a melt fraction differing by more
     than 0.05. This keeps melt fronts from moving in whole-cell jumps.
6. The **cumulate fraction** and its lock-up time are remapped conservatively as two extra rows of $\mathbf Q$
   (Section 16).

The remap is exact for the piecewise-linear geometry. Mass, heat capacity, $E$ and $H$ are therefore conserved to
round-off.

---

## 10. Heat conduction

*thermal.jl*

Heat transport is conduction with a convective enhancement inside the mobile body (Section 14):

$$
C\,\frac{\partial T}{\partial t} = \nabla\cdot\left(k\,\nabla T\right).
$$

**Finite volumes.** For two neighbouring leaves $a, b$ the conductance is

$$
K_{ab} = \frac{2 k_a k_b}{k_a + k_b}\; \gamma_{ab}, \qquad \gamma_{ab} = 1 \text{ (same size)},\; 2/3 \text{ (sizes differ by one level)}.
$$

In 2-D a face flux is $K\,\Delta T$, independent of cell size for equal cells.

**Implicit (backward Euler) step.**

$$
\frac{C_a}{\Delta t}\left(T_a^{n+1} - T_a^{n}\right) = \sum_b K_{ab}\left(T_b^{n+1} - T_a^{n+1}\right) + B_a ,
$$

solved as one sparse linear system. It is unconditionally stable, so the timestep only controls accuracy.

**Boundary conditions** (`thermal_bc`):
- `surface`: fixed temperature $T_{surf}$ at the top (half-cell conductance $2k$) and a constant basal heat flux
  $q_b = k_{host}\, G_T$ (the geotherm's own flux) at the bottom. Without a chamber the geotherm is a steady state.
- `insulated`: no flux through any boundary.
- The left edge and the symmetry axis are always no-flux.

**Conductivity.** $k = k_{magma} f + k_{host}(1-f)$ in every cell, multiplied by the Nusselt number $Nu$ in mobile-body
cells (Section 14).

**Updating the content.** With $C$ held fixed during the step:

$$
H \leftarrow H + C\,(T^{n+1} - T^{n}), \qquad E \leftarrow C\,T^{n+1}_K .
$$

The heat that crossed the boundaries is booked in the ledger.

---

## 11. Thermodynamics with MAGEMin

*thermo.jl, coupling.jl*

**Calls.** MAGEMin is initialised once with the chosen database (`ig` by default), using the default solver.
- All cells needing an update in a timestep go into **one batched multi-point minimisation**: per-cell bulk
  compositions in moles, at the cell's $T$ and lithostatic $P$.
- The specific-heat option is switched on, so the returned $c_p^{s}$ is the *apparent* heat capacity, which includes
  the latent heat of reaction.
- Progress is printed per timestep.

**Which cells are recomputed** (the "gate"). A cell is recomputed when it is flagged. That happens when an event,
settling, percolation, eruption or degassing changed it, or when its bulk composition differs from that of its
thermodynamic point by more than $\Delta X_{tol}$ (`dX_tol`). The shift is measured as $\sum_k |\hat x_k - \hat x_k^{point}|$, the sum of absolute
differences of the normalised molar fractions. An unflagged cell is recomputed when it is hot
($T \ge$ `subsolidus_T_C`) or contains melt, **and** one of these holds:

$$
|T - T_{last}| > \Delta T_{tol} \quad\text{or}\quad \left|\frac{H}{m} - h_{last}\right| > 3000\;\mathrm{J/kg/K}\times \Delta T_{tol}.
$$

The second (enthalpy) test catches cells crossing a sharp, near-eutectic reaction, where the apparent heat capacity
is very large and the temperature hardly changes.

**What is used from MAGEMin.**
- The bulk density, the apparent heat capacity (clamped to 300–50 000 J/kg/K) and the system enthalpy $h$.
- The melt, solid and fluid fractions and compositions, the liquid density and expansivity, and the melt viscosity
  $\eta_M$ (Giordano et al., 2008, computed by MAGEMin).
- The phase list and proportions for display.

**Temperature follows enthalpy.** MAGEMin is called at the conduction temperature $T$, but the cell's enthalpy $H$ is
the conserved quantity. After each minimisation the temperature is moved, by one Newton step, onto the
enthalpy–temperature curve:

$$
T \leftarrow T + \mathrm{clamp}\!\left(\frac{H/m - h(T)}{c_p^{s}},\; \pm 200\ \mathrm{K}\right),
$$

and the heat capacity used by the conduction solver is reset:

$$
C = m\, \min(c_p^{s},\, 3000\ \mathrm{J/kg/K}), \qquad E = C\, T_K .
$$

Two notes on this step:
- **Capped heat capacity.** The cap keeps a cell sitting at a near-eutectic step from becoming an artificial heat
  sink in the conduction solver. The latent heat is still accounted for exactly through $H$ and the correction
  above.
- **Bookkeeping.** The energy change of $E$ caused by this reset is booked as `remin_energy`, so $E$ stays
  consistent with the ledger.

**Phase enthalpies.** When melt, crystals or fluid are moved as separate parcels (settling, percolation, eruption,
degassing), each parcel must carry its own enthalpy. The molar enthalpy of each phase, $H_i = G_i + T_K S_i$, is
taken from MAGEMin. Its phase entropy $S_i = -\partial G_i/\partial T$ is evaluated at fixed phase composition from
the full solution model, mixing terms included, on the same per-mole-of-oxides basis as $G_i$. The phase enthalpies
are summed per group (melt, solids, fluid), weighted by phase fraction and divided by the group mass:

$$
h_M = \frac{\sum_{i\in M} x_i H_i}{\sum_{i\in M} x_i \mathcal M_i},\quad \text{etc.}
$$

Here $\mathcal M_i$ is the molar mass of phase $i$. Between calculations the parcel enthalpy is shifted to the
current temperature: $h_X(T) = h_X + c_p^{s}(T - T_{last})$.

**A parcel** of moles $\mathbf n_p$ (mass $m_p$) taken from a cell of mass $m$ carries

$$
\mathbf Q_p = \left(\tfrac{m_p}{m}E,\; \tfrac{m_p}{m}C,\; m_p\, h_X(T),\; \mathbf n_p\right).
$$

**Degassing** (`fluid_treatment = removed`). After each calculation, any free fluid is removed from the cell:
- The removed fraction is the fluid mole fraction, limited so that no oxide becomes negative.
- The fluid leaves with its own enthalpy $h_F$ and is booked in the fluid ledger.
- The cell is then recomputed in the next batch.

With `retained`, the fluid stays in the cell.

**Boost mode** (`boost_mode`, off by default). A host-rock cell can start MAGEMin from previous solutions: its own
and those of its host-rock face neighbours. This applies only to pure host-rock cells ($f = 0$) whose face
neighbours are all pure host rock, so a band one cell wide around the chamber always starts from scratch. The guess
is not used when the cell's composition has shifted by more than 0.02 (same measure as above).

---

## 12. Injection of new magma

*events.jl, body.jl*

Injections happen every `injection_period_yr`, starting at `first_injection_yr`. Each one does the following:

1. **Sill insertion.** The chamber opens by $\Delta T_c = V_{inj}/I$ and the opened band is filled with injected magma
   (Sections 8–9).
2. **Routing** (`injection_target`):
   - `body` (default): if a mobile body exists, the sill content that landed outside it is **exchanged at constant
     volume** with the same volume of mobile-body magma. Let $V_r$ be the injected area outside the body and $A_B$
     the body area. The exchange takes the fraction $\varphi = r V_r / A_B$ of every body cell's content, with
     $r = \min(1,\; 0.5\,A_B/V_r)$, and spreads it over the sill cells. The sill content goes into the body cells in
     proportion to their area. The new magma thus feeds the body directly, and no cell is over- or under-filled.
     Without a body, the sill stays in place.
   - `chamber` ("in place"): the sill stays where it was emplaced and joins the body only if it is connected to it.
3. **Equilibration of fed cells.** Every cell that received new material is brought to equilibrium at constant
   enthalpy by Newton iterations on temperature, at most 3, stopping when the correction is below 1 °C:

$$
T^{j+1} = T^{j} + \mathrm{clamp}\!\left(\frac{H - m\,h(T^{j})}{m\, c_p^{s}},\; \pm200\right).
$$

4. **Mobile body mixing.** The convecting body is homogenised. All its oxide moles are pooled and redistributed in
   proportion to cell area, all its enthalpy is pooled, and the common temperature is found by Newton iteration on

$$
h(T,\; \bar{\mathbf x},\; \bar P) = \frac{H_B}{m_B},
$$

   at the body's area-weighted mean pressure, with at most 8 iterations, a tolerance of 0.05 K and steps of at most
   200 K. Every body cell then gets the same point and temperature, and enthalpy in proportion to its mass.
5. **Unlocking.** Cumulate cells pushed back above $\phi_{lock} + 0.05$ by the new heat lose their cumulate label
   (Section 16).
6. The eruption trigger is **armed** (Section 18).

---

## 13. The mobile body

*body.jl*

The mobile body is the part of the chamber that is molten enough to flow and convect. It consists of chamber cells
with

$$
f \ge 0.5 \quad\text{and}\quad \phi > \phi_{lock},
$$

connected to each other through cell faces. Three rules complete the definition:

- **Only the largest connected region counts.** Smaller isolated melt-rich pockets do not convect, mix or settle;
  they crystallise in place or drain by percolation.
- **Enclosed holes are included.** Chamber cells completely surrounded by the body belong to it, as crystal-rich
  parcels carried by convection.
- **Host rock is never part of it**, however much it melts. Its melt reaches the chamber only by percolation.

The melt fraction used everywhere is the melt volume over melt plus solids:
$\phi = V_{melt}/(V_{melt} + V_{solid})$.

---

## 14. Parameterised convection

*body.jl*

Convection inside the mobile body is not resolved. Its effect, a much faster transfer of heat, is represented by
multiplying the conductivity of body cells by a Nusselt number computed from a body Rayleigh number:

$$
Ra = \frac{\rho\, g\, \alpha\, \Delta T\, L_B^3}{\kappa\, \eta}, \qquad \kappa = \frac{k_{magma}}{\rho\, c_p^{s}},
$$

$$
Nu = \begin{cases} (Ra/Ra_{c})^{\beta} & Ra > Ra_{c} \\ 1 & \text{otherwise} \end{cases}
$$

The terms are:
- $\Delta T$: the temperature range in the body.
- $L_B$: its vertical extent.
- $\alpha$: the melt expansivity.
- $\rho$, $c_p^{s}$, $\eta$: area-weighted body means.
- $Ra_c$ = `Ra_crit`, $\beta$ = `Nu_exponent` (1/3).

The bulk viscosity accounts for crystals with the Einstein–Roscoe relation:

$$
\eta = \eta_M \left(1 - \frac{\phi_x}{1 - \phi_{lock}}\right)^{-2.5}, \qquad \phi_x = 1 - \phi ,
$$

which diverges at lock-up. The body temperature and composition are also homogenised at every injection
(Section 12).

---

## 15. Crystal settling

*settling.jl*

**Settling velocity.** Crystals of radius $r$ (half of `crystal_size_mm`) sink through the melt at the hindered
Stokes velocity (Richardson & Zaki, 1954):

$$
v = \frac{2\,(\rho_S - \rho_M)\, g\, r^2}{9\,\eta_M}\, (1 - \phi_x)^{n}, \qquad n = \text{`hindered_exponent'} = 4.65 .
$$

**Settling in a convecting layer.** Convection keeps the crystal concentration uniform inside the body, but the flow
vanishes at the floor, where crystals fall out at speed $v$ (Martin & Nokes, 1988, 1989). Over a timestep the
fraction of suspended crystals deposited from a column of height $H_c$ is

$$
f_s = 1 - \exp\!\left(-\frac{v\,\Delta t}{H_c}\right).
$$

**Columns.** Each body cell is divided into vertical sub-columns of width $h_{min}$. In each sub-column:

- $H_c$ is the height of the contiguous body above and below the cell;
- the crystals leaving the cell are the moles $\mathbf n_x = w\, f_s\, x_S\, N\, \hat{\mathbf x}_S$, where
  $N$ is the cell's total oxide moles, $x_S$ the solid mole fraction, $\hat{\mathbf x}_S$ the normalised solid
  composition, and $w = \Delta x / h$ the sub-column share of the cell. Their volume is
  $V_x = m_x/\rho_S$, with $m_x = \sum_k n_{x,k} M_k$;
- the crystals go to the **base of the body**: the lowest body cell of that sub-column, or the next one up once that
  cell has reached lock-up. A body cell can take crystals until its melt fraction falls to $\phi_{lock}$:

$$
V^{cap} = \left(\phi_M^{vol} - \phi_{lock}\,(\phi_M^{vol} + \phi_S^{vol})\right) A .
$$

- If the body is a single cell thick in that sub-column, the crystals go to the cell beneath it, down to
  $\phi_{perc}$. Otherwise, crystals that find no room stay in suspension.

**Constant-volume exchange.** The deposited crystals exchange their volume with the same volume of melt from the
receiving cell. That melt moves up into the source cell. Both parcels carry their own phase enthalpies:

$$
\mathbf Q_{src} \mathrel{+}= \mathbf Q_{melt} - \mathbf Q_{xtal}, \qquad \mathbf Q_{rcv} \mathrel{+}= \mathbf Q_{xtal} - \mathbf Q_{melt}.
$$

The receiving cell is labelled cumulate when it is filled to lock-up, or immediately if it is outside the body.

**Slumping (angle of repose).** A crystal pile cannot hold steep walls. After settling, finest-width columns are
compared. Where the floor of the body is two or more cells higher in one column than in its neighbour, the top
cumulate cell of the higher column swaps its whole content with the lowest body cell of the lower column (equal
sizes, so the swap is exactly conservative). This repeats until no step exceeds one cell (a 45° slope on the grid).

---

## 16. Cumulate tracking

*state.jl, events.jl, body.jl*

Each cell carries a **cumulate fraction** $c \in [0,1]$ and a mean **lock-up time** $t_c$.

- **Formation:** a cell that receives settled crystals and leaves the body gets $c = 1$. Its time is blended with any
  older cumulate it held: $t_c \leftarrow c_{old} t_c + (1 - c_{old})\,t$.
- **Transport:** at every remap, $c\,A$ and $c\,A\,t_c$ are carried as extensive quantities. The new fraction is
  computed against the *old material* only, so injected magma does not dilute it:

$$
c_n = \frac{\sum_o (a_{no}/A_o)\, c_o A_o}{A_n - A_n^{inj}}, \qquad
t_{c,n} = \frac{\sum_o (a_{no}/A_o)\, c_o A_o t_{c,o}}{\sum_o (a_{no}/A_o)\, c_o A_o}.
$$

  The cumulate boundary therefore follows the real material displacement and does not jump by whole cells.
- **Label:** a chamber cell ($f \ge 0.5$) is cumulate when $c \ge 0.5$ and it is not in the mobile body.
- **Unlocking:** a cumulate cell whose melt fraction rises back above $\phi_{lock} + 0.05$ inside the body (for
  example after reheating by an injection) loses its label (Burgisser & Bergantz, 2011).
- **Display:** cumulate with $\phi > \phi_{perc} + 0.02$ is shown as *cumulate mush*, otherwise as *compacted
  cumulate*. The *Cumulate* figure groups the cumulate area by lock-up time.

---

## 17. Melt percolation and compaction

*body.jl*

Melt in a partially molten region is interconnected above a threshold $\phi_{perc}$ (the melt connectivity transition,
Rosenberg & Handy, 2005). It is buoyant and flows upward through the crystal framework by porous (Darcy) flow
(McKenzie, 1984).

**Darcy flux.** Permeability follows a Kozeny–Carman law for a granular framework (Wark & Watson, 1998). The upward
melt flux is

$$
k_\phi = \frac{d^2 \phi^3}{270}, \qquad q = \frac{k_\phi\, (\rho_S - \rho_M)\, g}{\eta_M},
$$

with $d$ the crystal size (`crystal_size_mm`).

**Which cells drain.** A cell outside the body is connected to it when a path of partially molten cells
($\phi > 0$) links them. Only cells holding more than $\phi_{perc}$ give up melt. Melt can pass through drained
restite at the contact, which sits near or just below the threshold after re-equilibration. Texturally equilibrated
partially molten rock has no connectivity threshold, while non-equilibrated rock connects at about 8–11 % melt
(Cheadle et al., 2004). $\phi_{perc}$ is therefore used as the threshold for extraction, not for transmission. The effective melt fraction subtracts the melt already moved by settling in the same step.

**(a) Pile columns: bottom-up compaction.** Below the mobile body, each finest-width column runs from the body
floor down to the chamber floor through the mush and cumulate cells. Across every horizontal face, melt rises from
the lower cell and the same volume of crystals moves down from the upper cell:

$$
V_{face} = \min\!\Big(q(\phi_{lower})\,\Delta t\,\Delta x,\;\; V^{excess}_{lower},\;\; V^{solid}_{upper}\Big),
\qquad V^{excess} = (\phi - \phi_{perc})(\phi_M^{vol} + \phi_S^{vol})\,A .
$$

- The top cell of the pile gives its melt directly to the body.
- The base rests on the impermeable chamber floor and only loses melt, so it compacts first. A compaction front
  then rises through the pile while young cumulate on top stays melt-rich.
- A column of thickness $L_c$ drains on a timescale $\tau \approx \phi L_c / q$. That is hundreds of years for fresh
  mush with 10 mm grains, and $10^4$–$10^5$ years for millimetre grains (Bachmann & Bergantz, 2004).

**(b) Other donors.** These are roof and side mush, and partially molten host rock. Each loses, per timestep,

$$
\Delta\phi = \min\!\left(\phi - \phi_{perc},\; \frac{q\,\Delta t}{L}\right),
$$

where $L$ is the thickness of the connected partially molten column it belongs to. The melt leaves with its own
composition and enthalpy $h_M$.

**Where the melt goes.**
- From inside the chamber ($f \ge 0.5$), it is added to the mobile body cells in proportion to their area. The
  chamber size does not change.
- From the host rock ($f < 0.5$), it is pooled. The chamber is opened by its full-section volume
  $S \sum V$ (sill insertion of that melt, Section 8), and the volume is recorded as *percolated area*.

---

## 18. Eruption

*eruption.jl*

**Trigger.** An eruption happens when the trigger is *armed* (by an injection since the last eruption) and the
area-weighted mean melt fraction of the mobile body exceeds $\phi_{erupt}$. There is at most one eruption per
injection.

**Volume.** The target is a fraction `erupt_frac` of the body volume, capped at half of the chamber:

$$
V_{target} = \min\!\left(\text{erupt\_frac}\times A_B,\;\; 0.5\, \frac{A_{ch}}{S}\right) \quad(\text{half-domain}).
$$

**What erupts.** Each body cell gives the same fraction $f_e$ of its melt and fluid, and $f_e\,\chi$ of its crystals.
Here $\chi$ (`erupt_crystal_frac`) runs from 0 (crystal-poor melt) to 1 (the bulk magma with all suspended crystals).
$f_e$ is found from the volumes, capped at 0.95:

$$
f_e = \min\!\left(\frac{V_{target}}{\sum_B A\,(\phi_M^{vol} + \phi_F^{vol} + \chi\,\phi_S^{vol})},\; 0.95\right).
$$

Each phase leaves with its own composition and enthalpy.

**Overpressure trigger (optional).** With `eruption_trigger = overpressure`, the melt fraction only decides whether
the magma *can* erupt (mobile-body mean melt above $\phi_{erupt}$). What *triggers* the eruption is the chamber
overpressure $\Delta P$ (Jellinek & DePaolo 2003; Degruyter & Huber 2014):

$$
\frac{d\Delta P}{dt} = \frac{1}{\beta_{eff}\,V}\,\frac{dV_{src}}{dt} - \frac{\Delta P}{\tau}, \qquad
\tau = \eta_{shell}\,\beta_{eff}, \qquad \beta_{eff} = \beta_m + \frac{1}{\mu}.
$$

- $V$ is the chamber volume (full-section area).
- $\mu$ is the host shear modulus. $1/\mu$ is the compressibility of a cylindrical cavity in plane strain.
- $\beta_m$ is the magma compressibility, weighted by magma fraction and volume:
  $\phi_M/K_M + \phi_S/K_S + \phi_F/P$. $K_M$ and $K_S$ are the melt and solid bulk moduli from MAGEMin, and the fluid
  is taken as an ideal gas at lithostatic pressure.
- $\eta_{shell}$ is the effective viscosity of a wall-rock shell around the chamber. The local viscosity is
  $\eta = A \exp\!\big(G/(R\,T)\big)$; the defaults $A = 4.25\times10^{7}$ Pa s and $G = 141$ kJ/mol follow
  Degruyter & Huber (2014).
  - For a viscous shell around a cylindrical cavity of radius $a$, the overpressure needed to grow the cavity is
    $\Delta P \propto \int_a^b \eta\, r^{-3}\, dr$.
  - The effective viscosity is therefore the mean of $\eta$ over the host cells of the shell, weighted by their area
    and by $\big(a/(a+d)\big)^3$, where $d$ is the distance to the nearest magma cell.
  - $a = \sqrt{V/\pi}$ is the equivalent chamber radius. The shell extends to `shell_thickness_m`, or to $a$ when that
    option is 0.
  - The hot rock next to the magma weighs most, but the cooler rock further out keeps the shell stiff.

The volume source $dV_{src}$ is the sum of three terms:
- **Recharge.** Each injection adds its volume at a constant rate over `recharge_time_yr`. The default of 0 means one
  injection period, i.e. continuous recharge at the mean rate.
- **Percolation.** Melt percolated into the chamber from the host.
- **Phase changes in the magma** (crystallisation, melting, fluid exsolution). They are measured from a
  material-volume row added to $\mathbf Q$:
  - every parcel carries its phase volume ($m/\rho_M$, $m/\rho_S$, $m/\rho_F$);
  - whenever a cell gets a new MAGEMin point, its volume is reset to $m/\rho$, and the difference, weighted by the
    magma fraction, is the phase-change volume.
  - A fluid removed by degassing leaves the volume row, but its exsolution has already been counted. Exsolved fluid
    therefore pressurises the chamber before it leaves, and its escape does not relieve the pressure.

Over a step $\Delta t$ the source is treated as a constant rate, with the exact solution

$$
\Delta P(t+\Delta t) = \Delta P\,e^{-x} + \frac{\Delta V_{src}}{\beta_{eff} V}\,\frac{1 - e^{-x}}{x}, \qquad x = \Delta t/\tau .
$$

When $\Delta P$ exceeds `dP_crit_MPa` but the magma is not eruptible (no mobile body, or mean melt below
$\phi_{erupt}$), the wall rock fails without an eruption (a dike that stalls): $\Delta P$ is capped at the critical
value. An eruption happens when $\Delta P$ exceeds `dP_crit_MPa` and the body is eruptible. It removes the volume that brings
$\Delta P$ back to zero, $\beta_{eff} V \Delta P$, within the same caps as above. $\Delta P$ then drops by the erupted
volume over $\beta_{eff} V$. A chamber in warm crust relaxes its overpressure in years, so it can keep growing without
erupting; cold crust or fast recharge leads to eruptions.

**Closure.** The chamber closes by the erupted full-section volume $S\,V$, with uniform compression of the interior
(Section 8). The erupted material is booked in the ledger and recorded as a *pluton/eruption layer*: time, volume,
mean temperature and composition.

---

## 19. Trace elements and zircon

*trace.jl, zircon.jl*

Trace elements are switched on with `te_enabled` (MAGEMin thermodynamics only). They use the same KD models and
predefined compositions as the PTX path tab. The compositions are entered next to the major elements in the material
and injection composition panels; the injected magma uses the magma trace elements when "Same as magma" is on. Zircon is modelled when the KD model contains Zr and a Zr saturation
model is selected.

**What is stored.** The content vector of every cell (Section 5) gets extra extensive rows after the oxides:

$$
\mathbf Q = \big(E,\, C,\, H,\, n_1 \dots n_{N_{ox}},\; X_1 \dots X_{N_{el}},\;
\underbrace{N_z^{f},\; M_z^{f,inh},\; M_z^{f,1} \dots M_z^{f,N_{bin}}}_{f = 1 \dots K}\big)
$$

- $X_e$ is the mass of element $e$ in the cell [kg/m] that is **not** in zircon.
- Zircon is held in $K$ **families** (`zircon_families`):
  - family 1 holds the inherited host-rock zircon and its overgrowths;
  - families $2 \dots K$ hold the grains nucleated during successive epochs of length $t_{run}/(K-1)$.
- For each family $f$:
  - $N_z^f$ is its number of grains;
  - $M_z^{f,inh}$ is its inherited zircon mass (non-zero only for family 1);
  - $M_z^{f,j}$ is the mass that crystallised during age bin $j$. Bin $j$ covers the model times
    $[(j-1)\,\Delta t_{age},\; j\,\Delta t_{age})$, where $\Delta t_{age}$ is `zircon_age_bin_yr`.

Families are kept apart through mixing, so grains of different origin keep their own size and zoning.

Because these rows are extensive, the remap, the injection swap, the homogenisation of the mobile body, cell swaps
and the ledger handle them like the oxides. No extra code is needed for these operations.

**Initial and injected content.**
- Injected magma carries $X_e = \rho\,C^{inj}_e\,10^{-6}$ per unit volume. With "Equilibrated melt", the bulk
  concentrations are first partitioned at the injection conditions and the melt concentrations are injected.
- The host rock carries the host composition. Its Zr above what the melt and solids hold at saturation is put into
  inherited zircon (family 1) of radius `zircon_host_radius_um`. A melt-free host therefore holds all its Zr as
  zircon.

**Partitioning.** Every MAGEMin point also runs `TE_prediction` (MAGEMin_C) on unit concentrations, without
saturation corrections. This gives the solid/melt ratio $D_e = C^{S}_e / C^{M}_e$, and the point stores it with the
melt and solid weight fractions $w_M$, $w_S$. In a cell of mass $m$, the melt and solid concentrations follow from
mass balance; trace elements are not carried by the fluid:

$$
C^{M}_e = \frac{X_e}{m\,(w_M + D_e\,w_S)}, \qquad C^{S}_e = D_e\,C^{M}_e .
$$

**Transport.** Whenever melt and crystals separate, the parcel takes the concentration of its own phase:
- settling;
- compaction;
- percolation;
- eruption;
- degassing (fluid parcels carry no trace elements).

Zircon follows the crystals: a solid parcel of mass $m_p$ takes the fraction $m_p/(m\,w_S)$ of every zircon row.
Melt parcels carry no zircon. The exception is a cell that has (almost) no crystals ($w_S \le 10^{-3}$): there the
zircon follows the melt.

**Zr saturation.** At each MAGEMin point, `zirconium_saturation` (MAGEMin_C) gives $C_{sat}$ [µg/g] with the
selected model:
- Watson & Harrison (1983);
- Boehnke et al. (2013);
- Crisp & Berry (2022).

Between minimisations, $C_{sat}$ follows the cell temperature along the 1/T dependence of the model:

$$
C_{sat}(T) = C_{sat}(T_{last})\,\exp\!\Big[b\Big(\frac{1}{T_{last}} - \frac{1}{T}\Big)\Big], \qquad
b = 12900\ \text{(WH)},\; 10108\ \text{(B)},\; 5790\ln 10\ \text{(CB)}\ \text{K}.
$$

**Zr diffusivity** in the melt (Zhang & Xu 2016, Eq. 9). It uses cation mole fractions of the melt on a wet basis,
with H counted like Na; $P$ is in GPa and $T$ in K:

$$
\ln D_{Zr} = -13.95 + 5.15\,(H + 4.1\,Ca - Mg) - \frac{36457\,(Si + Al - 1.8\,Fe) - 11008\,P\,(Si + Al - 2/3)}{T}.
$$

**Growth and dissolution rate** (Zhang & Xu 2016, Eqs. 14–18, after Kerr 1995). The grains of a family share the
mean radius $a_f = \big(3M_z^f / 4\pi\rho_z N_z^f\big)^{1/3}$, with $\rho_z = 4650$ kg/m³. Each grain grows or
dissolves at

$$
\frac{da}{dt} = \frac{\rho_M}{\rho_z}\,\frac{C - C_{sat}}{C_z - C_{sat}}\,\frac{D_{Zr}}{\delta}, \qquad
\delta = \frac{2a}{1 + (1 + Pe)^{1/3}}, \qquad Pe = \frac{4 g a^3 \Delta\rho}{9\,\eta_M D_{Zr}},
$$

- $C$ is the Zr concentration of the melt (mass fraction).
- $C_z = 0.497644$ is the Zr mass fraction of zircon.
- $\eta_M$ is the melt viscosity.
- $\Delta\rho = \rho_z - \rho_M$.
- $Pe$ is used in the mobile body only; in the mush the grains do not sink, so $Pe = 0$ and $\delta = a$.

Summed over all grains, the melt (together with the Zr held by the solids in equilibrium with it, mass
$m_{eff} = m(w_M + D_{Zr} w_S)$) relaxes toward saturation:

$$
\frac{dC}{dt} = -k\,(C - C_{sat}), \qquad k = \sum_f k_f, \qquad
k_f = \frac{4\pi a_f N_z^f \rho_M D_{Zr}\,\tfrac12\big(1 + (1+Pe_f)^{1/3}\big)\, C_z}{(C_z - C_{sat})\, m_{eff}} .
$$

The zircon exchanged over a step is shared between the families in proportion to $k_f$. Larger families of grains
take more, and small grains dissolve away first.

**Integration** over each thermal step uses the exact exponential solution with $a$ frozen:

$$
C(t+h) = C_{sat} + (C - C_{sat})\,e^{-k h}, \qquad \Delta M_z = m_{eff}\,\frac{C - C(t+h)}{C_z}.
$$

- Sub-steps $h$ keep the change of each family's zircon mass below 30 % per sub-step, so that $a_f$ is updated as
  the grains grow or shrink.
- The Zr leaving the melt equals the Zr entering zircon, so Zr is conserved exactly.
- Growth is added to the age bin of the middle of the step.
- Dissolution removes zircon from the youngest bin first, down to the inherited zircon, so rims dissolve before
  cores. A family's grains vanish ($N_z^f = 0$) when its zircon is gone.
- Cells without melt exchange nothing: their zircon is armoured.

**Nucleation.** When the melt is supersaturated ($C > C_{sat}$) and the cell has no zircon,
$n_{nuc}\,V_M$ grains of radius 1 µm nucleate in the family of the current epoch, $n_{nuc}$ being
`zircon_nucleation_density`. Their mass is taken from the melt.

**Eruption sampling and synthetic analyses.** The erupted parcels carry their zircon rows, and these are stored
with the eruption layer. The eruptions of one output (since the previous output) are merged into one sample. All ages
are measured from one reference time, the latest output $t_{ref}$ (the "present" of the run): a zircon crystallised
at time $t$ has age $t_{ref} - t$ (kyr). Older outputs therefore show their zircon populations on the same axis,
older by the time since they erupted, and the eruptions of the selected output are shaded on that axis.
- **Single spots.** `zircon_synthetic_grains` single-spot ages are drawn from the erupted zircon mass, uniformly
  within an age bin; each eruption of the output contributes in proportion to its zircon.
- **Zoned grains.** As many zoned grains are drawn from the families in proportion to their grain numbers.
  - A grain of family $f$ has radius $a_f$. Its zones are concentric shells from the oldest zircon (core) to the
    youngest (rim), with outer radii $r_j = a_f\,\big(\sum_{i \le j} M^{f,i} / M^f\big)^{1/3}$.
  - It is analysed by a core-to-rim traverse of spots of diameter $d$ (`zircon_spot_um`): a core spot covering
    $[0, d/2]$, then spots every $d$ inward from the rim, centred at $a_f - d/2,\; a_f - 3d/2, \dots$, as long as they
    do not overlap the core spot. A grain with $2a_f \le d$ gets one whole-grain spot.
  - Each spot age is the mean of the zone ages under it, weighted by their radial overlap, so zones thinner than the
    spot are mixed. Spots with at least 5 % inherited zircon are counted as inherited or mixed.
- **Analytical uncertainty.** Every synthetic age is "measured": Gaussian noise of 1σ is added, following the dating
  method (`zircon_method`):
  - SIMS ²³⁸U–²³⁰Th: an absolute σ (`zircon_sigma_kyr`, default 3 kyr);
  - LA-ICP-MS U–Pb: 1 % of the absolute age;
  - CA-ID-TIMS U–Pb: 0.05 % of the absolute age.

  The absolute age of a spot is `zircon_eruption_age_Ma` (the absolute age of the latest output) plus its age
  before $t_{ref}$. This decides whether kyr-scale crystallisation histories can be resolved at all.

**Displays (Eruption → Zircon ages),** following the magmatic-zircon literature:
1. **Rank-order plot.** Single-spot ages sorted from youngest to oldest with 2σ error bars, the eruptions shaded,
   and the inverse-variance weighted mean with its MSWD. An MSWD well above 1 means a protracted crystallisation
   history rather than a single age population.
2. **Core-to-rim plot.** Each zoned grain in a column, ranked by core age. Its spots are joined from core (circle)
   to rim (diamond) with 2σ error bars, coloured by the number of spots on the grain.
3. **Age distribution.** A histogram of the single-spot ages with bins of twice the median 1σ, and a Gaussian
   kernel density with a bandwidth of one median 1σ (Vermeesch 2012).
4. **Family illustration.** One representative grain per family, drawn to scale as a prism with pyramidal ends. Its
   growth zones are shaded in greys as in a CL image, and its spots are labelled with their ages.

The *Trace elements* figure shows each eruption's REE or all trace elements (bulk erupted material, Zr in zircon
included), normalised to chondrite or to the injected magma, with the injected magma as reference. All zircon and
trace-element figures show only the eruptions of the selected output, i.e. those since the previous output.

---

## 20. Time stepping and event order

*events.jl, app_live.jl*

Each thermal step of length $\Delta t$ (`thermal_dt_yr`) does:

1. **Conduction** (Section 10). Advance time.
2. **Mobile body** from the current melt fractions; reset the per-step settling record.
3. **Settling** (Section 15), then **slumping**.
4. **Mobile body** update.
5. **Eruption** if triggered (Section 18).
6. **Percolation and compaction** (Section 17).
7. **One MAGEMin batch** for all cells passing the gate (Section 11); temperature correction and degassing.
8. **Zircon** growth, nucleation and dissolution in every cell with melt (Section 19), then the **overpressure**
   update when the overpressure trigger is on (Section 18).
9. **Mobile body**, **unlocking** (Section 16), **convection** (Ra, Nu, conductivities).
10. **Remeshing** if an internal boundary has become coarser than $h_{min}$.

Injections happen at their scheduled times between thermal steps (Section 12). Outputs are saved on the output
schedule (`output_every_yr`), always after the conduction step. When an output time coincides with an injection,
the output is saved first. The time series of the diagnostic figures are recorded at every output and at every
injection.

---

## 21. Conservation and diagnostics

*state.jl*

The ledger holds the initial content, injected, inflow, outflow, extracted (erupted) and degassed contents, the heat
crossing the boundaries and the energy booked by the heat-capacity resets. The expected total of each row of
$\mathbf Q$ is

$$
\mathbf Q^{expected} = \mathbf Q^{initial} + \mathbf Q^{inj} - \mathbf Q^{extr} - \mathbf Q^{out} + \mathbf Q^{in} - \mathbf Q^{fluid},
$$

$$
E^{expected} \mathrel{+}= E^{boundary} + E^{remin}, \qquad H^{expected} \mathrel{+}= E^{boundary}.
$$

Reported diagnostics:

| Diagnostic | Definition |
|---|---|
| mass error | $\max_k \lvert \sum n_k - n_k^{expected} \rvert / \max(\text{initial}, \text{injected}, \text{inflow}, \text{total})$ |
| trace-element error | the same, over the elements, with Zr in zircon ($C_z \sum M_z$) added to the Zr row |
| enthalpy error | $(\sum H - H^{expected}) / \lvert H^{initial} \rvert$ |
| energy error | $(\sum E - E^{expected}) / \lvert E^{initial} \rvert$ |
| grid error | (chamber area on the grid − analytic chamber area / S) / (analytic / S) |
| host error | (host area + outflow − initial host area) / initial host area |
| budget error | (injected + percolated − chamber − erupted) / (injected + percolated) |

All of them stay at round-off level, around $10^{-13}$ for mass and trace elements and $10^{-15}$ for enthalpy, in
the test runs. The trace-element error checks every transfer between melt, crystals, zircon, fluid and the outside;
the zircon exchange moves Zr between the element row and the zircon rows without changing their sum.

---

## 22. Outputs and display

*plotting.jl, app_figures.jl*

**Map window.** The maps are mirrored to the full section and the window is chosen automatically:
- **Width:** twice the chamber length, or wider if the chamber has grown beyond it.
- **Height:** centred on the chamber, set so the map has a width-to-height ratio of about 2.2, and always tall enough
  for the chamber plus a margin. The window is kept inside the model domain.
- **Fit:** both axes keep an equal scale. When the screen ratio differs from 2.2, the map box shrinks to fit the data
  rather than leaving empty space inside it.

The temperature colour scale runs from the surface temperature to the injection temperature, or to the hottest
temperature in the model if that is higher.

**Maps:**
- temperature, with isotherms every 100 °C;
- material class;
- melt fraction;
- the number of MAGEMin calculations per cell, with the total.

The quadtree grid can be drawn over any map (*Results display* options). Clicking a cell shows its phase
proportions (mol%, wt% or vol%).

**Material classes:**

| Class | Meaning |
|---|---|
| 0 | host rock |
| 1 | magma or mush in the chamber, not mobile ($\phi \le \phi_{lock}$) |
| 2 | mobile body |
| 3 | cumulate mush ($\phi > \phi_{perc} + 0.02$) |
| 4 | compacted cumulate |
| 5 | partially molten host rock, $\phi \le \phi_{perc}$ |
| 6 | partially molten host rock above $\phi_{perc}$ or giving melt to the chamber |
| 7 | restite: host rock that has given melt to the chamber and is not feeding it now |

The restite label uses a restite fraction carried by each cell. It is set to 1 when a host cell gives melt to the
chamber, and is remapped with the material like the cumulate fraction (Section 16). A host cell is shown as restite
when this fraction is at least 0.5, even after it has cooled.

**Logs:** cumulative injected and erupted areas, with each layer's composition. When layers are numerous and small
(e.g. frequent overpressure eruptions), consecutive layers are grouped into at most 50 boxes, with the episode range,
time span, total area, mean temperature and summed composition on hover.

**Time series:**
- vital signs (temperatures, melt fraction);
- convection (Nu, Ra, body, percolated, settled and cumulate areas);
- energy budget and conservation diagnostics;
- the cumulate log: one bar per piling event (cumulate grouped by lock-up time), stacked from the oldest at the
  base without gaps, split into the vol% of each solid phase.

**Eruption:** cumulative volumes; erupted trace elements; zircon age spectra (Section 19).

**Animations:** the temperature, material, melt-fraction and calculation maps, the TAS diagram and the cumulate log
also have a "Save gif" button. It renders the figure at every stored output with the active display options (grid,
outline, isotherms, probe and pie unit), the time series cut at each output time (so the TAS chamber path grows),
all frames at one size, and writes an animated GIF to the output folder with `gif_frame_ms` per frame.

**Save and load simulations:** above the output selector, "Save simulation" writes the current run (every stored
output, the time series and the options) to `saved_states/mageres_runs/<name>.jld2`; "Load simulation" reads it back
as a finished run, so every result tab, the output selector and the exports work as after a live run, and the
configuration panel is restored to the run's options. Saved states leave out MAGEMin initial guesses and the compiled
trace-element partition functions, which are only needed while computing.

**Resume simulation:** below "Load simulation", "Resume simulation" continues the current run (finished, cancelled or
loaded) up to the run time set in the configuration panel. All other options stay those of the run.
- The run continues from the full state taken at the end of the run (or at its last output, for a run saved while it
  was still running). Outputs keep the same interval and are appended to the run.
- MAGEMin is re-initialised. A loaded run's partition functions are rebuilt, and its MAGEMin initial guesses (not
  saved) start empty.
- Zircon age bins are extended to cover the new run time. Nucleation epochs (families) keep the original spacing, and
  grains nucleated after the original end join the open-ended last family.
- Simulations saved before resume support hold no per-cell zircon. They resume from their last output with the
  chamber and host zircon restarted empty (erupted zircon is kept), and the run status notes it.
- With constant properties, a resumed run is identical to an uninterrupted one.

**Export:** every figure has an "Export svg" button that writes a layered, editable SVG to the app's output folder,
with the selected output time in the file name. Maps are exported with the true model cells (one rectangle per
quadtree cell, mirrored across the symmetry axis) instead of the screen image, with the grid, isotherms, chamber
outline, logs, legend, colour bar and probe pie as vector layers.

**Compositions:** injected magma, chamber bulk and erupted magma over time (mol%; erupted magma on an anhydrous
basis). A total alkali–silica (TAS) diagram, in anhydrous wt%, shows the three together. Injected and erupted batches
appear as symbols and the chamber as a path coloured by time.

---

## 23. Constant-property mode

With `thermodynamics = constant`, MAGEMin is not used. Magma and host have fixed density, heat capacity and
conductivity (`rho_*`, `cp_*`, `k_*`). The content per unit volume is $(\rho c_p T_K,\; \rho c_p,\; \rho c_p T_K,\; \mathbf n)$.
The model then only solves conduction, chamber growth and the remap. There is no melting, settling, percolation or
eruption. This mode is fast and useful to look at the thermal and geometric behaviour alone.

---

## 24. Parameters

The whole configuration can be saved and reloaded from the Configuration panel ("Save configuration" / "Load
configuration"). This includes every option below, the database, the magma, host and injection bulk-rock
compositions, the "Same as magma" switch and the three trace-element compositions. Each configuration is a JSON file
in `saved_states/mageres/` (`mageres_save_options` / `mageres_load_options`).

**Model geometry**

| Option | Default | Meaning |
|---|---|---|
| `domain_width_km` | 20 | width of the full section |
| `domain_thickness_km` |  30  | depth of the model bottom |
| `grid_h_max_m` | 1000 | coarsest cell size |
| `grid_h_min_m` |  62.5  | finest cell size |
| `grid_grading` | 0.25 | growth of cell size with distance from the chamber |
| `lens_length_km` | 5 | chamber length $L$ |
| `lens_depth_km` |  24  | depth of the chamber centre |
| `lens_shape` | ellipse | ellipse or parabola |
| `lens_n_segments` | 32 | number of station segments |
| `opening_mode` | split | roof/floor share of the opening |

**Model properties**

| Option | Default | Meaning |
|---|---|---|
| `database` | ig | MAGEMin database |
| `magma_bulk`, `host_bulk`, `injection_bulk` | tonalite, wet basalt, = magma | bulk compositions (mol) |
| `thermodynamics` | magemin | magemin or constant |
| `T_surface_C` | 15 | surface temperature |
| `geotherm_gradient_C_km` |  20  | geothermal gradient |
| `k_magma`, `k_host` | 2.0, 2.5 | conductivities |
| `rho_*`, `cp_*` | 2600/2800, 1200/1000 | constant-mode properties only |

**Injection**

| Option | Default | Meaning |
|---|---|---|
| `injection_period_yr` | 1000 | time between injections |
| `first_injection_yr` | 0 | first injection |
| `T_injection_C` |  1200  | injection temperature |
| `lens_thickness_m` | 100 | thickness of each injected lens at its centre |
| `injection_target` | body | mobile body (sill in place if none) or in place |
| `injection_melt_only` | off | inject the bulk as defined, or only its equilibrated melt |

**Eruption and melt segregation**

| Option | Default | Meaning |
|---|---|---|
| `phi_lock` |  0.4  | lock-up melt fraction |
| `phi_perc` | 0.07 | melt connectivity threshold |
| `phi_erupt` |  0.6  | eruptible mean melt fraction of the body |
| `erupt_frac` |  0.2  | erupted fraction of the body volume per event |
| `erupt_crystal_frac` |  1  | erupted crystal fraction χ (0 melt only, 1 bulk) |
| `fluid_treatment` | removed | free fluid removed or retained |
| `eruption_trigger` | melt | melt fraction, or overpressure (Section 18) |
| `dP_crit_MPa` | 20 | critical overpressure |
| `host_shear_modulus_GPa` | 10 | wall-rock shear modulus |
| `host_visc_A_Pas`, `host_visc_G_kJ` | 4.25e7, 141 | wall-rock viscosity law |
| `recharge_time_yr` | 0 | time over which an injection pressurises the chamber (0 = injection period) |
| `shell_thickness_m` | 0 | wall-rock shell used for the effective viscosity (0 = equivalent chamber radius) |

**Settling and compaction**

| Option | Default | Meaning |
|---|---|---|
| `crystal_size_mm` |  5  | crystal size (settling and permeability) |
| `hindered_exponent` | 4.65 | Richardson–Zaki exponent |

**Solver**

| Option | Default | Meaning |
|---|---|---|
| `run_time_yr` |  100000  | total time |
| `output_every_yr` | 1000 | output interval |
| `thermal_dt_yr` | 100 | timestep |
| `thermal_bc` | surface | surface or insulated |
| `dT_tol` | 5 | re-equilibration temperature tolerance (°C) |
| `dX_tol` |  0.001  | re-equilibration composition tolerance |
| `subsolidus_T_C` | 600 | below this, melt-free cells are not recomputed |
| `boost_mode` | off | initial guesses for host rock |
| `Ra_crit`, `Nu_exponent` | 1000, 1/3 | convection law |
| `g` | 9.81 | gravity |

**Trace elements and zircon** (Section 19)

| Option | Default | Meaning |
|---|---|---|
| `te_enabled` | off | carry trace elements |
| `kds_mod` | OL | KD model (OL, CO, Yak25) |
| `zrsat_mod` | B | Zr saturation model (none, WH, B, CB); none disables zircon |
| `te_elements`, `te_injection_ppm`, `te_host_ppm` | tonalite / basalt | element list and injected and host compositions (µg/g) |
| `zircon_age_bin_yr` | 1000 | width of the zircon age bins |
| `zircon_nucleation_density` | 1e8 | grains nucleated per m³ of melt |
| `zircon_host_radius_um` | 50 | radius of the inherited host-rock zircon |
| `zircon_inherited_age_Ma` | 300 | age shown for inherited zircon |
| `zircon_synthetic_grains` | 100 | synthetic single spots and zoned grains drawn per eruption |
| `zircon_families` | 6 | zircon families: inherited + nucleation epochs |
| `zircon_spot_um` | 20 | analytical spot diameter |
| `zircon_method` | SIMS U-Th | dating method setting the analytical uncertainty (SIMS U-Th, LA-ICP-MS U-Pb, CA-ID-TIMS U-Pb) |
| `zircon_sigma_kyr` | 3 | SIMS U-Th 1σ |
| `zircon_eruption_age_Ma` | 1 | absolute age of the latest output, used for the relative U-Pb uncertainties |

**Internal constants**

| Constant | Value | Role |
|---|---|---|
| symmetry factor $S$ | 2 | half-domain → full section |
| heat-capacity cap for conduction | 3000 J/kg/K | Section 11 |
| apparent $c_p$ clamp | 300–50 000 J/kg/K | Section 11 |
| temperature correction limit | ±200 K | Section 11 |
| boost: max composition shift | 0.02 | Section 11 |
| melt-front flag | 0.05 in melt fraction | Section 9 |
| cell equilibration | ≤ 3 iterations, 1 K | Section 12 |
| body mixing | ≤ 8 iterations, 0.05 K, steps ≤ 200 K | Section 12 |
| routing swap cap | 0.5 of the body area | Section 12 |
| mobile body: chamber fraction | ≥ 0.5 | Section 13 |
| cumulate label threshold | 0.5 | Section 16 |
| unlock margin | 0.05 above φ_lock | Section 16 |
| Kozeny–Carman constant | 270 | Section 17 |
| eruption caps | 0.5 of the chamber, 0.95 of the melt | Section 18 |
| slumping passes | ≤ 50 | Section 15 |
| zircon density, Zr fraction | 4650 kg/m³, 0.497644 | Section 19 |
| zircon nucleus radius | 1 µm | Section 19 |
| zircon sub-step limit | 30 % mass change, ≤ 1000 sub-steps | Section 19 |
| zircon follows the melt below | $w_S \le 10^{-3}$ | Section 19 |

---

## 25. Assumptions and limitations

- **Two-dimensional, plane-strain.** Areas stand for volumes per unit length out of plane. Comparisons with 3-D
  volumes need an assumed third dimension.
- **No resolved flow.** Magma convection is parameterised (k·Nu); crystal and melt motions are prescribed transfer
  laws (Stokes, Darcy), not solutions of the momentum equations. The host rock deforms only by the prescribed column
  shear; there is no elasticity, fracturing or stoping.
- **Prescribed geometry.** The chamber keeps its self-similar shape (ellipse or parabola) and stays centred; new magma
  always enters at the centre plane.
- **Homogenised body.** The mobile body is fully mixed at each injection; layering or double-diffusive convection
  within it is not represented.
- **Equilibrium thermodynamics.** Each cell is at equilibrium at its own $T$ and $P$, with no kinetics or
  undercooling. Fractionation arises only from the physical separation of phases (settling, percolation, eruption,
  degassing).
- **Simplified compaction.** Matrix deformation is represented by crystal–melt exchange between neighbouring cells
  at the Darcy rate; the compaction length and matrix viscosity are not modelled.
- **Grid resolution.** A sill thinner than $h_{min}$ shares its cells with older material, which speeds up its early
  cooling.
- **Assimilation.** Host rock enters the chamber only as percolated melt; bulk assimilation of wall rock is not
  modelled.
- **Trace elements.** Partitioning is at equilibrium with the KD model at each MAGEMin point; when fluid is present
  its share of the mass is lumped with the crystals in the `TE_prediction` ratio. Zircon does not feed back on the
  major elements (its SiO₂ is ignored, about 0.03 wt% of the magma for 200 ppm Zr).
- **Zircon.** One mean grain radius per family and cell (no size distribution within a family); grains do not
  settle on their own; per-cell zircon is not kept in the stored outputs (the zircon figures use the eruption
  records); the
  saturation models were calibrated mostly on felsic melts (Zhang & Xu 2016 find the Boehnke model to be the best
  general choice); ages are model times, not U–Pb ages, and do not include analytical scatter.

---

## 26. References

- Annen, C. (2009). From plutons to magma chambers: thermal constraints on the accumulation of eruptible silicic
  magma in the upper crust. *Earth and Planetary Science Letters*, 284, 409–416.
  [doi:10.1016/j.epsl.2009.05.006](https://doi.org/10.1016/j.epsl.2009.05.006)
- Annen, C., Blundy, J. D., & Sparks, R. S. J. (2006). The genesis of intermediate and silicic magmas in deep crustal
  hot zones. *Journal of Petrology*, 47, 505–539. [doi:10.1093/petrology/egi084](https://doi.org/10.1093/petrology/egi084)
- Bachmann, O., & Bergantz, G. W. (2004). On the origin of crystal-poor rhyolites: extracted from batholithic crystal
  mushes. *Journal of Petrology*, 45, 1565–1582. [doi:10.1093/petrology/egh019](https://doi.org/10.1093/petrology/egh019)
- Boehnke, P., Watson, E. B., Trail, D., Harrison, T. M., & Schmitt, A. K. (2013). Zircon saturation re-visited.
  *Chemical Geology*, 351, 324–334. [doi:10.1016/j.chemgeo.2013.05.028](https://doi.org/10.1016/j.chemgeo.2013.05.028)
- Bohrson, W. A., Spera, F. J., Ghiorso, M. S., Brown, G. A., Creamer, J. B., & Mayfield, A. (2014). Thermodynamic
  model for energy-constrained open-system evolution of crustal magma bodies undergoing simultaneous recharge,
  assimilation and crystallization: the Magma Chamber Simulator. *Journal of Petrology*, 55, 1685–1717.
  [doi:10.1093/petrology/egu036](https://doi.org/10.1093/petrology/egu036)
- Burgisser, A., & Bergantz, G. W. (2011). A rapid mechanism to remobilize and homogenize highly crystalline magma
  bodies. *Nature*, 471, 212–215. [doi:10.1038/nature09799](https://doi.org/10.1038/nature09799)
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
- Marsh, B. D. (1981). On the crystallinity, probability of occurrence, and rheology of lava and magma.
  *Contributions to Mineralogy and Petrology*, 78, 85–98. [doi:10.1007/BF00371146](https://doi.org/10.1007/BF00371146)
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
- Rosenberg, C. L., & Handy, M. R. (2005). Experimental deformation of partially melted granite revisited:
  implications for the continental crust. *Journal of Metamorphic Geology*, 23, 19–28.
  [doi:10.1111/j.1525-1314.2005.00555.x](https://doi.org/10.1111/j.1525-1314.2005.00555.x)
- Schmitt, A. K. (2011). Uranium series accessory crystal dating of magmatic processes. *Annual Review of Earth and
  Planetary Sciences*, 39, 321–349. [doi:10.1146/annurev-earth-040610-133330](https://doi.org/10.1146/annurev-earth-040610-133330)
- Shirley, D. N. (1986). Compaction of igneous cumulates. *The Journal of Geology*, 94, 795–809.
  [doi:10.1086/629088](https://doi.org/10.1086/629088)
- Sutherland, I. E., & Hodgman, G. W. (1974). Reentrant polygon clipping. *Communications of the ACM*, 17, 32–42.
  [doi:10.1145/360767.360802](https://doi.org/10.1145/360767.360802)
- Tegner, C., Thy, P., Holness, M. B., Jakobsen, J. K., & Lesher, C. E. (2009). Differentiation and compaction in the
  Skaergaard intrusion. *Journal of Petrology*, 50, 813–840. [doi:10.1093/petrology/egp020](https://doi.org/10.1093/petrology/egp020)
- Turcotte, D. L., & Schubert, G. (2014). *Geodynamics* (3rd ed.). Cambridge University Press.
  [doi:10.1017/CBO9780511843877](https://doi.org/10.1017/CBO9780511843877)
- Vermeesch, P. (2012). On the visualisation of detrital age distributions. *Chemical Geology*, 312–313, 190–194.
  [doi:10.1016/j.chemgeo.2012.04.021](https://doi.org/10.1016/j.chemgeo.2012.04.021)
- Wark, D. A., & Watson, E. B. (1998). Grain-scale permeabilities of texturally equilibrated, monomineralic rocks.
  *Earth and Planetary Science Letters*, 164, 591–605.
  [doi:10.1016/S0012-821X(98)00252-0](https://doi.org/10.1016/S0012-821X(98)00252-0)
- Watson, E. B., & Harrison, T. M. (1983). Zircon saturation revisited: temperature and composition effects in a
  variety of crustal magma types. *Earth and Planetary Science Letters*, 64, 295–304.
  [doi:10.1016/0012-821X(83)90211-X](https://doi.org/10.1016/0012-821X(83)90211-X)
- Zhang, Y., & Xu, Z. (2016). Zircon saturation and Zr diffusion in rhyolitic melts, and zircon growth
  geospeedometer. *American Mineralogist*, 101, 1252–1267. [doi:10.2138/am-2016-5462](https://doi.org/10.2138/am-2016-5462)
