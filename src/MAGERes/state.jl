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
    MAGEResLayer

    One layer of a source or pluton column: time [yr], area, temperature [°C], oxide moles and tracer rows
    (trace-element and zircon content, empty without trace elements).
"""
struct MAGEResLayer
    t       :: Float64
    area    :: Float64
    T       :: Float64
    moles   :: Vector{Float64}
    tracers :: Vector{Float64}
end

MAGEResLayer(t::Float64, area::Float64, T::Float64, moles::Vector{Float64}) =
    MAGEResLayer(t, area, T, moles, Float64[])

"""
    MAGEResColumn

    Stack of MAGEResLayer records (source or pluton column); `MAGEResColumn()` is an empty column.
"""
mutable struct MAGEResColumn
    layers :: Vector{MAGEResLayer}
end

MAGEResColumn() = MAGEResColumn(MAGEResLayer[])

"""
    mageres_column_area(c::MAGEResColumn)

    Total area of the layers of column `c`.
"""
mageres_column_area(c::MAGEResColumn) = sum((l.area for l in c.layers); init = 0.0)

"""
    MAGEResLedger

    Cumulative budget of the conserved quantities: initial content, injected, extracted, outflow, inflow
    and degassed fluid vectors, boundary and re-minimization energies.
"""
mutable struct MAGEResLedger
    initial         :: Vector{Float64}
    injected        :: Vector{Float64}
    extracted       :: Vector{Float64}
    outflow         :: Vector{Float64}
    inflow          :: Vector{Float64}
    boundary_energy :: Float64
    fluid           :: Vector{Float64}
    remin_energy    :: Float64
end

"""
    MAGEResLedger(Q::Matrix{Float64})

    Ledger whose initial content is `Q` summed over the cells, with all fluxes zero.
"""
MAGEResLedger(Q::Matrix{Float64}) =
    (nf = size(Q, 1); MAGEResLedger(vec(sum(Q; dims = 2)), zeros(nf), zeros(nf), zeros(nf), zeros(nf),
                                    0.0, zeros(nf), 0.0))

"""
    mageres_copy_ledger(L::MAGEResLedger)

    Copy of ledger `L` with all vectors copied.
"""
mageres_copy_ledger(L::MAGEResLedger) =
    MAGEResLedger(copy(L.initial), copy(L.injected), copy(L.extracted), copy(L.outflow), copy(L.inflow),
                  L.boundary_energy, copy(L.fluid), L.remin_energy)

"""
    mageres_expected_content(L::MAGEResLedger)

    Total conserved quantities expected from the ledger balance.
"""
function mageres_expected_content(L::MAGEResLedger)
    e = L.initial .+ L.injected .- L.extracted .- L.outflow .+ L.inflow .- L.fluid
    e[MAGERES_IE] += L.boundary_energy + L.remin_energy
    e[MAGERES_IH] += L.boundary_energy
    return e
end

"""
    MAGEResEventRecord

    Diagnostics of one event: time [yr], kind, area, relative host, budget, grid, energy, oxide mass and
    trace-element mass errors, number of cells and message.
"""
struct MAGEResEventRecord
    t            :: Float64
    kind         :: Symbol
    area         :: Float64
    host_error   :: Float64
    budget_error :: Float64
    grid_error   :: Float64
    energy_error :: Float64
    mass_error   :: Float64
    te_error     :: Float64
    ncells       :: Int
    message      :: String
end

"""
    MAGEResPressure

    Chamber overpressure state (overpressure eruption trigger): overpressure [Pa], volume source waiting for the next
    step [m²], effective compressibility [1/Pa], wall-rock shell temperature [°C], viscosity [Pa s], relaxation
    time [s], the recharge inflows still pressurising the chamber (rate [m²/yr], start and end time [yr]), the
    phase-change volume waiting for the next step [m²], and the phase-change and inflow volume sources of the last
    step [m²].
