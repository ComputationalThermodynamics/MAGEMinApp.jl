"""
    export_rho_for_LaMEM()
    This function export a density diagram in the the right format to be directly used in LaMEM
"""
function save_rho_for_LaMEM(    dtb         ::String,
                                sub         ::Int64,
                                refLvl      ::Int64,
                                Xrange,
                                Yrange,
                                bulk1                  )

    np          = length(Out_XY)

    field2save  = ["rho_M","rho_S","frac_M"]
    ncol        = length(field2save)
    field       = Matrix{Union{Float64,Missing}}(undef,np,ncol);

    for j=1:ncol
        for i=1:np
            field[i,j] = Float64(get_property(Out_XY[i], field2save[j]));
        end
    end

    n            = 2^(sub + refLvl + addedRefinementLvl)
    x            = range(minimum(data.xc), stop = maximum(data.xc), length = n)
    y            = range(minimum(data.yc), stop = maximum(data.yc), length = n)

    T            = vcat(x)
    P            = vcat(y)
    gridded      = Array{Union{Float64,Missing}}(undef,n,n,ncol);

    Xr           = (Xrange[2]-Xrange[1])/n
    Yr           = (Yrange[2]-Yrange[1])/n

    for l=1:ncol
        for k=1:np
            for i=data.x[k][1]+Xr/2 : Xr : data.x[k][3]
                for j=data.y[k][1]+Yr/2 : Yr : data.y[k][3]
                    ii                  = Int64(round((i-Xrange[1] + Xr/2)/(Xr)))
                    jj                  = Int64(round((j-Yrange[1] + Yr/2)/(Yr)))
                    gridded[ii,jj,l]    = field[k,l]
                end
            end
        end
    end

    # filter some potential iffy values
    rho_S_min                        = minimum(gridded[:,:,2])
    rho_M_min                        = minimum(gridded[:,:,1])

    gridded[gridded[:,:,2] .== 0.0,2] .= 3000.0
    gridded[isnan.(gridded[:,:,2]),2] .= 3000.0
    gridded[gridded[:,:,1] .== 0.0,1] .= 2000.0
    gridded[isnan.(gridded[:,:,1]),1] .= 2000.0
    gridded[gridded[:,:,3] .> 1.0,3] .= 1.0

    # convert values
    T      .= T .+ 273.15            # --> to K
    P      .= P .* 1e3               # --> to bar

    nT      =  length(x)
    nP      =  length(y)
    dT      = (maximum(x)-minimum(x))/(nT-1);
    dP      = (maximum(y)-minimum(y))/(nP-1)*1000.0;

    # retrieve bulk rock composition and associated oxide list
    n_ox    = length(bulk1);
    bulk    = zeros(n_ox); 
    oxi     = Vector{String}(undef, n_ox)
    for i=1:n_ox
        tmp = bulk1[i][:mol_fraction]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        bulk[i]   = tmp;
        oxi[i]    = bulk1[i][:oxide];
    end

    file        = ""
    file       *= @sprintf("5\n")
    file       *= @sprintf("\n")
    file       *= @sprintf("Phase diagram always needs this 5 columns:\n")
    file       *= @sprintf("       1               2                     3            4        5\n");
    file       *= @sprintf("rho_melt[kg/m3]   melt_fraction[wt]   rho_solid[kg/m3]   T[K]   P[bar]\n");
    file       *= @sprintf("1-49:  Comments\n");
    file       *= @sprintf("50:    Lowest T [K]\n");
    file       *= @sprintf("51:    T increment\n");
    file       *= @sprintf("52:    # of T values\n");
    file       *= @sprintf("53:    Lowest P [K]\n");
    file       *= @sprintf("54:    P increment\n");
    file       *= @sprintf("55:    # of P values\n");

    for i=1:4
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("Phase diagram produced using MAGEMin v%s with database %5s\n",Out_XY[1].MAGEMin_ver,dtb)
    file       *= @sprintf("Bulk rock composition[mol fraction]\n")
    for i=1:n_ox
        file   *= @sprintf("%8s : %+5.10f\n",oxi[i],bulk[i])
    end
    for i=n_ox+1:11
        file   *= @sprintf("\n")
    end
    for i=1:20
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("%5.10f\n",minimum(T));
    file       *= @sprintf("%5.10f\n",dT);
    file       *= @sprintf("%d\n",nT);
    file       *= @sprintf("%5.10f\n",minimum(P));
    file       *= @sprintf("%5.10f\n",dP);
    file       *= @sprintf("%d\n",nP);
    for j=1:nP
        for i=1:nT
            file   *= @sprintf("%5.6f %5.6f %5.6f %5.6f %5.6f\n",gridded[i,j,1],gridded[i,j,3],gridded[i,j,2],T[i],P[j])
        end
    end


    return file
end


