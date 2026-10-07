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

const MAGERES_IG_OXIDES    = ["SiO2", "Al2O3", "CaO", "MgO", "FeO", "K2O", "Na2O", "TiO2", "O", "Cr2O3", "H2O"]
const MAGERES_TONALITE_101 = [66.01, 11.98, 7.06, 4.16, 5.3, 1.57, 4.12, 0.66, 0.97, 0.01, 20.0]
const MAGERES_WET_BASALT   = [50.081, 8.6901, 11.6698, 12.1438, 7.7832, 0.215, 2.4978, 1.0059, 0.467, 0.01, 5.4364]

"""
    MAGEResOptions

    All user options of a MAGEMin Reservoir run: model geometry and grid, material properties and bulk
    compositions, injection, eruption, settling, solver setup and results display.
"""
Base.@kwdef mutable struct MAGEResOptions
    domain_width_km           :: Float64         = 20.0
    domain_thickness_km       :: Float64         = 30.0
    grid_h_max_m              :: Float64         = 1000.0
    grid_h_min_m              :: Float64         = 62.5
    grid_grading              :: Float64         = 0.25
    lens_length_km            :: Float64         = 5.0
    lens_thickness_m          :: Float64         = 100.0
    lens_depth_km             :: Float64         = 24.0
    lens_shape                :: String          = "ellipse"
    lens_n_segments           :: Int             = 32
    opening_mode              :: String          = "split"

    database                  :: String          = "ig"
    oxides                    :: Vector{String}  = copy(MAGERES_IG_OXIDES)
    magma_bulk                :: Vector{Float64} = copy(MAGERES_TONALITE_101)
    host_bulk                 :: Vector{Float64} = copy(MAGERES_WET_BASALT)
    injection_bulk            :: Vector{Float64} = Float64[]
    thermodynamics            :: String          = "magemin"
    T_surface_C               :: Float64         = 15.0
    geotherm_gradient_C_km    :: Float64         = 20.0
    rho_magma                 :: Float64         = 2600.0
    rho_host                  :: Float64         = 2800.0
    cp_magma                  :: Float64         = 1200.0
    cp_host                   :: Float64         = 1000.0
    k_magma                   :: Float64         = 2.0
    k_host                    :: Float64         = 2.5

    injection_period_yr       :: Float64         = 1000.0
    first_injection_yr        :: Float64         = 0.0
    T_injection_C             :: Float64         = 1200.0
    injection_target          :: String          = "body"
    injection_melt_only       :: Bool            = false

    phi_lock                  :: Float64         = 0.40
    phi_perc                  :: Float64         = 0.07
    phi_erupt                 :: Float64         = 0.60
    erupt_frac                :: Float64         = 0.20
    erupt_crystal_frac        :: Float64         = 1.0
    fluid_treatment           :: String          = "removed"
    eruption_trigger          :: String          = "melt"
    dP_crit_MPa               :: Float64         = 20.0
    host_shear_modulus_GPa    :: Float64         = 10.0
    host_visc_A_Pas           :: Float64         = 4.25e7
    host_visc_G_kJ            :: Float64         = 141.0
    recharge_time_yr          :: Float64         = 0.0
    shell_thickness_m         :: Float64         = 0.0

    crystal_size_mm           :: Float64         = 5.0
    hindered_exponent         :: Float64         = 4.65

    run_time_yr               :: Float64         = 100_000.0
    output_every_yr           :: Float64         = 1000.0
    thermal_dt_yr             :: Float64         = 100.0
    thermal_bc                :: String          = "surface"
    dT_tol                    :: Float64         = 5.0
    dX_tol                    :: Float64         = 1e-3
    subsolidus_T_C            :: Float64         = 600.0
    boost_mode                :: Bool            = false
    Ra_crit                   :: Float64         = 1000.0
    Nu_exponent               :: Float64         = 1.0/3.0
    g                         :: Float64         = 9.81

    te_enabled                :: Bool            = false
    kds_mod                   :: String          = "OL"
    zrsat_mod                 :: String          = "B"
    te_elements               :: Vector{String}  = String[]
    te_injection_ppm          :: Vector{Float64} = Float64[]
    te_magma_ppm              :: Vector{Float64} = Float64[]
    te_host_ppm               :: Vector{Float64} = Float64[]
    zircon_age_bin_yr         :: Float64         = 1000.0
    zircon_nucleation_density :: Float64         = 1e8
    zircon_host_radius_um     :: Float64         = 50.0
    zircon_inherited_age_Ma   :: Float64         = 300.0
    zircon_synthetic_grains   :: Int             = 100
    zircon_families           :: Int             = 6
    zircon_spot_um            :: Float64         = 20.0
    zircon_method             :: String          = "SIMS_UTh"
    zircon_sigma_kyr          :: Float64         = 3.0
    zircon_eruption_age_Ma    :: Float64         = 1.0

    show_grid                 :: Bool            = true
    show_outline              :: Bool            = true
    show_isotherms            :: Bool            = true
    gif_frame_ms              :: Int             = 250
