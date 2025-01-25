function Tab_isoSpaths_Callbacks(app)
  


    #save references to bibtex
    callback!(
        app,
        Output("export-citation-save-isoS", "is_open"),
        Output("export-citation-failed-isoS", "is_open"),
        Input("export-citation-button-isoS", "n_clicks"),
        State("export-citation-id-isoS", "value"),
        State("database-dropdown-isoS","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            output_bib      = "_"*dtb*".bib"
            fileout         = fname*output_bib
            magemin         = "MAGEMin"
            bib             = import_bibtex("./references/references.bib")
            
            print("\nSaving references for computed phase diagram\n")
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



    callback!(
        app,
        Output("output-data-uploadn-isoS", "is_open"),
        Output("output-data-uploadn-failed-isoS", "is_open"),
        Input("upload-bulk-isoS", "contents"),
        State("upload-bulk-isoS", "filename"),
        prevent_initial_call=true,
    ) do contents, filename

        if !(contents isa Nothing)
            status = parse_bulk_rock(contents, filename)
            if status == 1
                return "success", ""
            else
                return "", "failed"
            end
        end
    end


    #save all table to file
    callback!(
        app,
        Output("data-all-csv-isoS-save", "is_open"),
        Output("data-all-save-csv-isoS-failed", "is_open"),
        Input("save-all-csv-isoS-button", "n_clicks"),
        State("Filename-all-isoS-id", "value"),
        State("database-dropdown-isoS","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_"*dtb
            fileout = fname*datab

            MAGEMin_data2dataframe(Out_ISOS,dtb,fileout)
            return "success", ""
        else
            return  "", "failed"
        end
    end


    #save all table to file
    callback!(
        app,
        Output("download-all-table-isoS-text", "data"),
        Output("data-all-table-isoS-save", "is_open"),
        Output("data-all-save-table-isoS-failed", "is_open"),
        Input("save-all-table-isoS-button", "n_clicks"),
        State("Filename-all-isoS-id", "value"),
        State("database-dropdown-isoS","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_"*dtb
            fileout = fname*datab*".txt"
            file    = MAGEMin_data2table(Out_ISOS,dtb)            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "success", ""
        else
            output = nothing
            return output, "", "failed"
        end
    end


    """
        Callback to compute and display isentropic path
    """
    callback!(
        app,
        Output("isoS-plot",                 "figure"),
        Output("isoS-plot",                 "config"),
        Output("phase-selector-isoS-id",    "options"),
        Output("display-entropy-textarea",  "value"),
        Output("path-isoS-plot",            "figure"),
        Output("path-isoS-plot",            "config"),   
        Output("output-loading-id-isentropic",         "children"),

        Input("compute-path-button-isoS",   "n_clicks"),
        Input("sys-unit-isoS",              "value"),

        State("select-bulk-unit-isoS",      "value"),
        State("phase-selection-isoS",       "value"),
        State("pure-phase-selection-isoS",  "value"),
        State("phase-selector-isoS-id",     "options"),

        State("starting-pressure-isoS-id",  "value"),
        State("starting-temperature-isoS-id",  "value"),
        State("ending-pressure-isoS-id",    "value"),
        State("tolerance-id-isoS",          "value"),      
        
        State("n-steps-id-isoS",         "value"),
        State("database-dropdown-isoS",  "value"),
        State("buffer-dropdown-isoS",    "value"),
        State("solver-dropdown-isoS",    "value"),    
        State("verbose-dropdown-isoS",   "value"),   
        State("table-bulk-rock-isoS",    "data"),  
        State("buffer-1-mul-id-isoS",    "value"),  

        State("mb-cpx-switch-isoS",      "value"),           # false,true -> 0,1
        State("limit-ca-opx-id-isoS",    "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id-isoS",      "value"),           # 0.0-1.0 -> 0,1
        State("test-dropdown-isoS",      "value"),
        State("sys-unit-isoS",           "value"),

    
        prevent_initial_call = true,

        ) do    compute,    upsys,      
                sys_unit,   phase_selection,    pure_phase_selection,    phase_list,
                Pini,       Tini,       Pfinal, tolerance,  nsteps,    
                dtb,        bufferType, solver,
                verbose,    bulk,       bufferN,
                cpx,        limOpx,     limOpxVal,  test,   sysunit

        Pini = Float64(Pini);   Tini = Float64(Tini);  Pfinal = Float64(Pfinal);

        bid             = pushed_button( callback_context() )    # get which button has been pushed
        entropy         = ""
        title           = db[(db.db .== dtb), :].title[test+1]
        figIsoS         = plot(    Layout( height= 320 ))
        loading         = "" 
        if bid == "compute-path-button-isoS"

            global Out_ISOS, ph_names, layout_isoS, layout_path, data_plot, df_path_plot

            bufferN                 = Float64(bufferN)               # convert buffer_n to float
            bulk_ini, bulk_ini, oxi = get_bulkrock_prop(bulk, bulk; sys_unit=sys_unit)  

            compute_new_IsentropicPath(     nsteps,     bulk_ini,   oxi,    phase_selection,    pure_phase_selection,
                                            Pini,       Tini,       Pfinal, tolerance,
                                            dtb,        bufferType, solver,
                                            verbose,    bulk,       bufferN,
                                            cpx,        limOpx,     limOpxVal    )

            layout_isoS             = initialize_layout_isoS(title,sysunit)
            layout_path             = initialize_layout_isoS_path(Pini, Tini, Pfinal)

            data_plot, phase_list   = get_data_plot_isoS(sysunit)
            df_path_plot            = get_data_plot_isoS_path()

            figIsoS                 = plot(data_plot,layout_isoS)
            figIsoSPath             = plot(df_path_plot, x=:x, y=:y, layout_path)
            entropy                 = Out_ISOS[1].entropy
        elseif bid == "sys-unit-isoS"
            data_plot, phase_list   = get_data_plot_isoS(sysunit)
            ytitle                  = "Phase fraction ["*sysunit*"%]"
            
            layout_isoS[:yaxis_title]    = ytitle

            figIsoS                 = plot(data_plot,layout_isoS)
            figIsoSPath             = plot(df_path_plot, x=:x, y=:y, layout_path)
            entropy                 = Out_ISOS[1].entropy
        else
            figIsoS                 = plot(    Layout( height= 320 ))
        end

        configIsoS   = PlotConfig(  toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename =  "isentropic_path_mode_"*replace(title, " " => "_"),
                                    height   =  360,
                                    width    =  960,
                                    scale    =  2.0,       ).fields)

        configPathIsoS   = PlotConfig(  toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg",
                                    filename =  "isentropic_path_PT_"*replace(title, " " => "_"),
                                    height   =  640,
                                    width    =  640,
                                    scale    =  2.0,       ).fields)

        return figIsoS, configIsoS, phase_list, string( round(entropy,digits=5) ), figIsoSPath, configPathIsoS, loading
    end





    """
        Callback to compute and display PTX path
    """
    callback!(
        app,
        Output("isoS-frac-plot",         "figure"),
        Output("isoS-frac-plot",         "config"),
        
        Input("phase-selector-isoS-id",      "value"),

        State("database-dropdown-isoS",  "value"),
        State("test-dropdown-isoS",      "value"),
        State("sys-unit-isoS",           "value"),

        prevent_initial_call = true,

        ) do    phases,
                dtb,    test,   sysunit


        bid         = pushed_button( callback_context() )    # get which button has been pushed
        title       = db[(db.db .== dtb), :].title[test+1]

        if ~isempty(phases)
            layout_comp  = initialize_comp_layout(sysunit)

            data_comp_plot = get_data_comp_plot_isoS(sysunit,phases)
            
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



    callback!(app,
        Output("collapse-isoS-path", "is_open"),
        [Input("button-isoS-path", "n_clicks")],
        [State("collapse-isoS-path", "is_open")], ) do  n, is_open
        
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
        Output("collapse-path-opt-isoS", "is_open"),
        [Input("button-path-opt-isoS", "n_clicks")],
        [State("collapse-path-opt-isoS", "is_open")], ) do  n, is_open
        
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
        Output("collapse-disp-opt-isoS", "is_open"),
        [Input("button-disp-opt-isoS", "n_clicks")],
        [State("collapse-disp-opt-isoS", "is_open")], ) do  n, is_open
        
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
        Output("collapse-pathdef-isoS", "is_open"),
        [Input("button-pathdef-isoS", "n_clicks")],
        [State("collapse-pathdef-isoS", "is_open")], ) do  n, is_open
        
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
        Output("collapse-pathinformation-isoS", "is_open"),
        [Input("button-pathinformation-isoS", "n_clicks")],
        [State("collapse-pathinformation-isoS", "is_open")], ) do  n, is_open
        
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

    # callback to display ca-orthopyroxene limiter
    callback!(
        app,
        Output("switch-opx-id-isoS", "style"),
        Input("database-dropdown-isoS", "value"),
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
        return style
    end


    # callback to display clinopyroxene choice for the metabasite database
    callback!(
        app,
        Output("switch-cpx-id-isoS",     "style"),
        Input("database-dropdown-isoS",  "value"),
    ) do value

        if value == "mb"
            style  = Dict("display" => "block")
        else 
            style  = Dict("display" => "none")
        end
        return style
    end


    # callback function to display to right set of variables as function of the diagram type
    callback!(
        app,
        Output("buffer-1-id-isoS", "style"),
        Input("buffer-dropdown-isoS", "value"),
    ) do value

        if value != "none"
            b1  = Dict("display" => "block")
        else
            b1  = Dict("display" => "none")
        end

        return b1
    end


    callback!(
        app,
        Output("table-bulk-rock-isoS","data"),
        Output("test-dropdown-isoS","options"),
        Output("test-dropdown-isoS","value"),
        Output("database-caption-isoS","value"),
        Output("phase-selection-isoS","options"),
        Output("phase-selection-isoS","value"),
        Output("pure-phase-selection-isoS","options"),
        Output("pure-phase-selection-isoS","value"),
        Input("select-bulk-unit-isoS","value"),

        Input("test-dropdown-isoS","value"),
        Input("database-dropdown-isoS","value"),
        Input("output-data-uploadn-isoS", "is_open"),        # this listens for changes and updated the list

        State("table-bulk-rock-isoS","data"),

        prevent_initial_call = false,
    ) do sys_unit, 
        test, dtb, update,
        tb_data

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        if sys_unit == 1
            data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
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


        return data, opts, val, cap, phase_selection_options, phase_selection_value, pure_phase_selection_options, pure_phase_selection_value                
    end



    # open/close Curve interpretation box
    callback!(app,
        Output("collapse-phase-selection-isoS", "is_open"),
        [Input("button-phase-selection-isoS", "n_clicks")],
        [State("collapse-phase-selection-isoS", "is_open")], ) do  n, is_open
        
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
        Output("collapse-pure-phase-selection-isoS", "is_open"),
        [Input("button-pure-phase-selection-isoS", "n_clicks")],
        [State("collapse-pure-phase-selection-isoS", "is_open")], ) do  n, is_open
        
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
        Output("collapse-config-isoS", "is_open"),
        [Input("button-config-isoS", "n_clicks")],
        [State("collapse-config-isoS", "is_open")], ) do  n, is_open
            
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
        Output("collapse-bulk-isoS", "is_open"),
        [Input("button-bulk-isoS", "n_clicks")],
        [State("collapse-bulk-isoS", "is_open")], ) do  n, is_open
            
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

    return app
end