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

"""
    Retrieve AFM diagram
"""
function get_AFM()

    global Out_PTX;

    n_ox    = length(Out_PTX[1].oxides)
    oxides  = Out_PTX[1].oxides
    n_tot   = length(Out_PTX)

    liq_afm        = Matrix{Union{Float64,Missing}}(undef, n_ox, (n_tot+1))    .= missing
    liq_wt          = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    liq_P           = Vector{Union{Float64,Missing}}(undef, (n_tot+1))          .= missing
    colormap        = get_jet_colormap(n_tot+1)
 
    for j=1:n_tot
        id      = findall(Out_PTX[j].ph .== "liq")
        if ~isempty(id)
            liq_afm[:,j] = Out_PTX[j].SS_vec[id[1]].Comp_wt .*100.0
            liq_wt[j]    = Out_PTX[j].ph_frac_wt[id[1]]
            liq_P[j]     = Out_PTX[j].P_kbar
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
function get_TAS_diagram(phases,title)

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
    colormap        = get_jet_colormap(n_tot+1)
 
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
                            showscale   = false,
                            showlegend  = false,
                            marker      = attr(     size        = fracEvol[:,1].*15.0 .+ 6.0,
                                                    color       = colormap,
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

    layout_ptx  = Layout(

        title= attr(
            text    = title,
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
        xaxis_title = "SiO2 [wt%]",
        yaxis_title = "K2O + Na2O [wt%]",
        xaxis_range = [35.0, 85.0], 
        # yaxis_range = [0.0,15.0],
        annotations = annotations,
        width       = 760,
        height      = 480,
        xaxis       = attr(
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
function get_TAS_pluto_diagram(phases,title)

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
    colormap        = get_jet_colormap(n_tot+1)
 
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
                            showscale   = false,
                            showlegend  = false,
                            marker      = attr(     size        = fracEvol[:,1].*15.0 .+ 6.0,
                                                    color       = colormap,
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

    layout_ptx  = Layout(

        title= attr(
            text    = title,
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
        xaxis_title = "SiO2 [wt%]",
        yaxis_title = "K2O + Na2O [wt%]",
        xaxis_range = [35.0, 85.0], 
        # yaxis_range = [0.0,15.0],
        annotations = annotations,
        width       = 760,
        height      = 480,
        xaxis       = attr(
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

        LibMAGEMin.FreeDatabases(gv, DB, z_b)

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

        LibMAGEMin.FreeDatabases(gv, DB, z_b)

        Tsol  = string(   round((a+b)/2.0,digits=2) )
    else
        print("Cannot compute solidus temperature if liq is removed from the solution phase list\n") 
        Tsol        = ""
    end

    return Tsol
end




function compute_new_PTXpath(   nsteps,     PTdata,     mode,       bulk_ini,   bulk_assim, oxi,    phase_selection,    assim, var_buffer,
                                dtb,        dataset,    bufferType, solver,
                                verbose,    bufferN,
                                cpx,        limOpx,     limOpxVal,
                                nCon,       nRes                                  )

        global Out_PTX, ph_names_ptx, fracEvol, compo_matrix, removedBulk


        nsteps = Int64(nsteps)

        mbCpx,limitCaOpx,CaOpxLim,sol = get_init_param( dtb,        solver,
                                                        cpx,        limOpx,     limOpxVal ) 

        # retrieve PTX path
        data    = copy(PTdata)
        np      = length(data)

        if np <= 1
            print("Cannot compute a path if at least 2 points are not defined! \n")
        else
            ph_names_ptx= Vector{String}()

            n_tot       = np + (np-1)*nsteps
            fracEvol    = Matrix{Float64}(undef,n_tot,2)
            removedBulk = Matrix{Float64}(undef,n_tot,length(bulk_ini))
            Out_PTX     = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n_tot)

            Pres        = zeros(Float64,np)
            Temp        = zeros(Float64,np)
            Add         = zeros(Float64,np)
            Buff        = zeros(Float64,np)

            for i=1:np
                Pres[i] = data[i][Symbol("col-1")]
                Temp[i] = data[i][Symbol("col-2")]
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
    
            # define system unit and starting bulk rock composition
            sys_in  = "mol"
            bulk    = copy(bulk_ini)

            if assim == "true"
                 bulk   .= (1.0 - Add[1]) .* bulk + Add[1].* bulk_assim
            end

            gv      =  define_bulk_rock(gv, bulk, oxi, sys_in, dtb);

            fracEvol[1,1]            = 1.0;          # starting material fraction is always one as we want to measure the relative change here
            fracEvol[1,2]            = 0.0; 
            removedBulk[1,:]        .= zeros(length(bulk_ini))
            k = 1
            @showprogress for i = 1:np-1
                # if we assimilate a second bulk then we compute the assimilated fraction per step
                if assim == "true"
                    A       = Add[i+1]
                    val     = A / (1.0 - A)
                    step    = val/(nsteps+1)
                end

                for j = 1:nsteps+1
                    P = Pres[i] + (j-1)*( (Pres[i+1] - Pres[i])/ (nsteps+1) )
                    T = Temp[i] + (j-1)*( (Temp[i+1] - Temp[i])/ (nsteps+1) )

                    if var_buffer == true
                        bufferN = Buff[i] + (j-1)*( (Buff[i+1] - Buff[i])/ (nsteps+1) )
                    end

                    if assim == "true"
                        bulk   .= (1.0 .- step ./ (1.0 .+ step .* j)) .* bulk .+ (step ./ (1.0 .+ step .* j)) .* bulk_assim
                    end
                        gv      =  define_bulk_rock(gv, bulk, oxi, sys_in, dtb);

                    Out_PTX[k] = deepcopy( point_wise_minimization(P,T, gv, z_b, DB, splx_data, sys_in; buffer_n=bufferN, rm_list=phase_selection, name_solvus=true) )

                    if mode == "fm"
                        if Out_PTX[k].frac_S > 0.0
                            if nCon > 0.0
                                if Out_PTX[k].frac_M > nCon/100.0
                                    bulk                .= Out_PTX[k].bulk_S .*((100.0-nCon)/100.0) .+ Out_PTX[k].bulk_M .*(nCon/100.0)
                                    removedBulk[k+1,:]  .= Out_PTX[k].bulk_S .*(nCon/100.0) .+ Out_PTX[k].bulk_M .*((100.0-nCon)/100.0)
                                    fracEvol[k+1,1]      = fracEvol[k,1] * (Out_PTX[k].frac_S + Out_PTX[k].frac_F + nCon/100.0) 
                                    fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                                else
                                    removedBulk[k+1,:]  .= zeros(length(bulk_ini))
                                    fracEvol[k+1,1]      = fracEvol[k,1]
                                    fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                                end
                            else
                                bulk                .= Out_PTX[k].bulk_S
                                removedBulk[k+1,:]  .= zeros(length(bulk_ini))
                                fracEvol[k+1,1]      = fracEvol[k,1]
                                fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                            end
                        else
                            removedBulk[k+1,:]    .= zeros(length(bulk_ini))
                            fracEvol[k+1,1]      = fracEvol[k,1]
                            fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                        end
                    elseif mode == "fc"
                        if Out_PTX[k].frac_M > 0.0

                            if nRes > 0.0
                                if Out_PTX[k].frac_S > nRes/100.0
                                    bulk                .= Out_PTX[k].bulk_M .*((100.0-nRes)/100.0) .+ Out_PTX[k].bulk_S .*(nRes/100.0)
                                    removedBulk[k+1,:]  .= Out_PTX[k].bulk_M .*(nRes/100.0) .+ Out_PTX[k].bulk_S .*((100.0-nRes)/100.0)
                                    fracEvol[k+1,1]      = fracEvol[k,1] * (Out_PTX[k].frac_M - nRes/100.0)     #removed
                                    fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1]                                #remained
                                else
                                    fracEvol[k+1,1]      = fracEvol[k,1] * (Out_PTX[k].frac_M - Out_PTX[k].frac_S) 
                                    fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                                end
                            else
                                bulk                .= Out_PTX[k].bulk_M
                                removedBulk[k+1,:]  .= Out_PTX[k].bulk_S
                                fracEvol[k+1,1]      = fracEvol[k,1] * (Out_PTX[k].frac_M) 
                                fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                            end
                        else
                            removedBulk[k+1,:]  .= zeros(length(bulk_ini))
                            fracEvol[k+1,1]      = fracEvol[k,1]
                            fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                        end
                    else
                        removedBulk[k+1,:]  .= zeros(length(bulk_ini))
                        fracEvol[k+1,1]      = fracEvol[k,1]
                        fracEvol[k+1,2]      = 1.0 - fracEvol[k+1,1] 
                    end

                    k += 1
                end
            end

            fracEvol[fracEvol .< 0.0] .= 0.0

            
            Out_PTX[k] = deepcopy( point_wise_minimization(Pres[np],Temp[np], gv, z_b, DB, splx_data, sys_in; buffer_n=Buff[np], rm_list=phase_selection, name_solvus=true) )
  
            for k = 1:n_tot
                for l=1:length(Out_PTX[k].ph)
                    if ~(Out_PTX[k].ph[l] in ph_names_ptx)
                        push!(ph_names_ptx,Out_PTX[k].ph[l])
                    end
                end
            end
            ph_names_ptx = sort(ph_names_ptx)

            # free MAGEMin
            LibMAGEMin.FreeDatabases(gv, DB, z_b)
        end

end

function get_data_plot(display_mode, sysunit)

    n_ph    = length(ph_names_ptx)
    n_tot   = length(Out_PTX)
    data_plot_ptx  = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n_ph+2);

    x       = Vector{String}(undef, n_tot)
    Y       = zeros(Float64, n_ph, n_tot)

    colormap = get_jet_colormap(n_ph)
    
    for i=1:n_ph

        ph = ph_names_ptx[i]
        for k=1:n_tot
            
            x[k]    = string(round(Out_PTX[k].P_kbar,digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
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
            ph      = ph_names_ptx[i]

            data_plot_ptx[i] = scatter(;    x           =  x,
                                            y           =  Y[i,:],
                                            name        = ph_names_ptx[i],
                                            stackgroup  = "one",
                                            mode        = "lines",
                                            line        = attr(     width   =  0.5,
                                                                    color   = AppData.mineral_style[1][ph][1])  )
        end
    else 
        for i=1:n_ph
            ph      = ph_names_ptx[i]

            data_plot_ptx[i] = scatter(;    x           =  x,
                                            y           =  Y[i,:],
                                            name        = ph_names_ptx[i],
                                            mode        = "markers+lines",
                                            marker = attr(
                                                size    = 5.0,          # Set the size of the circle
                                                color   = AppData.mineral_style[1][ph][1],      # Set the color of the circle
                                                symbol  = "circle-open", # Use an open circle marker
                                                opacity = 0.5           # Set the transparency (0.0 = fully transparent, 1.0 = fully opaque)
                                            ),
                                            line        = attr(     width   = 0.75,
                                                                    color   = AppData.mineral_style[1][ph][1])  )
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
    phase_list = [Dict("label" => "  "*ph_names_ptx[i], "value" => ph_names_ptx[i]) for i=1:n_ph]


    return data_plot_ptx, phase_list
end


function get_extracted_data_plot(ext_mode,sysunit,mode,nRes,nCon)

    n_ph    = length(ph_names_ptx)
    n_tot   = length(Out_PTX)

    ph_names_ext_ptx = []
    for i in ph_names_ptx
        if i != "liq"
            push!(ph_names_ext_ptx,i)
        end
    end

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
            
            x[k]    = string(round(Out_PTX[k].P_kbar, digits=1))*"; "*string(round(Out_PTX[k].T_C, digits=1))
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
                                                    name        = ph_names_ext_ptx[i],
                                                    stackgroup  = "one",
                                                    mode        = "lines",
                                                    line        = attr(     width   =  1.0,
                                                                            color   = AppData.mineral_style[1][ph][1])  )
        end
    else 
        for i=1:n_ph_e

            ph      = ph_names_ext_ptx[i]

            data_extracted_plot_ptx[i] = scatter(;  x           =  x,
                                                    y           =  Z[i,:],
                                                    name        = ph_names_ext_ptx[i],
                                                    mode        = "markers+lines",
                                                    marker = attr(
                                                        size    = 5.0,          # Set the size of the circle
                                                        color   = AppData.mineral_style[1][ph][1],      # Set the color of the circle
                                                        symbol  = "circle-open", # Use an open circle marker
                                                        opacity = 0.5           # Set the transparency (0.0 = fully transparent, 1.0 = fully opaque)
                                                    ),
                                                    line        = attr(     width   = 1.0,
                                                                            color   = AppData.mineral_style[1][ph][1])   )
         end
    end

    # build phase list:
    phase_list_ext = [Dict("label" => "  "*ph_names_ext_ptx[i], "value" => ph_names_ext_ptx[i]) for i=1:n_ph_e]

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
            
            x[k]    = string(round(Out_PTX[j].P_kbar,digits=1))*"; "*string(round(Out_PTX[j].T_C,digits=1))
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
        x[k]    = string(round(Out_PTX[k].P_kbar,digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
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
        x[k]    = string(round(Out_PTX[k].P_kbar,digits=1))*"; "*string(round(Out_PTX[k].T_C,digits=1))
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
function initialize_rm_layout()
    ytitle         = "Oxide fraction [mol%]"
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
        xaxis_title = "P-T conditions [kbar, °C]",
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
        xaxis_title = "P-T conditions [kbar, °C]",
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




function initialize_ext_layout(title,sysunit)
    ytitle               = "Fractionated phase fraction ["*sysunit*"%]"
    layout_ext_ptx  = Layout(

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
        xaxis_title = "P-T conditions [kbar, °C]",
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
        xaxis_title = "P-T conditions [kbar, °C]",
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

    return layout_comp
end