"""
    save equilibrium function
"""
function save_equilibrium_to_file(  out::MAGEMin_C.gmin_struct{Float64, Int64}  )

    file = ""
    file *= @sprintf("============================================================\n")
    for i=1:length(out.ph)
        file *= @sprintf(" %4s ",out.ph[i])
    end
    file *= @sprintf(" {%.4f %.4f} kbar/°C\n\n",out.P_kbar,out.T_C)

    file *= @sprintf("End-members fractions[wt fr]:\n")
    for i=1:out.n_SS
        for j=1:length(out.SS_vec[i].emNames)
            file *= @sprintf(" %8s",out.SS_vec[i].emNames[j])
        end
        file *= @sprintf("\n")
        for j=1:length(out.SS_vec[i].emFrac_wt)
            file *= @sprintf(" %8f",out.SS_vec[i].emFrac_wt[j])
        end
        file *= @sprintf("\n")        
    end
    file *= @sprintf("\n") 


    file *= @sprintf("Oxide compositions [wt fr]:\n")
    file *= @sprintf("% 8s"," ") 
    for i=1:length(out.oxides)
        file *= @sprintf(" %8s",out.oxides[i]) 
    end
    file *= @sprintf("\n")   
    file *= @sprintf(" %8s","SYS") 
    for i=1:length(out.bulk_wt)
        file *= @sprintf(" %8f",out.bulk_wt[i])
    end
    file *= @sprintf("\n")  
    for i=1:out.n_SS
        file *= @sprintf(" %8s",out.ph[i])
        for j=1:length(out.SS_vec[i].Comp_wt)
            file *= @sprintf(" %8f",out.SS_vec[i].Comp_wt[j])
        end
        file *= @sprintf("\n")  
    end
    for i=1:out.n_PP
        file *= @sprintf(" %8s",out.ph[i+out.n_SS])
        for j=1:length(out.PP_vec[i].Comp_wt)
            file *= @sprintf(" %8f",out.PP_vec[i].Comp_wt[j])
        end
        file *= @sprintf("\n")  
    end
    file *= @sprintf("\n")  

    file *= @sprintf("Stable mineral assemblage:\n")    
    file *= @sprintf("%6s%15s %13s %17s %17s %12s %12s %12s %12s %12s %12s %12s %12s %12s\n","phase","fraction[wt]","G[kJ]" ,"V_molar[cm3/mol]","V_partial[cm3]" ,"Cp[kJ/K]","Rho[kg/m3]","Alpha[1/K]","Entropy[J/K]","Enthalpy[J]","BulkMod[GPa]","ShearMod[GPa]","Vp[km/s]","Vs[km/s]")
   
    for i=1:out.n_SS
        file *= @sprintf("%6s",out.ph[i])
        file *= @sprintf("%+15.5f %+13.5f %+17.5f %+17.5f %+12.5f %+12.5f %+12.8f %+12.6f %+12.4f %+12.2f %+12.2f %+13.2f %+12.2f",
                        out.ph_frac_wt[i],
                        out.SS_vec[i].G,
                        out.SS_vec[i].V,
                        out.SS_vec[i].V*out.ph_frac[i]*out.SS_vec[i].f,
                        out.SS_vec[i].cp,
                        out.SS_vec[i].rho,
                        out.SS_vec[i].alpha,
                        out.SS_vec[i].entropy,
                        out.SS_vec[i].enthalpy,
                        out.SS_vec[i].bulkMod,
                        out.SS_vec[i].shearMod,
                        out.SS_vec[i].Vp,
                        out.SS_vec[i].Vs)
        file *= @sprintf("\n")  
    end

    for i=1:out.n_PP
        file *= @sprintf("%6s",out.ph[i+out.n_SS])
        file *= @sprintf("%+15.5f %+13.5f %+17.5f %+17.5f %+12.5f %+12.5f %+12.8f %+12.6f %+12.4f %+12.2f %+12.2f %+13.2f %+12.2f",
                        out.ph_frac_wt[i],
                        out.PP_vec[i].G,
                        out.PP_vec[i].V,
                        out.PP_vec[i].V*out.ph_frac[i+out.n_SS]*out.PP_vec[i].f,
                        out.PP_vec[i].cp,
                        out.PP_vec[i].rho,
                        out.PP_vec[i].alpha,
                        out.PP_vec[i].entropy,
                        out.PP_vec[i].enthalpy,
                        out.PP_vec[i].bulkMod,
                        out.PP_vec[i].shearMod,
                        out.PP_vec[i].Vp,
                        out.PP_vec[i].Vs)
        file *= @sprintf("\n")  
    end

    file *= @sprintf("%6s %14s %+13.5f %17s %+17.5f %+12.5f %+12.5f %12s %+12.6f %+12.4f %+12.5f %+12.5f %+13.5f %+12.5f\n",
                    "SYS",
                    " ",
                    out.G_system,
                    " ",    
                    0, #V
                    0, #cp
                    out.rho,
                    " ",  
                    out.entropy,
                    out.enthalpy,
                    out.bulkMod,
                    out.shearMod,
                    out.Vp,
                    out.Vs   )
    file *= @sprintf("\n")    

    file *= @sprintf("Gamma[J] (chemical potential of oxides):\n")  
    for i=1:length(out.oxides)
        file *= @sprintf(" %6s %8.3f\n",out.oxides[i],out.Gamma[i]) 
    end
    file *= @sprintf("\n") 

    file *= @sprintf("System fugacity:\n")  
    file *= @sprintf(" %6s %g\n","fO2",out.fO2)  
    file *= @sprintf(" %6s %g\n","dQFM",out.dQFM)  
    file *= @sprintf("\n\n") 

    file *= @sprintf("G-hyperplane distance[J]:\n")  
    for i=1:out.n_SS
        file *= @sprintf(" %6s %12.8f\n",out.ph[i],out.SS_vec[i].deltaG)  
    end
    file *= @sprintf("\n\n") 


    #for THERMOCALC
    file *= @sprintf("Initial guess for THERMOCALC:\n") 
    file *= @sprintf("%% ----------------------------------------------------------\n") 
    file *= @sprintf("%% at P =  %12.8f, T = %12.8f, for: ",out.P_kbar,out.T_C)
    for i=1:out.n_SS
        file *= @sprintf("%s ",out.ph[i])  
    end
    file *= @sprintf("\n") 
    file *= @sprintf("%% ----------------------------------------------------------\n") 
    file *= @sprintf("ptguess  %12.8f %12.8f\n",out.P_kbar,out.T_C) 
    file *= @sprintf("%% ----------------------------------------------------------\n")     
    n = 1;
    for i=1:out.n_SS
        for j=1:length(out.SS_vec[i].emFrac)-1
            if length(out.ph[i]) == 1
                file *= @sprintf(	"xyzguess %5s(%1s) %10f\n", out.SS_vec[i].compVariablesNames[j],out.ph[i], out.SS_vec[i].compVariables[j])
            elseif length(out.ph[i]) == 2
                file *= @sprintf(	"xyzguess %5s(%2s) %10f\n", out.SS_vec[i].compVariablesNames[j],out.ph[i], out.SS_vec[i].compVariables[j])
            elseif length(out.ph[i]) == 3
                file *= @sprintf(	"xyzguess %5s(%3s) %10f\n", out.SS_vec[i].compVariablesNames[j],out.ph[i], out.SS_vec[i].compVariables[j])
            elseif length(out.ph[i]) == 4
                file *= @sprintf(	"xyzguess %5s(%4s) %10f\n", out.SS_vec[i].compVariablesNames[j],out.ph[i], out.SS_vec[i].compVariables[j])
            elseif length(out.ph[i]) == 5
                file *= @sprintf(	"xyzguess %5s(%5s) %10f\n", out.SS_vec[i].compVariablesNames[j],out.ph[i], out.SS_vec[i].compVariables[j])
            end
        end
        if n < out.n_SS
            file *= @sprintf("%% -----------------------------\n");
        end
        n += 1
    end     
    file *= @sprintf("%% —————————————————————————————\n");

    return file
