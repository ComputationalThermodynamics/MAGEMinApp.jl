function Tab_PhaseDiagram_Callbacks(app)

    """
        Callback to compute and display TAS diagram
    """
    callback!(
        app,
        Output("load-exp-success",   "is_open"),
        Output("load-exp-failed",    "is_open"),
        Input("load-exp-button",     "n_clicks"),
        State("load-exp-id",         "value"),

        prevent_initial_call = true,

        ) do n_click, filename

        println("Loading experimental data from file: $filename")
        println("$(pwd())")
        if isfile(filename)
            global AppData = merge(AppData, (customWs = CSV.read(filename, DataFrame),))
            return success, failed = "success", ""
        else
            return success, failed = "", "failed"
            println("File not found: $filename, check path")
        end
    end


    """
        Callback to compute and display TAS diagram
    """
    callback!(
        app,
        Output("code-avail",            "value"),
        Input("retrieve-statement",      "n_clicks"),

        prevent_initial_call = true,

        ) do    n_click

        return retrieve_statement()

    end


    """
        Callback to compute and display TAS diagram
    """
    callback!(
        app,
        Output("TAS-plot-pd",            "figure"),
        Output("TAS-plot-pd",            "config"),
        Output("TAS-pluto-plot-pd",      "figure"),
        Output("TAS-pluto-plot-pd",      "config"),
        Output("AFM-plot-pd",            "figure"),
        Output("AFM-plot-pd",            "config"),
        
        Input("compute-TAS-button",      "n_clicks"),

        State("database-dropdown",       "value"),
        State("test-dropdown",           "value"),
        State("select-pie-unit",         "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test,   sysunit

        global points_in_idx, Out_XY;

        bid         = pushed_button( callback_context() )    # get which button has been pushed
        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            tas, layout     = get_TAS_phase_diagram()
            figTAS          = plot( tas, layout)

            tas_pluto, layout_pluto     = get_TAS_pluto_phase_diagram()
            figTAS_pluto                = plot( tas_pluto, layout_pluto)
       
            
            afm, layout_afm = get_AFM_phase_diagram()
            figAFM          = plot( afm, layout_afm)
        else
            figTAS          = plot(Layout( height= 740 ))
            figTAS_pluto    = plot(Layout( height= 740 ))
            figAFM          = plot(Layout( height= 740 ))
        end

        configTAS   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "TAS_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)


        configTAS_pluto   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "TAS_plutonic_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configAFM   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "AFM_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figTAS, configTAS, figTAS_pluto, configTAS_pluto, figAFM, configAFM
    end

    callback!(
        app,
        Output("classification-canvas", "is_open"),
        Input("classification-canvas-button", "n_clicks"),
        State("classification-canvas", "is_open"),
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    #save all to file
    callback!(
        app,
        Output("download-lamem-in",             "data"      ),
        Output("export-to-lamem-text",          "is_open"   ),
        Output("export-to-lamem-text-failed",   "is_open"   ),
        Input("export-to-lamem",                "n_clicks"  ),
        State("database-dropdown",              "value"     ),
        State("diagram-dropdown",               "value"     ),
        State("gsub-id",                        "value"     ),                   # n subdivision
        State("refinement-levels",              "value"     ),                   # level
        State("tmin-id",                        "value"     ),                   # tmin
        State("tmax-id",                        "value"     ),                   # tmax
        State("pmin-id",                        "value"     ),                   # pmin
        State("pmax-id",                        "value"     ),                   # pmax
        State("table-bulk-rock",                "data"      ),                   # bulk-rock 1
        State("test-dropdown",                  "value"     ),

        prevent_initial_call=true,
        
    ) do n_clicks, dtb, dtype, sub, refLvl,
            tmin, tmax, pmin, pmax, bulk1, t

        if dtype == "pt"
            Xrange          = (Float64(tmin),Float64(tmax))
            Yrange          = (Float64(pmin),Float64(pmax))

            testName = replace(db[(db.db .== dtb), :].title[t+1], " " => "_")
            fileout = testName*".in";
            file    = save_rho_for_LaMEM(   dtb,
                                            sub,
                                            refLvl,
                                            Xrange,
                                            Yrange,
                                            bulk1 )
            output  = Dict("content" => file,"filename" => fileout)
            return output, "success", ""
        else
            output = nothing
            return output, "", "failed"
        end

    end



    #save all to file
    callback!(
        app,
        Output("download-geomodel-in", "data"),
        Output("export-geomodel-text", "is_open"),
        Output("export-geomodel-text-failed", "is_open"),
        Input("export-geomodel",    "n_clicks"),
        State("database-dropdown","value"),
        State("diagram-dropdown",   "value"),
        State("gsub-id","value"),                   # n subdivision
        State("refinement-levels","value"),         # level
        State("tmin-id","value"),                   # tmin
        State("tmax-id","value"),                   # tmax
        State("pmin-id","value"),                   # pmin
        State("pmax-id","value"),                   # pmax
        State("table-bulk-rock","data"),            # bulk-rock 1
        State("test-dropdown",      "value"),
        prevent_initial_call=true,
    ) do n_clicks, dtb, dtype, sub, refLvl,
            tmin, tmax, pmin, pmax, bulk1, t

        if dtype == "pt"
            Xrange          = (Float64(tmin),Float64(tmax))
            Yrange          = (Float64(pmin),Float64(pmax))

            testName = replace(db[(db.db .== dtb), :].title[t+1], " " => "_")
            fileout = testName*".in";
            file    = save_rho_for_GeoModel(    dtb,
                                                sub,
                                                refLvl,
                                                Xrange,
                                                Yrange,
                                                bulk1 )
            output  = Dict("content" => file,"filename" => fileout)
            return output, "success", ""
        else
            output = nothing
            return output, "", "failed"
        end

    end

    # save table to file
    callback!(
        app,
        Output("data-eq-csv-save", "is_open"),
        Output("data-eq-save-csv-failed", "is_open"),
        Input("save-eq-csv-button", "n_clicks"),
        State("Filename-eq-id", "value"),
        State("database-dropdown","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_"*dtb
            fileout = fname*datab
            MAGEMin_data2dataframe(Out_XY[point_id],dtb,fileout)

            return  "success", ""
        else
            return  "", "failed"
        end

    end

    # save table to file
    callback!(
        app,
        Output("download-table-text", "data"),
        Output("data-eq-table-save", "is_open"),
        Output("data-eq-save-table-failed", "is_open"),
        Input("save-eq-table-button", "n_clicks"),
        State("Filename-eq-id", "value"),
        State("database-dropdown","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_"*dtb
            fileout = fname*datab*".txt"
            file    = MAGEMin_data2table(Out_XY[point_id],dtb)            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "success", ""
        else
            return nothing, "", "failed"
        end
    end


    #save all table to file
    callback!(
        app,
        Output("data-all-table-save", "is_open"),
        Output("data-all-save-table-failed", "is_open"),
        Input("save-all-table-button", "n_clicks"),
        State("Filename-all-id", "value"),
        State("database-dropdown","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            datab   = "_"*dtb
            fileout = fname*datab

            MAGEMin_data2dataframe(Out_XY,dtb,fileout)
            return "success", ""
        else
            return  "", "failed"
        end
    end


    #save references to bibtex
    callback!(
        app,
        Output("export-citation-save", "is_open"),
        Output("export-citation-failed", "is_open"),
        Input("export-citation-button", "n_clicks"),
        State("export-citation-id", "value"),
        State("database-dropdown","value"),
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
            elseif dtb == "mbe"   
                id_ta = findfirst(bib[bib.keys[i]].fields["info"] .== "ta" for i=1:n_ref)
                push!(selection, String(bib.keys[id_ta]))
                id_oamp = findfirst(bib[bib.keys[i]].fields["info"] .== "oamp" for i=1:n_ref)
                push!(selection, String(bib.keys[id_oamp]))
            end

            selected_bib    = Bibliography.select(bib, selection)
            
            export_bibtex(fileout, selected_bib)

            return "success", ""
        else
            return  "", "failed"
        end
    end


    # save to file
    callback!(
        app,
        Output("download-text", "data"),
        Output("data-eq-save", "is_open"),
        Output("data-eq-save-failed", "is_open"),
        Input("save-eq-button", "n_clicks"),
        State("Filename-eq-id", "value"),
        State("database-dropdown","value"),
        State("mb-cpx-switch","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb, mbCpx

        if fname != "filename"
            P       = "_Pkbar_"*string(Out_XY[point_id].P_kbar)
            T       = "_TC_"*string(Out_XY[point_id].T_C)
            datab   = "_"*dtb
            fileout = fname*datab*P*T*".txt"
            file    = save_equilibrium_to_file(Out_XY[point_id], dtb, mbCpx)            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "success", ""
        else
            return nothing, "", "failed"
        end
    end


    callback!(
        app,
        Output("test-show-id", "style"),
        Input("phase-diagram", "selectedData"),
        prevent_initial_call = true,
    ) do selectedData

        global data, points_in_idx;

        if !isnothing(selectedData) 
            if "range" in keys(selectedData)
                np      = length(data.points)
                points  = [(data.points[k][1],data.points[k][2]) for k in 1:np]

                x_range = selectedData["range"]["x"]
                y_range = selectedData["range"]["y"]

                points_in_idx = findall(point -> is_inside_range(point, x_range, y_range), points)

            elseif "lassoPoints" in keys(selectedData)
                np      = length(data.points)
                points  = [(data.points[k][1],data.points[k][2]) for k in 1:np]

                x_array = selectedData["lassoPoints"]["x"]
                y_array = selectedData["lassoPoints"]["y"]
                
                polygon = [(x_array[i], y_array[i]) for i in 1:length(x_array)]
                push!(polygon, polygon[1])  # Close the polygon by appending the first point to the end

                points_in_idx = findall(point -> is_inside_polygon(point, polygon) == 1, points)
            end
        end

        return Dict("display" => "none")
    end


    """
        Callback function to display mineral composition when clicking on the pie diagram
    """
    callback!(
        app,
        Output("disp-test-id",              "style"     ),
        Output("table-phase-composition",   "data"      ),
        Output("ph-comp-title",             "children"  ),
        Input("pie-diagram",                "clickData" ),
        Input("phase-diagram",              "clickData" ),

        prevent_initial_call = true,
    ) do click_info, click_info2
        bid    = pushed_button( callback_context() ) 

        if bid == "pie-diagram"
            global point_id
            ph      = click_info[:points][1][:label]

            p       = Out_XY[point_id].ph
            p_id    = findfirst(p .== ph)
            n_SS    = Out_XY[point_id].n_SS

            if p_id > n_SS 
                p_id       -= n_SS
                comp        = Out_XY[point_id].PP_vec[p_id].Comp
                comp_wt     = Out_XY[point_id].PP_vec[p_id].Comp_wt
                comp_apfu   = Out_XY[point_id].PP_vec[p_id].Comp_apfu
            else
                comp        = Out_XY[point_id].SS_vec[p_id].Comp
                comp_wt     = Out_XY[point_id].SS_vec[p_id].Comp_wt
                comp_apfu   = Out_XY[point_id].SS_vec[p_id].Comp_apfu
            end
            oxi = Out_XY[point_id].oxides

            data        =   [Dict(  "oxide"     => oxi[i],
                                    "mol%"      => round(comp[i]*100.0,digits=2),
                                     "wt%"      => round(comp_wt[i]*100.0,digits=2),
                                     "apfu"     => round(comp_apfu[i],digits=2))
                                                for i=1:length(oxi) ]

            style  = Dict("display" => "block")
            title =  "$(ph) composition"

        elseif bid == "phase-diagram"
            style  = Dict("display" => "none")
            data   = []
            title =  ""
        end

        return style, data, title
    end


    # clickData callback when clicking on diagram point 
    callback!(
        app,
        Output("pie-diagram",           "figure"    ),
        Output("system-chemistry-id",   "value"     ),
        Output("magemin_c-snippet",     "value"     ),
        Input("phase-diagram",          "clickData" ),
        Input("select-pie-unit",        "value"     ),
        State("database-dropdown",      "value"     ), 
        State("diagram-dropdown",       "value"     ),          # pt,px,tx

        State("buffer-dropdown",        "value"     ),
        State("buffer-1-mul-id",        "value"     ),
        State("buffer-2-mul-id",        "value"     ),  
        State("phase-selection",        "value"     ),
        State("pure-phase-selection",   "value"     ),
        State("solver-dropdown",        "value"     ),            # bulk-rock 1
        

        prevent_initial_call = true,
    ) do click_info, pie_unit, dtb, diagType, buffer, buffer_n1, buffer_n2, ph_selection, pure_ph_selection, solver

        # phase_selection                 = remove_phases(string_vec_diff_ss(phase_selection,dtb),dtb)
        # pure_phase_selection            = remove_phases(string_vec_diff_ss(pure_phase_selection,dtb),dtb)
        phase_selection                 = remove_phases(string_vec_diff(ph_selection,pure_ph_selection,dtb),dtb)
        global point_id

        all_ox  = ["CO2","Cl","MnO","Na2O","CaO","K2O","FeO","MgO","Al2O3","SiO2","H2O","TiO2","O","S"];
        all_acr = ["CO2","Cl","Mn","N","C","K","F","M","A","S","H","T","O","S"];

        sp  = click_info[:points][][:text]
        tmp = match(r"#([^# ]+)#", sp)

        if tmp !== nothing

            point_id = tmp.match
            point_id = parse(Int64,replace.(point_id,r"#"=>""))

            ids     = reverse(sortperm(Out_XY[point_id].ph_frac))   #this gets the ids in descending order of phase fraction

            labels  = Out_XY[point_id].ph[ids]
            if pie_unit == 1
                values  = Out_XY[point_id].ph_frac[ids]     .* 100.0
                sys     = "mol%"
            elseif pie_unit == 2
                values  = Out_XY[point_id].ph_frac_wt[ids]  .* 100.0
                sys     = "wt%"
            elseif pie_unit == 3
                values  = Out_XY[point_id].ph_frac_vol[ids] .* 100.0
                sys     = "vol%"
            end

            title = "P: $(round(Out_XY[point_id].P_kbar; digits = 3)) T: $(round(Out_XY[point_id].T_C; digits = 3)) Mode [$(sys)]"
            layout = Layout(    font        = attr(size = 10),
                                height      = 220,
                                margin      = attr(autoexpand = false, l=8, r=8, b=8, t=24),
                                autosize    = false,
                                title       = attr(text=title, x=0.5, y=0.98),
                                titlefont   = attr(size=12))


            trace   = pie(; labels          = labels,
                            values          = values,
                            domain          = attr(x=[0.0, 0.95], y=[0.0, 0.9]),
                            hoverinfo       = "label+percent",
                            textposition    = "inside" #=,
                            hovertext   = hover_text[ids] =# )
            fig     = plot(trace,layout)


            # retrieve info to be displayed in the top textbox
            ids     = (Out_XY[1].bulk .!= 0.0)
            act_ox  = Out_XY[1].oxides[ids]
    
            sys_chem = []
            id_sys   = []
            for i=1:length(all_ox)
                if all_ox[i] in act_ox
                    push!(sys_chem, all_acr[i])
                    push!(id_sys,findfirst(act_ox .== all_ox[i]))
                end
            end
            sys_chem = join(sys_chem)
            bk       = join(round.(Out_XY[point_id].bulk[id_sys] .*100.0; digits = 3),"; ")
    
            text = sys_chem*" (mol%)"*" - ["*bk*"]"

            # code snippet to performation point calculation in MAGEMin_C
            if buffer != "none"
                buf      = ", buffer=\"qfm\""
                bufn     = ", B="*string(Out_XY[point_id].buffer_n)
            else
                buf     = ""
                bufn    = ""
            end
            if !isnothing(phase_selection)
                # if !isnothing(pure_phase_selection)
                #     phase_selection = vcat(phase_selection,pure_phase_selection)
                # end
                rm_list = ", rm_list=$phase_selection"
            else
                rm_list = ""
            end
            if solver == "pge"
                slv = ", solver=1"
            elseif solver == "lp"
                slv = ", solver=0"
            elseif solver == "hyb"
                slv = ", solver=2"
            end
            snip     = "using MAGEMin_C\n"
            snip    *= "data    = Initialize_MAGEMin(\"$dtb\", verbose=false$buf$slv);\n"
            snip    *= "P, T    = $( round(Out_XY[point_id].P_kbar; digits = 8)), $(round(Out_XY[point_id].T_C; digits = 8));\n"
            snip    *= "Xoxides = [\"$(join(Out_XY[point_id].oxides,"\"; \""))\"];\n"
            snip    *= "X       = [$(join( round.(Out_XY[point_id].bulk; digits = 5),", "))];\n"
            snip    *= "sys_in  = \"mol\";\n"
            snip    *= "out     = single_point_minimization(P, T, data, X=X, Xoxides=Xoxides$(bufn), sys_in=sys_in$rm_list)\n"
        end

        return fig, text, snip
    end


    callback!(
        app,
        Output("interval-simulation_progress",  "disabled"),
        Input("stop-trigger",                   "modified_timestamp"),
        Input("start-trigger",                  "value"),

        prevent_initial_call    = true,
    ) do stop, start

        bid  = pushed_button( callback_context() )
        # println("bid: $bid")
        if bid == "stop-trigger"
            return true
        elseif bid == "start-trigger"
            return false
        end
        
    end


    """
        Callback function to trigger phase diagram calculation using a relay function that activate dcc_interval listener for the progressbar
    """
    callback!(
        app,
        Output("compute-button",            "value"),
        Output("uni-refine-pb-button",      "value"),
        Output("refine-pb-button",          "value"),
        Output("start-trigger",              "value"),

        Input("compute-button-raw",         "n_clicks"),
        Input("uni-refine-pb-button-raw",   "n_clicks"),
        Input("refine-pb-button-raw",       "n_clicks"),
 
        State("compute-button",             "value"),
        State("uni-refine-pb-button",       "value"),
        State("refine-pb-button",           "value"),

        prevent_initial_call    = true,
    ) do compute_raw, uni_refine_raw, refine_raw, compute, uni_refine, refine

        bid  = pushed_button( callback_context() )

        if bid == "compute-button-raw"
            return compute*-1, no_update(), no_update(), 1
        elseif bid == "uni-refine-pb-button-raw"
            return no_update(), uni_refine*-1, no_update(), 1
        elseif bid == "refine-pb-button-raw"
            return no_update(), no_update(), refine*-1, 1
        end

    end



    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output("reaction-line-dropdown","options"),
        Output("reaction-line-dropdown","value"),
        Input("trigger-update-reaction-line-list","value"),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do reac_update
    
        global phase_infos;

        # bid         = pushed_button( callback_context() ) 
        pp          = phase_infos.act_pp;
        ss          = phase_infos.act_ss;

        ph          = vcat(ss,pp);

        reac_opt    = [Dict(    "label"     => " "*i,
                                "value"     => i )
                            for i in ph ];

        reac_val    = ph[1];


        return reac_opt, reac_val
    end

    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output("line-style-dropdown-reaction",  "value"     ),
        Output("iso-line-width-id-reaction",    "value"     ),
        Output("colorpicker-reaction",          "value"     ),
        Output("iso-text-size-id-reaction",     "value"     ),
        Input("reaction-line-dropdown",         "value"     ),
        Input("save-reaction-line",           "n_clicks"  ),
        Input("reset-reaction-line",            "n_clicks"  ),
        State("line-style-dropdown-reaction",   "value"     ),
        State("iso-line-width-id-reaction",     "value"     ),
        State("colorpicker-reaction",           "value"     ),
        State("iso-text-size-id-reaction",      "value"     ),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do ph, up, reset, ls, lw, col, ts
        bid     = pushed_button( callback_context() ) 
        global phase_infos;

        opt     = ("solid",0.75,"#000000",10.0,"")

        if bid == "reaction-line-dropdown"

            if ph in phase_infos.act_ss
                id  = findfirst(phase_infos.act_ss .== ph)
                opt = phase_infos.reac_ss[id]
            else
                id  = findfirst(phase_infos.act_pp .== ph)
                opt = phase_infos.reac_pp[id]
            end

            return opt[1], opt[2], opt[3], opt[4]
        elseif bid == "save-reaction-line"

            opt = (ls,lw,col,ts,ph)

            if ph in phase_infos.act_ss
                id  = findfirst(phase_infos.act_ss .== ph)
                phase_infos.reac_ss[id] = opt
            else
                id  = findfirst(phase_infos.act_pp .== ph)
                phase_infos.reac_pp[id] = opt
            end

            return no_update(), no_update(), no_update(), no_update()
        elseif bid == "reset-reaction-line"

            if ph in phase_infos.act_ss
                id  = findfirst(phase_infos.act_ss .== ph)
                phase_infos.reac_ss[id] = opt
            else
                id  = findfirst(phase_infos.act_pp .== ph)
                phase_infos.reac_pp[id] = opt
            end

            return opt[1], opt[2], opt[3], opt[4]
        end

    end


    """
        Callback function to update the phase diagram based on the user input
    """
    callback!(
        app,
        Output("show-grid",                 "value"), 
        Output("show-full-grid",            "value"), 
        Output("pd-legend",                 "figure"),
        Output("pd-legend",                 "config"),
        Output("phase-diagram",             "figure"),
        Output("phase-diagram",             "config"),
        Output("computation-info-id",       "children"),
        Output("stable-assemblage-id",      "children"),     

        Output("isopleth-dropdown",         "options"),
        Output("hidden-isopleth-dropdown",  "options"),
        Output("smooth-colormap",           "value"),
        Output("tabs",                      "active_tab"),      # currently active tab

        Output("min-color-id",              "value"),
        Output("max-color-id",              "value"),
        Output("output-loading-id",         "children"),
        Output("trigger-update-ss-list",    "value"),
        Output("trigger-update-reaction-line-list",    "value"),
        Output("show-text-list-id",         "style"),
        Output("stop-trigger",              "data"),
        Output("range-slider-color",        "value"),
        
        Input("update-reaction-line",       "n_clicks"), 
        Input("show-grid",                  "value"), 
        Input("show-full-grid",             "value"), 
        Input("show-lbl-id",                "value"),
     
        Input("button-add-isopleth",        "n_clicks"),
        Input("button-remove-isopleth",     "n_clicks"),
        Input("button-remove-all-isopleth", "n_clicks"),
        Input("button-hide-isopleth",       "n_clicks"),
        Input("button-show-isopleth",       "n_clicks"),
        Input("button-show-all-isopleth",   "n_clicks"),
        Input("button-hide-all-isopleth",   "n_clicks"),

        # perform calculations
        Input("compute-button",         "value"),
        Input("refine-pb-button",       "value"),
        Input("uni-refine-pb-button",   "value"),

        # color section
        Input("min-color-id",           "value"),
        Input("max-color-id",           "value"),

        Input("colormaps_cross",        "value"),
        Input("smooth-colormap",        "value"),
        Input("range-slider-color",     "value"),
        Input("set-min-white",          "value"),
        Input("reverse-colormap",       "value"),
        Input("fields-dropdown",        "value"),
        Input("update-title-button",    "n_clicks"),
        Input("load-state-id",          "value"),

        State("field-size-id",              "value"),
        State("title-id",               "value"),
        State("stable-assemblage-id",   "children"),   

        State("exp-dropdown",           "value"),           # true,false
        State("diagram-dropdown",       "value"),           # pt, px, tx
        State("database-dropdown",      "value"),           # mp, mb, ig ,igd, um, alk
        State("dataset-dropdown",       "value"),           # pt, px, tx
        State("watsat-dropdown",        "value"),           # false,true -> 0,1
        State("watsat-val-id",        "value"),           # false,true -> 0,1
        
        State("mb-cpx-switch",          "value"),           # false,true -> 0,1
        State("limit-ca-opx-id",        "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id",          "value"),           # 0.0-1.0 -> 0,1
        State("phase-selection",        "value"),
        State("pure-phase-selection",    "value"),

        State("pt-x-table",             "data"),
        State("tmin-id",                "value"),           # tmin
        State("tmax-id",                "value"),           # tmax
        State("pmin-id",                "value"),           # pmin
        State("pmax-id",                "value"),           # pmax
        State("event1-tmin-id",         "value"),           # tmin
        State("event1-tmax-id",         "value"),           # tmax
        State("event2-tmin-id",         "value"),           # tmin
        State("event2-tmax-id",         "value"),           # tmax

        State("event1-threshold-id",    "value"),           # tmax
        State("event2-threshold-id",    "value"),           # tmax
        State("event1-remaining-water-id",       "value"),           # tmax
        State("event2-remaining-water-id",       "value"),           # tmax
        State("event1-remain-id",       "value"),           # tmax
        State("event2-remain-id",       "value"),           # tmax
    
        State("fixed-temperature-val-id","value"),          # fix T
        State("fixed-pressure-val-id",  "value"),           # fix P

        State("gsub-id",                "value"),           # n subdivision
        State("refinement-dropdown",    "value"),           # ph,em
        State("refinement-levels",      "value"),           # level

        State("buffer-dropdown",        "value"),           # none,qfm,mw,qif,cco,hm,nno
        State("solver-dropdown",        "value"),           # pge,lp
        State("boost-mode-dropdown",    "value"),           # false,true
        State("verbose-dropdown",       "value"),           # none,light,full -> -1,0,1
        State("scp-dropdown",           "value"),           # none,light,full -> -1,0,1

        State("table-bulk-rock",        "data"),            # bulk-rock 1
        State("table-2-bulk-rock",      "data"),            # bulk-rock 2
        State("select-bulk-unit",       "value"),
        State("buffer-1-mul-id",        "value"),           # buffer n 1
        State("buffer-2-mul-id",        "value"),           # buffer n 2

        State("tepm-dropdown",          "value"),
        State("kds-dropdown",           "value"),
        State("zrsat-dropdown",         "value"),
        State("table-te-rock",          "data"),            # bulk-rock 1
        State("table-te-2-rock",        "data"),  

        State("test-dropdown",          "value"),           # test number

        # block related to isopleth plotting
        State("isopleth-dropdown",      "options"),
        State("isopleth-dropdown",      "value"),
        State("hidden-isopleth-dropdown",      "options"),
        State("hidden-isopleth-dropdown",      "value"),
        State("phase-dropdown",         "value"),
        State("ss-dropdown",            "value"),
        State("em-dropdown",            "value"),
        State("ox-dropdown",            "value"),
        State("of-dropdown",            "value"),
        State("other-dropdown",         "value"),
        State("sys-unit-isopleth-dropdown",  "value"),
        State("rm-exfluid-isopleth-dropdown",  "value"),
        State("input-calc-id",          "value"),
        State("input-cust-id",          "value"),
        State("input-calc-sf-id",       "value"),
        State("input-cust-sf-id",       "value"),
        State("line-style-dropdown",    "value"),
        State("iso-line-width-id",      "value"),
        State("colorpicker_isoL",       "value"),
        State("iso-text-size-id",       "value"),
        State("iso-min-id",             "value"),
        State("iso-step-id",            "value"),
        State("iso-max-id",             "value"),
        State("tabs",                   "active_tab"),      # currently active tab

        prevent_initial_call = true,

    ) do    reac_up,    grid,       full_grid,  lbl,     addIso,     removeIso,  removeAllIso,    isoShow,   isoHide, isoShowAll,    isoHideAll,    
            n_clicks_mesh, n_clicks_refine, uni_n_clicks_refine, 
            minColor,   maxColor,
            colorMap,   smooth,     rangeColor, set_white,  reverse,    fieldname,  updateTitle,     loadstateid, 
            field_size, customTitle, txt_list,
            custW,      diagType,   dtb,        dataset,    watsat,     watsat_val, cpx,        limOpx,     limOpxVal,  ph_selection, pure_ph_selection, PTpath,
            tmin,       tmax,       pmin,       pmax,       e1_tmin,    e1_tmax,    e2_tmin,    e2_tmax,    e1_liq,     e2_liq,  e1_remain_wat,     e2_remain_wat,e1_remain,     e2_remain,      
            fixT,       fixP,
            sub,        refType,    refLvl,
            bufferType, solver,     boost,      verbose,    scp,
            bulk1,      bulk2,      sys_unit,   
            bufferN1,   bufferN2,
            tepm,       kds_mod,    zrsat_mod,  bulkte1,    bulkte2,
            test,
            isopleths,  isoplethsID,isoplethsHid,  isoplethsHidID,  phase,      ss,         em,     ox,    of,     ot, sys, rmf, calc, cust, calc_sf, cust_sf,
            isoLineStyle, isoLineWidth, isoColorLine,           isoLabelSize,   
            minIso,     stepIso,    maxIso,
            active_tab


        phase_selection                 = remove_phases(string_vec_diff(ph_selection,pure_ph_selection,dtb),dtb)
        smooth                          = smooth
        xtitle, ytitle, Xrange, Yrange  = diagram_type(diagType, tmin, tmax, pmin, pmax, e1_tmin, e1_tmax, e2_tmin, e2_tmax)                # get axis information
        bufferN1, bufferN2, fixT, fixP, e1_liq, e2_liq,  e1_remain_wat,  e2_remain_wat,  e1_remain,  e2_remain,  = convert2Float64(bufferN1, bufferN2, fixT, fixP, e1_liq, e2_liq,  e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,)               # convert buffer_n to float
        bid                             = pushed_button( callback_context() )                           # get the ID of the last pushed button
        bulkte_L, bulkte_R, elem        = get_terock_prop(bulkte1, bulkte2)
        colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)              # get colormap information
        bulk_L, bulk_R, oxi             = get_bulkrock_prop(bulk1, bulk2; sys_unit=sys_unit)                               # get bulk rock composition information
        fieldNames                      = ["data_plot","data_reaction","data_grid","data_isopleth_out"]
        field2plot                      = zeros(Int64,4)

        field2plot[1]       =  1
        loading             = ""  
        update_ss_list      = ""
        update_reaction_list      = ""
        store_stop   = string(rand())


        if bid == "compute-button"
            loading                     = ""  
            smooth                      = "best"
            # declare set of global variables needed to generate, refine and display phase diagrams
            global fig, data, Hash_XY, Out_TE_XY, all_TE_ph, n_phase_XY, gridded, gridded_info, gridded_fields, phase_infos, X, Y, meant, npoints
            global addedRefinementLvl   = 0;
            global n_lbl                = 0;
            global iso_show             = 1;
            global data_plot, data_reaction, data_grid, layout, data_isopleth, data_isopleth_out, PT_infos, infos;
            global Out_XY =  Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,0)
            global CompProgress

            CompProgress.title = "Calculation Progress"
        
            CompProgress.stage = "Initial G isopleth"
            data_isopleth = initialize_g_isopleth(; n_iso_max = 32)

            if fieldname == "Variance"
                rangeColor = [1,7]
                colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)
            end

            data_plot, layout, npoints, meant, txt_list  =  compute_new_phaseDiagram(   xtitle,     ytitle,     lbl,        field_size,
                                                                                        Xrange,     Yrange,     fieldname,  customTitle,
                                                                                        dtb,        dataset,    custW,      diagType,   verbose,    scp,        solver,     boost, phase_selection,
                                                                                        fixT,       fixP,
                                                                                        e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,
                                                                                        sub,        refLvl,
                                                                                        watsat,     watsat_val, cpx,        limOpx,     limOpxVal,  PTpath,
                                                                                        bulk_L,     bulk_R,     oxi,
                                                                                        bufferType, bufferN1,   bufferN2,
                                                                                        minColor,   maxColor,
                                                                                        smooth,     colorm,     reverseColorMap, set_white,
                                                                                        test,       refType                          )
            if tepm == "true"
                if dtb != "um" && dtb != "ume" && dtb != "mtl"
                    t = @elapsed Out_TE_XY,all_TE_ph = tepm_function(   diagType, dtb,
                                                                        kds_mod, zrsat_mod, bulkte_L, bulkte_R, elem)

                    println("Computed trace element partitioning in $t s")
                else
                    println("Cannot compute trace-element partitioning for $dtb database as it does not include a melt model\n")
                end
            end

            infos           = get_computation_info(npoints, meant)

            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid       = show_hide_mesh_grid()
            active_tab      = "tab-phase-diagram" 

            minColor        = round(minimum(skipmissing(gridded)),digits=2); 
            maxColor        = round(maximum(skipmissing(gridded)),digits=2);  
            update_ss_list  = 1
            update_reaction_list  = 1
        elseif bid == "update-reaction-line"

            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)

        elseif bid == "refine-pb-button" || bid == "uni-refine-pb-button"
                
            CompProgress.title = "Calculation Progress"

            if bid == "uni-refine-pb-button"
                CompProgress.stage = "refine uniformly"
            elseif bid == "refine-pb-button"
                CompProgress.stage = "refine phase boundaries"
            end

            CompProgress.total_levels = 0
            CompProgress.refinement_level = 1
            CompProgress.tinit = time()

            data_plot, layout, npoints, meant, txt_list   =  refine_phaseDiagram(   xtitle,     ytitle,     lbl,        field_size,
                                                                                    Xrange,     Yrange,     fieldname,  customTitle,
                                                                                    dtb,        dataset,    custW,      diagType,   watsat,     watsat_val, verbose,    scp,    solver,  boost, phase_selection,
                                                                                    fixT,       fixP,
                                                                                    e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,e1_remain,  e2_remain,
                                                                                    sub,        refLvl,
                                                                                    cpx,        limOpx,     limOpxVal,  PTpath,
                                                                                    bulk_L,     bulk_R,     oxi,
                                                                                    bufferType, bufferN1,   bufferN2,
                                                                                    minColor,   maxColor,
                                                                                    smooth,     colorm,     reverseColorMap, set_white,
                                                                                    test,       refType,    bid                             )

            if tepm == "true"
                if dtb != "um" && dtb != "ume" && dtb != "mtl"
                    t = @elapsed Out_TE_XY,all_TE_ph = tepm_function(   diagType, dtb,
                                                                        kds_mod, zrsat_mod, bulkte_L, bulkte_R, elem)

                    println("Computed trace element partitioning in $t s")
                else
                    println("Cannot compute trace-element partitioning for $dtb database as it does not include a melt model\n")
                end
            end

            infos           = get_computation_info(npoints, meant)
            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid       = show_hide_mesh_grid()
            update_ss_list  = 1
            update_reaction_list  = 1

        elseif bid == "load-state-id"
            data_plot,layout =  update_displayed_field_phaseDiagram( xtitle,     ytitle,     
            Xrange,     Yrange,     fieldname,
            dtb,        oxi,
            sub,        refLvl,
            smooth,     colorm,     reverseColorMap, set_white,
            test,       refType                                 )

            minColor        = round(minimum(skipmissing(gridded)),digits=2); 
            maxColor        = round(maximum(skipmissing(gridded)),digits=2);        

            active_tab      = "tab-phase-diagram"     
        elseif bid == "set-min-white" || bid == "min-color-id" || bid == "max-color-id" || bid == "colormaps_cross" || bid == "smooth-colormap" || bid == "range-slider-color" || bid == "reverse-colormap"

            data_plot, layout =  update_colormap_phaseDiagram(  xtitle,     ytitle,     
                                                                Xrange,     Yrange,     fieldname,
                                                                dtb,        diagType,
                                                                minColor,   maxColor,
                                                                smooth,     colorm,     reverseColorMap, set_white,
                                                                test                                                    )

        elseif bid == "fields-dropdown"

            data_plot,layout =  update_displayed_field_phaseDiagram( xtitle,     ytitle,     
                                                                    Xrange,     Yrange,     fieldname,
                                                                    dtb,        oxi,
                                                                    sub,        refLvl,
                                                                    smooth,     colorm,     reverseColorMap, set_white,
                                                                    test,       refType                                 )

            minColor        = round(minimum(skipmissing(gridded)),digits=2); 
            maxColor        = round(maximum(skipmissing(gridded)),digits=2);  
                                                                                                 
        elseif bid == "show-grid"

            if grid == "true"
                field2plot[2] = 1
            end

        elseif bid == "show-full-grid"

            if full_grid == "true"
                field2plot[3] = 1
            end
                                                        
        elseif bid == "button-add-isopleth"

            data_isopleth, isopleths = add_isopleth_phaseDiagram(   Xrange,     Yrange,
                                                                    sub,        refLvl,
                                                                    dtb,        oxi,
                                                                    isopleths,  phase,      ss,     em,  ox,   of,     ot, sys, rmf,    calc, cust, calc_sf, cust_sf,
                                                                    isoLineStyle,   isoLineWidth, isoColorLine,           isoLabelSize,   
                                                                    minIso,     stepIso,    maxIso                      )
            data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
            field2plot[4] = 1
            iso_show      = 1

        elseif bid == "button-hide-isopleth"

            if (isoplethsID) in data_isopleth.active
                data_isopleth, isopleths, isoplethsHid = hide_single_isopleth_phaseDiagram(isoplethsID)
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                field2plot[4] = 1
            else
                println("Cannot hide isopleth, did you select one?")
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                field2plot[4] = 1
            end
        elseif bid == "button-show-isopleth"

            if (isoplethsHidID) in data_isopleth.hidden
                data_isopleth, isopleths, isoplethsHid = show_single_isopleth_phaseDiagram(isoplethsHidID)
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                field2plot[4] = 1
            else
                println("Cannot show isopleth, did you select one?")
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                field2plot[4] = 1
            end
        elseif bid == "button-remove-isopleth"

            if (isoplethsID) in data_isopleth.active
                if data_isopleth.n_iso > 1
                    data_isopleth, isopleths = remove_single_isopleth_phaseDiagram(isoplethsID)
                    data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                    field2plot[4] = 1
                else
                    data_isopleth, isopleths, isoplethsHid, data_plot = remove_all_isopleth_phaseDiagram()
                end

            else
                println("Cannot remove isopleth, did you select one?")
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                field2plot[4] = 1
            end

        elseif bid == "button-remove-all-isopleth"

            data_isopleth, isopleths, isoplethsHid, data_plot = remove_all_isopleth_phaseDiagram()

        elseif bid == "button-show-all-isopleth"

            iso_show          = 1
            data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
            field2plot[4] = 1

        elseif bid == "button-hide-all-isopleth"

            iso_show          = 0
            
        elseif bid == "update-title-button"
            if @isdefined(MAGEMin_data)
                layout[:title] = attr(
                    text    = customTitle,
                    x       = 0.4,
                    xanchor = "center",
                    yanchor = "top"
                )
            end
        else
            fig = plot()
        end

        if lbl == "true"
            for i=1:n_lbl+1
                layout[:annotations][i][:visible] = true
            end
            show_text_list  = Dict("display" => "block")  

        else
            for i=1:n_lbl+1
                layout[:annotations][i][:visible] = false
            end
            show_text_list  = Dict("display" => "none")  
        end

        # check state of unchanged variables ["data_plot","data_reaction","data_grid"]
        if grid == "true"
            field2plot[2] = 1
        end
        if full_grid == "true"
            field2plot[3] = 1
        end
        if data_isopleth.n_iso > 0 && iso_show == 1
            field2plot[4] = 1
        end

        # Fetch the fields to display
        if sum(field2plot) == 0
            fig = plot()
        else
            data_all = eval(Symbol(fieldNames[1]))
            np       = length(field2plot)

            for i=2:np
                if field2plot[i] == 1
                    data_all = vcat( data_all, eval(Symbol(fieldNames[i])) )
                end
            end

            fig = plot_diagram(data_all,layout)
        end

        config   = PlotConfig(    toImageButtonOptions  = attr(     name     = "Download as svg",
                                                                    format   = "svg",
                                                                    filename =  replace(customTitle, " " => "_"),
                                                                    height   =  900,
                                                                    width    =  720,
                                                                    scale    =  2.0,       ).fields)

        layoutCap = Layout(     height          =  30,        
                                plot_bgcolor    = "white", 
                                paper_bgcolor   = "white", 
                                title           = "",
                                xaxis           = attr(showticklabels=false),
                                yaxis           = attr(showticklabels=false),
                                legend=attr(
                                    x           =  0.05,             
                                    xanchor     = "left",
                                    orientation = "h"
                                ))
        if field2plot[4] == 0
            fig_cap = plot(layoutCap)
        else
            fig_cap = plot(data_isopleth.isoCap[data_isopleth.active],layoutCap)
        end
        
        config_cap  = PlotConfig(    toImageButtonOptions  = attr(      name     = "Download as svg",
                                                                        format   = "svg",
                                                                        filename =  (replace(customTitle, " " => "_"))*"_label",
                                                                        height   =  30,
                                                                        width    =  900,
                                                                        scale    =  2.0,       ).fields)

        if isempty(update_ss_list) && isempty(update_reaction_list)
            return grid, full_grid, fig_cap, config_cap, fig, config, infos, txt_list, isopleths, isoplethsHid, smooth, active_tab, minColor,   maxColor, loading, no_update(), no_update(), show_text_list, store_stop, rangeColor
       else
            return grid, full_grid, fig_cap, config_cap, fig, config, infos, txt_list, isopleths, isoplethsHid, smooth, active_tab, minColor,   maxColor, loading, update_ss_list, update_reaction_list, show_text_list, store_stop, rangeColor
        end
    end


    # save to file
    callback!(
        app,
        Output("iso-save",              "is_open"),
        Output("iso-save-failed",       "is_open"),
        Input("button-export-isopleth", "n_clicks"),
        State("database-dropdown",      "value"),
        State("title-id",               "value"),
        prevent_initial_call=true,
    ) do n_clicks, dtb, title

        global data_isopleth
        n = data_isopleth.n_iso
        if n > 0

            isoT = data_isopleth.isoT[data_isopleth.active]
            lbl = data_isopleth.label[data_isopleth.active]

            for i = 1:n
                export_contours_to_txt(isoT[i], lbl[i], "isopleth_"*replace(title, " " => "_")*"_"*lbl[i]*".txt")
            end

            return "success", ""
        else
            return "", "failed"
        end
    end


    global data_isopleth


    

    """
        Callback function to toggle the visibility of the collapse element
        and the collapse element containing the phase diagram information
    """
    callback!(app,
        Output("collapse", "is_open"),
        [Input("button-display-options", "n_clicks")],
        [State("collapse", "is_open")], ) do  n, is_open
        
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


    """
        Callback function to toggle the visibility of the collapse element
    """
    callback!(app,
        Output("collapse-infos-phase-diagram", "is_open"),
        [Input("infos-phase-diagram", "n_clicks")],
        [State("collapse-infos-phase-diagram", "is_open")], ) do  n, is_open
        
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
        Output("collapse-phase-label", "is_open"),
        [Input("phase-label", "n_clicks")],
        [State("collapse-phase-label", "is_open")], ) do  n, is_open
        
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