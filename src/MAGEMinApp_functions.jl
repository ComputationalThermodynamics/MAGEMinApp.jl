


function set_min_to_white(colormap; reverseColorMap = false)

    color       = colormap
    nc          = length(color)
    cust_color  = Vector{String}(undef, nc)
    cust_color = [ [(i-1)/(nc-1),"rgba($(color[i].r),$(color[i].g),$(color[i].b),1.0)"] for i = 1:nc]

    if reverseColorMap == false
        cust_color[1][2] = "rgba(1.0,1.0,1.0,0.0)"
    else
        cust_color[end][2] = "rgba(1.0,1.0,1.0,0.0)"
    end
    colormap = cust_color

    return colormap
end

function discretize_colormap(colormap,min,max)

    color       = colormap
    nc          = length(color)
    n           = Int64((max - min)+1)
    stp         = Int64(floor(nc / n ))
    println("color $color")
    println("nc $nc n $n stp $stp")

    tmp  = Vector{String}(undef, n)
    tmp  = ["rgba($(round(color[i].r,digits=5)),$(round(color[i].g,digits=5)),$(round(color[i].b,digits=5)),1.0)" for i = 1:stp:nc]

    cust_color = Vector{Any}[]
    for i=1:n
        line1 = [round(Float64((i)/n - 1/n),digits=5),tmp[i]]
        line2 = [round(Float64((i)/n),digits=5),tmp[i]]
        
        push!(cust_color,line1)
        push!(cust_color,line2)
    end  
    # cust_color[1][1] = 0.001

    println("cust_color $cust_color")

    return cust_color
end


function get_jet_colormap(n)

    jet256 = ["RGB(0,0,127)", "RGB(0,0,132)", "RGB(0,0,136)", "RGB(0,0,141)", "RGB(0,0,145)", "RGB(0,0,150)", "RGB(0,0,154)", "RGB(0,0,159)", "RGB(0,0,163)", "RGB(0,0,168)", "RGB(0,0,172)", "RGB(0,0,177)", "RGB(0,0,182)", "RGB(0,0,186)", "RGB(0,0,191)", "RGB(0,0,195)", "RGB(0,0,200)", "RGB(0,0,204)", "RGB(0,0,209)", "RGB(0,0,213)", "RGB(0,0,218)", "RGB(0,0,222)", "RGB(0,0,227)", "RGB(0,0,232)", "RGB(0,0,236)", "RGB(0,0,241)", "RGB(0,0,245)", "RGB(0,0,250)", "RGB(0,0,254)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,0,255)", "RGB(0,4,255)", "RGB(0,8,255)", "RGB(0,12,255)", "RGB(0,16,255)", "RGB(0,20,255)", "RGB(0,24,255)", "RGB(0,28,255)", "RGB(0,32,255)", "RGB(0,36,255)", "RGB(0,40,255)", "RGB(0,44,255)", "RGB(0,48,255)", "RGB(0,52,255)", "RGB(0,56,255)", "RGB(0,60,255)", "RGB(0,64,255)", "RGB(0,68,255)", "RGB(0,72,255)", "RGB(0,76,255)", "RGB(0,80,255)", "RGB(0,84,255)", "RGB(0,88,255)", "RGB(0,92,255)", "RGB(0,96,255)", "RGB(0,100,255)", "RGB(0,104,255)", "RGB(0,108,255)", "RGB(0,112,255)", "RGB(0,116,255)", "RGB(0,120,255)", "RGB(0,124,255)", "RGB(0,128,255)", "RGB(0,132,255)", "RGB(0,136,255)", "RGB(0,140,255)", "RGB(0,144,255)", "RGB(0,148,255)", "RGB(0,152,255)", "RGB(0,156,255)", "RGB(0,160,255)", "RGB(0,164,255)", "RGB(0,168,255)", "RGB(0,172,255)", "RGB(0,176,255)", "RGB(0,180,255)", "RGB(0,184,255)", "RGB(0,188,255)", "RGB(0,192,255)", "RGB(0,196,255)", "RGB(0,200,255)", "RGB(0,204,255)", "RGB(0,208,255)", "RGB(0,212,255)", "RGB(0,216,255)", "RGB(0,220,254)", "RGB(0,224,250)", "RGB(0,228,247)", "RGB(2,232,244)", "RGB(5,236,241)", "RGB(8,240,237)", "RGB(12,244,234)", "RGB(15,248,231)", "RGB(18,252,228)", "RGB(21,255,225)", "RGB(24,255,221)", "RGB(28,255,218)", "RGB(31,255,215)", "RGB(34,255,212)", "RGB(37,255,208)", "RGB(41,255,205)", "RGB(44,255,202)", "RGB(47,255,199)", "RGB(50,255,195)", "RGB(54,255,192)", "RGB(57,255,189)", "RGB(60,255,186)", "RGB(63,255,183)", "RGB(66,255,179)", "RGB(70,255,176)", "RGB(73,255,173)", "RGB(76,255,170)", "RGB(79,255,166)", "RGB(83,255,163)", "RGB(86,255,160)", "RGB(89,255,157)", "RGB(92,255,154)", "RGB(95,255,150)", "RGB(99,255,147)", "RGB(102,255,144)", "RGB(105,255,141)", "RGB(108,255,137)", "RGB(112,255,134)", "RGB(115,255,131)", "RGB(118,255,128)", "RGB(121,255,125)", "RGB(124,255,121)", "RGB(128,255,118)", "RGB(131,255,115)", "RGB(134,255,112)", "RGB(137,255,108)", "RGB(141,255,105)", "RGB(144,255,102)", "RGB(147,255,99)", "RGB(150,255,95)", "RGB(154,255,92)", "RGB(157,255,89)", "RGB(160,255,86)", "RGB(163,255,83)", "RGB(166,255,79)", "RGB(170,255,76)", "RGB(173,255,73)", "RGB(176,255,70)", "RGB(179,255,66)", "RGB(183,255,63)", "RGB(186,255,60)", "RGB(189,255,57)", "RGB(192,255,54)", "RGB(195,255,50)", "RGB(199,255,47)", "RGB(202,255,44)", "RGB(205,255,41)", "RGB(208,255,37)", "RGB(212,255,34)", "RGB(215,255,31)", "RGB(218,255,28)", "RGB(221,255,24)", "RGB(224,255,21)", "RGB(228,255,18)", "RGB(231,255,15)", "RGB(234,255,12)", "RGB(237,255,8)", "RGB(241,252,5)", "RGB(244,248,2)", "RGB(247,244,0)", "RGB(250,240,0)", "RGB(254,237,0)", "RGB(255,233,0)", "RGB(255,229,0)", "RGB(255,226,0)", "RGB(255,222,0)", "RGB(255,218,0)", "RGB(255,215,0)", "RGB(255,211,0)", "RGB(255,207,0)", "RGB(255,203,0)", "RGB(255,200,0)", "RGB(255,196,0)", "RGB(255,192,0)", "RGB(255,189,0)", "RGB(255,185,0)", "RGB(255,181,0)", "RGB(255,177,0)", "RGB(255,174,0)", "RGB(255,170,0)", "RGB(255,166,0)", "RGB(255,163,0)", "RGB(255,159,0)", "RGB(255,155,0)", "RGB(255,152,0)", "RGB(255,148,0)", "RGB(255,144,0)", "RGB(255,140,0)", "RGB(255,137,0)", "RGB(255,133,0)", "RGB(255,129,0)", "RGB(255,126,0)", "RGB(255,122,0)", "RGB(255,118,0)", "RGB(255,115,0)", "RGB(255,111,0)", "RGB(255,107,0)", "RGB(255,103,0)", "RGB(255,100,0)", "RGB(255,96,0)", "RGB(255,92,0)", "RGB(255,89,0)", "RGB(255,85,0)", "RGB(255,81,0)", "RGB(255,77,0)", "RGB(255,74,0)", "RGB(255,70,0)", "RGB(255,66,0)", "RGB(255,63,0)", "RGB(255,59,0)", "RGB(255,55,0)", "RGB(255,52,0)", "RGB(255,48,0)", "RGB(255,44,0)", "RGB(255,40,0)", "RGB(255,37,0)", "RGB(255,33,0)", "RGB(255,29,0)", "RGB(255,26,0)", "RGB(255,22,0)", "RGB(254,18,0)", "RGB(250,15,0)", "RGB(245,11,0)", "RGB(241,7,0)", "RGB(236,3,0)", "RGB(232,0,0)", "RGB(227,0,0)", "RGB(222,0,0)", "RGB(218,0,0)", "RGB(213,0,0)", "RGB(209,0,0)", "RGB(204,0,0)", "RGB(200,0,0)", "RGB(195,0,0)", "RGB(191,0,0)", "RGB(186,0,0)", "RGB(182,0,0)", "RGB(177,0,0)", "RGB(172,0,0)", "RGB(168,0,0)", "RGB(163,0,0)", "RGB(159,0,0)", "RGB(154,0,0)", "RGB(150,0,0)", "RGB(145,0,0)", "RGB(141,0,0)", "RGB(136,0,0)", "RGB(132,0,0)", "RGB(127,0,0)"]

    np    = length(jet256)

    step  = Int64(floor(np/n))
    if step == 0
        step = 1
    end

    return jet256[1:step:end]

