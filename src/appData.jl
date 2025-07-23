global AppData

debug   = "**Main developer**\n"
debug   *= "Nicolas Riel\n\n"

debug   *= "**Debugging and Additions**\n"
debug   *= "Alexandre Peillod\n"
debug   *= "Anton Popov\n"
debug   *= "Boris Kaus\n"
debug   *= "Ding Chenlong\n"
debug   *= "Hugo Dominguez\n"
debug   *= "Hendrik Ranocha\n"
debug   *= "Jamison Assunção\n"
debug   *= "Jean-François Moyen\n"
debug   *= "Joshua Laughton\n"
debug   *= "Jun Ren\n"
debug   *= "Lorenzo Candioti\n"
debug   *= "Owen Weller\n"
debug   *= "Paul Tackley\n"
debug   *= "Pierre Lanari\n"
debug   *= "Renato Moraes\n"
debug   *= "Simon Schorn\n"
debug   *= "Tim J.B. Holland\n"
debug   *= "Tobias Keller"

app      = "**Interface Suggestions**\n"
app     *= "Boris Kaus\n"
app     *= "Brendan Dyck\n"
app     *= "Buchanan Kerswell\n"
app     *= "Cerine Bouadani\n"
app     *= "Chris Yakymchuk\n"
app     *= "Dinarte Lucas\n"
app     *= "Ding Chenlong\n"
app     *= "Dimitrios Moutzouris\n"
app     *= "Evangelos Moulas\n"
app     *= "Guillaume Duclaux\n"
app     *= "Ian Cawood\n"
app     *= "Jacob Forshaw\n"
app     *= "Jean-François Moyen\n"
app     *= "Joan Reche Estrada\n"
app     *= "Martin Miranda Muruzabal\n"
app     *= "Nathwani Chetan Lalitkumar\n"
app     *= "Nicholas Lucas\n"
app     *= "Olivier Namur\n"
app     *= "Owen Weller\n"
app     *= "Paul Tackley\n"
app     *= "Pierre Lanari\n"
app     *= "Renee Tamblyn\n"
app     *= "Simon Schorn\n"
app     *= "Yishen Zhang"

contact  = "**Links**\n"
contact *= "[Tutorials](https://computationalthermodynamics.github.io/MAGEMin_C.jl/dev/)\n"
contact *= "[Post issue](https://github.com/ComputationalThermodynamics/MAGEMinApp.jl/issues)\n"
contact *= "[Open discussion](https://github.com/ComputationalThermodynamics/MAGEMin/discussions)\n"
contact *= "[Discord](https://discord.gg/fjmVZyej9F)"

descri  = "**Comments**\n"
descri *= "Set of examples on how to use MAGEMinApp\n"
descri *= "Something is not working properly?\n"
descri *= "Need additional options?\n"
descri *= "... or join our Discord!"


contribs = [debug,app,contact,descri]

dtb_dict = [
    Dict("label" => "- PUBLISHED DATABASE -", "value" => "separator", "disabled" => true),  # Simulate a horizontal line
    Dict("label" => "Metapelite (White et al., 2014)", "value" => "mp"),
    Dict("label" => "Metabasite (Green et al., 2016)", "value" => "mb"),
    Dict("label" => "Igneous (Green et al., 2025, after H18)", "value" => "ig"),
    Dict("label" => "Igneous alkaline dry (Weller et al., 2024)", "value" => "igad"),
    Dict("label" => "Ultramafic (Evans & Frost., 2021)", "value" => "um"),
    Dict("label" => "- MANTLE DATABASE -", "value" => "separator", "disabled" => true),  # Simulate a horizontal line
    Dict("label" => "Mantle (Holland et al., 2013)", "value" => "mtl"),
    Dict("label" => "Stixrude & Lithgow-Bertelloni (2011)", "value" => "sb11"),
    Dict("label" => "Stixrude & Lithgow-Bertelloni (2021)", "value" => "sb21"),
    Dict("label" => "- CUSTOM DATABASE -", "value" => "separator", "disabled" => true),  # Simulate a horizontal line
    Dict("label" => "Ultramafic extended (Evans & Frost., 2021)", "value" => "ume"),
    Dict("label" => "Metapelite extended (White et al., 2014, Green et al., 2016, Evans & Frost., 2021)", "value" => "mpe"),
    Dict("label" => "Metabasite extended (Green et al., 2016, Diener et al., 2007)", "value" => "mbe"),
]

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

