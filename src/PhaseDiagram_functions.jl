mutable struct ss_infos
    ss_name :: String
    n_em    :: Int64
    n_xeos  :: Int64
    ss_em   :: Vector{String}
    ss_xeos :: Vector{String}
end

mutable struct db_infos
    db_name :: String
    db_info :: String
    data_ss :: Array{ss_infos}
    ss_name :: Array{String}
    data_pp :: Array{String}
end


mutable struct isopleth_data
    n_iso   :: Int64
    n_iso_max   :: Int64

    status  :: Vector{Int64}
    active  :: Vector{Int64}
    isoP    :: Vector{GenericTrace{Dict{Symbol, Any}}}

    label   :: Vector{String}
    value   :: Vector{Int64}
end


"""
    function to format the markdown text area to display general informations of the computation
"""
function get_computation_info(npoints, meant)

    infos  = "|Number of computed points &nbsp;| Minimization time (ms) |\n"
    infos *= "|--------------------------------|------------------------|\n"
    infos *= "|  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;"*string(npoints)*"  |   &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;"*string(meant)*" |\n"

    return infos
end


function get_phase_diagram_information(npoints, dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2)

    PD_infos  = Vector{String}(undef,2)

    datetoday = string(Dates.today())
    rightnow  = string(Dates.Time(Dates.now()))


    if diagType == "pt"
        dgtype = "Pressure-Temperature, fixed composition"
    elseif diagType == "px"
        dgtype = "Pressure-Composition, fixed temperature"
    else
        dgtype = "Temperature-Composition, fixed pressure"
    end

    if solver == "lp"
        solv = "LP (legacy)"
    elseif solver == "pge"
        solv = "PGE (default)"
    elseif solver == "hyb"
        solv = "Hybrid (PGE&LP)"
    end


    db_in     = retrieve_solution_phase_information(dtb)


    PD_infos[1]  = "Phase Diagram computed using MAGEMin v"*Out_XY[1].MAGEMin_ver*"<br>"
    PD_infos[1] *= "‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾<br>"
    PD_infos[1] *= "Number of points <br>"
    PD_infos[1] *= "Date & time <br>"
    PD_infos[1] *= "Database <br>"
    PD_infos[1] *= "Diagram type <br>"
    PD_infos[1] *= "Solver <br>"
    PD_infos[1] *= "Oxide list <br>"
    if bufferType != "none"
        PD_infos[1] *= "Buffer <br>"
    end            
    if diagType == "pt"
        PD_infos[1] *= "X comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end       
    elseif diagType == "px"
        PD_infos[1] *= "X1 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end
        PD_infos[1] *= "X2 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "Fixed Temp <br>"
    else
        PD_infos[1] *= "X1 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "X2 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "Fixed Pres <br>"
    end
    PD_infos[1] *= "_____________________________________________________________________________________________________<br>"
    

    PD_infos[2] = "<br>"
    PD_infos[2] *= "<br>"
    PD_infos[2] *= string(npoints) * "<br>"
    PD_infos[2] *= datetoday * ", " * rightnow * "<br>"
    PD_infos[2] *= db_in.db_info * "<br>"
    PD_infos[2] *= dgtype *"<br>"
    PD_infos[2] *= solv *"<br>"
    PD_infos[2] *= join(oxi, " ") *"<br>"
    if bufferType != "none"
        PD_infos[2] *= bufferType *"<br>"
    end            
    if diagType == "pt"
        PD_infos[2] *= join(bulk_L, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end       
    elseif diagType == "px"
        PD_infos[2] *= join(bulk_L, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end
        PD_infos[2] *= join(bulk_R, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(fixT, " ") *"<br>"
    else
        PD_infos[2] *= join(bulk_L, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end        
        PD_infos[2] *= join(bulk_R, " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(fixP, " ") *"<br>"
    end
    PD_infos[2] *= " <br>"

    return PD_infos
end




"""
    retrieve_solution_phase_information(dtb)

    retrieve the solution phase information based on the active database
"""
function retrieve_solution_phase_information(dtb)

    db_inf  = db_infos[db_infos("mp", "Metapelite (White et al., 2014)", ss_infos[ss_infos("liq", 8, 7, ["none", "q4L", "abL", "kspL", "anL", "slL", "fo2L", "fa2L", "h2oL"], ["none", "q", "fsp", "na", "an", "ol", "x", "h2o"]), ss_infos("fsp", 3, 2, ["none", "ab", "an", "san"], ["none", "ca", "k"]), ss_infos("bi", 7, 6, ["none", "phl", "annm", "obi", "east", "tbi", "fbi", "mmbi"], ["none", "x", "m", "y", "f", "t", "Q"]), ss_infos("g", 5, 4, ["none", "py", "alm", "spss", "gr", "kho"], ["none", "x", "z", "m", "f"]), ss_infos("ep", 3, 2, ["none", "cz", "ep", "fep"], ["none", "f", "Q"]), ss_infos("ma", 6, 5, ["none", "mut", "celt", "fcelt", "pat", "ma", "fmu"], ["none", "x", "y", "f", "n", "c"]), ss_infos("mu", 6, 5, ["none", "mut", "cel", "fcel", "pat", "ma", "fmu"], ["none", "x", "y", "f", "n", "c"]), ss_infos("opx", 7, 6, ["none", "en", "fs", "fm", "mgts", "fopx", "mnopx", "odi"], ["none", "x", "m", "y", "f", "c", "Q"]), ss_infos("sa", 5, 4, ["none", "spr4", "spr5", "fspm", "spro", "ospr"], ["none", "x", "y", "f", "Q"]), ss_infos("cd", 4, 3, ["none", "crd", "fcrd", "hcrd", "mncd"], ["none", "x", "m", "h"]), ss_infos("st", 5, 4, ["none", "mstm", "fst", "mnstm", "msto", "mstt"], ["none", "x", "m", "f", "t"]), ss_infos("chl", 8, 7, ["none", "clin", "afchl", "ames", "daph", "ochl1", "ochl4", "f3clin", "mmchl"], ["none", "x", "y", "f", "m", "QAl", "Q1", "Q4"]), ss_infos("ctd", 4, 3, ["none", "mctd", "fctd", "mnct", "ctdo"], ["none", "x", "m", "f"]), ss_infos("sp", 4, 3, ["none", "herc", "sp", "mt", "usp"], ["none", "x", "y", "z"]), ss_infos("ilmm", 5, 4, ["none", "oilm", "dilm", "dhem", "geik", "pnt"], ["none", "i", "g", "m", "Q"])], ["liq", "fsp", "bi", "g", "ep", "ma", "mu", "opx", "sa", "cd", "st", "chl", "ctd", "sp", "ilmm"], ["q", "crst", "trd", "coe", "stv", "ky", "sill", "and", "ru", "sph", "O2", "H2O", "qfm", "qif", "nno", "hm", "cco"]), db_infos("mb", "Metabasite (Green et al., 2016)", ss_infos[ss_infos("sp", 4, 3, ["none", "herc", "sp", "mt", "usp"], ["none", "x", "y", "z"]), ss_infos("opx", 6, 5, ["none", "en", "fs", "fm", "mgts", "fopx", "odi"], ["none", "x", "y", "f", "c", "Q"]), ss_infos("fsp", 3, 2, ["none", "ab", "an", "san"], ["none", "ca", "k"]), ss_infos("liq", 9, 8, ["none", "q4L", "abL", "kspL", "wo1L", "sl1L", "fa2L", "fo2L", "watL", "anoL"], ["none", "q", "fsp", "na", "wo", "sil", "ol", "x", "yan"]), ss_infos("mu", 6, 5, ["none", "mu", "cel", "fcel", "pa", "mam", "fmu"], ["none", "x", "y", "f", "n", "c"]), ss_infos("ilm", 3, 2, ["none", "oilm", "dilm", "dhem"], ["none", "x", "Q"]), ss_infos("ol", 2, 1, ["none", "fo", "fa"], ["none", "x"]), ss_infos("hb", 11, 10, ["none", "tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["none", "x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ep", 3, 2, ["none", "cz", "ep", "fep"], ["none", "f", "Q"]), ss_infos("g", 4, 3, ["none", "py", "alm", "gr", "kho"], ["none", "x", "z", "f"]), ss_infos("chl", 7, 6, ["none", "clin", "afchl", "ames", "daph", "ochl1", "ochl4", "f3clin"], ["none", "x", "y", "f", "QAl", "Q1", "Q4"]), ss_infos("bi", 6, 5, ["none", "phl", "annm", "obi", "east", "tbi", "fbi"], ["none", "x", "y", "f", "t", "Q"]), ss_infos("dio", 7, 6, ["none", "jd", "di", "hed", "acmm", "om", "cfm", "jac"], ["none", "x", "j", "t", "c", "Qaf", "Qfm"]), ss_infos("abc", 2, 1, ["none", "abm", "anm"], ["none", "ca"])], ["sp", "opx", "fsp", "liq", "mu", "ilm", "ol", "hb", "ep", "g", "chl", "bi", "dio", "abc"], ["q", "crst", "trd", "coe", "law", "ky", "sill", "and", "ru", "sph", "sph", "ab", "H2O", "qfm", "qif", "nno", "hm", "cco"]), db_infos("ig", "Igneous HP18 (Green et al., 2023)", ss_infos[ss_infos("spn", 8, 7, ["none", "nsp", "isp", "nhc", "ihc", "nmt", "imt", "pcr", "usp"], ["none", "x", "y", "c", "t", "Q1", "Q2", "Q3"]), ss_infos("bi", 6, 5, ["none", "phl", "annm", "obi", "eas", "tbi", "fbi"], ["none", "x", "y", "f", "t", "Q"]), ss_infos("cd", 3, 2, ["none", "crd", "fcrd", "hcrd"], ["none", "x", "h"]), ss_infos("cpx", 10, 9, ["none", "di", "cfs", "cats", "crdi", "cess", "cbuf", "jd", "cen", "cfm", "kjd"], ["none", "x", "y", "o", "n", "Q", "f", "cr", "t", "k"]), ss_infos("ep", 3, 2, ["none", "cz", "ep", "fep"], ["none", "f", "Q"]), ss_infos("g", 6, 5, ["none", "py", "alm", "gr", "andr", "knom", "tig"], ["none", "x", "c", "f", "cr", "t"]), ss_infos("hb", 11, 10, ["none", "tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["none", "x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ilm", 5, 4, ["none", "oilm", "dilm", "hm", "ogk", "dgk"], ["none", "i", "m", "Q", "Qt"]), ss_infos("liq", 12, 11, ["none", "q4L", "slL", "wo1L", "fo2L", "fa2L", "jdL", "hmL", "ekL", "tiL", "kjL", "ctL", "wat1L"], ["none", "wo", "sl", "fo", "fa", "jd", "hm", "ek", "ti", "kj", "yct", "h2o"]), ss_infos("ol", 4, 3, ["none", "mont", "fa", "fo", "cfm"], ["none", "x", "c", "Q"]), ss_infos("opx", 9, 8, ["none", "en", "fs", "fm", "odi", "mgts", "cren", "obuf", "mess", "ojd"], ["none", "x", "y", "c", "Q", "f", "t", "cr", "j"]), ss_infos("fsp", 3, 2, ["none", "ab", "an", "san"], ["none", "ca", "k"]), ss_infos("fl", 11, 10, ["none", "qfL", "slfL", "wofL", "fofL", "fafL", "jdfL", "hmfL", "ekfL", "tifL", "kjfL", "H2O"], ["none", "wo", "sl", "fo", "fa", "jd", "hm", "ek", "ti", "kj", "h2o"]), ss_infos("fper", 2, 1, ["none", "per", "wu"], ["none", ""])], ["spn", "bi", "cd", "cpx", "ep", "g", "hb", "ilm", "liq", "ol", "opx", "fsp", "fl", "fper"], ["q", "crst", "trd", "coe", "stv", "ky", "sill", "and", "ru", "sph", "O2", "qfm", "mw", "qif", "nno", "hm", "cco"]), db_infos("ige", "Igneous HP18 (Green et al., 2023), extended", ss_infos[ss_infos("spn", 8, 7, ["none", "nsp", "isp", "nhc", "ihc", "nmt", "imt", "pcr", "usp"], ["none", "x", "y", "c", "t", "Q1", "Q2", "Q3"]), ss_infos("bi", 6, 5, ["none", "phl", "annm", "obi", "eas", "tbi", "fbi"], ["none", "x", "y", "f", "t", "Q"]), ss_infos("cd", 3, 2, ["none", "crd", "fcrd", "hcrd"], ["none", "x", "h"]), ss_infos("cpx", 10, 9, ["none", "di", "cfs", "cats", "crdi", "cess", "cbuf", "jd", "cen", "cfm", "kjd"], ["none", "x", "y", "o", "n", "Q", "f", "cr", "t", "k"]), ss_infos("ep", 3, 2, ["none", "cz", "ep", "fep"], ["none", "f", "Q"]), ss_infos("g", 6, 5, ["none", "py", "alm", "gr", "andr", "knom", "tig"], ["none", "x", "c", "f", "cr", "t"]), ss_infos("hb", 11, 10, ["none", "tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["none", "x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ilm", 5, 4, ["none", "oilm", "dilm", "hm", "ogk", "dgk"], ["none", "i", "m", "Q", "Qt"]), ss_infos("liq", 12, 11, ["none", "q4L", "slL", "wo1L", "fo2L", "fa2L", "jdL", "hmL", "ekL", "tiL", "kjL", "ctL", "wat1L"], ["none", "wo", "sl", "fo", "fa", "jd", "hm", "ek", "ti", "kj", "yct", "h2o"]), ss_infos("ol", 4, 3, ["none", "mont", "fa", "fo", "cfm"], ["none", "x", "c", "Q"]), ss_infos("opx", 9, 8, ["none", "en", "fs", "fm", "odi", "mgts", "cren", "obuf", "mess", "ojd"], ["none", "x", "y", "c", "Q", "f", "t", "cr", "j"]), ss_infos("fsp", 3, 2, ["none", "ab", "an", "san"], ["none", "ca", "k"]), ss_infos("fl", 11, 10, ["none", "qfL", "slfL", "wofL", "fofL", "fafL", "jdfL", "hmfL", "ekfL", "tifL", "kjfL", "H2O"], ["none", "wo", "sl", "fo", "fa", "jd", "hm", "ek", "ti", "kj", "h2o"]), ss_infos("fper", 2, 1, ["none", "per", "wu"], ["none", ""]), ss_infos("ma", 6, 5, ["none", "mut", "celt", "fcelt", "pat", "ma", "fmu"], ["none", "x", "y", "f", "n", "c"]), ss_infos("chl", 7, 6, ["none", "clin", "afchl", "ames", "daph", "ochl1", "ochl4", "f3clin"], ["none", "x", "y", "f", "QA1", "Q1", "Q4"]), ss_infos("mu", 6, 5, ["none", "mu", "cel", "fcel", "pa", "mam", "fmu"], ["none", "x", "y", "f", "n", "c"])], ["spn", "bi", "cd", "cpx", "ep", "g", "hb", "ilm", "liq", "ol", "opx", "fsp", "fl", "fper", "ma", "chl", "mu"], ["q", "crst", "trd", "coe", "stv", "ky", "sill", "and", "ru", "sph", "O2", "zo", "qfm", "mw", "qif", "nno", "hm", "cco"]), db_infos("igd", "Igneous T21 (Green et al., 2023)", ss_infos[ss_infos("spn", 8, 7, ["none", "nsp", "isp", "nhc", "ihc", "nmt", "imt", "pcr", "usp"], ["none", "x", "y", "c", "t", "Q1", "Q2", "Q3"]), ss_infos("bi", 6, 5, ["none", "phl", "annm", "obi", "eas", "tbi", "fbi"], ["none", "x", "y", "f", "t", "Q"]), ss_infos("cd", 3, 2, ["none", "crd", "fcrd", "hcrd"], ["none", "x", "h"]), ss_infos("cpx", 10, 9, ["none", "di", "cfs", "cats", "crdi", "cess", "cbuf", "jd", "cen", "cfm", "kjd"], ["none", "x", "y", "o", "n", "Q", "f", "cr", "t", "k"]), ss_infos("ep", 3, 2, ["none", "cz", "ep", "fep"], ["none", "f", "Q"]), ss_infos("g", 6, 5, ["none", "py", "alm", "gr", "andr", "knr", "tig"], ["none", "x", "c", "f", "cr", "t"]), ss_infos("hb", 11, 10, ["none", "tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["none", "x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ilm", 5, 4, ["none", "oilm", "dilm", "hm", "ogk", "dgk"], ["none", "i", "m", "Q", "Qt"]), ss_infos("liq", 15, 14, ["none", "q3L", "sl1L", "wo1L", "fo2L", "fa2L", "neL", "hmL", "ekL", "tiL", "kjL", "anL", "ab1L", "enL", "kfL", "wat1L"], ["none", "wo", "sl", "fo", "fa", "ne", "hm", "ek", "ti", "kj", "h2o", "yan", "yab", "yen", "ykf"]), ss_infos("ol", 4, 3, ["none", "mnt", "fa", "fo", "cfm"], ["none", "x", "c", "Q"]), ss_infos("opx", 9, 8, ["none", "en", "fs", "fm", "odi", "mgts", "cren", "obuf", "mess", "ojd"], ["none", "x", "y", "c", "Q", "f", "t", "cr", "j"]), ss_infos("fsp", 3, 2, ["none", "ab", "an", "san"], ["none", "ca", "k"]), ss_infos("fl", 4, 3, ["none", "qfL", "nefL", "ksfL", "H2O"], ["none", "ne", "ks", "h2o"]), ss_infos("fper", 2, 1, ["none", "per", "wu"], ["none", ""])], ["spn", "bi", "cd", "cpx", "ep", "g", "hb", "ilm", "liq", "ol", "opx", "fsp", "fl", "fper"], ["q", "crst", "trd", "coe", "stv", "ky", "sill", "and", "ru", "sph", "O2", "qfm", "mw", "qif", "nno", "hm", "cco"]), db_infos("alk", "Alkaline (Weller et al., 2023)", ss_infos[ss_infos("spn", 8, 7, ["none", "nsp", "isp", "nhc", "ihc", "nmt", "imt", "pcr", "usp"], ["none", "x", "y", "c", "t", "Q1", "Q2", "Q3"]), ss_infos("bi", 6, 5, ["none", "phl", "annm", "obi", "eas", "tbi", "fbi"], ["none", "x", "y", "f", "t", "Q"]), ss_infos("cd", 3, 2, ["none", "crd", "fcrd", "hcrd"], ["none", "x", "h"]), ss_infos("cpx", 10, 9, ["none", "di", "cfs", "cats", "crdi", "cess", "cbuf", "jd", "cen", "cfm", "kjd"], ["none", "x", "y", "o", "n", "Q", "f", "cr", "t", "k"]), ss_infos("ep", 3, 2, ["none", "cz", "ep", "fep"], ["none", "f", "Q"]), ss_infos("g", 6, 5, ["none", "py", "alm", "gr", "andr", "knr", "tig"], ["none", "x", "c", "f", "cr", "t"]), ss_infos("hb", 11, 10, ["none", "tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["none", "x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ilm", 5, 4, ["none", "oilm", "dilm", "hm", "ogk", "dgk"], ["none", "i", "m", "Q", "Qt"]), ss_infos("liq", 15, 14, ["none", "q3L", "sl1L", "wo1L", "fo2L", "fa2L", "nmL", "hmL", "ekL", "tiL", "kmL", "anL", "ab1L", "enL", "kfL", "wat1L"], ["none", "wo", "sl", "fo", "fa", "ns", "hm", "ek", "ti", "ks", "h2o", "yan", "yab", "yen", "ykf"]), ss_infos("ol", 4, 3, ["none", "mnt", "fa", "fo", "cfm"], ["none", "x", "c", "Q"]), ss_infos("opx", 9, 8, ["none", "en", "fs", "fm", "odi", "mgts", "cren", "obuf", "mess", "ojd"], ["none", "x", "y", "c", "Q", "f", "t", "cr", "j"]), ss_infos("fsp", 3, 2, ["none", "ab", "an", "san"], ["none", "ca", "k"]), ss_infos("fl", 4, 3, ["none", "qfL", "nefL", "ksfL", "H2O"], ["none", "ne", "ks", "h2o"]), ss_infos("lct", 2, 1, ["none", "nlc", "klc"], ["none", "n"]), ss_infos("mel", 5, 4, ["none", "geh", "ak", "fak", "nml", "fge"], ["none", "x", "n", "y", "f"]), ss_infos("ness", 6, 5, ["none", "neN", "neS", "neK", "neO", "neC", "neF"], ["none", "s", "k", "Q", "f", "c"]), ss_infos("kals", 2, 1, ["none", "nks", "kls"], ["none", "k"])], ["spn", "bi", "cd", "cpx", "ep", "g", "hb", "ilm", "liq", "ol", "opx", "fsp", "fl", "lct", "mel", "ness", "kals"], ["q", "crst", "trd", "coe", "stv", "ky", "sill", "and", "ru", "sph", "O2", "qfm", "mw", "qif", "nno", "hm", "cco"]), db_infos("um", "Ultramafic (Evans & Frost., 2021)", ss_infos[ss_infos("fluid", 2, 1, ["none", "H2", "H2O"], ["none", "x"]), ss_infos("ol", 2, 1, ["none", "fo", "fa"], ["none", "x"]), ss_infos("br", 2, 1, ["none", "br", "fbr"], ["none", "x"]), ss_infos("ch", 2, 1, ["none", "chum", "chuf"], ["none", "x"]), ss_infos("atg", 5, 4, ["none", "atgf", "fatg", "atgo", "aatg", "oatg"], ["none", "x", "y", "f", "t"]), ss_infos("g", 2, 1, ["none", "py", "alm"], ["none", "x"]), ss_infos("ta", 6, 5, ["none", "ta", "fta", "tao", "tats", "ota", "tap"], ["none", "x", "y", "f", "v", "Q"]), ss_infos("chl", 7, 6, ["none", "clin", "afchl", "ames", "daph", "ochl1", "ochl4", "f3clin"], ["none", "x", "y", "f", "m", "t", "QA1"]), ss_infos("spi", 3, 2, ["none", "herc", "sp", "mt"], ["none", "x", "y"]), ss_infos("opx", 5, 4, ["none", "en", "fs", "fm", "mgts", "fopx"], ["none", "x", "y", "f", "Q"]), ss_infos("po", 2, 1, ["none", "trov", "trot"], ["none", "y"]), ss_infos("anth", 5, 4, ["none", "anth", "gedf", "fant", "a", "b"], ["none", "x", "y", "z", "a"])], ["fluid", "ol", "br", "ch", "atg", "g", "ta", "chl", "spi", "opx", "po", "anth"], ["q", "crst", "trd", "coe", "stv", "ky", "sill", "and", "pyr", "O2", "qfm", "qif", "nno", "hm", "cco"])]
    dbs     = ["mp","mb","ig","ige","igd","alk","um"]
    id      = findall(dbs .== dtb)[1]

    return db_inf[id]
end


"""
    Diagram type function 
        diagram_type(diagType, tmin, tmax, pmin, pmax)

    returns axis titles and axis ranges
"""
function diagram_type(diagType, tmin, tmax, pmin, pmax)
    if diagType == "pt"
        xtitle = "Temperature [Celsius]"
        ytitle = "Pressure [kbar]"
        Xrange          = (Float64(tmin),Float64(tmax))
        Yrange          = (Float64(pmin),Float64(pmax))
    elseif diagType == "px"
        Xrange          = (Float64(0.0),Float64(1.0))
        Yrange          = (Float64(pmin),Float64(pmax))
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Pressure [kbar]"
    else # diagType == "tx"
        Xrange          = (Float64(0.0),Float64(1.0) )
        Yrange          = (Float64(tmin),Float64(tmax))
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Temperature [Celsius]"
    end
    return xtitle, ytitle, Xrange, Yrange
end

"""
    convert2Float64(bufferN1, bufferN2,fixT,fixP)

    converts input to float if the provided value is an integer
"""
function convert2Float64(bufferN1, bufferN2,fixT,fixP)
    bufferN1 = Float64(bufferN1)
    bufferN2 = Float64(bufferN2)
    fixT     = Float64(fixT)
    fixP     = Float64(fixP)

    return bufferN1, bufferN2, fixT, fixP
end

"""
    pushed_button( ctx )

    Get the id of the last pushed button
"""
function pushed_button( ctx )
    ctx = callback_context()
    if length(ctx.triggered) == 0
        bid = ""
    else
        bid = split(ctx.triggered[1].prop_id, ".")[1]
    end
    return bid
end

"""
    get_colormap_prop(colorMap, rangeColor, reverse) 

    retrieve colormap range and reserve boolean
"""
function get_colormap_prop(colorMap, rangeColor, reverse) 

    if rangeColor == [1,9]
        colorm = colors[Symbol(colorMap)]
    else
        colorm = restrict_colorMapRange(colorMap,rangeColor)
    end

    if reverse == "false"
        reverseColorMap = false
    else
        reverseColorMap = true
    end

    return colorm, reverseColorMap
end



"""
    get_bulkrock_prop(bulk1, bulk2)

    retrieve bulk rock composition and components from dash table
"""
function get_bulkrock_prop(bulk1, bulk2)
 
    n_ox    = length(bulk1);
    bulk_L  = zeros(n_ox); 
    bulk_R  = zeros(n_ox);
    oxi     = Vector{String}(undef, n_ox)
    # in case the bulk rock is entered manually, the inputed values can be a string, this ensures convertion to float64
    for i=1:n_ox
        tmp = bulk1[i][:mol_fraction]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        tmp2 = bulk2[i][:mol_fraction]
        if typeof(tmp2) == String
            tmp2 = parse(Float64,tmp2)
        end
        bulk_L[i]   = tmp;
        bulk_R[i]   = tmp2;
        oxi[i]      = bulk1[i][:oxide];
    end

    return bulk_L, bulk_R, oxi
end


"""
    compute_new_phaseDiagram(   xtitle,     ytitle,     
                                Xrange,     Yrange,     fieldname,
                                dtb,        diagType,   verbose,
                                fixT,       fixP,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                smooth,     colorm,     reverseColorMap,
                                test,       PT_infos,   refType                                     )

    Compute a new phase diagram from scratch
"""
function compute_new_phaseDiagram(  xtitle,     ytitle,     lbl,
                                    Xrange,     Yrange,     fieldname,  customTitle,
                                    dtb,        diagType,   verbose,    solver,
                                    fixT,       fixP,
                                    sub,        refLvl,
                                    cpx,        limOpx,     limOpxVal,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    smooth,     colorm,     reverseColorMap,
                                    test,       refType                                  )

        empty!(AppData.PseudosectionData);              #this empty the data from previous pseudosection computation

        #________________________________________________________________________________________#
        # Create coarse mesh
        cmesh           = t8_cmesh_quad_2d(MPI.COMM_WORLD, Xrange, Yrange)

        # Refine coarse mesh (in a regular manner)
        level           = sub
        forest          = t8_forest_new_uniform(cmesh, t8_scheme_new_default_cxx(), level, 0, MPI.COMM_WORLD)
        data            = get_element_data(forest)

        #________________________________________________________________________________________#
        # initialize database
        global forest, data, Hash_XY, Out_XY, n_phase_XY, field, data_plot, gridded, gridded_info, X, Y, PhasesLabels, layout, n_lbl
        global addedRefinementLvl  = 0;
        global MAGEMin_data;

        # set clinopyroxene for the metabasite database
        mbCpx = 0
        if cpx == true && dtb =="mb"
            mbCpx = 1;
        end
        limitCaOpx  = 0
        CaOpxLim    = 1.0
        if limOpx == "ON" && (dtb =="mb" || dtb =="ig" || dtb =="igd" || dtb =="alk")
            limitCaOpx   = 1
            CaOpxLim     = limOpxVal
        end
        if solver == "pge"
            sol = 1
        elseif solver == "lp"
            sol = 0
        elseif solver == "hyb" 
            sol = 2         
        end

        MAGEMin_data    =   Initialize_MAGEMin( dtb;
                                                verbose     = false,
                                                limitCaOpx  = limitCaOpx,
                                                CaOpxLim    = CaOpxLim,
                                                mbCpx       = mbCpx,
                                                buffer      = bufferType,
                                                solver      = sol    );

        #________________________________________________________________________________________#                      
        # initial optimization on regular grid
        Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  data, 
                                                        MAGEMin_data,
                                                        diagType,
                                                        fixT,
                                                        fixP,
                                                        oxi,
                                                        bulk_L,
                                                        bulk_R,
                                                        bufferType,
                                                        bufferN1,
                                                        bufferN2,
                                                        refType    )
                    
        #________________________________________________________________________________________#     
        # Refine the mesh along phase boundaries

        for irefine = 1:refLvl
            refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
            forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
            t = @elapsed Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(  data_new,
                                                                        MAGEMin_data,
                                                                        diagType,
                                                                        fixT,
                                                                        fixP,
                                                                        oxi,
                                                                        bulk_L,
                                                                        bulk_R,
                                                                        bufferType,
                                                                        bufferN1,
                                                                        bufferN2,
                                                                        refType, 
                                                                        ind_map         = ind_map,
                                                                        Out_XY_old      = Out_XY,
                                                                        n_phase_XY_old  = n_phase_XY    ) # recompute points that have not been computed before

            println("Computed $(length(ind_map.<0)) new points in $t seconds")
            data    = data_new
            forest  = forest_new
            
        end

        push!(AppData.PseudosectionData,Out_XY);

        #________________________________________________________________________________________#                   
        # Scatter plotly of the grid

        gridded, gridded_info, X, Y, npoints, meant = get_gridded_map(  fieldname,
                                                                        oxi,
                                                                        Out_XY,
                                                                        Hash_XY,
                                                                        sub,
                                                                        refLvl,
                                                                        refType,
                                                                        data.xc,
                                                                        data.yc,
                                                                        data.x,
                                                                        data.y,
                                                                        Xrange,
                                                                        Yrange)

        PT_infos                           = get_phase_diagram_information(npoints, dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2)

        data_plot, annotations = get_diagram_labels(    fieldname,
                                                        oxi,
                                                        Out_XY,
                                                        Hash_XY,
                                                        sub,
                                                        refLvl,
                                                        refType,
                                                        data.xc,
                                                        data.yc,
                                                        PT_infos )
        ticks   = 4
        frame   = get_plot_frame(Xrange,Yrange, ticks)                                  
        layout  = Layout(
                    images=frame,
                    title= attr(
                        text    = customTitle,
                        x       = 0.4,
                        xanchor = "center",
                        yanchor = "top"
                    ),
                    hoverlabel = attr(
                        bgcolor     = "#566573",
                        bordercolor = "#f8f9f9",
                    ),
                    plot_bgcolor = "#FFF",
                    paper_bgcolor = "#FFF",
                    xaxis_title = xtitle,
                    yaxis_title = ytitle,
                    annotations = annotations,
                    width       = 900,
                    height      = 900,
                    autosize    = false,
                    margin      = attr(autoexpand = false, l=50, r=280, b=260, t=70, pad=4),
                    xaxis_range = Xrange, 
                    yaxis_range = Yrange,
                    xaxis       = attr(     tickmode    = "linear",
                                            tick0       = Xrange[1],
                                            dtick       = (Xrange[2]-Xrange[1])/(ticks+1)
                                        ),
                    yaxis       = attr(     tickmode    = "linear",
                                            tick0       = Yrange[1],
                                            dtick       = (Yrange[2]-Yrange[1])/(ticks+1)
                                    ),
                )
                
        heat_map = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
                            zsmooth         = smooth,
                            connectgaps     = true,
                            type            = "heatmap",
                            colorscale      = colorm,
                            reversescale    = reverseColorMap,
                            colorbar_title  = fieldname,
                            hoverinfo       = "skip",
                            showlegend      = false,
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5         ),)

 
        hover_lbl = heatmap(    x               = X,
                                y               = Y,
                                z               = X,
                                type            = "heatmap",
                                showscale       = false,
                                opacity         = 0.0,
                                hoverinfo       = "text",
                                showlegend      = false,
                                text            = gridded_info )


        data_plot[1]    = heat_map

        return vcat(data_plot,hover_lbl), layout, npoints, meant
end



"""
    refine_phaseDiagram(   xtitle,     ytitle,     
                                    Xrange,     Yrange,     fieldname,
                                    dtb,        diagType,   verbose,
                                    fixT,       fixP,
                                    sub,        refLvl,
                                    cpx,        limOpx,     limOpxVal,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    smooth,     colorm,     reverseColorMap,
                                    test,       PT_infos,   refType                                   )
    Refine existing phase diagram
"""
function refine_phaseDiagram(   xtitle,     ytitle,     lbl,
                                Xrange,     Yrange,     fieldname,  customTitle,
                                dtb,        diagType,   verbose,    solver,
                                fixT,       fixP,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                smooth,     colorm,     reverseColorMap,
                                test,       refType                                 )

    global MAGEMin_data, forest, data, Hash_XY, Out_XY, n_phase_XY, field, data_plot, gridded, gridded_info, X, Y, PhasesLabels, addedRefinementLvl, layout, n_lbl

    refine_elements                          = refine_phase_boundaries(forest, Hash_XY);
    forest_new, data_new, ind_map            = adapt_forest(forest, refine_elements, data);     # Adapt the mesh; also returns the new coordinates and a mapping from old->new
    t = @elapsed Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(  data_new,
                                                                MAGEMin_data,
                                                                diagType,
                                                                fixT,
                                                                fixP,
                                                                oxi,
                                                                bulk_L,
                                                                bulk_R,
                                                                bufferType,
                                                                bufferN1,
                                                                bufferN2, 
                                                                refType,
                                                                ind_map         = ind_map,
                                                                Out_XY_old      = Out_XY,
                                                                n_phase_XY_old  = n_phase_XY) # recompute points that have not been computed before

    println("Computed $(length(ind_map.<0)) new points in $(round(t, digits=3)) seconds")
    data                = data_new
    forest              = forest_new
    addedRefinementLvl += 1;

    empty!(AppData.PseudosectionData)
    push!(AppData.PseudosectionData,Out_XY);

    #________________________________________________________________________________________#                   
    # Scatter plotly of the grid
    gridded, gridded_info, X, Y, npoints, meant = get_gridded_map(  fieldname,
                                                                    oxi,
                                                                    Out_XY,
                                                                    Hash_XY,
                                                                    sub,
                                                                    refLvl + addedRefinementLvl,
                                                                    refType,
                                                                    data.xc,
                                                                    data.yc,
                                                                    data.x,
                                                                    data.y,
                                                                    Xrange,
                                                                    Yrange )
    
    PT_infos                           = get_phase_diagram_information(npoints,dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2)
                                                              
    data_plot, annotations = get_diagram_labels(    fieldname,
                                                    oxi,
                                                    Out_XY,
                                                    Hash_XY,
                                                    sub,
                                                    refLvl,
                                                    refType,
                                                    data.xc,
                                                    data.yc,
                                                    PT_infos )
    layout[:annotations] = annotations 
    layout[:title] = attr(
        text    = customTitle,
        x       = 0.4,
        xanchor = "center",
        yanchor = "top"
    )
    
    data_plot[1] = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
                            connectgaps     = true,
                            zsmooth         =  smooth,
                            type            = "heatmap",
                            colorscale      = colorm,
                            colorbar_title  = fieldname,
                            reversescale    = reverseColorMap,
                            hoverinfo       = "skip",
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5         ),)

    hover_lbl = heatmap(    x               = X,
                            y               = Y,
                            z               = X,
                            type            = "heatmap",
                            showscale       = false,
                            opacity         = 0.0,
                            hoverinfo       = "text",
                            showlegend      = false,
                            text            = gridded_info )

    return vcat(data_plot,hover_lbl), layout, npoints, meant

end


"""
    update_colormap_phaseDiagram(      xtitle,     ytitle,     
                                                Xrange,     Yrange,     fieldname,
                                                dtb,        diagType,
                                                smooth,     colorm,     reverseColorMap,
                                                test                                  )
    Updates the colormap configuration of the phase diagram
"""
function update_colormap_phaseDiagram(      xtitle,     ytitle,     
                                            Xrange,     Yrange,     fieldname,
                                            dtb,        diagType,
                                            smooth,     colorm,     reverseColorMap,
                                            test                                  )
    global PT_infos, layout

    data_plot[1] = heatmap( x               =  X,
                            y               =  Y,
                            z               =  gridded,
                            zsmooth         =  smooth,
                            connectgaps     = true,
                            type            = "heatmap",
                            colorscale      =  colorm,
                            colorbar_title  =  fieldname,
                            reversescale    =  reverseColorMap,
                            hoverinfo       = "skip",
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5         ),)

    return data_plot,layout
end


"""
    show_hide_reaction_lines(    xtitle,     ytitle,     grid,  
                                    Xrange,     Yrange,     fieldname,
                                    dtb,
                                    smooth,     colorm,     reverseColorMap,
                                    test                                  )
    Shows/hides the grid
"""
function  show_hide_reaction_lines(  sub, 
                                        refLvl, 
                                        Xrange, 
                                        Yrange  )

    global data, Hash_XY, addedRefinementLvl

    boundaries  = get_boundaries(   Hash_XY,
                                    sub,
                                    refLvl+addedRefinementLvl,
                                    Xrange,
                                    Yrange,
                                    data.xc,
                                    data.yc,
                                    data.x,
                                    data.y          ) 
    
    bnd            = findall(boundaries .> 0)

    # np             = length(bnd)
    # grid_plot      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, np);
    # for i = 1:np

    #     x = vcat(data.x[boundaries[bnd[i]]],data.x[boundaries[bnd[i]]][1])
    #     y = vcat(data.y[boundaries[bnd[i]]],data.y[boundaries[bnd[i]]][1])
    #     grid_plot[i] = scatter(     x           = x,
    #                                 y           = y,
    #                                 mode        = "lines",
    #                                 # line_color  = "#FFFFFF",
    #                                 line_color  = "#333333",
    #                                 line_width  = 0.2,
    #                                 showlegend  = false     )
    # end

    grid_plot = GenericTrace{Dict{Symbol, Any}}

    grid_plot =  scatter(   x           = data.xc[boundaries[bnd]],
                            y           = data.yc[boundaries[bnd]],
                            mode        = "markers",
                            # line_color  = "#FFFFFF",
                            # color       = "#333333",
                            marker      = attr(color = "#333333", size = 1.5),
                            hoverinfo   = "skip",
                            showlegend  = false     );

    # print("$data \n")


    # n_hull      = length(unique(Hash_XY))
    # hull_list   = Vector{Any}(undef,    n_hull)
    # id          = 0

    # for i in unique(Hash_XY)
    #     field_tmp   = findall(Hash_XY .== i)
    
    #     # t2          = reduce(vcat,data.x[field_tmp])
    #     # p2          = reduce(vcat,data.y[field_tmp])
    
    #     t2          = data.xc[field_tmp]
    #     p2          = data.yc[field_tmp]

    #     np          = length(t2)
    #     if np > 2
    #         id             += 1
    #         points          = [[ t2[i]+rand()/100, p2[i]+rand()/100] for i=1:np]
    #         hull_list[id]   = concave_hull(points,1024)
    #     end
    # end
    # n_trace     = id;
    # grid_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,n_trace);

    # for i = 1:n_trace

    #     tmp     = mapreduce(permutedims,vcat,hull_list[i].vertices)
    #     tmp     = vcat(tmp,tmp[1,:]')
    
    #     grid_plot[i] = scatter(     x           =  tmp[:,1],
    #                                 y           =  tmp[:,2],
    #                                 mode        = "lines",
    #                                 # line_color  = "#FFFFFF",
    #                                 line_color  = "#333333",
    #                                 line_width  = 0.2,
    #                                 showlegend  = false     )
    # end

    return grid_plot
end




"""
    show_hide_reaction_lines(    xtitle,     ytitle,     grid,  
                                    Xrange,     Yrange,     fieldname,
                                    dtb,
                                    smooth,     colorm,     reverseColorMap,
                                    test                                  )
    Shows/hides the grid
"""
function  show_hide_mesh_grid()

    np             = length(data.x)
    grid_plot      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, np);
    for i = 1:np

        grid_plot[i] = scatter(     x           = data.x[i],
                                    y           = data.y[i],
                                    mode        = "lines",
                                    # line_color  = "#FFFFFF",
                                    line_color  = "#333333",
                                    line_width  = 0.2,
                                    hoverinfo   = "skip",
                                    showlegend  = false     )
    end

    return grid_plot
end




"""
    update_diplayed_field_phaseDiagram(   xtitle,     ytitle,     
                                                    Xrange,     Yrange,     fieldname,
                                                    dtb,        oxi,
                                                    sub,        refLvl,
                                                    smooth,     colorm,     reverseColorMap,
                                                    test                                  )
    Updates the field displayed
"""
function  update_diplayed_field_phaseDiagram(   xtitle,     ytitle,     
                                                Xrange,     Yrange,     fieldname,
                                                dtb,        oxi,
                                                sub,        refLvl,
                                                smooth,     colorm,     reverseColorMap,
                                                test,       refType                                  )

    global data, Out_XY, data_plot, gridded, gridded_info, X, Y, PhasesLabels, addedRefinementLvl, PT_infos, layout

    gridded, X, Y, npoints, meant = get_gridded_map_no_lbl(     fieldname,
                                                                oxi,
                                                                Out_XY,
                                                                Hash_XY,
                                                                sub,
                                                                refLvl + addedRefinementLvl,
                                                                refType,
                                                                data.xc,
                                                                data.yc,
                                                                data.x,
                                                                data.y,
                                                                Xrange,
                                                                Yrange )


    data_plot[1] = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
                            zsmooth         = smooth,
                            connectgaps     = true,
                            type            = "heatmap",
                            colorscale      = colorm,
                            colorbar_title  = fieldname,
                            reversescale    = reverseColorMap,
                            hoverinfo       = "skip",
                            # hoverinfo       = "text",
                            # text            = gridded_info,
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5         ),)

    return data_plot,layout
end

"""

    Initiatize global variable storing isopleths information
"""
function initialize_g_isopleth(; n_iso_max = 32)
    global data_isopleth

    status    = zeros(Int64,n_iso_max)
    active    = []
    isoP      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap

    for i=1:n_iso_max
        isoP[i] = contour()
    end

    label     = Vector{String}(undef,n_iso_max)
    value     = Vector{Int64}(undef,n_iso_max)

    data_isopleth = isopleth_data(0, n_iso_max,
                                status, active, isoP,
                                label, value)

    
    return data_isopleth
end


"""

    add_isopleth_phaseDiagram
"""
function add_isopleth_phaseDiagram(         Xrange,     Yrange, 
                                            sub,        refLvl,
                                            dtb,        oxi,
                                            isopleths,  phase,      ss,     em,     of,
                                            isoColorLine,           isoLabelSize,       
                                            minIso,     stepIso,    maxIso      )

    isoLabelSize    = Int64(isoLabelSize)

    if (phase == "ss" && em == "none") || (phase == "pp")
        mod     = "ph_frac"
        em      = ""
        name    = ss*"_mode"
    elseif (phase == "ss" && em != "none")
        mod     = "em_frac"
        name    = ss*"_"*em*"_mode"
    elseif (phase == "of")
        em      = ""
        ss      = ""
        mod     = "of_mod"
        name    = of
    end

    global data_isopleth, nIsopleths, data, Out_XY, data_plot, X, Y, addedRefinementLvl

    gridded, X, Y = get_isopleth_map(   mod, ss, em, of,
                                        oxi,
                                        Out_XY,
                                        sub,
                                        refLvl + addedRefinementLvl,
                                        data.xc,
                                        data.yc,
                                        data.x,
                                        data.y,
                                        Xrange,
                                        Yrange )

    data_isopleth.n_iso += 1

    data_isopleth.isoP[data_isopleth.n_iso]= contour(     x                   = X,
                                                y                   = Y,
                                                z                   = gridded,
                                                contours_coloring   = "lines",
                                                colorscale          = [[0, isoColorLine], [1, isoColorLine]],
                                                
                                                contours_start      = minIso,
                                                contours_end        = maxIso,
                                                contours_size       = stepIso,
                                                line_width          = 1,
                                                showscale           = false,
                                                hoverinfo           = "skip",
                                                contours            =  attr(    coloring    = "lines",
                                                                                showlabels  = true,
                                                                                labelfont   = attr( size    = isoLabelSize,
                                                                                                    color   = isoColorLine,  )
                                                )
                                            )
    data_isopleth.status[data_isopleth.n_iso]   = 1
    data_isopleth.label[data_isopleth.n_iso]    = name
    data_isopleth.value[data_isopleth.n_iso]    = data_isopleth.n_iso
    data_isopleth.active                   = findall(data_isopleth.status .== 1)
    n_act                             = length(data_isopleth.active)

    isopleths = [Dict("label" => data_isopleth.label[data_isopleth.active[i]], "value" => data_isopleth.value[data_isopleth.active[i]])
                        for i=1:n_act]

    return data_isopleth, isopleths

end

function remove_single_isopleth_phaseDiagram(isoplethsID)
    global data_isopleth

    data_isopleth.n_iso                -= 1      
    data_isopleth.status[isoplethsID]   = 0;
    data_isopleth.isoP[isoplethsID]     = contour()
    data_isopleth.label[isoplethsID]    = ""
    data_isopleth.value[isoplethsID]    = 0
    data_isopleth.active                = findall(data_isopleth.status .== 1)
    n_act                          = length(data_isopleth.active)
    isopleths = [Dict("label" => data_isopleth.label[data_isopleth.active[i]], "value" => data_isopleth.value[data_isopleth.active[i]])
                    for i=1:n_act]

    return data_isopleth, isopleths
end


function remove_all_isopleth_phaseDiagram()
    global data_isopleth, data_plot

    data_isopleth.label    .= ""
    data_isopleth.value    .= 0
    data_isopleth.n_iso     = 0
    for i=1:data_isopleth.n_iso_max
        data_isopleth.isoP[i] = contour()
    end
    data_isopleth.status   .= 0
    data_isopleth.active   .= 0

    # clear isopleth dropdown menu
    isopleths = []              

    return data_isopleth, isopleths, data_plot
end