end

function get_lines_colormap()

    color_lines = [ "RGB(182,69,91)",
                    "RGB(182,69,156)",
                    "RGB(174,69,182)",
                    "RGB(107,69,182)",
                    "RGB(69,84,182)",
                    "RGB(69,152,182)",
                    "RGB(69,182,152)",
                    "RGB(69,182,91)",
                    "RGB(107,182,69)",
                    "RGB(159,182,69)",
                    "RGB(182,156,69)",
                    "RGB(182,122,69)",
                    "RGB(182,76,69)"]

    return color_lines

end

function get_init_param(    dtb         :: String,
                            solver      :: String,
                            cpx,        
                            limOpx,    
                            limOpxVal   :: Float64 )   

        # set clinopyroxene for the metabasite database
        mbCpx = 0
        if cpx == true && (dtb =="mb" || dtb =="mbe"  )
            mbCpx = 1;
        end
        limitCaOpx  = 0
        CaOpxLim    = 1.0
        if limOpx == "ON" && (dtb =="mb" || dtb =="mbe" || dtb =="ig" || dtb =="igd" || dtb =="alk")
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

    return mbCpx,limitCaOpx,CaOpxLim,sol

end

function string_vec_diff(solution_ph_selection, pure_ph_selection, dtb)

    ss_selection = string_vec_diff_ss(solution_ph_selection,    dtb)
    pp_selection = string_vec_diff_pp(pure_ph_selection,        dtb)

    if isnothing(ss_selection) && isnothing(pp_selection)
        return nothing
    elseif isnothing(ss_selection)
        return pp_selection
    elseif isnothing(pp_selection)
        return ss_selection
    else
        return vcat(ss_selection,pp_selection)
    end

end


"""
    Function to retrieve active set of solution phases
"""
function string_vec_diff_ss(phase_selection,dtb)

    db_in                           = retrieve_solution_phase_information(dtb)
    set_A                           = phase_selection
    set_B                           = db_in.ss_name
    phase_selection                 = setdiff(set_B, set_A)
    if isempty(phase_selection)
        phase_selection = nothing
    end

    return phase_selection
end

"""
    Function to retrieve active set of pure phases
"""
function string_vec_diff_pp(phase_selection,dtb)

    db_in                           = retrieve_solution_phase_information(dtb)
    set_A                           = phase_selection
    pp_all                          = db_in.data_pp
    set_B                           = setdiff(pp_all, AppData.hidden_pp)

    pure_phase_selection            = setdiff(set_B, set_A)
    if isempty(pure_phase_selection)
        pure_phase_selection = nothing
    end

    return pure_phase_selection