end


"""
    Function to restrict colormap range
"""
function restrict_colorMapRange(    colorMap    ::String,
                                    rangeColor  ::JSON3.Array{Int64, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}})

    n       = rangeColor[2]-rangeColor[1]
    colorm  = Vector{Vector{Any}}(undef,10)

    rin     = zeros(n+1)
    gin     = zeros(n+1)
    bin     = zeros(n+1)
    xin     = zeros(n+1)

    m       = length(colors[Symbol(colorMap)])
    cor     = Int64(floor(m/9))

    k = 1
    for i=rangeColor[1]*cor:cor:rangeColor[2]*cor
        rin[k] = colors[Symbol(colorMap)][i].r
        gin[k] = colors[Symbol(colorMap)][i].g
        bin[k] = colors[Symbol(colorMap)][i].b
        xin[k] = i
        k += 1
    end

    r_interp    = linear_interpolation(xin, rin)
    g_interp    = linear_interpolation(xin, gin)
    b_interp    = linear_interpolation(xin, bin)
    xmid        = vcat( (rangeColor[1]*cor) : (rangeColor[2]-rangeColor[1])/9.0*cor : (rangeColor[2]*cor) )

    rout        = r_interp(xmid)
    gout        = g_interp(xmid)
    bout        = b_interp(xmid)

    for i = 1:10
        ix          = 1.0/9.0 * Float64(i) - 1.0/9.0
        clr         = "rgb("*string(Int64(round(rout[i]*255)))*","*string(Int64(round(gout[i]*255)))*","*string(Int64(round(bout[i]*255)))*")"
        colorm[i]   = [ix, clr]
    end

    return colorm
end


