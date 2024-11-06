function Tab_PhaseDiagram_Callbacks(app)

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
            
            selection       = [bib.keys[id_db], bib.keys[id_magemin]]
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
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "filename"
            P       = "_Pkbar_"*string(Out_XY[point_id].P_kbar)
            T       = "_TC_"*string(Out_XY[point_id].T_C)
            datab   = "_"*dtb
            fileout = fname*datab*P*T*".txt"
            file    = save_equilibrium_to_file(Out_XY[point_id])            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "success", ""
        else
            return nothing, "", "failed"
        end
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
        State("solver-dropdown",        "value"     ),            # bulk-rock 1
        

        prevent_initial_call = true,
    ) do click_info, pie_unit, dtb, diagType, buffer, buffer_n1, buffer_n2, phase_selection, solver

        phase_selection                 = remove_phases(string_vec_dif(phase_selection,dtb),dtb)

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


    """
        Callback function to update the phase diagram based on the user input
    """
    callback!(
        app,
        Output("show-grid",             "value"), 
        Output("show-full-grid",        "value"), 
        Output("pd-legend",             "figure"),
        Output("pd-legend",             "config"),
        Output("phase-diagram",         "figure"),
        Output("phase-diagram",         "config"),
        Output("computation-info-id",   "children"),        

        Output("isopleth-dropdown",     "options"),
        Output("smooth-colormap",       "value"),
        Output("tabs",                  "active_tab"),      # currently active tab

        Output("min-color-id",           "value"),
        Output("max-color-id",           "value"),

        Input("show-grid",                  "value"), 
        Input("show-full-grid",             "value"), 
        Input("show-lbl-id",                "value"),
        Input("button-add-isopleth",        "n_clicks"),
        Input("button-remove-isopleth",     "n_clicks"),
        Input("button-remove-all-isopleth", "n_clicks"),
        Input("button-show-all-isopleth",   "n_clicks"),
        Input("button-hide-all-isopleth",   "n_clicks"),

        Input("compute-button",         "n_clicks"),
        Input("refine-pb-button",       "n_clicks"),
  
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
        State("title-id",               "value"),

        State("diagram-dropdown",       "value"),           # pt, px, tx
        State("database-dropdown",      "value"),           # mp, mb, ig ,igd, um, alk
        State("watsat-dropdown",        "value"),           # false,true -> 0,1
        State("mb-cpx-switch",          "value"),           # false,true -> 0,1
        State("limit-ca-opx-id",        "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id",          "value"),           # 0.0-1.0 -> 0,1
        State("phase-selection",        "value"),

        State("pt-x-table",             "data"),
        State("tmin-id",                "value"),           # tmin
        State("tmax-id",                "value"),           # tmax
        State("pmin-id",                "value"),           # pmin
        State("pmax-id",                "value"),           # pmax

        State("fixed-temperature-val-id","value"),          # fix T
        State("fixed-pressure-val-id",  "value"),           # fix P

        State("gsub-id",                "value"),           # n subdivision
        State("refinement-dropdown",    "value"),           # ph,em
        State("refinement-levels",      "value"),           # level

        State("buffer-dropdown",        "value"),           # none,qfm,mw,qif,cco,hm,nno
        State("solver-dropdown",        "value"),           # pge,lp
        State("verbose-dropdown",       "value"),           # none,light,full -> -1,0,1
        State("scp-dropdown",           "value"),           # none,light,full -> -1,0,1

        State("table-bulk-rock",        "data"),            # bulk-rock 1
        State("table-2-bulk-rock",      "data"),            # bulk-rock 2

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
        State("phase-dropdown",         "value"),
        State("ss-dropdown",            "value"),
        State("em-dropdown",            "value"),
        State("of-dropdown",            "value"),
        State("other-dropdown",         "value"),
        State("input-calc-id",          "value"),
        State("input-cust-id",          "value"),
        State("line-style-dropdown",    "value"),
        State("iso-line-width-id",      "value"),
        State("colorpicker_isoL",       "value"),
        State("iso-text-size-id",       "value"),
        State("iso-min-id",             "value"),
        State("iso-step-id",            "value"),
        State("iso-max-id",             "value"),
        State("tabs",                   "active_tab"),      # currently active tab

        prevent_initial_call = true,

    ) do    grid,       full_grid,  lbl,        addIso,     removeIso,  removeAllIso,    isoShow,    isoHide,    n_clicks_mesh, n_clicks_refine, 
            minColor,   maxColor,
            colorMap,   smooth,     rangeColor, set_white,  reverse,    fieldname,  updateTitle,     loadstateid, customTitle,
            diagType,   dtb,        watsat,     cpx,        limOpx,     limOpxVal,  phase_selection, PTpath,
            tmin,       tmax,       pmin,       pmax,
            fixT,       fixP,
            sub,        refType,    refLvl,
            bufferType, solver,     verbose,    scp,
            bulk1,      bulk2,      
            bufferN1,   bufferN2,
            tepm,       kds_mod,    zrsat_mod,  bulkte1,    bulkte2,
            test,
            isopleths,  isoplethsID,phase,      ss,         em,         of,     ot, calc, cust,
            isoLineStyle, isoLineWidth, isoColorLine,           isoLabelSize,   
            minIso,     stepIso,    maxIso,     active_tab


        phase_selection                 = remove_phases(string_vec_dif(phase_selection,dtb),dtb)
        smooth                          = smooth
        xtitle, ytitle, Xrange, Yrange  = diagram_type(diagType, tmin, tmax, pmin, pmax)                # get axis information
        bufferN1, bufferN2, fixT, fixP  = convert2Float64(bufferN1, bufferN2, fixT, fixP)               # convert buffer_n to float
        bid                             = pushed_button( callback_context() )                           # get the ID of the last pushed button
        bulkte_L, bulkte_R, elem        = get_terock_prop(bulkte1, bulkte2)
        colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)              # get colormap information
        bulk_L, bulk_R, oxi             = get_bulkrock_prop(bulk1, bulk2)                               # get bulk rock composition information
        fieldNames                      = ["data_plot","data_reaction","data_grid","data_isopleth_out"]
        field2plot                      = zeros(Int64,4)

        field2plot[1]    = 1
        if bid == "compute-button"

            smooth                      = "best"
            # declare set of global variables needed to generate, refine and display phase diagrams
            global fig, data, Hash_XY, Out_TE_XY, all_TE_ph, n_phase_XY, gridded, gridded_info, X, Y, meant, npoints
            global addedRefinementLvl   = 0;
            global n_lbl                = 0;
            global iso_show             = 1;
            global data_plot, data_reaction, data_grid, layout, data_isopleth, data_isopleth_out, PT_infos, infos;
            global Out_XY =  Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,0)

            data_isopleth = initialize_g_isopleth(; n_iso_max = 32)

            data_plot, layout, npoints, meant  =  compute_new_phaseDiagram( xtitle,     ytitle,     lbl,
                                                                            Xrange,     Yrange,     fieldname,  customTitle,
                                                                            dtb,        diagType,   verbose,    scp,        solver,     phase_selection,
                                                                            fixT,       fixP,
                                                                            sub,        refLvl,
                                                                            watsat,     cpx,        limOpx,     limOpxVal,  PTpath,
                                                                            bulk_L,     bulk_R,     oxi,
                                                                            bufferType, bufferN1,   bufferN2,
                                                                            minColor,   maxColor,
                                                                            smooth,     colorm,     reverseColorMap, set_white,
                                                                            test,       refType                          )
            if tepm == "true"
                if dtb != "um" && dtb != "ume" && dtb != "mtl"
                    t = @elapsed Out_TE_XY,all_TE_ph = tepm_function(   diagType, dtb,
                                                                        kds_mod, zrsat_mod, bulkte_L, bulkte_R)

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
    
        elseif bid == "refine-pb-button"

            data_plot, layout, npoints, meant  =  refine_phaseDiagram(  xtitle,     ytitle,     lbl, 
                                                                        Xrange,     Yrange,     fieldname,  customTitle,
                                                                        dtb,        diagType,   watsat, verbose,    scp,    solver, phase_selection,
                                                                        fixT,       fixP,
                                                                        sub,        refLvl,
                                                                        cpx,        limOpx,     limOpxVal,  PTpath,
                                                                        bulk_L,     bulk_R,     oxi,
                                                                        bufferType, bufferN1,   bufferN2,
                                                                        minColor,   maxColor,
                                                                        smooth,     colorm,     reverseColorMap, set_white,
                                                                        test,       refType                             )

            if tepm == "true"
                if dtb != "um" && dtb != "ume" && dtb != "mtl"
                    t = @elapsed Out_TE_XY,all_TE_ph = tepm_function(   diagType, dtb,
                                                                        kds_mod, zrsat_mod, bulkte_L, bulkte_R)

                    println("Computed trace element partitioning in $t s")
                else
                    println("Cannot compute trace-element partitioning for $dtb database as it does not include a melt model\n")
                end
            end

            infos           = get_computation_info(npoints, meant)
            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid       = show_hide_mesh_grid()

        elseif bid == "load-state-id"
            data_plot,layout =  update_diplayed_field_phaseDiagram( xtitle,     ytitle,     
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

            data_plot,layout =  update_diplayed_field_phaseDiagram( xtitle,     ytitle,     
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
                                                                    isopleths,  phase,      ss,     em,     of,     ot, calc, cust,
                                                                    isoLineStyle,   isoLineWidth, isoColorLine,           isoLabelSize,   
                                                                    minIso,     stepIso,    maxIso                      )
            data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
            field2plot[4] = 1
            iso_show      = 1

        elseif bid == "button-remove-isopleth"

            if (isoplethsID) in data_isopleth.active
                if data_isopleth.n_iso > 1
                    data_isopleth, isopleths = remove_single_isopleth_phaseDiagram(isoplethsID)
                    data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                    field2plot[4] = 1
                else
                    data_isopleth, isopleths, data_plot = remove_all_isopleth_phaseDiagram()
                end

            else
                print("cannot remove isopleth, did you select one?")
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                field2plot[4] = 1
            end

        elseif bid == "button-remove-all-isopleth"

            data_isopleth, isopleths, data_plot = remove_all_isopleth_phaseDiagram()

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
        else
            for i=1:n_lbl+1
                layout[:annotations][i][:visible] = false
            end
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
                                                                    width    =  900,
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


        return grid, full_grid, fig_cap, config_cap, fig, config, infos, isopleths, smooth, active_tab, minColor,   maxColor
    end


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



    return app
end