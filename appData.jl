global AppData

MAGEMin_version = "v1.3.3";
vertice_list    = [];
mesh            = [];
field           = [];


db = DataFrame(         title       = String[],
                        comments    = String[],
                        database    = String[],
                        test        = Int64[],
                        sysUnit     = String[],
                        oxide       = Array{String, 1}[],
                        mol         = Array{Float64, 1}[],
                       )         
    
# METAPELITE DATABASE
push!(db,Dict(          :title      => "FPWorldMedian pelite - water oversaturated",
                        :comments   => "Forshaw, J. B., & Pattison, D. R. (2023)",
                        :database   => "Metapelite (White et al., 2014)",
                        :db         => "mp",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :mol        => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,30.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "FPWorldMedian pelite - water undersaturated",
                        :comments   => "Forshaw, J. B., & Pattison, D. R. (2023)",
                        :database   => "Metapelite (White et al., 2014)",
                        :db         => "mp",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :mol        => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,5.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "Pelite - water oversaturated",
                        :comments   => "White et al., 2014, Fig 8",
                        :database   => "Metapelite (White et al., 2014)",
                        :db         => "mp",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :mol        => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,40.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "Pelite - water undersaturated",
                        :comments   => "White et al., 2014, Fig 8",
                        :database   => "Metapelite (White et al., 2014)",
                        :db         => "mp",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :mol        => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,6.244],
                        ), cols=:union)

push!(db,Dict(          :title      => "Garnet-migmatite - AV0832a",
                        :comments   => "Riel et al., 2013",
                        :database   => "Metapelite (White et al., 2014)",
                        :db         => "mp",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :mol        => [73.9880,8.6143,2.0146,2.7401, 3.8451, 1.7686, 2.4820, 0.6393, 0.11, 0.0630,  10.0],
                        ), cols=:union)