"""
    Function to retrieve the field labels
"""
function get_diagram_labels(    fieldname   ::String,
                                oxi         ::Vector{String},
                                Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                                Hash_XY     ::Vector{UInt64},
                                sub         ::Int64,
                                refLvl      ::Int64,
                                refType     ::String,
                                xc          ::Vector{Float64},
                                yc          ::Vector{Float64},
                                PT_infos    ::Vector{String} )

    global n_lbl
    print("Get phase diagram labels ..."); t0 = time();

    np          = length(data.x)
    ph          = Vector{String}(undef,np)
    phd         = Vector{String}(undef,np)
    fac         = (maximum(xc)-minimum(xc))*(maximum(yc)-minimum(yc))
    
    if refType == "ph"
        for i = 1:np
            phd[i]      = ""
            for k=1:length(Out_XY[i].ph)
                phd[i] *= Out_XY[i].ph[k]*" "
                if k % 3 == 0
                    phd[i] *= "<br>" 
                end
            end
            ph[i]       = join(Out_XY[i].ph," ")
        end

    elseif refType == "em"
        for i = 1:np
            ph_em = get_dominant_en(    Out_XY[i].ph,
                                        Out_XY[i].n_SS,
                                        Out_XY[i].SS_vec)
            phd[i]      = ""
            for k=1:length(ph_em)
                phd[i] *= ph_em[k]*" "
                if k % 3 == 0
                    phd[i] *= "<br>" 
                end
            end
            ph[i]       = join(ph_em," ")  
        end
    end

    n_hull      = length(unique(Hash_XY))
    hull_list   = Vector{Any}(undef,    n_hull)
    ph_list     = Vector{String}(undef, n_hull)
    phd_list    = Vector{String}(undef, n_hull)
    id          = 0

    for i in unique(Hash_XY)
        field_tmp   = findall(Hash_XY .== i)
    
        t2          = xc[field_tmp]
        p2          = yc[field_tmp]
        phase       = ph[field_tmp]
        phased      = phd[field_tmp]
    
        np          = length(t2)
        if np > 2
            id             += 1
            points          = [[ t2[i]+rand()/100, p2[i]+rand()/100] for i=1:np]
            hull_list[id]   = concave_hull(points,1024)
            ph_list[id]     = phase[1]
            phd_list[id]    = phased[1]
        end
    end

    n_trace     = id;
    traces      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,n_trace+1);
    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,n_trace+3)
    labelCoor   = Matrix{Float64}(undef,n_trace,2)
    
    txt_list = ""
    cnt = 1;
    for i=1:n_trace
        
        tmp     = mapreduce(permutedims,vcat,hull_list[i].vertices)
        tmp     = vcat(tmp,tmp[1,:]')
    
        traces[i+1] = scatter(; x           =  tmp[:,1],
                                y           =  tmp[:,2],
                                fill        = "toself",
                                fillcolor   = "transparent",
                                line_width  =  0.0,
                                mode        = "lines",
                                hoverinfo   = "text",
                                showlegend  = false,
                                text        =  ph_list[i],
                                );
    
    
        np          = size(tmp,1) 
        if np > 4
            tmp2    = [tmp[i,:] for i in 1:size(tmp,1)]
            ctr     = PolygonOps.centroid(tmp2)
        else
            ctr     = zeros(2)
            ctr[1]  =  mean(tmp[2:end,1])
            ctr[2]  =  mean(tmp[2:end,2])
        end
        labelCoor[i,1]   = (ctr[1]-minimum(xc))/(maximum(xc)-minimum(xc))
        labelCoor[i,2]   = (ctr[2]-minimum(yc))/(maximum(yc)-minimum(yc))
    
        if i > 1
            for j=1:i-1
                dist = sqrt((labelCoor[i,1] - labelCoor[j,1])^2+(labelCoor[i,2] - labelCoor[j,2])^2)
            end
        end
    
        if area(hull_list[i])/fac < 0.004
            ax = -15
            ay = -15

            annotations[i] =   attr(    xref        = "x",
                                        yref        = "y",
                                        x           = ctr[1],
                                        y           = ctr[2],
                                        ax          = ax,
                                        ay          = ay,
                                        text        = string(cnt),
                                        showarrow   = true,
                                        arrowhead   = 1,
                                        visible     = true,
                                        font        = attr( size = 10, color = "#212121"),
                                    )  
            txt_list *= string(cnt)*") "*ph_list[i]*"<br>"
            cnt +=1
        elseif area(hull_list[i])/fac > 0.03 
            annotations[i] =   attr(    xref        = "x",
                                        yref        = "y",
                                        align       = "left",
                                        valign      = "top",
                                        x           = ctr[1],
                                        y           = ctr[2],
                                        text        = phd_list[i],
                                        showarrow   = false,
                                        visible     = true,
                                        font        = attr( size = 10, color = "#212121"),  
                                    )                     
        else
            annotations[i] =   attr(    xref        = "x",
                                        yref        = "y",
                                        align       = "left",
                                        valign      = "top",
                                        x           = ctr[1],
                                        y           = ctr[2],
                                        text        = string(cnt),
                                        showarrow   = false,
                                        visible     = true,
                                        font        = attr( size = 10, color = "#212121"),
                                    )  
    
            txt_list *= string(cnt)*") "*ph_list[i]*"<br>" 
            cnt +=1  
        end 
    end
    
    annotations[n_trace+1] =   attr(    xref        = "paper",
                                        yref        = "paper",
                                        align       = "left",
                                        valign      = "top",
                                        height      = 960,
                                        x           = 0.0,
                                        y           = 0.0,
                                        xshift      = 640,
                                        yshift      = -360,
                                        text        = txt_list,
                                        showarrow   = false,
                                        clicktoshow = false,
                                        visible     = true,
                                        font        = attr( size = 10),
    )  


    annotations[n_trace+2] =   attr(    xref        = "paper",
                                        yref        = "paper",
                                        align       = "left",
                                        valign      = "top",
                                        x           = 0.0,
                                        y           = 0.0,
                                        yshift      = -250,
                                        text        = PT_infos[1],
                                        showarrow   = false,
                                        clicktoshow = false,
                                        visible     = true,
                                        font        = attr( size = 10),
                                        )   

    annotations[n_trace+3] =   attr(    xref        = "paper",
                                        yref        = "paper",
                                        align       = "left",
                                        valign      = "top",
                                        x           = 0.2,
                                        y           = 0.0,
                                        yshift      = -250,
                                        text        = PT_infos[2],
                                        showarrow   = false,
                                        clicktoshow = false,
                                        visible     = true,
                                        font        = attr( size = 10),
                                        )   
    n_lbl = n_trace
    println("\rGet phase diagram labels $(round(time()-t0, digits=3)) s"); 

    return traces, annotations 
end

"""
    Function to generate the frame of the diagrams,
    This includes MAGEMin logo, outline and ticks
"""
function get_plot_frame(Xrange, Yrange, ticks)

    frame   = Array{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}, 1}(undef, 1+4+ticks*6)
    # frame   = Array{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}, 1}(undef, 1+4+1)

    outline = [ attr(
        source  =  "assets/static/images/MAGEMin.jpg",
        xref    = "paper",
        yref    = "paper",
        x       =  0.05,
        y       =  1.01,
        sizex   =  0.1, 
        sizey   =  0.1,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_v.png",
        xref    = "paper",
        yref    = "paper",
        x       =  0.0,
        y       =  0.0,
        sizex   =  0.002, 
        sizey   =  1.0,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_v.png",
        xref    = "paper",
        yref    = "paper",
        x       =  1.0,
        y       =  0.0,
        sizex   =  0.002, 
        sizey   =  1.0,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_h.png",
        xref    = "paper",
        yref    = "paper",
        x       =  1.0,
        y       =  0.0,
        sizex   =  1.0, 
        sizey   =  0.002,
        xanchor = "right", 
        yanchor = "bottom"
    ),
    attr(
        source  = "assets/static/images/img_h.png",
        xref    = "paper",
        yref    = "paper",
        x       =  1.0,
        y       =  1.0,
        sizex   =  1.0, 
        sizey   =  0.002,
        xanchor = "right", 
        yanchor = "bottom"
    )]

    frame[1:5] .= outline

    dx = 1.0/(ticks+1)
    dy = 1.0/(ticks+1)


    frame[6] = attr(        source  = "assets/static/images/img_h_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            x       =  0.0,
                            y       =  dy,
                            sizex   =  0.005, 
                            sizey   =  0.002,
                            xanchor = "right", 
                            yanchor = "bottom"  )  

  

    n = 6
    for i=0:(ticks+1)

        frame[n] = attr(    source  = "assets/static/images/img_h_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            # x       =  0.005,
                            x       =  0.0,
                            y       =  dy*i,

                            sizex   =  0.005, 
                            sizey   =  0.002,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1
        frame[n] = attr(    source  = "assets/static/images/img_h_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            # x       =  1.0,
                            x       =  1.005,
                            y       =  dy*i,

                            sizex   =  0.005, 
                            sizey   =  0.002,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1
        frame[n] = attr(    source  = "assets/static/images/img_v_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            x       =  dx*i,
                            # y       =  0.0,
                            y       =  -0.005,

                            sizex   =  0.002, 
                            sizey   =  0.005,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1
        frame[n] = attr(    source  = "assets/static/images/img_v_tick.png",
                            xref    = "paper",
                            yref    = "paper",
                            x       =  dx*i,
                            # y       =  0.995,
                            y       =  1.0,

                            sizex   =  0.002, 
                            sizey   =  0.005,
                            xanchor = "right", 
                            yanchor = "bottom"  )  
        n+=1

    end
    
    return frame
end



"""
    Function interpolate AMR grid to regular grid
"""
function get_boundaries(    Hash_XY     ::Vector{UInt64},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64},
                            xc          ::Vector{Float64},
                            yc          ::Vector{Float64},
                            xf          ::Vector{SVector{4, Float64}},
                            yf          ::Vector{SVector{4, Float64}}, )

    np           = length(xf)
    n            = 2^(sub + refLvl)
    x            = range(minimum(xc), stop = maximum(xc), length = n)
    y            = range(minimum(yc), stop = maximum(yc), length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    hash_field   = Matrix{UInt64}(undef,n,n);
    hash_id      = Matrix{Int64}( undef,n,n); 

    Xr = (Xrange[2]-Xrange[1])/n
    Yr = (Yrange[2]-Yrange[1])/n

    for k=1:np
        for i=xf[k][1]+Xr/2 : Xr : xf[k][3]
            for j=yf[k][1]+Yr/2 : Yr : yf[k][3]
                iii                  = Int64(round((i-Xrange[1] + Xr/2)/(Xr)))
                jjj                  = Int64(round((j-Yrange[1] + Yr/2)/(Yr)))
                hash_field[iii,jjj]   = Hash_XY[k] 
                hash_id[iii,jjj]      = k
            end
        end
    end

    # print("hash_id: $hash_id \n\n")

    uhash   = unique(Hash_XY)
    nf      = length(uhash)
    phase   = zeros(Int64,n,n)

    for j=1:n
        for i=1:nf
            phase[j,findall(hash_field[j,:] .== uhash[i])] .= i
        end
    end

    boundaries = zeros(Int64,n*n)
    for i=1:n
        for j=1:n
            gx = 0; gy = 0;
            if i != n && j != n 
                gx = (phase[i,j+1] - phase[i,j])/2.0; 
                gy = (phase[i+1,j] - phase[i,j])/2.0;
            else
                if i == n && j < n
                    gx = (phase[i,j+1] - phase[i,j])/2.0;
                elseif j == n && i < n
                    gy = (phase[i+1,j] - phase[i,j])/2.0;
                end
            end
            if abs(gx) + abs(gy) > 0
                k = j + n*(i-1)
                boundaries[k] = hash_id[i,j]
            end     
        end
    end

    return boundaries
end


"""
    Function interpolate AMR grid to regular grid
"""
function get_gridded_map(   fieldname   ::String,
                            oxi         ::Vector{String},
                            Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                            Hash_XY     ::Vector{UInt64},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            refType     ::String,
                            xc          ::Vector{Float64},
                            yc          ::Vector{Float64},
                            xf          ::Vector{SVector{4, Float64}},
                            yf          ::Vector{SVector{4, Float64}},
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64} )

    print("Interpolate data on grid ..."); t0 = time()
    np          = length(data.x)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing}}(undef,np);
 
    npoints     = np

    meant       = 0.0
    for i=1:np
        meant  += Out_XY[i].time_ms
    end
    meant      /= npoints
    meant       = round(meant; digits = 3)

    if fieldname == "#Phases"
        for i=1:np
            field[i] = Float64(length(Out_XY[i].ph));
        end
    elseif fieldname == "Hash"
        for i=1:np
            field[i] = Hash_XY[i];
        end 
    elseif fieldname == "Variance"
        for i=1:np
            field[i] = Float64(len_ox - n_phase_XY[i] + 2.0);
        end
    elseif fieldname == "s_cp"
        for i=1:np
            field[i] = Out_XY[i].s_cp[1];
        end
    elseif fieldname == "Delta_rho"
        for i=1:np
            field[i] = 0.0
            if (Out_XY[i].frac_M > 0.0 && Out_XY[i].frac_S > 0.0)
                field[i] = Out_XY[i].rho_S - Out_XY[i].rho_M
            end
        end
    else
        for i=1:np
            field[i] = Float64(get_property(Out_XY[i], fieldname));
        end

        field[isnan.(field)] .= 0.0
        if fieldname == "frac_M" || fieldname == "rho_M" || fieldname == "rho_S" || fieldname == "Delta_rho"
            field[isless.(field, 1e-8)] .= 0.0              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
        # elseif fieldname == "fO2" || fieldname == "dQFM"
        #     field .= log10.(field)
        end
    end

    n            = 2^(sub + refLvl)
    x            = range(minimum(xc), stop = maximum(xc), length = n)
    y            = range(minimum(yc), stop = maximum(yc), length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);
    gridded_info = Matrix{Union{String,Missing}}(undef,n,n); 

    Xr = (Xrange[2]-Xrange[1])/n
    Yr = (Yrange[2]-Yrange[1])/n

    for k=1:np
        ii              = Int64(round((xc[k]-Xrange[1] + Xr/2)/(Xr)))
        jj              = Int64(round((yc[k]-Yrange[1] + Yr/2)/(Yr))) 
        gridded[ii,jj]  = field[k] 

        for i=xf[k][1]+Xr/2 : Xr : xf[k][3]
            for j=yf[k][1]+Yr/2 : Yr : yf[k][3]
                iii                  = Int64(round((i-Xrange[1] + Xr/2)/(Xr)))
                jjj                  = Int64(round((j-Yrange[1] + Yr/2)/(Yr)))

                tmp                 = replace(string(Out_XY[k].ph), "\""=>"", "]"=>"", "["=>"", ","=>"")
                gridded_info[iii,jjj] = "#"*string(k)*"# "*tmp
            end
        end

    end
    println("\rInterpolate data on grid $(round(time()-t0, digits=3)) s"); 
    
    return gridded, gridded_info, X, Y, npoints, meant