end


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

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    T            = vcat(x)
    P            = vcat(y)
    gridded      = Array{Union{Float64,Missing}}(undef,n,n,ncol);

    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    for l=1:ncol
        for k=1:np
            ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
            jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
            gridded[ii,jj,l]  = field[k,l] 
        end

        for i=1:length(data.cells)
            cell    = data.cells[i]
            tmp     = field[cell[1],l] 

            ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
            jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            for ii = ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
            end

            jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
            jj_ix = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

            for ii in ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
                for jj in jj_min+1:jj_max-1
                    gridded[ii, jj,l] = tmp
                end
            end

        end
    end

    # filter some potential iffy values
    gridded[gridded[:,:,2] .== 0.0,2] .= 3000.0
    gridded[isnan.(gridded[:,:,2]),2] .= 3000.0
    gridded[gridded[:,:,1] .== 0.0,1] .= 2000.0
    gridded[isnan.(gridded[:,:,1]),1] .= 2000.0
    gridded[gridded[:,:,3] .> 1.0,3]  .= 1.0

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
        tmp = bulk1[i][:fraction]
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
    file       *= @sprintf("53:    Lowest P [bar]\n");
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
    for i=1:19
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("[meltRho, rho, kg/m^3] [meltFrac, wtPercent, NoUnits] [rockRho, rho, kg/m^3] [Temperature, T, K] [Pressure, P, bar]   \n");
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
save_rho_for_GeoModel()
    This function export parameters useful for geodynamic coupling -> P,T, rho_S, rho_M, Frac_M, Vp, Vs, s_cp
"""
function save_rho_for_GeoModel(     dtb         ::String,
                                    sub         ::Int64,
                                    refLvl      ::Int64,
                                    Xrange,
                                    Yrange,
                                    bulk1                  )

    np          = length(Out_XY)

    field2save  = ["rho_M","rho_S","frac_M","Vp","Vs","s_cp","alpha"]
    ncol        = length(field2save)
    field       = Matrix{Union{Float64,Missing}}(undef,np,ncol);

    for j=1:ncol
        if field2save[j] == "s_cp"
            for i=1:np
                field[i,j] = Out_XY[i].s_cp[1];
            end
        elseif field2save[j] == "s_cp"
            for i=1:np
                field[i,j] = Out_XY[i].alpha[1];
            end
        else
            for i=1:np
                field[i,j] = Float64(get_property(Out_XY[i], field2save[j]));
            end
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    T            = vcat(x)
    P            = vcat(y)
    gridded      = Array{Union{Float64,Missing}}(undef,n,n,ncol);

    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    for l=1:ncol
        for k=1:np
            ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
            jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
            gridded[ii,jj,l]  = field[k,l] 
        end

        for i=1:length(data.cells)
            cell    = data.cells[i]
            tmp     = field[cell[1],l] 

            ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
            jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            for ii = ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
            end

            jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
            jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
            ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
            for jj in jj_min+1:jj_max-1
                gridded[ii_ix, jj,l] = tmp
            end

            ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
            ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
            jj_ix = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

            for ii in ii_min+1:ii_max-1
                gridded[ii, jj_ix,l] = tmp
                for jj in jj_min+1:jj_max-1
                    gridded[ii, jj,l] = tmp
                end
            end

        end
    end

    # filter some potential iffy values
    gridded[gridded[:,:,2] .== 0.0,2] .= 3000.0
    gridded[isnan.(gridded[:,:,2]),2] .= 3000.0
    gridded[gridded[:,:,1] .== 0.0,1] .= 2000.0
    gridded[isnan.(gridded[:,:,1]),1] .= 2000.0
    gridded[gridded[:,:,3] .> 1.0,3]  .= 1.0

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
        tmp = bulk1[i][:fraction]
        if typeof(tmp) == String
            tmp = parse(Float64,tmp)
        end
        bulk[i]   = tmp;
        oxi[i]    = bulk1[i][:oxide];
    end

    file        = ""
    file       *= @sprintf("8\n")
    file       *= @sprintf("\n\n")
    file       *= @sprintf("       1               2                     3                4        5             6       7        8\n");
    file       *= @sprintf("rho_melt[kg/m3]   melt_fraction[wt]   rho_solid[kg/m3]    Vp[km/s]  Vs[km/s]  s_cp[J/kg/K]  T[K]   P[bar]  \n");
    file       *= @sprintf("1-49:  Comments\n");
    file       *= @sprintf("50:    Lowest T [K]\n");
    file       *= @sprintf("51:    T increment\n");
    file       *= @sprintf("52:    # of T values\n");
    file       *= @sprintf("53:    Lowest P [bar]\n");
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
    for i=1:19
        file   *= @sprintf("\n")
    end
    file       *= @sprintf("[meltRho, rho, kg/m^3] [meltFrac, wtPercent, NoUnits] [rockRho, rho, kg/m^3] [Vp, vp, km/s] [Vs, vs, km/s] [SpecificCp, scp, J/kg/K] [Temperature, T, K] [Pressure, P, bar]   \n");
    file       *= @sprintf("%5.10f\n",minimum(T));
    file       *= @sprintf("%5.10f\n",dT);
    file       *= @sprintf("%d\n",nT);
    file       *= @sprintf("%5.10f\n",minimum(P));
    file       *= @sprintf("%5.10f\n",dP);
    file       *= @sprintf("%d\n",nP);
    for j=1:nP
        for i=1:nT
            file   *= @sprintf("%5.6f %5.6f %5.6f %5.6f %5.6f %5.6f %5.6f %5.6f\n",gridded[i,j,1],gridded[i,j,3],gridded[i,j,2],gridded[i,j,4],gridded[i,j,5],gridded[i,j,6],T[i],P[j])
        end
    end


    return file
end


"""
    save equilibrium function
