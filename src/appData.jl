global AppData

# LIST AVAILABLE DATABASE
dba = DataFrame(        database     = String[],
                        acronym      = String[],
)    
push!(dba,Dict(         :database    => "Metapelite (White et al., 2014)",
                        :acronym     => "mp",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Metabasite (Green et al., 2016)",
                        :acronym     => "mb",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Igneous (Holland et al., 2018)",
                        :acronym     => "ig",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Ultramafic (Evans & Frost., 2021)",
                        :acronym     => "um",
                        ), cols=:union)



db = DataFrame(         bulk        = String[],
                        title       = String[],
                        comments    = String[],
                        db          = String[],
                        test        = Int64[],
                        sysUnit     = String[],
                        oxide       = Array{String, 1}[],
                        frac        = Array{Float64, 1}[],
                        frac2       = Array{Float64, 1}[],
                       )         
    
# METAPELITE DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FPWorldMedian pelite - water oversaturated",
                        :comments   => "Forshaw, J. B., & Pattison, D. R. (2023)",
                        :db         => "mp",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,30.0],
                        :frac2      => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,30.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FPWorldMedian pelite - water undersaturated",
                        :comments   => "Forshaw, J. B., & Pattison, D. R. (2023)",
                        :db         => "mp",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,5.0],
                        :frac2      => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,5.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Pelite - water oversaturated",
                        :comments   => "White et al., 2014, Fig 8",
                        :db         => "mp",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,40.0],
                        :frac2      => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,40.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Pelite - water undersaturated",
                        :comments   => "White et al., 2014, Fig 8",
                        :db         => "mp",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,6.244],
                        :frac2      => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,6.244],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Garnet-migmatite - AV0832a",
                        :comments   => "Riel et al., 2013",
                        :db         => "mp",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => [73.9880,8.6143,2.0146,2.7401, 3.8451, 1.7686, 2.4820, 0.6393, 0.11, 0.0630,  10.0],
                        :frac2      => [73.9880,8.6143,2.0146,2.7401, 3.8451, 1.7686, 2.4820, 0.6393, 0.11, 0.0630,  10.0],
                        ), cols=:union)

# METABASITE DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "SM89 oxidised average MORB composition",
                        :comments   => "Sun & McDonough, 1989",
                        :db         => "mb",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [52.47, 9.10, 12.21, 12.71, 8.15, 0.23, 2.61, 1.05, 1.47, 20.0],
                        :frac2      => [52.47, 9.10, 12.21, 12.71, 8.15, 0.23, 2.61, 1.05, 1.47, 20.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Natural amphibolites and low-temperature granulites",
                        :comments   => "unpublished",
                        :db         => "mb",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [51.08, 9.68, 13.26, 11.21, 11.66, 0.16, 0.79, 1.37, 0.80, 20.0],
                        :frac2      => [51.08, 9.68, 13.26, 11.21, 11.66, 0.16, 0.79, 1.37, 0.80, 20.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "SQA Synthetic amphibolite composition",
                        :comments   => "Patino Douce & Beard, 1995",
                        :db         => "mb",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [60.05, 6.62, 8.31, 9.93, 6.57, 0.44, 1.83, 1.27, 0.33, 4.64],
                        :frac2      => [60.05, 6.62, 8.31, 9.93, 6.57, 0.44, 1.83, 1.27, 0.33, 4.64],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "BL478: Sample 478",
                        :comments   => "Beard & Lofgren, 1991",
                        :db         => "mb",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [53.96, 9.26, 10.15, 8.11, 10.14, 0.11, 2.54, 1.35, 0.98, 3.42],
                        :frac2      => [53.96, 9.26, 10.15, 8.11, 10.14, 0.11, 2.54, 1.35, 0.98, 3.42],
                        ), cols=:union)

#IGNEOUS DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "KLB1 Peridotite - Anhydrous",
                        :comments   => "Holland et al., 2018",
                        :db         => "ig",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :frac       => [38.494,  1.776,  2.824, 50.566, 5.886,  0.01,  0.250,  0.10,  0.096,  0.109, 0],
                        :frac2      => [38.494,  1.776,  2.824, 50.566, 5.886,  0.01,  0.250,  0.10,  0.096,  0.109, 0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "RE46 - Icelandic basalt",
                        :comments   => "Yang et al., 1996",
                        :db         => "ig",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :frac       => [ 50.72,	9.16,15.21, 16.25,	7.06, 0.01, 1.47, 0.39, 0.35,  0.01,  0.0],
                        :frac2      => [ 50.72,	9.16,15.21, 16.25,	7.06, 0.01, 1.47, 0.39, 0.35,  0.01,  0.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "N_MORB - Basalt",
                        :comments   => "Gale et al., 2013",
                        :db         => "ig",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :frac       => [53.21,	9.41,	12.21,	12.21,	8.65,	0.09,	2.90,1.21,0.69,0.02, 0.0],
                        :frac2      => [53.21,	9.41,	12.21,	12.21,	8.65,	0.09,	2.90,1.21,0.69,0.02, 0.0],
                        ), cols=:union)
             
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "MIX1-G - Pyroxenite",
                        :comments   => "Hirschmann et al., 2003",
                        :db         => "ig",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :frac       => [45.25,	8.89,	12.22,	24.68,6.45,	0.03,	1.39,0.67,0.11,0.02,0.0],
                        :frac2      => [45.25,	8.89,	12.22,	24.68,6.45,	0.03,	1.39,0.67,0.11,0.02,0.0],
                        ), cols=:union)
             
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "High-Al basalt",
                        :comments   => "Baker, 1983",
                        :db         => "ig",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :frac       => [54.40,	12.96, 11.31, 7.68, 8.63,	0.54, 3.93, 0.79, 0.41, 0.01, 0.0],
                        :frac2      => [54.40,	12.96, 11.31, 7.68, 8.63,	0.54, 3.93, 0.79, 0.41, 0.01, 0.0],
                        ), cols=:union)
             
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Tonalite 101",
                        :comments   => "Piwinskii, 1968",
                        :db         => "ig",
                        :test       => 5,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :frac       => [66.01,11.98,7.06,4.16,5.30,1.57,4.12,0.66,0.97,0.01, 50],
                        :frac2      => [66.01,11.98,7.06,4.16,5.30,1.57,4.12,0.66,0.97,0.01, 50],
                        ), cols=:union)
             
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Wet Basalt",
                        :comments   => "unpublished",
                        :db         => "ig",
                        :test       => 6,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :frac       => [50.0810,  8.6901,  11.6698, 12.1438, 7.7832,  0.2150,  2.4978,  1.0059,  0.4670,  0.0100, 5.4364],
                        :frac2      => [50.0810,  8.6901,  11.6698, 12.1438, 7.7832,  0.2150,  2.4978,  1.0059,  0.4670,  0.0100, 5.4364],
                        ), cols=:union)