"""
mutable struct MAGEResPressure
    dP :: Float64
    dV_pending :: Float64
    dV_phase_pending :: Float64
    beta       :: Float64
    T_shell    :: Float64
    eta        :: Float64
    tau        :: Float64
    inflow     :: Vector{NTuple{3,Float64}}
    dV_phase   :: Float64
    dV_in      :: Float64
end

MAGEResPressure() = MAGEResPressure(0.0, 0.0, 0.0, NaN, NaN, NaN, NaN, NTuple{3,Float64}[], 0.0, 0.0)

"""
    MAGEResState

    Full model state: time [yr], options, materials, chamber, grid, conserved quantities `Q`, conductivity,
    source/pluton columns, ledger, history, thermodynamics, convection, cumulate and eruption tracking, and chamber
    overpressure.
"""
mutable struct MAGEResState
    t               :: Float64
    opts            :: MAGEResOptions
    z_top           :: Float64
    magma           :: MAGEResMaterial
    host            :: MAGEResMaterial
    injection       :: MAGEResMaterial
    chamber         :: MAGEResChamber
    grid            :: MAGEResGrid
    Q               :: Matrix{Float64}
    k               :: Vector{Float64}
    source          :: MAGEResColumn
    pluton          :: MAGEResColumn
    host_area0      :: Float64
    outflow_area    :: Float64
    ledger          :: MAGEResLedger
    next_injection  :: Float64
    n_thermal_steps :: Int
    history         :: Vector{MAGEResEventRecord}
    conn            :: Union{Nothing,MAGEResThermalConnectivity}
    thermo          :: Union{Nothing,MAGEResThermo}
    body            :: BitVector
    Nu              :: Float64
    Ra              :: Float64
    percolated_area :: Float64
    cumulate_t      :: Vector{Float64}
    cum_frac        :: Vector{Float64}
    cum_time        :: Vector{Float64}
    restite_frac    :: Vector{Float64}
    settled_area    :: Float64
    donor           :: BitVector
    erupt_armed     :: Bool
    melt_out        :: Vector{Float64}
    pressure        :: MAGEResPressure
end

"""
    mageres_depth(st::MAGEResState, y::Real)

    Depth below the model top of height `y`.
"""
mageres_depth(st::MAGEResState, y::Real) = st.z_top - y

"""
    mageres_geotherm_T(o::MAGEResOptions, y::Real)

    Geotherm temperature [°C] at height `y` [m].
"""
mageres_geotherm_T(o::MAGEResOptions, y::Real) = o.T_surface_C - mageres_geotherm_gradient(o) * min(y, 0.0)

"""
    mageres_temperature(st::MAGEResState)

    Per-cell temperature [°C] from energy and heat capacity.
"""
mageres_temperature(st::MAGEResState) = st.Q[MAGERES_IE, :] ./ st.Q[MAGERES_IC, :] .- MAGERES_T0_K

"""
    mageres_heat_capacity(st::MAGEResState)

    Per-cell heat capacity.
"""
mageres_heat_capacity(st::MAGEResState) = st.Q[MAGERES_IC, :]

"""
    mageres_cell_moles(st::MAGEResState)

    Oxide moles of every cell (one column per cell).
"""
mageres_cell_moles(st::MAGEResState) = st.Q[mageres_ox_rows(st), :]

"""
    mageres_noxides(st::MAGEResState)

    Number of oxides carried in `st.Q`.
"""
mageres_noxides(st::MAGEResState) = length(st.opts.oxides)

"""
    mageres_cumulate(st::MAGEResState)

    Cells with a cumulate time (excluding the mobile body when it is defined) and magma fraction >= 0.5.
"""
mageres_cumulate(st::MAGEResState) = (length(st.body) == length(st.cumulate_t) ? .!isnan.(st.cumulate_t) .& .!st.body :
                                       .!isnan.(st.cumulate_t)) .& (st.grid.frac .>= 0.5)

const MAGERES_CUMULATE_FRAC = 0.5

"""
    mageres_update_cumulate_tag!(st::MAGEResState)

    Set `cumulate_t` to the cumulate time of cells with cumulate fraction >= `MAGERES_CUMULATE_FRAC`, NaN elsewhere.
