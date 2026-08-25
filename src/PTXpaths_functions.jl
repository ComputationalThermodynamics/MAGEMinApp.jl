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
    Retrieve the per-point data driving the classification-diagram marker color, plus its axis label
"""
function get_classification_color_data(field::String)
    global Out_PTX

    n_tot   = length(Out_PTX)
    vals    = Vector{Union{Float64,Missing}}(undef, (n_tot+1)) .= missing

    if field == "point"
        for j=1:n_tot
            vals[j] = Float64(j)
        end
        label = "Point number"
    elseif field == "pressure"
        for j=1:n_tot
            vals[j] = Out_PTX[j].P_kbar
        end
        label = "Pressure [kbar]"
    elseif field == "liq_mol" || field == "liq_wt" || field == "liq_vol"
        for j=1:n_tot
            id  = findall(Out_PTX[j].ph .== "liq")
            if ~isempty(id)
                vals[j] = field == "liq_mol" ? Out_PTX[j].ph_frac[id[1]]*100.0 :
                          field == "liq_wt"  ? Out_PTX[j].ph_frac_wt[id[1]]*100.0 :
                                                Out_PTX[j].ph_frac_vol[id[1]]*100.0
            end
        end
        label = field == "liq_mol" ? "liq [mol%]" : field == "liq_wt" ? "liq [wt%]" : "liq [vol%]"
    else
        for j=1:n_tot
            vals[j] = Out_PTX[j].T_C
        end
        label = "Temperature [°C]"
    end

    return vals, label
end

"""
    Retrieve AFM diagram
"""
function get_AFM(field::String, colorscale)

    global Out_PTX;

    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_tot   = length(Out_PTX)

    liq_afm        = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))    .= missing
    liq_wt          = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing

    color_data, color_label = get_classification_color_data(field)

    for j=1:n_tot
        id      = findall(Out_PTX[j].ph .== "liq")
        if ~isempty(id)
            liq_afm[:,j] = Out_PTX[j].SS_vec[id[1]].Comp_wt .*100.0
            liq_wt[j]    = Out_PTX[j].ph_frac_wt[id[1]]
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
        showlegend  = false,
        marker  = attr(     size        = liq_wt .*20.0 .+ 2.0,
                            color       = color_data,
                            colorscale  = colorscale,
                            showscale   = true,
                            colorbar    = attr( title     = attr(text=color_label, side="right"),
                                                thickness = 12,
                                                len       = 0.38,
                                                x         = 0.82,
                                                y         = 0.68 ),
                            line        = attr( width = 0.75,
                                                color = "black" )    ),
        name    = "Sample Points"
    )

    size_legend = [scatterternary(  a = [nothing], b = [nothing], c = [nothing],
                            mode        = "markers",
                            showlegend  = true,
                            name        = lbl,
                            marker      = attr( size = sz, color = "#888888",
                                                line = attr(width=0.75, color="black") ))
                    for (sz, lbl) in ((2.0, "0%"), (12.0, "50%"), (22.0, "100%"))]

    layout_afm = Layout(
        title= attr(
            text    = "AFM Diagram [wt%]",
            x       = 0.2,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=50, b=16, t=40),
        legend      = attr( x = 0.82, y = 0.28, xanchor = "left", yanchor = "top",
                            title = attr(text="Marker size<br>(melt fraction)"),
                            bgcolor = "rgba(255,255,255,0.9)", bordercolor = "#ccc", borderwidth = 1 ),
        ternary=attr(
            domain  = attr(x=[0.0, 0.80], y=[0.0, 1.0]),
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
        ),
        height      = 400,
        paper_bgcolor = "#FFF",
    )

    return vcat([afm], size_legend), layout_afm
end



"""
    Retrieve TAS diagram
"""
function get_TAS_diagram(phases,title,field::String,colorscale)

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


    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_tot   = length(Out_PTX)

    liq_tas         = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))      .= missing

    color_data, color_label = get_classification_color_data(field)

    for j=1:n_tot
        id      = findall(Out_PTX[j].ph .== "liq")
        if ~isempty(id)
            liq_tas[:,j] = Out_PTX[j].SS_vec[id[1]].Comp_wt .*100.0
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
                            opacity     = 0.8,
                            showlegend  = false,
                            marker      = attr(     size        = fracEvol[:,1].*15.0 .+ 6.0,
                                                    color       = color_data,
                                                    colorscale  = colorscale,
                                                    showscale   = true,
                                                    colorbar    = attr( title     = attr(text=color_label, side="right"),
                                                                        thickness = 12,
                                                                        len       = 0.38,
                                                                        x         = 0.82,
                                                                        y         = 0.68 ),
                                                    line        = attr( width = 0.75,
                                                                        color = "black" )    ))

    for (sz, lbl) in ((6.0, "0%"), (13.5, "50%"), (21.0, "100%"))
        push!(tas, scatter(     x = [nothing], y = [nothing],
                                mode        = "markers",
                                showlegend  = true,
                                name        = lbl,
                                marker      = attr( size = sz, color = "#888888",
                                                    line = attr(width=0.75, color="black") )))
    end

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

    layout_ptx  = Layout(

        title= attr(
            text    = title,
            x       = 0.5,
            y       = 1.10,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=50, b=16, t=24),
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
        legend      = attr( x = 0.82, y = 0.28, xanchor = "left", yanchor = "top",
                            title = attr(text="Marker size<br>(system remaining)"),
                            bgcolor = "rgba(255,255,255,0.9)", bordercolor = "#ccc", borderwidth = 1 ),
        height      = 480,
        xaxis       = attr(
            domain        = [0.0, 0.80],
            fixedrange    = true,
            # showgrid      = false,  # Disable gridlines inside the plot
            # zeroline      = true,   # Show the axis line
            # #zerolinecolor = "black", # Set axis line color to black
            # linecolor     = "black", # Set the bottom axis line color
            # linewidth     = 1       # Set the thickness of the axis line
        ),
        yaxis       = attr(
            fixedrange    = true,
            # showgrid      = false,  # Disable gridlines inside the plot
            # zeroline      = true,   # Show the axis line
            # #zerolinecolor = "black", # Set axis line color to black
            # linecolor     = "black", # Set the left axis line color
            # linewidth     = 1,       # Set the thickness of the axis line
            # range         = [0.0, nothing]
        ),
    )

   
    return tas, layout_ptx
end



"""
    Retrieve TAS diagram
