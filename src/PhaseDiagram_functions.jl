#=~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Project      : MAGEMin_App
#   License      : GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
#   Developers   : Nicolas Riel, Boris Kaus
#   Contributors : Nerone, S., Dominguez, H., Moyen, J-F.
#   Organization : Institute of Geosciences, Johannes-Gutenberg University, Mainz
#   Contact      : nriel[at]uni-mainz.de
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ =#

import Contour as CTR

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
    hidden  :: Vector{Int64}
    isoP    :: Vector{GenericTrace{Dict{Symbol, Any}}}
    isoPexp :: Vector{GenericTrace{Dict{Symbol, Any}}}
    isoT    :: Vector{CTR.ContourCollection{CTR.ContourLevel{Tuple{Float64, Float64}, Float64}}}
    isoCap  :: Vector{GenericTrace{Dict{Symbol, Any}}}

    label   :: Vector{String}
    value   :: Vector{Int64}
end


"""
    Function to recover Zenodo link for MAGEMin packages
"""
function get_zenodo_link(   organization    :: String,
                            package_name    :: String, 
                            version         :: String )

    link        = "(link will be available soon)"
    try
        query       = "https://zenodo.org/api/records/?q=$organization+$package_name+$version"
        response    = HTTP.get(query)
        if response.status == 200
            records = JSON3.read(response.body)
            if length(records["hits"]["hits"]) > 0 && occursin(package_name,records["hits"]["hits"][1]["metadata"]["title"])
                link = records["hits"]["hits"][1]["links"]["self_html"]
            end
        end
    catch err
        link = "(offline, cannot fetch link)"
    end
    return link
end

function retrieve_statement()
    GUI_link          = get_zenodo_link("ComputationalThermodynamics", "MAGEMinApp",  String(GUI_version)         )
    MAGEMin_C_link    = get_zenodo_link("ComputationalThermodynamics", "MAGEMin_C",   String(MAGEMin_C_version)   )
    MAGEMin_link      = get_zenodo_link("ComputationalThermodynamics", "MAGEMin",     String(split(MAGEMin_version)[1])     )
    statement         = "The version of the softwares used to produce the equilibrium thermodynamics calculations are available on Zenodo at, MAGEMin v$(split(MAGEMin_version)[1]): $MAGEMin_link, MAGEMin_C v$MAGEMin_C_version: $MAGEMin_C_link and MAGEMinApp v$GUI_version: $GUI_link."

    return statement
end


function get_system_comp_acronyme(bulk,oxides)

    return acronym
end

""" 
    inside range function
"""
function is_inside_range(point, x_range, y_range)
    x, y = point
    return x_range[1] <= x <= x_range[2] && y_range[1] <= y <= y_range[2]
end

"""
    inside polygon function
"""
function is_inside_polygon(point, polygon)
    return PolygonOps.inpolygon(point, polygon)
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


function prt(   in    ::Union{Float64,Vector{Float64}};
                acc   ::Int64                             =   4)

    if typeof(in) == Vector{Float64}
        out = " $( join( round.( in, digits  =   acc)," ") )"
    else
        out = " $(       round( in, digits   =   acc)      )"
    end

    return out
end


"""
    Retrieve AFM diagram
"""
function get_AFM_phase_diagram()

    global points_in_idx, Out_XY;

    n_ox    = length(Out_XY[1].oxides)
    oxides  = Out_XY[1].oxides
    n_tot   = length(points_in_idx)

    liq_afm        = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))    .= missing
    liq_wt          = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    liq_P           = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    colormap        = get_jet_colormap(n_tot+1)
 
    for j=1:n_tot
        id      = findall(Out_XY[points_in_idx[j]].ph .== "liq")
        if ~isempty(id)
            liq_afm[:,j] = Out_XY[points_in_idx[j]].SS_vec[id[1]].Comp_wt .*100.0
            liq_wt[j]    = Out_XY[points_in_idx[j]].ph_frac_wt[id[1]]
            liq_P[j]     = Out_XY[points_in_idx[j]].P_kbar
        end
    end

    afm_  = findall(oxides .== "Al2O3" .|| oxides .== "FeO" .|| oxides .== "MgO") 

    id_A = findall(oxides .== "Al2O3") 
    id_F = findall(oxides .== "FeO")
    id_M = findall(oxides .== "MgO")

    if ~isempty(afm_)
        liq_afm ./= sum(liq_afm[afm_,:],dims=1)
        liq_afm .*= 100.0
    end

    A   = liq_afm[id_A,:]
    F   = liq_afm[id_F,:]
    M   = liq_afm[id_M,:]

    # Create the ternary plot
    afm = scatterternary(
        b       = A,
        a       = F,
        c       = M,
        mode    = "markers",
        hoverinfo   = "skip",
        opacity     = 0.6,
        marker  = attr(     size        = liq_wt .*20.0 .+ 2.0,
                            color       = liq_P,
                            colorscale  = colormap,
                            line        = attr( width = 0.75,
                                                color = "black" )    ),
        name    = "Sample Points"
    )
    
    layout_afm = Layout(
        title= attr(
            text    = "AFM Diagram [wt%]",
            x       = 0.2,
            xanchor = "center",
            yanchor = "top"
        ),
        ternary=attr(
            sum     = 100,
            baxis   = attr(title="A [Al2O3]", gridcolor     = "darkgray",
                                                showline    =  true,
                                                linecolor   = "darkgray"),
            aaxis   = attr(title="F [FeOt]" ,   gridcolor   = "darkgray",
                                                showline    =  true,
                                                linecolor   = "darkgray"),
            caxis   = attr(title="M [MgO]"  ,   gridcolor   = "darkgray",
                                                showline    =  true,
                                                linecolor   = "darkgray"),
            bgcolor = "#FFF",
            width       = 640,
            height      = 400,
        ),
        paper_bgcolor = "#FFF",
    )

    return afm, layout_afm
end


