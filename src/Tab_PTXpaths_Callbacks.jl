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

function Tab_PTXpaths_Callbacks(app)

    callback!(
        app,
        Output("style-canvas", "is_open"),
        Input("style-canvas-button", "n_clicks"),
        State("style-canvas", "is_open"),
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;

    #save references to bibtex
    callback!(
        app,
        Output("export-removed-save-ptx",   "is_open"),
        Output("export-removed-failed-ptx", "is_open"),
        Input("export-removed-button-ptx",  "n_clicks"),
        State("export-removed-id-ptx",      "value"),
        State("database-dropdown-ptx",      "value"),
        State("sys-unit-ptx",               "value"),
        State("mode-dropdown-ptx",          "value"),
        State("residual-id",                "value"),

        prevent_initial_call=true,
    ) do n_clicks, fname, dtb, sysunit, mode, nRes

        if fname != "filename"
            output  = "_fractionated_bulk_"*dtb
            fileout = fname*output

            n_ox    = length(Out_PTX[1].oxides)
            oxides  = Out_PTX[1].oxides
            n_tot   = length(Out_PTX)

            P       = Vector{Float64}(undef, n_tot)
            T       = Vector{Float64}(undef, n_tot)

            for k=1:n_tot
                P[k]    = Out_PTX[k].P_kbar
                T[k]    = Out_PTX[k].T_C
            end

            rmB      = Matrix{Union{Float64,Missing}}(undef, n_tot, n_ox) .= 0.0
            rmB     .= removedBulk
            if any(isnan, rmB)
                rmB[isnan.(rmB)]    .= 0.0
            end
            rmB[rmB .== 0.0]        .= missing

            rmB2        = Matrix{Union{Float64,Missing}}(undef, n_tot, n_ox) .= 0.0
            cumfrac     = accumulate(+, fracEvol[:,2])
            start_id    = findfirst(removedBulk[:,1] .!= 0.0)
        
            if isnothing(start_id)
                rmB2   .= missing
            else
                rmB2[start_id,:]    .= removedBulk[start_id,:]
                for i=start_id+1:n_tot
                    tmp = removedBulk[i,:] .* fracEvol[i,2] .+  rmB2[i-1,:].*cumfrac[i-1]
                    rmB2[i,:] .= tmp ./sum(tmp)
                end
                if any(isnan, rmB2)
                    rmB2[isnan.(rmB2)]     .= 0.0
                end
                rmB2[rmB2 .== 0.0]        .= missing
            end
            
            # Here we create the dataframe's header:
            MAGEMin_db = DataFrame(         Symbol("point[#]")          => Int64[],
                                            Symbol("P[kbar]")           => Float64[],
                                            Symbol("T[°C]")             => Float64[],
                                            Symbol("Removed $(sysunit)%")     => Float64[],
                                            Symbol("Remaining $(sysunit)%")     => Float64[])

            for i in oxides
                col = i*"_step"
                MAGEMin_db[!, col] = Float64[] 
            end
            MAGEMin_db[!, "Integrated $(sysunit)%"] = Float64[] 
            for i in oxides
                col = i*"_int"
                MAGEMin_db[!, col] = Float64[] 
            end

            for k=1:n_tot
                part_1 = Dict(  "point[#]"      => k,
                                "P[kbar]"       => P[k],
                                "T[°C]"         => T[k],
                                "Removed $(sysunit)%" => fracEvol[k,2],
                                "Remaining $(sysunit)%" => fracEvol[k,1])

                part_2 = Dict(  (oxides[j]*"_step" => rmB[k,j].*100.0)
                                for j in eachindex(oxides))

                part_3 = Dict(  "Integrated $(sysunit)%" => cumfrac[k])

                part_4 = Dict(  (oxides[j]*"_int" => rmB2[k,j].*100.0)
                                for j in eachindex(oxides))

                row    = merge(part_1,part_2,part_3,part_4)   
                push!(MAGEMin_db, row, cols=:union)        
            end

            filename = fileout*".csv"
            CSV.write(filename, MAGEMin_db)
        

            if mode == "fc"
                output  = "_fractionated_phases_"*dtb
                fileout = fname*output

                n_ox    = length(Out_PTX[1].oxides)
                oxides  = Out_PTX[1].oxides
                n_tot   = length(Out_PTX)

                P       = Vector{Float64}(undef, n_tot)
                T       = Vector{Float64}(undef, n_tot)

                for k=1:n_tot
                    P[k]    = Out_PTX[k].P_kbar
                    T[k]    = Out_PTX[k].T_C
                end

                n_ph    = length(ph_names_ptx)

                ph_names_ext_ptx = []
                for i in ph_names_ptx
                    if i != "liq"
                        push!(ph_names_ext_ptx,i)
                    end
                end
                n_ph_e = length(ph_names_ext_ptx)

                x       = Vector{String}(undef, n_tot)
                melt    = zeros(Int64, n_tot)
                Z       = Matrix{Union{Float64,Missing}}(undef, n_ph_e, n_tot) .= missing
                Y       = zeros(Float64, n_ph_e, n_tot)
# add a zero line first
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
        
                # Here we create the dataframe's header:
                MAGEMin_db = DataFrame(         Symbol("point[#]")              => Int64[],
                                                Symbol("P[kbar]")               => Float64[],
                                                Symbol("T[°C]")                 => Float64[],
                                                Symbol("Removed $(sysunit)%")   => Float64[],
                                                Symbol("Remaining $(sysunit)%") => Float64[])


                for i in ph_names_ext_ptx
                    col = i*"_$(sysunit)%"
                    MAGEMin_db[!, col] = Float64[] 
                end
                
                Z = hcat(zeros(length(ph_names_ext_ptx)),Z)
                for k=1:n_tot
                    part_1 = Dict(  "point[#]"              => k,
                                    "P[kbar]"               => P[k],
                                    "T[°C]"                 => T[k],
                                    "Removed $(sysunit)%"   => fracEvol[k,2],
                                    "Remaining $(sysunit)%" => fracEvol[k,1])

                    part_2 = Dict(  (ph_names_ext_ptx[j]*"_$(sysunit)%" => Z[j,k])
                                    for j in eachindex(ph_names_ext_ptx))

                    row    = merge(part_1,part_2)   
                    push!(MAGEMin_db, row, cols=:union)        
                end

                filename = fileout*".csv"
                CSV.write(filename, MAGEMin_db)
            end

            return "success", ""
        else
            return  "", "failed"
        end
    end

    #save references to bibtex
    callback!(
        app,
        Output("export-citation-save-ptx", "is_open"),
        Output("export-citation-failed-ptx", "is_open"),
        Input("export-citation-button-ptx", "n_clicks"),
        State("export-citation-id-ptx", "value"),
        State("database-dropdown-ptx","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            output_bib      = "_"*dtb*".bib"
            fileout         = fname*output_bib
            magemin         = "MAGEMin"
            bib             = import_bibtex("./references/references.bib")
            
            print("\nSaving references for computed PTX path\n")
            print("output path: $(pwd())\n")

            n_ref           = length(bib.keys)
            id_db           = findfirst(bib[bib.keys[i]].fields["info"] .== dtb for i=1:n_ref)
            id_magemin      = findfirst(bib[bib.keys[i]].fields["info"] .== magemin for i=1:n_ref)
            
            selection       = String[]

            push!(selection, String(bib.keys[id_db]))
            push!(selection, String(bib.keys[id_magemin]))
            
            if dtb == "ume"
                id_green = findfirst(bib[bib.keys[i]].fields["info"] .== "mb" for i=1:n_ref)
                push!(selection, String(bib.keys[id_green]))
            elseif dtb == "mpe"
                id_green = findfirst(bib[bib.keys[i]].fields["info"] .== "mb" for i=1:n_ref)
                push!(selection, String(bib.keys[id_green]))
                id_flc = findfirst(bib[bib.keys[i]].fields["info"] .== "flc" for i=1:n_ref)
                push!(selection, String(bib.keys[id_flc]))
                id_occm = findfirst(bib[bib.keys[i]].fields["info"] .== "occm" for i=1:n_ref)
                push!(selection, String(bib.keys[id_occm]))
                id_um= findfirst(bib[bib.keys[i]].fields["info"] .== "um" for i=1:n_ref)
                push!(selection, String(bib.keys[id_um]))
            end

            selected_bib    = Bibliography.select(bib, selection)
            
            export_bibtex(fileout, selected_bib)

            return "success", ""
        else
            return  "", "failed"
        end
    end

  
    #save all table to file
    callback!(
        app,
        Output("data-all-csv-ptx-save", "is_open"),
        Output("data-all-save-csv-ptx-failed", "is_open"),
        Input("save-all-csv-ptx-button", "n_clicks"),
        State("Filename-all-ptx-id", "value"),
        State("database-dropdown-ptx","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_"*dtb
            fileout = fname*datab

            MAGEMin_data2dataframe(Out_PTX,dtb,fileout)
            return "success", ""
        else
            return  "", "failed"
        end
    end


    #save all table to an inlined CSV file
    callback!(
        app,
        Output("data-all-csv-inlined-ptx-save", "is_open"),
        Output("data-all-save-csv-inlined-ptx-failed", "is_open"),
        Input("save-all-csv-inlined-ptx-button", "n_clicks"),
        State("Filename-all-ptx-id", "value"),
        State("database-dropdown-ptx","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_inlined_"*dtb
            fileout = fname*datab

            MAGEMin_data2dataframe_inlined(Out_PTX,dtb,fileout)
            return "success", ""
        else
            return  "", "failed"
        end
    end

    #save all table to file
    callback!(
        app,
        Output("download-all-table-ptx-text", "data"),
        Output("data-all-table-ptx-save", "is_open"),
        Output("data-all-save-table-ptx-failed", "is_open"),
        Input("save-all-table-ptx-button", "n_clicks"),
        State("Filename-all-ptx-id", "value"),
        State("database-dropdown-ptx","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_"*dtb
            fileout = fname*datab*".txt"
            file    = MAGEMin_data2table(Out_PTX,dtb)            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "success", ""
        else
            output = nothing
            return output, "", "failed"
        end
    end


    """
        Callback to update preview of PT path
    """
    callback!(
        app,
        Output("path-plot", "figure"),
        Input("ptx-table", "data"),
        ) do data

        dataout = copy(data)
        np      = length(dataout)
        x       = zeros(np)
        y       = zeros(np)

        annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,np)

        for i=1:np
            x[i] = dataout[i][Symbol("col-2")]
            y[i] = dataout[i][Symbol("col-1")]
            annotations[i] =   attr(    xref        = "x",
                                        yref        = "y",
                                        x           = x[i],
                                        y           = y[i],
                                        xshift      = -10,
                                        yshift      = +10,
                                        text        = "#$i",
                                        showarrow   = false,
                                        visible     = true,
                                        font        = attr( size = 10, color = "#212121"),
                                    )  
        end

        Xmin    = maximum([0.0,minimum(x) - 50.0])
        Xmax    = maximum(x) + 50.0
        Ymin    = maximum([0.0,minimum(y) - 2.0])
        Ymax    = maximum(y) + 2.0

        df = DataFrame(
            x=x,
            y=y,
        )
    
        layout_ptx  = Layout(
            font        = attr(size = 10),
            height      = 240,
            margin      = attr(autoexpand = false, l=16, r=16, b=16, t=16),
            autosize    = false,
            xaxis_title = "Temperature [°C]",
            yaxis_title = "Pressure [kbar]",
            xaxis_range = [Xmin,Xmax], 
            yaxis_range = [Ymin,Ymax],
            annotations = annotations,
            showlegend  = false,
            xaxis       = attr(     fixedrange    = true,
                            ),
            yaxis       = attr(     fixedrange    = true,
                            ),
        )

        fig = plot(df, x=:x, y=:y, layout_ptx)
    
        return fig
    end


    callback!(
        app,
        Output("output-data-uploadn-ptx",           "is_open"   ),
        Output("output-data-uploadn-failed-ptx",    "is_open"   ),

        Input("transfer-bulk-button",               "n_clicks"  ),
        Input("upload-bulk-ptx",                    "contents"  ),

        State("upload-bulk-ptx",                    "filename"  ),
        State("transfer-bulk-name",                 "value"     ),
        State("transfer-bulk-id",                   "value"     ),

        prevent_initial_call=true,
    ) do bulk, contents, filename, transfer_bulk_name, transfer_bulk_id

        bid         = pushed_button( callback_context() ) 
        
        if bid == "upload-bulk-ptx"
            if !(contents isa Nothing)
                status = parse_bulk_rock(contents, filename)
                if status == 1
                    return "success", ""
                else
                    return "", "failed"
                end
            end
        elseif bid == "transfer-bulk-button"
            global point_id

            bulkrock    = zeros(Float64,length(Out_XY[point_id].oxides))
            oxides      = Out_XY[point_id].oxides
            dbin        = Out_XY[point_id].database
            test 		= length(db[(db.db .== dbin), :].test);
            if transfer_bulk_id == "Solid"
                bulkrock = Out_XY[point_id].bulk_S
            elseif transfer_bulk_id == "Melt"
                bulkrock = Out_XY[point_id].bulk_M
            else
                bulkrock = Out_XY[point_id].bulk
            end

            if sum(bulkrock) == 0.0
                return "", "failed"
            else
                bulkrock2       = copy(bulkrock)
                bulkrock_wt     = round.(mol2wt(bulkrock, oxides),  digits = 6)
                bulkrock2_wt    = round.(mol2wt(bulkrock2, oxides), digits = 6)
                bulkrock        = round.(bulkrock   .* 100.0,       digits = 6)
                bulkrock2       = round.(bulkrock2  .* 100.0,       digits = 6)
                push!(db,Dict(  :bulk       => "custom",
                                :title      => transfer_bulk_name*"_"*transfer_bulk_id,
                                :comments   => "pd2ptx",
                                :db         => dbin,
                                :test       => test,
                                :sysUnit    => "mol",
                                :oxide      => oxides,
                                :frac       => bulkrock,
                                :frac2      => bulkrock2,
                                :frac_wt    => bulkrock_wt,
                                :frac2_wt   => bulkrock2_wt,
                            ), cols=:union)

                return "success", ""
            end
        end

    end


    """
        Callback to compute and display PTX path
    """
    callback!(
        app,
        Output("ptx-frac-plot",         "figure"),
        Output("ptx-frac-plot",         "config"),
        
        Input("phase-selector-id",      "value"),

        State("database-dropdown-ptx",  "value"),
        State("test-dropdown-ptx",      "value"),
        State("sys-unit-ptx",           "value"),

        prevent_initial_call = true,

        ) do    phases,
                dtb,    test,   sysunit


        bid         = pushed_button( callback_context() )    # get which button has been pushed
        title       = db[(db.db .== dtb), :].title[test+1]


        if ~isempty(phases)
            layout_comp  = initialize_comp_layout(sysunit)

            data_comp_plot = get_data_comp_plot(sysunit,phases)
            
            fig     = plot( data_comp_plot,layout_comp)
        else
            fig     =  plot(    Layout( height= 360 ))
        end



        config   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename = "path_composition_"*replace(title, " " => "_"),
                                    width    =  960,
                                    height   =  360,
                                    scale    =  2.0,       ).fields)

        return fig, config
    end



    """
        Callback to compute and display TAS diagram
    """
    callback!(
        app,
        Output("TAS-plot",              "figure"),
        Output("TAS-plot",              "config"),
        Output("TAS-pluto-plot",        "figure"),
        Output("TAS-pluto-plot",        "config"),
        Output("AFM-plot",              "figure"),
        Output("AFM-plot",              "config"),
        Input("phase-selector-id",      "value"),

        State("database-dropdown-ptx",  "value"),
        State("test-dropdown-ptx",      "value"),
        State("sys-unit-ptx",           "value"),

        prevent_initial_call = true,

        ) do    phases,
                dtb,    test,   sysunit

        bid         = pushed_button( callback_context() )    # get which button has been pushed
        title       = db[(db.db .== dtb), :].title[test+1]

        if "liq" in phases
            tas, layout_ptx = get_TAS_diagram(phases,title)
            figTAS          = plot( tas, layout_ptx)
            tas_pluto, layout_ptx_pluto = get_TAS_pluto_diagram(phases,title)
            figTAS_pluto    = plot( tas_pluto, layout_ptx_pluto)
            afm, layout_afm = get_AFM()
            figAFM          = plot( afm, layout_afm)
        else
            figTAS          =  plot(Layout( height= 360 ))
            figTAS_pluto    =  plot(Layout( height= 360 ))
            figAFM          =  plot(Layout( height= 640 ))
        end

        configTAS   = PlotConfig(       toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "TAS_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configTAS_pluto = PlotConfig(   toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "TAS_plutonic_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configAFM = PlotConfig(         toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "AFM_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figTAS, configTAS, figTAS_pluto, configTAS_pluto, figAFM, configAFM
    end


    """
        Callback to compute and display PTX path
    """
    callback!(
        app,
        Output("display-liquidus-textarea",     "value"),
        Output("display-solidus-textarea",     "value"),
        Input("find-liquidus-button",          "n_clicks"),
        Input("find-solidus-button",           "n_clicks"),
        State("phase-selection-PTX",            "value"),
        State("liquidus-pressure-val-id",       "value"),
        State("liquidus-tolerance-val-id",      "value"),
        State("solidus-pressure-val-id",       "value"),
        State("solidus-tolerance-val-id",      "value"),

        State("display-liquidus-textarea",     "value"),
        State("display-solidus-textarea",     "value"),

        State("database-dropdown-ptx",  "value"),
        State("dataset-dropdown-ptx",  "value"),
        State("buffer-dropdown-ptx",    "value"),
        State("solver-dropdown-ptx",    "value"),    
        State("verbose-dropdown-ptx",   "value"),   
        State("table-bulk-rock-ptx",    "data"),  
        State("buffer-1-mul-id-ptx",    "value"),  

        State("mb-cpx-switch-ptx",      "value"),           # false,true -> 0,1
        State("limit-ca-opx-id-ptx",    "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id-ptx",      "value"),           # 0.0-1.0 -> 0,1
        State("test-dropdown-ptx",      "value"),
        State("select-bulk-unit-ptx",    "value"),

        prevent_initial_call = true,

        ) do    compute,    compute_sol,     phase_selection,   pressure,   tolerance, sol_pressure, sol_tolerance,
                Tliq,       Tsol,
                dtb,        dataset,        bufferType,     solver,
                verbose,    bulk,           bufferN,
                cpx,        limOpx,         limOpxVal,      test,       sysunit

        bid             = pushed_button( callback_context() )    # get which button has been pushed

        if bid == "find-liquidus-button"
            bufferN                 = Float64(bufferN)               # convert buffer_n to float
            bulk_ini, bulk_ini, oxi = get_bulkrock_prop(bulk, bulk)  

            Tliq = compute_Tliq(    sysunit,    pressure,   tolerance,  bulk_ini,   oxi,    phase_selection,
                                    dtb,        dataset,    bufferType, solver,
                                    verbose,    bulk,       bufferN,
                                    cpx,        limOpx,     limOpxVal  )
        elseif bid == "find-solidus-button"
            bufferN                 = Float64(bufferN)               # convert buffer_n to float
            bulk_ini, bulk_ini, oxi = get_bulkrock_prop(bulk, bulk)  

            Tsol = compute_Tsol(    sysunit,    sol_pressure,   sol_tolerance,  bulk_ini,   oxi,    phase_selection,
                                    dtb,        dataset,    bufferType, solver,
                                    verbose,    bulk,       bufferN,
                                    cpx,        limOpx,     limOpxVal  )
        end

        return Tliq, Tsol
    end

    # Callback to hide rows for phases not in phase_infos_PTX
    callback!(app,
        [Output("row-name-$mineral",        "style") for mineral in keys(AppData.mineral_style)]...,  # Outputs for each row
        [Output("row-color-$mineral",       "style") for mineral in keys(AppData.mineral_style)]...,  # Outputs for each row
        [Output("row-linestyle-$mineral",   "style") for mineral in keys(AppData.mineral_style)]...,  # Outputs for each row
        Input("ptx-plot", "figure"),

        prevent_initial_call = true,  # Input: selected phases from a dropdown or other component

    ) do click
        global phase_infos_PTX
        phase_selection = vcat(phase_infos_PTX.act_ss, phase_infos_PTX.act_pp)

        styles_name, styles_color, styles_linestyle = [], [], []
        for mineral in keys(AppData.mineral_style)
            if mineral in phase_selection
                push!(styles_name,      Dict("margin-bottom" => "0px", "height" => "24px", "display" => "block"))
                push!(styles_color,     Dict("margin-bottom" => "0px", "height" => "24px", "display" => "block"))
                push!(styles_linestyle, Dict("margin-bottom" => "0px", "height" => "24px", "display" => "block"))
            else
                push!(styles_name,      Dict("margin-bottom" => "0px", "height" => "24px", "display" => "none"))
                push!(styles_color,     Dict("margin-bottom" => "0px", "height" => "24px", "display" => "none"))
                push!(styles_linestyle, Dict("margin-bottom" => "0px", "height" => "24px", "display" => "none"))
            end
        end

        return styles_name..., styles_color..., styles_linestyle...
    end

    # Callback to save updated linestyles
    callback!(app,  Output("color-style-save", "is_open"),
                    Input("save-color-style", "n_clicks"),
                    [State("colorpicker-$mineral",  "value") for mineral in keys(AppData.mineral_style)]...,  # Outputs for each row
                    [State("dropdown-$mineral",     "value") for mineral in keys(AppData.mineral_style)]...,  # Outputs for each row
                    prevent_initial_call = true ) do n_clicks, style...

        if n_clicks == 0
            return false
        end

        mineral_names   = collect(keys(AppData.mineral_style))            
        np              = length(keys(AppData.mineral_style))
        color           = style[1:np]
        linestyle       = style[np+1:end]

        mineral_style = Dict{String, Vector{Any}}()
        for (i, ph) in enumerate(mineral_names)
            mineral_style[ph] = [color[i], linestyle[i], 1.0]
        end

        # Save the updated dictionary to disk
        save_style(mineral_style)

        return "Success"
    end

    """
        Callback to compute and display PTX path
    """
    callback!(
        app,
        Output("ptx-plot",              "figure"),
        Output("ptx-plot",              "config"),
        Output("ptx-extracted-plot",    "figure"),
        Output("ptx-extracted-plot",    "config"),
        Output("ptx-removed-plot",      "figure"),
        Output("ptx-removed-plot",      "config"),
        Output("ptx-removed-int-plot",  "figure"),
        Output("ptx-removed-int-plot",  "config"),
        Output("phase-selector-id",     "options"),
        Output("output-loading-id-ptx", "children"),

        Input("compute-path-button",    "n_clicks"),
        Input("sys-unit-ptx",           "value"),
        Input("display-mode",           "value"),
        Input("ext-display-mode",       "value"),

        State("select-bulk-unit-ptx",   "value"),
        State("phase-selection-PTX",    "value"),
        State("pure-phase-selection-PTX","value"),
        State("phase-selector-id",      "options"),
        State("n-steps-id-ptx",         "value"),
        State("ptx-table",              "data"),
        State("mode-dropdown-ptx",      "value"),
        State("assimilation-dropdown-ptx", "value"),
        State("variable-buffer-ptx-id", "value"),
        
        State("database-dropdown-ptx",  "value"),
        State("dataset-dropdown-ptx",  "value"),
        State("buffer-dropdown-ptx",    "value"),
        State("solver-dropdown-ptx",    "value"),    
        State("verbose-dropdown-ptx",   "value"),   
        State("table-bulk-rock-ptx",    "data"),  
        State("table-2-bulk-rock-ptx",  "data"),  
        State("buffer-1-mul-id-ptx",    "value"),  

        State("mb-cpx-switch-ptx",      "value"),           # false,true -> 0,1
        State("limit-ca-opx-id-ptx",    "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id-ptx",      "value"),           # 0.0-1.0 -> 0,1
        State("test-dropdown-ptx",      "value"),
        State("sys-unit-ptx",           "value"),

        State("connectivity-id",        "value"),
        State("residual-id",            "value"),
    
        prevent_initial_call = true,

        ) do    compute,    upsys,      display_mode,               ext_display_mode,    
                sys_unit,   phase_selection, pure_phase_selection,  phase_list, nsteps,     PTdata,     mode,   assim,  var_buffer,
                dtb,        dataset,    bufferType, solver,
                verbose,    bulk,       bulk2,      bufferN,
                cpx,        limOpx,     limOpxVal,  test,   sysunit,
                nCon,       nRes  

        bid                     = pushed_button( callback_context() )    # get which button has been pushed
        phase_selection         = remove_phases(string_vec_diff(phase_selection,pure_phase_selection,dtb),dtb)
        title                   = db[(db.db .== dtb), :].title[test+1]
        loading                 = ""

        if bid == "compute-path-button"

            global Out_PTX, ph_names_ptx, phase_infos_PTX, layout_ptx, layout_extracted_ptx, data_plot_ptx, fracEvol, removedBulk, layout_rm_ptx, data_comp_rm_plot, layout_rm_int_ptx, data_comp_rm_int_plot

            bufferN                     = Float64(bufferN)               # convert buffer_n to float
            bulk_ini, bulk_assim, oxi   = get_bulkrock_prop(bulk, bulk2; sys_unit=sys_unit)  

            compute_new_PTXpath(    nsteps,     PTdata,     mode,       bulk_ini,  bulk_assim,  oxi,    phase_selection,    assim, var_buffer,
                                    dtb,        dataset,    bufferType, solver,
                                    verbose,    bufferN,
                                    cpx,        limOpx,     limOpxVal,
                                    nCon,       nRes                                  )

            phase_infos_PTX             = get_phase_infos(Out_PTX)


            layout_ptx                  = initialize_layout(title,sysunit)
            layout_extracted_ptx        = initialize_ext_layout(title,sysunit)
            data_plot_ptx, phase_list   = get_data_plot(display_mode,sysunit)
            data_extracted_plot_ptx, phase_list_ext   = get_extracted_data_plot(ext_display_mode,sysunit,mode,nRes,nCon)

            figPTX                      = plot(data_plot_ptx,layout_ptx)
            figExtractedPTX             = plot(data_extracted_plot_ptx,layout_extracted_ptx)

            layout_rm_ptx               = initialize_rm_layout()
            data_comp_rm_plot           = get_data_comp_rm_plot()

            figrmPTX                    = plot(data_comp_rm_plot,layout_rm_ptx)

            layout_rm_int_ptx           = initialize_rm_layout()
            data_comp_rm_int_plot       = get_data_comp_rm_int_plot()

            figrmintPTX                 = plot(data_comp_rm_int_plot,layout_rm_int_ptx)

        elseif bid == "sys-unit-ptx" || bid == "ext-display-mode" || bid == "display-mode"
            data_plot_ptx, phase_list   = get_data_plot(display_mode,sysunit)
            data_extracted_plot_ptx, phase_list_ext   = get_extracted_data_plot(ext_display_mode,sysunit,mode,nRes,nCon)

            layout_ptx[:yaxis_title]    = "Phase fraction ["*sysunit*"%]"
            layout_extracted_ptx[:yaxis_title]        = "Extracted phase fraction ["*sysunit*"%]"
            figPTX                  = plot(data_plot_ptx,layout_ptx)
            figExtractedPTX         = plot(data_extracted_plot_ptx,layout_extracted_ptx)
            figrmPTX                = plot(data_comp_rm_plot,layout_rm_ptx)
            figrmintPTX             = plot(data_comp_rm_int_plot,layout_rm_int_ptx)
        else
            figPTX                  = plot(    Layout( height= 320 ))
            figExtractedPTX         = plot(    Layout( height= 320 ))
            figrmPTX                = plot(    Layout( height= 320 ))
            figrmintPTX             = plot(    Layout( height= 320 ))
        end

        configPTX   = PlotConfig(   toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename =  "PTX_path_"*replace(title, " " => "_"),
                                    height   =  360,
                                    width    =  960,
                                    scale    =  2.0,       ).fields)
        configExtractedPTX   = PlotConfig(   toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename =  "PTX_path_extracted_"*replace(title, " " => "_"),
                                    height   =  360,
                                    width    =  960,
                                    scale    =  2.0,       ).fields)
        configrmPTX   = PlotConfig( toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename =  "PTX_path_removed_"*replace(title, " " => "_"),
                                    height   =  360,
                                    width    =  960,
                                    scale    =  2.0,       ).fields)
        configrmintPTX   = PlotConfig( toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename =  "PTX_path_integrated_removed_"*replace(title, " " => "_"),
                                    height   =  360,
                                    width    =  960,
                                    scale    =  2.0,       ).fields)

        return figPTX, configPTX, figExtractedPTX, configExtractedPTX, figrmPTX, configrmPTX, figrmintPTX, configrmintPTX, phase_list, loading#, disp_frac
    end


    # callback to display ca-orthopyroxene limiter
    callback!(
        app,
        Output("switch-opx-id-ptx", "style"),
        Output("dataset-ptx-display-id", "style"),
        Input("database-dropdown-ptx", "value"),
    ) do value
        # global db
        if value == "ig"
            style  = Dict("display" => "none")
        elseif value == "igd"
            style  = Dict("display" => "block")    
        elseif value == "alk"
            style  = Dict("display" => "block")  
        else 
            style  = Dict("display" => "none")
        end

        if value == "sb11" || value == "sb21"
            style_dataset = Dict("display" => "none")
        else
            style_dataset = Dict("display" => "block")
        end

        return style, style_dataset
    end


    # callback to display clinopyroxene choice for the metabasite database
    callback!(
        app,
        Output("switch-cpx-id-ptx",     "style"),
        Input("database-dropdown-ptx",  "value"),
    ) do value

        if value == "mb" || value == "mbe"
            style  = Dict("display" => "block")
        else 
            style  = Dict("display" => "none")
        end
        return style
    end

    callback!(
        app,
        Output("show-residual-id",      "style"),
        Input("mode-dropdown-ptx",      "value"),
    ) do value

        if value == "fc"
            style  = Dict("display" => "block")
        else 
            style  = Dict("display" => "none")
        end
        return style
    end

    callback!(
        app,
        Output("show-connectivity-id",  "style"),
        Input("mode-dropdown-ptx",      "value"),
    ) do value
  
        if value == "fm"
            style  = Dict("display" => "block")
        else 
            style  = Dict("display" => "none")
        end
        return style
    end


    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("buffer-1-id-ptx",               "style"),
        Output("variable-buffer-display-id",    "style"),
        Output("variable-buffer-ptx-id",        "value"),

        Input("buffer-dropdown-ptx", "value"),
    ) do value

        if value != "none"
            b1              = Dict("display" => "block")
            buffer_display  = Dict("display" => "block")
            var_buff        = true
        else
            b1              = Dict("display" => "none")
            buffer_display  = Dict("display" => "none")
            var_buff        = false
        end

        return b1, buffer_display, var_buff
    end



    callback!(
        app,
        Output("table-bulk-rock-ptx","data"),
        Output("test-dropdown-ptx","options"),
        Output("test-dropdown-ptx","value"),
        Output("database-caption-ptx","value"),
        Output("phase-selection-PTX","options"),
        Output("phase-selection-PTX","value"),
        Output("pure-phase-selection-PTX","options"),
        Output("pure-phase-selection-PTX","value"),

        Output("dataset-dropdown-ptx","options"),
        Output("dataset-dropdown-ptx","value"),
        Input("select-bulk-unit-ptx","value"),

        Input("test-dropdown-ptx","value"),
        Input("database-dropdown-ptx","value"),
        Input("output-data-uploadn-ptx", "is_open"),        # this listens for changes and updated the list

        State("table-bulk-rock-ptx","data"),

        prevent_initial_call=false,
    ) do sys_unit, 
        test, dtb, update, tb_data

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        if sys_unit == 1
            data        =   [Dict(  "oxide"     => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                    "fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac[1][i])
                                        for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
        elseif sys_unit == 2
            data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                    "fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac_wt[1][i])
                                        for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
        end


        opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                "value" => db[(db.db .== dtb), :].test[i]  )
                                    for i=1:length(db[(db.db .== dtb), :].test)]

        cap         = dba[(dba.acronym .== dtb) , :].database[1]      
        
        val         = t

        db_in       = retrieve_solution_phase_information(dtb)

        # this is the phase selection part for the database when compute a diagram
        phase_selection_options = [Dict(    "label"     => " "*i,
                                            "value"     => i )
                                                for i in db_in.ss_name ]
        phase_selection_value   = db_in.ss_name


        # this is the phase selection part for the database when compute a diagram
        pp_all  = db_in.data_pp
        pp_disp = setdiff(pp_all, AppData.hidden_pp)

        pure_phase_selection_options = [Dict(    "label"     => " "*i,
                                                 "value"     => i )
                                                for i in pp_disp ]
        pure_phase_selection_value   = pp_disp

        dataset_options = [Dict(    "label"     => "ds$(db_in.dataset_opt[i])",
                                    "value"     => db_in.dataset_opt[i] )
                                for i = 1:length(db_in.dataset_opt) ]
        dataset_value    = db_in.db_dataset

        return data, opts, val, cap, phase_selection_options, phase_selection_value, pure_phase_selection_options, pure_phase_selection_value, dataset_options, dataset_value
    end



    callback!(
        app,
        Output("table-2-bulk-rock-ptx","data"),
        Output("test-2-dropdown-ptx","options"),
        Output("test-2-dropdown-ptx","value"),

        Input("select-bulk-unit-ptx","value"),

        Input("test-2-dropdown-ptx","value"),
        Input("database-dropdown-ptx","value"),
        Input("output-data-uploadn-ptx", "is_open"),        # this listens for changes and updated the list

        State("table-2-bulk-rock-ptx","data"),

        prevent_initial_call=true,
    ) do sys_unit, 
        test, dtb, update, 
        tb_data

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        if (~isempty(db[(db.db .== dtb) .& (db.test .== t), :].frac2[1]))
            if sys_unit == 1
                data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                        "fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac2[1][i])
                                            for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
            elseif sys_unit == 2
                data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                        "fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac2_wt[1][i])
                                            for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
            end
        else
            if sys_unit == 1    
                data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                        "fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac[1][i])
                                            for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
            elseif sys_unit == 2
                data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                        "fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac_wt[1][i])
                                            for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]
            end
        end

        opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                "value" => db[(db.db .== dtb), :].test[i]  )
                                    for i=1:length(db[(db.db .== dtb), :].test)]

        # cap         = dba[(dba.acronym .== dtb) , :].database[1]      
        
        val         = t
        return data, opts, val                  
    end

    callback!(app,
        Output("collapse-disp-opt", "is_open"),
        [Input("button-disp-opt", "n_clicks")],
        [State("collapse-disp-opt", "is_open")], ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open    
    end

    callback!(app,
        Output("collapse-path-opt", "is_open"),
        [Input("button-path-opt", "n_clicks")],
        [State("collapse-path-opt", "is_open")], ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open    
    end

    callback!(app,
        Output("collapse-pathdef", "is_open"),
        [Input("button-pathdef", "n_clicks")],
        [State("collapse-pathdef", "is_open")], ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open    
    end

    callback!(app,
        Output("collapse-path", "is_open"),
        [Input("button-path", "n_clicks")],
        [State("collapse-path", "is_open")], ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open    
    end

    callback!(app,
        Output("collapse-path-preview", "is_open"),
        [Input("button-path-preview", "n_clicks")],
        [State("collapse-path-preview", "is_open")], ) do  n, is_open
            
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open    
    end

    callback!(app,
        Output("collapse-config", "is_open"),
        [Input("button-config", "n_clicks")],
        [State("collapse-config", "is_open")], ) do  n, is_open
            
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open    
    end

    callback!(app,
        Output("collapse-bulk-ptx", "is_open"),
        [Input("button-bulk-ptx", "n_clicks")],
        [State("collapse-bulk-ptx", "is_open")], ) do  n, is_open
            
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open    
    end


    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-phase-selection-PTX", "is_open"),
        [Input("button-phase-selection-PTX", "n_clicks")],
        [State("collapse-phase-selection-PTX", "is_open")], ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end

    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-pure-phase-selection-PTX", "is_open"),
        [Input("button-pure-phase-selection-PTX", "n_clicks")],
        [State("collapse-pure-phase-selection-PTX", "is_open")], ) do  n, is_open
        
        if isnothing(n); n=0 end

        if n>0
            if is_open==1
                is_open = 0
            elseif is_open==0
                is_open = 1
            end
        end
        return is_open 
            
    end



    callback!(app,
        Output("ptx-table",                 "data"      ),
        Output("ptx-table",                 "columns"   ),
        Output("table-2-id-ptx",            "style"     ),
        Output("test-2-id-ptx",             "style"     ),

        Input("assimilation-dropdown-ptx",  "value"     ),
        Input("add-row-button",             "n_clicks"  ),
        Input("variable-buffer-ptx-id",     "value"     ),

        State("assimilation-dropdown-ptx",  "value"     ),
        State("ptx-table",                  "data"      ),
        State("ptx-table",                  "columns"   ),

        prevent_initial_call = true,

        ) do value, n_clicks, var_buffer, assim, data, colout

        bid                     = pushed_button( callback_context() )    # get which button has been pushed

        dataout = copy(data)
        if value == "true"
            table2  = Dict("display" => "block")  
            test2   = Dict("display" => "block")  
        else
            table2  = Dict("display" => "none") 
            test2   = Dict("display" => "none") 
        end

        if assim == "true"
            if var_buffer == false
                colout = [  Dict("name" => "P [kbar]",  "id"    => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "T [°C]",    "id"    => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "Add [mol%]", "id"   => "col-3", "deletable" => false, "renamable" => false, "type" => "numeric")]

                if n_clicks > 0 && bid == "add-row-button"
                    add = Dict(Symbol("col-1") => 7.5, Symbol("col-2") => 1000.0, Symbol("col-3") => 0.0)
                    push!(dataout,add)
                end
            elseif var_buffer == true
                colout = [  Dict("name" => "P [kbar]",  "id"        => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "T [°C]",    "id"        => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "Add [mol%]", "id"       => "col-3", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "Buffer",     "id"       => "col-4", "deletable" => false, "renamable" => false, "type" => "numeric")]

                if n_clicks > 0 && bid == "add-row-button"
                    add = Dict(Symbol("col-1") => 7.5, Symbol("col-2") => 1000.0, Symbol("col-3") => 0.0, Symbol("col-4") => 0.0)
                    push!(dataout,add)
                end
            end

        else
            if var_buffer == false
                colout = [  Dict("name" => "P [kbar]",  "id"   => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "T [°C]",    "id"   => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric")]

                if n_clicks > 0 && bid == "add-row-button"
                    add = Dict(Symbol("col-1") => 7.5, Symbol("col-2") => 1000.0)
                    push!(dataout,add)
                end
            elseif var_buffer == true
                colout = [  Dict("name" => "P [kbar]",  "id"        => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "T [°C]",    "id"        => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "Buffer",    "id"        => "col-4", "deletable" => false, "renamable" => false, "type" => "numeric")]

                if n_clicks > 0 && bid == "add-row-button"
                    add = Dict(Symbol("col-1") => 7.5, Symbol("col-2") => 1000.0, Symbol("col-4") => 0.0)
                    push!(dataout,add)
                end
            end
        end

        return dataout, colout, table2, test2
    end

    return app
end