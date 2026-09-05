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

const _mineral_oxide_stoich = Dict(
    "SiO2"  => (:Si,  1, 2),
    "TiO2"  => (:Ti,  1, 2),
    "Al2O3" => (:Al,  2, 3),
    "Cr2O3" => (:Cr,  2, 3),
    "Fe2O3" => (:Fe3, 2, 3),
    "FeO"   => (:Fe2, 1, 1),
    "MnO"   => (:Mn,  1, 1),
    "MgO"   => (:Mg,  1, 1),
    "CaO"   => (:Ca,  1, 1),
    "Na2O"  => (:Na,  2, 1),
    "K2O"   => (:K,   2, 1),
)

"""
    oxide_cations(wt, O_basis)

    Recalculate an oxide-wt% composition to cations on a formula unit
    normalized so that the oxide-stoichiometric oxygen (SiO2 -> 2 O per Si,
    MgO -> 1 O per Mg, etc.) sums to `O_basis`.

    For anhydrous minerals (e.g. pyroxene, `O_basis = 6`), this equals the
    real structural oxygen count. For hydrous minerals normalized on the
    conventional "anhydrous + n(OH)" basis (e.g. amphibole, `O_basis = 23`
    for the "23 O, 2 OH" convention), it already folds in the oxygen shared
    with OH by charge-balance identity, so no OH content is needed as input.

    Fe3+/Fe2+ speciation is picked up from whichever convention the phase's
    `Comp_wt` actually carries: either an explicit `wt["Fe2O3"]` (used
    directly), or — as in MAGEMin's Holland & Powell-based databases
    (`ig`, `mp`, `mb`, ...) — the HP "excess oxygen" component `wt["O"]`,
    where `FeO` is reported as total Fe-as-ferrous and `O` (monatomic,
    16 g/mol) is the proxy for Fe3+: 2 FeO + O -> Fe2O3, i.e.
    mol(Fe3+) = 2 * mol(O), taken out of the reported total FeO. Either
    way, no Droop (1987)-style Fe3+ estimation from total Fe alone is
    required since MAGEMin's solid-solution models resolve the speciation
    thermodynamically.

    Returns `nothing` if the composition carries no oxygen (e.g. empty entry).
"""
function oxide_cations(wt::Dict{String,Float64}, O_basis::Float64)

    cat = Dict{Symbol,Float64}(:Si=>0.0, :Ti=>0.0, :Al=>0.0, :Cr=>0.0, :Fe3=>0.0,
                                :Fe2=>0.0, :Mn=>0.0, :Mg=>0.0, :Ca=>0.0, :Na=>0.0, :K=>0.0)
    mol_O = 0.0

    for (ox, (sym, ncat, nox)) in _mineral_oxide_stoich
        w = get(wt, ox, 0.0)
        (ismissing(w) || w <= 0.0) && continue
        mol_ox      = w / get_molar_mass(ox)
        cat[sym]   += mol_ox * ncat
        mol_O      += mol_ox * nox
    end

    w_O = get(wt, "O", 0.0)
    if !ismissing(w_O) && w_O > 0.0
        mol_excess_O = w_O / get_molar_mass("O")
        fe3_from_O   = min(cat[:Fe2], 2.0 * mol_excess_O)
        cat[:Fe3]   += fe3_from_O
        cat[:Fe2]   -= fe3_from_O
        mol_O       += mol_excess_O
    end

    mol_O <= 0.0 && return nothing

    f = O_basis / mol_O
    for k in keys(cat)
        cat[k] *= f
    end

    return cat
end
