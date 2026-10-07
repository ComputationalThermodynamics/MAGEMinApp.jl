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

"""
    MAGEResThermalConnectivity

    Conduction faces of a grid as leaf pairs `(fa, fb)` with geometric factor `fgeo`, plus the leaves
    on the top and bottom boundaries.
"""
struct MAGEResThermalConnectivity
    fa     :: Vector{Int}
    fb     :: Vector{Int}
    fgeo   :: Vector{Float64}
    top    :: Vector{Int}
    bottom :: Vector{Int}
end

"""
    mageres_thermal_connectivity(g::MAGEResGrid)

    Build the `MAGEResThermalConnectivity` of grid `g`, listing every interior face once (geometric factor
    1 between same-level leaves, 2/3 otherwise) and the top and bottom boundary leaves.
"""
function mageres_thermal_connectivity(g::MAGEResGrid)
    fa     = Int[]
    fb     = Int[]
    fgeo   = Float64[]
    top    = Int[]
    bottom = Int[]
    for c in 1:mageres_ncells(g)
        for d in (1, 3)
            kind, nb = mageres_face_neighbors(g, c, d)
            if kind == :boundary
                d == 3 && push!(top, c)
                continue
            end
            geo = kind == :same ? 1.0 : 2 / 3
            for m in nb
                push!(fa, c); push!(fb, m); push!(fgeo, geo)
            end
        end
        first(mageres_face_neighbors(g, c, 4)) == :boundary && push!(bottom, c)
    end
    return MAGEResThermalConnectivity(fa, fb, fgeo, top, bottom)
end

"""
    harmonic(a::Float64, b::Float64)

    Harmonic mean of `a` and `b`.
"""
@inline harmonic(a::Float64, b::Float64) = 2a * b / (a + b)

"""
    mageres_reference_diffusivity(o::MAGEResOptions)

    Thermal diffusivity of the host rock [m²/s].
"""
mageres_reference_diffusivity(o::MAGEResOptions) = o.k_host / (o.rho_host * o.cp_host)

"""
    mageres_geotherm_gradient(o::MAGEResOptions)

    Geothermal gradient [°C/m].
"""
mageres_geotherm_gradient(o::MAGEResOptions) = o.geotherm_gradient_C_km / 1e3

"""
    mageres_bottom_flux(o::MAGEResOptions)

    Basal heat flux [W/m²] matching the geothermal gradient in the host rock.
"""
mageres_bottom_flux(o::MAGEResOptions) = o.k_host * mageres_geotherm_gradient(o)

"""
    mageres_conduction_step(g, tc, k, C, T, dt, t_s, o)

    Implicit conduction step of length `dt` [s] for the leaf temperatures `T` [°C] with conductivities `k`
    and heat capacities `C`; with the "surface" boundary, fixed top temperature and basal heat flux.
    Returns the new temperatures and the energy entering through the boundaries during the step.
"""
function mageres_conduction_step(g::MAGEResGrid, tc::MAGEResThermalConnectivity, k::Vector{Float64}, C::Vector{Float64},
                                 T::Vector{Float64}, dt::Float64, t_s::Float64, o::MAGEResOptions)
    n    = mageres_ncells(g)
    nf   = length(tc.fa)
    I    = Vector{Int}(undef, 2nf + n)
    J    = similar(I)
    V    = Vector{Float64}(undef, 2nf + n)
    diag = C ./ dt
    rhs  = C ./ dt .* T
    @inbounds for f in 1:nf
        a, b     = tc.fa[f], tc.fb[f]
        coef     = harmonic(k[a], k[b]) * tc.fgeo[f]
        I[2*f-1] = a; J[2*f-1] = b; V[2*f-1] = -coef
        I[2*f]   = b; J[2*f]   = a; V[2*f]   = -coef
        diag[a] += coef
        diag[b] += coef
    end
    lid     = o.thermal_bc == "surface"
    Tinf    = o.T_surface_C
    qb      = mageres_bottom_flux(o)
    topcoef = zeros(length(tc.top))
    if lid
        for (m, c) in enumerate(tc.top)
            topcoef[m] = 2 * k[c]
            diag[c]   += topcoef[m]
            rhs[c]    += topcoef[m] * Tinf
        end
        for c in tc.bottom
            rhs[c] += qb * g.h[c]
        end
    end
    @inbounds for c in 1:n
        I[2nf+c] = c; J[2nf+c] = c; V[2nf+c] = diag[c]
    end
    Tn = sparse(I, J, V, n, n) \ rhs
    Eb = 0.0
    if lid
        for (m, c) in enumerate(tc.top)
            Eb += topcoef[m] * (Tinf - Tn[c])
        end
        Eb += qb * sum(g.h[c] for c in tc.bottom; init = 0.0)
    end
    return Tn, Eb * dt
end