"""
function save_equilibrium_to_file(  out::MAGEMin_C.gmin_struct{Float64, Int64}, dtb, mbCpx )

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
    if mbCpx == true; aug = 1;
    else  aug = 0; end
       
    file *= @sprintf("Initial guess for THERMOCALC:\n") 
    file *= @sprintf("%% ----------------------------------------------------------\n") 
    file *= @sprintf("%% at P =  %12.8f, T = %12.8f, for: ",out.P_kbar,out.T_C)
    for i=1:out.n_SS
        ph = get_ss_from_mineral(dtb, out.ph[i], aug)
        file *= @sprintf("%s ",ph)  
    end
    file *= @sprintf("\n") 
    file *= @sprintf("%% ----------------------------------------------------------\n") 
    file *= @sprintf("ptguess  %12.8f %12.8f\n",out.P_kbar,out.T_C) 
    file *= @sprintf("%% ----------------------------------------------------------\n")     
    n = 1;

    
    for i=1:out.n_SS
        for j=1:length(out.SS_vec[i].emFrac)-1
            ph = get_ss_from_mineral(dtb, out.ph[i], aug)
            if length(ph) == 1
                file *= @sprintf(	"xyzguess %5s(%1s) %10f\n", out.SS_vec[i].compVariablesNames[j],ph ,out.SS_vec[i].compVariables[j])
            elseif length(ph) == 2
                file *= @sprintf(	"xyzguess %5s(%2s) %10f\n", out.SS_vec[i].compVariablesNames[j],ph ,out.SS_vec[i].compVariables[j])
            elseif length(ph) == 3
                file *= @sprintf(	"xyzguess %5s(%3s) %10f\n", out.SS_vec[i].compVariablesNames[j],ph ,out.SS_vec[i].compVariables[j])
            elseif length(ph) == 4
                file *= @sprintf(	"xyzguess %5s(%4s) %10f\n", out.SS_vec[i].compVariablesNames[j],ph ,out.SS_vec[i].compVariables[j])
            elseif length(ph) == 5
                file *= @sprintf(	"xyzguess %5s(%5s) %10f\n", out.SS_vec[i].compVariablesNames[j],ph ,out.SS_vec[i].compVariables[j])
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
                                    rangeColor  :: Union{JSON3.Array{Int64, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}},Vector{Int64}} )

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

function get_phase_infos(       Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                                data        ::MAGEMinApp.AMR_data )

    global phase_infos

    np          = length(data.points)
    
    # here we also get information about the phases that are stable accross the diagram and their potential solvus
    act_ss      = []
    act_pp      = []

    reac_ss     = []
    reac_pp     = []

    def         = ("solid",0.75,"#000000",10.0,"")

    act_sol     = []
    for i = 1:np
        n_ph = length(Out_XY[i].ph)
        n_SS = Out_XY[i].n_SS
        for k in Out_XY[i].sol_name[1:n_SS]
            if k in act_sol
            else 
                push!(act_sol, k) 
            end
        end
        for k in Out_XY[i].ph[1:n_SS]
            if k in act_ss
            else 
                push!(reac_ss, def) 
                push!(act_ss, k) 
            end
        end
        if n_ph > n_SS
            for k in Out_XY[i].ph[1+n_SS:n_ph]
                if k in act_pp
                else
                    push!(reac_pp, def) 
                    push!(act_pp, k)
                end
            end
        end

    end

    phase_infos = ( act_pp       = act_pp,
                    act_ss       = act_ss,
                    reac_pp      = reac_pp,
                    reac_ss      = reac_ss,
                    act_sol      = act_sol  )
    return nothing
end

"""
    Function to retrieve the field labels
