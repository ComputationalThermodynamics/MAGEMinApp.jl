#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

"""
Functions for building IntersecT-compatible DataFrames from MAGEMinApp phase diagram data.

The main entry point is `build_intersect_model_df`, which converts the global `Out_XY`
vector into the model DataFrame expected by IntersecT.run_intersect.

Workflow:
    model_df = build_intersect_model_df(Out_XY, ["Grt_Mg", "Grt_Ca", "Bt_Fe"])
    result   = IntersecT.run_intersect(model_df, measurements_df;
                   x_col="T(C)", y_col="P(kbar)", analysis_type="WDS spot")
"""

# Maps oxide column names (as stored in Out_XY[i].oxides) to element symbols
# used in IntersecT "Phase_Element" column headers.
const OXIDE_TO_ELEMENT = Dict(
    "SiO2"  => "Si",
    "Al2O3" => "Al",
    "TiO2"  => "Ti",
    "FeO"   => "Fe",
    "Fe2O3" => "Fe",
    "MgO"   => "Mg",
    "MnO"   => "Mn",
    "CaO"   => "Ca",
    "Na2O"  => "Na",
    "K2O"   => "K",
    "H2O"   => "H",
    "O"     => "O",
    "Cr2O3" => "Cr",
    "NiO"   => "Ni",
    "P2O5"  => "P",
    "CO2"   => "C",
    "S"     => "S",
    "F2O"   => "F",
    "Cl2O"  => "Cl",
)

"""
    build_intersect_model_df(Out_XY, phase_elements;
                             x_col="T(C)", y_col="P(kbar)") -> DataFrame

Build a model DataFrame in IntersecT format directly from MAGEMinApp's `Out_XY` data.

# Arguments
- `Out_XY`         : global vector of MAGEMin_C.gmin_struct results (one entry per grid point)
- `phase_elements` : Vector of `"Phase_Element"` strings to extract, e.g. `["Grt_Mg", "Grt_Ca"]`.
                     Phase names must match entries in `Out_XY[i].ph` exactly.
                     Element names must be symbols (e.g. `"Mg"`, `"Ca"`, `"Fe"`) that map
                     to oxides in `Out_XY[i].oxides` via the OXIDE_TO_ELEMENT table.
- `x_col`          : column header for the x-coordinate (default `"T(C)"`)
- `y_col`          : column header for the y-coordinate (default `"P(kbar)"`)

# Returns
DataFrame with columns [x_col, y_col, phase_elements...].
T values come from `Out_XY[i].T_C` (°C) and P from `Out_XY[i].P_kbar` (kbar).
Grid points where a requested phase is absent receive `NaN` for that phase's elements.

# Example
```julia
model_df = build_intersect_model_df(Out_XY, ["Grt_Mg", "Grt_Ca", "Grt_Fe", "Bt_Fe"])
result   = IntersecT.run_intersect(model_df, measurements_df;
               x_col="T(C)", y_col="P(kbar)", analysis_type="WDS spot")
```
"""
function build_intersect_model_df(
    Out_XY        :: Vector,
    phase_elements :: Vector{String};
    x_col          :: String = "T [Celsius]",
    y_col          :: String = "P [kbar]"
)::DataFrame

    isempty(Out_XY)        && error("Out_XY is empty — compute a phase diagram first")
    isempty(phase_elements) && error("phase_elements must not be empty")

    n_points = length(Out_XY)
    n_cols   = length(phase_elements)
    oxides   = Out_XY[1].oxides   # same list for every grid point

    # Build element-symbol → oxide index lookup from the grid's oxide list.
    # If two oxides map to the same element (e.g. FeO and Fe2O3 → Fe), the first
    # occurrence wins; the user can disambiguate by requesting separate columns.
    elem_to_ox_idx = Dict{String, Int}()
    for (k, ox) in enumerate(oxides)
        elem = get(OXIDE_TO_ELEMENT, String(ox), nothing)
        isnothing(elem)              && continue
        haskey(elem_to_ox_idx, elem) && continue
        elem_to_ox_idx[elem] = k
    end

    # Parse and validate "Phase_Element" strings
    parsed = Vector{Tuple{String, String}}(undef, n_cols)
    for (j, pe) in enumerate(phase_elements)
        parts = split(pe, "_"; limit=2)
        length(parts) == 2 ||
            error("Expected 'Phase_Element' format (e.g. 'Grt_Mg'), got: \"$pe\"")
        ph, el = String(parts[1]), String(parts[2])
        haskey(elem_to_ox_idx, el) ||
            error("Element \"$el\" (from \"$pe\") not found in oxide list: $(join(oxides, ", "))\n" *
                  "Known elements: $(join(sort(collect(keys(elem_to_ox_idx))), ", "))")
        parsed[j] = (ph, el)
    end

    # Allocate output (NaN = phase absent or element not applicable)
    T_vec       = Vector{Float64}(undef, n_points)
    P_vec       = Vector{Float64}(undef, n_points)
    data_matrix = fill(NaN, n_points, n_cols)

    for i in 1:n_points
        T_vec[i] = Out_XY[i].T_C
        P_vec[i] = Out_XY[i].P_kbar

        ph_list = Out_XY[i].ph
        n_SS    = Out_XY[i].n_SS

        for (j, (ph, el)) in enumerate(parsed)
            # Match against Warr-converted names so "Grt" finds "g" in ph_list, etc.
            idx = findfirst(k -> display_ph_name(String(ph_list[k])) == ph, 1:length(ph_list))
            isnothing(idx) && continue   # phase absent at this point -> stays NaN

            ox_idx   = elem_to_ox_idx[el]
            apfu_vec = idx <= n_SS ?
                Out_XY[i].SS_vec[idx].Comp_apfu :
                Out_XY[i].PP_vec[idx - n_SS].Comp_apfu

            v = apfu_vec[ox_idx]
            data_matrix[i, j] = (ismissing(v) || (v isa Number && isnan(Float64(v)))) ?
                NaN : Float64(v)
        end
    end

    # Assemble DataFrame
    df = DataFrame(x_col => T_vec, y_col => P_vec)
    for (j, pe) in enumerate(phase_elements)
        df[!, pe] = data_matrix[:, j]
    end

    return df