push!(dba,Dict(         :database    => "Igneous (Green et al., 2025, after H18)",
                        :acronym     => "ig",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Igneous alkaline dry (Weller et al., 2024)",
                        :acronym     => "igad",
                         ), cols=:union)
                                     
push!(dba,Dict(         :database    => "Ultramafic (Evans & Frost., 2021)",
                        :acronym     => "um",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Mantle (Holland et al., 2013)",
                        :acronym     => "mtl",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Stixrude & Lithgow-Bertelloni (2011)",
                        :acronym     => "sb11",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Stixrude & Lithgow-Bertelloni (2021)",
                        :acronym     => "sb21",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Ultramafic extended (Evans & Frost., 2021) + pl, hb and aug from Green et al., 2016",
                        :acronym     => "ume",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Metapelite extended (White et al., 2014, Green et al., 2016, Evans & Frost., 2021)",
                        :acronym     => "mpe",
                        ), cols=:union)

push!(dba,Dict(         :database    => "Metabasite (Green et al., 2016; Diener et al., 2007)",
                        :acronym     => "mbe",
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
                        frac_wt     = Array{Float64, 1}[],
                        frac2_wt    = Array{Float64, 1}[],
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

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Average Bulk CC",
                        :comments   => "Rudnick & Gao, 2003",
                        :db         => "mp",
                        :test       => 5,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => round.([64.36480235503944, 9.951144607816047, 7.2938321423178545, 7.378814803489908, 5.959385604415841, 1.2261212291694328, 3.1607674436810393, 0.5751752369381947, 0.0, 0.08995657713225781, 10.0],digits= 4),
                        :frac2      => round.([64.36480235503944, 9.951144607816047, 7.2938321423178545, 7.378814803489908, 5.959385604415841, 1.2261212291694328, 3.1607674436810393, 0.5751752369381947, 0.0, 0.08995657713225781, 10.0],digits= 4),
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Average UCC",
                        :comments   => "Rudnick & Gao, 2003",
                        :db         => "mp",
                        :test       => 6,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => round.([71.64852226623434, 9.762337693730293, 4.137608315807357, 3.977494310700263, 4.533845289441219, 1.9211888655717828, 3.4100371722303193, 0.517851036946454, 0.0, 0.09111504933797493, 10.0],digits= 4),
                        :frac2      => round.([71.64852226623434, 9.762337693730293, 4.137608315807357, 3.977494310700263, 4.533845289441219, 1.9211888655717828, 3.4100371722303193, 0.517851036946454, 0.0, 0.09111504933797493, 10.0],digits= 4),
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Average MCC",
                        :comments   => "Rudnick & Gao, 2003",
                        :db         => "mp",
                        :test       => 7,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => round.([67.7653027080356, 9.43246090028847, 6.002261050065877, 5.7115368586970225, 5.371966554978745, 1.5654547351768213, 3.5068057313151213, 0.5538276266411739, 0.0, 0.09038383480115338, 10.0],digits= 4),
                        :frac2      => round.([67.7653027080356, 9.43246090028847, 6.002261050065877, 5.7115368586970225, 5.371966554978745, 1.5654547351768213, 3.5068057313151213, 0.5538276266411739, 0.0, 0.09038383480115338, 10.0],digits= 4),
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Average MCC",
                        :comments   => "Rudnick & Gao, 2003",
                        :db         => "mp",
                        :test       => 8,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O"],
                        :frac       => round.([56.062248485178635, 10.45480788601888, 10.78623259422388, 11.331638180074636, 7.523383987301963, 0.40844925775177815, 2.6968294429344315, 0.6474928471760583, 0.0, 0.08891731933973626, 0.0],digits= 4),
                        :frac2      => round.([56.062248485178635, 10.45480788601888, 10.78623259422388, 11.331638180074636, 7.523383987301963, 0.40844925775177815, 2.6968294429344315, 0.6474928471760583, 0.0, 0.08891731933973626, 0.0],digits= 4),
                        ), cols=:union)
                      
                        

