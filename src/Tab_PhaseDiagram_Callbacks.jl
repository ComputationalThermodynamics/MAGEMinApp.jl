function Tab_PhaseDiagram_Callbacks(app)

    #save all to file
    callback!(
        app,
        Output("download-all-text", "data"),
        Output("data-all-save", "is_open"),
        Output("data-all-save-failed", "is_open"),
        Input("save-all-button", "n_clicks"),
        State("Filename-all-id", "value"),
        State("database-dropdown","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb

        if fname != "... filename ..."
            datab   = "_"*dtb
            fileout = fname*datab*".txt"
            file    = save_all_to_file(dtb)            #point_id is defined as global variable in clickData callback
            output  = Dict("content" => file,"filename" => fileout)
            
            return output, "success", ""
        else
            output = nothing
            return output, "", "failed"
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

        if fname != "... filename ..."
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

    # clickData callback
    callback!(
        app,
        Output("click-data-left", "children"),
        Output("click-data-right", "children"),
        Input("phase-diagram", "clickData"),
        State("diagram-dropdown","value"),          # pt,px,tx
        prevent_initial_call = true,
    ) do click_info, diagType

        global point_id

        sp  = click_info[:points][][:text]
        tmp = match(r"#([^# ]+)#", sp)


        if tmp !== nothing
            point_id = tmp.match
            point_id = parse(Int64,replace.(point_id,r"#"=>""))

            # left panel
            pLeft = "\n"
            pLeft *= "|Variable &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;|Value &nbsp; &nbsp; &nbsp; &nbsp;| Unit |\n"
            pLeft *= "|----------|-------|------|\n"
            pLeft *= "| Pressure |"*string(round(Out_XY[point_id].P_kbar; digits = 3))*"| kbar |\n"
            pLeft *= "| Temperature |"*string(round(Out_XY[point_id].T_C; digits = 3))*"| °C |\n"
            pLeft *= "| Gibbs energy |"*string(round(Out_XY[point_id].G_system; digits = 3))*"| kJ |\n"
            pLeft *= "| ρ_system |"*string(round(Out_XY[point_id].rho; digits = 1))*"| kg/m³   |\n"

            if "liq" in Out_XY[point_id].ph
                pLeft *= "| ρ_solid |"*string(round(Out_XY[point_id].rho_S; digits = 1))*"| kg/m³ |\n"
                pLeft *= "| ρ_melt |"*string(round(Out_XY[point_id].rho_M; digits = 1))*"| kg/m³ |\n"
            end
            
            # X       = "Composition\t\t**mol**\t: "*join(round.(Out_XY[point_id].bulk; digits = 3)," ")*"\n"
            
            # right panel
            pRight = "\n"
            pRight *= "|Phase &nbsp; &nbsp;| Fraction |\n"
            pRight *= "|-------|----------|\n"
            np      = length(Out_XY[point_id].ph)
            for i=1:np
                pRight *= "| "*Out_XY[point_id].ph[i]*"|"*string(round.(Out_XY[point_id].ph_frac[i]; digits = 3))*"| \n"
            end

        end

        return pLeft,pRight
    end

    # Callback function to create compute the phase diagram using T8code for Adaptive Mesh Refinement
    callback!(
        app,
        Output("show-grid",         "value"), 
        Output("show-full-grid",    "value"), 
        Output("phase-diagram",     "figure"),
        Output("phase-diagram",     "config"),
        Output("computation-info-id",       "children"),        

        Output("isopleth-dropdown", "options"),
        Output("smooth-colormap",   "value"),
        Output("tabs",    "active_tab"),                 # currently active tab
        
        Input("show-grid",                  "value"), 
        Input("show-full-grid",             "value"), 
        Input("show-lbl-id",                "value"),
        Input("button-add-isopleth",        "n_clicks"),
        Input("button-remove-isopleth",     "n_clicks"),
        Input("button-remove-all-isopleth", "n_clicks"),
        Input("button-show-all-isopleth",   "n_clicks"),
        Input("button-hide-all-isopleth",   "n_clicks"),

        Input("compute-button",     "n_clicks"),
        Input("refine-pb-button",   "n_clicks"),

        Input("colormaps_cross",    "value"),
        Input("smooth-colormap",    "value"),
        Input("range-slider-color", "value"),
        Input("reverse-colormap",   "value"),
        Input("fields-dropdown",    "value"),

        State("diagram-dropdown",   "value"),           # pt, px, tx
        State("database-dropdown",  "value"),           # mp, mb, ig ,igd, um, alk
        State("mb-cpx-switch",      "value"),           # false,true -> 0,1
        State("limit-ca-opx-id",    "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id",      "value"),           # 0.0-1.0 -> 0,1

        State("tmin-id",            "value"),           # tmin
        State("tmax-id",            "value"),           # tmax
        State("pmin-id",            "value"),           # pmin
        State("pmax-id",            "value"),           # pmax

        State("fixed-temperature-val-id","value"),      # fix T
        State("fixed-pressure-val-id",   "value"),      # fix P

        State("gsub-id",            "value"),           # n subdivision
        State("refinement-dropdown","value"),           # ph,em
        State("refinement-levels",  "value"),           # level

        State("buffer-dropdown",    "value"),           # none,qfm,mw,qif,cco,hm,nno
        State("solver-dropdown",    "value"),           # pge,lp
        State("verbose-dropdown",   "value"),           # none,light,full -> -1,0,1

        State("table-bulk-rock",    "data"),            # bulk-rock 1
        State("table-2-bulk-rock",  "data"),            # bulk-rock 2
        
        State("buffer-1-mul-id",    "value"),           # buffer n 1
        State("buffer-2-mul-id",    "value"),           # buffer n 2

        State("test-dropdown",      "value"),           # test number

        # block related to isopleth plotting
        State("isopleth-dropdown",  "options"),
        State("isopleth-dropdown",  "value"),
        State("phase-dropdown",     "value"),
        State("ss-dropdown",        "value"),
        State("em-dropdown",        "value"),
        State("of-dropdown",        "value"),
        State("colorpicker_isoL",   "value"),
        State("iso-text-size-id",   "value"),
        State("iso-min-id",         "value"),
        State("iso-step-id",        "value"),
        State("iso-max-id",         "value"),
        State("tabs",               "active_tab"),      # currently active tab

        prevent_initial_call = true,

    ) do    grid,       full_grid,  lbl,        addIso,     removeIso,  removeAllIso,   isoShow,    isoHide,    n_clicks_mesh, n_clicks_refine, 
            colorMap,   smooth,     rangeColor, reverse,    fieldname,
            diagType,   dtb,        cpx,        limOpx,     limOpxVal,
            tmin,       tmax,       pmin,       pmax,
            fixT,       fixP,
            sub,        refType,    refLvl,
            bufferType, solver,     verbose,
            bulk1,      bulk2,
            bufferN1,   bufferN2,
            test,
            isopleths,  isoplethsID,phase,      ss,         em,         of,  
            isoColorLine,           isoLabelSize,   
            minIso,     stepIso,    maxIso,     active_tab

        smooth                          = smooth
        xtitle, ytitle, Xrange, Yrange  = diagram_type(diagType, tmin, tmax, pmin, pmax)                # get axis information
        bufferN1, bufferN2, fixT, fixP  = convert2Float64(bufferN1, bufferN2, fixT, fixP)               # convert buffer_n to float
        bid                             = pushed_button( callback_context() )                           # get the ID of the last pushed button
        colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)              # get colormap information
        bulk_L, bulk_R, oxi             = get_bulkrock_prop(bulk1, bulk2)                               # get bulk rock composition information
        fieldNames                      = ["data_plot","data_reaction","data_grid","data_isopleth_out"]
        field2plot                      = zeros(Int64,4)


        field2plot[1]    = 1
        if bid == "compute-button"
            smooth                      = "best"
      
            if @isdefined(MAGEMin_data)
                for i = 1:Threads.nthreads()
                    finalize_MAGEMin(MAGEMin_data.gv[i],MAGEMin_data.DB[i],MAGEMin_data.z_b[i])
                end
            end
            GC.gc()         # garbage collector should be place after freeing the threads, otherwise this leads to issues
            
            # declare set of global variables needed to generate, refine and display phase diagrams
            global fig, MAGEMin_data, forest, data, Hash_XY, Out_XY, n_phase_XY, field, gridded, gridded_info, X, Y, meant, npoints, PhasesLabels
            global addedRefinementLvl   = 0;
            global n_lbl                = 0;
            global iso_show             = 1;
            global data_plot, data_reaction, data_grid, layout, data_isopleth, data_isopleth_out, PT_infos, infos;

            data_isopleth = initialize_g_isopleth(; n_iso_max = 32)

            data_plot, layout, npoints, meant  =  compute_new_phaseDiagram( xtitle,     ytitle,     lbl,
                                                                            Xrange,     Yrange,     fieldname,
                                                                            dtb,        diagType,   verbose,    solver,
                                                                            fixT,       fixP,
                                                                            sub,        refLvl,
                                                                            cpx,        limOpx,     limOpxVal,
                                                                            bulk_L,     bulk_R,     oxi,
                                                                            bufferType, bufferN1,   bufferN2,
                                                                            smooth,     colorm,     reverseColorMap,
                                                                            test,       refType                          )

            infos           = get_computation_info(npoints, meant)
            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid       = show_hide_mesh_grid()
            active_tab      = "tab-phase-diagram" 

        elseif bid == "refine-pb-button"

            data_plot, layout, npoints, meant  =  refine_phaseDiagram(  xtitle,     ytitle,     lbl, 
                                                                        Xrange,     Yrange,     fieldname,
                                                                        dtb,        diagType,   verbose,    solver,
                                                                        fixT,       fixP,
                                                                        sub,        refLvl,
                                                                        cpx,        limOpx,     limOpxVal,
                                                                        bulk_L,     bulk_R,     oxi,
                                                                        bufferType, bufferN1,   bufferN2,
                                                                        smooth,     colorm,     reverseColorMap,
                                                                        test,       refType                             )

            infos           = get_computation_info(npoints, meant)
            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid       = show_hide_mesh_grid()
                                                      
        elseif bid == "colormaps_cross" || bid == "smooth-colormap" || bid == "range-slider-color" || bid == "reverse-colormap"

            data_plot, layout =  update_colormap_phaseDiagram(  xtitle,     ytitle,     
                                                                Xrange,     Yrange,     fieldname,
                                                                dtb,        diagType,
                                                                smooth,     colorm,     reverseColorMap,
                                                                test                                                    )

        elseif bid == "fields-dropdown"

            data_plot,layout =  update_diplayed_field_phaseDiagram( xtitle,     ytitle,     
                                                                    Xrange,     Yrange,     fieldname,
                                                                    dtb,        oxi,
                                                                    sub,        refLvl,
                                                                    smooth,     colorm,     reverseColorMap,
                                                                    test,       refType                                 )

        elseif bid == "show-grid"

            if grid == "true"
                field2plot[2] = 1
                # full_grid = "false"
            end

        elseif bid == "show-full-grid"

            if full_grid == "true"
                field2plot[3] = 1
                # grid = "false"
            end
                                                        
        elseif bid == "button-add-isopleth"

            data_isopleth, isopleths = add_isopleth_phaseDiagram(   Xrange,     Yrange,
                                                                    sub,        refLvl,
                                                                    dtb,        oxi,
                                                                    isopleths,  phase,      ss,     em,     of,
                                                                    isoColorLine,           isoLabelSize,   
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

        elseif bid == "show-lbl-id"

            if lbl == "true"
                for i=1:n_lbl+1
                    layout[:annotations][i][:visible] = true
                end
            else
                for i=1:n_lbl+1
                    layout[:annotations][i][:visible] = false
                end
            end

        end


        # check state of unchanged variables ["data_plot","data_reaction","data_grid","data_isopleth_out"]
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
                                                                    format   = "svg", # one of png, svg, jpeg, webp
                                                                    filename =  replace(db[(db.db .== dtb), :].title[test+1], " " => "_"),
                                                                    height   =  900,
                                                                    width    =  900,
                                                                    scale    =  2.0,       ).fields)



        return grid, full_grid, fig, config, infos, isopleths, smooth, active_tab 
    end


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


    callback!(app,
        Output("collapse-refinement", "is_open"),
        [Input("button-refinement", "n_clicks")],
        [State("collapse-refinement", "is_open")], ) do  n, is_open
        
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