end

const MAGERES_OPTION_GROUPS = [
    "Model geometry" => [
        :domain_width_km     => "Domain width (km)",
        :domain_thickness_km => "Domain bottom depth (km)",
        :grid_h_max_m        => "Coarsest cell (m)",
        :grid_h_min_m        => "Finest cell (m)",
        :grid_grading        => "Refinement grading",
        :lens_length_km      => "Chamber length (km)",
        :lens_depth_km       => "Chamber centre - depth (km)",
        :lens_shape          => "Chamber shape",
        :lens_n_segments     => "Chamber stations",
        :opening_mode        => "Opening mode"],
    "Model properties" => [
        :database               => "Database",
        :oxides                 => "Oxides",
        :magma_bulk             => "Magma bulk",
        :host_bulk              => "Host bulk",
        :injection_bulk         => "Injection bulk (empty = magma)",
        :thermodynamics         => "Thermodynamics",
        :T_surface_C            => "Top boundary T, surface (°C)",
        :geotherm_gradient_C_km => "Geothermal gradient (°C/km)",
        :rho_magma              => "Magma density (kg/m³)",
        :rho_host               => "Host density (kg/m³)",
        :cp_magma               => "Magma cp (J/kg·K)",
        :cp_host                => "Host cp (J/kg·K)",
        :k_magma                => "Magma conductivity (W/m·K)",
        :k_host                 => "Host conductivity (W/m·K)"],
    "Injection" => [
        :injection_period_yr => "Injection period (yr)",
        :first_injection_yr  => "First injection (yr)",
        :T_injection_C       => "Injection T (°C)",
        :lens_thickness_m    => "Injected lens thickness (m)",
        :injection_target    => "Injection target",
        :injection_melt_only => "Injected material"],
    "Eruption" => [
        :phi_lock               => "Lock-up melt fraction (vol)",
        :phi_perc               => "Percolation threshold (melt vol)",
        :phi_erupt              => "Eruptible melt fraction (vol, mobile-body mean)",
        :erupt_frac             => "Erupted fraction per event (vol of mobile body)",
        :erupt_crystal_frac     => "Erupted crystal fraction (0 melt only, 1 bulk)",
        :fluid_treatment        => "Fluid treatment",
        :eruption_trigger       => "Eruption trigger",
        :dP_crit_MPa            => "Critical overpressure (MPa)",
        :host_shear_modulus_GPa => "Host shear modulus (GPa)",
        :host_visc_A_Pas        => "Host viscosity prefactor A (Pa s)",
        :host_visc_G_kJ         => "Host viscosity activation energy (kJ/mol)",
        :recharge_time_yr       => "Recharge pressurisation time (yr, 0 = injection period)",
        :shell_thickness_m      => "Wall-rock shell thickness (m, 0 = equivalent chamber radius)"],
    "Settling" => [
        :crystal_size_mm   => "Crystal size (mm)",
        :hindered_exponent => "Hindered-settling exponent"],
    "Solver setup" => [
        :run_time_yr     => "Total time (yr)",
        :output_every_yr => "Save output every (yr)",
        :thermal_dt_yr   => "Timestep (yr)",
        :thermal_bc      => "Thermal boundary",
        :dT_tol          => "Re-equilibration ΔT tolerance (°C)",
        :dX_tol          => "Re-equilibration ΔX tolerance",
        :subsolidus_T_C  => "Sub-solidus T (°C)",
        :Ra_crit         => "Critical Rayleigh number",
        :Nu_exponent     => "Nusselt exponent",
        :g               => "Gravity (m/s²)",
        :boost_mode      => "Boost mode (host rock: initial guess from neighbouring solutions)"],
    "Trace elements" => [
        :te_enabled                => "TE predictive model",
        :kds_mod                   => "Kd's database",
        :zrsat_mod                 => "Zr saturation (none = no zircon)",
        :zircon_age_bin_yr         => "Zircon age bin (yr)",
        :zircon_nucleation_density => "Zircon nucleation density (grains/m³ of melt)",
        :zircon_host_radius_um     => "Inherited zircon radius (µm)",
        :zircon_inherited_age_Ma   => "Inherited zircon age (Ma)",
        :zircon_synthetic_grains   => "Synthetic grains per eruption",
        :zircon_families           => "Zircon families (inherited + nucleation epochs)",
        :zircon_spot_um            => "Analytical spot diameter (µm)",
        :zircon_method             => "Dating method (analytical uncertainty)",
        :zircon_sigma_kyr          => "SIMS U-Th uncertainty, 1σ (kyr)",
        :zircon_eruption_age_Ma    => "Absolute age of the latest output for U-Pb uncertainty (Ma)",
        :te_elements               => "Trace elements",
        :te_injection_ppm          => "Injected magma trace elements (µg/g)",
        :te_magma_ppm              => "Magma trace elements (µg/g)",
        :te_host_ppm               => "Host rock trace elements (µg/g)"],
    "Results display" => [
        :show_grid      => "Show mesh grid",
        :show_outline   => "Show chamber outline",
        :show_isotherms => "Show isotherms (every 100 °C)",
        :gif_frame_ms   => "GIF frame duration (ms)"],
]