"""
function mageres_update_cumulate_tag!(st::MAGEResState)
    st.cumulate_t = [f >= MAGERES_CUMULATE_FRAC ? t : NaN for (f, t) in zip(st.cum_frac, st.cum_time)]
    return st
end

"""
    mageres_tag_cumulate!(st::MAGEResState, c::Int)

    Mark cell `c` as fully cumulate, blending its cumulate time with the current time by its previous fraction.
"""
function mageres_tag_cumulate!(st::MAGEResState, c::Int)
    f = st.cum_frac[c]
    f >= 1 && return st
    st.cum_time[c]   = f > 0 && isfinite(st.cum_time[c]) ? f * st.cum_time[c] + (1 - f) * st.t : st.t
    st.cum_frac[c]   = 1.0
    st.cumulate_t[c] = st.cum_time[c]
    return st
end

"""
    mageres_host_density_at(st::MAGEResState, y::Real)

    Host-rock conserved-quantity density at height `y`, from the host profile or the geotherm.
"""
mageres_host_density_at(st::MAGEResState, y::Real) =
    st.thermo === nothing ? mageres_content_density(st.host, mageres_geotherm_T(st.opts, y)) :
                            mageres_profile_density(st.thermo.profile, y)

"""
    mageres_injected_density(st::MAGEResState)

    Conserved-quantity density of the injected magma.
"""
mageres_injected_density(st::MAGEResState) =
    st.thermo === nothing ? mageres_content_density(st.injection, st.opts.T_injection_C) : st.thermo.injection_density

"""
    mageres_conductivity!(st::MAGEResState)

    Set the cell conductivities from the magma fraction, multiplied by `Nu` in the convecting body.
"""
function mageres_conductivity!(st::MAGEResState)
    g    = st.grid
    st.k = st.magma.k .* g.frac .+ st.host.k .* (1 .- g.frac)
    length(st.body) == length(st.k) && st.Nu > 1 && (st.k[st.body] .*= st.Nu)
    return st
end

"""
    mageres_init_state(opts = MAGEResOptions(); mm = nothing, progressbar = true, callback_fn = nothing,
                       stage_fn = nothing)

    Initial MAGEResState for `opts`: validated options, optional MAGEMin thermodynamics, chamber, grid and cells
    filled with host-rock content along the geotherm.
"""
function mageres_init_state(opts::MAGEResOptions = MAGEResOptions(); mm = nothing, progressbar::Bool = true,
                            callback_fn = nothing, stage_fn = nothing)
    mageres_validate_options(opts)
    o  = deepcopy(opts)
    th = nothing
    if o.thermodynamics == "magemin"
        mm === nothing && (mm = Initialize_MAGEMin(o.database; verbose = false, solver = 0))
        th = mageres_build_thermo(o, mm; progressbar = progressbar, callback_fn = callback_fn, stage_fn = stage_fn)
    end
    c     = MAGEResChamber(o)
    g     = mageres_build_grid(o, c)
    z_top = mageres_model_top_depth(o)
    magma = mageres_magma_material(o)
    host  = mageres_host_material(o)
    inj   = mageres_injection_material(o)
    nf    = th === nothing ? MAGERES_IN0 - 1 + length(o.oxides) : size(th.profile.density, 1)
    Q     = zeros(nf, mageres_ncells(g))
    for n in 1:mageres_ncells(g)
        Q[:, n] .= (th === nothing ? mageres_content_density(host, mageres_geotherm_T(o, g.yc[n])) :
                    mageres_profile_density(th.profile, g.yc[n])) .* g.area[n]
    end
    if th !== nothing
        th.points      = [mageres_profile_point(th.profile, g.yc[n]) for n in 1:mageres_ncells(g)]
        th.needs_remin = falses(mageres_ncells(g))
        th.calc_count  = zeros(Int, mageres_ncells(g))
    end
    A  = 1e3 * mageres_axis_x(o) * o.domain_thickness_km
    ti = o.injection_period_yr > 0 ? o.first_injection_yr : Inf
    st = MAGEResState(0.0, o, z_top, magma, host, inj, c, g, Q, Float64[], MAGEResColumn(), MAGEResColumn(), A, 0.0,
                      MAGEResLedger(Q), ti, 0, MAGEResEventRecord[], nothing, th, falses(mageres_ncells(g)), 1.0, 0.0,
                      0.0, fill(NaN, mageres_ncells(g)), zeros(mageres_ncells(g)), fill(NaN, mageres_ncells(g)),
                      zeros(mageres_ncells(g)), 0.0,
                      falses(mageres_ncells(g)), false,
                      zeros(mageres_ncells(g)), MAGEResPressure())
    return mageres_conductivity!(st)
end

"""
    mageres_grid_energy(st::MAGEResState)

    Total energy of all cells.
