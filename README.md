# MAGEMin_app.jl

`MAGEMin_app.jl` provides an easy-to-use web-based graphical user interface for `MAGEMin`. Available features:

1. Compute Pressure-Temperature iso-chemical phase diagrams (PT phase diagrams)
2. Compute Pressure or Temperature versus variable composition diagrams (PX, TX phase diagrams)
3. Display iso-contour of phase fractions, densities, seismic velocities etc.
4. Automatic labeling of the phase fields including listing the stable phase assemblage when the field is too small.
5. Compute Pressure-Temperature path diagrams for fractional melting and crystallization.
6. Save generated diagrams/figures as vector files (svg format).
7. Export single point and whole grid information as table (ascii format)

As for `MAGEMin`, you can choose among several thermodynamic dataset: Metapelite (White et al., 2014), Metabasite (Green et al., 2016), Igneous (Holland et al., 2018) or Ultramafic (Evans & Frost, 2021).

> [!CAUTION]
> As of now, `MAGEMin_app.jl` remains under development and the current release is a beta version. Reporting issues, potential improvement and contributions are most welcome.

### Installation

To install this, please install the local versions of `MAGEMin_jll` and `MAGEMin_C` first, after which you can install the App itself
```julia
julia>]
pkg> add MAGEMin_app
```

### Running

And start it with:
```julia
julia>using MAGEMin_app
julia>App()
[ Info: Listening on: 127.0.0.1:8050, thread id: 2
```
Next you can open [127.0.0.1:8050](127.0.0.1:8050) in your favorite browser, which will launch the App.


