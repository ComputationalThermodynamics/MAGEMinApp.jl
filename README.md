[![Build Status](https://github.com/ComputationalThermodynamics/MAGEMinApp.jl/workflows/CI/badge.svg)](https://github.com/ComputationalThermodynamics/MAGEMinApp.jl/actions)

> [!CAUTION]
> As of now, `MAGEMinApp.jl` remains under development and the current release is a beta version. Reporting issues, potential improvement and contributions are most welcome.

> [!CAUTION]
> There is still some issues with Windows machine. `] add MAGEMinApp` works well, however when `using MAGEMinApp` it may hang indefinitely. Currently, the workaround is to cancel `CTRL+C` and try `using MAGEMinApp` a couple of time.

> [!TIP]
> For Windows machine you can launch a threaded version of the Julia terminal (to perform computation in parallel using `MAGEMinApp`) by creating a `Julia_parallel.cmd` file and adding:
```
set JULIA_NUM_THREADS=8
C:\YOUR_PATH_TO_JULIA\bin\julia.exe
```
> Save the changes and execute the `Julia_parallel.cmd`


# MAGEMinApp.jl

<img src="https://raw.githubusercontent.com/ComputationalThermodynamics/repositories_pictures/main/MAGEMinApp/MAGEMin_app.png?raw=true" alt="drawing" width="820" alt="centered image"/>


`MAGEMinApp.jl` provides an easy-to-use web-based graphical user interface for `MAGEMin`. Available features:

1. Compute Pressure-Temperature iso-chemical phase diagrams (PT phase diagrams)
2. Compute Pressure or Temperature versus variable composition diagrams (PX, TX phase diagrams)
3. Display iso-contour of phase fractions, densities, seismic velocities etc.
4. Automatic labeling of the phase fields including listing the stable phase assemblage when the field is too small.
5. Compute Pressure-Temperature path diagrams for fractional melting and crystallization.
6. Save generated diagrams/figures as vector files (svg format).
7. Export single point and whole grid information as table (ascii format)

As for `MAGEMin`, you can choose among several thermodynamic dataset: Metapelite (White et al., 2014), Metabasite (Green et al., 2016), Igneous (Holland et al., 2018) or Ultramafic (Evans & Frost, 2021).


### Installation

To install this, please install the local versions of `MAGEMin_jll` and `MAGEMin_C` first, after which you can install the App itself
```julia
julia>]
pkg> add MAGEMinApp
```

### Running

And start it with:
```julia
julia>using MAGEMinApp
julia>App()
[ Info: Listening on: 127.0.0.1:8050, thread id: 2
```
Next you can open [127.0.0.1:8050](127.0.0.1:8050) in your favorite browser, which will launch the App.

### How to load custom bulk-rock composition

MAGEMinApp is designed is such a way that bulk-rock composition must be entered in a `*.dat` file and loaded in the simulation tab. An example of how to properly structure a bulk-rock composition file is given in `examples/bulk-rock_ref.dat`

* Commented lines must start with a `#`
* Bulk-rock composition line must contain `title; comments; db; sysUnit; oxide; frac; frac2`
* A valid example of bulk-rock composition entry is for instance:\
`title; comments; db; sysUnit; oxide; frac; frac2`\
`Test 2;Moo et al., 2000;ig;mol;[SiO2, Al2O3, CaO, MgO, FeO, K2O, Na2O, TiO2, O, Cr2O3, H2O];[48.97, 11.76, 13.87, 4.21, 8.97, 1.66, 10.66, 1.36, 1.66, 0.0, 5.0];`\

> [!IMPORTANT] 
> `db` must be either `mp` (metapelite, White et al., 2014), `mb` (metabasite, Green et al., 2016), `ig` (igneous, Holland et al., 2018) or `um` (ultramafic, Frost & Evans, 2021).
> 
> `sysUnit` must be `mol` or `wt`. Note that if `wt` is provided, the composition is converted and subsequently displayed in `mol` in `MAGEMinApp`.
> 
> `oxide` is the **complete** list of oxides of the selected database. You are not allowed to leave oxides out. Note however that either `FeO` and `O` **or** `FeO` and `Fe2O3` can be provided. `FeO` = `FeOt`.
> 
> `frac` is the `sysUnit` proportion of oxides. Set the oxide content to 0.0 to reduce the chemical system. If possible, the calculation will be performed in a fully reduced chemical system, otherwise a low value will be automatically set (around 0.01 `mol%`).
> 
> `frac2` is used only when computing T-X or P-X diagrams.