end


"""
    Function interpolate AMR grid to regular grid
"""
function get_gridded_map_no_lbl(    fieldname   ::String,
                                    oxi         ::Vector{String},
                                    Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                                    Hash_XY     ::Vector{UInt64},
                                    sub         ::Int64,
                                    refLvl      ::Int64,
                                    refType     ::String,
                                    xc          ::Vector{Float64},
                                    yc          ::Vector{Float64},
                                    xf          ::Vector{SVector{4, Float64}},
                                    yf          ::Vector{SVector{4, Float64}},
                                    Xrange      ::Tuple{Float64, Float64},
                                    Yrange      ::Tuple{Float64, Float64} )

    print("Interpolate data on grid ..."); t0 = time()
    np          = length(data.x)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing}}(undef,np);
 
    npoints     = np

    meant       = 0.0
    for i=1:np
        meant  += Out_XY[i].time_ms
    end
    meant      /= npoints
    meant       = round(meant; digits = 3)

    if fieldname == "#Phases"
        for i=1:np
            field[i] = Float64(length(Out_XY[i].ph));
        end
    elseif fieldname == "Hash"
        for i=1:np
            field[i] = Hash_XY[i];
        end 
    elseif fieldname == "Variance"
        for i=1:np
            field[i] = Float64(len_ox - n_phase_XY[i] + 2.0);
        end
    elseif fieldname == "s_cp"
        for i=1:np
            field[i] = Out_XY[i].s_cp[1];
        end
    elseif fieldname == "Delta_rho"
        for i=1:np
            field[i] = 0.0
            if (Out_XY[i].frac_M > 0.0 && Out_XY[i].frac_S > 0.0)
                field[i] = Out_XY[i].rho_S - Out_XY[i].rho_M
            end
        end
    else
        for i=1:np
            field[i] = Float64(get_property(Out_XY[i], fieldname));
        end

        field[isnan.(field)] .= 0.0
        if fieldname == "frac_M" || fieldname == "rho_M" || fieldname == "rho_S"
            field[isless.(field, 1e-8)] .= 0.0              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
        # elseif fieldname == "fO2" || fieldname == "dQFM"
        #     field .= log10.(field)
        end
    end

    n            = 2^(sub + refLvl)
    x            = range(minimum(xc), stop = maximum(xc), length = n)
    y            = range(minimum(yc), stop = maximum(yc), length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);

    Xr = (Xrange[2]-Xrange[1])/n
    Yr = (Yrange[2]-Yrange[1])/n

    for k=1:np
        ii              = Int64(round((xc[k]-Xrange[1] + Xr/2)/(Xr)))
        jj              = Int64(round((yc[k]-Yrange[1] + Yr/2)/(Yr))) 
        gridded[ii,jj]  = field[k] 
    end
    println("\rInterpolate data on grid $(round(time()-t0, digits=3)) s"); 
    return gridded, X, Y, npoints, meant