"""
    Retrieve TAS diagram
"""
function get_TAS_phase_diagram()

    global points_in_idx, Out_XY;

    tas      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, 16);

    F        = [35. 0; 41 0; 41 7; 45 9.4; 48.4 11.5; 52.5 14; 48 16; 35 16;35 0]
    Pc       = [41. 0; 45 0; 45 3; 41 3;41 0]
    U1       = [41. 3; 45 3; 45 5; 49.4 7.3; 45 9.4; 41 7;41 3]
    U2       = [49.4 7.3; 53 9.3; 48.4 11.5; 45 9.4;49.4 7.3]
    U3       = [53. 9.3; 57.6 11.7; 52.5 14; 48.4 11.5;53 9.3]
    Ph       = [52.5 14; 57.6 11.7; 65 16; 48 16;52.5 14]
    B        = [45. 0; 52 0; 52 5; 45 5;45 0]
    S1       = [45. 5; 52 5; 49.4 7.3;45 5]
    S2       = [52. 5; 57 5.9; 53 9.3; 49.4 7.3;52 5]
    S3       = [57. 5.9; 63 7; 57.6 11.7; 53 9.3;57 5.9]
    T        = [63. 7; 69 8; 69 16; 65 16; 57.6 11.7;63 7]
    O1       = [52. 0; 57 0; 57 5.9; 52 5;52 0]
    O2       = [57. 0; 63 0; 63 7; 57 5.9;57 0]
    O3       = [63. 0; 77 0; 69 8; 63 7;63 0]
    R        = [77. 0; 85 0; 85 16; 69 16; 69 8;77 0]

    fields   = (F,Pc,U1,U2,U3,Ph,B,S1,S2,S3,T,O1,O2,O3,R)
    nf       = length(fields)
    xc       = zeros(nf)
    yc       = zeros(nf)

    for i=1:nf
        xc[i] = sum(fields[i][1:end-1,1])/(size(fields[i],1)-1.0)
        yc[i] = sum(fields[i][1:end-1,2])/(size(fields[i],1)-1.0)
    end
    
    # annotations shifts
    xc[1]   -=4.0;
    yc[1]   +=3.0;
    yc[3]   +=1.0;
    xc[6]   +=2.0;
    yc[8]   -=0.25;
    yc[9]   +=0.25;


    name = ["foidite" "picrobasalt" "basanite" "phonotephrite" "tephriphonolite" "phonolite" "basalt" "trachybasalt" "basaltic<br>trachyandesite" "trachyandesite" "trachyte" "basaltic<br>andesite" "andesite" "dacite" "rhyolite"];
       
    for i = 1:nf
        tas[i] = scatter(   x           = fields[i][:,1], 
                            y           = fields[i][:,2], 
                            hoverinfo   = "skip",
                            mode        = "lines",
                            showscale   = false,
                            showlegend  = false,
                            line        = attr( color   = "black", 
                                                width   = 0.75)                )
    end


    n_ox    = length(Out_XY[1].oxides)
    oxides  = Out_XY[1].oxides
    n_tot   = length(points_in_idx)

    liq_tas         = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))    .= missing
    liq_wt          = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    liq_P           = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    colormap        = get_jet_colormap(n_tot+1)
 
    for j=1:n_tot
        id      = findall(Out_XY[points_in_idx[j]].ph .== "liq")
        if ~isempty(id)
            liq_tas[:,j] = Out_XY[points_in_idx[j]].SS_vec[id[1]].Comp_wt .*100.0
            liq_wt[j]    = Out_XY[points_in_idx[j]].ph_frac_wt[id[1]]
            liq_P[j]     = Out_XY[points_in_idx[j]].P_kbar
        end
    end

    dry  = findall(oxides .!= "H2O") 
    id_Y = findall(oxides .== "K2O" .|| oxides .== "Na2O")
    id_X = findall(oxides .== "SiO2") 

    if ~isempty(dry)
        liq_tas ./=sum(liq_tas[dry,:],dims=1)
        liq_tas .*= 100.0
    end

    tas[end] = scatter(     x           = liq_tas[id_X,:], 
                            y           = sum(liq_tas[id_Y,:],dims=1), 
                            hoverinfo   = "skip",
                            mode        = "markers",
                            opacity     = 0.6,
                            showscale   = false,
                            showlegend  = false,
                            marker      = attr(     size        = liq_wt .*20.0 .+ 2.0,
                                                    color       = liq_P,
                                                    colorscale  = colormap,
                                                    line        = attr( width = 0.75,
                                                                        color = "black" )    ))

    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,nf)

    for i=1:nf
        annotations[i] =   attr(    xref        = "x",
                                    yref        = "y",
                                    x           = xc[i],
                                    y           = yc[i],
                                    text        = name[i],
                                    showarrow   = false,
                                    visible     = true,
                                    font        = attr( size = 10, color = "#212121"),
                                )  
    end

    layout  = Layout(

        title= attr(
            text    = "Volcanic TAS Diagram [Anhydrous, wt%]",
            x       = 0.5,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "SiO2 [wt%]",
        yaxis_title = "K2O + Na2O [wt%]",
        xaxis_range = [35.0, 85.0], 
        # yaxis_range = [0.0,15.0],
        annotations = annotations,
        width       = 640,
        height      = 400,
        xaxis       = attr(     fixedrange    = true,
                            ),
        yaxis       = attr(     fixedrange    = true,
                            ),
    )

   
    return tas, layout
end


function get_TAS_pluto_phase_diagram()

    global points_in_idx, Out_XY;

    tas      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, 16);

    fields   = ([40.433 9.475; 35.836 6.548; 35.836 5.52; 38.901 4.022; 43.452 8.291; 40.433 9.475], [48.885 14.972; 40.433 9.475; 43.452 8.291; 45.635 9.497; 51.858 13.274; 48.885 14.972], [51.904 15.978; 48.885 14.972; 51.858 13.274; 54.876 11.285; 58.034 11.508; 61.842 13.922; 53.994 15.955; 51.904 15.978], [61.889 10.056; 58.034 11.508; 61.842 13.922; 68.854 11.777; 64.954 8.983; 61.889 10.056], [73.963 9.52; 68.854 11.777; 64.954 8.983; 69.969 5.43; 74.009 8.492; 73.963 9.52], [63.003 6.972; 64.954 8.983; 69.969 5.43; 62.91 3.352; 63.003 6.972], [54.876 5.52; 63.003 6.994; 62.91 3.352; 56.827 1.497; 54.969 1.497; 54.876 5.52], [51.95 5.587; 54.876 5.52; 54.969 1.497; 51.95 1.52; 51.95 5.587], [44.427 5.765; 51.95 5.587; 51.95 1.52; 43.87 1.497; 40.898 3.062; 44.427 5.765], [44.427 5.765; 40.898 3.062; 38.901 4.022; 43.452 8.291; 45.635 9.497; 47.91 8.514; 46.006 7.017; 44.427 5.765], [47.91 8.514; 45.635 9.497; 51.858 13.274; 54.876 11.285; 50.0 9.296; 47.91 8.514], [54.923 9.296; 50.0 9.296; 54.876 11.285; 58.034 11.508; 61.889 10.056; 56.78 8.961; 54.923 9.296], [52.926 7.017; 56.78 8.961; 61.889 10.056; 64.954 8.983; 63.003 6.994; 54.876 5.52; 51.95 5.587; 52.926 7.017], [52.926 7.017; 51.95 5.587; 44.427 5.765; 46.053 7.039; 52.926 7.017], [56.78 8.961; 52.926 7.017; 46.053 7.039; 47.91 8.514; 50.0 9.296; 54.923 9.296; 56.78 8.961])
    nf       = length(fields)
    xc       = zeros(nf)
    yc       = zeros(nf)

    for i=1:nf
        xc[i] = sum(fields[i][2:end,1])/(Float64(size(fields[i],1)) -1.0)
        yc[i] = sum(fields[i][2:end,2])/(Float64(size(fields[i],1)) -1.0)
    end
    
    # annotations shifts
    xc[6]   +=0.75;


    name = [
        "Ijolite",
        "",
        "Nepheline<br>syenite",
        "Syenite",
        "Granite",
        "Granodiorite",
        "diorite",
        "Gabbro<br>diorite",
        "Gabbro",
        "",
        "",
        "Syenite",
        "Syenodiorite",
        "Gabbro",
        "Syenodiorite"
    ] 

    for i = 1:nf
        tas[i] = scatter(   x           = fields[i][:,1], 
                            y           = fields[i][:,2], 
                            hoverinfo   = "skip",
                            mode        = "lines",
                            showscale   = false,
                            showlegend  = false,
                            line        = attr( color   = "black", 
                                                width   = 0.75)                )
    end


    n_ox    = length(Out_XY[1].oxides)
    oxides  = Out_XY[1].oxides
    n_tot   = length(points_in_idx)

    liq_tas         = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))    .= missing
    liq_wt          = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    liq_P           = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    colormap        = get_jet_colormap(n_tot+1)
 
    for j=1:n_tot
        id      = findall(Out_XY[points_in_idx[j]].ph .== "liq")
        if ~isempty(id)
            liq_tas[:,j] = Out_XY[points_in_idx[j]].SS_vec[id[1]].Comp_wt .*100.0
            liq_wt[j]    = Out_XY[points_in_idx[j]].ph_frac_wt[id[1]]
            liq_P[j]     = Out_XY[points_in_idx[j]].P_kbar
        end
    end

    dry  = findall(oxides .!= "H2O") 
    id_Y = findall(oxides .== "K2O" .|| oxides .== "Na2O")
    id_X = findall(oxides .== "SiO2") 

    if ~isempty(dry)
        liq_tas ./=sum(liq_tas[dry,:],dims=1)
        liq_tas .*= 100.0
    end

    tas[end] = scatter(     x           = liq_tas[id_X,:], 
                            y           = sum(liq_tas[id_Y,:],dims=1), 
                            hoverinfo   = "skip",
                            mode        = "markers",
                            opacity     = 0.6,
                            showscale   = false,
                            showlegend  = false,
                            marker      = attr(     size        = liq_wt .*20.0 .+ 2.0,
                                                    color       = liq_P,
                                                    colorscale  = colormap,
                                                    line        = attr( width = 0.75,
                                                                        color = "black" )    ))

    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,nf)

    for i=1:nf
        annotations[i] =   attr(    xref        = "x",
                                    yref        = "y",
                                    x           = xc[i],
                                    y           = yc[i],
                                    text        = name[i],
                                    showarrow   = false,
                                    visible     = true,
                                    font        = attr( size = 10, color = "#212121"),
                                )  
    end

    layout  = Layout(

        title= attr(
            text    = "Plutonic TAS Diagram [Anhydrous, wt%]",
            x       = 0.5,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "SiO2 [wt%]",
        yaxis_title = "K2O + Na2O [wt%]",
        xaxis_range = [35.0, 85.0], 
        # yaxis_range = [0.0,  17.50],
        annotations = annotations,
        width       = 600,
        height      = 400,
        xaxis       = attr(     fixedrange    = true,
                            ),
        yaxis       = attr(     fixedrange    = true,
                            ),
    )

   
    return tas, layout
end



function get_phase_diagram_information(npoints, dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2, PTpath, watsat, watsat_val)

    ptx_data    = copy(PTpath)
    np      = length(ptx_data)
    Pres    = zeros(Float64,np)
    Temp    = zeros(Float64,np)
    x       = zeros(Float64,np)
    for i=1:np
        Pres[i] = to_kbar_pressure(ptx_data[i][Symbol("col-1")])
        Temp[i] = ptx_data[i][Symbol("col-2")]
        x[i]    = (i-1)*(1.0/(np-1))
    end

    PD_infos  = Vector{String}(undef,2)

    datetoday = string(Dates.today())
    rightnow  = string(Dates.Time(Dates.now()))


    if diagType == "pt"
        dgtype = "Pressure-Temperature, fixed composition"
    elseif diagType == "px"
        dgtype = "Pressure-Composition, fixed temperature"
    elseif diagType == "tx"
        dgtype = "Temperature-Composition, fixed pressure"
    elseif diagType == "ptx"
        dgtype = "Pressure Temperature path-Composition"
    elseif diagType == "tt"
        dgtype = "Polymetamorphic T-T path, fixed pressure"
    end

    if solver == "lp"
        solv = "LP (legacy)"
    elseif solver == "pge"
        solv = "PGE (default)"
    elseif solver == "hyb"
        solv = "Hybrid (PGE&LP)"
    end


    db_in     = retrieve_solution_phase_information(dtb)


    PD_infos[1]  = "Phase Diagram computed using MAGEMin $(MAGEMin_version) (MAGEMin_C v$(MAGEMin_C_version); GUI $(GUI_version)) <br>"
    PD_infos[1] *= "‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾<br>"
    PD_infos[1] *= "Number of points <br>"
    
    PD_infos[1] *= "Date & time <br>"
    PD_infos[1] *= "Database <br>"
    PD_infos[1] *= "Solution names <br>"
    PD_infos[1] *= "Diagram type <br>"
    if watsat == "true"
        PD_infos[1] *= "Water saturation<br>"
    end
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
        PD_infos[1] *= "X0 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end
        PD_infos[1] *= "X1 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "Fixed Temp <br>"
    elseif diagType == "tx"
        PD_infos[1] *= "X0 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "X1 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "Fixed Pres [$(pressure_unit_label())] <br>"
    elseif diagType == "ptx"
        PD_infos[1] *= "X0 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "X1 comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end        
        PD_infos[1] *= "PT path [P $(pressure_unit_label())]<br>"
        PD_infos[1] *= "PT path [T °C]<br>"
        # add ptx path here
    elseif diagType == "tt"
        PD_infos[1] *= "Starting comp [mol] <br>"
        if bufferType != "none"
            PD_infos[1] *= "Buffer factor <br>"
        end           
        PD_infos[1] *= "Fixed Pres [$(pressure_unit_label())] <br>"
    end
    oxi_string = replace.(oxi,"2"=>"₂", "3"=>"₃");

    PD_infos[1] *= "_____________________________________________________________________________________________________"
    PD_infos[2] = "<br>"
    PD_infos[2] *= "<br>"
    PD_infos[2] *= string(npoints) * "<br>"
    
    PD_infos[2] *= datetoday * ", " * rightnow * "<br>"
    PD_infos[2] *= dba[(dba.acronym .== dtb) , :].database[1] *"; "* Out_XY[1].dataset * "<br>" 
    PD_infos[2] *= join(phase_infos.act_sol, ", ") *"<br>"
    PD_infos[2] *= dgtype *"<br>"

    if watsat == "true"
        PD_infos[2] *= "Computed at solidus (+ $(watsat_val) mol% H2O) <br>"
    end

    PD_infos[2] *= solv *"<br>"

    PD_infos[2] *= join(oxi_string, " ") *"<br>"
    if bufferType != "none"
        PD_infos[2] *= bufferType *"<br>"
    end            
    if diagType == "pt"
        PD_infos[2] *= join(round.(bulk_L,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end       
    elseif diagType == "px"
        PD_infos[2] *= join(round.(bulk_L,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end
        PD_infos[2] *= join(round.(bulk_R,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(fixT, " ") *"<br>"
    elseif diagType == "tx"
        PD_infos[2] *= join(round.(bulk_L,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end        
        PD_infos[2] *= join(round.(bulk_R,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(display_pressure(fixP), " ") *"<br>"
    elseif diagType == "ptx"
        PD_infos[2] *= join(round.(bulk_L,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end        
        PD_infos[2] *= join(round.(bulk_R,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN2) *"<br>"
        end        
        PD_infos[2] *= join(display_pressure(Pres), " ") *"<br>"
        PD_infos[2] *= join(Temp, " ") *"<br>"
    elseif diagType == "tt"
        PD_infos[2] *= join(round.(bulk_L,digits=6), " ") *"<br>"
        if bufferType != "none"
            PD_infos[2] *= string(bufferN1) *"<br>"
        end        
        # PD_infos[2] *= join(round.(bulk_R,digits=6), " ") *"<br>"
        # if bufferType != "none"
        #     PD_infos[2] *= string(bufferN2) *"<br>"
        # end        
        PD_infos[2] *= join(display_pressure(fixP), " ") *"<br>"
    end

    PD_infos[2] *= "_"

    return PD_infos
end

"""
    Diagram type function 
        diagram_type(diagType, tmin, tmax, pmin, pmax)

    returns axis titles and axis ranges
"""
function diagram_type(diagType, tmin, tmax, pmin, pmax, e1_tmin, e1_tmax, e2_tmin, e2_tmax)
    if diagType == "pt"
        xtitle = "Temperature [Celsius]"
        ytitle = "Pressure [$(pressure_unit_label())]"
        Xrange          = (Float64(tmin),Float64(tmax))
        Yrange          = (Float64(pmin),Float64(pmax))
    elseif diagType == "px"
        Xrange          = (Float64(0.0),Float64(1.0))
        Yrange          = (Float64(pmin),Float64(pmax))
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Pressure [$(pressure_unit_label())]"
    elseif diagType == "tx"
        Xrange          = (Float64(0.0),Float64(1.0) )
        Yrange          = (Float64(tmin),Float64(tmax))
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Temperature [Celsius]"
    elseif diagType == "ptx"
        Xrange          = (Float64(0.0),Float64(1.0) )
        Yrange          = (Float64(0.0),Float64(1.0))
        xtitle = "Composition [X0 -> X1]"
        ytitle = "Pressure-Temperature path"
    elseif diagType == "tt"
            xtitle = "Event 2: temperature [Celsius]"
            ytitle = "Event 1: temperature [Celsius]"
            Xrange          = (Float64(e2_tmin),Float64(e2_tmax))
            Yrange          = (Float64(e1_tmin),Float64(e1_tmax))
    end
    return xtitle, ytitle, Xrange, Yrange
end

"""
    apply_pressure_display(data_in, layout_in, diagType)

    Returns copies of `data_in`/`layout_in` with the y-axis (pressure) rescaled
    from kbar to the currently selected display unit (cosmetic only). The
    underlying `data_plot`/`layout` globals always remain in kbar.
"""
function apply_pressure_display(data_in, layout_in, diagType)
    if !use_GPa[1] || !(diagType in ("pt","px","ptx"))
        return data_in, layout_in
    end

    data_out = deepcopy(data_in)
    for tr in data_out
        if haskey(tr, :y) && tr[:y] isa AbstractArray && all(v -> v isa Union{Missing,Real}, tr[:y])
            tr[:y] = display_pressure(tr[:y])
        end
    end

    layout_out = deepcopy(layout_in)
    if haskey(layout_out, :yaxis)
        ya = layout_out[:yaxis]
        if haskey(ya, :range)
            ya[:range] = display_pressure(collect(Float64, ya[:range]))
        end
        if haskey(ya, :tick0)
            ya[:tick0] = display_pressure(Float64(ya[:tick0]))
        end
        if haskey(ya, :dtick)
            ya[:dtick] = display_pressure(Float64(ya[:dtick]))
        end
        ya[:title] = "Pressure [$(pressure_unit_label())]"
    end

    if haskey(layout_out, :annotations)
        for ann in layout_out[:annotations]
            if haskey(ann, :y) && ann[:y] isa Number
                ann[:y] = display_pressure(Float64(ann[:y]))
            end
        end
    end

    return data_out, layout_out
end

"""
    convert2Float64(bufferN1, bufferN2,fixT,fixP)

    converts input to float if the provided value is an integer
"""
function convert2Float64(bufferN1, bufferN2,fixT,fixP,e1_liq,e2_liq,e1_remain_wat,e2_remain_wat,e1_remain,e2_remain)
    bufferN1 = Float64(bufferN1)
    bufferN2 = Float64(bufferN2)
    fixT     = Float64(fixT)
    fixP     = Float64(fixP)
    e1_liq   = Float64(e1_liq)
    e2_liq   = Float64(e2_liq)
    e1_remain   = Float64(e1_remain)
    e2_remain   = Float64(e2_remain)
    e1_remain_wat   = Float64(e1_remain_wat)
    e2_remain_wat   = Float64(e2_remain_wat)
    return bufferN1, bufferN2, fixT, fixP, e1_liq, e2_liq,e1_remain_wat,e2_remain_wat,e1_remain, e2_remain
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

    if haskey(custom_colormaps, colorMap)
        colorm = get_custom_colorscale(colorMap, rangeColor)
    elseif rangeColor == [1,9]
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
function get_bulkrock_prop(bulk1, bulk2; sys_unit = 1)
 
    n_ox    = length(bulk1);
    bulk_L  = zeros(n_ox); 
    bulk_R  = zeros(n_ox);
    oxi     = Vector{String}(undef, n_ox)
    # in case the bulk rock is entered manually, the inputed values can be a string, this ensures convertion to float64
    for i=1:n_ox
        tmp = bulk1[i][:fraction]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        tmp2 = bulk2[i][:fraction]
        if typeof(tmp2) == String
            tmp2 = parse(Float64,tmp2)
        end
        bulk_L[i]   = tmp;
        bulk_R[i]   = tmp2;
        oxi[i]      = bulk1[i][:oxide];
    end

    bulk_L  = bulk_L ./ sum(bulk_L)
    bulk_R  = bulk_R ./ sum(bulk_R)

    if sys_unit == 2 #then we are using wt% as input
        bulk_L  = wt2mol(bulk_L,oxi)
        bulk_R  = wt2mol(bulk_R,oxi)
    end

    return bulk_L, bulk_R, oxi
end




"""
    get_terock_prop(bulkte1, bulkte2)

    retrieve trace element compositions
"""
function get_terock_prop(bulkte1, bulkte2)
 
    n_el        = length(bulkte1);
    bulkte_L    = zeros(n_el); 
    bulkte_R    = zeros(n_el);
    elem        = Vector{String}(undef, n_el)
    # in case the bulk rock is entered manually, the inputed values can be a string, this ensures convertion to float64
    for i=1:n_el
        tmp = bulkte1[i][:μg_g]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        tmp2 = bulkte2[i][:μg_g]
        if typeof(tmp2) == String
            tmp2 = parse(Float64,tmp2)
        end
        bulkte_L[i]     = tmp;
        bulkte_R[i]     = tmp2;
        elem[i]         = bulkte1[i][:elements];
    end

    return bulkte_L, bulkte_R, elem
end



function tepm_function( diagType    :: String,
                        dtb         :: String,
                        kds_mod     :: String,
                        zrsat_mod   :: String,
                        ssat_mod    :: String,
                        co2sat_mod  :: String,
                        P2O5sat_mod :: String,
                        bulkte_L    :: Vector{Float64},
                        bulkte_R    :: Vector{Float64},
                        elem_TE     :: Vector{String})

    np          = length(Out_XY)
    
    Out_TE_XY   = Vector{MAGEMin_C.out_tepm}(undef,np)

    all_TE_ph   = []

    KDs_dtb = build_kds_database(kds_mod)
    global KDs_TE_elements = KDs_dtb.element_name

    bulkte_L      = MAGEMin_C.adjust_chemical_system( KDs_dtb, bulkte_L, elem_TE );
    bulkte_R      = MAGEMin_C.adjust_chemical_system( KDs_dtb, bulkte_R, elem_TE );
    TEvec         = Vector{Float64}(undef, length(bulkte_L));
    for i = 1:np

        if diagType != "pt"
            TEvec .= bulkte_L*(1.0 - Out_XY[i].X[1]) + bulkte_R*Out_XY[i].X[1];
        else
            TEvec .= bulkte_L
        end

        Out_TE_XY[i]  = TE_prediction(Out_XY[i], TEvec, KDs_dtb, dtb;
                                      ZrSat_model   = zrsat_mod,
                                      SSat_model    = ssat_mod,
                                      CO2Sat_model  = co2sat_mod,
                                      P2O5Sat_model = P2O5sat_mod)

        if ~isnothing(Out_TE_XY[i].ph_TE)
            for j in Out_TE_XY[i].ph_TE
                if !(j in all_TE_ph)
                    push!(all_TE_ph,string(j))
                end
            end
        end

    end

    return Out_TE_XY, all_TE_ph
end



"""
    compute_new_phaseDiagram(   xtitle,     ytitle,     
                                Xrange,     Yrange,     fieldname,
                                dtb,        diagType,   verbose,    scp,    solver,
                                fixT,       fixP,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                smooth,     colorm,     reverseColorMap,
                                test,       PT_infos,   refType                                     )

    Compute a new phase diagram from scratch
"""
function compute_new_phaseDiagram(  xtitle,     ytitle,     lbl,        field_size,
                                    Xrange,     Yrange,     fieldname,  customTitle,
                                    dtb,        dataset,    custW,      diagType,   verbose,    scp,    solver,    boost,  phase_selection,
                                    fixT,       fixP,
                                    e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,
                                    sub,        refLvl,
                                    watsat,     watsat_val, cpx,        limOpx,     limOpxVal,  PTpath,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    minColor,   maxColor,
                                    smooth,     colorm,     reverseColorMap, set_white,
                                    test,       refType,
                                    seismicScheme = "VRH", seismicWeightFactor = 0.5,
                                    seismic_cor = false, aspect_ratio = 0.3, seismic_water = 0,
                                    shallow_cor = false, anelastic_correction = false        )
        global CompProgress

        #________________________________________________________________________________________#
        # Create coarse mesh
        CompProgress.stage = "Initialize AMR mesh"
        data = init_AMR(Xrange,Yrange,sub)

        #________________________________________________________________________________________#
        # initialize database
        global data, Hash_XY, Out_XY, n_phase_XY, data_plot, gridded, gridded_info, gridded_fields, phase_infos, X, Y, layout, n_lbl
        global addedRefinementLvl  = 0;
        global MAGEMin_data;

        CompProgress.stage = "Get initial parameters"
        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 


        global pChip_wat, pChip_T;
        if diagType == "pt" && watsat == "true"
            pChip_wat, pChip_T = get_wat_sat_function(         Yrange,     bulk_L,     oxi,    phase_selection,
                                                                dtb,        bufferType, solver,
                                                                verbose,    bufferN1,
                                                                cpx,        limOpx,     limOpxVal, watsat_val)
        else
            pChip_wat, pChip_T = nothing, nothing
        end
                    
        CompProgress.stage = "Initialize MAGEMin"
        MAGEMin_data    =   Initialize_MAGEMin( dtb;
                                                verbose             = false,
                                                dataset             = dataset,
                                                limitCaOpx          = limitCaOpx,
                                                CaOpxLim            = CaOpxLim,
                                                mbCpx               = mbCpx,
                                                buffer              = bufferType,
                                                solver              = sol,
                                                seismicScheme       = seismicScheme,
                                                seismicWeightFactor = seismicWeightFactor    );

        #________________________________________________________________________________________#
        # initial optimization on regular grid
        CompProgress.stage = "Compute initial grid "
        CompProgress.refinement_level = 0
        CompProgress.total_levels = refLvl
        CompProgress.tinit =  time()
        CompProgress.total_points = length(data.npoints)

        Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin(  dtb, data, MAGEMin_data, custW,  diagType, PTpath,
                                                        phase_selection, fixT, fixP,
                                                        e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,
                                                        oxi, bulk_L, bulk_R,
                                                        bufferType, bufferN1, bufferN2,
                                                        scp, boost, refType,
                                                        pChip_wat, pChip_T,
                                                        seismic_cor, aspect_ratio, seismic_water, shallow_cor, anelastic_correction    )

        
        #________________________________________________________________________________________#     
        # Refine the mesh along phase boundaries
        # if diagType != "tt"
            CompProgress.stage = "refine grid level ->"
            for irefine = 1:refLvl
                # update computational progress 
                CompProgress.refinement_level = irefine
                CompProgress.tinit =  time()
                
                data    = select_cells_to_split_and_keep(data)
                data    = perform_AMR(data)
                CompProgress.total_points = length(data.npoints)
                t = @elapsed Out_XY, Hash_XY, n_phase_XY = refine_MAGEMin(              dtb, data, MAGEMin_data, custW,  diagType, PTpath,
                                                                                        phase_selection, fixT, fixP,
                                                                                        e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,
                                                                                        oxi, bulk_L, bulk_R,
                                                                                        bufferType, bufferN1, bufferN2,
                                                                                        scp, boost, refType,
                                                                                        pChip_wat, pChip_T,
                                                                                        seismic_cor, aspect_ratio, seismic_water, shallow_cor, anelastic_correction ) # recompute points that have not been computed before
                                                                        
                println("Computed $(length(data.npoints)) new points in $t seconds")
            end
        # end

        for i = 1:Threads.maxthreadid()
            finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
        end

        #________________________________________________________________________________________#                   
        # Scatter plotly of the grid

        gridded, gridded_info, gridded_fields, X, Y, npoints, meant = get_gridded_map(  fieldname,
                                                                                        "major",
                                                                                        oxi,
                                                                                        Out_XY,
                                                                                        nothing,
                                                                                        Hash_XY,
                                                                                        sub,
                                                                                        refLvl,
                                                                                        refType,
                                                                                        data,
                                                                                        Xrange,
                                                                                        Yrange)

        phase_infos = get_phase_infos(Out_XY)                                                                                

        PT_infos = get_phase_diagram_information(npoints, dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2,PTpath,watsat,watsat_val)

        data_plot, annotations, txt_list = get_diagram_labels(  Out_XY,
                                                                Hash_XY,
                                                                refType,
                                                                data,
                                                                PT_infos;
                                                                field_size = field_size )
        ticks   = 4
        frame   = get_plot_frame(Xrange,Yrange, ticks)                                  
        layout  = Layout(
                    images=frame,
                    title= attr(
                        text    = customTitle,
                        x       = 0.5,
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
                    width       = 720,
                    height      = 900,
                    autosize    = false,
                    margin      = attr(autoexpand = false, l=0, r=116, b=260, t=50, pad=1),
                    xaxis_range = Xrange, 
                    yaxis_range = Yrange,
                    xaxis       = attr(     tickmode    = "linear",
                                            tick0       = Xrange[1],
                                            dtick       = (Xrange[2]-Xrange[1])/(ticks+1),
                                            fixedrange    = true,
                                        ),
                    yaxis       = attr(     tickmode    = "linear",
                                            tick0       = Yrange[1],
                                            dtick       = (Yrange[2]-Yrange[1])/(ticks+1),
                                            fixedrange    = true,
                                    ),
                )
        minColor        = round(minimum(skipmissing(gridded)),digits=2); 
        maxColor        = round(maximum(skipmissing(gridded)),digits=2);    
        if set_white == "true"
            colorm = set_min_to_white(colorm; reverseColorMap)
        end
        if fieldname == "Variance"
        #     colorm = discretize_colormap(colorm,minColor,maxColor)
        end
        heat_map = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
                            zmin            =  minColor,
                            zmax            =  maxColor,
                            zsmooth         = smooth,
                            connectgaps     = true,
                            type            = "heatmap",
                            colorscale      = colorm,
                            reversescale    = reverseColorMap,
                            # colorbar_title  = fieldname,
                            hoverinfo       = "skip",
                            showlegend      = false,
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        exponentformat  = "e" ,
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)


        n       = 2^(sub + refLvl)+1
        xvals   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
        yvals   = range(data.Yrange[1], stop = data.Yrange[2], length = n)
        heat_map_export = heatmap(  x               = xvals,
                                    y               = yvals,
                                    z               = gridded',
                                    zmin            = minColor,
                                    zmax            = maxColor,
                                    zsmooth         = smooth,
                                    connectgaps     = true,
                                    type            = "heatmap",
                                    colorscale      = colorm,
                                    reversescale    = reverseColorMap,
                                    # colorbar_title  = fieldname,
                                    hoverinfo       = "skip",
                                    showlegend      = false,
                                    colorbar        = attr(     lenmode         = "fraction",
                                                                len             =  0.75,
                                                                thicknessmode   = "fraction",
                                                                exponentformat  = "e" ,
                                                                tickness        =  0.5,
                                                                x               =  1.005,
                                                                y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)

        # savefig(plot(heat_map_export,layout), "phase_diagram.svg"; width=720, height=900)

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

        return vcat(data_plot,hover_lbl), layout, npoints, meant, txt_list, heat_map_export
end



"""
    refine_phaseDiagram(            xtitle,     ytitle,     
                                    Xrange,     Yrange,     fieldname,
                                    dtb,        diagType,   verbose,    scp,    solver,
                                    fixT,       fixP,
                                    sub,        refLvl,
                                    cpx,        limOpx,     limOpxVal,
                                    bulk_L,     bulk_R,     oxi,
                                    bufferType, bufferN1,   bufferN2,
                                    smooth,     colorm,     reverseColorMap,
                                    test,       PT_infos,   refType                                   )
    Refine existing phase diagram
"""
function refine_phaseDiagram(   xtitle,     ytitle,     lbl,        field_size,
                                Xrange,     Yrange,     fieldname,  customTitle,
                                dtb,        dataset,    custW,  diagType,   watsat,  watsat_val,
                                verbose,    scp,        solver, boost, phase_selection,
                                fixT,       fixP,
                                e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,
                                sub,        refLvl,
                                cpx,        limOpx,     limOpxVal,  PTpath,
                                bulk_L,     bulk_R,     oxi,
                                bufferType, bufferN1,   bufferN2,
                                minColor,   maxColor,
                                smooth,     colorm,     reverseColorMap, set_white,
                                test,       refType, bid,
                                seismicScheme = "VRH", seismicWeightFactor = 0.5,
                                seismic_cor = false, aspect_ratio = 0.3, seismic_water = 0,
                                shallow_cor = false, anelastic_correction = false       )

    global data, Hash_XY, Out_XY, n_phase_XY, data_plot, gridded, gridded_info, gridded_fields, phase_infos, X, Y, addedRefinementLvl, layout, n_lbl, pChip_wat, pChip_T

    mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                    cpx,        limOpx,     limOpxVal ) 

    MAGEMin_data    =   Initialize_MAGEMin( dtb;
                                            verbose             = false,
                                            dataset             = dataset,
                                            limitCaOpx          = limitCaOpx,
                                            CaOpxLim            = CaOpxLim,
                                            mbCpx               = mbCpx,
                                            buffer              = bufferType,
                                            solver              = sol,
                                            seismicScheme       = seismicScheme,
                                            seismicWeightFactor = seismicWeightFactor    );

    data    = select_cells_to_split_and_keep(data; bid = bid)
    data    = perform_AMR(data)
    t = @elapsed Out_XY, Hash_XY, n_phase_XY  = refine_MAGEMin( dtb, data,  MAGEMin_data, custW,  diagType, PTpath,
                                                                            phase_selection, fixT, fixP,
                                                                            e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,
                                                                            oxi, bulk_L, bulk_R,
                                                                            bufferType, bufferN1, bufferN2,
                                                                            scp, boost, refType,
                                                                            pChip_wat,  pChip_T,
                                                                            seismic_cor, aspect_ratio, seismic_water, shallow_cor, anelastic_correction) # recompute points that have not been computed before

    println("Computed $(length(data.npoints)) new points in $(round(t, digits=3)) seconds")
    addedRefinementLvl += 1;

    for i = 1:Threads.maxthreadid()
        finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
    end

    #________________________________________________________________________________________#                   
    # Scatter plotly of the grid
    gridded, gridded_info, gridded_fields, X, Y, npoints, meant = get_gridded_map(  fieldname,
                                                                                    "major",
                                                                                    oxi,
                                                                                    Out_XY,
                                                                                    nothing,
                                                                                    Hash_XY,
                                                                                    sub,
                                                                                    refLvl + addedRefinementLvl,
                                                                                    refType,
                                                                                    data,
                                                                                    Xrange,
                                                                                    Yrange )
    
    PT_infos                           = get_phase_diagram_information(npoints,dtb,diagType,solver,bulk_L, bulk_R, oxi, fixT, fixP,bufferType, bufferN1, bufferN2,PTpath,watsat,watsat_val)
                                                              
    data_plot, annotations,txt_list = get_diagram_labels(   Out_XY,
                                                            Hash_XY,
                                                            refType,
                                                            data,
                                                            PT_infos;
                                                            field_size = field_size )
                                           
    layout[:annotations] = annotations 
    layout[:title] = attr(
        text    = customTitle,
        x       = 0.5,
        xanchor = "center",
        yanchor = "top"
    )
    if set_white == "true"
        colorm = set_min_to_white(colorm; reverseColorMap)
    end
    data_plot[1] = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
                            connectgaps     = true,
                            zsmooth         =  smooth,
                            type            = "heatmap",
                            colorscale      = colorm,
                            # colorbar_title  = fieldname,
                            reversescale    = reverseColorMap,
                            hoverinfo       = "skip",
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        exponentformat  = "e" ,
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)
    n       = 2^(sub + refLvl + addedRefinementLvl)+1
    xvals   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    yvals   = range(data.Yrange[1], stop = data.Yrange[2], length = n)
    heat_map_export = heatmap(  x               = xvals,
                                y               = yvals,
                                z               = gridded',
                                zmin            = minColor,
                                zmax            = maxColor,
                                zsmooth         = smooth,
                                connectgaps     = true,
                                type            = "heatmap",
                                colorscale      = colorm,
                                reversescale    = reverseColorMap,
                                # colorbar_title  = fieldname,
                                hoverinfo       = "skip",
                                showlegend      = false,
                                colorbar        = attr(     lenmode         = "fraction",
                                                            len             =  0.75,
                                                            thicknessmode   = "fraction",
                                                            exponentformat  = "e" ,
                                                            tickness        =  0.5,
                                                            x               =  1.005,
                                                            y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)
    hover_lbl = heatmap(    x               = X,
                            y               = Y,
                            z               = X,
                            type            = "heatmap",
                            showscale       = false,
                            opacity         = 0.0,
                            hoverinfo       = "text",
                            showlegend      = false,
                            text            = gridded_info )

    return vcat(data_plot,hover_lbl), layout, npoints, meant, txt_list, heat_map_export

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
                                            sub,        refLvl,
                                            minColor,   maxColor,
                                            smooth,     colorm,     reverseColorMap, set_white,
                                            test                                  )
    global PT_infos, layout, addedRefinementLvl
    if set_white == "true"
        colorm = set_min_to_white(colorm; reverseColorMap)
    end
    # if fieldname == "Variance"
    #     colorm = discretize_colormap(colorm,minColor,maxColor)
    # end
    data_plot[1] = heatmap( x               =  X,
                            y               =  Y,
                            z               =  gridded,
                            zmin            =  minColor,
                            zmax            =  maxColor,
                            zsmooth         =  smooth,
                            connectgaps     = true,
                            type            = "heatmap",
                            colorscale      =  colorm,
                            # colorbar_title  =  fieldname,
                            reversescale    =  reverseColorMap,
                            hoverinfo       = "skip",
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        exponentformat  = "e" ,
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)


    n       = 2^(sub + refLvl + addedRefinementLvl)+1
    xvals   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    yvals   = range(data.Yrange[1], stop = data.Yrange[2], length = n)
    heat_map_export = heatmap(  x               = xvals,
                                y               = yvals,
                                z               = gridded',
                                zmin            =  minColor,
                                zmax            =  maxColor,
                                zsmooth         =  smooth,
                                connectgaps     = true,
                                type            = "heatmap",
                                colorscale      =  colorm,
                                # colorbar_title  =  fieldname,
                                reversescale    =  reverseColorMap,
                                hoverinfo       = "skip",
                                colorbar        = attr(     lenmode         = "fraction",
                                                            len             =  0.75,
                                                            thicknessmode   = "fraction",
                                                            exponentformat  = "e" ,
                                                            tickness        =  0.5,
                                                            x               =  1.005,
                                                            y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)
    return data_plot,layout, heat_map_export
end


"""
   This function creates a binary mask, then contours it to retriev the phase boundary

"""
function get_phase_boundary(    ph     :: String,
                                n      :: Int,  
                                phase  :: Vector{Int},
                                mask   :: Matrix{Int},
                                data,
                                Out_XY )

    np_grid = length(data.points)

    for i=1:np_grid
        phase[i] = 0;
        if (ph in Out_XY[i].ph)
            phase[i] = 1;
        end
    end

    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    for k=1:np_grid
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        mask[ii,jj]     = phase[k] 
    end

    for i=1:length(data.cells)
        cell   = data.cells[i]
        tmp    = phase[cell[1]]

        ii_min = compute_index(data.points[cell[2]][1], data.Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], data.Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], data.Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            mask[ii, jj_ix] = tmp
        end

        jj_min = compute_index(data.points[cell[1]][2], data.Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], data.Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1],  data.Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            mask[ii_ix, jj] = tmp
        end

        jj_min = compute_index(data.points[cell[4]][2], data.Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], data.Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1],  data.Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            mask[ii_ix, jj] = tmp
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], data.Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], data.Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], data.Yrange[1], dy)

        for ii in ii_min+1:ii_max-1
            mask[ii, jj_ix] = tmp
            for jj in jj_min+1:jj_max-1
                mask[ii, jj] = tmp
            end
        end
    end

    phase_boundary    = CTR.contours(x,y,mask,[0.5])
    # phase_boundary  = cl.contours[1].lines[1].vertices

    return phase_boundary
end


"""
    show_hide_reaction_lines(    xtitle,     ytitle,     grid,  
                                    Xrange,     Yrange,     fieldname,
                                    dtb,
                                    smooth,     colorm,     reverseColorMap,
                                    test                                  )
    Shows/hides the grid
"""
function  show_hide_reaction_lines(     sub, 
                                        refLvl, 
                                        Xrange, 
                                        Yrange  )

    global data, Hash_XY, Out_XY, addedRefinementLvl, phase_infos

    n           = 2^(sub + refLvl+ addedRefinementLvl)+1
    phase       = Vector{Int}(undef,length(data.points));
    mask        = Matrix{Int}(undef,n,n);

    phase_contours = ()
    for ph in phase_infos.act_ss
        phase_boundary = get_phase_boundary(    ph,
                                                n,
                                                phase,
                                                mask,
                                                data,
                                                Out_XY )

        phase_contours = (phase_contours..., (ph, phase_boundary))
    end

    for ph in phase_infos.act_pp
        phase_boundary = get_phase_boundary(    ph,
                                                n,
                                                phase,
                                                mask,
                                                data,
                                                Out_XY )

        phase_contours = (phase_contours..., (ph, phase_boundary))
    end


    data_contour      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,length(phase_contours));

    n_ss = length(phase_infos.act_ss)
    n_pp = length(phase_infos.act_pp)

    for i=1:(n_ss+n_pp)
        if i <= n_ss
            opt = phase_infos.reac_ss[i]
        else
            opt = phase_infos.reac_pp[i - n_ss]
        end

        x       = []
        y       = []

        for j=1:length(phase_contours[i][2].contours[1].lines)
            ctr     = phase_contours[i][2].contours[1].lines[j].vertices
            x       = vcat(x, [ctr[k][1] for k in 1:size(ctr,1)],missing)
            y       = vcat(y, [ctr[k][2] for k in 1:size(ctr,1)],missing)
        end

        data_contour[i] = scatter(      x           = x, 
                                        y           = y, 
                                        hoverinfo   = "skip",
                                        mode        = "markers+lines",
                                        name        = opt[5],
                                        showscale   = false,
                                        showlegend  = false,
                                        marker      = attr( size    = 10,  # Set the marker size here
                                                            color   = "rgba(0,0,0,0)" ),
                                        line        = attr( color   = opt[3], 
                                                            dash    = opt[1],
                                                            width   = opt[2])                )
    end

    return data_contour

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

    np             = length(data.cells)
    grid_plot      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, np);
    for i = 1:np

        grid_plot[i] = scatter(     x           = [data.points[data.cells[i][j]][1] for j=1:4],
                                    y           = [data.points[data.cells[i][j]][2] for j=1:4],
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
    update_displayed_field_phaseDiagram(   xtitle,     ytitle,     
                                                    Xrange,     Yrange,     fieldname,
                                                    dtb,        oxi,
                                                    sub,        refLvl,
                                                    smooth,     colorm,     reverseColorMap,
                                                    test                                  )
    Updates the field displayed
"""
function  update_displayed_field_phaseDiagram(   xtitle,     ytitle,     
                                                Xrange,     Yrange,     fieldname,
                                                dtb,        oxi,
                                                sub,        refLvl,
                                                smooth,     colorm,     reverseColorMap, set_white,
                                                test,       refType                                  )

    global data, Out_XY, data_plot, gridded, gridded_info, X, Y, addedRefinementLvl, PT_infos, layout

    gridded, X, Y, npoints, meant = get_gridded_map_no_lbl(     fieldname,
                                                                "major",
                                                                "none",
                                                                "none",
                                                                oxi,
                                                                Out_XY,
                                                                nothing,
                                                                Hash_XY,
                                                                sub,
                                                                refLvl + addedRefinementLvl,
                                                                refType,
                                                                data,
                                                                Xrange,
                                                                Yrange )

    if set_white == "true"
        colorm = set_min_to_white(colorm; reverseColorMap)
    end
    data_plot[1] = heatmap( x               = X,
                            y               = Y,
                            z               = gridded,
                            zsmooth         = smooth,
                            connectgaps     = true,
                            type            = "heatmap",
                            colorscale      = colorm,
                            # colorbar_title  = fieldname,
                            reversescale    = reverseColorMap,
                            hoverinfo       = "skip",
                            # hoverinfo       = "text",
                            # text            = gridded_info,
                            colorbar        = attr(     lenmode         = "fraction",
                                                        len             =  0.75,
                                                        thicknessmode   = "fraction",
                                                        exponentformat  = "e" ,
                                                        tickness        =  0.5,
                                                        x               =  1.005,
                                                        y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)


    n       = 2^(sub + refLvl + addedRefinementLvl)+1
    xvals   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    yvals   = range(data.Yrange[1], stop = data.Yrange[2], length = n)
    heat_map_export = heatmap(  x               = xvals,
                                y               = yvals,
                                z               = gridded',
                                zsmooth         = smooth,
                                connectgaps     = true,
                                type            = "heatmap",
                                colorscale      = colorm,
                                # colorbar_title  = fieldname,
                                reversescale    = reverseColorMap,
                                hoverinfo       = "skip",
                                # hoverinfo       = "text",
                                # text            = gridded_info,
                                colorbar        = attr(     lenmode         = "fraction",
                                                            len             =  0.75,
                                                            thicknessmode   = "fraction",
                                                            exponentformat  = "e" ,
                                                            tickness        =  0.5,
                                                            x               =  1.005,
                                                            y               =  0.5,
                                                                title = attr(   text = fieldname,
                                                                                side = "right")         ),)

    return data_plot,layout, heat_map_export
end

"""

    Initiatize global variable storing isopleths information
"""
function initialize_g_isopleth(; n_iso_max = 32)
    global data_isopleth

    status    = zeros(Int64,n_iso_max)
    active    = []
    hidden    = []
    isoP      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap
    isoPexp   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap
    isoT      = Vector{CTR.ContourCollection{CTR.ContourLevel{Tuple{Float64, Float64}, Float64}}}(undef, n_iso_max); # + 1 to store the heatmap
    isoCap    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap

    for i=1:n_iso_max
        isoP[i]     = contour()
        isoPexp[i]  = contour()
        isoCap[i]   = scatter()
    end

    label     = Vector{String}(undef,n_iso_max)
    value     = Vector{Int64}(undef,n_iso_max)

    data_isopleth = isopleth_data(  0, n_iso_max, status, active, hidden, 
                                    isoP, isoPexp, isoT, isoCap,
                                    label, value)

    
    return data_isopleth
end


"""

    Initiatize global variable storing isopleths information
"""
function initialize_g_isopleth_te(; n_iso_max = 32)
    global data_isopleth_te

    status    = zeros(Int64,n_iso_max)
    active    = []
    hidden    = []
    isoP      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap
    isoPexp   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap
    isoT      = Vector{CTR.ContourCollection{CTR.ContourLevel{Tuple{Float64, Float64}, Float64}}}(undef, n_iso_max); # + 1 to store the heatmap
    isoCap    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_iso_max); # + 1 to store the heatmap

    for i=1:n_iso_max
        isoP[i] = contour()
        isoPexp[i]  = contour()
        isoCap[i] = scatter()
    end

    label     = Vector{String}(undef,n_iso_max)
    value     = Vector{Int64}(undef,n_iso_max)

    data_isopleth_te = isopleth_data(   0, n_iso_max,
                                        status, active, hidden, isoP, isoPexp, isoT, isoCap,
                                        label, value)

    
    return data_isopleth_te
end

"""

    add_isopleth_phaseDiagram
"""
function add_isopleth_phaseDiagram(         Xrange,     Yrange, 
                                            sub,        refLvl,
                                            dtb,        oxi,
                                            isopleths,  phase,      ss,     em,   ox,  of,     ot,  sys,   rmf,  calc, cust, calc_sf, calc_ox, cust_sf, cust_ox,
                                            isoLineStyle,   isoLineWidth, isoColorLine,           isoLabelSize,       
                                            minIso,     stepIso,    maxIso      )

    isoLabelSize    = Int64(isoLabelSize)

    if (phase == "ss" && ot == "mode") || (phase == "pp")
        if sys == "mol"
            mod     = "ph_frac"
            name    = ss*"_frac_[mol]"
        elseif  sys == "vol"
            mod     = "ph_frac_vol"
            name    = ss*"_frac_[vol]"
        else 
            mod     = "ph_frac_wt"
            name    = ss*"_frac_[wt]"
        end
        em      = ""

    elseif (phase == "ss" && ot == "emMode")

        if sys == "mol"
            mod     = "em_frac"
            name    = ss*"_"*em*"_frac_[mol]"
        else 
            mod     = "ph_frac_wt"
            name    = ss*"_"*em*"_frac_[wt]"
        end
    elseif (phase == "ss" && ot == "oxComp")
        if sys == "vol" 
            sys_cor = "wt"
            println("Warning: for oxides, the system unit has to be mol or wt. Setting value to wt%")
        else 
            sys_cor = sys
        end
        if sys_cor == "mol"
            mod     = "ox_comp"
            name    = ss*"_"*ox*"_frac_[mol]"
        else 
            mod     = "ox_comp_wt"
            name    = ss*"_"*ox*"_frac_[wt]"
        end
    elseif (phase == "ss" && ot == "MgNum")
        mod     = "ss_MgNum"
        em      = ""
        name    = ss*"_Mg#"
    elseif (phase == "ss" && ot == "calc")
        mod     = "ss_calc"
        em      = ""
        if cust != "none"
            name    = ss*"_["*cust*"]"
        else
            name    = ss*"_["*calc*"]"
        end
    elseif (phase == "ss" && ot == "calc_sf")
        mod     = "ss_calc_sf"
        if cust_sf != "none"
            name    = ss*"_["*cust_sf*"]"
        else
            name    = ss*"_["*calc_sf*"]"
        end
    elseif (phase == "ss" && ot == "calc_ox")
        if sys == "vol" 
            sys_cor = "wt"
            println("Warning: for oxides, the system unit has to be mol or wt. Setting value to wt%")
        else
            sys_cor = sys
        end
        mod         = "ss_calc_ox_"*sys_cor
        if cust_ox != "none"
            name    = ss*"_["*cust_ox*"]"*"_"*sys_cor
        else
            name    = ss*"_["*calc_ox*"]"*"_"*sys_cor
        end

    elseif (phase == "of")
        em      = ""
        ss      = ""
        mod     = "of_mod"
        name    = of
    else
        println("Wrong combination, needs debugging...")
    end

    global data_isopleth, nIsopleths, data, Out_XY, data_plot, X, Y, addedRefinementLvl

    gridded, X, Y = get_isopleth_map(   mod, ss, em, ox, of, ot, calc, calc_sf, calc_ox, rmf, 
                                        oxi,
                                        Out_XY,
                                        sub,
                                        refLvl + addedRefinementLvl,
                                        data,
                                        Xrange,
                                        Yrange )

    data_isopleth.n_iso += 1

    data_isopleth.isoT[data_isopleth.n_iso] = CTR.contours(X[1:size(gridded,1)],Y[1:size(gridded,1):end],Float64.(coalesce.(gridded, NaN)),collect(range(minIso, maxIso, Int(floor((maxIso-minIso)/stepIso)+1) )))
    data_isopleth.isoP[data_isopleth.n_iso] = contour(  x                   = X,
                                                        y                   = Y,
                                                        z                   = gridded,
                                                        contours_coloring   = "lines",
                                                        colorscale          = [[0, isoColorLine], [1, isoColorLine]],
                                                        # connectgaps         = false,
                                                        contours_start      = minIso,
                                                        contours_end        = maxIso,
                                                        contours_size       = stepIso,
                                                        line_width          = isoLineWidth,
                                                        line_dash           = isoLineStyle,
                                                        showscale           = false,
                                                        hoverinfo           = "skip",
                                                        contours            =  attr(    coloring    = "lines",
                                                                                        showlabels  = true,
                                                                                        labelfont   = attr( size    = isoLabelSize,
                                                                                                            color   = isoColorLine,  )
                                                        )
                                                    );
    n       = 2^(sub + refLvl + addedRefinementLvl)+1
    xvals   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    yvals   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    data_isopleth.isoPexp[data_isopleth.n_iso] = contour(   x                   = xvals,
                                                            y                   = yvals,
                                                            z                   = gridded',
                                                            contours_coloring   = "lines",
                                                            colorscale          = [[0, isoColorLine], [1, isoColorLine]],
                                                            # connectgaps         = false,
                                                            contours_start      = minIso,
                                                            contours_end        = maxIso,
                                                            contours_size       = stepIso,
                                                            line_width          = isoLineWidth,
                                                            line_dash           = isoLineStyle,
                                                            showscale           = false,
                                                            hoverinfo           = "skip",
                                                            contours            =  attr(    coloring    = "lines",
                                                                                            showlabels  = true,
                                                                                            labelfont   = attr( size    = isoLabelSize,
                                                                                                                color   = isoColorLine,  )
                                                            )
                                                        );


    data_isopleth.isoCap[data_isopleth.n_iso]   = scatter(  x           = [nothing],
                                                            y           = [nothing],
                                                            mode        = "lines",
                                                            line        =  attr(color=isoColorLine,dash=isoLineStyle,width=isoLineWidth),
                                                            name        =  name,
                                                            showlegend  =  true);

    data_isopleth.status[data_isopleth.n_iso]   = 1
    data_isopleth.label[data_isopleth.n_iso]    = name
    data_isopleth.value[data_isopleth.n_iso]    = data_isopleth.n_iso
    data_isopleth.active                        = findall(data_isopleth.status .== 1)
    n_act                                       = length(data_isopleth.active)

    isopleths = [Dict("label" => data_isopleth.label[data_isopleth.active[i]], "value" => data_isopleth.value[data_isopleth.active[i]])
                        for i=1:n_act]

    return data_isopleth, isopleths

end

function hide_single_isopleth_phaseDiagram(isoplethsID)
    global data_isopleth

    # data_isopleth.n_iso                -= 1      
    data_isopleth.status[isoplethsID]   = 2;

    # deals with the activte dropdown menu
    data_isopleth.active                = findall(data_isopleth.status .== 1)
    n_act                               = length(data_isopleth.active)
    isopleths = [Dict("label" => data_isopleth.label[data_isopleth.active[i]], "value" => data_isopleth.value[data_isopleth.active[i]])
                    for i=1:n_act]

    # deals with the hidden dropdown menu
    data_isopleth.hidden                = findall(data_isopleth.status .== 2)
    n_act                               = length(data_isopleth.hidden)
    isoplethsHid = [Dict("label" => data_isopleth.label[data_isopleth.hidden[i]], "value" => data_isopleth.value[data_isopleth.hidden[i]])
                    for i=1:n_act]              

    return data_isopleth, isopleths, isoplethsHid
end

function show_single_isopleth_phaseDiagram(isoplethsHidID)
    global data_isopleth

    # data_isopleth.n_iso                -= 1      
    data_isopleth.status[isoplethsHidID]   = 1;

    # deals with the activte dropdown menu
    data_isopleth.active                = findall(data_isopleth.status .== 1)
    n_act                               = length(data_isopleth.active)
    isopleths = [Dict("label" => data_isopleth.label[data_isopleth.active[i]], "value" => data_isopleth.value[data_isopleth.active[i]])
                    for i=1:n_act]

    # deals with the hidden dropdown menu
    data_isopleth.hidden                = findall(data_isopleth.status .== 2)
    n_act                               = length(data_isopleth.hidden)
    isoplethsHid = [Dict("label" => data_isopleth.label[data_isopleth.hidden[i]], "value" => data_isopleth.value[data_isopleth.hidden[i]])
                    for i=1:n_act]              

    return data_isopleth, isopleths, isoplethsHid
end


function remove_single_isopleth_phaseDiagram(isoplethsID)
    global data_isopleth

    data_isopleth.n_iso                -= 1      
    data_isopleth.status[isoplethsID]   = 0;
    data_isopleth.isoP[isoplethsID]     = contour()
    data_isopleth.isoCap[isoplethsID]   = scatter()
    data_isopleth.label[isoplethsID]    = ""
    data_isopleth.value[isoplethsID]    = 0
    data_isopleth.active                = findall(data_isopleth.status .== 1)
    n_act                               = length(data_isopleth.active)
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
        data_isopleth.isoCap[i] = scatter()
    end
    data_isopleth.status   .= 0
    data_isopleth.active   .= 0
    data_isopleth.hidden   .= 0

    # clear isopleth dropdown menu
    isopleths = []        
    isoplethsHid = []       

    return data_isopleth, isopleths, isoplethsHid, data_plot
end


function _draw_path_point_label(diagType, id)
    global Out_XY, data
    P = round(display_pressure(Out_XY[id].P_kbar), digits=2)
    T = round(Out_XY[id].T_C,    digits=2)
    if (diagType == "px" || diagType == "tx") && @isdefined(data) && id <= length(data.points)
        X = round(data.points[id][1], digits=4)
        return diagType == "px" ? "X=$(X); P=$(P)" : "X=$(X); T=$(T)"
    else
        return "T=$(T); P=$(P)"
    end
end

function draw_path_table_data(diagType, path_ids)
    global Out_XY, data

    p_col = "P[$(pressure_unit_label())]"

    if isempty(path_ids)
        if diagType == "px"
            cols = [Dict("id"=>"#","name"=>"#"), Dict("id"=>"X","name"=>"X"), Dict("id"=>p_col,"name"=>p_col)]
        elseif diagType == "tx"
            cols = [Dict("id"=>"#","name"=>"#"), Dict("id"=>"X","name"=>"X"), Dict("id"=>"T[°C]","name"=>"T[°C]")]
        else
            cols = [Dict("id"=>"#","name"=>"#"), Dict("id"=>p_col,"name"=>p_col), Dict("id"=>"T[°C]","name"=>"T[°C]")]
        end
        return cols, []
    end

    if diagType == "px"
        cols = [Dict("id"=>"#","name"=>"#"), Dict("id"=>"X","name"=>"X"), Dict("id"=>p_col,"name"=>p_col)]
        rows = [Dict("#"=>k, "X"=>(@isdefined(data) && id<=length(data.points) ? round(data.points[id][1],digits=4) : "—"),
                     p_col=>round(display_pressure(Out_XY[id].P_kbar), digits=3)) for (k,id) in enumerate(path_ids)]
    elseif diagType == "tx"
        cols = [Dict("id"=>"#","name"=>"#"), Dict("id"=>"X","name"=>"X"), Dict("id"=>"T[°C]","name"=>"T[°C]")]
        rows = [Dict("#"=>k, "X"=>(@isdefined(data) && id<=length(data.points) ? round(data.points[id][1],digits=4) : "—"),
                     "T[°C]"=>round(Out_XY[id].T_C, digits=3)) for (k,id) in enumerate(path_ids)]
    else
        cols = [Dict("id"=>"#","name"=>"#"), Dict("id"=>p_col,"name"=>p_col), Dict("id"=>"T[°C]","name"=>"T[°C]")]
        rows = [Dict("#"=>k, p_col=>round(display_pressure(Out_XY[id].P_kbar), digits=3),
                     "T[°C]"=>round(Out_XY[id].T_C, digits=3)) for (k,id) in enumerate(path_ids)]
    end

    return cols, rows
end

function get_draw_path_plot(diagType, sysunit, path_ids)
    global Out_XY

    n_tot = length(path_ids)
    if n_tot == 0
        return GenericTrace[], []
    end

    ph_names = Vector{String}()
    for id in path_ids
        for ph in Out_XY[id].ph
            if !(ph in ph_names)
                push!(ph_names, ph)
            end
        end
    end
    ph_names = sort(ph_names)
    n_ph     = length(ph_names)

    x = Vector{String}(undef, n_tot)
    Y = zeros(Float64, n_ph, n_tot)

    for (k, id) in enumerate(path_ids)
        x[k] = _draw_path_point_label(diagType, id)
        for (i, ph) in enumerate(ph_names)
            idx = findall(Out_XY[id].ph .== ph)
            if sysunit == "mol"
                if ~isempty(idx); Y[i,k] = sum(Out_XY[id].ph_frac[idx])     * 100.0; end
            elseif sysunit == "wt"
                if ~isempty(idx); Y[i,k] = sum(Out_XY[id].ph_frac_wt[idx])  * 100.0; end
            elseif sysunit == "vol"
                if ~isempty(idx); Y[i,k] = sum(Out_XY[id].ph_frac_vol[idx]) * 100.0; end
            end
        end
    end

    for k in 1:n_tot
        s = sum(Y[:, k])
        if s > 0.0; Y[:, k] ./= s / 100.0; end
    end

    traces = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph)
    for (i, ph) in enumerate(ph_names)
        color = haskey(AppData.mineral_style[1], ph) ? AppData.mineral_style[1][ph][1] : "grey"
        traces[i] = scatter(;
            x          = x,
            y          = Y[i,:],
            name       = display_ph_name(ph),
            stackgroup = "one",
            mode       = "lines",
            line       = attr(width=0.5, color=color)
        )
    end

    phase_list = [Dict("label" => "  "*display_ph_name(ph_names[i]), "value" => ph_names[i]) for i in 1:n_ph]

    return traces, phase_list
end


# ─── Thermobarometric intersection helpers ────────────────────────────────────

function _eval_thermobar_formula(formula_str, oxide_names, oxide_vals)
    pairs = sort(collect(zip(oxide_names, oxide_vals)), by = x -> -length(x[1]))
    expr  = formula_str
    for (name, val) in pairs
        expr = replace(expr, name => string(val))
    end
    try
        return Float64(eval(Meta.parse(expr)))
    catch
        return NaN
    end
end

function _get_thermobar_gridded(ph, formula_str, comp_unit, sub, refLvl)
    global Out_XY, data, addedRefinementLvl

    np    = length(data.points)
    field = Vector{Union{Float64,Missing}}(missing, np)

    for i in 1:np
        ph_list = Out_XY[i].ph
        idx     = findfirst(ph_list .== ph)
        if isnothing(idx)
            field[i] = missing
            continue
        end
        n_SS = Out_XY[i].n_SS
        if idx <= n_SS
            if comp_unit == "mol"
                comp = Out_XY[i].SS_vec[idx].Comp
            elseif comp_unit == "apfu"
                comp = Out_XY[i].SS_vec[idx].Comp_apfu
            else
                comp = Out_XY[i].SS_vec[idx].Comp_wt
            end
        else
            pp_idx = idx - n_SS
            if comp_unit == "mol"
                comp = Out_XY[i].PP_vec[pp_idx].Comp
            elseif comp_unit == "apfu"
                comp = Out_XY[i].PP_vec[pp_idx].Comp_apfu
            else
                comp = Out_XY[i].PP_vec[pp_idx].Comp_wt
            end
        end
        val     = _eval_thermobar_formula(formula_str, Out_XY[i].oxides, comp)
        field[i] = isnan(val) ? missing : val
    end

    Xrange = data.Xrange
    Yrange = data.Yrange
    n      = 2^(sub + refLvl + addedRefinementLvl) + 1
    dx     = (Xrange[2] - Xrange[1]) / (n - 1)
    dy     = (Yrange[2] - Yrange[1]) / (n - 1)
    x      = range(Xrange[1], stop = Xrange[2], length = n)
    y      = range(Yrange[1], stop = Yrange[2], length = n)
    X      = repeat(x,  n)[:]
    Y      = repeat(y', n)[:]

    gridded = Matrix{Union{Float64,Missing}}(missing, n, n)

    for k in 1:np
        ii = compute_index(data.points[k][1], Xrange[1], dx)
        jj = compute_index(data.points[k][2], Yrange[1], dy)
        gridded[ii, jj] = field[k]
    end

    for i in 1:length(data.cells)
        cell = data.cells[i]

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii in ii_min+1:ii_max-1
            f = (ii - ii_min) / (ii_max - ii_min)
            gridded[ii, jj_ix] = field[cell[2]] * (1.0 - f) + field[cell[3]] * f
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix  = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            f = (jj - jj_min) / (jj_max - jj_min)
            gridded[ii_ix, jj] = field[cell[1]] * (1.0 - f) + field[cell[2]] * f
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix  = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            f = (jj - jj_min) / (jj_max - jj_min)
            gridded[ii_ix, jj] = field[cell[4]] * (1.0 - f) + field[cell[3]] * f
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)
        for ii in ii_min+1:ii_max-1
            f   = (ii - ii_min) / (ii_max - ii_min)
            bot = field[cell[1]] * (1.0 - f) + field[cell[4]] * f
            top = field[cell[2]] * (1.0 - f) + field[cell[3]] * f
            gridded[ii, jj_ix] = bot
            for jj in jj_min+1:jj_max-1
                g = (jj - jj_min) / (jj_max - jj_min)
                gridded[ii, jj] = bot * (1.0 - g) + top * g
            end
        end
    end

    return gridded, X, Y
end

function get_thermobar_contour_plot(formula_store, color_store, comp_unit, csv_data, sub, refLvl)
    global Out_XY, data, AppData

    traces = GenericTrace{Dict{Symbol,Any}}[]
    stats  = Vector{Dict{String,Any}}()

    if !@isdefined(Out_XY) || isempty(Out_XY) || !@isdefined(data)
        return traces, stats
    end

    diag_oxides = Out_XY[1].oxides

    # Normalise JSON3 types to plain Julia so Dict key lookups and string comparisons work correctly
    fs = isnothing(formula_store) ? Vector{Dict{String,Any}}() :
         [Dict{String,Any}(String(k) => String(v) for (k,v) in pairs(d)) for d in formula_store]
    csv = isnothing(csv_data) ? Vector{Dict{String,Any}}() :
          [Dict{String,Any}(String(k) => v for (k,v) in pairs(d)) for d in csv_data]

    # Build once-per-(phase+formula) gridded fields
    seen_fields = Dict{Tuple{String,String}, Tuple}()

    added_legend = Set{String}()

    dash_cycle   = ["solid", "dash", "dot", "dashdot", "longdash"]
    phase_fi     = Dict{String,Int}()   # per-phase formula counter

    for (fi, fdict) in enumerate(fs)
        ph      = fdict["phase"]
        formula = fdict["formula"]
        label   = fdict["label"]
        key     = (ph, formula)
        color   = get(color_store, ph, haskey(AppData.mineral_style[1], ph) ? AppData.mineral_style[1][ph][1] : "#808080")
        # first formula for this phase → solid; subsequent → cycle dashed styles
        phase_fi[ph] = get(phase_fi, ph, 0) + 1
        dash = dash_cycle[mod1(phase_fi[ph], length(dash_cycle))]

        if !haskey(seen_fields, key)
            try
                gridded, X, Y = _get_thermobar_gridded(ph, formula, comp_unit, sub, refLvl)
                seen_fields[key] = (gridded, X, Y)
            catch
                continue
            end
        end
        gridded, X, Y = seen_fields[key]
        g_float = Float64.(coalesce.(gridded, NaN))

        target_vals = Float64[]

        for (si, sample) in enumerate(csv)
            sample_ph = get(sample, "mineral_name", "")
            if sample_ph != ph
                continue
            end
            ox_vals = [begin v = get(sample, ox, NaN); (v isa Number && isfinite(Float64(v))) ? Float64(v) : NaN end for ox in diag_oxides]
            target  = _eval_thermobar_formula(formula, diag_oxides, ox_vals)
            if isnan(target) || ismissing(target)
                continue
            end
            push!(target_vals, target)

            local cont
            try
                cont = CTR.contours(X[1:size(gridded,1)], Y[1:size(gridded,1):end], g_float, [target])
            catch
                continue
            end
            if isempty(cont.contours) || isempty(cont.contours[1].lines)
                continue
            end

            legend_key = "$(ph): $(label)"
            show_leg   = !(legend_key in added_legend)

            for (li, line) in enumerate(cont.contours[1].lines)
                lx_raw = [v[1] for v in line.vertices]
                ly_raw = [v[2] for v in line.vertices]
                lx = Union{Float64,Nothing}[isnan(v) ? nothing : v for v in lx_raw]
                ly = Union{Float64,Nothing}[isnan(v) ? nothing : v for v in ly_raw]
                push!(lx, nothing)
                push!(ly, nothing)
                push!(traces, scatter(
                    x           = lx,
                    y           = ly,
                    mode        = "lines",
                    line        = attr(color=color, width=1.5, dash=dash),
                    name        = legend_key,
                    legendgroup = legend_key,
                    showlegend  = show_leg,
                    uid         = "tb-$(fi)-$(ph)-$(si)-$(li)",
                    hovertext   = "$(ph) | $(label) = $(round(target, digits=4))",
                    hoverinfo   = "text",
                ))
                show_leg && push!(added_legend, legend_key)
                show_leg = false
            end
        end

        # Accumulate stats per (phase, formula)
        if !isempty(target_vals)
            n   = length(target_vals)
            μ   = sum(target_vals) / n
            σ   = n > 1 ? sqrt(sum((target_vals .- μ).^2) / (n - 1)) : 0.0
            push!(stats, Dict(
                "phase"   => ph,
                "formula" => label,
                "n"       => n,
                "mean"    => round(μ, digits=4),
                "std"     => round(σ, digits=4),
            ))
        end
    end

    return traces, stats
end

# ─────────────────────────────────────────────────────────────────────────────

function export_contours_to_txt(cont, name, filename)
    open(filename, "w") do io
        println(io, "isocontour: $name")
        for i=1:length(cont.contours)
            println(io, "level: $(cont.contours[i].level)")
            println(io, "Number of lines: $(length(cont.contours[i].lines))")
            l = 0
            for line in cont.contours[i].lines
                l += 1
                println(io, "Line: $(l); $(length(line.vertices)) vertices:")

                x = [line.vertices[j][1] for j in 1:length(line.vertices)]
                y = [line.vertices[j][2] for j in 1:length(line.vertices)]

                println(io, "x = [" * join(x, ", ") * "]")
                println(io, "y = [" * join(y, ", ") * "]")
            end
            println(io) # blank line between contours
        end
    end
end