# METABASITE DATABASE
push!(db,Dict(          :title      => "SM89 oxidised average MORB composition",
                        :comments   => "Sun & McDonough, 1989",
                        :database   => "Metabasite (Green et al., 2016)",
                        :db         => "mb",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","H2O"],
                        :mol        => [52.47, 9.10, 12.21, 12.71, 8.15, 0.23, 2.61, 1.05, 1.47, 20.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "Natural amphibolites and low-temperature granulites",
                        :comments   => "unpublished",
                        :database   => "Metabasite (Green et al., 2016)",
                        :db         => "mb",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","H2O"],
                        :mol        => [51.08, 9.68, 13.26, 11.21, 11.66, 0.16, 0.79, 1.37, 0.80, 20.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "SQA Synthetic amphibolite composition",
                        :comments   => "Patino Douce & Beard, 1995",
                        :database   => "Metabasite (Green et al., 2016)",
                        :db         => "mb",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","H2O"],
                        :mol        => [60.05, 6.62, 8.31, 9.93, 6.57, 0.44, 1.83, 1.27, 0.33, 4.64],
                        ), cols=:union)

push!(db,Dict(          :title      => "BL478: Sample 478",
                        :comments   => "Beard & Lofgren, 1991",
                        :database   => "Metabasite (Green et al., 2016)",
                        :db         => "mb",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","H2O"],
                        :mol        => [53.96, 9.26, 10.15, 8.11, 10.14, 0.11, 2.54, 1.35, 0.98, 3.42],
                        ), cols=:union)

#IGNEOUS DATABASE
push!(db,Dict(          :title      => "KLB1 Peridotite - Anhydrous",
                        :comments   => "Holland et al., 2018",
                        :database   => "Igneous (H18 -> Green et al., 2023)",
                        :db         => "ig",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [38.494,  1.776,  2.824, 50.566, 5.886,  0.01,  0.250,  0.10,  0.096,  0.109, 0],
                        ), cols=:union)

push!(db,Dict(          :title      => "RE46 - Icelandic basalt -",
                        :comments   => "Yang et al., 1996",
                        :database   => "Igneous (H18 -> Green et al., 2023)",
                        :db         => "ig",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [ 50.72,	9.16,15.21, 16.25,	7.06, 0.01, 1.47, 0.39, 0.35,  0.01,  0.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "N_MORB - Basalt",
                        :comments   => "Gale et al., 2013",
                        :database   => "Igneous (H18 -> Green et al., 2023)",
                        :db         => "ig",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [53.21,	9.41,	12.21,	12.21,	8.65,	0.09,	2.90,1.21,0.69,0.02, 0.0],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "MIX1-G - Pyroxenite",
                        :comments   => "Hirschmann et al., 2003",
                        :database   => "Igneous (H18 -> Green et al., 2023)",
                        :db         => "ig",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [45.25,	8.89,	12.22,	24.68,6.45,	0.03,	1.39,0.67,0.11,0.02,0.0],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "High-Al basalt",
                        :comments   => "Baker, 1983",
                        :database   => "Igneous (H18 -> Green et al., 2023)",
                        :db         => "ig",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [54.40,	12.96, 11.31, 7.68, 8.63,	0.54, 3.93, 0.79, 0.41, 0.01, 0.0],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "Tonalite 101",
                        :comments   => "Piwinskii, 1968",
                        :database   => "Igneous (H18 -> Green et al., 2023)",
                        :db         => "ig",
                        :test       => 5,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [66.01,11.98,7.06,4.16,5.30,1.57,4.12,0.66,0.97,0.01, 50],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "Wet Basalt",
                        :comments   => "unpublished",
                        :database   => "Igneous (H18 -> Green et al., 2023)",
                        :db         => "ig",
                        :test       => 6,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [50.0810,  8.6901,  11.6698, 12.1438, 7.7832,  0.2150,  2.4978,  1.0059,  0.4670,  0.0100, 5.4364],
                        ), cols=:union)
             
#IGNEOUS DATABASE
push!(db,Dict(          :title      => "KLB1 Peridotite - Anhydrous",
                        :comments   => "Holland et al., 2018",
                        :database   => "Igneous (T21 -> Green et al., 2023)",
                        :db         => "igd",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [38.494,  1.776,  2.824, 50.566, 5.886,  0.01,  0.250,  0.10,  0.096,  0.109, 0],
                        ), cols=:union)

push!(db,Dict(          :title      => "RE46 - Icelandic basalt -",
                        :comments   => "Yang et al., 1996",
                        :database   => "Igneous (T21 -> Green et al., 2023)",
                        :db         => "igd",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [ 50.72,	9.16,15.21, 16.25,	7.06, 0.01, 1.47, 0.39, 0.35,  0.01,  0.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "N_MORB - Basalt",
                        :comments   => "Gale et al., 2013",
                        :database   => "Igneous (T21 -> Green et al., 2023)",
                        :db         => "igd",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [53.21,	9.41,	12.21,	12.21,	8.65,	0.09,	2.90,1.21,0.69,0.02, 0.0],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "MIX1-G - Pyroxenite",
                        :comments   => "Hirschmann et al., 2003",
                        :database   => "Igneous (T21 -> Green et al., 2023)",
                        :db         => "igd",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [45.25,	8.89,	12.22,	24.68,6.45,	0.03,	1.39,0.67,0.11,0.02,0.0],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "High-Al basalt",
                        :comments   => "Baker, 1983",
                        :database   => "Igneous (T21 -> Green et al., 2023)",
                        :db         => "igd",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [54.40,	12.96, 11.31, 7.68, 8.63,	0.54, 3.93, 0.79, 0.41, 0.01, 0.0],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "Tonalite 101",
                        :comments   => "Piwinskii, 1968",
                        :database   => "Igneous (T21 -> Green et al., 2023)",
                        :db         => "igd",
                        :test       => 5,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [66.01,11.98,7.06,4.16,5.30,1.57,4.12,0.66,0.97,0.01, 50],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "Wet Basalt",
                        :comments   => "unpublished",
                        :database   => "Igneous (T21 -> Green et al., 2023)",
                        :db         => "igd",
                        :test       => 6,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [50.0810,  8.6901,  11.6698, 12.1438, 7.7832,  0.2150,  2.4978,  1.0059,  0.4670,  0.0100, 5.4364],
                        ), cols=:union)
             


#ALKALINE DATABASE
push!(db,Dict(          :title      => "Ne-syenite",
                        :comments   => "Weller et al., 2023",
                        :database   => "Alkaline (Weller et al., 2023)",
                        :db         => "alk",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [63.84, 13.72, 3.09, 1.55, 5.07, 4.04, 9.38, 0.78, 1.47, 0.01, 0.0],
                        ), cols=:union)
             
push!(db,Dict(          :title      => "Syenite",
                        :comments   => "Weller et al., 2023",
                        :database   => "Alkaline (Weller et al., 2023)",
                        :db         => "alk",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [70.06, 11.63, 2.76, 1.5, 4.3, 3.72, 6.41, 0.51, 0.89, 0.01, 0.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "Ijolite",
                        :comments   => "Weller et al., 2023",
                        :database   => "Alkaline (Weller et al., 2023)",
                        :db         => "alk",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [48.97, 12.76, 12.87, 5.21, 7.97, 1.66, 10.66, 1.36, 1.66, 0.01, 0.0],
                        ), cols=:union)
    
push!(db,Dict(          :title      => "9418",
                        :comments   => "Weller et al., 2023",
                        :database   => "Alkaline (Weller et al., 2023)",
                        :db         => "alk",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [53.221, 11.671, 10.009, 6.597, 7.053, 5.582, 2.956, 0.825, 1.94, 0.146, 0.0],
                        ), cols=:union)

push!(db,Dict(          :title      => "KLB1 Peridotite - Anhydrous",
                        :comments   => "Holland et al., 2018",
                        :database   => "Alkaline (Weller et al., 2023)",
                        :db         => "alk",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [38.494,  1.776,  2.824, 50.566, 5.886,  0.01,  0.250,  0.10,  0.096,  0.109, 0],
                        ), cols=:union)
                           
push!(db,Dict(          :title      => "Wet Ijolite",
                        :comments   => "Weller et al., 2023",
                        :database   => "Alkaline (Weller et al., 2023)",
                        :db         => "alk",
                        :test       => 5,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeOt","K2O","Na2O","TiO2","O","Cr2O3","H2O"],
                        :mol        => [48.97, 12.76, 12.87, 5.21, 7.97, 1.66, 10.66, 1.36, 1.66, 0.01, 20.0],
                        ), cols=:union)

#ULTRAMAFIC DATABASE
push!(db,Dict(          :title      => "Serpentine oxidized",
                        :comments   => "Evans & Forst, 2021",
                        :database   => "Ultramafic (Evans & Forst, 2021)",
                        :db         => "um",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","MgO","FeOt","O","H2O","S"],
                        :mol        => [20.044,  0.6256, 29.24, 3.149, 0.7324, 46.755, 0.3],
                        ), cols=:union)
    
push!(db,Dict(          :title      => "Serpentine reduced",
                        :comments   => "Evans & Forst, 2021",
                        :database   => "Ultramafic (Evans & Forst, 2021)",
                        :db         => "um",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","MgO","FeOt","O","H2O","S"],
                        :mol        => [20.044,  0.6256, 29.24, 3.149, 0.1324, 46.755, 0.3],
                        ), cols=:union)
    


AppData = ( MAGEMin_version = MAGEMin_version,
            vertice_list    = vertice_list,
            mesh            = mesh,
            field           = field,
            db              = db )
            