"""
function get_diagram_labels(    Out_XY      :: Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                                Hash_XY     :: Vector{UInt64},
                                refType     :: String,
                                data        :: MAGEMinApp.AMR_data,
                                PT_infos    :: Vector{String};
                                field_size  :: Int64 = 4 )

    global n_lbl, gridded_fields, phase_infos
    print("Get phase diagram labels ..."); t0 = time();

    np          = length(data.points)
    ph          = Vector{String}(undef,np)
    phd         = Vector{String}(undef,np)
    fac         = (data.Xrange[2]-data.Xrange[1])*(data.Yrange[2]-data.Yrange[1])

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
            ph_em = get_dominant_em(    Out_XY[i].ph,
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

    hull        = unique(Hash_XY)
    n_hull      = length(hull)
    area        = Vector{Any}(undef,    n_hull)
    n_pix       = Vector{Int64}(undef,    n_hull)
    ph_list     = Vector{String}(undef, n_hull)
    phd_list    = Vector{String}(undef, n_hull)
    id          = 0
    coor        = []

    int_vector  = [findfirst(x -> x == h, hull) for h in Hash_XY] 
    for i = 1:length(int_vector)

        field_tmp   = findall(int_vector .== i)
        np          = length(field_tmp)
        if np > 4
            id             += 1
            ph_list[id]     = ph[field_tmp][1]
            phd_list[id]    = phd[field_tmp][1]

            mask, bnds      = reduce_matrix(ifelse.(gridded_fields .!= i, 0, 1))
            mask            = BitArray(expand_with_zeros(mask))

            dx              = (data.Xrange[2]-data.Xrange[1])/(size(gridded_fields,1)-1)
            dy              = (data.Yrange[2]-data.Yrange[1])/(size(gridded_fields,2)-1)
            
            minX            = data.Xrange[1] + dx*(bnds[1]-1) - dx/2
            maxX            = data.Xrange[1] + dx*(bnds[2]-1) + dx/2
            minY            = data.Yrange[1] + dy*(bnds[3]-1) - dy/2
            maxY            = data.Yrange[1] + dy*(bnds[4]-1) + dy/2
            n_pix[id]       = Float64(sum(mask))
            area[id]        = n_pix[id]*dx*dy/fac
            centers         = select_point(mask, range(minY, maxY, size(mask,2)+1) , range(minX, maxX, size(mask,1)+1) )
            
            push!(coor,centers)
        end
    end

    n_trace     = id;
    traces      = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,n_trace+1);
    annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,n_trace+2)

    txt_list = ""
    cnt = 1;
    for i=1:n_trace
        traces[i+1] = scatter(; x           =  nothing,
                                y           =  nothing,
                                fill        = "toself",
                                fillcolor   = "transparent",
                                line_width  =  0.0,
                                mode        = "lines",
                                hoverinfo   = "text",
                                showlegend  = false,
                                text        = ph_list[i]        );
    

        ctr     = coor[i]
        if n_pix[i] > field_size
            if area[i] < 0.004      # place an arrow
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
                                            font        = attr( size = 9, color = "#212121"),
                                        )  
                txt_list *= string(cnt)*") "*ph_list[i]*"\n"
                cnt +=1
            elseif area[i] > 0.03 # place full label
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
            else    # place number
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
        
                txt_list *= string(cnt)*") "*ph_list[i]*"\n" 
                cnt +=1  
            end 
        else
            annotations[i] = attr(  xref        = "x",
                                    yref        = "y",
                                    align       = "left",
                                    valign      = "top",
                                    x           = ctr[1],
                                    y           = ctr[2],
                                    text        = "",
                                    showarrow   = false,
                                    visible     = false,
                                    font        = attr( size = 10, color = "#212121"),
                                )  
        end
    end

    annotations[n_trace+1] =   attr(    xref        = "paper",
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

    annotations[n_trace+2] =   attr(    xref        = "paper",
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
    println("\rGet phase diagram labels $(round(time()-t0, digits=3)) seconds"); 

    return traces, annotations, txt_list 
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
function get_gridded_map(   fieldname   ::String,
                            type        ::String,
                            oxi         ::Vector{String},
                            Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                            Out_TE_XY   ::Union{Nothing,Vector{MAGEMin_C.out_tepm}},
                            Hash_XY     ::Vector{UInt64},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            refType     ::String,
                            data        ::MAGEMinApp.AMR_data,
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64} )

    print("Interpolate data on grid ..."); t0 = time()
    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing,Nothing}}(undef,np);
 
    npoints     = np

    meant       = 0.0
    for i=1:np
        meant  += Out_XY[i].time_ms
    end
    meant      /= npoints
    meant       = round(meant; digits = 3)

    if type == "zr"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end

        field[isnothing.(field)] .= 0.0
    else
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
        elseif fieldname == "alpha"
            for i=1:np
                field[i] = Out_XY[i].alpha[1];
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
            end
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);
    gridded_info = Matrix{Union{String,Missing}}(fill(missing,n,n)); 

    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded[ii,jj]  = field[k] 

        tmp                 = replace(string(Out_XY[k].ph), "\""=>"", "]"=>"", "["=>"", ","=>"")
        gridded_info[ii,jj] = "#"*string(k)*"# "*tmp

    end

    for i=1:length(data.cells)
        cell   = data.cells[i]
        tmp    = "#"*string(cell[1])*"# "*replace(string(Out_XY[cell[1]].ph), "\""=>"", "]"=>"", "["=>"", ","=>"")

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            gridded_info[ii, jj_ix] = tmp
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_info[ii_ix, jj] = tmp
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_info[ii_ix, jj] = tmp
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

        for ii in ii_min+1:ii_max-1
            gridded_info[ii, jj_ix] = tmp
            for jj in jj_min+1:jj_max-1
                gridded_info[ii, jj] = tmp
            end
        end

    end

    println("\rInterpolate data on grid $(round(time()-t0, digits=3)) seconds"); 


    # test Anton functions
    f           = unique(Hash_XY)
    int_vector  = [findfirst(x -> x == h, f) for h in Hash_XY] 
    gridded_fields = Matrix{Int64}(undef,n,n);

    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded_fields[ii,jj]  = int_vector[k] 
    end

    for i=1:length(data.cells)
        cell   = data.cells[i]
        tmp    = int_vector[cell[1]]

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            gridded_fields[ii, jj_ix] = tmp
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_fields[ii_ix, jj] = tmp
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            gridded_fields[ii_ix, jj] = tmp
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

        for ii in ii_min+1:ii_max-1
            gridded_fields[ii, jj_ix] = tmp
            for jj in jj_min+1:jj_max-1
                gridded_fields[ii, jj] = tmp
            end
        end

    end

    return gridded, gridded_info, gridded_fields, X, Y, npoints, meant
end



"""
    parse use input
"""
function get_parsed_command(    point       :: Int64;
                                varBuilder  :: String = "M_Dy / M_Yb",
                                norm        :: String = "none" )

    # te_chondrite    = ["Rb", "Ba", "Th", "U", "Nb", "Ta", "La", "Ce", "Pb", "Pr", "Sr", "Nd", "Zr", "Hf", "Sm", "Eu", "Gd", "Tb", "Dy", "Y", "Ho", "Er", "Tm", "Yb", "Lu", "V", "Sc"]
    ppm_chondrite   = [2.3, 2.41,0.029,0.0074,0.24,0.0136,0.237,0.613,2.47,0.0928,7.25,0.457,3.82,0.103,0.148,0.0563,0.199,0.0361,0.246,1.57,0.0546,0.160,0.0247,0.161,0.0246,56,5.92]

    if ~isnothing(Out_TE_XY[point].Cliq)

        # varBuilder         = "[M_Dy]/([g_Dy]*[S_Yb])"
        pattern     = r"\[([^\]]+)\]"
        matches     = eachmatch(pattern, varBuilder)
        terms       = [match.captures[1] for match in matches]
        n_terms     = length(terms)
    

        ref         = "Out_TE_XY["*string(point)*"]"
        varBuilder_out     = varBuilder
        
        if ~isempty(terms)
            for i = 1:n_terms
                st = String.(split(terms[i], "_"))
                if length(st) == 2
                    id_el = findfirst(Out_TE_XY[point].elements  .== st[2])
                    if isnothing(id_el)
                        part1, part2 = "break", "break"
                        print("wrong element name!\n")
                    else

                        if norm == "bulk"
                            nrm = string(Out_TE_XY[point].C0[id_el])
                        elseif norm == "chondrite"
                            nrm = string(ppm_chondrite[id_el])
                        else
                            nrm = string(1.0)
                        end
    
                        if st[1] == "S"
                            part1 = ref*".Csol"
                            part2 = "["*string(id_el)*"]"
                        elseif st[1] == "M"
                            part1 = ref*".Cliq"
                            part2 = "["*string(id_el)*"]"
                        else
                            id_ph = findfirst(Out_TE_XY[point].ph_TE .== st[1])
                            if isnothing(id_ph)
                                part1, part2 = "break", "break"
                                # print("wrong phase name!\n")
                            else
                                part1 = ref*".Cmin"
                                part2 = "["*string(id_ph)*","*string(id_el)*"]"
                            end
                        end

                        left = "(("
                        right = ")/"*nrm*")"
    
                        if part1 == "break" || part2 == "break"
                            varBuilder_out = "NaN"
                        else
                            varBuilder_out = replace(varBuilder_out, "["*terms[i]*"]" => left*part1*part2*right)
                        end
                    end

                else
                    println("warning: underscore to split (M,S ph) and (element), has to be added")
                end
        
            end
        end
      
    else
        varBuilder_out = "NaN"
    end

    command = Meta.parse(varBuilder_out)

    return command
end

"""
    Function interpolate AMR grid to regular grid
