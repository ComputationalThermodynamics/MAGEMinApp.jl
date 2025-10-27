#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

global AppData

# retrieve contributors information
debug,app,contact,descri    = get_contributors()
contribs                    = [debug,app,contact,descri]

# retrieve database information and bulk-rock list
db, dba, dtb_dict, dbte     = get_dtbulk_list()

# retrieve phase list and other dictionaries
dict_ss, hidden_pp, dict_em, dict_OL12_KDs_l52, dict_OL12_KDs_g63, dict_OL12_KDs_g52l63, db_inf =  get_ph_list()

# retrieve package versions
GUI_v, MAGEMin_v, MAGEMin_C_v = get_pkg_versions()
const GUI_version       = GUI_v
const MAGEMin_version   = MAGEMin_v
const MAGEMin_C_version = MAGEMin_C_v

# load mineral style
mineral_style           = load_style(joinpath(pkg_dir, "./user_data/mineral_style_default.json"))
# Keep track of simulation progress - note that this should be added to a single global variable
global CompProgress     =  ComputationalProgress()
customWs                =  DataFrame()

# Here we fill a tupple with the KDs for the OL12 database
file_path               = joinpath(pkg_dir,"src","./tools/OL12.jld2")
@load file_path OL12

KDs                     = [(OL12[2],OL12[3],OL12[4],"OL","Laurent, O. 2012",OL12[1])]

HTTP.Connections.closeall()
AppData = ( contribs            = contribs,
            db                  = db,
            dba                 = dba,
            dtb_dict            = dtb_dict,
            dbte                = dbte,
            KDs                 = KDs,
            hidden_pp           = hidden_pp,
            dict_em             = dict_em,  
            dict_ss             = dict_ss,
            dict_OL12_KDs_l52   = dict_OL12_KDs_l52,
            dict_OL12_KDs_g63   = dict_OL12_KDs_g63,
            dict_OL12_KDs_g52l63= dict_OL12_KDs_g52l63,
            GUI_version         = GUI_version,
            db_inf              = db_inf,
            customWs            = customWs,
            mineral_style       = [mineral_style],
            )   