end

"""
    list_intersect_phases(Out_XY) -> Vector{String}

Return the set of solution-phase names that appear in at least one grid point,
sorted alphabetically. Useful for choosing which phases to pass to
`build_intersect_model_df`.
"""
function list_intersect_phases(Out_XY::Vector)::Vector{String}
    isempty(Out_XY) && return String[]
    seen = Set{String}()
    for i in 1:length(Out_XY)
        for (k, ph) in enumerate(Out_XY[i].ph)
            k <= Out_XY[i].n_SS && push!(seen, String(ph))
        end
    end
    return sort(collect(seen))
end

"""
    list_intersect_elements(Out_XY) -> Vector{String}

Return the element symbols available in the grid's oxide list (as used in
"Phase_Element" column headers), sorted alphabetically.
"""
function list_intersect_elements(Out_XY::Vector)::Vector{String}
    isempty(Out_XY) && return String[]
    elems = String[]
    seen  = Set{String}()
    for ox in Out_XY[1].oxides
        elem = get(OXIDE_TO_ELEMENT, String(ox), nothing)
        if !isnothing(elem) && !(elem in seen)
            push!(elems, elem)
            push!(seen, elem)
        end
    end
    return sort(elems)
end

"""
    make_measurements_df(phase_elements, apfu_values; uncertainties=nothing) -> DataFrame

Convenience constructor for the measurements DataFrame expected by IntersecT.

# Arguments
- `phase_elements` : Vector{String} of "Phase_Element" labels, same order as `apfu_values`
- `apfu_values`    : Vector{Float64} of observed a.p.f.u. values (one per element)
- `uncertainties`  : Vector{Float64} of analytical uncertainties, or `nothing` to let
                     IntersecT calculate them automatically from `analysis_type`

# Returns
DataFrame with 2 rows: row 1 = observed values, row 2 = uncertainties (NaN if auto).

# Example
```julia
meas_df = make_measurements_df(
    ["Grt_Mg", "Grt_Ca", "Grt_Fe"],
    [1.20,      0.80,     0.95],
    uncertainties = [0.05, 0.04, 0.04]
)
```
"""
function make_measurements_df(
    phase_elements :: Vector{String},
    apfu_values    :: Vector{Float64};
    uncertainties  :: Union{Vector{Float64}, Nothing} = nothing
)::DataFrame

    length(phase_elements) == length(apfu_values) ||
        error("phase_elements and apfu_values must have the same length")

    if !isnothing(uncertainties)
        length(uncertainties) == length(apfu_values) ||
            error("uncertainties must have the same length as apfu_values")
        err_row = uncertainties
    else
        err_row = fill(NaN, length(apfu_values))
    end

    df = DataFrame([pe => [apfu_values[j], err_row[j]] for (j, pe) in enumerate(phase_elements)])
    return df
end