"""
function get_gridded_map_no_lbl(    fieldname   ::String,
                                    type        ::String,
                                    varBuilder  ::String,
                                    norm        ::String,    
                                    oxi         ::Vector{String},
                                    Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                                    Out_TE_XY   ::Union{Nothing,Vector{MAGEMin_C.out_tepm}},
                                    Hash_XY     ::Vector{UInt64},
                                    sub         ::Int64,
                                    refLvl      ::Int64,
                                    refType     ::String,
                                    data        ::MAGEMinApp.AMR_data,
                                    Xrange      ::Tuple{Float64, Float64},
                                    Yrange      ::Tuple{Float64, Float64} )

    print("Interpolate data on grid ..."); t0 = time()
    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing,Nothing}}(undef,np);
 
    npoints     = np

    meant       = 0.0
    for i=1:np
        meant  += Out_XY[i].time_ms
    end
    meant      /= npoints
    meant       = round(meant; digits = 3)
    if type == "zr"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], fieldname);
        end

        field[isnothing.(field)] .= 0.0
    elseif type == "te"
        global i
        for i=1:np
            cmd = get_parsed_command( i;  varBuilder, norm) 
            field[i] = eval(cmd)
        end
        field[isnan.(field)] .= 0.0
    else
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
        elseif fieldname == "alpha"
            for i=1:np
                field[i] = Out_XY[i].alpha[1];
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
            end
        end
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);



    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded[ii,jj]  = field[k] 
    end



    println("\rInterpolate data on grid $(round(time()-t0, digits=3)) seconds"); 
    return gridded, X, Y, npoints, meant
end


"""
    Function interpolate AMR grid to regular grid