#ULTRAMAFIC DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Serpentine oxidized",
                        :comments   => "Evans & Forst, 2021",
                        :db         => "um",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","MgO","FeO","O","H2O","S"],
                        :frac       => [20.044,  0.6256, 29.24, 3.149, 0.7324, 46.755, 0.3],
                        :frac2      => [20.044,  0.6256, 29.24, 3.149, 0.7324, 46.755, 0.3],
                        ), cols=:union)
    
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Serpentine reduced",
                        :comments   => "Evans & Forst, 2021",
                        :db         => "um",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","MgO","FeO","O","H2O","S"],
                        :frac       => [20.044,  0.6256, 29.24, 3.149, 0.1324, 46.755, 0.3],
                        :frac2      => [20.044,  0.6256, 29.24, 3.149, 0.1324, 46.755, 0.3],
                        ), cols=:union)
    

dbte = DataFrame(       composition = String[],
                        title       = String[],
                        comments    = String[],
                        test        = Int64[],
                        elements    = Array{String, 1}[],
                        μg_g         = Array{Float64, 1}[],
                        μg_g2        = Array{Float64, 1}[],
                )   

push!(dbte,Dict(    :composition=> "predefined",
                    :title      => "Tonalite",
                    :comments   => "J-F Moyen",
                    :test       => 0,
                    :elements   => ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc"],
                    :μg_g        => [64.5373756, 499.0093971, 5.69152854, 1.064824497, 5.430265866, 0.722386615, 29.06202556, 53.78324684, 15.17205921, 5.797620808, 484.5753262, 20.54095673, 150.2402264, 3.95645511, 3.317738791, 0.961548784, 2.418869313, 0.315058021, 1.593968618, 7.459369222, 0.296925128, 0.799927928, 0.128677572, 0.713354049, 0.133287066, 39.87762745, 5.524762752],
                    :μg_g2       => [64.5373756, 499.0093971, 5.69152854, 1.064824497, 5.430265866, 0.722386615, 29.06202556, 53.78324684, 15.17205921, 5.797620808, 484.5753262, 20.54095673, 150.2402264, 3.95645511, 3.317738791, 0.961548784, 2.418869313, 0.315058021, 1.593968618, 7.459369222, 0.296925128, 0.799927928, 0.128677572, 0.713354049, 0.133287066, 39.87762745, 5.524762752],
                ), cols=:union)


push!(dbte,Dict(    :composition=> "predefined",
                    :title      => "Basalt",
                    :comments   => "J-F Moyen",
                    :test       => 1,
                    :elements   => ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc"],
                    :μg_g        => [16.60777308, 122.8449739, 1.074692058, 0.290233271, 3.808354064, 0.330971265, 6.938172601, 16.04827796, 5.452969044, 2.253943183, 163.4533209, 10.18276823, 66.90677472, 1.841502082, 3.3471043, 0.915941652, 3.28230146, 1.417695298, 3.851230952, 20.74016207, 0.914966282, 2.20425, 0.343734976, 2.136202593, 0.323405135, 257.4346716, 38.23663423],
                    :μg_g2       => [16.60777308, 122.8449739, 1.074692058, 0.290233271, 3.808354064, 0.330971265, 6.938172601, 16.04827796, 5.452969044, 2.253943183, 163.4533209, 10.18276823, 66.90677472, 1.841502082, 3.3471043, 0.915941652, 3.28230146, 1.417695298, 3.851230952, 20.74016207, 0.914966282, 2.20425, 0.343734976, 2.136202593, 0.323405135, 257.4346716, 38.23663423],
                ), cols=:union)


push!(dbte,Dict(    :composition=> "predefined",
                    :title      => "Pyrolite (Primitive Mantle)",
                    :comments   => "McDonough and Sun, 1995",
                    :test       => 2,
                    :elements   => ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc"],
                    :μg_g        => [0.6,6.6,0.0795,0.0203,0.658,0.037,0.648,1.675,0.150,0.254,19.9,1.25,10.5,0.283,0.406,0.154,0.544,0.099,0.674,4.30,0.149,0.438,0.068,0.441,0.0675,8.2,16.2],
                    :μg_g2       => [0.6,6.6,0.0795,0.0203,0.658,0.037,0.648,1.675,0.150,0.254,19.9,1.25,10.5,0.283,0.406,0.154,0.544,0.099,0.674,4.30,0.149,0.438,0.068,0.441,0.0675,8.2,16.2],
                ), cols=:union)

KDs_dtb     = get_OL_KDs_database();

AppData = ( db                  = db,
            dba                 = dba,
            dbte                = dbte,
            KDs_dtb             = KDs_dtb)