end


"""
    Function interpolate AMR grid to regular grid
"""
function get_isopleth_map(  mod         ::String, 
                            ss          ::String, 
                            em          ::String,
                            of          ::String,
                            oxi         ::Vector{String},
                            Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            xc          ::Vector{Float64},
                            yc          ::Vector{Float64},
                            xf          ::Vector{SVector{4, Float64}},
                            yf          ::Vector{SVector{4, Float64}},
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64} )

    np          = length(data.x)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing}}(missing,np);

    if mod == "ph_frac" 
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)  
                field[i] = Out_XY[i].ph_frac[id[1] ]
            else
                field[i] = 0.0
            end
        end
    elseif mod == "em_frac"
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)  
                idem     = findall(Out_XY[i].SS_vec[id[1]].emNames .== em)
                field[i] = Out_XY[i].SS_vec[id[1]].emFrac[idem[1]]
            else
                field[i] = 0.0
            end
        end 
    elseif mod == "of_mod"
        for i=1:np
            field[i] = Float64(get_property(Out_XY[i], of));
        end
        field[isnan.(field)] .= missing
        if of == "frac_M" || of == "rho_M" || of == "rho_S"
            field[isless.(field, 1e-8)] .= 0.0              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
        # elseif of == "fO2" || of == "dQFM"
        #     field .= log10.(field)
        end 
    end

    n            = 2^(sub + refLvl)
    x            = range(minimum(xc), stop = maximum(xc), length = n)
    y            = range(minimum(yc), stop = maximum(yc), length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    gridded      = Matrix{Union{Float64,Missing}}(missing,n,n);

    Xr = (Xrange[2]-Xrange[1])/n
    Yr = (Yrange[2]-Yrange[1])/n

    for k=1:np
        ii              = Int64(round((xc[k]-Xrange[1] + Xr/2)/(Xr)))
        jj              = Int64(round((yc[k]-Yrange[1] + Yr/2)/(Yr))) 
        gridded[ii,jj]  = field[k] 
    end

    return gridded, X, Y
end



"""
    Function to extract values from structure using structure's member name
"""
function get_property(x, name::String)
    s = Symbol(name)
    return getproperty(x, s)
end


"""
    Function to send back the oxide list of the implemented database
"""
function get_oxide_list(dbin::String)

    if dbin == "ig"
	    MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "H2O"];
    elseif dbin == "igd"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "H2O"];      
    elseif dbin == "ige"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "H2O"];      
    elseif dbin == "alk"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "H2O"];    
    elseif dbin == "mb"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "H2O"];     
    elseif dbin == "um"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "MgO" ;"FeO"; "O"; "H2O"; "S"];
    elseif dbin == "mp"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "MnO"; "H2O"];
    else
        print("Database not implemented...\n")
    end


    return MAGEMin_ox
