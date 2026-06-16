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

        prevent_initial_call=true,
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
            mkpath("./output")
            output  = "_extracted_bulk_"*dtb
            fileout = "./output/"*fname*output

            n_ox    = length(Out_PTX[1].oxides)
            oxides  = Out_PTX[1].oxides
            n_tot   = length(Out_PTX)

            P       = Vector{Float64}(undef, n_tot)
            T       = Vector{Float64}(undef, n_tot)

            for k=1:n_tot
                P[k]    = display_pressure(Out_PTX[k].P_kbar)
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
            MAGEMin_db = DataFrame(         Symbol("point[#]")                  => Int64[],
                                            Symbol("P[$(pressure_unit_label())]")  => Float64[],
                                            Symbol("T[°C]")                     => Float64[],
                                            Symbol("Step removed $(sysunit)%")       => Float64[])

            for i in oxides
                col = i*"_step"
                MAGEMin_db[!, col] = Float64[] 
            end

            MAGEMin_db[!, "Instantaneous removed $(sysunit)%"] = Float64[] 
            MAGEMin_db[!, "Accumulated removed $(sysunit)%"] = Float64[] 
            MAGEMin_db[!, "Accumulated remaining $(sysunit)%"] = Float64[] 
            for i in oxides
                col = i*"_acc"
                MAGEMin_db[!, col] = Float64[] 
            end

            # for k=1:n_tot
            #     part_1 = Dict(  "point[#]"                  => k,
            #                     "P[kbar]"                   => P[k],
            #                     "T[°C]"                     => T[k],
            #                     "Removed    $(sysunit)%"    => fracEvol[k,2],
            #                     "Remaining  $(sysunit)%"    => fracEvol[k,1])

            #     part_2 = Dict(  (oxides[j]*"_step" => rmB[k,j].*100.0)
            #                     for j in eachindex(oxides))

            #     part_3 = Dict(  "Integrated $(sysunit)%" => cumfrac[k])

            #     part_4 = Dict(  (oxides[j]*"_int" => rmB2[k,j].*100.0)
            #                     for j in eachindex(oxides))

            #     row    = merge(part_1,part_2,part_3,part_4)   
            #     push!(MAGEMin_db, row, cols=:union)        
            # end

            step_rm = zeros(Float64, n_tot)
            step_rm[2:end] = fracEvol[2:end,2] - fracEvol[1:end-1,2]
            for k=1:n_tot
                part_1 = Dict(  "point[#]"                  => k,
                                "P[$(pressure_unit_label())]" => P[k],
                                "T[°C]"                     => T[k],
                                "Step removed $(sysunit)%"  => step_rm[k])

                part_2 = Dict(  (oxides[j]*"_step" => rmB[k,j].*100.0)
                                for j in eachindex(oxides))

                part_3 = Dict(  "Instantaneous removed $(sysunit)%"   => fracEvol[k,3],
                                "Accumulated removed $(sysunit)%"     => fracEvol[k,2],
                                "Accumulated remaining $(sysunit)%"   => fracEvol[k,1])

                part_4 = Dict(  (oxides[j]*"_acc" => rmB2[k,j].*100.0)
                                for j in eachindex(oxides))

                row    = merge(part_1,part_2,part_3,part_4)   
                push!(MAGEMin_db, row, cols=:union)        
            end


            filename = fileout*".csv"
            CSV.write(filename, MAGEMin_db)
        

            if mode == "fc"
                output  = "_extracted_phases_"*dtb
                fileout = "./output/"*fname*output

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
                                                Symbol("Step removed $(sysunit)%")   => Float64[])


                for i in ph_names_ext_ptx
                    col = display_ph_name(i)*"_$(sysunit)%"
                    MAGEMin_db[!, col] = Float64[]
                end
                
                # Z = hcat(zeros(length(ph_names_ext_ptx)),Z)
                # for k=1:n_tot
                #     part_1 = Dict(  "point[#]"              => k,
                #                     "P[kbar]"               => P[k],
                #                     "T[°C]"                 => T[k],
                #                     "Removed $(sysunit)%"   => fracEvol[k,2],
                #                     "Remaining $(sysunit)%" => fracEvol[k,1])

                #     part_2 = Dict(  (ph_names_ext_ptx[j]*"_$(sysunit)%" => Z[j,k])
                #                     for j in eachindex(ph_names_ext_ptx))

                #     row    = merge(part_1,part_2)   
                #     push!(MAGEMin_db, row, cols=:union)        
                # end
                Z = hcat(zeros(length(ph_names_ext_ptx)),Z)
                step_rm = zeros(Float64, n_tot)
                step_rm[2:end] = fracEvol[2:end,2] - fracEvol[1:end-1,2]
                for k=1:n_tot
                    part_1 = Dict(  "point[#]"                  => k,
                                    "P[kbar]"                   => P[k],
                                    "T[°C]"                     => T[k],
                                    "Step removed $(sysunit)%"     => step_rm[k])

                    part_2 = Dict(  (display_ph_name(ph_names_ext_ptx[j])*"_$(sysunit)%" => Z[j,k])
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
            mkpath("./output")
            output_bib      = "_"*dtb*".bib"
            fileout         = "./output/"*fname*output_bib
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
            mkpath("./output")
            datab   = "_"*dtb
            fileout = "./output/"*fname*datab

            MAGEMin_data2dataframe(Out_PTX,dtb,fileout; use_Warr2021=use_warr_names[1], use_GPA=use_GPa[1])
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
            mkpath("./output")
            datab   = "_inlined_"*dtb
            fileout = "./output/"*fname*datab

            MAGEMin_data2dataframe_inlined(Out_PTX,dtb,fileout; use_Warr2021=use_warr_names[1], use_GPA=use_GPa[1])
            return "success", ""
        else
            return  "", "failed"
        end
    end

    #save trace-element data along PTX path to CSV file
    callback!(
        app,
        Output("data-te-csv-ptx-save",          "is_open"),
        Output("data-te-save-csv-ptx-failed",   "is_open"),
        Output("data-te-save-csv-ptx-not-computed", "is_open"),
        Input("save-te-csv-ptx-button",         "n_clicks"),
        State("Filename-te-ptx-id",             "value"),
        State("database-dropdown-ptx",          "value"),
        State("kds-dropdown-ptx",               "value"),
        State("zrsat-dropdown-ptx",             "value"),
        State("ssat-dropdown-ptx",              "value"),
        State("P2O5sat-dropdown-ptx",           "value"),
        State("co2sat-dropdown-ptx",            "value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb, kds, zrsat, ssat, P2O5sat, co2sat

        if !@isdefined(Out_TE_PTX) || isempty(Out_TE_PTX)
            return false, false, true
        end

        if fname == "filename"
            return false, true, false
        end

        sat_ext = ""
        if zrsat != "none"
            sat_ext *= "_$zrsat"
        end
        if ssat != "none"
            sat_ext *= "_$ssat"
        end
        if P2O5sat != "none"
            sat_ext *= "_$P2O5sat"
        end
        if co2sat != "none"
            sat_ext *= "_$co2sat"
        end

        mkpath("./output")
        datab   = "_te_"*dtb*"_"*kds*sat_ext
        fileout = "./output/"*fname*datab

        MAGEMin_dataTE2dataframe(Out_PTX, Out_TE_PTX, dtb, fileout; use_Warr2021=use_warr_names[1], use_GPA=use_GPa[1])
        return true, false, false
    end


    #save integrated cumulate trace-element composition to CSV
    callback!(
        app,
        Output("data-te-cumulate-csv-ptx-save",             "is_open"),
        Output("data-te-cumulate-save-csv-ptx-failed",      "is_open"),
        Output("data-te-cumulate-save-csv-ptx-not-computed","is_open"),
        Input("save-te-cumulate-csv-ptx-button",            "n_clicks"),
        State("Filename-te-cumulate-ptx-id",                "value"),
        State("database-dropdown-ptx",                      "value"),
        State("kds-dropdown-ptx",                           "value"),
        State("zrsat-dropdown-ptx",                         "value"),
        State("ssat-dropdown-ptx",                          "value"),
        State("P2O5sat-dropdown-ptx",                       "value"),
        State("co2sat-dropdown-ptx",                        "value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb, kds, zrsat, ssat, P2O5sat, co2sat

        if !@isdefined(Out_TE_PTX) || isempty(Out_TE_PTX)
            return false, false, true
        end

        if fname == "filename"
            return false, true, false
        end

        sat_ext = ""
        if zrsat != "none"
            sat_ext *= "_$zrsat"
        end
        if ssat != "none"
            sat_ext *= "_$ssat"
        end
        if P2O5sat != "none"
            sat_ext *= "_$P2O5sat"
        end
        if co2sat != "none"
            sat_ext *= "_$co2sat"
        end

        mkpath("./output")
        datab   = "_extracted_te_"*dtb*"_"*kds*sat_ext
        fileout = "./output/"*fname*datab*".csv"

        n_tot   = length(Out_PTX)
        n_te    = length(Out_TE_PTX[1].elements)
        elements = Out_TE_PTX[1].elements

        P = [display_pressure(Out_PTX[k].P_kbar) for k in 1:n_tot]
        T = [Out_PTX[k].T_C    for k in 1:n_tot]

        # extracted TE at each step: computed inline in compute_new_PTXpath, accounting for nRes/nCon mixing
        C_ext(k) = C_ext_TE_PTX[k]

        # stepwise extracted TE at each step
        Csol_step = Matrix{Union{Float64,Missing}}(undef, n_tot, n_te) .= missing
        for k in 1:n_tot
            if !all(isnan, C_ext(k))
                Csol_step[k, :] .= C_ext(k)
            end
        end

        # per-step incremental extracted fraction — fracEvol[:,2] encodes the correct
        # connectivity/residual logic for both fc and fm, so diff gives consistent weights
        step_rm = zeros(Float64, n_tot)
        step_rm[2:end] = fracEvol[2:end,2] - fracEvol[1:end-1,2]
        start_id = findfirst(k -> !all(isnan, C_ext(k)), 1:n_tot)

        # integrated cumulate TE: mass-weighted running average of extracted material
        Csol_int = Matrix{Union{Float64,Missing}}(undef, n_tot, n_te) .= missing
        if !isnothing(start_id)
            if !all(isnan, C_ext(start_id))
                Csol_int[start_id, :] .= C_ext(start_id)
            end
            for i in start_id+1:n_tot
                if !all(isnan, C_ext(i)) && !ismissing(Csol_int[i-1, 1])
                    wt_new = step_rm[i-1]
                    wt_old = fracEvol[i-1,2]
                    denom  = wt_new + wt_old
                    if denom > 0.0
                        Csol_int[i, :] .= (C_ext(i) .* wt_new .+ collect(skipmissing(Csol_int[i-1, :])) .* wt_old) ./ denom
                    else
                        Csol_int[i, :] .= Csol_int[i-1, :]
                    end
                elseif !ismissing(Csol_int[i-1, 1])
                    Csol_int[i, :] .= Csol_int[i-1, :]
                end
            end
        end

        MAGEMin_db = DataFrame(
            Symbol("point[#]")              => Int64[],
            Symbol("P[$(pressure_unit_label())]") => Float64[],
            Symbol("T[°C]")                 => Float64[],
            Symbol("Step removed%")         => Float64[],
            Symbol("Instantaneous removed%") => Float64[],
            Symbol("Accumulated removed%")  => Float64[],
        )
        for e in elements
            MAGEMin_db[!, e*"_step[μg/g]"] = Union{Float64,Missing}[]
        end
        for e in elements
            MAGEMin_db[!, e*"_int[μg/g]"] = Union{Float64,Missing}[]
        end

        for k in 1:n_tot
            part_1 = Dict(
                "point[#]"              => k,
                "P[$(pressure_unit_label())]" => P[k],
                "T[°C]"                 => T[k],
                "Step removed%"         => step_rm[k],
                "Instantaneous removed%" => fracEvol[k,3],
                "Accumulated removed%"  => fracEvol[k,2],
            )
            part_2 = Dict((elements[j]*"_step[μg/g]" => Csol_step[k, j]) for j in eachindex(elements))
            part_3 = Dict((elements[j]*"_int[μg/g]"  => Csol_int[k, j])  for j in eachindex(elements))
            push!(MAGEMin_db, merge(part_1, part_2, part_3), cols=:union)
        end

        CSV.write(fileout, MAGEMin_db)
        return true, false, false
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

        prevent_initial_call = false,
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
            yaxis_title = "Pressure [$(pressure_unit_label())]",
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
        Output("output-data-uploadn-ptx",           "is_open"    ),
        Output("output-data-uploadn-failed-ptx",    "is_open"    ),
        Output("output-data-uploadn-failed-ptx",    "children"   ),

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
                status, msg = parse_bulk_rock(contents, filename)
                if status == 1
                    return "success", false, ""
                else
                    return false, true, msg
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
                return false, true, "No bulk-rock composition available for the selected point"
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

                return "success", false, ""
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
        # State("liquidus-pressure-val-id",       "value"),
        # State("liquidus-tolerance-val-id",      "value"),
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

        ) do    compute,    compute_sol,     
                phase_selection,   pressure,   tolerance,
                Tliq,       Tsol,
                dtb,        dataset,        bufferType,     solver,
                verbose,    bulk,           bufferN,
                cpx,        limOpx,         limOpxVal,      test,       sysunit

        bid             = pushed_button( callback_context() )    # get which button has been pushed

        pressure        = to_kbar_pressure(Float64(pressure))    # convert displayed pressure unit to kbar

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

            Tsol = compute_Tsol(    sysunit,    pressure,   tolerance,  bulk_ini,   oxi,    phase_selection,
                                    dtb,        dataset,    bufferType, solver,
                                    verbose,    bulk,       bufferN,
                                    cpx,        limOpx,     limOpxVal  )
        end

        return Tliq, Tsol
    end

    # update the "Find solidus/liquidus" pressure label & value when the pressure unit is toggled
    callback!(app,
        Output("solidus-pressure-label-id",      "children"),
        Output("solidus-pressure-val-id",        "value"),
        Output("pressure-unit-prev-ptx-solidus", "children"),

        Input("pressure-unit-dropdown",          "value"),

        State("solidus-pressure-val-id",         "value"),
        State("pressure-unit-prev-ptx-solidus",  "children"),

        prevent_initial_call = true,

        ) do pressure_unit, pressure_val, pressure_unit_prev

        global use_GPa
        was_gpa    = (pressure_unit_prev == "gpa")
        use_GPa[1] = (pressure_unit == "gpa")

        if was_gpa != use_GPa[1]
            factor       = use_GPa[1] ? (1.0/10.0) : 10.0
            pressure_val = round(pressure_val * factor, digits=10)
        end

        label = "Pressure [$(pressure_unit_label())]"

        return label, pressure_val, pressure_unit
    end

    callback!(
        app,
        Output("colorpicker-mineral-id", "value"),  # Replace with your output
        Input("color-table-change-id", "selected_cells"),
        State("color-table-id", "data"),    

        prevent_initial_call = true,
    ) do selected, data

        row_index       =  selected[1]["row"] + 1
        color           = data[row_index]["Color"]

        return color
    end

    callback!(
        app,
        Output("color-table-id", "data"),    
        Output("color-table-id", "style_data_conditional"), 
        Output("color-table-change-id", "data"),
        Output("colorpicker-mineral-id", "style"),
        Input("ptx-plot",        "figure"),
        Input("colorpicker-mineral-id", "value"),  # Replace with your output
        State("color-table-change-id", "selected_cells"),
        State("color-table-id", "data"),    
        State("color-table-id", "style_data_conditional"), 
        State("color-table-change-id", "data"),
        State("colorpicker-mineral-id", "style"),  # Replace with your output
        prevent_initial_call = true,
    ) do clock, color, selected, data, style, data_select, picker_style
        bid         = pushed_button( callback_context() )    # get which button has been pushed

        if bid == "colorpicker-mineral-id"
            dataout     = copy(data)
            styleout    = copy(style)
            np          = length(dataout)
            row_index   =  selected[1]["row"] + 1
            dataout[row_index][Symbol("Color")]             = color
            styleout[row_index][Symbol("background-color")] = color

            mineral = haskey(data[row_index], "LegacyMineral") ? data[row_index]["LegacyMineral"] : data[row_index]["Mineral"]
            AppData.mineral_style[1][mineral][1]   = color
        

        elseif bid == "ptx-plot"
            global phase_infos_PTX
            if !@isdefined(phase_infos_PTX)
                return data, style, data_select, picker_style
            end
            phase_selection = vcat(phase_infos_PTX.act_ss, phase_infos_PTX.act_pp)

            dataout = [
                Dict("Mineral" => display_ph_name(mineral), "LegacyMineral" => mineral, "Color" => AppData.mineral_style[1][mineral][1])
                for mineral in phase_selection
            ]
            color_list = [AppData.mineral_style[1][mineral][1] for mineral in phase_selection]
            styleout = [
                Dict("if" => Dict("row_index" => i-1, "column_id" => "Color"), "background-color" => color_list[i])
                for i in 1:length(color_list)
            ]
            data_select = [
                Dict("Change" => " ")
                for i in 1:length(color_list)
            ]
            picker_style   =  Dict("height" => "$((24 + 6) * (length(color_list)+1))px", "padding" => "0", "margin" => "0" )

        end


        return dataout, styleout, data_select, picker_style
    end


    # Callback to save updated linestyles
    callback!(app,  Output("color-style-save", "is_open"),
                    Input("save-color-style", "n_clicks"),
                    prevent_initial_call = true ) do n_clicks

        if n_clicks == 0
            return false
        end

        # Save the updated dictionary to disk
        save_style(AppData.mineral_style[1])

        return "Success"
    end

    """
        Callback to compute and display PTX path
    """
    callback!(
        app,
        Output("display-entropy-textarea",  "value"),
        Output("path-isoS-plot",        "figure"),
        Output("path-isoS-plot",        "config"),
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
        Output("te-ptx-computed-store", "data"    ),

        Input("compute-path-button",    "n_clicks"),
        Input("sys-unit-ptx",           "value"),
        Input("display-mode",           "value"),
        Input("ext-display-mode",       "value"),
        Input("mineral-naming-dropdown","value"),

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
        State("color-table-id",         "data"),

        State("starting-temperature-isoS-id",   "value"),
        State("isentropic-dropdown-ptx",        "value"),
        State("display-entropy-textarea",       "value"),

        State("ptx-watsat-dropdown",            "value"),
        State("ptx-watsat-val-id",              "value"),

        State("tepm-dropdown-ptx",              "value"),
        State("kds-dropdown-ptx",               "value"),
        State("zrsat-dropdown-ptx",             "value"),
        State("ssat-dropdown-ptx",              "value"),
        State("P2O5sat-dropdown-ptx",           "value"),
        State("co2sat-dropdown-ptx",            "value"),
        State("table-te-rock-ptx",              "data"  ),
        State("table-te-2-rock-ptx",            "data"  ),

        prevent_initial_call = true,

        ) do    compute,    upsys,      display_mode,               ext_display_mode,   warr_naming,
                sys_unit,   phase_selection, pure_phase_selection,  phase_list, nsteps,     PTdata,     mode,   assim,  var_buffer,
                dtb,        dataset,    bufferType, solver,
                verbose,    bulk,       bulk2,      bufferN,
                cpx,        limOpx,     limOpxVal,  test,   sysunit,
                nCon,       nRes,       color_table,
                T_start,    isentropic_mode, entropy,
                watsat,     watsat_val,
                te_model,   kds_mod,    zrsat_mod,  ssat_mod,   P2O5sat_mod,    co2sat_mod, bulkte1,    bulkte2

        global use_warr_names
        use_warr_names[1]       = (warr_naming == "warr")
        bid                     = pushed_button( callback_context() )    # get which button has been pushed
        phase_selection         = remove_phases(string_vec_diff(to_str_vec(phase_selection),to_str_vec(pure_phase_selection),dtb),dtb)
        title                   = db[(db.db .== dtb), :].title[test+1]
        loading                 = ""

        if bid == "compute-path-button"

            global Out_PTX, ph_names_ptx, phase_infos_PTX, layout_ptx, layout_extracted_ptx, data_plot_ptx, fracEvol, removedBulk, layout_rm_ptx, data_comp_rm_plot, layout_rm_int_ptx, data_comp_rm_int_plot
            global layout_path, figIsoSPath
            global Out_TE_PTX, all_TE_ph_ptx, C_ext_TE_PTX

            bufferN                     = Float64(bufferN)               # convert buffer_n to float
            bulk_ini, bulk_assim, oxi   = get_bulkrock_prop(bulk, bulk2; sys_unit=sys_unit)

            bulkte_ini_te, bulkte_ass_te, elem_te = te_model == "true" ?
                                                    get_terock_prop(bulkte1, bulkte2) :
                                                    (Float64[], Float64[], String[])

            compute_new_PTXpath(    nsteps,     PTdata,     mode,       bulk_ini,  bulk_assim,  oxi,    phase_selection,    assim, var_buffer,
                                    dtb,        dataset,    bufferType, solver,
                                    verbose,    bufferN,
                                    cpx,        limOpx,     limOpxVal,
                                    nCon,       nRes,
                                    T_start,    isentropic_mode,
                                    watsat,     watsat_val,
                                    te_model,   kds_mod,    zrsat_mod,  ssat_mod,   P2O5sat_mod,    co2sat_mod,
                                    bulkte_ini_te, bulkte_ass_te, elem_te             )

            if isentropic_mode == true
                entropy                 = string(round(Out_PTX[1].entropy[1],digits=3))

                layout_path             = initialize_layout_isoS_path(Float64(Out_PTX[1].P_kbar), Float64(T_start), Float64(Out_PTX[end].P_kbar))
                df_path_plot            = get_data_plot_isoS_path()
                figIsoSPath             = plot(df_path_plot, x=:x, y=:y, layout_path)
            end

            phase_infos_PTX             = get_phase_infos(Out_PTX)


            layout_ptx                  = initialize_layout(title,sysunit)
            layout_extracted_ptx        = initialize_ext_layout(title,sysunit)
            data_plot_ptx, phase_list   = get_data_plot(display_mode, sysunit)
            data_extracted_plot_ptx, phase_list_ext   = get_extracted_data_plot(ext_display_mode,sysunit,mode,nRes,nCon,isentropic_mode)

            figPTX                      = plot(data_plot_ptx,layout_ptx)
            figExtractedPTX             = plot(data_extracted_plot_ptx,layout_extracted_ptx)

            layout_rm_ptx               = initialize_rm_layout()
            data_comp_rm_plot           = get_data_comp_rm_plot()

            figrmPTX                    = plot(data_comp_rm_plot,layout_rm_ptx)

            layout_rm_int_ptx           = initialize_rm_layout()
            data_comp_rm_int_plot       = get_data_comp_rm_int_plot()

            figrmintPTX                 = plot(data_comp_rm_int_plot,layout_rm_int_ptx)

        elseif (bid == "sys-unit-ptx" || bid == "ext-display-mode" || bid == "display-mode" || bid == "mineral-naming-dropdown") &&
               @isdefined(Out_PTX) && !isempty(Out_PTX) && @isdefined(ph_names_ptx)
            data_plot_ptx, phase_list   = get_data_plot(display_mode,sysunit)
            data_extracted_plot_ptx, phase_list_ext   = get_extracted_data_plot(ext_display_mode,sysunit,mode,nRes,nCon,isentropic_mode)

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

        configPathIsoS   = PlotConfig(  toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename =  "PTX_path_isentropic_"*replace(title, " " => "_"),
                                    height   =  640,
                                    width    =  640,
                                    scale    =  2.0,       ).fields)
        te_computed = bid == "compute-path-button" && te_model == "true"
        if isentropic_mode == true
            return entropy, figIsoSPath, configPathIsoS, figPTX, configPTX, figExtractedPTX, configExtractedPTX, figrmPTX, configrmPTX, figrmintPTX, configrmintPTX, phase_list, loading, te_computed
        else
            return entropy, no_update(), no_update(), figPTX, configPTX, figExtractedPTX, configExtractedPTX, figrmPTX, configrmPTX, figrmintPTX, configrmintPTX, phase_list, loading, te_computed
        end                            
        
    end


    # callback to display ca-orthopyroxene limiter
    callback!(
        app,
        Output("switch-opx-id-ptx", "style"),
        Output("dataset-ptx-display-id", "style"),
        Input("database-dropdown-ptx", "value"),

        prevent_initial_call = true,
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

        if value == "sb11" || value == "sb21" || value == "sb24"
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

        prevent_initial_call = true,
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
        Output("ptx-watsat-display-id", "style"),
        Input("ptx-watsat-dropdown",    "value"),

        prevent_initial_call = true,
    ) do value
        if value == "true"
            style = Dict("display" => "block")
        else
            style = Dict("display" => "none")
        end
        return style
    end

    callback!(
        app,
        Output("show-residual-id",      "style"),
        Input("mode-dropdown-ptx",      "value"),

        prevent_initial_call = true,
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

        prevent_initial_call = true,
    ) do value
  
        if value == "fm"
            style  = Dict("display" => "block")
        else 
            style  = Dict("display" => "none")
        end
        return style
    end

    callback!(
        app,
        Output("show-isentropic-id",        "style"),
        Output("isentropic-dropdown-ptx",   "value"),
        Output("show-fracphases-id",        "style"),
        
        Input("mode-dropdown-ptx",          "value"),
        State("isentropic-dropdown-ptx",    "value"),

        prevent_initial_call = true,
    ) do value, isentropic_value

        if value == "fc" || value == "eq" || value == "fm"
            style  = Dict("display" => "block")
        else 
            style               = Dict("display" => "none")
            isentropic_value    = false
        end

        if value == "fc"
            style2  = Dict("display" => "block")
        else 
            style2  = Dict("display" => "none")
        end

        return style, isentropic_value, style2
    end



    callback!(
        app,
        # Output("show-pathdef-id",           "style"),
        Output("show-isopathdef-id",        "style"),

        Output("show-pathpreview-id",       "style"),
        Output("show-isopathpreview-id",    "style"),

        Input("isentropic-dropdown-ptx",    "value"),

        prevent_initial_call = true,
    ) do value

        if value == true
            style  = Dict("display" => "none")
            style2  = Dict("display" => "block")
        else 
            style  = Dict("display" => "block")
            style2  = Dict("display" => "none")
        end
        return #=style, =#style2, style, style2
    end

    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("buffer-1-id-ptx",               "style"),
        Output("variable-buffer-display-id",    "style"),
        Output("variable-buffer-ptx-id",        "value"),

        Input("buffer-dropdown-ptx", "value"),

        prevent_initial_call = true,
    ) do value

        if value != "none"
            b1              = Dict("display" => "block")
            buffer_display  = Dict("display" => "block")
            var_buff        = false
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

        prevent_initial_call = false,
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
        phase_selection_options = [Dict(    "label"     => " "*display_ph_name(i),
                                            "value"     => i )
                                                for i in db_in.ss_name ]
        phase_selection_value   = db_in.ss_name


        # this is the phase selection part for the database when compute a diagram
        pp_all  = db_in.data_pp
        pp_disp = setdiff(pp_all, AppData.hidden_pp)

        pure_phase_selection_options = [Dict(    "label"     => " "*display_ph_name(i),
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

        prevent_initial_call=false, #needs to be load for the remove list
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
        [State("collapse-disp-opt", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
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
        [State("collapse-path-opt", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
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
        [State("collapse-pathdef", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
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
        [State("collapse-path", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
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
        [State("collapse-path-preview", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
            
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
        [State("collapse-config", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
            
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
        [State("collapse-bulk-ptx", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
            
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
        [State("collapse-phase-selection-PTX", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
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
        [State("collapse-pure-phase-selection-PTX", "is_open")],

        prevent_initial_call = true, ) do  n, is_open
        
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
        Output("variable-buffer-display-id2","style"     ),
        Output("pressure-unit-prev-ptx",    "children"  ),

        Input("assimilation-dropdown-ptx",  "value"     ),
        Input("add-row-button",             "n_clicks"  ),
        Input("variable-buffer-ptx-id",     "value"     ),
        Input("isentropic-dropdown-ptx",     "value"    ),
        Input("pressure-unit-dropdown",     "value"     ),

        State("assimilation-dropdown-ptx",  "value"     ),
        State("ptx-table",                  "data"      ),
        State("ptx-table",                  "columns"   ),
        State("pressure-unit-prev-ptx",     "children"  ),

        prevent_initial_call = true,

        ) do value, n_clicks, var_buffer, isentropic_value, pressure_unit,
                assim, data, colout, pressure_unit_prev

        bid                     = pushed_button( callback_context() )    # get which button has been pushed

        if bid == "pressure-unit-dropdown"
            global use_GPa
            was_gpa    = (pressure_unit_prev == "gpa")
            use_GPa[1] = (pressure_unit == "gpa")

            dataout    = copy(data)
            colsout    = copy(colout)

            if was_gpa != use_GPa[1]
                factor = use_GPa[1] ? (1.0/10.0) : 10.0
                for row in dataout
                    row[Symbol("col-1")] = round(row[Symbol("col-1")] * factor, digits=10)
                end
            end

            colsout[1][:name] = "P [$(pressure_unit_label())]"

            return dataout, colsout, no_update(), no_update(), no_update(), pressure_unit
        end

        dataout = copy(data)
        if value == "true"
            table2  = Dict("display" => "block")  
            test2   = Dict("display" => "block")  
        else
            table2  = Dict("display" => "none") 
            test2   = Dict("display" => "none") 
        end

        if assim == "true"
            if isentropic_value == false
                if var_buffer == false
                    colout = [  Dict("name" => "P [$(pressure_unit_label())]",  "id"    => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "T [°C]",    "id"    => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "Add [mol%]", "id"   => "col-3", "deletable" => false, "renamable" => false, "type" => "numeric")]

                    if n_clicks > 0 && bid == "add-row-button"
                        add = Dict(Symbol("col-1") => display_pressure(7.5), Symbol("col-2") => 1000.0, Symbol("col-3") => 0.0)
                        push!(dataout,add)
                    end
                elseif var_buffer == true
                    colout = [  Dict("name" => "P [$(pressure_unit_label())]",  "id"        => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "T [°C]",    "id"        => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "Add [mol%]", "id"       => "col-3", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "Buffer",     "id"       => "col-4", "deletable" => false, "renamable" => false, "type" => "numeric")]

                    if n_clicks > 0 && bid == "add-row-button"
                        add = Dict(Symbol("col-1") => display_pressure(7.5), Symbol("col-2") => 1000.0, Symbol("col-3") => 0.0, Symbol("col-4") => 0.0)
                        push!(dataout,add)
                    end
                end
            else
                colout = [  Dict("name" => "P [$(pressure_unit_label())]",  "id"    => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                            Dict("name" => "Add [mol%]", "id"   => "col-3", "deletable" => false, "renamable" => false, "type" => "numeric")]

                if n_clicks > 0 && bid == "add-row-button"
                    add = Dict(Symbol("col-1") => display_pressure(7.5), Symbol("col-3") => 0.0)
                    push!(dataout,add)
                end
            end

        else
            if isentropic_value == false
                if var_buffer == false
                    colout = [  Dict("name" => "P [$(pressure_unit_label())]",  "id"   => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "T [°C]",    "id"   => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric")]

                    if n_clicks > 0 && bid == "add-row-button"
                        add = Dict(Symbol("col-1") => display_pressure(7.5), Symbol("col-2") => 1000.0)
                        push!(dataout,add)
                    end
                elseif var_buffer == true
                    colout = [  Dict("name" => "P [$(pressure_unit_label())]",  "id"        => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "T [°C]",    "id"        => "col-2", "deletable" => false, "renamable" => false, "type" => "numeric"),
                                Dict("name" => "Buffer",    "id"        => "col-4", "deletable" => false, "renamable" => false, "type" => "numeric")]

                    if n_clicks > 0 && bid == "add-row-button"
                        add = Dict(Symbol("col-1") => display_pressure(7.5), Symbol("col-2") => 1000.0, Symbol("col-4") => 0.0)
                        push!(dataout,add)
                    end
                end
            else
                colout = [  Dict("name" => "P [$(pressure_unit_label())]",  "id"   => "col-1", "deletable" => false, "renamable" => false, "type" => "numeric")
                            ]
                if n_clicks > 0 && bid == "add-row-button"
                    add = Dict(Symbol("col-1") => display_pressure(7.5))
                    push!(dataout,add)
                end
            end

        end

        if var_buffer == false
            var_buff_disp = Dict("display" => "block") 
        else
            var_buff_disp = Dict("display" => "none")
        end

        return dataout, colout, table2, test2, var_buff_disp, no_update()
    end

    # Show/hide TE section + enable/disable TE tab based on tepm dropdown
    callback!(
        app,
        Output("tepm-section-ptx",      "style"),
        Output("te-tab-ptx",            "disabled"),
        Output("te-export-buttons-ptx", "style"),
        Input("tepm-dropdown-ptx",      "value"),
        prevent_initial_call = true,
    ) do tepm
        if tepm == "true"
            return Dict("display" => "block"), false, Dict("display" => "block")
        else
            return Dict("display" => "none"), true, Dict("display" => "none")
        end
    end

    # Show/hide assimilant TE section based on assimilation dropdown
    callback!(
        app,
        Output("collapse-assim-te-ptx", "is_open"),
        Input("assimilation-dropdown-ptx", "value"),
        prevent_initial_call = true,
    ) do assim
        return assim == "true" ? 1 : 0
    end

    # Toggle TE section
    callback!(
        app,
        Output("collapse-te-ptx",      "is_open"),
        [Input("button-te-ptx",        "n_clicks")],
        [State("collapse-te-ptx",      "is_open")],
        prevent_initial_call = true,
    ) do n, is_open
        if isnothing(n); n = 0 end
        if n > 0
            if is_open == 1
                is_open = 0
            elseif is_open == 0
                is_open = 1
            end
        end
        return is_open
    end

    # Parse and store uploaded TE bulk composition file for PTX paths
    callback!(
        app,
        Output("output-te-uploadn-ptx",         "is_open"),
        Output("output-te-uploadn-ptx-failed",  "is_open"),
        Input("upload-te-ptx",                  "contents"),
        State("upload-te-ptx",                  "filename"),
        State("kds-dropdown-ptx",               "value"),
        prevent_initial_call=true,
    ) do contents, filename, kdsDB
        if !(contents isa Nothing)
            status = parse_bulk_te(contents, filename, kdsDB)
            if status == 1
                return "success", nothing
            else
                return nothing, "failed"
            end
        end
    end

    # Update initial TE bulk table and dropdown options when preset changes or file is uploaded
    callback!(
        app,
        Output("table-te-rock-ptx",    "data"   ),
        Output("test-te-dropdown-ptx", "options"),
        Output("test-te-dropdown-ptx", "value"  ),
        Input("test-te-dropdown-ptx",  "value"  ),
        Input("output-te-uploadn-ptx", "is_open"),
        prevent_initial_call = true,
    ) do test_id, _
        if test_id > size(dbte, 1) - 1
            test_id = 0
        end
        data = [Dict("elements" => dbte.elements[test_id+1][i],
                     "μg_g"     => dbte.μg_g[test_id+1][i])
                for i = 1:length(dbte.elements[test_id+1])]
        opts = [Dict("label" => dbte.title[i], "value" => dbte.test[i])
                for i = 1:size(dbte, 1)]
        return data, opts, test_id
    end

    # Update assimilant TE bulk table and dropdown options when preset changes or file is uploaded
    callback!(
        app,
        Output("table-te-2-rock-ptx",      "data"   ),
        Output("test-te-2-dropdown-ptx",   "options"),
        Output("test-te-2-dropdown-ptx",   "value"  ),
        Input("test-te-2-dropdown-ptx",    "value"  ),
        Input("output-te-uploadn-ptx",     "is_open"),
        prevent_initial_call = true,
    ) do test_id, _
        if test_id > size(dbte, 1) - 1
            test_id = 0
        end
        data = [Dict("elements" => dbte.elements[test_id+1][i],
                     "μg_g"     => dbte.μg_g2[test_id+1][i])
                for i = 1:length(dbte.elements[test_id+1])]
        opts = [Dict("label" => dbte.title[i], "value" => dbte.test[i])
                for i = 1:size(dbte, 1)]
        return data, opts, test_id
    end

    # Extract step from PT path click or reset to 1 on new computation
    callback!(
        app,
        Output("te-ptx-step-id",       "value"   ),
        Input("te-ptx-computed-store", "data"    ),
        Input("pt-path-te-ptx",        "clickData"),
        prevent_initial_call = true,
    ) do _, click_data
        bid = pushed_button(callback_context())
        if bid == "te-ptx-computed-store"
            return 1
        end
        if isnothing(click_data)
            return 1
        end
        sp  = click_data[:points][][:text]
        tmp = match(r"#([0-9]+)#", sp)
        if tmp !== nothing
            return parse(Int64, tmp.captures[1])
        end
        return 1
    end

    # Update PT path plot + REE spectrum when step or display options change
    callback!(
        app,
        Output("pt-path-te-ptx",   "figure"  ),
        Output("pt-path-te-ptx",   "config"  ),
        Output("ree-spectrum-ptx",  "figure"  ),
        Output("ree-spectrum-ptx",  "config"  ),
        Output("te-ptx-step-info",  "children"),
        Input("te-ptx-step-id",         "value"),
        Input("normalization-te-ptx",   "value"),
        Input("show-spectrum-te-ptx",   "value"),
        prevent_initial_call = true,
    ) do step_id, norm, show_type

        empty_pt  = plot(GenericTrace[], Layout())
        empty_ree = plot(GenericTrace[], Layout())

        if !@isdefined(Out_TE_PTX) || isempty(Out_TE_PTX)
            return empty_pt, PlotConfig(), empty_ree, PlotConfig(), ""
        end

        step_id = clamp(Int(step_id), 1, length(Out_TE_PTX))

        # PT path figure
        data_pt, layout_pt = get_pt_path_te_plot(step_id)
        fig_pt   = plot(data_pt, layout_pt)
        config_pt = PlotConfig(displayModeBar = false)

        # REE spectrum figure
        layout_ree = get_layout_ree_ptx(norm, show_type)
        data_ree   = get_data_ree_plot_ptx(step_id, norm, show_type)
        fig_ree    = plot(data_ree, layout_ree)
        config_ree = PlotConfig(toImageButtonOptions = attr(
                        name = "Download as svg", format = "svg",
                        filename = "ptx_te_spectrum_step$(step_id)",
                        height = 280, width = 900, scale = 2.0).fields)

        out  = Out_PTX[step_id]
        info = "\n| Variable | Value | Unit |\n|---|---|---|\n"
        info *= "| P |" * string(round(display_pressure(out.P_kbar); digits=3)) * "| $(pressure_unit_label()) |\n"
        info *= "| T |" * string(round(out.T_C;   digits=3)) * "| °C |\n"

        return fig_pt, config_pt, fig_ree, config_ree, info
    end

    # Populate element + phase dropdowns when TE computation finishes
    callback!(
        app,
        Output("te-evol-element-ptx", "options"),
        Output("te-evol-element-ptx", "value"  ),
        Output("te-evol-phase-ptx",   "options"),
        Output("te-evol-phase-ptx",   "value"  ),
        Input("te-ptx-computed-store",   "data" ),
        Input("mineral-naming-dropdown", "value"),
        prevent_initial_call = true,
    ) do computed, warr_naming

        global use_warr_names
        use_warr_names[1] = (warr_naming == "warr")

        bid = pushed_button(callback_context())

        # helper: build phase options with display labels and legacy values
        function build_phase_opts()
            opts = [Dict("label" => "Cliq", "value" => "Cliq"),
                    Dict("label" => "Csol", "value" => "Csol")]
            if @isdefined(all_TE_ph_ptx)
                for ph in all_TE_ph_ptx
                    push!(opts, Dict("label" => display_ph_name(string(ph)), "value" => string(ph)))
                end
            end
            return opts
        end

        if bid == "mineral-naming-dropdown"
            if !@isdefined(Out_TE_PTX) || isempty(Out_TE_PTX)
                return no_update(), no_update(), no_update(), no_update()
            end
            return no_update(), no_update(), build_phase_opts(), no_update()
        end

        if !computed || !@isdefined(Out_TE_PTX) || isempty(Out_TE_PTX)
            return [], nothing, [], nothing
        end

        elem_opts = [Dict("label" => e, "value" => e) for e in Out_TE_PTX[1].elements]
        elem_val  = Out_TE_PTX[1].elements[1]
        phase_val = ["Cliq", "Csol"]

        return elem_opts, elem_val, build_phase_opts(), phase_val
    end

    # Render TE evolution plot when element or phase selection changes
    callback!(
        app,
        Output("te-evol-ptx", "figure"),
        Output("te-evol-ptx", "config"),
        Input("te-evol-element-ptx", "value"),
        Input("te-evol-phase-ptx",   "value"),
        prevent_initial_call = true,
    ) do element, phases
        empty_fig = plot(GenericTrace[], Layout())
        if !@isdefined(Out_TE_PTX) || isempty(Out_TE_PTX)
            return empty_fig, PlotConfig()
        end
        if isnothing(element) || isnothing(phases) || isempty(phases)
            return empty_fig, PlotConfig()
        end

        phases_vec = phases isa AbstractString ? [String(phases)] : [String(p) for p in phases]
        data_evol, layout_evol = get_te_evolution_plot(String(element), phases_vec)
        fig_evol  = plot(data_evol, layout_evol)
        config_evol = PlotConfig(toImageButtonOptions = attr(
                        name = "Download as svg", format = "svg",
                        filename = "ptx_te_evolution_$(element)",
                        height = 280, width = 900, scale = 2.0).fields)

        return fig_evol, config_evol
    end

    # Field builder: compute custom formula along PTX path
    callback!(
        app,
        Output("te-fieldbuilder-ptx", "figure"),
        Output("te-fieldbuilder-ptx", "config"),
        Input("te-fieldbuilder-button-ptx",  "n_clicks"),
        State("te-fieldbuilder-formula-ptx", "value"   ),
        State("te-fieldbuilder-norm-ptx",    "value"   ),
        prevent_initial_call = true,
    ) do _, varBuilder, norm
        empty_fig = plot(GenericTrace[], Layout())
        if !@isdefined(Out_TE_PTX) || isempty(Out_TE_PTX)
            return empty_fig, PlotConfig()
        end
        if isnothing(varBuilder) || strip(varBuilder) == ""
            return empty_fig, PlotConfig()
        end

        data_fb, layout_fb = get_te_fieldbuilder_plot(String(varBuilder), String(norm))
        fig_fb    = plot(data_fb, layout_fb)
        config_fb = PlotConfig(toImageButtonOptions = attr(
                        name = "Download as svg", format = "svg",
                        filename = "ptx_te_fieldbuilder",
                        height = 280, width = 900, scale = 2.0).fields)

        return fig_fb, config_fb
    end

    # Hide buffers unsupported by sb24
    callback!(
        app,
        Output("buffer-dropdown-ptx", "options"),
        Input("database-dropdown-ptx", "value" ),
        prevent_initial_call = true,
    ) do dtb

        all_opts = [
            (label = "no buffer", value = "none"   ),
            (label = "QFM",       value = "qfm"    ),
            (label = "MW",        value = "mw"     ),
            (label = "IW",        value = "iw"     ),
            (label = "QIF",       value = "qif"    ),
            (label = "CCO",       value = "cco"    ),
            (label = "HM",        value = "hm"     ),
            (label = "NNO",       value = "nno"    ),
            (label = "aH2O",      value = "aH2O"   ),
            (label = "aO2",       value = "aO2"    ),
            (label = "aFeO",      value = "aFeO"   ),
            (label = "aMgO",      value = "aMgO"   ),
            (label = "aAl2O3",    value = "aAl2O3" ),
            (label = "aTiO2",     value = "aTiO2"  ),
        ]

        hidden = ["cco", "nno", "aTiO2", "aH2O"]
        return dtb == "sb24" ? filter(o -> !(o.value in hidden), all_opts) : all_opts
    end

    return app
end