"""
function get_TAS_pluto_diagram(phases,title,field::String,colorscale)

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


    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_tot   = length(Out_PTX)

    liq_tas         = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))      .= missing

    color_data, color_label = get_classification_color_data(field)

    for j=1:n_tot
        id      = findall(Out_PTX[j].ph .== "liq")
        if ~isempty(id)
            liq_tas[:,j] = Out_PTX[j].SS_vec[id[1]].Comp_wt .*100.0
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
                            opacity     = 0.8,
                            showlegend  = false,
                            marker      = attr(     size        = fracEvol[:,1].*15.0 .+ 6.0,
                                                    color       = color_data,
                                                    colorscale  = colorscale,
                                                    showscale   = true,
                                                    colorbar    = attr( title     = attr(text=color_label, side="right"),
                                                                        thickness = 12,
                                                                        len       = 0.38,
                                                                        x         = 0.82,
                                                                        y         = 0.68 ),
                                                    line        = attr( width = 0.75,
                                                                        color = "black" )    ))

    for (sz, lbl) in ((6.0, "0%"), (13.5, "50%"), (21.0, "100%"))
        push!(tas, scatter(     x = [nothing], y = [nothing],
                                mode        = "markers",
                                showlegend  = true,
                                name        = lbl,
                                marker      = attr( size = sz, color = "#888888",
                                                    line = attr(width=0.75, color="black") )))
    end

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

    layout_ptx  = Layout(

        title= attr(
            text    = title,
            x       = 0.5,
            y       = 1.10,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=50, b=16, t=24),
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
        legend      = attr( x = 0.82, y = 0.28, xanchor = "left", yanchor = "top",
                            title = attr(text="Marker size<br>(system remaining)"),
                            bgcolor = "rgba(255,255,255,0.9)", bordercolor = "#ccc", borderwidth = 1 ),
        height      = 480,
        xaxis       = attr(
            domain        = [0.0, 0.80],
            fixedrange    = true,
            # showgrid      = false,  # Disable gridlines inside the plot
            # zeroline      = true,   # Show the axis line
            # #zerolinecolor = "black", # Set axis line color to black
            # linecolor     = "black", # Set the bottom axis line color
            # linewidth     = 1       # Set the thickness of the axis line
        ),
        yaxis       = attr(
            fixedrange    = true,
            # showgrid      = false,  # Disable gridlines inside the plot
            # zeroline      = true,   # Show the axis line
            # #zerolinecolor = "black", # Set axis line color to black
            # linecolor     = "black", # Set the left axis line color
            # linewidth     = 1,       # Set the thickness of the axis line
            # range         = [0.0, nothing]
        ),
    )

   
    return tas, layout_ptx
end




function compute_Tliq(          sysunit, pressure,   tolerance,  bulk_ini,   oxi,    phase_selection,
                                dtb,        dataset,    bufferType, solver,
                                verbose,    bulk,       bufferN,
                                cpx,        limOpx,     limOpxVal       )

    if "liq" in phase_selection 
        
        phase_selection = remove_phases(string_vec_diff_ss(phase_selection,dtb),dtb)

        Tsol        = 600.0;
        Tmax        = 2200.0;
                        
        out = MAGEMin_C.gmin_struct{Float64, Int64}

        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 


        # initialize single thread MAGEMin 
        GC.gc() 
        gv, z_b, DB, splx_data = init_MAGEMin(  dtb;        
                                                verbose     = verbose,
                                                dataset     = dataset,
                                                mbCpx       = mbCpx,
                                                limitCaOpx  = limitCaOpx,
                                                CaOpxLim    = CaOpxLim,
                                                buffer      = bufferType,
                                                solver      = sol    );
        if sysunit == 1
            sys_in = "mol"
        else
            sys_in = "wt"
        end
        gv      =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);

        out     = deepcopy( point_wise_minimization(pressure, Tmax, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
        ref     = out.ph
        nph     = length(out.ph)
        if (nph > 1)
            print("Warning at $Tmax °C, one or several solution phases are stable: $(out.ph)\n")
            print(" - This likely means that one of the oxide of the database $dtb does not enter the melt chemical space...\n")
            print("   ... or fluid is stable, or a buffer is active!\n")
            print(" - The current assemblage at $Tmax °C is therefore taken as a reference for supra-liquidus conditions\n\n")
        end

        n_max       = 32

        a           = Tsol
        b           = Tmax
        n           = 1
        conv        = 0
        n           = 0
        sign_a      = -1

        while n < n_max && conv == 0
            c = (a+b)/2.0

            out     = deepcopy( point_wise_minimization(pressure, c , gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )
            cmp     = setdiff(out.ph,ref)

            if isempty(cmp)
                result = 1;
            else
                result = -1;
            end

            sign_c  = sign(result)

            if abs(b-a) < tolerance
                conv = 1
            else
                if  sign_c == sign_a
                    a = c
                    sign_a = sign_c
                else
                    b = c
                end
                
            end
            n += 1
        end

        LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))

        Tliq  = string( round((a+b)/2.0,digits=2))
    else
        print("Cannot compute liquidus temperature if liq is removed from the solution phase list\n") 
        Tliq        = ""
    end

    return Tliq
end




function compute_Tsol(          sysunit,    pressure,   tolerance,  bulk_ini,   oxi,    phase_selection,
                                dtb,        dataset,    bufferType, solver,
                                verbose,    bulk,       bufferN,
                                cpx,        limOpx,     limOpxVal       )

    if "liq" in phase_selection 
        
        phase_selection = remove_phases(string_vec_diff_ss(phase_selection,dtb),dtb)

        Tmin        = 500.0;
        Tliq        = 2200.0;
                        
        out = MAGEMin_C.gmin_struct{Float64, Int64}

        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 


        # initialize single thread MAGEMin 
        GC.gc() 
        gv, z_b, DB, splx_data = init_MAGEMin(  dtb;        
                                                verbose     = verbose,
                                                dataset     = dataset,
                                                mbCpx       = mbCpx,
                                                limitCaOpx  = limitCaOpx,
                                                CaOpxLim    = CaOpxLim,
                                                buffer      = bufferType,
                                                solver      = sol    );

                         
        if sysunit == 1
            sys_in = "mol"
        else
            sys_in = "wt"
        end
        gv      =  define_bulk_rock(gv, bulk_ini, oxi, sys_in, dtb);

        out     = deepcopy( point_wise_minimization(pressure, Tliq, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

        n_max       = 32

        a           = Tmin
        b           = Tliq
        n           = 1
        conv        = 0
        n           = 0
        sign_a      = -1

        while n < n_max && conv == 0
            c = (a+b)/2.0

            out     = deepcopy( point_wise_minimization(pressure, c , gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

            if "liq" in out.ph
                result = 1;
            else
                result = -1;
            end

            sign_c  = sign(result)

            if abs(b-a) < tolerance
                conv = 1
            else
                if  sign_c == sign_a
                    a = c
                    sign_a = sign_c
                else
                    b = c
                end
                
            end
            n += 1
        end

        LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))

        Tsol  = string(   round((a+b)/2.0,digits=2) )
    else
        print("Cannot compute solidus temperature if liq is removed from the solution phase list\n") 
        Tsol        = ""
    end

    return Tsol
end


function initialize_layout_isoS_path(   Pini :: Float64,
                                        Tini :: Float64,
                                        Pfinal :: Float64   )

    layout_isoS  = Layout(   font        = attr(size = 10),
                        height      = 240,
                        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
                        autosize    = false,
                        xaxis_title = "Temperature [°C]",
                        yaxis_title = "Pressure [$(pressure_unit_label())]",
                        xaxis_range = [Tini-300,Tini+100],
                        yaxis_range = [display_pressure(0.0),display_pressure(Pini+5.0)],
                        showlegend  = false,
                        xaxis       = attr(     fixedrange    = true,
                                            ),
                         yaxis       = attr(     fixedrange    = true,
                                            ),
    )

    return layout_isoS
end

function get_data_plot_isoS_path()

    n_tot   = length(Out_PTX)

    x       = Vector{Float64}(undef, n_tot)
    y       = Vector{Float64}(undef, n_tot)

    for i=1:n_tot
        x[i] = Out_PTX[i].T_C
        y[i] = display_pressure(Out_PTX[i].P_kbar)
    end

    df_path_plot = DataFrame(   x=x,
                                y=y     )

    return df_path_plot
end

function compute_new_PTXpath(   nsteps,     PTdata,     mode,       bulk_ini,   bulk_assim, oxi,    phase_selection,    assim, var_buffer,
                                dtb,        dataset,    bufferType, solver,
                                verbose,    bufferN,    scp,
                                cpx,        limOpx,     limOpxVal,
                                nCon,       nRes,
                                T_start,    isentropic_mode,
                                watsat      = "false",  watsat_val  = 0.0,
                                te_model    = "false",
                                kds_mod     = "",       zrsat_mod   = "none",
                                ssat_mod    = "none",   P2O5sat_mod = "none",   co2sat_mod  = "none",
                                bulkte_ini  = Float64[], bulkte_ass  = Float64[], elem_TE = String[],
                                seismicScheme = "VRH",  seismicWeightFactor = 0.5, seismicCorMode = false,
                                aspectRatio = 0.3, seismicWater = 0, shallowCor = false, fluidAsMelt = false, anelasticCor = false,
                                calcUnit = "mol", phase_thresholds = [], reminimize_threshold = false )

        global Out_PTX, ph_names_ptx, fracEvol, compo_matrix, removedBulk, assimFrac
        global Out_TE_PTX, all_TE_ph_ptx, C_ext_TE_PTX


        nsteps = Int64(nsteps)

        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 

        # retrieve PTX path
        data    = copy(PTdata)
        if isentropic_mode   == true
            np      = 2
        elseif isentropic_mode == false
            np      = length(data)
        end

        if np <= 1
            print("Cannot compute a path if at least 2 points are not defined! \n")
        else
            ph_names_ptx= Vector{String}()

            n_tot       = np + (np-1)*nsteps
            fracEvol    = Matrix{Float64}(undef,n_tot,3)
            removedBulk = Matrix{Float64}(undef,n_tot,length(bulk_ini))
            assimFrac   = zeros(Float64, n_tot)
            Out_PTX     = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n_tot)

            # TE initialization: set up KD database, adjust TE bulk compositions, and
            # pre-adjust the assimilant TE if assimilation is active
            te_enabled  = te_model == "true" && !isempty(bulkte_ini) && !isempty(kds_mod) &&
                          !(dtb in ["um", "ume", "mtl"])
            if te_enabled
                KDs_dtb      = build_kds_database(kds_mod)
                bulkte_ini_a = MAGEMin_C.adjust_chemical_system(KDs_dtb, bulkte_ini, elem_TE)
                bulkte_ass_a = assim == "true" && !isempty(bulkte_ass) ?
                               MAGEMin_C.adjust_chemical_system(KDs_dtb, bulkte_ass, elem_TE) :
                               copy(bulkte_ini_a)
                bulkte_cur   = copy(bulkte_ini_a)
                Out_TE_PTX   = Vector{MAGEMin_C.out_tepm}(undef, n_tot)
                all_TE_ph    = []
                C_ext_TE_PTX = [fill(NaN, length(bulkte_ini_a)) for _ in 1:n_tot]
            end

            Pres        = zeros(Float64,np)
            Temp        = zeros(Float64,np)
            Add         = zeros(Float64,np)
            Buff        = zeros(Float64,np)

            if isentropic_mode == false
                for i=1:np
                    Pres[i] = to_kbar_pressure(Float64(data[i][Symbol("col-1")]))
                    Temp[i] = data[i][Symbol("col-2")]
                end
            else isentropic_mode == true
                for i=1:np
                    Pres[i] = to_kbar_pressure(Float64(data[i][Symbol("col-1")]))
                end
                Temp[1] = T_start
            end
            
            if var_buffer == true
                for i=1:np
                    Buff[i] = data[i][Symbol("col-4")]
                end
            else
                for i=1:np
                    Buff[i] = bufferN
                end
            end

            if assim == "true"
                for i=1:np
                    Add[i] = data[i][Symbol("col-3")]
                    if Add[i] < 0.0
                        Add[i] = 0.0
                        print(" warning, value of point $i is < 0.0 mol%, setting it back to 0.0\n")
                    elseif Add[i] > 100.0
                        Add[i] = 100.0
                        print(" warning, value of point $i is > 100.0 mol%, setting it back to 100.0\n")
                    end
                end
                Add ./= 100.0;
            end

            # precompute water-saturation interpolators if requested
            pChip_wat, pChip_T = nothing, nothing
            id_h2o_ptx         = findfirst(oxi .== "H2O")
            id_dry_ptx         = findall(oxi .!= "H2O")
            if watsat == "true" && !isnothing(id_h2o_ptx)
                Yrange             = [minimum(Pres), maximum(Pres)]
                if Yrange[1] == Yrange[2]                  # constant-pressure path: avoid a zero-length range
                    Yrange[2]      += 1.0
                end
                pChip_wat, pChip_T = get_wat_sat_function(  Yrange,     bulk_ini,   oxi,    phase_selection,
                                                            dtb,        bufferType, solver,
                                                            verbose,    bufferN,
                                                            cpx,        limOpx,     limOpxVal, Float64(watsat_val))
            end

            # initialize single thread MAGEMin
            gv, z_b, DB, splx_data = init_MAGEMin(  dtb;
                                                    verbose     = verbose,
                                                    dataset     = dataset,
                                                    mbCpx       = mbCpx,
                                                    limitCaOpx  = limitCaOpx,
                                                    CaOpxLim    = CaOpxLim,
                                                    buffer      = bufferType,
                                                    solver      = sol,
                                                    seismicScheme       = seismicScheme,
                                                    seismicWeightFactor = seismicWeightFactor    );
    
            # define system unit and starting bulk rock composition
            # NOTE: `bulk` (the running composition tracked/updated throughout the
            # loop) is always kept in MOL basis here, since that's what `sys_in`/
            # `define_bulk_rock` and the water-saturation lookup expect. When
            # calcUnit == "wt", the assimilation blend and the melt/solid mass
            # balance below are instead carried out in MAGEMin's own wt-basis
            # fields (bulk_S_wt/bulk_M_wt, frac_S_wt/frac_M_wt) -- which already
            # exist as computed outputs -- and the result is converted back to
            # mol via `to_mol` before being stored into `bulk`, so mixing X% of
            # something means X mol% or X wt% depending on calcUnit, without
            # changing anything about how MAGEMin itself is driven.
            calcUnit    = calcUnit in ("mol","wt","vol") ? calcUnit : "mol"

            # There is no native "bulk_S_vol"/"bulk_M_vol" field, and -- unlike
            # mass -- volume cannot be used as a per-oxide mixing weight either.
            # A first attempt at "vol" built bulk_S_val as a volume-fraction-
            # weighted average of each solid phase's own MOL composition; that
            # is NOT a valid mole-conserving bulk composition (verified with a
            # 2-phase counter-example: 1 mol of a dense pure-oxide-1 phase + 1
            # mol of a light pure-oxide-2 phase must average back to [0.5,0.5],
            # but volume-fraction-weighting instead returns whatever the two
            # phases' volume ratio happens to be, e.g. [0.09,0.91] for a 10x
            # molar-volume contrast) -- because unlike mass, volume is not
            # additive per-oxide, so it silently ignores the density contrast
            # between whatever phases are being combined. That is what made the
            # earlier "vol" fm/fc results diverge instead of converging with
            # resolution: the error compounds every step as modal proportions
            # (and therefore the built-in density mismatch) shift.
            #
            # bulk_S_val/bulk_M_val therefore stay on the native MOL basis for
            # "vol" (same as "mol") -- correct and stable, since MAGEMin itself
            # already computes bulk_S/bulk_M as a proper mole-weighted average.
            # What "vol" actually changes is the MIXING WEIGHT: nCon/nRes are
            # given as volume percentages, so before blending bulk_S_val/
            # bulk_M_val (mol-basis) the target must be converted to the
            # equivalent MOLE-fraction weight -- the same molar-volume-ratio
            # trick already used by te_melt_wt_frac below, generalized to
            # target either melt or solid. `t` is the desired volume fraction
            # of whichever phase `target_is_melt` selects; `r` is the molar-
            # volume ratio of the OTHER phase to the TARGET phase (recovered,
            # again, from frac_*_vol vs frac_* without needing any molar-mass
            # or molar-volume table).
            function con_weight_mol(o, t, target_is_melt::Bool)
                calcUnit != "vol" && return t
                r = target_is_melt ? (o.frac_S_vol * o.frac_M) / (o.frac_S * o.frac_M_vol) :
                                      (o.frac_M_vol * o.frac_S) / (o.frac_M * o.frac_S_vol)
                return (t * r) / ((1.0 - t) + t * r)
            end

            frac_S_val(o) = calcUnit == "wt" ? o.frac_S_wt : calcUnit == "vol" ? o.frac_S_vol : o.frac_S
            frac_M_val(o) = calcUnit == "wt" ? o.frac_M_wt : calcUnit == "vol" ? o.frac_M_vol : o.frac_M
            frac_F_val(o) = calcUnit == "wt" ? o.frac_F_wt : calcUnit == "vol" ? o.frac_F_vol : o.frac_F
            bulk_S_val(o) = calcUnit == "wt" ? o.bulk_S_wt : o.bulk_S
            bulk_M_val(o) = calcUnit == "wt" ? o.bulk_M_wt : o.bulk_M
            # wt2mol (like mol2wt) is a MAGEMin_C utility that always returns its
            # result on a sum-to-100 (percentage) basis, regardless of its input's
            # scale -- unlike every native gmin_struct field (bulk_S_wt, Comp_wt,
            # ...), which sums to 1. Dividing by 100 here restores the sum-to-1
            # fraction convention that `bulk` must hold everywhere else in this
            # function (define_bulk_rock/point_wise_minimization are scale-
            # invariant so this was invisible on its own, but the phase-threshold
            # capping below subtracts an absolute sum-to-1-basis quantity from
            # `bulk` and silently no-ops if `bulk` is 100x too large). Only "wt"
            # needs this: bulk_S_val/bulk_M_val for "vol" are mol-basis, same as
            # "mol" (see con_weight_mol above).
            to_mol(v)      = calcUnit == "wt" ? wt2mol(v, oxi) ./ 100.0 : v

            # Trace-element partitioning (TE_prediction) always works on MAGEMin's
            # weight-basis melt/solid split (out.frac_M_wt/frac_S_wt) internally,
            # regardless of calcUnit -- so Csol/Cliq are always weight-basis
            # concentrations. When re-mixing them for carry-forward using the
            # SAME (w_S, w_M) weights applied to the major-element bulk above, those
            # weights must therefore be WEIGHT fractions too. If calcUnit == "wt"
            # they already are; if calcUnit == "mol" or "vol", convert the mole-
            # basis (or volume-basis) mixing weights to the equivalent weight
            # fraction using the ratio of the melt/solid sub-compositions' molar
            # masses, which is recoverable from o.frac_M_wt/o.frac_M(_vol) vs
            # o.frac_S_wt/o.frac_S(_vol) (all already computed by MAGEMin)
            # without needing any per-oxide molar-mass table.
            function te_melt_wt_frac(o, w_S, w_M)
                calcUnit == "wt" && return w_M
                r = calcUnit == "vol" ? (o.frac_M_wt * o.frac_S_vol) / (o.frac_M_vol * o.frac_S_wt) :
                                         (o.frac_M_wt * o.frac_S)     / (o.frac_M     * o.frac_S_wt)
                return (w_M * r) / (w_S + w_M * r)
            end

            # Per-phase extraction thresholds (Advanced path definition panel): converts
            # a mol/wt/vol-basis threshold excess for a single phase into the equivalent
            # MOL-basis amount to subtract from `bulk`, reusing the same ratio trick as
            # te_melt_wt_frac above (moles per unit of the chosen fraction, recovered
            # from that phase's own mol vs wt/vol fraction, no molar-mass table needed).
            function phase_excess_mol_frac(pt, id, unit, threshold_pct)
                prop = unit == "mol" ? sum(pt.ph_frac[id]) :
                       unit == "wt"  ? sum(pt.ph_frac_wt[id]) :
                                       sum(pt.ph_frac_vol[id])
                excess = prop - threshold_pct/100.0
                excess <= 0.0 && return 0.0
                unit == "mol" && return excess
                r = sum(pt.ph_frac[id]) / prop
                return excess * r
            end

            sys_in  = "mol"
            bulk    = copy(bulk_ini)
            bulk_assim_calc = (assim == "true" && calcUnit == "wt") ? mol2wt(bulk_assim, oxi) : bulk_assim

            if assim == "true"
                 bulk   .= to_mol( (1.0 - Add[1]) .* (calcUnit == "wt" ? mol2wt(bulk, oxi) : bulk) .+ Add[1] .* bulk_assim_calc )
            end

            gv      =  define_bulk_rock(gv, bulk, oxi, sys_in, dtb);

            fracEvol[1,1]            = 1.0;          # starting material fraction is always one as we want to measure the relative change here
            fracEvol[1,2]            = 0.0; 
            fracEvol[1,3]            = 0.0; 
            removedBulk[1,:]        .= zeros(length(bulk_ini))

            # retrieve reference entropy of the system
            if isentropic_mode == true
                out         = MAGEMin_C.gmin_struct{Float64, Int64};
                Out_PTX[1]  = deepcopy( point_wise_minimization(Pres[1],T_start, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true, scp=scp, seismic_cor=seismicCorMode, aspect_ratio=aspectRatio, seismic_water=seismicWater, shallow_correction=shallowCor, fluid_as_melt=fluidAsMelt, anelastic_cor=anelasticCor) )
                Sref        = Out_PTX[1].entropy[1];
                n_max       = 32
                tolerance   = 0.001
                delta_T     = (Pres[1]-Pres[np])/(nsteps+1)*(16.0);
            end

            k = 1
            for i = 1:np-1
                # if we assimilate a second bulk then we compute the assimilated fraction per step
                if assim == "true"
                    A       = Add[i+1]
                    val     = A / (1.0 - A)
                    step    = val/(nsteps+1)
                end

                @showprogress desc="Computing PTX path: point $i to $np " for j = 1:nsteps+1
                    P = Pres[i] + (j-1)*( (Pres[i+1] - Pres[i])/ (nsteps+1) )
                    T = Temp[i] + (j-1)*( (Temp[i+1] - Temp[i])/ (nsteps+1) )

                    if var_buffer == true
                        bufferN = Buff[i] + (j-1)*( (Buff[i+1] - Buff[i])/ (nsteps+1) )
                    end

                    if assim == "true"
                        w_assim = step ./ (1.0 .+ step .* j)
                        bulk   .= to_mol( (1.0 .- w_assim) .* (calcUnit == "wt" ? mol2wt(bulk, oxi) : bulk) .+ w_assim .* bulk_assim_calc )
                    end

                    if ~isnothing(pChip_wat) && isentropic_mode == false
                        TsatSol  = pChip_T(P)
                        waterSat = pChip_wat(P)
                        if T > TsatSol
                            tmp_bulk              = deepcopy(bulk)
                            tmp_bulk            ./= sum(tmp_bulk[id_dry_ptx])
                            tmp_bulk[id_h2o_ptx]  = waterSat
                            tmp_bulk            ./= sum(tmp_bulk)
                            gv = define_bulk_rock(gv, tmp_bulk, oxi, sys_in, dtb)
                        else
                            gv = define_bulk_rock(gv, bulk, oxi, sys_in, dtb)
                        end
                    else
                        gv = define_bulk_rock(gv, bulk, oxi, sys_in, dtb)
                    end

                    if isentropic_mode == true && k > 1
                        P = Pres[i] + (j-1)*( (Pres[i+1] - Pres[i])/ (nsteps+1) )

                        a           = Out_PTX[j-1].T_C - 2.0*delta_T
                        b           = Out_PTX[j-1].T_C
                        n           = 1
                        conv        = 0
                        n           = 0
                        sign_a      = -1
                
                        while n < n_max && conv == 0
                            c       = (a+b)/2.0
                            out     = deepcopy( point_wise_minimization(P, c , gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true, scp=scp, seismic_cor=seismicCorMode, aspect_ratio=aspectRatio, seismic_water=seismicWater, shallow_correction=shallowCor, fluid_as_melt=fluidAsMelt, anelastic_cor=anelasticCor) )
                            result  = out.entropy[1] - Sref

                            sign_c  = sign(result)
                
                            if abs(b-a) < tolerance
                                conv = 1
                            else
                                if  sign_c == sign_a
                                    a = c
                                    sign_a = sign_c
                                else
                                    b = c
                                end
                                
                            end
                            n += 1
                        end
                        if conv == 0
                            print(" WARNING: isentropic path did not converge at P = $P kbar between T = $a °C and T = $b °C\n")
                        end
                        Out_PTX[k]    = deepcopy(out)

                    elseif isentropic_mode == false
                        Out_PTX[k] = deepcopy( point_wise_minimization(P,T, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true, scp=scp, seismic_cor=seismicCorMode, aspect_ratio=aspectRatio, seismic_water=seismicWater, shallow_correction=shallowCor, fluid_as_melt=fluidAsMelt, anelastic_cor=anelasticCor) )
                    end


                    # assimFrac must be known before the mode blocks so TE can use it
                    if assim == "true"
                        alpha        = step / (1.0 + step * j)
                        assimFrac[k] = k == 1 ? alpha : (1.0 - alpha) * assimFrac[k-1] + alpha
                    end

                    if te_enabled
                        TEvec = assim == "true" ?
                                (1.0 - assimFrac[k]) .* bulkte_cur .+ assimFrac[k] .* bulkte_ass_a :
                                bulkte_cur
                    end

                    if mode == "fm"
                        if frac_S_val(Out_PTX[k]) > 0.0
                            if nCon > 0.0
                                if frac_M_val(Out_PTX[k]) > nCon/100.0
                                    w_con              = con_weight_mol(Out_PTX[k], nCon/100.0, true)
                                    bulk               .= to_mol( bulk_S_val(Out_PTX[k]) .*(1.0 - w_con) .+ bulk_M_val(Out_PTX[k]) .* w_con )
                                    removedBulk[k+1,:] .= bulk_M_val(Out_PTX[k])
                                    fracEvol[k+1,1]     = fracEvol[k,1] * (frac_S_val(Out_PTX[k]) + frac_F_val(Out_PTX[k]) + nCon/100.0)
                                    fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                                    fracEvol[k+1,3]     = 1.0 - (frac_S_val(Out_PTX[k]) + frac_F_val(Out_PTX[k]) + nCon/100.0)
                                    if te_enabled
                                        Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                        if !all(isnan, Out_TE_PTX[k].Csol) && !all(isnan, Out_TE_PTX[k].Cliq)
                                            w_M_te            = te_melt_wt_frac(Out_PTX[k], (100.0-nCon)/100.0, nCon/100.0)
                                            bulkte_cur        = Out_TE_PTX[k].Csol .* (1.0 - w_M_te) .+ Out_TE_PTX[k].Cliq .* w_M_te
                                            C_ext_TE_PTX[k+1] = copy(Out_TE_PTX[k].Cliq)
                                        end
                                    end
                                else
                                    removedBulk[k+1,:] .= zeros(length(bulk_ini))
                                    fracEvol[k+1,1]     = fracEvol[k,1]
                                    fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                                    fracEvol[k+1,3]     = 0.0
                                    if te_enabled
                                        Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                        # below connectivity: no bulk update, no extraction
                                    end
                                end
                            else
                                bulk               .= to_mol( bulk_S_val(Out_PTX[k]) )
                                removedBulk[k+1,:] .= zeros(length(bulk_ini))
                                fracEvol[k+1,1]     = fracEvol[k,1]
                                fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                                fracEvol[k+1,3]     = 0.0
                                if te_enabled
                                    Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                    if !all(isnan, Out_TE_PTX[k].Csol)
                                        bulkte_cur = copy(Out_TE_PTX[k].Csol)
                                        # no C_ext_TE_PTX: mirrors removedBulk = zeros
                                    end
                                end
                            end
                        else
                            removedBulk[k+1,:] .= zeros(length(bulk_ini))
                            fracEvol[k+1,1]     = fracEvol[k,1]
                            fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                            fracEvol[k+1,3]     = 0.0
                            if te_enabled
                                Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                # no solid: no bulk update
                            end
                        end
                    elseif mode == "fc"
                        if frac_M_val(Out_PTX[k]) > 0.0
                            if nRes > 0.0
                                if frac_S_val(Out_PTX[k]) > nRes/100.0
                                    # nRes/100 plays two different roles below (the
                                    # residual solid's target fraction in the carried-
                                    # forward `bulk`, vs. the entrained melt's fraction
                                    # in the extracted `removedBulk`) -- each needs its
                                    # own mole-equivalent conversion, targeting whichever
                                    # phase that occurrence of nRes/100 actually applies to
                                    w_con_S            = con_weight_mol(Out_PTX[k], nRes/100.0, false)
                                    w_con_M            = con_weight_mol(Out_PTX[k], nRes/100.0, true)
                                    bulk               .= to_mol( bulk_M_val(Out_PTX[k]) .*(1.0 - w_con_S) .+ bulk_S_val(Out_PTX[k]) .* w_con_S )
                                    removedBulk[k+1,:] .= bulk_M_val(Out_PTX[k]) .* w_con_M .+ bulk_S_val(Out_PTX[k]) .*(1.0 - w_con_M)
                                    fracEvol[k+1,1]     = fracEvol[k,1] * (frac_M_val(Out_PTX[k]) - nRes/100.0)
                                    fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                                    fracEvol[k+1,3]     = 1.0 - frac_M_val(Out_PTX[k]) - nRes/100.0
                                    if te_enabled
                                        Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                        if !all(isnan, Out_TE_PTX[k].Cliq) && !all(isnan, Out_TE_PTX[k].Csol)
                                            w_M_te            = te_melt_wt_frac(Out_PTX[k], nRes/100.0, (100.0-nRes)/100.0)
                                            w_M_ext_te        = te_melt_wt_frac(Out_PTX[k], (100.0-nRes)/100.0, nRes/100.0)
                                            bulkte_cur        = Out_TE_PTX[k].Cliq .* w_M_te .+ Out_TE_PTX[k].Csol .* (1.0 - w_M_te)
                                            C_ext_TE_PTX[k+1] = Out_TE_PTX[k].Cliq .* w_M_ext_te .+ Out_TE_PTX[k].Csol .* (1.0 - w_M_ext_te)
                                        end
                                    end
                                else
                                    bulk               .= to_mol( bulk_M_val(Out_PTX[k]) )
                                    removedBulk[k+1,:] .= bulk_S_val(Out_PTX[k])
                                    fracEvol[k+1,1]     = fracEvol[k,1] * (frac_M_val(Out_PTX[k]) - frac_S_val(Out_PTX[k]))
                                    fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                                    fracEvol[k+1,3]     = 1.0 - (frac_M_val(Out_PTX[k]) - frac_S_val(Out_PTX[k]))
                                    if te_enabled
                                        Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                        if !all(isnan, Out_TE_PTX[k].Cliq) && !all(isnan, Out_TE_PTX[k].Csol)
                                            bulkte_cur        = copy(Out_TE_PTX[k].Cliq)
                                            C_ext_TE_PTX[k+1] = copy(Out_TE_PTX[k].Csol)
                                        end
                                    end
                                end
                            else
                                bulk               .= to_mol( bulk_M_val(Out_PTX[k]) )
                                removedBulk[k+1,:] .= bulk_S_val(Out_PTX[k])
                                fracEvol[k+1,1]     = fracEvol[k,1] * frac_M_val(Out_PTX[k])
                                fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                                fracEvol[k+1,3]     = 1.0 - frac_M_val(Out_PTX[k])
                                if te_enabled
                                    Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                    if !all(isnan, Out_TE_PTX[k].Cliq) && !all(isnan, Out_TE_PTX[k].Csol)
                                        bulkte_cur        = copy(Out_TE_PTX[k].Cliq)
                                        C_ext_TE_PTX[k+1] = copy(Out_TE_PTX[k].Csol)
                                    end
                                end
                            end
                        else
                            removedBulk[k+1,:] .= zeros(length(bulk_ini))
                            fracEvol[k+1,1]     = fracEvol[k,1]
                            fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                            fracEvol[k+1,3]     = 0.0
                            if te_enabled
                                Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                                # no melt: no bulk update
                            end
                        end
                    else
                        removedBulk[k+1,:] .= zeros(length(bulk_ini))
                        fracEvol[k+1,1]     = fracEvol[k,1]
                        fracEvol[k+1,2]     = 1.0 - fracEvol[k+1,1]
                        fracEvol[k+1,3]     = 0.0
                        if te_enabled
                            Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb; ZrSat_model=zrsat_mod, SSat_model=ssat_mod, P2O5Sat_model=P2O5sat_mod, CO2Sat_model=co2sat_mod)
                            # not fc/fm: no bulk update
                        end
                    end

                    # Per-phase extraction thresholds (Advanced path definition panel):
                    # applies regardless of P-T-X Mode, on top of whatever the block
                    # above already did to `bulk`/`removedBulk`/`fracEvol` this step.
                    # Once a configured phase's proportion (in its own mol/wt/vol unit)
                    # exceeds its threshold at this step, only the excess is removed --
                    # a continuous cap, not a one-time full extraction. Merged into the
                    # SAME removedBulk/fracEvol bookkeeping fm/fc already use, so the
                    # existing "Extracted phases"/"Phase composition" plots correctly
                    # show the combined total removed by either mechanism.
                    if !isempty(phase_thresholds) && isassigned(Out_PTX, k)
                        pt   = Out_PTX[k]
                        n_SS = pt.n_SS

                        # removedBulk[k+1,:] is a per-step COMPOSITION SHAPE (always
                        # summing to 0 or 1, plotted directly as a 0-100% breakdown by
                        # get_data_comp_rm_plot/get_data_comp_rm_int_plot) -- it is NOT
                        # a mass-weighted quantity, so a threshold's contribution can't
                        # simply be added on top of whatever fm/fc already wrote there.
                        # Capture what fm/fc already removed THIS step (as a fraction of
                        # the CURRENT, pre-this-step system) so it can be folded into a
                        # single re-normalized sum-to-1 shape together with whatever
                        # thresholding removes below, rather than corrupting the shape.
                        existing_shape = copy(removedBulk[k+1,:])
                        existing_mass  = fracEvol[k,1] > 0.0 ? clamp(1.0 - fracEvol[k+1,1]/fracEvol[k,1], 0.0, 1.0) : 0.0

                        total_excess_calc     = 0.0                                  # calcUnit-basis fraction of the CURRENT system removed by thresholding this step
                        combined_extra_shape  = zeros(Float64, length(bulk_ini))     # sums to total_excess_calc once the loop below is done

                        for entry in phase_thresholds
                            thr_val = entry.values[i] + (j-1)*((entry.values[i+1]-entry.values[i])/(nsteps+1))
                            id_ph   = findall(pt.ph .== entry.phase)
                            isempty(id_ph) && continue

                            excess_mol_frac = phase_excess_mol_frac(pt, id_ph, entry.unit, thr_val)
                            excess_mol_frac <= 0.0 && continue

                            comps    = [ i_ph <= n_SS ? pt.SS_vec[i_ph].Comp : pt.PP_vec[i_ph - n_SS].Comp for i_ph in id_ph ]
                            comp_avg = sum(comps) ./ length(comps)   # simple average across solvus instances

                            bulk             .-= excess_mol_frac .* comp_avg
                            bulk[bulk .< 0.0] .= 0.0
                            bulk            ./= sum(bulk)

                            # removedBulk/fracEvol are tracked in `calcUnit` basis (mol
                            # or wt) throughout the rest of this function; convert this
                            # mol-basis excess the same way, reusing the molar-mass
                            # ratio trick already used for the trace-element fix (this
                            # phase's own mol vs wt fraction gives exactly that ratio),
                            # and MAGEMin's own already-fraction-scaled Comp_wt fields
                            # for the composition shape -- NOT the mol2wt()/wt2mol()
                            # utility functions, which are percent-scaled (sum to 100,
                            # for user-facing bulk-rock display) rather than fraction-
                            # scaled (sum to 1), unlike every native gmin_struct field.
                            if calcUnit == "wt"
                                comps_wt         = [ i_ph <= n_SS ? pt.SS_vec[i_ph].Comp_wt : pt.PP_vec[i_ph - n_SS].Comp_wt for i_ph in id_ph ]
                                comp_avg_wt      = sum(comps_wt) ./ length(comps_wt)
                                wt_frac_ratio    = sum(pt.ph_frac_wt[id_ph]) / sum(pt.ph_frac[id_ph])   # MM_phase / MM_system
                                excess_calc      = excess_mol_frac * wt_frac_ratio
                                removed_contrib  = excess_calc .* comp_avg_wt
                            else
                                excess_calc      = excess_mol_frac
                                removed_contrib  = excess_mol_frac .* comp_avg
                            end

                            combined_extra_shape .+= removed_contrib
                            total_excess_calc     += excess_calc
                        end

                        if total_excess_calc > 0.0
                            total_mass = existing_mass + total_excess_calc
                            removedBulk[k+1,:] .= (existing_shape .* existing_mass .+ combined_extra_shape) ./ total_mass

                            fracEvol[k+1,1] *= (1.0 - total_excess_calc)
                            fracEvol[k+1,2]  = 1.0 - fracEvol[k+1,1]

                            # optional re-minimization (Re-minimize toggle in the Advanced
                            # path definition panel): by default the capped phase's plotted
                            # proportion is the PRE-cap equilibrium (matching how fm/fc only
                            # ever adjust the bulk carried into the next step, never the
                            # current point's own display). When enabled, re-equilibrate this
                            # point with the post-cap bulk so the displayed phase proportion
                            # is pinned at the threshold instead of showing the pre-cap value.
                            if reminimize_threshold
                                gv         = define_bulk_rock(gv, bulk, oxi, sys_in, dtb)
                                Out_PTX[k] = deepcopy( point_wise_minimization(P, T, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true, scp=scp, seismic_cor=seismicCorMode, aspect_ratio=aspectRatio, seismic_water=seismicWater, shallow_correction=shallowCor, fluid_as_melt=fluidAsMelt, anelastic_cor=anelasticCor) )
                            end
                        end
                    end

                    if te_enabled && isassigned(Out_TE_PTX, k) && !isnothing(Out_TE_PTX[k].ph_TE)
                        for ph in Out_TE_PTX[k].ph_TE
                            if !(ph in all_TE_ph)
                                push!(all_TE_ph, string(ph))
                            end
                        end
                    end

                    if bufferType != "none"
                        if bufferType == "aH2O"
                            id_H2O = findfirst(oxi .== "H2O")
                            if ~isempty(id_H2O)
                                bulk[id_H2O] = 0.6
                            end
                        elseif bufferType == "aTiO2"
                            id_TiO2 = findfirst(oxi .== "TiO2")
                            if ~isempty(id_TiO2)
                                bulk[id_TiO2] = 0.5
                            end
                        elseif bufferType == "aAl2O3"
                            id_Al2O3 = findfirst(oxi .== "Al2O3")
                            if ~isempty(id_Al2O3)
                                bulk[id_Al2O3] = 0.8
                            end
                        elseif bufferType == "aFeO"
                            id_FeO = findfirst(oxi .== "FeO")
                            if ~isempty(id_FeO)
                                bulk[id_FeO] = 0.8
                            end
                        elseif bufferType == "aMgO"
                            id_MgO = findfirst(oxi .== "MgO")
                            if ~isempty(id_MgO)
                                bulk[id_MgO] = 0.8
                            end
                        else
                            id_O = findfirst(oxi .== "O")
                            if ~isempty(id_O)
                                bulk[id_O] = 0.3
                            end
                        end
                    end


                    if isentropic_mode == true && (mode == "fm" || mode == "fc")
                        T_C     = Out_PTX[k].T_C
                        P_kbar  = Out_PTX[k].P_kbar
                        gv      = define_bulk_rock(gv, bulk, oxi, sys_in, dtb);
                        out     = deepcopy( point_wise_minimization(P_kbar,T_C, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true, scp=scp, seismic_cor=seismicCorMode, aspect_ratio=aspectRatio, seismic_water=seismicWater, shallow_correction=shallowCor, fluid_as_melt=fluidAsMelt, anelastic_cor=anelasticCor) )
                        Sref    = out.entropy[1]
                    end

                    k += 1
                end
            end

            fracEvol[fracEvol .< 0.0] .= 0.0

            
            if isentropic_mode == true
                P           = Pres[np]
                a           = Out_PTX[k-1].T_C - 2.0*delta_T
                b           = Out_PTX[k-1].T_C
                n           = 1
                conv        = 0
                n           = 0
                sign_a      = -1
        
                while n < n_max && conv == 0
                    c       = (a+b)/2.0
                    out     = deepcopy( point_wise_minimization(P, c , gv, z_b, DB, splx_data, sys_in; buffer_n=Buff[np], rm_list=phase_selection, name_solvus=true, scp=scp, seismic_cor=seismicCorMode, aspect_ratio=aspectRatio, seismic_water=seismicWater, shallow_correction=shallowCor, fluid_as_melt=fluidAsMelt, anelastic_cor=anelasticCor) )
                    result  = out.entropy[1] - Sref

                    sign_c  = sign(result)
        
                    if abs(b-a) < tolerance
                        conv = 1
                    else
                        if  sign_c == sign_a
                            a = c
                            sign_a = sign_c
                        else
                            b = c
                        end
                        
                    end
                    n += 1
                end

                Out_PTX[k]    = deepcopy(out)

            elseif isentropic_mode == false
                 Out_PTX[k] = deepcopy( point_wise_minimization(Pres[np],Temp[np], gv, z_b, DB, splx_data, sys_in; buffer_n=Buff[np], rm_list=phase_selection, name_solvus=true, scp=scp, seismic_cor=seismicCorMode, aspect_ratio=aspectRatio, seismic_water=seismicWater, shallow_correction=shallowCor, fluid_as_melt=fluidAsMelt, anelastic_cor=anelasticCor) )
            end

            if assim == "true" && k > 1
                assimFrac[k] = assimFrac[k-1]
            end

            # TE prediction for the final point (no bulk update needed after the last step)
            if te_enabled
                if assim == "true"
                    f_ass   = assimFrac[k]
                    TEvec   = (1.0 - f_ass) .* bulkte_cur .+ f_ass .* bulkte_ass_a
                else
                    TEvec   = bulkte_cur
                end
                Out_TE_PTX[k] = TE_prediction(Out_PTX[k], TEvec, KDs_dtb, dtb;
                                               ZrSat_model   = zrsat_mod,
                                               SSat_model    = ssat_mod,
                                               P2O5Sat_model = P2O5sat_mod,
                                               CO2Sat_model  = co2sat_mod)
                if !isnothing(Out_TE_PTX[k].ph_TE)
                    for ph in Out_TE_PTX[k].ph_TE
                        if !(ph in all_TE_ph)
                            push!(all_TE_ph, string(ph))
                        end
                    end
                end
                all_TE_ph_ptx = all_TE_ph
            end

            for k = 1:n_tot
                for l=1:length(Out_PTX[k].ph)
                    if ~(Out_PTX[k].ph[l] in ph_names_ptx)
                        push!(ph_names_ptx,Out_PTX[k].ph[l])
                    end
                end
            end
            ph_names_ptx = sort(ph_names_ptx)

            # free MAGEMin
            LibMAGEMin.FreeDatabases(gv, DB, z_b, pointer_from_objref(splx_data))
        end

end

function get_pt_path_te_plot(step_id :: Int64)
    global Out_PTX

    np   = length(Out_PTX)
    T_v  = [Out_PTX[k].T_C    for k = 1:np]
    P_v  = [display_pressure(Out_PTX[k].P_kbar) for k = 1:np]
    text = ["#$(k)#"          for k = 1:np]

    punit = pressure_unit_label()
    hover = ["T: $(round(T_v[k];digits=1)) °C | P: $(round(P_v[k];digits=2)) $punit | step: $k" for k = 1:np]

    trace_path = scatter(;
        x              = T_v,
        y              = P_v,
        mode           = "lines+markers",
        line           = attr(color = "lightgray", width = 1),
        marker         = attr(size = 6, color = collect(1:np),
                              colorscale = "Jet", showscale = false),
        text           = text,
        hovertext      = hover,
        hovertemplate  = "%{hovertext}<extra></extra>",
        showlegend     = false,
    )

    trace_sel = scatter(;
        x              = [T_v[step_id]],
        y              = [P_v[step_id]],
        mode           = "markers",
        marker         = attr(size = 12, color = "white",
                              line = attr(color = "black", width = 2)),
        text           = ["#$(step_id)#"],
        hoverinfo      = "skip",
        showlegend     = false,
    )

    layout = Layout(
        font       = attr(size = 10),
        height     = 160,
        margin     = attr(autoexpand = false, l = 40, r = 12, b = 30, t = 10),
        autosize   = false,
        xaxis_title = "T [°C]",
        yaxis_title = "P [$(pressure_unit_label())]",
        xaxis      = attr(fixedrange = true),
        yaxis      = attr(fixedrange = true, autorange = "reversed"),
        showlegend = false,
        dragmode   = false,
    )

    return [trace_path, trace_sel], layout
end


function get_layout_ree_ptx(norm :: String, show_type :: String)
    if show_type == "ree"
        xaxis_title = "Rare Earth Elements"
    else
        xaxis_title = "Trace Elements"
    end
    yaxis_title = "C/" * norm * " log10[μg/g]"

    layout_ree = Layout(
        font        = attr(size = 10),
        height      = 280,
        margin      = attr(autoexpand = false, l=12, r=12, b=8, t=32),
        autosize    = false,
        xaxis_title = xaxis_title,
        yaxis_title = yaxis_title,
        yaxis_type  = "log",
        showlegend  = true,
        dragmode    = false,
        xaxis       = attr(fixedrange = true),
        yaxis       = attr(fixedrange = true),
    )
    return layout_ree
end


function _ptx_tick_labels(np::Int)
    max_ticks = 10
    tick_step = max(1, div(np - 1, max_ticks - 1))
    tick_idx  = sort(unique(vcat(1:tick_step:np, np)))
    tick_vals = tick_idx
    tick_text = ["P=$(round(display_pressure(Out_PTX[k].P_kbar); digits=1))\nT=$(round(Out_PTX[k].T_C; digits=0))°C"
                 for k in tick_idx]
    return tick_vals, tick_text
end


function get_parsed_command_ptx(step_id :: Int64;
                                 varBuilder :: String = "[M_Dy] / [M_Yb]",
                                 norm       :: String = "none")
    global Out_TE_PTX

    te_chondrite  = ["Rb","Ba","Th","U","Nb","Ta","La","Ce","Pb","Pr","Sr","Nd","Zr","Hf",
                     "Sm","Eu","Gd","Tb","Dy","Y","Ho","Er","Tm","Yb","Lu","V","Sc"]
    ppm_chondrite = [2.3, 2.41, 0.029, 0.0074, 0.24, 0.0136, 0.237, 0.613, 2.47, 0.0928,
                     7.25, 0.457, 3.82, 0.103, 0.148, 0.0563, 0.199, 0.0361, 0.246, 1.57,
                     0.0546, 0.160, 0.0247, 0.161, 0.0246, 56, 5.92]

    res = Out_TE_PTX[step_id]

    if all(isnan, res.Cliq)
        return Meta.parse("NaN")
    end
    if all(isnan, res.Csol) && occursin("S_", varBuilder)
        return Meta.parse("NaN")
    end

    pattern        = r"\[([^\]]+)\]"
    terms          = [m.captures[1] for m in eachmatch(pattern, varBuilder)]
    ref            = "Out_TE_PTX[" * string(step_id) * "]"
    varBuilder_out = varBuilder

    for term in terms
        st = String.(split(term, "_"))
        if length(st) != 2
            varBuilder_out = "NaN"; break
        end
        id_el = findfirst(isequal(st[2]), string.(res.elements))
        if isnothing(id_el)
            varBuilder_out = "NaN"; break
        end

        if norm == "bulk"
            nrm = string(res.C0[id_el])
        elseif norm == "chondrite"
            id_ch = findfirst(isequal(st[2]), te_chondrite)
            nrm   = isnothing(id_ch) ? "1.0" : string(ppm_chondrite[id_ch])
        else
            nrm = "1.0"
        end

        if st[1] == "M"
            part1 = ref * ".Cliq"; part2 = "[" * string(id_el) * "]"
        elseif st[1] == "S"
            part1 = ref * ".Csol"; part2 = "[" * string(id_el) * "]"
        elseif st[1] == "C0"
            part1 = ref * ".C0";   part2 = "[" * string(id_el) * "]"
        else
            ph_te = res.ph_TE
            if isnothing(ph_te)
                id_ph = nothing
            else
                id_ph = findfirst(isequal(st[1]), string.(ph_te))
                if isnothing(id_ph) && use_warr_names[1]
                    id_ph = findfirst(ph -> MAGEMin_C.get_Warr_name(ph) == st[1], ph_te)
                end
            end
            if isnothing(id_ph)
                varBuilder_out = "NaN"; break
            end
            part1 = ref * ".Cmin"
            part2 = "[" * string(id_ph) * "," * string(id_el) * "]"
        end

        varBuilder_out = replace(varBuilder_out,
                                 "[" * term * "]" => "((" * part1 * part2 * ")/" * nrm * ")")
    end

    return Meta.parse(varBuilder_out)
end


function get_te_fieldbuilder_plot(varBuilder::String, norm::String)
    global Out_PTX, Out_TE_PTX

    np       = length(Out_TE_PTX)
    x_vals   = collect(1:np)
    hover_pt = ["P: $(round(display_pressure(Out_PTX[k].P_kbar); digits=2)) $(pressure_unit_label()) | T: $(round(Out_PTX[k].T_C; digits=1)) °C | step: $k"
                for k = 1:np]

    tick_vals, tick_text = _ptx_tick_labels(np)

    y_vals = Vector{Union{Float64,Missing}}(undef, np)
    for k = 1:np
        cmd    = get_parsed_command_ptx(k; varBuilder=varBuilder, norm=norm)
        val    = try eval(cmd) catch; NaN end
        y_vals[k] = (val isa Number && isfinite(Float64(val))) ? Float64(val) : missing
    end

    ytitle = norm == "none" ? varBuilder : varBuilder * " / " * norm
    traces = [scatter(; x=x_vals, y=y_vals,
                       mode="markers+lines",
                       name=varBuilder,
                       hovertext=hover_pt,
                       hovertemplate="%{hovertext}<extra></extra>",
                       marker=attr(size=5, color="steelblue"),
                       line=attr(color="steelblue", width=1.5),
                       connectgaps=false)]

    layout = Layout(
        font     = attr(size=10),
        margin   = attr(autoexpand=false, l=55, r=12, b=60, t=20),
        autosize = false,
        xaxis    = attr(tickmode="array", tickvals=tick_vals, ticktext=tick_text, tickangle=-45),
        yaxis_title = ytitle,
        showlegend  = false,
    )

    return traces, layout
end


function get_te_evolution_plot(element::String, phases::Vector{String})
    global Out_PTX, Out_TE_PTX

    np       = length(Out_TE_PTX)
    elem_idx = findfirst(isequal(element), Out_TE_PTX[1].elements)
    if isnothing(elem_idx)
        return GenericTrace[], Layout()
    end

    x_vals             = collect(1:np)
    hover_pt           = ["P: $(round(display_pressure(Out_PTX[k].P_kbar); digits=2)) $(pressure_unit_label()) | T: $(round(Out_PTX[k].T_C; digits=1)) °C | step: $k" for k = 1:np]
    tick_vals, tick_text = _ptx_tick_labels(np)

    colormap   = get_lines_colormap()
    traces     = GenericTrace[]
    min_ci     = 1

    for phase in phases
        y_vals = Vector{Union{Float64,Missing}}(undef, np)

        if phase == "Cliq"
            for k = 1:np
                res = Out_TE_PTX[k]
                y_vals[k] = (!all(isnan, res.Cliq) && !isnan(res.Cliq[elem_idx])) ? res.Cliq[elem_idx] : missing
            end
            color = "RGB(176,0,0)"

        elseif phase == "Csol"
            for k = 1:np
                res = Out_TE_PTX[k]
                y_vals[k] = (!all(isnan, res.Csol) && !isnan(res.Csol[elem_idx])) ? res.Csol[elem_idx] : missing
            end
            color = "black"

        else   # mineral phase
            color = colormap[mod1(min_ci, length(colormap))]
            min_ci += 1
            for k = 1:np
                res = Out_TE_PTX[k]
                if !isnothing(res.ph_TE)
                    ph_idx = findfirst(isequal(phase), string.(res.ph_TE))
                    if !isnothing(ph_idx) && !isnan(res.Cmin[ph_idx, elem_idx])
                        y_vals[k] = res.Cmin[ph_idx, elem_idx]
                    else
                        y_vals[k] = missing
                    end
                else
                    y_vals[k] = missing
                end
            end
        end

        ph_label = display_ph_name(phase)
        push!(traces, scatter(; x=x_vals, y=y_vals,
                               mode="markers+lines",
                               name=ph_label,
                               hovertext=hover_pt,
                               hovertemplate="%{hovertext}<extra>$ph_label</extra>",
                               marker=attr(size=5, color=color),
                               line=attr(color=color, width=1.5),
                               connectgaps=false))
    end

    layout = Layout(
        font   = attr(size=10),
        margin = attr(autoexpand=false, l=55, r=12, b=60, t=20),
        autosize = false,
        xaxis  = attr(tickmode="array", tickvals=tick_vals, ticktext=tick_text, tickangle=-45),
        yaxis_title = "$element [μg/g]",
        showlegend  = true,
        legend      = attr(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
    )

    return traces, layout
end


function get_data_ree_plot_ptx(step_id, norm, show_type)

    ree           = ["La", "Ce", "Pr", "Nd", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"]
    te_chondrite  = ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc", "Cs", "K", "Ti"]
    ppm_chondrite = [2.3, 2.41, 0.029, 0.0074, 0.24, 0.0136, 0.237, 0.613, 2.47, 0.0928, 7.25, 0.457, 3.82, 0.103, 0.148, 0.0563, 0.199, 0.0361, 0.246, 1.57, 0.0546, 0.160, 0.0247, 0.161, 0.0246, 56, 5.92, 0.188, 558.0, 436.0]

    res = Out_TE_PTX[step_id]

    if show_type == "ree"
        te      = ree
        te_idx  = [findfirst(isequal(x), res.elements) for x in ree]
    else
        mask    = [!isnothing(findfirst(isequal(x), res.elements)) for x in te_chondrite]
        te      = te_chondrite[mask]
        te_idx  = [findfirst(isequal(x), res.elements) for x in te]
    end

    chon_idx = [findfirst(isequal(x), te_chondrite) for x in te]

    n_ree    = length(te_idx)
    n_traces = 0
    Cph, C0, Csol, Cliq = 0, 0, 0, 0

    if !isnothing(res.ph_TE)
        n_ph_TE  = length(res.ph_TE)
        n_traces += n_ph_TE
        Cph       = 1
    end
    if all(!isnan, res.C0);   n_traces += 1; C0   = 1; end
    if all(!isnan, res.Cliq); n_traces += 1; Cliq = 1; end
    if all(!isnan, res.Csol); n_traces += 1; Csol = 1; end

    data_ree_plot  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_traces)
    compo_mat      = Matrix{Union{Float64,Missing}}(undef, n_traces, n_ree) .= missing
    colormap       = get_lines_colormap()

    if norm == "chondrite"
        C_norm = ppm_chondrite[chon_idx]
    elseif norm == "bulk"
        C_norm = res.C0[te_idx]
    else
        C_norm = ones(n_ree)
    end

    k = 1
    if Cph == 1
        for i = 1:n_ph_TE
            compo_mat[k, :] = res.Cmin[i, te_idx]
            data_ree_plot[k] = scatter(; x = te, y = compo_mat[k, :] ./ C_norm,
                                         name = display_ph_name(res.ph_TE[i]), mode = "markers+lines",
                                         marker = attr(size = 4.0, color = colormap[k]),
                                         line   = attr(width = 1.0, color = colormap[k]))
            k += 1
        end
    end
    if C0 == 1
        compo_mat[k, :] = res.C0[te_idx]
        data_ree_plot[k] = scatter(; x = te, y = compo_mat[k, :] ./ C_norm,
                                     name = "C0", mode = "lines",
                                     line = attr(dash = "dash", color = "black", width = 2.0))
        k += 1
    end
    if Cliq == 1
        compo_mat[k, :] = res.Cliq[te_idx]
        data_ree_plot[k] = scatter(; x = te, y = compo_mat[k, :] ./ C_norm,
                                     name = "Cliq", mode = "markers+lines",
                                     marker = attr(size = 6.0, color = "RGB(176,0,0)"),
                                     line   = attr(color = "RGB(176,0,0)", width = 2.0))
        k += 1
    end
    if Csol == 1
        compo_mat[k, :] = res.Csol[te_idx]
        data_ree_plot[k] = scatter(; x = te, y = compo_mat[k, :] ./ C_norm,
                                     name = "Csol", mode = "markers+lines",
                                     marker = attr(size = 6.0, color = "black"),
                                     line   = attr(color = "black", width = 2.0))
    end

    return data_ree_plot
end


function get_data_plot(display_mode, sysunit)

    ph_ord  = order_phases(ph_names_ptx)
    n_ph    = length(ph_ord)
    n_tot   = length(Out_PTX)
    data_plot_ptx  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph+2);

    x       = Vector{String}(undef, n_tot)
    Y       = zeros(Float64, n_ph, n_tot)

    colormap = get_jet_colormap(n_ph)

    for i=1:n_ph

        ph = ph_ord[i]
        for k=1:n_tot
            
            x[k]    = string(round(display_pressure(Out_PTX[k].P_kbar),digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
            id      = findall(Out_PTX[k].ph .== ph)

            if sysunit == "mol"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac[id]) .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "wt"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac_wt[id]) .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "vol"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac_vol[id]) .*100.0                # we sum in case of solvi
                end
            end
        
        end
    end 

    for k=1:n_tot
        Y[:,k] .= Y[:,k]/sum(Y[:,k]) .* 100.0
    end

    if display_mode == "stacked"
        for i=1:n_ph
            ph      = ph_ord[i]

            data_plot_ptx[i] = scatter(;    x           =  x,
                                            y           =  Y[i,:],
                                            name        = display_ph_name(ph_ord[i]),
                                            stackgroup  = "one",
                                            mode        = "lines",
                                            line        = attr(     width   =  0.5,
                                                                    color   = get_phase_color(ph))  )
        end
    elseif display_mode == "bars"
        for i=1:n_ph

            ph      = ph_ord[i]

            data_plot_ptx[i] = bar(         x           =  x,
                                            y           =  Y[i,:],
                                            name        = display_ph_name(ph_ord[i]),
                                            marker      = attr( color   = get_phase_color(ph),
                                                                line    = attr(width=0.0, color="black"),
                                                                opacity = 0.6) # black outline
                                            )
         end
    else
        for i=1:n_ph
            ph      = ph_ord[i]

            data_plot_ptx[i] = scatter(;    x           =  x,
                                            y           =  Y[i,:],
                                            name        = display_ph_name(ph_ord[i]),
                                            mode        = "markers+lines",
                                            marker = attr(
                                                size    = 5.0,          # Set the size of the circle
                                                color   = get_phase_color(ph),      # Set the color of the circle
                                                symbol  = "circle-open", # Use an open circle marker
                                                opacity = 0.5           # Set the transparency (0.0 = fully transparent, 1.0 = fully opaque)
                                            ),
                                            line        = attr(     width   = 0.75,
                                                                    color   = get_phase_color(ph))  )
         end
    end

     data_plot_ptx[n_ph+1] = scatter(   x               = x,
                                    name            = "removed %",
                                    y               = fracEvol[:,2].*100.0, 
                                    hoverinfo       = "skip",
                                    mode            = "lines",
                                    line            = attr( dash    = "dash",
                                                            color   = "black", 
                                                            width   = 0.75)                ) 

     data_plot_ptx[n_ph+2] = scatter(   x               = x,
                                    y               = fracEvol[:,1].*100.0, 
                                    name            = "remaining %",
                                    hoverinfo       = "skip",
                                    mode            = "lines",
                                    line            = attr( color   = "black", 
                                                            width   = 0.75)                ) 


    # build phase list:
    phase_list = [Dict("label" => "  "*display_ph_name(ph_ord[i]), "value" => ph_ord[i]) for i=1:n_ph]


    return data_plot_ptx, phase_list
end


function get_extracted_data_plot(ext_mode,sysunit,mode,nRes,nCon,isentropic_mode)

    n_ph    = length(ph_names_ptx)
    n_tot   = length(Out_PTX)

    ph_names_ext_ptx = []
    for i in ph_names_ptx
        if i != "liq"
            push!(ph_names_ext_ptx,i)
        end
    end
    ph_names_ext_ptx = order_phases(ph_names_ext_ptx)

    n_ph_e = length(ph_names_ext_ptx)
    data_extracted_plot_ptx  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph_e);

    x       = Vector{String}(undef, n_tot)
    melt    = zeros(Int64, n_tot)
    Z       = Matrix{Union{Float64,Missing}}(undef, n_ph_e, n_tot) .= missing
    Y       = zeros(Float64, n_ph_e, n_tot)

    colormap = get_jet_colormap(n_ph_e)

    for i=1:n_ph_e
        
        ph = ph_names_ext_ptx[i]

        for k=1:n_tot
            
            x[k]    = string(round(display_pressure(Out_PTX[k].P_kbar), digits=1))*"; "*string(round(Out_PTX[k].T_C, digits=1))
            id      = findall(Out_PTX[k].ph .== ph )
            if "liq" in Out_PTX[k].ph 
                melt[k] = 1
            end

            if mode == "fc"
                frac = fracEvol[k,1] * 1.0 - (nRes/100.0)
            else
                frac = 0.0
            end

            if sysunit == "mol"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac[id]) .* frac .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "wt"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac_wt[id]) .* frac .*100.0                # we sum in case of solvi
                end
            elseif sysunit == "vol"
                if ~isempty(id)
                    Y[i,k] = sum(Out_PTX[k].ph_frac_vol[id]) .* frac .*100.0                # we sum in case of solvi
                end
            end


        
        end

    end 

    Z .= hcat([accumulate(+,Y[i,:]) for i=1:n_ph_e]...)'

    for i=1:n_tot
        if melt[i] == 0
            Z[:,i] .= missing
        end
    end

    if ext_mode == "stacked"
        for i=1:n_ph_e

            ph      = ph_names_ext_ptx[i]

            data_extracted_plot_ptx[i] = scatter(;  x           =  x,
                                                    y           =  Z[i,:],
                                                    name        = display_ph_name(ph_names_ext_ptx[i]),
                                                    stackgroup  = "one",
                                                    mode        = "lines",
                                                    line        = attr(     width   =  1.0,
                                                                            color   = get_phase_color(ph))  )
        end
    elseif ext_mode == "bars"

        if isentropic_mode == true

            if n_tot > 128
                k = ceil(Int, n_tot / 128)  # Step size to reduce to ~128 points
                indices = 1:k:n_tot
                x_sampled = x[indices]
                Z_sampled = Z[:, indices]
                println(" WARNING: large number of steps for isentropic paths leads to improper bar plots... (PlotlyJS unsolved issue)" )
                println(" Downsampling bar plot from $n_tot to $(length(indices)) points... (csv output remains correct)" )
            else
                x_sampled = x
                Z_sampled = Z
            end

            for i=1:n_ph_e
                ph = ph_names_ext_ptx[i]
                data_extracted_plot_ptx[i] = bar(   x           =  x_sampled,
                                                    y           =  Z_sampled[i,:],
                                                    name        = display_ph_name(ph_names_ext_ptx[i]),
                                                    marker      = attr( color   = get_phase_color(ph),
                                                                        line    = attr(width=0.0, color="black"),
                                                                        opacity = 0.6) # black outline
                                                )
            end

        else
            for i=1:n_ph_e

                ph      = ph_names_ext_ptx[i]

                data_extracted_plot_ptx[i] = bar(   x           =  x,
                                                    y           =  Z[i,:],
                                                    name        = display_ph_name(ph_names_ext_ptx[i]),
                                                    marker      = attr( color   = get_phase_color(ph),
                                                                        line    = attr(width=0.0, color="black"),
                                                                        opacity = 0.6) # black outline
                                                )
            end
        end
    else
        for i=1:n_ph_e

            ph      = ph_names_ext_ptx[i]

            data_extracted_plot_ptx[i] = scatter(;  x           =  x,
                                                    y           =  Z[i,:],
                                                    name        = display_ph_name(ph_names_ext_ptx[i]),
                                                    mode        = "lines",
                                                    marker = attr(
                                                        size    = 5.0,          # Set the size of the circle
                                                        color   = get_phase_color(ph),      # Set the color of the circle
                                                        symbol  = "circle-open", # Use an open circle marker
                                                        opacity = 0.6           # Set the transparency (0.0 = fully transparent, 1.0 = fully opaque)
                                                    ),
                                                    line        = attr(     width   = 1.0,
                                                                            color   = get_phase_color(ph))   )
         end
    end

    # build phase list:
    phase_list_ext = [Dict("label" => "  "*display_ph_name(ph_names_ext_ptx[i]), "value" => ph_names_ext_ptx[i]) for i=1:n_ph_e]

    return data_extracted_plot_ptx, phase_list_ext
end

"""
    function get_data_comp_plot(sysunit,phases)

    Gets the composition of selected stable phases accross the PTX paths and create a scatter plot
