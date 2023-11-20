using MAGEMin_C


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
    data_pp :: Array{String}
end


db_details      = [ "Metapelite (White et al., 2014)",
                    "Metabasite (Green et al., 2016)",
                    "Igneous HP18 (Green et al., 2023)",
                    "Igneous T21 (Green et al., 2023)",
                    "Alkaline (Weller et al., 2023)",
                    "Ultramafic (Tomlinson et al., 2021)"]

database_list   = ["mp","mb","ig","igd","alk","um"]
db_inf          = Array{db_infos, 1}(undef, length(database_list))

for k=1:length(database_list)
    dtb         = database_list[k]
    gv, z_b, DB, splx_data  = init_MAGEMin(dtb; mbCpx = 0);
    sys_in      =   "mol"     #default is mol, if wt is provided conversion will be done internally (MAGEMin works on mol basis)
    test        =   0         #KLB1
    gv          =   use_predefined_bulk_rock(gv, test, dtb);
    gv.verbose  =  -1
    P           =   8.0
    T           =   800.0
    out         =   point_wise_minimization(P,T, gv, z_b, DB, splx_data, sys_in);

    ss_struct  = unsafe_wrap(Vector{LibMAGEMin.SS_ref},DB.SS_ref_db,gv.len_ss);
    ss_names   = unsafe_string.(unsafe_wrap(Vector{Ptr{Int8}}, gv.SS_list, gv.len_ss));
    pp_names   = unsafe_string.(unsafe_wrap(Vector{Ptr{Int8}}, gv.PP_list, gv.len_pp));

    ss = Array{ss_infos, 1}(undef, gv.len_ss)

    for i=1:gv.len_ss
        n_em 	= ss_struct[i].n_em
        n_xeos 	= ss_struct[i].n_xeos
        
        em_names   = unsafe_string.(unsafe_wrap(Vector{Ptr{Int8}}, ss_struct[i].EM_list, n_em))

        em_names2  = Vector{String}(undef,n_em+1)
        em_names2[1] = "none"
        em_names2[2:end] = em_names


        xeos_names = unsafe_string.(unsafe_wrap(Vector{Ptr{Int8}}, ss_struct[i].CV_list, n_xeos))
        xeos_names2  = Vector{String}(undef,n_xeos+1)
        xeos_names2[1] = "none"
        xeos_names2[2:end] = xeos_names



        ss[i]   = ss_infos(ss_names[i], n_em, n_xeos, em_names2, xeos_names2)
    end


    db_inf[k] = db_infos(database_list[k],db_details[k],ss,pp_names)

end

print(db_inf)


# for i=1:length(database_list)
#     print("$(db_inf[i])\n\n")
# end