const MAGERES_OPENING_MODES     = ("split", "up", "down")
const MAGERES_LENS_SHAPES       = ("ellipse", "parabola")
const MAGERES_THERMODYNAMICS    = ("constant", "magemin")
const MAGERES_THERMAL_BCS       = ("surface", "insulated")
const MAGERES_FLUID_TREATMENT   = ("removed", "retained")
const MAGERES_INJECTION_TARGETS = ("chamber", "body")
const MAGERES_KDS_MODELS        = ("OL", "CO", "Yak25")
const MAGERES_ERUPTION_TRIGGERS = ("melt", "overpressure")
const MAGERES_ZIRCON_METHODS    = ("SIMS_UTh", "LA_UPb", "TIMS_UPb")
const MAGERES_ZRSAT_MODELS      = ("none", "WH", "B", "CB")

"""
    mageres_convert_option(T::Type, v)

    Convert the raw value `v` to the option field type `T` (string, Bool, integer, string vector,
    Float64 vector, or plain `convert` otherwise).
"""
function mageres_convert_option(T::Type, v)
    T <: AbstractString && return string(v)
    T === Bool && return Bool(v)
    T <: Integer && return round(T, Float64(v))
    T <: AbstractVector{<:AbstractString} && return String[string(x) for x in v]
    T <: AbstractVector{<:Real} && return Float64[Float64(x) for x in v]
    return convert(T, v)
end

const MAGERES_RETIRED_OPTIONS = (:lens_x_km, :lens_angle_deg, :bulk_group_tol, :eruption_style, :view_top_km,
                                 :view_bottom_km)

"""
    mageres_options_from_dict(d::AbstractDict)

    Build a validated `MAGEResOptions` from a dictionary of field name => value, starting from the defaults.
    Retired option names are skipped; unknown names throw an `ArgumentError`.
"""
function mageres_options_from_dict(d::AbstractDict)
    o = MAGEResOptions()
    for (k, v) in d
        f = Symbol(k)
        f in MAGERES_RETIRED_OPTIONS && continue
        hasfield(MAGEResOptions, f) || throw(ArgumentError("unknown option: $k"))
        setfield!(o, f, mageres_convert_option(fieldtype(MAGEResOptions, f), v))
    end
    mageres_validate_options(o)
    return o
end

"""
    mageres_options_to_dict(o::MAGEResOptions)

    Return a `Dict{String,Any}` of field name => value for every field of `o`, with vector fields copied.
"""
mageres_options_to_dict(o::MAGEResOptions) =
    Dict{String,Any}(string(f) => (x = getfield(o, f); x isa AbstractVector ? copy(x) : x)
                     for f in fieldnames(MAGEResOptions))

"""
    mageres_save_options(path::AbstractString, o::MAGEResOptions)

    Write the options `o` as JSON to `path` and return `path`.
"""
mageres_save_options(path::AbstractString, o::MAGEResOptions) =
    (open(io -> JSON3.write(io, mageres_options_to_dict(o)), path, "w"); path)