# METABASITE DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FWorldMedian metabasite - water over saturated",
                        :comments   => "Forshaw et al., 2024",
                        :db         => "mb",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 40.0],
                        :frac2      => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 40.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FWorldMedian metabasite - water undersaturated",
                        :comments   => "Forshaw et al., 2024",
                        :db         => "mb",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 5.0],
                        :frac2      => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 5.0],
                        ), cols=:union)


push!(db,Dict(          :bulk       => "predefined",
                        :title      => "SM89 oxidised average MORB composition",
                        :comments   => "Sun & McDonough, 1989",
                        :db         => "mb",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [52.47, 9.10, 12.21, 12.71, 8.15, 0.23, 2.61, 1.05, 1.47, 20.0],
                        :frac2      => [52.47, 9.10, 12.21, 12.71, 8.15, 0.23, 2.61, 1.05, 1.47, 20.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Natural amphibolites and low-temperature granulites",
                        :comments   => "unpublished",
                        :db         => "mb",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [51.08, 9.68, 13.26, 11.21, 11.66, 0.16, 0.79, 1.37, 0.80, 20.0],
                        :frac2      => [51.08, 9.68, 13.26, 11.21, 11.66, 0.16, 0.79, 1.37, 0.80, 20.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "SQA Synthetic amphibolite composition",
                        :comments   => "Patino Douce & Beard, 1995",
                        :db         => "mb",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [60.05, 6.62, 8.31, 9.93, 6.57, 0.44, 1.83, 1.27, 0.33, 4.64],
                        :frac2      => [60.05, 6.62, 8.31, 9.93, 6.57, 0.44, 1.83, 1.27, 0.33, 4.64],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "BL478: Sample 478",
                        :comments   => "Beard & Lofgren, 1991",
                        :db         => "mb",
                        :test       => 5,
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


# IGNEOUS ALKALINE DRY DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Ne-Syenite",
                        :comments   => "Weller et al., 2024",
                        :db         => "igad",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3"],
                        :frac       => round.([0.6201068479844584, 0.13326857697911607, 0.030014570179698878, 0.015055852355512383, 0.04924720738222438, 0.03924235065565808, 0.09111219038368139, 0.007576493443419135, 0.014278776104905291, 9.713453132588633e-5].*100.0,digits= 4),
                        :frac2      => round.([0.6201068479844584, 0.13326857697911607, 0.030014570179698878, 0.015055852355512383, 0.04924720738222438, 0.03924235065565808, 0.09111219038368139, 0.007576493443419135, 0.014278776104905291, 9.713453132588633e-5].*100.0,digits= 4),
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Syenite",
                        :comments   => "Weller et al., 2024",
                        :db         => "igad",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3"],
                        :frac       => round.([0.6882797917280675, 0.11425483839276943, 0.027114647804302974, 0.014736221632773355, 0.04224383534728362, 0.036545829649277925, 0.06297278711071815, 0.0050103153551429415, 0.008743491502112191, 9.824147755182237e-5].*100.0,digits= 4),
                        :frac2      => round.([0.6882797917280675, 0.11425483839276943, 0.027114647804302974, 0.014736221632773355, 0.04224383534728362, 0.036545829649277925, 0.06297278711071815, 0.0050103153551429415, 0.008743491502112191, 9.824147755182237e-5].*100.0,digits= 4),
                        ), cols=:union)   
                        
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Ijolite",
                        :comments   => "Weller et al., 2024",
                        :db         => "igad",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3"],
                        :frac       => round.([0.4748375836323088, 0.12372733443226996, 0.1247939493842723, 0.05051876272665569, 0.07728110152235045, 0.016096189275671486, 0.10336468534858918, 0.01318723940657423, 0.016096189275671486, 9.696499563657522e-5].*100.0,digits= 4),
                        :frac2      => round.([0.4748375836323088, 0.12372733443226996, 0.1247939493842723, 0.05051876272665569, 0.07728110152235045, 0.016096189275671486, 0.10336468534858918, 0.01318723940657423, 0.016096189275671486, 9.696499563657522e-5].*100.0,digits= 4),
                        ), cols=:union)                          

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "KLB1 Peridotite - Anhydrous",
                        :comments   => "Holland et al., 2018",
                        :db         => "igad",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3"],
                        :frac       => [38.494,  1.776,  2.824, 50.566, 5.886,  0.01,  0.250,  0.10,  0.096,  0.109],
                        :frac2      => [38.494,  1.776,  2.824, 50.566, 5.886,  0.01,  0.250,  0.10,  0.096,  0.109],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "RE46 - Icelandic basalt",
                        :comments   => "Yang et al., 1996",
                        :db         => "igad",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","Cr2O3"],
                        :frac       => [ 50.72,	9.16,15.21, 16.25,	7.06, 0.01, 1.47, 0.39, 0.35,  0.01],
                        :frac2      => [ 50.72,	9.16,15.21, 16.25,	7.06, 0.01, 1.47, 0.39, 0.35,  0.01],
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
    

