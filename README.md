# MAGEMin_app.jl

`MAGEMin_app.jl` provides a web-based graphical user interface for `MAGEMin`, with which you can create phase diagrams.

> [!CAUTION]
> As of now, this remains under development and has not yet been officially released. We recommend to not use it for publications yet. The precompiled binaries will work on various systems, but details will only be given in an upcoming publication, after which we will make an official release. 

### Installation

To install this, please install the local versions of `MAGEMin_jll` and `MAGEMin_C` first, after which you can install the app itself
```julia
julia>]
pkg> add https://github.com/boriskaus/MAGEMin_jll.jl
pkg> add https://github.com/boriskaus/MAGEMin_C.jl
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



### Development

In case your first name is Nico and you want to use a locally developed library, you need to checkout a local development version of `MAGEMin_C`
```julia
julia>]
pkg> rm MAGEMin_C
pkg> dev https://github.com/boriskaus/MAGEMin_C.jl
```
You'll need to compile a new dynamic library for your system within the `TC_calibration` folder, place yourself in `~/.julia/dev/MAGEMin_C` and copy the following files over: 
```
cp -r ~/TC_calibration/gen .
cp -r ~/TC_calibration/test .
cp -r ~/TC_calibration/julia .
```