end

"""
    function to parce bulk-rock composition file
"""
function bulk_file_to_db(datain)

    global db;
    
    db = db[(db.bulk .== "predefined"), :];

    for i=2:size(datain,1)
        bulk   		= "custom";

        idx 		= findall(datain[1,:] .== "title")[1];
        title   	= string(datain[i,idx]);

        idx 		= findall(datain[1,:] .== "comments")[1];
        comments   	= string(datain[i,idx]);

        idx 		= findall(datain[1,:] .== "db")[1];
        dbin   		= datain[i,idx];

        test 		= length(db[(db.db .== dbin), :].test);

        idx 		= findall(datain[1,:] .== "sysUnit")[1];
        sysUnit   	= datain[i,idx];

        idx 		= findall(datain[1,:] .== "oxide")[1];
        oxide   	= rsplit(datain[i,idx],",");
        oxide 		= strip.(convert.(String,oxide));
        oxide 		= replace.(oxide,r"\]"=>"",r"\["=>"");

        idx 		= findall(datain[1,:] .== "frac")[1];
        frac   		= rsplit(datain[i,idx],",");
        frac 		= strip.(convert.(String,frac));
        frac 		= replace.(frac,r"\]"=>"",r"\["=>"");
        frac 		= parse.(Float64,frac);

        idx 		= findall(datain[1,:] .== "frac2")[1];
        bulkrock, MAGEMin_ox    = convertBulk4MAGEMin(frac,oxide,String(sysUnit),String(dbin)) 
        bulkrock   .= round.(bulkrock; digits = 4)


        if ~isempty(datain[i,idx])
            frac2  		= rsplit(datain[i,idx],",");
            frac2 		= strip.(convert.(String,frac2));
            frac2 		= replace.(frac2,r"\]"=>"",r"\["=>"");
            frac2		= parse.(Float64,frac2);
            bulkrock2, MAGEMin_ox   = convertBulk4MAGEMin(frac2,oxide,String(sysUnit),String(dbin)) 
            bulkrock2  .= round.(bulkrock2; digits = 4)
        else
            bulkrock2   = deepcopy(bulkrock)
        end

        oxide                   = get_oxide_list(String(dbin))


        push!(db,Dict(  :bulk       => bulk,
                        :title      => title,
                        :comments   => comments,
                        :db         => dbin,
                        :test       => test,
                        :sysUnit    => sysUnit,
                        :oxide      => oxide,
                        :frac       => bulkrock,
                        :frac2      => bulkrock2,
                    ), cols=:union)
    end