# test = db_infos[db_infos("mp", "Metapelite (White et al., 2014)", ss_infos[ss_infos("liq", 8, 7, ["q4L", "abL", "kspL", "anL", "slL", "fo2L", "fa2L", "h2oL"], ["q", "fsp", "na", "an", "ol", "x", "h2o"]), ss_infos("pl4tr", 3, 2, ["ab", "an", "san"], ["ca", "k"]), ss_infos("bi", 7, 6, ["phl", "annm", "obi", "east", "tbi", "fbi", "mmbi"], ["x", "m", "y", "f", "t", "Q"]), ss_infos("g", 5, 4, ["py", "alm", "spss", "gr", "kho"], ["x", "z", "m", "f"]), ss_infos("ep", 3, 2, ["cz", "ep", "fep"], ["f", "Q"]), ss_infos("ma", 6, 5, ["mut", "celt", "fcelt", "pat", "ma", "fmu"], ["x", "y", "f", "n", "c"]), ss_infos("mu", 6, 5, ["mut", "cel", "fcel", "pat", "ma", "fmu"], ["x", "y", "f", "n", "c"]), ss_infos("opx", 7, 6, ["en", "fs", "fm", "mgts", "fopx", "mnopx", "odi"], ["x", "m", "y", "f", "c", "Q"]), ss_infos("sa", 5, 4, ["spr4", "spr5", "fspm", "spro", "ospr"], ["x", "y", "f", "Q"]), ss_infos("cd", 4, 3, ["crd", "fcrd", "hcrd", "mncd"], ["x", "m", "h"]), ss_infos("st", 5, 4, ["mstm", "fst", "mnstm", "msto", "mstt"], ["x", "m", "f", "t"]), ss_infos("chl", 8, 7, ["clin", "afchl", "ames", "daph", "ochl1", "ochl4", "f3clin", "mmchl"], ["x", "y", "f", "m", "QAl", "Q1", "Q4"]), ss_infos("ctd", 4, 3, ["mctd", "fctd", "mnct", "ctdo"], ["x", "m", "f"]), ss_infos("sp", 4, 3, ["herc", "sp", "mt", "usp"], ["x", "y", "z"]), ss_infos("ilm", 5, 4, ["oilm", "dilm", "dhem", "geik", "pnt"], ["i", "g", "m", "Q"]), ss_infos("mt", 3, 2, ["imt", "dmt", "usp"], ["x", "Q"])]), db_infos("mb", "Metabasite (Green et al., 2016)", ss_infos[ss_infos("sp", 4, 3, ["herc", "sp", "mt", "usp"], ["x", "y", "z"]), ss_infos("opx", 6, 5, ["en", "fs", "fm", "mgts", "fopx", "odi"], ["x", "y", "f", "c", "Q"]), ss_infos("pl4tr", 3, 2, ["ab", "an", "san"], ["ca", "k"]), ss_infos("liq", 9, 8, ["q4L", "abL", "kspL", "wo1L", "sl1L", "fa2L", "fo2L", "watL", "anoL"], ["q", "fsp", "na", "wo", "sil", "ol", "x", "yan"]), ss_infos("mu", 6, 5, ["mu", "cel", "fcel", "pa", "mam", "fmu"], ["x", "y", "f", "n", "c"]), ss_infos("ilm", 3, 2, ["oilm", "dilm", "dhem"], ["x", "Q"]), ss_infos("ol", 2, 1, ["fo", "fa"], ["x"]), ss_infos("hb", 11, 10, ["tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ep", 3, 2, ["cz", "ep", "fep"], ["f", "Q"]), ss_infos("g", 4, 3, ["py", "alm", "gr", "kho"], ["x", "z", "f"]), ss_infos("chl", 7, 6, ["clin", "afchl", "ames", "daph", "ochl1", "ochl4", "f3clin"], ["x", "y", "f", "QAl", "Q1", "Q4"]), ss_infos("bi", 6, 5, ["phl", "annm", "obi", "east", "tbi", "fbi"], ["x", "y", "f", "t", "Q"]), ss_infos("dio", 7, 6, ["jd", "di", "hed", "acmm", "om", "cfm", "jac"], ["x", "j", "t", "c", "Qaf", "Qfm"]), ss_infos("abc", 2, 1, ["abm", "anm"], ["ca"])]), db_infos("ig", "Igneous HP18 (Green et al., 2023)", ss_infos[ss_infos("spn", 8, 7, ["nsp", "isp", "nhc", "ihc", "nmt", "imt", "pcr", "usp"], ["x", "y", "c", "t", "Q1", "Q2", "Q3"]), ss_infos("bi", 6, 5, ["phl", "annm", "obi", "eas", "tbi", "fbi"], ["x", "y", "f", "t", "Q"]), ss_infos("cd", 3, 2, ["crd", "fcrd", "hcrd"], ["x", "h"]), ss_infos("cpx", 10, 9, ["di", "cfs", "cats", "crdi", "cess", "cbuf", "jd", "cen", "cfm", "kjd"], ["x", "y", "o", "n", "Q", "f", "cr", "t", "k"]), ss_infos("ep", 3, 2, ["cz", "ep", "fep"], ["f", "Q"]), ss_infos("g", 6, 5, ["py", "alm", "gr", "andr", "knom", "tig"], ["x", "c", "f", "cr", "t"]), ss_infos("hb", 11, 10, ["tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ilm", 5, 4, ["oilm", "dilm", "hm", "ogk", "dgk"], ["i", "m", "Q", "Qt"]), ss_infos("liq", 12, 11, ["q4L", "slL", "wo1L", "fo2L", "fa2L", "jdL", "hmL", "ekL", "tiL", "kjL", "ctL", "wat1L"], ["wo", "sl", "fo", "fa", "jd", "hm", "ek", "ti", "kj", "yct", "h2o"]), ss_infos("ol", 4, 3, ["mont", "fa", "fo", "cfm"], ["x", "c", "Q"]), ss_infos("opx", 9, 8, ["en", "fs", "fm", "odi", "mgts", "cren", "obuf", "mess", "ojd"], ["x", "y", "c", "Q", "f", "t", "cr", "j"]), ss_infos("pl4T", 3, 2, ["ab", "an", "san"], ["ca", "k"]), ss_infos("fl", 11, 10, ["qfL", "slfL", "wofL", "fofL", "fafL", "jdfL", "hmfL", "ekfL", "tifL", "kjfL", "H2O"], ["wo", "sl", "fo", "fa", "jd", "hm", "ek", "ti", "kj", "h2o"]), ss_infos("fper", 2, 1, ["per", "wu"], ["\xa0\x1c9B%\x7f"])]), db_infos("igd", "Igneous T21 (Green et al., 2023)", ss_infos[ss_infos("spn", 8, 7, ["nsp", "isp", "nhc", "ihc", "nmt", "imt", "pcr", "usp"], ["x", "y", "c", "t", "Q1", "Q2", "Q3"]), ss_infos("bi", 6, 5, ["phl", "annm", "obi", "eas", "tbi", "fbi"], ["x", "y", "f", "t", "Q"]), ss_infos("cd", 3, 2, ["crd", "fcrd", "hcrd"], ["x", "h"]), ss_infos("cpx", 10, 9, ["di", "cfs", "cats", "crdi", "cess", "cbuf", "jd", "cen", "cfm", "kjd"], ["x", "y", "o", "n", "Q", "f", "cr", "t", "k"]), ss_infos("ep", 3, 2, ["cz", "ep", "fep"], ["f", "Q"]), ss_infos("g", 6, 5, ["py", "alm", "gr", "andr", "knr", "tig"], ["x", "c", "f", "cr", "t"]), ss_infos("hb", 11, 10, ["tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ilm", 5, 4, ["oilm", "dilm", "hm", "ogk", "dgk"], ["i", "m", "Q", "Qt"]), ss_infos("liq", 15, 14, ["q3L", "sl1L", "wo1L", "fo2L", "fa2L", "neL", "hmL", "ekL", "tiL", "kjL", "anL", "ab1L", "enL", "kfL", "wat1L"], ["wo", "sl", "fo", "fa", "ne", "hm", "ek", "ti", "kj", "h2o", "yan", "yab", "yen", "ykf"]), ss_infos("ol", 4, 3, ["mnt", "fa", "fo", "cfm"], ["x", "c", "Q"]), ss_infos("opx", 9, 8, ["en", "fs", "fm", "odi", "mgts", "cren", "obuf", "mess", "ojd"], ["x", "y", "c", "Q", "f", "t", "cr", "j"]), ss_infos("fsp", 3, 2, ["ab", "an", "san"], ["ca", "k"]), ss_infos("fl", 4, 3, ["qfL", "nefL", "ksfL", "H2O"], ["ne", "ks", "h2o"]), ss_infos("fper", 2, 1, ["per", "wu"], [""])]), db_infos("alk", "Alkaline (Weller et al., 2023)", ss_infos[ss_infos("spn", 8, 7, ["nsp", "isp", "nhc", "ihc", "nmt", "imt", "pcr", "usp"], ["x", "y", "c", "t", "Q1", "Q2", "Q3"]), ss_infos("bi", 6, 5, ["phl", "annm", "obi", "eas", "tbi", "fbi"], ["x", "y", "f", "t", "Q"]), ss_infos("cd", 3, 2, ["crd", "fcrd", "hcrd"], ["x", "h"]), ss_infos("cpx", 10, 9, ["di", "cfs", "cats", "crdi", "cess", "cbuf", "jd", "cen", "cfm", "kjd"], ["x", "y", "o", "n", "Q", "f", "cr", "t", "k"]), ss_infos("ep", 3, 2, ["cz", "ep", "fep"], ["f", "Q"]), ss_infos("g", 6, 5, ["py", "alm", "gr", "andr", "knr", "tig"], ["x", "c", "f", "cr", "t"]), ss_infos("hb", 11, 10, ["tr", "tsm", "prgm", "glm", "cumm", "grnm", "a", "b", "mrb", "kprg", "tts"], ["x", "y", "z", "a", "k", "c", "f", "t", "Q1", "Q2"]), ss_infos("ilm", 5, 4, ["oilm", "dilm", "hm", "ogk", "dgk"], ["i", "m", "Q", "Qt"]), ss_infos("liq", 15, 14, ["q3L", "sl1L", "wo1L", "fo2L", "fa2L", "nmL", "hmL", "ekL", "tiL", "kmL", "anL", "ab1L", "enL", "kfL", "wat1L"], ["wo", "sl", "fo", "fa", "ns", "hm", "ek", "ti", "ks", "h2o", "yan", "yab", "yen", "ykf"]), ss_infos("ol", 4, 3, ["mnt", "fa", "fo", "cfm"], ["x", "c", "Q"]), ss_infos("opx", 9, 8, ["en", "fs", "fm", "odi", "mgts", "cren", "obuf", "mess", "ojd"], ["x", "y", "c", "Q", "f", "t", "cr", "j"]), ss_infos("fsp", 3, 2, ["ab", "an", "san"], ["ca", "k"]), ss_infos("fl", 4, 3, ["qfL", "nefL", "ksfL", "H2O"], ["ne", "ks", "h2o"]), ss_infos("lct", 2, 1, ["nlc", "klc"], ["n"]), ss_infos("mel", 5, 4, ["geh", "ak", "fak", "nml", "fge"], ["x", "n", "y", "f"]), ss_infos("ness", 6, 5, ["neN", "neS", "neK", "neO", "neC", "neF"], ["s", "k", "Q", "f", "c"]), ss_infos("kals", 2, 1, ["nks", "kls"], ["k"])]), db_infos("um", "Ultramafic (Tomlinson et al., 2021)", ss_infos[ss_infos("fluid", 2, 1, ["H2", "H2O"], ["x"]), ss_infos("ol", 2, 1, ["fo", "fa"], ["x"]), ss_infos("br", 2, 1, ["br", "fbr"], ["x"]), ss_infos("ch", 2, 1, ["chum", "chuf"], ["x"]), ss_infos("atg", 5, 4, ["atgf", "fatg", "atgo", "aatg", "oatg"], ["x", "y", "f", "t"]), ss_infos("g", 2, 1, ["py", "alm"], ["x"]), ss_infos("ta", 6, 5, ["ta", "fta", "tao", "tats", "ota", "tap"], ["x", "y", "f", "v", "Q"]), ss_infos("chl", 7, 6, ["clin", "afchl", "ames", "daph", "ochl1", "ochl4", "f3clin"], ["x", "y", "f", "m", "t", "QA1"]), ss_infos("spi", 3, 2, ["herc", "sp", "mt"], ["x", "y"]), ss_infos("opx", 5, 4, ["en", "fs", "fm", "mgts", "fopx"], ["x", "y", "f", "Q"]), ss_infos("po", 2, 1, ["trov", "trot"], ["y"]), ss_infos("anth", 5, 4, ["anth", "gedf", "fant", "a", "b"], ["x", "y", "z", "a"])])]