#ULTRAMAFIC EXTENDED DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Barberton komatiite",
                        :comments   => "Tamblyn et al., 2022",
                        :db         => "ume",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","MgO","FeO","O","H2O","S","CaO","Na2O"],
                        :frac       => [38.51, 2.25, 29.03, 4.65, 0.5, 16.0, 0.0, 6.92, 0.25],
                        :frac2      => [38.51, 2.25, 29.03, 4.65, 0.5, 16.0, 0.0, 6.92, 0.25],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Serpentine oxidized",
                        :comments   => "Evans & Forst, 2021",
                        :db         => "ume",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","MgO","FeO","O","H2O","S","CaO","Na2O"],
                        :frac       => [20.044,  0.6256, 29.24, 3.149, 0.7324, 46.755, 0.3,2.0,0.15],
                        :frac2      => [20.044,  0.6256, 29.24, 3.149, 0.7324, 46.755, 0.3,2.0,0.15],
                        ), cols=:union)
    
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Serpentine reduced",
                        :comments   => "Evans & Forst, 2021",
                        :db         => "ume",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","MgO","FeO","O","H2O","S","CaO","Na2O"],
                        :frac       => [20.044,  0.6256, 29.24, 3.149, 0.1324, 46.755, 0.3,2.0,0.15],
                        :frac2      => [20.044,  0.6256, 29.24, 3.149, 0.1324, 46.755, 0.3,2.0,0.15],
                        ), cols=:union)

 