"""
    mageres_load_options(path::AbstractString)

    Read a JSON options file written by `mageres_save_options` and return the validated `MAGEResOptions`.
"""
mageres_load_options(path::AbstractString) =
    mageres_options_from_dict(Dict{String,Any}(string(k) => v for (k, v) in JSON3.read(read(path, String))))

"""
    mageres_model_top_depth(o::MAGEResOptions)

    Vertical coordinate of the model top surface [m] (always 0.0).
"""
mageres_model_top_depth(o::MAGEResOptions) = 0.0

"""
    mageres_validate_options(o::MAGEResOptions)

    Check the consistency of all options in `o` and throw an `ArgumentError` on the first invalid one.
    Returns `o`.
"""
function mageres_validate_options(o::MAGEResOptions)
    o.opening_mode in MAGERES_OPENING_MODES ||
        throw(ArgumentError("opening_mode must be one of $(MAGERES_OPENING_MODES)"))
    o.lens_shape in MAGERES_LENS_SHAPES ||
        throw(ArgumentError("lens_shape must be one of $(MAGERES_LENS_SHAPES)"))
    o.thermodynamics in MAGERES_THERMODYNAMICS ||
        throw(ArgumentError("thermodynamics must be one of $(MAGERES_THERMODYNAMICS)"))
    o.thermal_bc in MAGERES_THERMAL_BCS ||
        throw(ArgumentError("thermal_bc must be one of $(MAGERES_THERMAL_BCS)"))
    o.fluid_treatment in MAGERES_FLUID_TREATMENT ||
        throw(ArgumentError("fluid_treatment must be one of $(MAGERES_FLUID_TREATMENT)"))
    o.lens_n_segments >= 2 || throw(ArgumentError("lens_n_segments must be ≥ 2"))
    o.thermal_dt_yr > 0 || throw(ArgumentError("thermal_dt_yr must be > 0"))
    o.run_time_yr > 0 && o.output_every_yr > 0 || throw(ArgumentError("run_time_yr and output_every_yr must be > 0"))
    0 < o.grid_h_min_m <= o.grid_h_max_m || throw(ArgumentError("need 0 < grid_h_min_m ≤ grid_h_max_m"))
    (0.0 <= o.phi_perc < o.phi_lock < o.phi_erupt <= 1.0) ||
        throw(ArgumentError("melt thresholds must satisfy 0 ≤ phi_perc < phi_lock < phi_erupt ≤ 1"))
    0.0 < o.erupt_frac <= 1.0 || throw(ArgumentError("erupt_frac must be in (0, 1]"))
    o.injection_target in MAGERES_INJECTION_TARGETS ||
        throw(ArgumentError("injection_target must be one of $(MAGERES_INJECTION_TARGETS)"))
    0.0 <= o.erupt_crystal_frac <= 1.0 || throw(ArgumentError("erupt_crystal_frac must be in [0, 1]"))
    o.dT_tol > 0 || throw(ArgumentError("dT_tol must be > 0"))
    o.dX_tol >= 0 || throw(ArgumentError("dX_tol must be ≥ 0"))
    o.crystal_size_mm > 0 || throw(ArgumentError("crystal_size_mm must be > 0"))
    o.hindered_exponent >= 0 || throw(ArgumentError("hindered_exponent must be ≥ 0"))
    o.Ra_crit > 0 && o.Nu_exponent > 0 || throw(ArgumentError("Ra_crit and Nu_exponent must be > 0"))
    o.injection_period_yr >= 0 || throw(ArgumentError("injection_period_yr must be ≥ 0"))
    n = length(o.oxides)
    length(o.magma_bulk) == n && length(o.host_bulk) == n ||
        throw(ArgumentError("magma_bulk and host_bulk must have one entry per oxide"))
    (isempty(o.injection_bulk) || length(o.injection_bulk) == n) ||
        throw(ArgumentError("injection_bulk must be empty or have one entry per oxide"))
    for b in (o.magma_bulk, o.host_bulk, o.injection_bulk)
        all(>=(0), b) || throw(ArgumentError("bulk compositions must be non-negative"))
    end
    all(k -> haskey(MAGERES_OXIDE_MOLAR_MASS, k), o.oxides) || throw(ArgumentError("unknown oxide in $(o.oxides)"))
    for x in (o.rho_magma, o.rho_host, o.cp_magma, o.cp_host, o.k_magma, o.k_host, o.g)
        x > 0 || throw(ArgumentError("material properties must be positive"))
    end
    for (L, name) in ((o.domain_width_km / 2, "half the domain width"), (o.domain_thickness_km, "domain_thickness_km"))
        m = 1e3 * L / o.grid_h_max_m
        abs(m - round(m)) < 1e-9 && m >= 1 || throw(ArgumentError("$name must be a multiple of grid_h_max_m"))
    end
    o.eruption_trigger in MAGERES_ERUPTION_TRIGGERS ||
        throw(ArgumentError("eruption_trigger must be one of $(MAGERES_ERUPTION_TRIGGERS)"))
    (o.eruption_trigger == "melt" || o.thermodynamics == "magemin") ||
        throw(ArgumentError("the overpressure eruption trigger requires MAGEMin thermodynamics"))
    o.dP_crit_MPa > 0 && o.host_shear_modulus_GPa > 0 && o.host_visc_A_Pas > 0 && o.host_visc_G_kJ > 0 ||
        throw(ArgumentError("overpressure parameters must be positive"))
    o.recharge_time_yr >= 0 || throw(ArgumentError("recharge_time_yr must be ≥ 0"))
    o.shell_thickness_m >= 0 || throw(ArgumentError("shell_thickness_m must be ≥ 0"))
    o.gif_frame_ms > 0 || throw(ArgumentError("gif_frame_ms must be > 0"))
    o.kds_mod in MAGERES_KDS_MODELS || throw(ArgumentError("kds_mod must be one of $(MAGERES_KDS_MODELS)"))
    o.zrsat_mod in MAGERES_ZRSAT_MODELS || throw(ArgumentError("zrsat_mod must be one of $(MAGERES_ZRSAT_MODELS)"))
    (!o.te_enabled || o.thermodynamics == "magemin") ||
        throw(ArgumentError("trace elements require MAGEMin thermodynamics"))
    ne = length(o.te_elements)
    for v in (o.te_injection_ppm, o.te_host_ppm, o.te_magma_ppm)
        (isempty(v) || length(v) == ne) ||
            throw(ArgumentError("trace-element compositions must have one entry per element"))
        all(>=(0), v) || throw(ArgumentError("trace-element compositions must be non-negative"))
    end
    o.zircon_age_bin_yr > 0 || throw(ArgumentError("zircon_age_bin_yr must be > 0"))
    o.zircon_nucleation_density > 0 || throw(ArgumentError("zircon_nucleation_density must be > 0"))
    o.zircon_host_radius_um > 0 || throw(ArgumentError("zircon_host_radius_um must be > 0"))
    o.zircon_inherited_age_Ma >= 0 || throw(ArgumentError("zircon_inherited_age_Ma must be ≥ 0"))
    o.zircon_synthetic_grains >= 1 || throw(ArgumentError("zircon_synthetic_grains must be ≥ 1"))
    o.zircon_families >= 2 || throw(ArgumentError("zircon_families must be ≥ 2"))
    o.zircon_spot_um > 0 || throw(ArgumentError("zircon_spot_um must be > 0"))
    o.zircon_method in MAGERES_ZIRCON_METHODS ||
        throw(ArgumentError("zircon_method must be one of $(MAGERES_ZIRCON_METHODS)"))
    o.zircon_sigma_kyr > 0 && o.zircon_eruption_age_Ma > 0 ||
        throw(ArgumentError("zircon_sigma_kyr and zircon_eruption_age_Ma must be > 0"))
    o.lens_length_km < o.domain_width_km ||
        throw(ArgumentError("the chamber must lie inside the domain horizontally"))
    0 < o.lens_depth_km < o.domain_thickness_km ||
        throw(ArgumentError("chamber depth must lie between the surface and the domain bottom depth"))
    return o
end

"""
    mageres_opening_share(mode::AbstractString)

    Fraction of the chamber opening taken up by roof uplift: 0.5 for "split", 1.0 for "up", 0.0 otherwise.
"""
mageres_opening_share(mode::AbstractString) = mode == "split" ? 0.5 : mode == "up" ? 1.0 : 0.0

const MAGERES_SECONDS_PER_YEAR = 365.25 * 24 * 3600
const MAGERES_T0_K             = 273.15
