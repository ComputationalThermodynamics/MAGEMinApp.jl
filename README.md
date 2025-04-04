
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://computationalthermodynamics.github.io/MAGEMin_C.jl/dev/)
[![Build Status](https://github.com/ComputationalThermodynamics/MAGEMinApp.jl/workflows/CI/badge.svg)](https://github.com/ComputationalThermodynamics/MAGEMinApp.jl/actions)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14605704.svg)](https://doi.org/10.5281/zenodo.14605704)
# MAGEMinApp.jl

<img src="https://raw.githubusercontent.com/ComputationalThermodynamics/repositories_pictures/main/MAGEMinApp/MAGEMin_app.png?raw=true" alt="drawing" width="820" alt="centered image"/>


`MAGEMinApp.jl` provides an easy-to-use web-based graphical user interface for `MAGEMin`. Available features:

1. Compute Pressure-Temperature iso-chemical phase diagrams (P-T phase diagrams)
2. Compute Pressure and/or Temperature versus variable composition diagrams (P-X, T-X, PT-X phase diagrams)
3. Display iso-contour of phase fractions, densities, seismic velocities etc.
4. Automatic labeling of the phase fields including listing the stable phase assemblage when the field is too small.
5. Compute Pressure-Temperature path diagrams for fractional melting and crystallization.
6. Save generated diagrams/figures as vector files (svg format).
7. Export single point and whole grid information as table (ascii format)

As for `MAGEMin`, you can choose among several thermodynamic dataset: Metapelite (White et al., 2014), Metabasite (Green et al., 2016), Igneous (Holland et al., 2018) or Ultramafic (Evans & Frost, 2021).

## Available thermodynamic database

### Published
- `mp`; `MnNCKFMASHTO` -> metapelite, White et al. (2014)
- `mb`; `MnNCKFMASHTO` -> metabasite, Green et al. (2016)
- `ig`; `NCKFMASHTOCr` ->  igneous, Green et al. (2025) corrected after Holland et al. (2018)
- `igad`; `NCKFMASTOCr` ->  igneous alkaline dry, Weller et al. (2024)
- `um`; `FMASHOS` -> ultramafic, Frost & Evans (2021)
- `mtl`; `NCFMAS` -> mantle to upper lowermost mantle, Holland et al. (2013)

### Custom
- `ume`; `FMASHOS` ->  ultramafic extended, Frost & Evans (2021) + Green et al., (2016)
- `mpe`; `CO2MnNCKFMASHTS` -> metapelite extended , White et al. (2014) + Green et al. (2016) (hb, dio, aug) + Frost & Evans (2021) (po, fl) + Franzolin et al. (2011) (occm).

> [!CAUTION]
> Custom/Hybrid database are provided in the hope it may be useful for advanced users. In most cases it is recommenced to use the official published database.

### Installation

To install MAGEMinApp:
```julia
julia>]         # opens package manager in Julia
pkg> add MAGEMinApp
```
> [!IMPORTANT] 
> Make sure you have the last version installed!

### Update to newest version

If you have a previous version of MAGEMinApp installed, the easiest way to update MAGEMinApp is the following:

```julia
julia>]
pkg> rm MAGEMinApp      # First remove MAGEMinApp
pkg> rm MAGEMin_C       # In case you also use MAGEMin_C this needs to be removed first before updating it, as MAGEMinApp is locked on the last version of MAGEMin_C
pkg> update             # update the repository
pkg> add MAGEMinApp     # reinstall MAGEMin
pkg> up MAGEMinApp      # sometimes needed to update to the last version
(pkg> add MAGEMin_C)    # If you want to have MAGEMin_C too
```

If you cannot update to the last MAGEMinApp version, try to set the Julia registry to "eager" using the following command, then redo the update process.

```julia
julia> ENV["JULIA_PKG_SERVER_REGISTRY_PREFERENCE"] = "eager"
```

### Running MAGEMinApp

And start it with:
```julia
julia> using MAGEMinApp
julia> App()
[ Info: Listening on: 127.0.0.1:8050, thread id: 2
```
Next you can open [127.0.0.1:8050](127.0.0.1:8050) in your favorite browser, which will launch the App.

### How to load custom bulk-rock composition

MAGEMinApp is designed is such a way that bulk-rock composition must be entered in a `*.dat` file and loaded in the simulation tab. An example of valid bulk-rock composition file is given in `examples/bulk-rock_ref.dat`

* Commented lines must start with a `#`
* Bulk-rock composition line must contain `title; comments; db; sysUnit; oxide; frac; frac2`
* A valid example of bulk-rock composition entry is for instance:\
`title; comments; db; sysUnit; oxide; frac; frac2`\
`Test 2;Moo et al., 2000;ig;mol;[SiO2, Al2O3, CaO, MgO, FeO, K2O, Na2O, TiO2, O, Cr2O3, H2O];[48.97, 11.76, 13.87, 4.21, 8.97, 1.66, 10.66, 1.36, 1.66, 0.0, 5.0];`\

> [!IMPORTANT] 
> `db` must be either `mp` (metapelite, White et al., 2014), `mb` (metabasite, Green et al., 2016), `ig` (igneous, Holland et al., 2018), `um` (ultramafic, Frost & Evans, 2021), `ume` (ultramafic extended, Frost & Evans, 2021 + Green et al., 2016), `mtl` (mantle to upper lowermost mantle, Holland et al., 2013) or `mpe` (metapelite extended, White et al., 2014 + Green et al., 2016, Frost & Evans, 2021).
> 
> `sysUnit` must be `mol` or `wt`. Note that if `wt` is provided, the composition is converted and subsequently displayed in `mol` in `MAGEMinApp`.
> 
> `oxide` is the **complete** list of oxides of the selected database. You are not allowed to leave oxides out. If you don't need all oxides of the database simply set them to 0.0. Note, that either `FeO` and `O` **or** `FeO` and `Fe2O3` can be provided. In the first case `FeO` = `FeOt`.
> 
> `frac` is the `sysUnit` proportion of oxides. Set the oxide content to 0.0 to reduce the chemical system. If possible, the calculation will be performed in a fully reduced chemical system, otherwise a low value will be automatically set (around 0.01 `mol%`). Generally, `TiO2`, `Cr2O3`, `MnO`, `O` and `H2O` can be effectively set to 0.0.
> 
> `frac2` is used only when computing T-X or P-X diagrams.


### Remarks

> [!TIP]
> For Windows machine you can launch a multi-threaded (parallel) version of the Julia terminal (to perform computation in parallel using `MAGEMinApp`) by creating a `Julia_parallel.cmd` file and adding the following lines (changing `8` to the number of threads your machine can support (type `versioninfo()` in a Julia terminal)). Then save the changes and execute  `Julia_parallel.cmd`.
```
set JULIA_NUM_THREADS=8
C:\YOUR_PATH_TO_JULIA\bin\julia.exe
```

> [!CAUTION]
> As of now, `MAGEMinApp.jl` remains under development and the current release is a beta version. Reporting issues, potential improvement and contributions are most welcome.

> [!IMPORTANT] 
> In the simulation tab, bulk-rock composition are displayed in mol fraction. When using a bulk-rock composition file and the system unit is wt%, the bulk-rock are loaded and converted to mol%.

> [!IMPORTANT] 
> When computing PTX paths (fractional crystalllization or melting), if an oxide reaches low concentration (< 1e-5 mol fraction) and if this oxide can effectively be set to 0.0, MAGEMinApp will automatically set it to 0.0. Conversely if the same oxide cannot be put to 0.0 with the current solution phase formulation, it will be set to 1e-5. This ensures stability of the algorithm.