# METAPELITE EXTENDED DATABASE, accounting for CO2 and S
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FPWorldMedian pelite - water oversaturated",
                        :comments   => "Forshaw, J. B., & Pattison, D. R. (2023)",
                        :db         => "mpe",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O","CO2","S"],
                        :frac       => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,30.0,10.0,1.0],
                        :frac2      => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,30.0,10.0,1.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FPWorldMedian pelite - water undersaturated",
                        :comments   => "Forshaw, J. B., & Pattison, D. R. (2023)",
                        :db         => "mpe",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O","CO2","S"],
                        :frac       => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,5.0,10.0,1.0],
                        :frac2      => [70.999,12.805,0.771,3.978,6.342,2.7895,1.481,0.758,0.72933,0.075,5.0,10.0,1.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Pelite - water oversaturated",
                        :comments   => "White et al., 2014, Fig 8",
                        :db         => "mpe",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O","CO2","S"],
                        :frac       => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,40.0,10.0,1.0],
                        :frac2      => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,40.0,10.0,1.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Pelite - water undersaturated",
                        :comments   => "White et al., 2014, Fig 8",
                        :db         => "mpe",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O","CO2","S"],
                        :frac       => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,6.244,10.0,1.0],
                        :frac2      => [64.578,13.651,1.586,5.529,8.025,2.943,2.000,0.907,0.65,0.175,6.244,10.0,1.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Garnet-migmatite - AV0832a",
                        :comments   => "Riel et al., 2013",
                        :db         => "mpe",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O","CO2","S"],
                        :frac       => [73.9880,8.6143,2.0146,2.7401, 3.8451, 1.7686, 2.4820, 0.6393, 0.11, 0.0630,  10.0,10.0,1.0],
                        :frac2      => [73.9880,8.6143,2.0146,2.7401, 3.8451, 1.7686, 2.4820, 0.6393, 0.11, 0.0630,  10.0,10.0,1.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "IO27",
                        :comments   => "Peillod et al., 2024",
                        :db         => "mpe",
                        :test       => 5,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","MnO","H2O","CO2","S"],
                        :frac       => [65.514, 9.500, 2.012, 7.38, 8.896, 1.48, 4.108, 0.99, 0.0, 0.098, 30.0, 0.0, 0.0],
                        :frac2      => [65.514, 9.500, 2.012, 7.38, 8.896, 1.48, 4.108, 0.99, 0.0, 0.098, 30.0, 0.0, 0.0],
                        ), cols=:union)



#MANTLE DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "KLB-1",
                        :comments   => "Holland et al., 2013",
                        :db         => "mtl",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","Na2O"],
                        :frac       => [38.494,1.776,2.824,50.566,5.886,0.250],
                        :frac2      => [38.494,1.776,2.824,50.566,5.886,0.250],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Pyrolite",
                        :comments   => "Holland et al., 2013",
                        :db         => "mtl",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","Na2O"],
                        :frac       => [38.89,2.2,3.1,50.0,5.8,0.01],
                        :frac2      => [38.89,2.2,3.1,50.0,5.8,0.01],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Harzburgite",
                        :comments   => "Holland et al., 2013",
                        :db         => "mtl",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","Na2O"],
                        :frac       => [36.39,0.7,0.9,56.6,5.4,0.01],
                        :frac2      => [36.39,0.7,0.9,56.6,5.4,0.01],
                        ), cols=:union)  
                        
#MANTLE DATABASE STIXRUDE 2011
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "KLB-1",
                        :comments   => "Stixrude & Lithgow-Bertelloni (2011)",
                        :db         => "sb11",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","CaO","Al2O3","FeO","MgO","Na2O"],
                        :frac       => [38.41,3.18,1.8,5.85,50.49, 0.250],
                        :frac2      => [38.41,3.18,1.8,5.85,50.49, 0.250],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Pyrolite",
                        :comments   => "Stixrude & Lithgow-Bertelloni (2011)",
                        :db         => "sb11",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [38.89,2.2,3.1,5.8,50.0,0.01],
                        :frac2      => [38.89,2.2,3.1,5.8,50.0,0.01],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Harzburgite",
                        :comments   => "Stixrude & Lithgow-Bertelloni (2011)",
                        :db         => "sb11",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [36.39,0.7,0.9,5.4,56.6,0.01],
                        :frac2      => [36.39,0.7,0.9,5.4,56.6,0.01],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Bulk DMM",
                        :comments   => "Workman & Hart, 2005",
                        :db         => "sb11",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [38.82533751228409, 2.0365437262790334, 2.949115292540495, 5.939734393438787, 50.13984011481426, 0.10942896064333986],
                        :frac2      => [38.82533751228409, 2.0365437262790334, 2.949115292540495, 5.939734393438787, 50.13984011481426, 0.10942896064333986],
                        # :frac       => [44.71,3.98,3.17,8.18,38.73,0.13],
                        # :frac2      => [44.71,3.98,3.17,8.18,38.73,0.13],
                        ), cols=:union) 

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "RE46 - Icelandic basalt",
                        :comments   => "Yang et al., 1996",
                        :db         => "sb11",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [ 50.72,	9.16,15.21, 7.06, 16.25, 1.47],
                        :frac2      => [ 50.72,	9.16,15.21, 7.06, 16.25, 1.47],
                        ), cols=:union) 
                        