"""
function get_data_comp_plot(sysunit,phases)

    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_ph    = length(phases)
    n_tot   = length(Out_PTX)

    data_comp_plot  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ox);
    x               = Vector{Union{String,Missing}}(undef, (n_tot+1)*n_ph)
    compo_matrix    = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1)*n_ph) .= missing
    colormap        = get_jet_colormap(n_ox)
 
    k = 1
    for i=1:n_ph
        ph      = phases[i]
        for j=1:n_tot
            
            x[k]    = string(round(display_pressure(Out_PTX[j].P_kbar),digits=1))*"; "*string(round(Out_PTX[j].T_C,digits=1))
            id      = findall(Out_PTX[j].ph .== ph)
            if ~isempty(id)
                n_solvi = length(id)
                if sysunit == "mol"
                    
                    if n_solvi > 1      # then this is a solution phase as there is a solvus
                        if ismissing(compo_matrix[1,k])
                            compo_matrix[:,k] .= 0.0
                        end
                        for n=1:n_solvi
                            compo_matrix[:,k] += Out_PTX[j].SS_vec[id[n]].Comp ./ Float64(n_solvi) .*100.0
                        end
                        
                    else
                        id      = id[1]
                        n_SS    = Out_PTX[j].n_SS
                        if id > n_SS    # then this is a pure phase
                            compo_matrix[:,k] = Out_PTX[j].PP_vec[id - n_SS].Comp .*100.0
                        else            # else this is a solution phase
                            compo_matrix[:,k] = Out_PTX[j].SS_vec[id].Comp .*100.0
                        end

                    end

                elseif sysunit == "wt"
                    if n_solvi > 1      # then this is a solution phase as there is a solvus
                        if ismissing(compo_matrix[1,k])
                            compo_matrix[:,k] .= 0.0
                        end
                        for n=1:n_solvi
                            compo_matrix[:,k] += Out_PTX[j].SS_vec[id[n]].Comp_wt ./ Float64(n_solvi) .*100.0
                        end
                    else
                        id      = id[1]
                        n_SS    = Out_PTX[j].n_SS
                        if id > n_SS    # then this is a pure phase
                            compo_matrix[:,k] = Out_PTX[j].PP_vec[id - n_SS].Comp_wt .*100.0
                        else            # else this is a solution phase
                            compo_matrix[:,k] = Out_PTX[j].SS_vec[id].Comp_wt .*100.0
                        end

                    end

                end
            else                    # else the phase is not stable therefore we don't fill the array
                compo_matrix[:,k] .= missing
            end
            k+=1
        
        end
        x[k]    = missing
        compo_matrix[:,k] .= missing
        k+=1

    end 

    for k=1:n_ox

        data_comp_plot[k] = scatter(;   x           =  x,
                                        y           =  compo_matrix[k,:],
                                        name        = oxides[k],
                                        mode        = "markers+lines",
                                        marker = attr(
                                            size    = 5.0,          # Set the size of the circle
                                            color   = colormap[k],      # Set the color of the circle
                                            symbol  = "circle-open", # Use an open circle marker
                                            opacity = 0.5           # Set the transparency (0.0 = fully transparent, 1.0 = fully opaque)
                                        ),
                                        line        = attr(     width   = 1.0,
                                                                color   = colormap[k])  )
    end


    return data_comp_plot
end


function get_data_comp_rm_plot()

    global removedBulk

    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_tot   = length(Out_PTX)

    data_comp_rm_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ox+2);
    x                   = Vector{String}(undef, n_tot)
    colormap            = get_jet_colormap(n_ox)
 
    for k=1:n_tot
        x[k]    = string(round(display_pressure(Out_PTX[k].P_kbar),digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
    end

    rmB      = Matrix{Union{Float64,Missing}}(undef, n_tot, n_ox) .= 0.0
    rmB     .= removedBulk
    if any(isnan, rmB)
        rmB[isnan.(rmB)]         .= 0.0
    end
    rmB[rmB .== 0.0]        .= missing
    for k=1:n_ox
        data_comp_rm_plot[k] = scatter(;    x           = x,
                                            y           = rmB[:,k].*100.0,
                                            name        = oxides[k],
                                            mode        = "markers+lines",
                                            marker = attr(
                                                size    = 5.0,          # Set the size of the circle
                                                color   = colormap[k],      # Set the color of the circle
                                                symbol  = "circle-open", # Use an open circle marker
                                                opacity = 0.5           # Set the transparency (0.0 = fully transparent, 1.0 = fully opaque)
                                            ),
                                            line        = attr(     width   = 1.0,
                                                                    color   = colormap[k])  )
    end
    data_comp_rm_plot[n_ox+1] = scatter(    x               = x,
                                            name            = "removed %",
                                            y               = fracEvol[:,2].*100.0, 
                                            hoverinfo       = "skip",
                                            mode            = "lines",
                                            line            = attr( dash    = "dash",
                                                                    color   = "black", 
                                                                    width   = 0.75)                ) 

    data_comp_rm_plot[n_ox+2] = scatter(    x               = x,
                                            y               = fracEvol[:,1].*100.0, 
                                            name            = "remaining %",
                                            hoverinfo       = "skip",
                                            mode            = "lines",
                                            line            = attr( color   = "black", 
                                                                    width   = 0.75)                ) 
    return data_comp_rm_plot
end


function get_data_comp_rm_int_plot()

    global removedBulk, fracEvol

    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_tot   = length(Out_PTX)

    data_comp_rm_in_plot   = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ox+2);
    x                   = Vector{String}(undef, n_tot)
    colormap            = get_jet_colormap(n_ox)
 
    for k=1:n_tot
        x[k]    = string(round(display_pressure(Out_PTX[k].P_kbar),digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
    end

    rmB      = Matrix{Union{Float64,Missing}}(undef, n_tot, n_ox) .= 0.0
    cumfrac  = accumulate(+, fracEvol[:,2])
    start_id = findfirst(removedBulk[:,1] .!= 0.0)

    if isnothing(start_id)
        rmB .= missing
    else
        rmB[start_id,:]    .= removedBulk[start_id,:]
        for i=start_id+1:n_tot
            tmp = removedBulk[i,:] .* fracEvol[i,2] .+  rmB[i-1,:].*cumfrac[i-1]
            rmB[i,:] .= tmp ./sum(tmp)
        end
        if any(isnan, rmB)
            rmB[isnan.(rmB)]         .= 0.0
        end
        rmB[rmB .== 0.0]        .= missing
    end
    

    for k=1:n_ox
        data_comp_rm_in_plot[k] = scatter(;     x           = x,
                                                y           = rmB[:,k].*100.0,
                                                name        = oxides[k],
                                                mode        = "markers+lines",
                                                marker = attr(
                                                    size    = 5.0,          # Set the size of the circle
                                                    color   = colormap[k],      # Set the color of the circle
                                                    symbol  = "circle-open", # Use an open circle marker
                                                    opacity = 0.5           # Set the transparency (0.0 = fully transparent, 1.0 = fully opaque)
                                                ),
                                                line        = attr(     width   = 1.0,
                                                                        color   = colormap[k])  )
    end
    data_comp_rm_in_plot[n_ox+1] = scatter( x               = x,
                                            name            = "removed %",
                                            y               = fracEvol[:,2].*100.0, 
                                            hoverinfo       = "skip",
                                            mode            = "lines",
                                            line            = attr( dash    = "dash",
                                                                    color   = "black", 
                                                                    width   = 0.75)                ) 

     data_comp_rm_in_plot[n_ox+2] = scatter(    x               = x,
                                                y               = fracEvol[:,1].*100.0, 
                                                name            = "remaining %",
                                                hoverinfo       = "skip",
                                                mode            = "lines",
                                                line            = attr( color   = "black", 
                                                                        width   = 0.75)                ) 

    return data_comp_rm_in_plot
end


# ------------------------------------------------ LAYOUTS ------------------------------------------------#
function initialize_rm_layout(calcUnit = "mol")
    ytitle         = "Oxide fraction [$(calcUnit)%]"
    layout_rm_ptx  = Layout(

        title= attr(
            text    = "",
            x       = 0.5,
            y       = 1.10,
            xanchor = "center",
            yanchor = "top"
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=24),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "P-T conditions [$(pressure_unit_label()), °C]",
        yaxis_title = ytitle,
        height      = 360,
        xaxis       = attr(
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the bottom axis line color
            linewidth     = 1       # Set the thickness of the axis line
        ),
        yaxis       = attr(
            autorange     = false,
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the left axis line color
            linewidth     = 1,       # Set the thickness of the axis line
            range         = [0.0, 100.0]
        ),
    )

    return layout_rm_ptx
end


function initialize_layout(title,sysunit)
    ytitle               = "Phase fraction ["*sysunit*"%]"
    layout_ptx  = Layout(
        barmode     = "stack",
        bargap      = 0,        # No gap between bars
        bargroupgap = 0,        # No gap between bar groups
        title= attr(
            text    = title,
            x       = 0.5,
            y       = 1.10,
            xanchor = "center",
            yanchor = "top",
            font    = attr(
                size  = 14,
            )
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=24),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "P-T conditions [$(pressure_unit_label()), °C]",
        yaxis_title = ytitle,
        height      = 360,
        xaxis       = attr(
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the bottom axis line color
            linewidth     = 1       # Set the thickness of the axis line
        ),
        yaxis       = attr(
            autorange     = false,
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the left axis line color
            linewidth     = 1,       # Set the thickness of the axis line
            range         = [0.0, 100.0]
        ),
    )

    return layout_ptx
end


"""
    initialize_field_layout(title, ytitle)

