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

const MAGERES_OXIDE_MOLAR_MASS = Dict(
    "SiO2"  => 60.0843,  "Al2O3" => 101.9613, "CaO"   => 56.0774, "MgO"  => 40.3044, "FeO" => 71.8444,
    "Fe2O3" => 159.6882, "K2O"   => 94.1960,  "Na2O"  => 61.9789, "TiO2" => 79.8658, "O"   => 15.9994,
    "MnO"   => 70.9374,  "Cr2O3" => 151.9904, "H2O"   => 18.0153, "CO2"  => 44.0095, "S"   => 32.065,
)

"""
    mageres_normalized(b::AbstractVector{<:Real})

    Return `b` divided by its sum, or `b` as a Float64 vector if the sum is not positive.
"""
mageres_normalized(b::AbstractVector{<:Real}) = (s = sum(b); s > 0 ? b ./ s : collect(Float64, b))

"""
    mageres_molar_mass_kg(oxides::Vector{String}, bulk::AbstractVector{<:Real})

    Mean molar mass [kg/mol] of the normalized molar `bulk` over the given `oxides`.
"""
mageres_molar_mass_kg(oxides::Vector{String}, bulk::AbstractVector{<:Real}) =
    sum(mageres_normalized(bulk)[k] * MAGERES_OXIDE_MOLAR_MASS[oxides[k]] for k in eachindex(oxides)) / 1000

"""
    MAGEResMaterial

    Rock or magma material: normalized molar bulk, density [kg/m³], heat capacity [J/kg/K],
    conductivity [W/m/K] and oxide moles per unit volume [mol/m³].
"""
struct MAGEResMaterial
    bulk         :: Vector{Float64}
    rho          :: Float64
    cp           :: Float64
    k            :: Float64
    moles_per_m3 :: Vector{Float64}
end

"""
    MAGEResMaterial(oxides::Vector{String}, bulk, rho, cp, k)

    Build an `MAGEResMaterial` from a molar `bulk` over `oxides` and the density `rho`, heat capacity `cp`
    and conductivity `k`; the bulk is normalized and the moles per m³ are derived from `rho`.
"""
function MAGEResMaterial(oxides::Vector{String}, bulk::AbstractVector{<:Real}, rho::Real, cp::Real, k::Real)
    x = mageres_normalized(bulk)
    n = rho / mageres_molar_mass_kg(oxides, x)
    return MAGEResMaterial(x, Float64(rho), Float64(cp), Float64(k), n .* x)
end

"""
    mageres_magma_material(o::MAGEResOptions)

    Magma `MAGEResMaterial` built from the magma bulk and magma properties of `o`.
"""
mageres_magma_material(o::MAGEResOptions) = MAGEResMaterial(o.oxides, o.magma_bulk, o.rho_magma, o.cp_magma, o.k_magma)

"""
    mageres_host_material(o::MAGEResOptions)

    Host-rock `MAGEResMaterial` built from the host bulk and host properties of `o`.
"""
mageres_host_material(o::MAGEResOptions) = MAGEResMaterial(o.oxides, o.host_bulk, o.rho_host, o.cp_host, o.k_host)

"""
    mageres_injection_material(o::MAGEResOptions)

    Injected-magma `MAGEResMaterial`: the injection bulk of `o` (or the magma bulk when empty) with magma properties.
"""
mageres_injection_material(o::MAGEResOptions) =
    MAGEResMaterial(o.oxides, isempty(o.injection_bulk) ? o.magma_bulk : o.injection_bulk,
                    o.rho_magma, o.cp_magma, o.k_magma)

const MAGERES_IE  = 1
const MAGERES_IC  = 2
const MAGERES_IH  = 3
const MAGERES_IN0 = 4

"""
    mageres_content_density(m::MAGEResMaterial, T_C::Real)

    Content vector per unit volume of material `m` at temperature `T_C` [°C]: energy ρ·cp·T [J/m³],
    heat capacity ρ·cp [J/m³/K], enthalpy ρ·cp·T [J/m³], then oxide moles [mol/m³].
"""
mageres_content_density(m::MAGEResMaterial, T_C::Real) =
    vcat(m.rho * m.cp * (T_C + MAGERES_T0_K), m.rho * m.cp, m.rho * m.cp * (T_C + MAGERES_T0_K), m.moles_per_m3)