#MANTLE DATABASE STIXRUDE 2021
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "KLB-1",
                        :comments   => "Stixrude & Lithgow-Bertelloni (2011)",
                        :db         => "sb21",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","CaO","Al2O3","FeO","MgO","Na2O"],
                        :frac       => [38.41,3.18,1.8,5.85,50.49, 0.250],
                        :frac2      => [38.41,3.18,1.8,5.85,50.49, 0.250],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Pyrolite",
                        :comments   => "Stixrude & Lithgow-Bertelloni (2011)",
                        :db         => "sb21",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [38.89,2.2,3.1,5.8,50.0,0.01],
                        :frac2      => [38.89,2.2,3.1,5.8,50.0,0.01],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Harzburgite",
                        :comments   => "Stixrude & Lithgow-Bertelloni (2011)",
                        :db         => "sb21",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [36.39,0.7,0.9,5.4,56.6,0.01],
                        :frac2      => [36.39,0.7,0.9,5.4,56.6,0.01],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Bulk DMM",
                        :comments   => "Workman & Hart, 2005",
                        :db         => "sb21",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [38.82533751228409, 2.0365437262790334, 2.949115292540495, 5.939734393438787, 50.13984011481426, 0.10942896064333986],
                        :frac2      => [38.82533751228409, 2.0365437262790334, 2.949115292540495, 5.939734393438787, 50.13984011481426, 0.10942896064333986],
                        # :frac       => [44.71,3.98,3.17,8.18,38.73,0.13],
                        # :frac2      => [44.71,3.98,3.17,8.18,38.73,0.13],
                        ), cols=:union)  

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "RE46 - Icelandic basalt",
                        :comments   => "Yang et al., 1996",
                        :db         => "sb21",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","FeO","MgO","Na2O"],
                        :frac       => [ 50.72,	9.16,15.21, 7.06, 16.25, 1.47],
                        :frac2      => [ 50.72,	9.16,15.21, 7.06, 16.25, 1.47],
                        ), cols=:union) 
                    

# METABASITE DATABASE
push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FWorldMedian metabasite - water over saturated",
                        :comments   => "Forshaw et al., 2024",
                        :db         => "mbe",
                        :test       => 0,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 40.0],
                        :frac2      => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 40.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "FWorldMedian metabasite - water undersaturated",
                        :comments   => "Forshaw et al., 2024",
                        :db         => "mbe",
                        :test       => 1,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 5.0],
                        :frac2      => [53.5839, 9.5138, 10.7349, 10.6198, 10.0168, 0.3326, 2.852, 1.0439, 1.3023, 5.0],
                        ), cols=:union)


