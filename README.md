# MAGEMin_app.jl

`MAGEMin_app.jl` provides a web-based graphical user interface for `MAGEMin`, with which you can create phase diagrams.

> [!CAUTION]
> As of now, this remains under development and has not yet been officially released. We recommend to not use it for publications yet.

### Installation

You can install this with:
```julia
julia>]
pkg> add https://github.com/ComputationalThermodynamics/MAGEMin_app
```

### Running

And start it with:
```julia
julia>using MAGEMin_app
julia>App()
[ Info: Listening on: 127.0.0.1:8050, thread id: 2
```
Next you can open [127.0.0.1:8050](127.0.0.1:8050) in your favorite browser.