end


function parse_bulk_rock(contents, filename)
    try
        content_type, content_string = split(contents, ',');
        decoded = base64decode(content_string);
        input   = String(decoded) ;
        datain  = strip.(string.(readdlm(IOBuffer(input), ';', comments=true, comment_char='#')));

        bulk_file_to_db(datain);

        return 1
    catch e
        return 0
    end

  end

function get_initial_vertices(Xsub,Ysub,tmin,tmax,pmin,pmax)
    x0      = tmin;
    y0      = pmin;
    xrng    = tmax-tmin;
    yrng    = pmax-pmin;

    Xsub = Int64(Xsub)
    Ysub = Int64(Ysub)

    nb      = (Ysub + 1 )*(Xsub + 1);   # main quads
    ns      = (Ysub)*(Xsub + 2);        # tri subdivision

    vert_list = zeros(nb+ns,2);         # declare vertice coordinate matrix

    b_xs = Float64(1.0/Xsub);                    # x step
    b_ys = Float64(1.0/Ysub);                    # y step

    # get coarse grid vertice position
    inc = 1;
    for i=1:Xsub+1
        for j=1:Ysub+1
            vert_list[inc,1] = (Float64(i)-1)*b_xs;
            vert_list[inc,2] = (Float64(j)-1)*b_ys;
            inc += 1;
        end
    end

    # intermediate vertices boundary position
    for j=1:Ysub
        vert_list[inc,1] = 0.0;
        vert_list[inc,2] = (Float64(j)-1)*b_ys + b_ys/2.0;
        inc += 1;
    end
    for j=1:Ysub
        vert_list[inc,1] = 1.0;
        vert_list[inc,2] = (Float64(j)-1)*b_ys + b_ys/2.0;
        inc += 1;
    end

    # intermediate vertices inner position
    for i=1:Xsub
        for j=1:Ysub
            vert_list[inc,1] = (Float64(i)-1)*b_xs + b_xs/2.0;
            vert_list[inc,2] = (Float64(j)-1)*b_ys + b_ys/2.0;
            inc += 1;
        end
    end

    for inc=1:size(vert_list,1);
        vert_list[inc,1] = vert_list[inc,1] * xrng + x0;
        vert_list[inc,2] = vert_list[inc,2] * yrng + y0;
    end

    return vert_list
end

function get_field_from_vert(vert,tmin,tmax,pmin,pmax)

    n       = size(vert,1);
    field   = zeros(n);

    for i=1:n
        field[i]   = circle_eq(vert[i,1],vert[i,2],tmin,tmax,pmin,pmax);             # function to test AMR with triangles
    end

    return field
end

function circle_eq(xc,yc,tmin,tmax,pmin,pmax)
    x0      = tmin;
    y0      = pmin;
    xrng    = tmax-tmin;
    yrng    = pmax-pmin;

    r = 0.25;
    x = (xc - (x0 + xrng/4))/(xrng/2);
    y = (yc - y0)/yrng;

    if (x - 0.5)*(x - 0.5) + (y - 0.5)*(y - 0.5) - r*r < 0
        z = 1;
    else
        z = 0;
    end

    return z
end


function generator_scatter_traces(tmin,tmax,pmin,pmax)
    # print("$(AppData.vertice_list)\n\n")
    mesh    = delaunay(AppData.vertice_list[]);
    mcat    = cat(mesh.simplices,mesh.simplices[:,1],dims=2);
    n       = size(mesh.simplices,1);
    data    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n);

    for i=1:n
        x   = mesh.points[mcat[i,:],1]
        y   = mesh.points[mcat[i,:],2]

        tmp = AppData.field[];
        z   = tmp[mcat[i,:]]
 
        # ugly way to have different colors -> will use heatmap here
        if sum(z)/4.0 == 0.0
            color = "#9999FF"
        elseif sum(z)/4.0 == 1.0
            color = "#FF99FF"
        else
            color = "#6633FF"
        end
        
        data[i]=scatter(;   x           = x,
                            y           = y,
                            fill        = "toself",
                            fillcolor   = color,
                            line_color  = "#000000",
                            line_width  = 0.1, #0.5
                            marker      = attr( color   = "LightSkyBlue",
                                                size    = 0.1, #4
                                                line    = attr(width=0.1, color="#000000")),
                            hoverinfo   = "skip",
                        );
    end

    return data, mesh;
end    