"""
function get_isopleth_map(  mod         ::String, 
                            ss          ::String, 
                            em          ::String,
                            ox          ::String,
                            of          ::String,
                            ot          ::String,
                            calc        ::String,
                            calc_sf     ::String,
                            rmf         ::Bool,
                            oxi         ::Vector{String},
                            Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            data        ::MAGEMinApp.AMR_data,
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64} )

    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing}}(missing,np);

    if mod == "ph_frac" 
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id) 
                field[i] = Out_XY[i].ph_frac[id[1] ]

                if rmf == true 
                    if "H2O" in Out_XY[i].ph
                        id = findfirst(Out_XY[i].ph .== "H2O")
                        field[i] = field[i] / (1.0 - Out_XY[i].ph_frac[id])
                    end
                    if "fl" in Out_XY[i].ph
                        id = findfirst(Out_XY[i].ph .== "fl")
                        field[i] = field[i] / (1.0 - Out_XY[i].ph_frac[id])
                    end
                end

            else
                field[i] = 0.0
            end
        end
    elseif mod == "ph_frac_wt" 
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                if ~isempty(id)  
                    field[i] = Out_XY[i].ph_frac_wt[id[1] ]

                    if rmf == true 
                        if "H2O" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "H2O")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_wt[id])
                        end
                        if "fl" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "fl")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_wt[id])
                        end
                    end

                else
                    field[i] = 0.0
                end
            end
        elseif mod == "ph_frac_vol" 
            for i=1:np
                id       = findall(Out_XY[i].ph .== ss)
                if ~isempty(id)  
                    field[i] = Out_XY[i].ph_frac_vol[id[1] ]

                    if rmf == true 
                        if "H2O" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "H2O")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_vol[id])
                        end
                        if "fl" in Out_XY[i].ph
                            id = findfirst(Out_XY[i].ph .== "fl")
                            field[i] = field[i] / (1.0 - Out_XY[i].ph_frac_vol[id])
                        end
                    end
                else
                    field[i] = 0.0
                end
            end
    elseif mod == "ss_MgNum"
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)  
                mg_id   = findfirst( Out_XY[i].oxides .== "MgO");
                fe_id   = findfirst( Out_XY[i].oxides .== "FeO");
                mg      =  Out_XY[i].SS_vec[id[1]].Comp_apfu[mg_id];
                fe      =  Out_XY[i].SS_vec[id[1]].Comp_apfu[fe_id];
                field[i] = mg / (mg + fe);
            else
                field[i] = 0.0
            end
        end 
    elseif mod == "ss_calc"
        el          = Out_XY[1].elements
        replacements = Dict("Si" => "si", "Ca" => "ca", "Al" => "al")
        for (old, new) in replacements
            el      = replace(el,   old => new)
            calc    = replace(calc, old => new)
        end

        n_el        = length(el)
        global i, j, id
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)  
                
                cmd2eval    = calc
                id          = id[1]

                for j = 1:n_el
                    if occursin(el[j], calc)
                        cmd2eval = replace(cmd2eval, el[j] => "Out_XY[$i].SS_vec[$id].Comp_apfu[$j]")
                    end
                end
                command  = Meta.parse(cmd2eval)
                field[i] = eval(command)

            else
                field[i] = 0.0
            end
        end  
    elseif mod == "ss_calc_sf"

        global i, j, id
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)

            if ~isempty(id)  

                id          = id[1]
                sf        = Out_XY[i].SS_vec[id].siteFractionsNames
                n_sf        = length(sf)

                cmd2eval    = calc_sf
                

                for j = 1:n_sf
                    if occursin(sf[j], calc_sf)
                        cmd2eval = replace(cmd2eval, sf[j] => "Out_XY[$i].SS_vec[$id].siteFractions[$j]")
                    end
                end
                command  = Meta.parse(cmd2eval)
                field[i] = eval(command)

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
    elseif mod == "em_frac_wt"
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            if ~isempty(id)  
                idem     = findall(Out_XY[i].SS_vec[id[1]].emNames .== em)
                field[i] = Out_XY[i].SS_vec[id[1]].emFrac_wt[idem[1]]
            else
                field[i] = 0.0
            end
        end 
    elseif mod == "ox_comp"
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            ox_id    = findfirst(Out_XY[i].oxides .== ox)
            if ~isempty(id)  
                field[i] = Out_XY[i].SS_vec[id[1]].Comp[ox_id]
            else
                field[i] = 0.0
            end
        end 
    elseif mod == "ox_comp_wt"
        for i=1:np
            id       = findall(Out_XY[i].ph .== ss)
            ox_id    = findfirst(Out_XY[i].oxides .== ox)
            if ~isempty(id)  
                field[i] = Out_XY[i].SS_vec[id[1]].Comp_wt[ox_id]
            else
                field[i] = 0.0
            end
        end 
    elseif mod == "of_mod"
        if of == "s_cp"
            for i=1:np
                field[i] = Out_XY[i].s_cp[1];
            end
        elseif of == "alpha"
            for i=1:np
                field[i] = Out_XY[i].alpha[1];
            end
        else
            for i=1:np
                field[i] = Float64(get_property(Out_XY[i], of));
            end
        end
        field[isnan.(field)] .= missing
        if of == "frac_M" || of == "rho_M" || of == "rho_S"
            field[isless.(field, 1e-8)] .= 0.0              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
        end 
    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded      = Matrix{Union{Float64,Missing}}(undef,n,n);


    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded[ii,jj]  = field[k] 
    end

    for i=1:length(data.cells)
        cell   = data.cells[i]

        ii_min = compute_index(data.points[cell[2]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[cell[3]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        for ii = ii_min+1:ii_max-1
            f = (ii - ii_min)/ (ii_max - ii_min)
            gridded[ii, jj_ix] = field[cell[2]]*(1.0 - f) + field[cell[3]]*f
        end

        jj_min = compute_index(data.points[cell[1]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[2]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[1]][1], Xrange[1], dx)
        for jj = jj_min+1:jj_max-1
            f = (jj - jj_min)/ (jj_max - jj_min)
            gridded[ii_ix, jj] = field[cell[1]]*(1.0 - f) + field[cell[2]]*f
        end

        jj_min = compute_index(data.points[cell[4]][2], Yrange[1], dy)
        jj_max = compute_index(data.points[cell[3]][2], Yrange[1], dy)
        ii_ix = compute_index(data.points[cell[4]][1], Xrange[1], dx)
        for jj in jj_min+1:jj_max-1
            f = (jj - jj_min)/ (jj_max - jj_min)
            gridded[ii_ix, jj] = field[cell[4]]*(1.0 - f) + field[cell[3]]*f
        end

        ii_min = compute_index(data.points[data.cells[i][1]][1], Xrange[1], dx)
        ii_max = compute_index(data.points[data.cells[i][4]][1], Xrange[1], dx)
        jj_ix  = compute_index(data.points[data.cells[i][1]][2], Yrange[1], dy)

        for ii = ii_min+1:ii_max-1
            f = (ii - ii_min)/ (ii_max - ii_min)
            gridded[ii, jj_ix] = field[cell[1]]*(1.0 - f) + field[cell[4]]*f

            bot = field[cell[1]]*(1.0 - f) + field[cell[4]]*f
            top = field[cell[2]]*(1.0 - f) + field[cell[3]]*f
            for jj = jj_min+1:jj_max-1
                g = (jj - jj_min)/ (jj_max - jj_min)
                gridded[ii, jj] = bot*(1.0 -g) + top*g
            end
        end

    end
    return gridded, X, Y
end



"""
    Function interpolate AMR grid to regular grid