Layout for the PTX path "selected field across path" plot. Unlike the
phase-fraction plots, the y-axis is not a 0-100% scale (fields like
density, Vp, entropy, ... each have their own range), so autorange is left on.
"""
function initialize_field_layout(title, ytitle)
    layout_field  = Layout(
        title= attr(
            text    = title,
            x       = 0.5,
            y       = 1.10,
            xanchor = "center",
            yanchor = "top",
            font    = attr(
                size  = 14,
            )
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=24),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "P-T conditions [$(pressure_unit_label()), °C]",
        yaxis_title = ytitle,
        height      = 360,
        showlegend  = false,
        xaxis       = attr(
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the bottom axis line color
            linewidth     = 1       # Set the thickness of the axis line
        ),
        yaxis       = attr(
            autorange     = true,
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the left axis line color
            linewidth     = 1,       # Set the thickness of the axis line
        ),
    )

    return layout_field
end


"""
    get_ptx_field_plot(fieldname::String)

Samples a single system-level field (see `field_dropdown_options()` /
`OTHER_FIELD_LABELS`, PhaseDiagram_functions.jl) at every step of the
computed PTX path, reusing `get_other_field_value` (the same per-point
extractor the Phase Diagram tab's "draw path field profile" uses). "Hash"
is handled separately here since it only becomes a meaningful small integer
once mapped against the *other* assemblages seen along this path.
"""
function get_ptx_field_plot(fieldname::String)

    n_tot   = length(Out_PTX)
    x       = Vector{String}(undef, n_tot)
    y       = Vector{Float64}(undef, n_tot)

    for k = 1:n_tot
        x[k] = string(round(display_pressure(Out_PTX[k].P_kbar),digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
    end

    if fieldname == "Hash"
        raw_hash    = [hash(sort(Out_PTX[k].ph)) for k = 1:n_tot]
        uniq_hash   = unique(raw_hash)
        y          .= [Float64(findfirst(==(h), uniq_hash)) for h in raw_hash]
    else
        y          .= [get_other_field_value(Out_PTX[k], fieldname) for k = 1:n_tot]
    end

    trace = scatter(;   x       = x,
                        y       = y,
                        mode    = "markers+lines",
                        marker  = attr(size = 5.0, color = "black", symbol = "circle-open", opacity = 0.5),
                        line    = attr(width = 0.75, color = "black"),
                        name    = get(OTHER_FIELD_LABELS, fieldname, fieldname),
                    )

    return GenericTrace[trace]
end


function initialize_ext_layout(title,sysunit)
    ytitle               = "Exrtacted phase fraction ["*sysunit*"%]"
    
    layout_ext_ptx  = Layout(
        barmode     = "stack",
        bargap      = 0,        # No gap between bars
        bargroupgap = 0,        # No gap between bar groups
        title= attr(
            text    = title,
            x       = 0.5,
            y       = 1.10,
            xanchor = "center",
            yanchor = "top",
            font    = attr(
                size  = 14, 
            )
        ),
        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=24),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "P-T conditions [$(pressure_unit_label()), °C]",
        yaxis_title = ytitle,

        height      = 360,
        xaxis       = attr(
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the bottom axis line color
            linewidth     = 1       # Set the thickness of the axis line
        ),
        yaxis       = attr(
            autorange     = false,
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the left axis line color
            linewidth     = 1,       # Set the thickness of the axis line
            range         = [0.0, 100]
        ),
    )

    return layout_ext_ptx
end

function initialize_comp_layout(sysunit)
    ytitle               = "oxide fraction ["*sysunit*"%]"
    layout_comp  = Layout(


        margin      = attr(autoexpand = false, l=16, r=16, b=16, t=24),
        hoverlabel = attr(
            bgcolor     = "#566573",
            bordercolor = "#f8f9f9",
        ),
        plot_bgcolor = "#FFF",
        paper_bgcolor = "#FFF",
        xaxis_title = "P-T conditions [$(pressure_unit_label()), °C]",
        yaxis_title = ytitle,

        height      = 360,
        xaxis       = attr(
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the bottom axis line color
            linewidth     = 1       # Set the thickness of the axis line
        ),
        yaxis       = attr(
            autorange     = false,
            fixedrange    = true,
            showgrid      = false,  # Disable gridlines inside the plot
            zeroline      = true,   # Show the axis line
            linecolor     = "black", # Set the left axis line color
            linewidth     = 1,       # Set the thickness of the axis line
            range         = [0.0, 100]
        ),
    )

    return layout_comp
end