"""
mageres_grid_energy(st::MAGEResState) = sum(@view st.Q[MAGERES_IE, :])

"""
    mageres_budget(st::MAGEResState)

    NamedTuple of chamber, grid, source, pluton and outflow areas, energies, relative host, budget, grid,
    energy, enthalpy, oxide mass and trace-element mass errors, and mean/max/min temperatures [°C].
"""
function mageres_budget(st::MAGEResState)
    g            = st.grid
    A_chamber    = mageres_chamber_area(st.chamber)
    A_magma_grid = mageres_magma_area(g)
    A_host_grid  = sum((1 .- g.frac) .* g.area)
    A_source     = mageres_column_area(st.source)
    A_pluton     = mageres_column_area(st.pluton)
    A_fed        = A_source + st.percolated_area
    total        = vec(sum(st.Q; dims = 2))
    expct        = mageres_expected_content(st.ledger)
    L            = st.ledger
    mass_err = maximum(abs(total[f] - expct[f]) /
                       max(abs(L.initial[f]), abs(L.injected[f]), abs(L.inflow[f]), abs(total[f]), 1e-300)
                       for f in mageres_ox_rows(st))
    T  = mageres_temperature(st)
    Am = sum(g.frac .* g.area)
    return (; A_chamber, A_magma_grid, A_host_grid, A_source, A_pluton,
              A_percolated   = st.percolated_area,
              outflow        = st.outflow_area,
              thickness      = mageres_chamber_thickness(st.chamber),
              E              = total[MAGERES_IE],
              E_expected     = expct[MAGERES_IE],
              host_error     = (A_host_grid + st.outflow_area - st.host_area0) / st.host_area0,
              budget_error   = A_fed > 0 ? (A_fed - A_chamber - A_pluton) / A_fed : 0.0,
              grid_error     = (A_magma_grid - A_chamber / MAGERES_SYMMETRY) / max(A_chamber / MAGERES_SYMMETRY, 1.0),
              energy_error   = (total[MAGERES_IE] - expct[MAGERES_IE]) / abs(st.ledger.initial[MAGERES_IE]),
              enthalpy_error = (total[MAGERES_IH] - expct[MAGERES_IH]) / abs(st.ledger.initial[MAGERES_IH]),
              mass_error     = mass_err,
              te_error       = mageres_te_error(st, total, expct),
              T_mean_chamber = Am > 0 ? sum(T .* g.frac .* g.area) / Am : NaN,
              T_max          = maximum(T),
              T_min          = minimum(T))
end

"""
    mageres_record!(st::MAGEResState, kind::Symbol, area::Float64, message::String = "")

    Append an MAGEResEventRecord with the current budget errors to `st.history` and return the budget.
"""
function mageres_record!(st::MAGEResState, kind::Symbol, area::Float64, message::String = "")
    b = mageres_budget(st)
    push!(st.history, MAGEResEventRecord(st.t, kind, area, b.host_error, b.budget_error, b.grid_error, b.energy_error,
                                         b.mass_error, b.te_error, mageres_ncells(st.grid), message))
    return b
end