push!(db,Dict(          :bulk       => "predefined",
                        :title      => "SM89 oxidised average MORB composition",
                        :comments   => "Sun & McDonough, 1989",
                        :db         => "mbe",
                        :test       => 2,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [52.47, 9.10, 12.21, 12.71, 8.15, 0.23, 2.61, 1.05, 1.47, 20.0],
                        :frac2      => [52.47, 9.10, 12.21, 12.71, 8.15, 0.23, 2.61, 1.05, 1.47, 20.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "Natural amphibolites and low-temperature granulites",
                        :comments   => "unpublished",
                        :db         => "mbe",
                        :test       => 3,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [51.08, 9.68, 13.26, 11.21, 11.66, 0.16, 0.79, 1.37, 0.80, 20.0],
                        :frac2      => [51.08, 9.68, 13.26, 11.21, 11.66, 0.16, 0.79, 1.37, 0.80, 20.0],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "SQA Synthetic amphibolite composition",
                        :comments   => "Patino Douce & Beard, 1995",
                        :db         => "mbe",
                        :test       => 4,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [60.05, 6.62, 8.31, 9.93, 6.57, 0.44, 1.83, 1.27, 0.33, 4.64],
                        :frac2      => [60.05, 6.62, 8.31, 9.93, 6.57, 0.44, 1.83, 1.27, 0.33, 4.64],
                        ), cols=:union)

push!(db,Dict(          :bulk       => "predefined",
                        :title      => "BL478: Sample 478",
                        :comments   => "Beard & Lofgren, 1991",
                        :db         => "mbe",
                        :test       => 5,
                        :sysUnit    => "mol",
                        :oxide      => ["SiO2","Al2O3","CaO","MgO","FeO","K2O","Na2O","TiO2","O","H2O"],
                        :frac       => [53.96, 9.26, 10.15, 8.11, 10.14, 0.11, 2.54, 1.35, 0.98, 3.42],
                        :frac2      => [53.96, 9.26, 10.15, 8.11, 10.14, 0.11, 2.54, 1.35, 0.98, 3.42],
                        ), cols=:union)


dbte = DataFrame(       composition = String[],
                        title       = String[],
                        comments    = String[],
                        test        = Int64[],
                        elements    = Array{String, 1}[],
                        μg_g        = Array{Float64, 1}[],
                        μg_g2       = Array{Float64, 1}[],
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



db.frac_wt  .= mol2wt.(db.frac,db.oxide)
db.frac2_wt .= mol2wt.(db.frac2,db.oxide)

for (i,val) in enumerate(db.frac_wt)
    db.frac_wt[i] = round.(val,digits= 6)
end
for (i,val) in enumerate(db.frac2_wt)
    db.frac2_wt[i] = round.(val,digits= 6)
end

hidden_pp = ["O2","qfm","mw","iw","qif","nno","hm","cco","aH2O","aO2","aMgO","aFeO","aAl2O3","aTiO2",]

# load ss and em informations to be display in information tab
# Read the JSON file
file_path   = joinpath(pkg_dir,"src","./tools/em_name.json")
dict_em     = JSON.parsefile(file_path)
file_path   = joinpath(pkg_dir,"src","./tools/ss_name.json")
dict_ss     = JSON.parsefile(file_path)

db_inf      = retrieve_solution_phase_information("ig");


# retrieve MAGEMin version number info
data = Initialize_MAGEMin("mp", verbose=false);
data = use_predefined_bulk_rock(data, 0);
out  = point_wise_minimization(4.0,400.0, data);
Finalize_MAGEMin(data);

const GUI_version       = string(pkgversion(MAGEMinApp))
const MAGEMin_version   = out.MAGEMin_ver
const MAGEMin_C_version = string(pkgversion(MAGEMin_C))

# Keep track of simulation progress - note that this should be added to a single global variable
global CompProgress      =  ComputationalProgress()
customWs                 =  DataFrame()

# Here we fill a tupple with the KDs for the OL12 database
file_path   = joinpath(pkg_dir,"src","./tools/OL12.jld2")
@load file_path OL12

KDs = [(OL12[2],OL12[3],OL12[4],"OL","Laurent, O. 2012",OL12[1])]


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
            db_inf              = db_inf,
            customWs            = customWs
            )   