"""
function get_isopleth_map_te(   mod         ::String, 
                                field       ::String, 
                                field_zr    ::String,
                                calc        ::String,
                                norm_te     ::String,
                                oxi         ::Vector{String},
                                Out_TE_XY   ::Vector{MAGEMin_C.out_tepm},
                                sub         ::Int64,
                                refLvl      ::Int64,
                                data        ::MAGEMinApp.AMR_data,
                                Xrange      ::Tuple{Float64, Float64},
                                Yrange      ::Tuple{Float64, Float64} )

    np          = length(data.points)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Nothing}}(nothing,np);

    if mod == "calc"
        global i
        for i=1:np
            cmd = get_parsed_command( i;  varBuilder=calc, norm=norm_te) 
            field[i] = eval(cmd)
        end
        field[isnan.(field)] .= 0.0
    elseif mod == "zrc"
        for i=1:np
            field[i] = get_property(Out_TE_XY[i], field_zr);
        end
        field[isnothing.(field)] .= 0.0

    end

    n   = 2^(sub + refLvl)+1
    dx  = (data.Xrange[2]-data.Xrange[1])/(n-1)
    dy  = (data.Yrange[2]-data.Yrange[1])/(n-1)

    x   = range(data.Xrange[1], stop = data.Xrange[2], length = n)
    y   = range(data.Yrange[1], stop = data.Yrange[2], length = n)

    X            = repeat(x , n)[:]
    Y            = repeat(y', n)[:]
    
    gridded_TE   = Matrix{Union{Float64,Missing}}(missing,n,n);

    for k=1:np
        ii              = compute_index(data.points[k][1], data.Xrange[1], dx)
        jj              = compute_index(data.points[k][2], data.Yrange[1], dy)
        gridded_TE[ii,jj]  = field[k] 
    end

    return gridded_TE, X, Y
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
    elseif dbin == "igad"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"];        
    elseif dbin == "mb"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "H2O"];     
    elseif dbin == "mbe"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "H2O"];     
    elseif dbin == "um"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "MgO" ;"FeO"; "O"; "H2O"; "S"];
    elseif dbin == "ume"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "MgO" ;"FeO"; "O"; "H2O"; "S"; "CaO"; "Na2O"];        
    elseif dbin == "mp"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "MnO"; "H2O"];
    elseif dbin == "mtl"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO";"Na2O"]; 
    elseif dbin == "mpe"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "MnO"; "H2O"; "CO2"; "S"];
    elseif dbin == "sb11"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "FeO"; "MgO"; "Na2O"]; 
    elseif dbin == "sb21"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "FeO"; "MgO"; "Na2O"]; 
    else
        print("Database not implemented...\n")
    end


    return MAGEMin_ox
end

"""
    function to parse bulk-rock composition file
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
        dbin   		= lowercase(datain[i,idx]);

        test 		= length(db[(db.db .== dbin), :].test);

        idx 		= findall(datain[1,:] .== "sysUnit")[1];
        sysUnit   	= lowercase(datain[i,idx]);

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

        oxide           = get_oxide_list(String(dbin))

        bulkrock_wt     = round.(mol2wt(bulkrock, oxide),digits=6)
        bulkrock2_wt    = round.(mol2wt(bulkrock2, oxide),digits=6)

        push!(db,Dict(  :bulk       => bulk,
                        :title      => title,
                        :comments   => comments,
                        :db         => dbin,
                        :test       => test,
                        :sysUnit    => sysUnit,
                        :oxide      => oxide,
                        :frac       => bulkrock,
                        :frac2      => bulkrock2,
                        :frac_wt    => bulkrock_wt,
                        :frac2_wt   => bulkrock2_wt,
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


function parse_bulk_te(contents, filename, kdsDB)
    try
        content_type, content_string = split(contents, ',');
        decoded = base64decode(content_string);
        input   = String(decoded) ;
        datain  = strip.(string.(readdlm(IOBuffer(input), ';', comments=true, comment_char='#')));

        te_bulk_file_to_db(datain, kdsDB);

        return 1
    catch e
        return 0
    end

end

"""
  function to parse bulk-te composition file
"""
function te_bulk_file_to_db(datain, kds_mod)

    global dbte;

    dbte = dbte[(dbte.composition .== "predefined"), :];

    TE_models   = [AppData.KDs[i][4] for i in 1:length(AppData.KDs)]
    id_TE_model = findfirst(TE_models .== kds_mod)
    KDs_dtb     = MAGEMin_C.create_custom_KDs_database(AppData.KDs[id_TE_model][1], AppData.KDs[id_TE_model][2], AppData.KDs[id_TE_model][3]; info = AppData.KDs[id_TE_model][6])

    id_title 		= findfirst(datain[1,:] .== "title")
    id_comments		= findfirst(datain[1,:] .== "comments")
    id_elements		= findfirst(datain[1,:] .== "elements")
    id_frac         = findfirst(datain[1,:] .== "frac")
    id_frac2        = findfirst(datain[1,:] .== "frac2")

    for i=2:size(datain, 1)
        composition = "custom"
        test 		= length(dbte.test)
        title   	= string(datain[i,id_title])

        comments    = string(datain[i,id_comments])
        elements    = rsplit(datain[i,id_elements],",")
        elements 	= strip.(convert.(String,elements))
        elements 	= replace.(elements,r"\]"=>"",r"\["=>"")

        frac   	    = rsplit(datain[i,id_frac],",")
        frac 		= strip.(convert.(String,frac))
        frac 		= replace.(frac,r"\]"=>"",r"\["=>"")
        frac 		= parse.(Float64,frac)

        bulkte      = MAGEMin_C.adjust_chemical_system( KDs_dtb, frac, elements)
        bulkte     .= round.(bulkte; digits = 4)

        if ~isempty(datain[i,id_frac2])
            frac2  		= rsplit(datain[i,id_frac2],",");
            frac2 		= strip.(convert.(String,frac2));
            frac2 		= replace.(frac2,r"\]"=>"",r"\["=>"");
            frac2		= parse.(Float64,frac2);
            bulkte2     = MAGEMin_C.adjust_chemical_system( KDs_dtb, frac2, elements);
            bulkte2    .= round.(bulkte2; digits = 4)
        else
            bulkte2     = deepcopy(bulkte)
        end

        elements        = KDs_dtb.element_name

        push!(dbte,Dict(    :composition    => composition,
                            :title          => title,
                            :comments       => comments,
                            :test           => test,
                            :elements       => elements,
                            :μg_g           => bulkte,
                            :μg_g2          => bulkte2,
                    ), cols=:union)
    end

end


function read_xlsx_KDs( filename  :: String;
                        sheet_name :: String = "KDs" )

    if !isfile(filename)
        error("File $filename does not exist.")
        return nothing
    else
        info, name    = "", ""
        status  = 0
        XLSX.openxlsx(filename) do xf
            if sheet_name in XLSX.sheetnames(xf)
                sheet   = xf[sheet_name]
                acr     = sheet[1, 1]  
                name    = sheet[1, 2]  
                info    = sheet[1, 3]  

                data    = XLSX.readtable(filename, sheet_name; first_row=2) |> DataFrame

                el      = names(data)[2:end]
                ph      = string.(data[!, "Phase"])
                KDs     = Matrix{String}(string.(data[:, 2:end]))

                return (el, ph, KDs, acr, name, info)
            else
                error("Sheet 'KDs' not found in $filename.")
                return nothing
            end
        end
    end

end

function parse_contents(contents, filename)
    # We need to extract the base64 part and decode it
    content_string  = split(contents, ",")[2]
    file_bytes      = base64decode(content_string)

    # Save to a temporary file
    temp_filename = tempname() * ".xlsx"
    open(temp_filename, "w") do f
        write(f, file_bytes)
    end
    KDs         = read_xlsx_KDs(temp_filename)

    return KDs
end




