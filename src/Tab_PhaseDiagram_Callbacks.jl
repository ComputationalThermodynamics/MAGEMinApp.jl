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

function Tab_PhaseDiagram_Callbacks(app)

    global using_sample_point = false           # true when the pie chart/composition table currently show a Sample point rather than a clicked grid point
    global SamplePoint        = nothing         # (out = <gmin_struct>, xval = <Float64 or nothing>) of the last computed Sample point

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
            println("File not found: $filename, check path")
            return success, failed = "", "failed"
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
        prevent_initial_call = true,
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    """
        Callback to compute and display Ca-amphibole classification diagrams
    """
    callback!(
        app,
        Output("CaAmpPanelA-plot-pd",    "figure"),
        Output("CaAmpPanelA-plot-pd",    "config"),
        Output("CaAmpPanelB-plot-pd",    "figure"),
        Output("CaAmpPanelB-plot-pd",    "config"),
        Output("CaAmpPanelC-plot-pd",    "figure"),
        Output("CaAmpPanelC-plot-pd",    "config"),

        Input("compute-CaAmp-button",    "n_clicks"),

        State("database-dropdown",       "value"),
        State("test-dropdown",           "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test

        global points_in_idx, Out_XY;

        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            panelA, layoutA     = get_CaAmpPanelA_diagram()
            figCaAmpA           = plot( panelA, layoutA)

            panelB, layoutB     = get_CaAmpPanelB_diagram()
            figCaAmpB           = plot( panelB, layoutB)

            panelC, layoutC     = get_CaAmpPanelC_diagram()
            figCaAmpC           = plot( panelC, layoutC)
        else
            figCaAmpA        = plot(Layout( height= 740 ))
            figCaAmpB        = plot(Layout( height= 740 ))
            figCaAmpC        = plot(Layout( height= 740 ))
        end

        configCaAmpA   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "CaAmp_PanelA_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configCaAmpB   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "CaAmp_PanelB_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configCaAmpC   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "CaAmp_PanelC_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figCaAmpA, configCaAmpA, figCaAmpB, configCaAmpB, figCaAmpC, configCaAmpC
    end

    callback!(
        app,
        Output("CaAmp-classification-canvas", "is_open"),
        Input("CaAmp-classification-canvas-button", "n_clicks"),
        State("CaAmp-classification-canvas", "is_open"),
        prevent_initial_call = true,
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    """
        Callback to compute and display clinopyroxene classification diagrams
    """
    callback!(
        app,
        Output("CpxQJ-plot-pd",          "figure"),
        Output("CpxQJ-plot-pd",          "config"),
        Output("CpxQuad-plot-pd",        "figure"),
        Output("CpxQuad-plot-pd",        "config"),
        Output("CpxNaPx-plot-pd",        "figure"),
        Output("CpxNaPx-plot-pd",        "config"),

        Input("compute-Cpx-button",      "n_clicks"),

        State("database-dropdown",       "value"),
        State("test-dropdown",           "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test

        global points_in_idx, Out_XY;

        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            qj, layoutQJ         = get_CpxQJ_diagram()
            figCpxQJ             = plot( qj, layoutQJ)

            quad, layoutQuad     = get_CpxQuad_diagram()
            figCpxQuad           = plot( quad, layoutQuad)

            napx, layoutNaPx     = get_CpxNaPx_diagram()
            figCpxNaPx           = plot( napx, layoutNaPx)
        else
            figCpxQJ         = plot(Layout( height= 740 ))
            figCpxQuad       = plot(Layout( height= 740 ))
            figCpxNaPx       = plot(Layout( height= 740 ))
        end

        configCpxQJ   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Cpx_QJ_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configCpxQuad   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Cpx_Quad_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configCpxNaPx   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Cpx_NaPx_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figCpxQJ, configCpxQJ, figCpxQuad, configCpxQuad, figCpxNaPx, configCpxNaPx
    end

    callback!(
        app,
        Output("Cpx-classification-canvas", "is_open"),
        Input("Cpx-classification-canvas-button", "n_clicks"),
        State("Cpx-classification-canvas", "is_open"),
        prevent_initial_call = true,
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    """
        Callback to compute and display orthopyroxene classification diagram
    """
    callback!(
        app,
        Output("OpxQuad-plot-pd",        "figure"),
        Output("OpxQuad-plot-pd",        "config"),

        Input("compute-Opx-button",      "n_clicks"),

        State("database-dropdown",       "value"),
        State("test-dropdown",           "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test

        global points_in_idx, Out_XY;

        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            quad, layoutQuad     = get_OpxQuad_diagram()
            figOpxQuad           = plot( quad, layoutQuad)
        else
            figOpxQuad       = plot(Layout( height= 740 ))
        end

        configOpxQuad   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Opx_Quad_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figOpxQuad, configOpxQuad
    end

    callback!(
        app,
        Output("Opx-classification-canvas", "is_open"),
        Input("Opx-classification-canvas-button", "n_clicks"),
        State("Opx-classification-canvas", "is_open"),
        prevent_initial_call = true,
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    """
        Callback to compute and display muscovite classification diagrams
    """
    callback!(
        app,
        Output("MicaInterlayer-plot-pd",  "figure"),
        Output("MicaInterlayer-plot-pd",  "config"),
        Output("MicaCeladonite-plot-pd",  "figure"),
        Output("MicaCeladonite-plot-pd",  "config"),

        Input("compute-Mica-button",      "n_clicks"),

        State("database-dropdown",        "value"),
        State("test-dropdown",            "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test

        global points_in_idx, Out_XY;

        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            il, layoutIL       = get_MicaInterlayer_diagram()
            figMicaIL          = plot( il, layoutIL)

            cel, layoutCel     = get_MicaCeladonite_diagram()
            figMicaCel         = plot( cel, layoutCel)
        else
            figMicaIL        = plot(Layout( height= 740 ))
            figMicaCel       = plot(Layout( height= 740 ))
        end

        configMicaIL   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Mica_Interlayer_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configMicaCel   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Mica_Celadonite_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figMicaIL, configMicaIL, figMicaCel, configMicaCel
    end

    callback!(
        app,
        Output("Mica-classification-canvas", "is_open"),
        Input("Mica-classification-canvas-button", "n_clicks"),
        State("Mica-classification-canvas", "is_open"),
        prevent_initial_call = true,
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    """
        Callback to compute and display feldspar classification diagram
    """
    callback!(
        app,
        Output("Feldspar-plot-pd",       "figure"),
        Output("Feldspar-plot-pd",       "config"),

        Input("compute-Feldspar-button", "n_clicks"),

        State("database-dropdown",       "value"),
        State("test-dropdown",           "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test

        global points_in_idx, Out_XY;

        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            fsp, layoutFsp     = get_Feldspar_diagram()
            figFsp             = plot( fsp, layoutFsp)
        else
            figFsp       = plot(Layout( height= 740 ))
        end

        configFsp   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Feldspar_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figFsp, configFsp
    end

    callback!(
        app,
        Output("Feldspar-classification-canvas", "is_open"),
        Input("Feldspar-classification-canvas-button", "n_clicks"),
        State("Feldspar-classification-canvas", "is_open"),
        prevent_initial_call = true,
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    """
        Callback to compute and display garnet classification diagram
    """
    callback!(
        app,
        Output("Garnet-plot-pd",         "figure"),
        Output("Garnet-plot-pd",         "config"),

        Input("compute-Garnet-button",   "n_clicks"),

        State("database-dropdown",       "value"),
        State("test-dropdown",           "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test

        global points_in_idx, Out_XY;

        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            grt, layoutGrt     = get_Garnet_diagram()
            figGrt             = plot( grt, layoutGrt)
        else
            figGrt       = plot(Layout( height= 740 ))
        end

        configGrt   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Garnet_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figGrt, configGrt
    end

    callback!(
        app,
        Output("Garnet-classification-canvas", "is_open"),
        Input("Garnet-classification-canvas-button", "n_clicks"),
        State("Garnet-classification-canvas", "is_open"),
        prevent_initial_call = true,
    ) do n1, is_open
        return n1 > 0 ? is_open == 0 : is_open
    end;


    """
        Callback to compute and display Fe-Ti oxide classification diagrams
    """
    callback!(
        app,
        Output("Spinel-plot-pd",         "figure"),
        Output("Spinel-plot-pd",         "config"),
        Output("Ilmenite-plot-pd",       "figure"),
        Output("Ilmenite-plot-pd",       "config"),

        Input("compute-Oxide-button",    "n_clicks"),

        State("database-dropdown",       "value"),
        State("test-dropdown",           "value"),

        prevent_initial_call = true,

        ) do    n_click,
                dtb,    test

        global points_in_idx, Out_XY;

        title       = db[(db.db .== dtb), :].title[test+1]

        if @isdefined(points_in_idx) && @isdefined(Out_XY)
            spl, layoutSpl     = get_Spinel_diagram()
            figSpl             = plot( spl, layoutSpl)

            ilm, layoutIlm     = get_Ilmenite_diagram()
            figIlm             = plot( ilm, layoutIlm)
        else
            figSpl       = plot(Layout( height= 740 ))
            figIlm       = plot(Layout( height= 740 ))
        end

        configSpl   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Spinel_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        configIlm   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg",
                                        filename = "Ilmenite_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figSpl, configSpl, figIlm, configIlm
    end

    callback!(
        app,
        Output("Oxide-classification-canvas", "is_open"),
        Input("Oxide-classification-canvas-button", "n_clicks"),
        State("Oxide-classification-canvas", "is_open"),
        prevent_initial_call = true,
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
            Yrange          = (to_kbar_pressure(Float64(pmin)),to_kbar_pressure(Float64(pmax)))

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
            Yrange          = (to_kbar_pressure(Float64(pmin)),to_kbar_pressure(Float64(pmax)))

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
            mkpath(output_dir[1])
            datab   = "_"*dtb
            fileout = output_dir[1]*fname*datab
            out     = using_sample_point ? SamplePoint.out : Out_XY[point_id]
            MAGEMin_data2dataframe(out,dtb,fileout; use_Warr2021=use_warr_names[1], use_GPA=use_GPa[1])
            (!using_sample_point && o18_available()) && o18_export_csv([point_id], fileout*"_O18.csv")

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
            out     = using_sample_point ? SamplePoint.out : Out_XY[point_id]     #point_id/SamplePoint are defined as global variables in the pie-chart callback
            file    = MAGEMin_data2table(out,dtb)
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
            mkpath(output_dir[1])
            datab   = "_"*dtb
            fileout = output_dir[1]*fname*datab

            MAGEMin_data2dataframe(Out_XY,dtb,fileout; use_Warr2021=use_warr_names[1], use_GPA=use_GPa[1])
            o18_available() && o18_export_csv(collect(eachindex(Out_O18_XY)), fileout*"_O18.csv")
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
        State("o18-dropdown","value"),
        State("o18-melt-dropdown","value"),
        State("o18-unmapped-dropdown","value"),
        prevent_initial_call=true,
    ) do n_clicks, fname, dtb, o18_on, o18_melt, o18_unmapped

        if fname != "filename"
            mkpath(output_dir[1])
            output_bib      = "_"*dtb*".bib"
            fileout         = output_dir[1]*fname*output_bib
            magemin         = "MAGEMin"
            bib             = import_bibtex("./references/references.bib")

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
            push_bib_infos!(selection, bib, o18_bib_infos(o18_on, o18_melt, o18_unmapped))

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
            out     = using_sample_point ? SamplePoint.out : Out_XY[point_id]     #point_id/SamplePoint are defined as global variables in the pie-chart callback
            P       = "_P$(pressure_unit_label())_"*string(round(display_pressure(out.P_kbar); digits=3))
            T       = "_TC_"*string(out.T_C)
            datab   = "_"*dtb
            fileout = fname*datab*P*T*".txt"
            file    = save_equilibrium_to_file(out, dtb, mbCpx)
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
            global point_id, using_sample_point, SamplePoint
            ph      = click_info[:points][1][:customdata]

            out     = using_sample_point ? SamplePoint.out : Out_XY[point_id]
            data    = phase_composition_rows(out, ph)

            style  = Dict("display" => "block")
            title =  "$(display_ph_name(ph)) composition"

        elseif bid == "phase-diagram"
            style  = Dict("display" => "none")
            data   = []
            title =  ""
        end

        return style, data, title
    end


    """
        Show/hide the Sample point P/T/X inputs depending on diagram type; Sample point is
        only offered for P-T, P-X and T-X diagrams (PT-X path, poly-metamorphic T-T and
        mu-mu diagrams use different axis semantics and are out of scope for now).
    """
    callback!(
        app,
        Output("sample-point-section-id", "style"),
        Output("sample-point-p-div-id",   "style"),
        Output("sample-point-t-div-id",   "style"),
        Output("sample-point-x-div-id",   "style"),
        Input("diagram-dropdown",         "value"),
    ) do diagType
        shown  = Dict("display" => "block")
        hidden = Dict("display" => "none")

        if diagType == "pt"
            return shown, shown, shown, hidden
        elseif diagType == "px"
            return shown, shown, hidden, shown
        elseif diagType == "tx"
            return shown, hidden, shown, shown
        else
            return hidden, hidden, hidden, hidden
        end
    end


    """
        Keep the Sample point pressure input label in sync with the pressure unit dropdown
    """
    callback!(
        app,
        Output("sample-point-p-label-id", "children"),
        Input("pressure-unit-dropdown",   "value"),

        prevent_initial_call = true,
    ) do pressure_unit
        unit = pressure_unit == "gpa" ? "GPa" : "kbar"
        return "Pressure [$unit]"
    end


    # clickData callback when clicking on diagram point, or computing a Sample point
    callback!(
        app,
        Output("pie-diagram",           "figure"    ),
        Output("system-chemistry-id",   "value"     ),
        Output("magemin_c-snippet",     "value"     ),
        Output("sample-point-error-id", "children"  ),
        Output("sample-point-error-id", "is_open"   ),
        Input("phase-diagram",          "clickData" ),
        Input("select-pie-unit",        "value"     ),
        Input("compute-sample-point-button", "n_clicks"),
        State("database-dropdown",      "value"     ),
        State("diagram-dropdown",       "value"     ),          # pt,px,tx

        State("buffer-dropdown",        "value"     ),
        State("buffer-1-mul-id",        "value"     ),
        State("buffer-2-mul-id",        "value"     ),
        State("phase-selection",        "value"     ),
        State("pure-phase-selection",   "value"     ),
        State("solver-dropdown",        "value"     ),            # bulk-rock 1
        State("optimizer-dropdown",     "value"     ),            # nlopt,ns

        # Sample point
        State("sample-point-p-id",      "value"     ),
        State("sample-point-t-id",      "value"     ),
        State("sample-point-x-id",      "value"     ),
        State("dataset-dropdown",       "value"     ),
        State("mb-cpx-switch",          "value"     ),
        State("limit-ca-opx-id",        "value"     ),
        State("ca-opx-val-id",          "value"     ),
        State("scp-dropdown",           "value"     ),
        State("sas-dropdown",           "value"     ),
        State("wf-id",                  "value"     ),
        State("seismic-cor-dropdown",   "value"     ),
        State("aspect-ratio-id",        "value"     ),
        State("seismic-water-dropdown", "value"     ),
        State("shallow-cor-dropdown",   "value"     ),
        State("fluid-as-melt-dropdown", "value"     ),
        State("anelastic-cor-dropdown", "value"     ),
        State("table-bulk-rock",        "data"      ),
        State("table-2-bulk-rock",      "data"      ),
        State("select-bulk-unit",       "value"     ),
        State("fixed-temperature-val-id", "value"   ),
        State("fixed-pressure-val-id",  "value"     ),

        prevent_initial_call = true,
    ) do click_info, pie_unit, sample_n_clicks, dtb, diagType, buffer, buffer_n1, buffer_n2, ph_selection, pure_ph_selection, solver, optimizer,
            sample_p, sample_t, sample_x, dataset, cpx, limOpx, limOpxVal, scp, sas, wf,
            seismicCorMode, aspectRatioVal, seismicWaterMode, shallowCorMode, fluidAsMeltMode, anelasticCorMode,
            bulk1, bulk2, sys_unit, fixT, fixP

        diagType = diagram_type_2d(diagType)
        # phase_selection                 = remove_phases(string_vec_diff_ss(phase_selection,dtb),dtb)
        # pure_phase_selection            = remove_phases(string_vec_diff_ss(pure_phase_selection,dtb),dtb)
        phase_selection                 = remove_phases(string_vec_diff(to_str_vec(ph_selection),to_str_vec(pure_ph_selection),dtb),dtb)
        global point_id
        global using_sample_point, SamplePoint

        bid = pushed_button( callback_context() )

        # ---- shared builders: turn any single-point result (gmin_struct) into the pie chart / system chemistry text / MAGEMin_C snippet ----
        pie_from_result(out, xval) = phase_pie_figure(out, dtb, pie_unit, xval)

        system_chem_text(out) = system_chemistry_text(out)

        function magemin_snippet(out)
            # code snippet to perform the point calculation in MAGEMin_C
            if buffer != "none"
                buf      = ", buffer=\"$buffer\""
                bufn     = ", B="*string(out.buffer_n)
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
                slv = get_optimizer(dtb, optimizer, 0) == 1 ? ", solver=0, optimizer=1" : ", solver=0"
            elseif solver == "hyb"
                slv = ", solver=2"
            end
            snip     = "using MAGEMin_C\n"
            snip    *= "data    = Initialize_MAGEMin(\"$dtb\", verbose=false$buf$slv);\n"
            snip    *= "P, T    = $( round(out.P_kbar; digits = 8)), $(round(out.T_C; digits = 8));\n"
            snip    *= "Xoxides = [\"$(join(out.oxides,"\"; \""))\"];\n"
            snip    *= "X       = [$(join( round.(out.bulk; digits = 5),", "))];\n"
            snip    *= "sys_in  = \"mol\";\n"
            snip    *= "out     = single_point_minimization(P, T, data, X=X, Xoxides=Xoxides$(bufn), sys_in=sys_in$rm_list)\n"
            return snip
        end

        if bid == "compute-sample-point-button"

            if !(diagType in ("pt", "px", "tx"))
                return no_update(), no_update(), no_update(), "Sample point is only available for P-T, P-X and T-X diagrams.", true
            end
            if isnothing(sample_p) || isnothing(sample_t) || ((diagType == "px" || diagType == "tx") && isnothing(sample_x))
                return no_update(), no_update(), no_update(), "Provide valid P, T and X values.", true
            end

            bulk_L, bulk_R, oxi             = get_bulkrock_prop(bulk1, bulk2; sys_unit=sys_unit)
            mbCpx, limitCaOpx, CaOpxLim, sol = get_init_param(dtb, solver, cpx, limOpx, Float64(limOpxVal))

            if diagType == "pt"
                P_kbar  = to_kbar_pressure(Float64(sample_p))
                T_C     = Float64(sample_t)
                bulk    = copy(bulk_L)
                bufferN = Float64(buffer_n1)
                xval    = nothing
            else
                Xfrac   = clamp(Float64(sample_x), 0.0, 1.0)
                bulk    = bulk_L .* (1.0 - Xfrac) .+ bulk_R .* Xfrac
                bufferN = Float64(buffer_n1) * (1.0 - Xfrac) + Float64(buffer_n2) * Xfrac
                xval    = Xfrac
                if diagType == "px"
                    P_kbar = to_kbar_pressure(Float64(sample_p))
                    T_C    = Float64(fixT)
                else # tx
                    P_kbar = to_kbar_pressure(Float64(fixP))
                    T_C    = Float64(sample_t)
                end
            end

            seismicScheme       = sas == 0 ? "VRH" : "HS"
            seismicWeightFactor  = Float64(wf)

            # same initializer (and hence the same set of options: database, dataset,
            # buffer, solver, cpx/Ca-opx settings, seismic scheme) as the grid/diagram
            # computation itself uses, so the sample point is fully consistent with it
            out = nothing
            MAGEMin_data = nothing
            try
                MAGEMin_data = Initialize_MAGEMin( dtb;
                                                    verbose             = false,
                                                    dataset             = dataset,
                                                    mbCpx               = mbCpx,
                                                    limitCaOpx          = limitCaOpx,
                                                    CaOpxLim            = CaOpxLim,
                                                    buffer              = buffer,
                                                    solver              = sol,
                                                    optimizer           = get_optimizer(dtb, optimizer, sol),
                                                    seismicScheme       = seismicScheme,
                                                    seismicWeightFactor = seismicWeightFactor    )
                out = deepcopy( single_point_minimization(P_kbar, T_C, MAGEMin_data;
                                    X                   = bulk,
                                    Xoxides             = oxi,
                                    sys_in              = "mol",
                                    B                   = bufferN,
                                    rm_list             = phase_selection,
                                    name_solvus         = true,
                                    scp                 = scp,
                                    progressbar         = false,
                                    seismic_cor         = Bool(seismicCorMode),
                                    aspect_ratio        = Float64(aspectRatioVal),
                                    seismic_water       = Int64(seismicWaterMode),
                                    shallow_correction  = Bool(shallowCorMode),
                                    fluid_as_melt       = Bool(fluidAsMeltMode),
                                    anelastic_cor       = Bool(anelasticCorMode) ) )
            catch e
                println("Sample point minimization failed: ", e)
                return no_update(), no_update(), no_update(), "MAGEMin failed to compute this point - check the P/T/X values.", true
            finally
                isnothing(MAGEMin_data) || Finalize_MAGEMin(MAGEMin_data)
            end

            using_sample_point = true
            SamplePoint         = (out = out, xval = xval)

            fig  = pie_from_result(out, xval)
            text = system_chem_text(out)
            snip = magemin_snippet(out)

            return fig, text, snip, no_update(), no_update()

        elseif bid == "phase-diagram" || (bid == "select-pie-unit" && !using_sample_point)

            if bid == "phase-diagram"
                using_sample_point = false
            end

            pid = pd_click_point_id(click_info)

            if pid === nothing
                return no_update(), no_update(), no_update(), no_update(), no_update()
            end

            point_id = pid
            out      = Out_XY[point_id]

            show_x = (diagType == "px" || diagType == "tx") && @isdefined(data) && point_id <= length(data.points)
            xval   = show_x ? data.points[point_id][1] : nothing

            fig  = pie_from_result(out, xval)
            text = system_chem_text(out)
            snip = magemin_snippet(out)

            return fig, text, snip, no_update(), no_update()

        else    # bid == "select-pie-unit" while a Sample point is currently displayed

            if isnothing(SamplePoint)
                return no_update(), no_update(), no_update(), no_update(), no_update()
            end
            out, xval = SamplePoint.out, SamplePoint.xval

            fig  = pie_from_result(out, xval)
            text = system_chem_text(out)
            snip = magemin_snippet(out)

            return fig, text, snip, no_update(), no_update()
        end
    end


    callback!(
        app,
        Output("interval-simulation_progress",  "disabled"),
        Input("stop-trigger",                   "modified_timestamp"),
        Input("start-trigger",                  "value"),
        Input("mageres-progress-off",               "data"),
        Input("pd3d-progress-off",                  "modified_timestamp"),

        prevent_initial_call    = true,
    ) do stop, start, mageres_off, pd3d_off

        bid  = pushed_button( callback_context() )

        if bid == "stop-trigger"
            return true
        elseif bid == "start-trigger"
            return false
        elseif bid == "mageres-progress-off" || bid == "pd3d-progress-off"
            return true
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
        Output("mc-run-trigger",            "value"),
        Output("start-trigger",              "value"),
        Output("compute-3d-button",          "value"),

        Input("compute-button-raw",         "n_clicks"),
        Input("uni-refine-pb-button-raw",   "n_clicks"),
        Input("refine-pb-button-raw",       "n_clicks"),
        Input("mc-run-button-raw",          "n_clicks"),
        Input("launch-run-button-mageres",      "n_clicks"),

        State("compute-button",             "value"),
        State("uni-refine-pb-button",       "value"),
        State("refine-pb-button",           "value"),
        State("mc-run-trigger",             "value"),
        State("compute-3d-button",          "value"),
        State("diagram-dropdown",           "value"),

        prevent_initial_call    = true,
    ) do compute_raw, uni_refine_raw, refine_raw, mc_run_raw, mageres_launch_raw, compute, uni_refine, refine, mc_run_trigger, compute3d, diagType

        bid  = pushed_button( callback_context() )
        if bid == "compute-button-raw" && diagType == "ptx3d"
            return no_update(), no_update(), no_update(), no_update(), 1, compute3d*-1
        elseif bid == "compute-button-raw"
            return compute*-1, no_update(), no_update(), no_update(), 1, no_update()
        elseif bid == "uni-refine-pb-button-raw"
            return no_update(), uni_refine*-1, no_update(), no_update(), 1, no_update()
        elseif bid == "refine-pb-button-raw"
            return no_update(), no_update(), refine*-1, no_update(), 1, no_update()
        elseif bid == "mc-run-button-raw"
            return no_update(), no_update(), no_update(), mc_run_trigger*-1, 1, no_update()
        elseif bid == "launch-run-button-mageres"
            return no_update(), no_update(), no_update(), no_update(), 1, no_update()
        end

    end



    # update the dictionary of the solution phases and end-members for isopleths
    callback!(
        app,
        Output("reaction-line-dropdown","options"),
        Output("reaction-line-dropdown","value"),
        Input("trigger-update-reaction-line-list","value"),
        Input("mineral-naming-dropdown",           "value"),

        prevent_initial_call = true,         # we have to load at startup, so one minimzation is achieved
    ) do reac_update, warr_naming

        global phase_infos, use_warr_names;
        use_warr_names[1] = (warr_naming == "warr")

        if !@isdefined(phase_infos)
            return [], nothing
        end

        pp          = phase_infos.act_pp;
        ss          = phase_infos.act_ss;

        ph          = vcat(ss,pp);

        reac_opt    = [Dict(    "label"     => " "*display_ph_name(i),
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

        if !@isdefined(phase_infos) || isnothing(ph)
            return no_update(), no_update(), no_update(), no_update()
        end

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


    callback!(
        app,
        Output("sys-unit-isopleth-dropdown",    "options"   ),
        Output("sys-unit-isopleth-dropdown",    "value"     ),
        Input("other-dropdown",                 "value"     ),
        State("sys-unit-isopleth-dropdown",     "value"     ),

        prevent_initial_call = true,
    ) do other, val
    
        if other == "calc_ox" || other == "oxComp"
            options        = [  (label = "mol fraction",    value = "mol"),
                                (label = "wt fraction",     value = "wt")]
            if val == "vol"
                val = "mol"
            end
        else
            options        = [  (label = "mol fraction",    value = "mol"),
                                (label = "wt fraction",     value = "wt"),
                                (label = "vol fraction",    value = "vol")]
        end

        return options, val
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
        Output("phase-assemblage-table-id", "data"),
        Output("phase-assemblage-table-id", "selected_cells"),
        Output("phase-assemblage-clipboard-id", "content"),

        Output("isopleth-dropdown",         "options"),
        Output("hidden-isopleth-dropdown",  "options"),
        Output("smooth-colormap",           "value"),
        Output("pd2d-goto-tab",             "data"),

        Output("min-color-id",              "value"),
        Output("max-color-id",              "value"),
        Output("output-loading-id",         "children"),
        Output("trigger-update-ss-list",    "value"),
        Output("trigger-update-reaction-line-list",    "value"),
        Output("show-text-list-id",         "style"),
        Output("stop-trigger",              "data"),
        Output("range-slider-color",        "value"),
        Output("mc-run-done",               "data"),

        Input("update-reaction-line",       "n_clicks"),
        Input("show-full-grid",             "value"), 
     
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
        Input("mc-run-trigger",         "value"),

        # color section
        Input("min-color-id",           "value"),
        Input("max-color-id",           "value"),

        Input("colormaps_cross",        "value"),
        Input("smooth-colormap",        "value"),
        Input("range-slider-color",     "value"),
        Input("set-min-white",          "value"),
        Input("reverse-colormap",       "value"),
        Input("fields-dropdown",        "value"),
        Input("fields-dropdown-o18-q-pd",   "value"),
        Input("fields-dropdown-o18-p1-pd",  "value"),
        Input("fields-dropdown-o18-p2-pd",  "value"),
        Input("update-title-button",    "n_clicks"),
        Input("load-state-id",          "value"),
        Input("mineral-naming-dropdown","value"),
        Input("pressure-unit-dropdown", "value"),
        Input("phase-assemblage-table-id", "selected_cells"),
        Input("clear-assemblage-highlight-button", "n_clicks"),
        subd_inputs("")...,
        Input("smooth-boundaries-switch", "value"),
        Input("smooth-boundaries-sigma",  "value"),

        # STATES
        State("field-size-id",          "value"),
        State("title-id",               "value"),
        State("phase-assemblage-clipboard-id", "content"),

        State("exp-dropdown",           "value"),           # true,false
        State("diagram-dropdown",       "value"),           # pt, px, tx
        State("database-dropdown",      "value"),           # mp, mb, ig ,igd, um, alk
        State("dataset-dropdown",       "value"),           # pt, px, tx
        State("watsat-dropdown",        "value"),           # false,true -> 0,1
        State("watsat-val-id",          "value"),           # false,true -> 0,1

        State("mb-cpx-switch",          "value"),           # false,true -> 0,1
        State("limit-ca-opx-id",        "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id",          "value"),           # 0.0-1.0 -> 0,1
        State("phase-selection",        "value"),
        State("pure-phase-selection",   "value"),

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
        State("optimizer-dropdown",     "value"),           # nlopt,ns
        State("boost-mode-dropdown",    "value"),           # false,true
        State("verbose-dropdown",       "value"),           # none,light,full -> -1,0,1
        State("scp-dropdown",           "value"),           # none,light,full -> -1,0,1
        State("sas-dropdown",           "value"),           # seismic averaging scheme: 0=VRH, 1=HS
        State("wf-id",                  "value"),           # seismic weight factor [0,1]
        State("seismic-cor-dropdown",   "value"),           # seismic velocity corrections true/false
        State("aspect-ratio-id",        "value"),           # aspect ratio of melt/pore geometry [0,1]
        State("seismic-water-dropdown", "value"),           # anelastic correction mode: 0=dry, 1=damp, 2=wet (saturated) mantle
        State("shallow-cor-dropdown",   "value"),           # shallow correction true/false
        State("fluid-as-melt-dropdown", "value"),           # fluid as melt true/false
        State("anelastic-cor-dropdown", "value"),           # anelastic correction true/false

        State("table-bulk-rock",        "data" ),            # bulk-rock 1
        State("table-2-bulk-rock",      "data" ),            # bulk-rock 2
        State("select-bulk-unit",       "value"),
        State("buffer-1-mul-id",        "value"),           # buffer n 1
        State("buffer-2-mul-id",        "value"),           # buffer n 2

        State("mumu-oxide1-dropdown",      "value"),
        State("mumu-oxide2-dropdown",      "value"),
        State("mumu-mu1-min-id",           "value"),
        State("mumu-mu1-max-id",           "value"),
        State("mumu-mu2-min-id",           "value"),
        State("mumu-mu2-max-id",           "value"),
        State("sec-p1-id",                 "value"),
        State("sec-t1-id",                 "value"),
        State("sec-p2-id",                 "value"),
        State("sec-t2-id",                 "value"),
        State("sec-search-pmin-id",        "value"),
        State("sec-search-pmax-id",        "value"),
        State("sec-search-tmin-id",        "value"),
        State("sec-search-tmax-id",        "value"),
        State("sec-range-mode-id",         "value"),
        State("sec-xmin-id",               "value"),
        State("sec-xmax-id",               "value"),
        State("sec-ymin-id",               "value"),
        State("sec-ymax-id",               "value"),

        State("tepm-dropdown",          "value"),
        State("kds-dropdown",           "value"),
        State("zrsat-dropdown",         "value"),
        State("ssat-dropdown",          "value"),
        State("co2sat-dropdown",        "value"),
        State("P2O5sat-dropdown",       "value"),
        State("mnzsat-dropdown",        "value"),
        State("table-te-rock",          "data" ),            # bulk-rock 1
        State("table-te-2-rock",        "data" ),  
        State("o18-dropdown",           "value"),
        State("o18-delta-id",           "value"),
        State("o18-delta2-id",          "value"),
        State("o18-anchor-id",          "value"),
        State("o18-anchor-delta-id",    "value"),
        State("o18-melt-dropdown",      "value"),
        State("o18-unmapped-dropdown",  "value"),
        State("o18-tmax-id",            "value"),

        State("test-dropdown",          "value"),           # test number

        # block related to isopleth plotting
        State("isopleth-dropdown",      "options"),
        State("isopleth-dropdown",      "value"),
        State("hidden-isopleth-dropdown",      "options"),
        State("hidden-isopleth-dropdown",      "value"),
        State("phase-dropdown",         "value"),
        State("fields-dropdown-o18-q-iso",  "value"),
        State("fields-dropdown-o18-p1-iso", "value"),
        State("fields-dropdown-o18-p2-iso", "value"),
        State("ss-dropdown",            "value"),
        State("em-dropdown",            "value"),
        State("ox-dropdown",            "value"),
        State("of-dropdown",            "value"),
        State("other-dropdown",         "value"),
        State("sys-unit-isopleth-dropdown",     "value"),
        State("rm-exfluid-isopleth-dropdown",   "value"),
        State("input-calc-id",          "value"),
        State("input-cust-id",          "value"),
        State("input-calc-sf-id",       "value"),
        State("input-calc-ox-id",       "value"),
        State("input-cust-sf-id",       "value"),
        State("input-cust-ox-id",       "value"),
        State("line-style-dropdown",    "value"),
        State("iso-line-width-id",      "value"),
        State("colorpicker_isoL",       "value"),
        State("iso-text-size-id",       "value"),
        State("iso-min-id",             "value"),
        State("iso-step-id",            "value"),
        State("iso-max-id",             "value"),
        State("tabs",                   "active_tab"),      # currently active tab

        # Monte Carlo (Uncertainty tab)
        State("mc-sigma-table",         "data"),
        State("mc-sigma-mode",          "value"),
        State("mc-bulk-unit",           "value"),
        State("mc-n-realizations",      "value"),
        State("mc-seed",                "value"),
        State("mc-mode",                "value"),
        State("mc-bulk2-table",         "data"),

        State("show-grid",              "value"),
        State("show-lbl-id",            "value"),
        State("lbl-bg-id",              "value"),
        State("iso-label-bg-id",        "value"),

        prevent_initial_call = true,

    ) do args...
        lock(() -> pd_main_update(args...), MINIMIZATION_LOCK)
    end

    function pd_main_update(reac_up,    full_grid,  addIso,     removeIso,  removeAllIso,    isoShow,   isoHide,   isoShowAll,    isoHideAll,
            n_clicks_mesh, n_clicks_refine, uni_n_clicks_refine, n_clicks_mc,
            minColor,   maxColor,
            colorMap,   smooth,     rangeColor, set_white,  reverse,    fieldname,  o18_q,      o18_p1,     o18_p2,     updateTitle,     loadstateid,       warr_naming, pressure_unit,
            assemblage_selected_cells, clearHighlight,
            subd_show,  subd_vel,   subd_dip,   subd_depth, subd_T0,    subd_T1,    subd_h,     subd_d,     subd_kappa, subd_rho,
            smooth_bnd, smooth_sigma,
            # STATES
            field_size, customTitle, txt_list,
            custW,      diagType,   dtb,        dataset,    watsat,     watsat_val, cpx,        limOpx,     limOpxVal,  ph_selection, pure_ph_selection, PTpath,
            tmin,       tmax,       pmin,       pmax,       e1_tmin,    e1_tmax,    e2_tmin,    e2_tmax,    e1_liq,     e2_liq,  e1_remain_wat,     e2_remain_wat,e1_remain,     e2_remain,      
            fixT,       fixP,
            sub,        refType,    refLvl,
            bufferType, solver,     optimizer,  boost,      verbose,    scp,        sas,        wf,         seismicCorMode, aspectRatioVal, seismicWaterMode, shallowCorMode, fluidAsMeltMode, anelasticCorMode,
            bulk1,      bulk2,      sys_unit,
            bufferN1,   bufferN2,
            mumu_oxide1, mumu_oxide2, mumu_mu1_min, mumu_mu1_max, mumu_mu2_min, mumu_mu2_max,
            sec_p1,     sec_t1,     sec_p2,     sec_t2,
            sec_spmin,  sec_spmax,  sec_stmin,  sec_stmax,
            sec_mode,   sec_xmin,   sec_xmax,   sec_ymin,   sec_ymax,
            tepm,       kds_mod,    zrsat_mod,  ssat_mod,   co2sat_mod, P2O5sat_mod,    mnzsat_mod,     bulkte1,    bulkte2,
            o18,        o18_delta,  o18_delta2, o18_anchor, o18_anchor_delta,   o18_melt,   o18_unmapped,   o18_tmax,
            test,
            isopleths,  isoplethsID,isoplethsHid,  isoplethsHidID,  phase,      o18_q_iso,  o18_p1_iso, o18_p2_iso, ss,         em,     ox,    of,     ot, sys, rmf, calc, cust, calc_sf, calc_ox, cust_sf, cust_ox,
            isoLineStyle, isoLineWidth, isoColorLine,           isoLabelSize,
            minIso,     stepIso,    maxIso,
            active_tab,
            mc_sigma_data, mc_sigma_mode_str, mc_bulk_unit, mc_n_real, mc_seed_val, mc_mode, mc_bulk2_data,
            grid,       lbl,        lbl_bg,     iso_lbl_bg)


        diagType                        = diagram_type_2d(diagType)
        o18_field_sel                   = fieldname == "o18"
        fieldname                       = o18_main_fieldname(fieldname, o18_q, o18_p1, o18_p2)
        compute_field                   = is_o18_field(fieldname) ? "Variance" : fieldname
        phase == "o18" && (of = "o18:" * o18_fieldname(o18_q_iso, o18_p1_iso, o18_p2_iso))
        global use_GPa
        use_GPa[1]                      = (pressure_unit == "gpa")                                                                          # keep in sync with the dropdown for this callback's invocation
        phase_selection                 = remove_phases(string_vec_diff(to_str_vec(ph_selection),to_str_vec(pure_ph_selection),dtb),dtb)
        smooth                          = smooth
        seismicScheme                   = sas == 0 ? "VRH" : "HS"
        seismicWeightFactor             = Float64(wf)
        seismicCor                      = Bool(seismicCorMode)
        aspectRatio                     = Float64(aspectRatioVal)
        seismicWater                    = Int64(seismicWaterMode)
        shallowCor                      = Bool(shallowCorMode)
        fluidAsMelt                     = Bool(fluidAsMeltMode)
        anelasticCor                    = Bool(anelasticCorMode)
        pmin, pmax                      = to_kbar_pressure(Float64(pmin)), to_kbar_pressure(Float64(pmax))                                  # convert displayed pressure unit to kbar
        xtitle, ytitle, Xrange, Yrange  = diagram_type(diagType, tmin, tmax, pmin, pmax, e1_tmin, e1_tmax, e2_tmin, e2_tmax)                # get axis information
        bufferN1, bufferN2, fixT, fixP, e1_liq, e2_liq,  e1_remain_wat,  e2_remain_wat,  e1_remain,  e2_remain,  = convert2Float64(bufferN1, bufferN2, fixT, fixP, e1_liq, e2_liq,  e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,)               # convert buffer_n to float
        fixP                            = to_kbar_pressure(fixP)                                                                            # convert displayed pressure unit to kbar
        global use_warr_names
        use_warr_names[1]               = (warr_naming == "warr")
        bid                             = pushed_button( callback_context() )                           # get the ID of the last pushed button
        bulkte_L, bulkte_R, elem        = get_terock_prop(bulkte1, bulkte2)
        colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)              # get colormap information
        bulk_L, bulk_R, oxi             = get_bulkrock_prop(bulk1, bulk2; sys_unit=sys_unit)                               # get bulk rock composition information

        mumu_oxide1_idx     = 0
        mumu_oxide2_idx     = 0

        if diagType in MU_TYPES
            mumu_oxide1_idx     = findfirst(oxi .== mumu_oxide1)
            mumu_oxide2_idx     = diagType == "mumu" ? findfirst(oxi .== mumu_oxide2) : 0

            xtitle, ytitle, _, Yrange = diagram_type(diagType, tmin, tmax, pmin, pmax, e1_tmin, e1_tmax, e2_tmin, e2_tmax;
                                                    mumu_oxide1_name=mumu_oxide1, mumu_oxide2_name=mumu_oxide2)

            Xrange = (Float64(mumu_mu1_min), Float64(mumu_mu1_max))
            if diagType == "mumu"
                Yrange = (Float64(mumu_mu2_min), Float64(mumu_mu2_max))
            end
        end

        sec_Pbox, sec_Tbox, sec_limits = nothing, nothing, nothing
        numP(x)     = x isa Number ? to_kbar_pressure(Float64(x)) : nothing
        numT(x)     = x isa Number ? Float64(x) : nothing
        if diagType in SECTION_TYPES
            sec_mode    = section_range_mode(sec_mode)
            sec_Pbox    = extrema((to_kbar_pressure(Float64(something(sec_p1, 1.0))), to_kbar_pressure(Float64(something(sec_p2, 10.0)))))
            sec_Tbox    = extrema((Float64(something(sec_t1, 500.0)), Float64(something(sec_t2, 800.0))))
            sec_limits  = section_limits(sec_Pbox, sec_Tbox, (numP(sec_spmin), numP(sec_spmax), numT(sec_stmin), numT(sec_stmax)), sec_mode)
            xtitle, ytitle, Xrange, Yrange = diagram_type(diagType, 0.0, 1.0, 0.0, 1.0, e1_tmin, e1_tmax, e2_tmin, e2_tmax)
            if bid == "compute-button"
                if sec_mode == "manual"
                    rx, ry, ok_sec = section_manual_ranges(diagType, sec_xmin, sec_xmax, sec_ymin, sec_ymax)
                else
                    rx, ry, _, ok_sec = section_box_ranges( diagType, sec_Pbox, sec_Tbox, bulk_L, oxi, dtb, bufferType, solver,
                                                            Float64(bufferN1), phase_selection, cpx, limOpx, Float64(limOpxVal);
                                                            mode = sec_mode, optimizer = optimizer, dataset = dataset,
                                                            limits = (numP(sec_spmin), numP(sec_spmax), numT(sec_stmin), numT(sec_stmax)) )
                end
                if ok_sec
                    Xrange, Yrange = rx, ry
                else
                    println("Section diagram: no valid ranges ($(sec_mode)): boundary minimizations failed, the box is degenerate or the manual ranges are incomplete; check the P-T box.")
                end
            elseif @isdefined(data)
                Xrange, Yrange = (Float64(data.Xrange[1]), Float64(data.Xrange[2])), (Float64(data.Yrange[1]), Float64(data.Yrange[2]))
            end
        elseif diagType in SECTION_X_TYPES
            sec_limits  = (numP(sec_spmin), numP(sec_spmax), numT(sec_stmin), numT(sec_stmax))
            if section_x_fixed_P(diagType)
                sec_Pbox, sec_Tbox = (Float64(fixP), Float64(fixP)), (Float64(tmin), Float64(tmax))
            else
                sec_Pbox, sec_Tbox = (Float64(pmin), Float64(pmax)), (Float64(fixT), Float64(fixT))
            end
            xtitle, ytitle, Xrange, Yrange = diagram_type(diagType, tmin, tmax, pmin, pmax, e1_tmin, e1_tmax, e2_tmin, e2_tmax)
            if bid == "compute-button"
                yr, ok_sec = section_x_ranges(  diagType, section_x_fixed_P(diagType) ? Float64(fixP) : Float64(fixT),
                                                section_x_fixed_P(diagType) ? sec_Tbox : sec_Pbox,
                                                bulk_L, bulk_R, Float64(bufferN1), Float64(bufferN2), oxi, dtb, bufferType, solver,
                                                phase_selection, cpx, limOpx, Float64(limOpxVal); optimizer = optimizer, dataset = dataset )
                if ok_sec
                    Yrange = yr
                else
                    println("Section diagram: the bounds do not span a range (a corner minimization failed or equal values); check the bounds.")
                end
            elseif @isdefined(data)
                Xrange, Yrange = (Float64(data.Xrange[1]), Float64(data.Xrange[2])), (Float64(data.Yrange[1]), Float64(data.Yrange[2]))
            end
        end

        global pd_fig_meta
        pd_fig_meta = (xtitle = xtitle, ytitle = ytitle, diagType = diagType)

        fieldNames                      = ["data_plot","data_reaction","data_grid","data_isopleth_out"]
        fieldNames_exp                  = ["data_plot","data_reaction","data_grid","data_isopleth_out_export"]
        field2plot                      = zeros(Int64,4)

        field2plot[1]       =  1
        loading             = ""
        update_ss_list      = ""
        update_reaction_list      = ""
        store_stop   = string(rand())
        clear_selection      = no_update()     # only touched when a new diagram is built or the Clear button is pushed
        mc_done      = no_update()


        if bid == "compute-button"
            loading                     = ""  
            smooth                      = "best"
            # declare set of global variables needed to generate, refine and display phase diagrams
            global fig, data, Hash_XY, Out_TE_XY, all_TE_ph, Out_O18_XY, all_O18_ph, n_phase_XY, gridded, gridded_info, gridded_fields, phase_infos, X, Y, meant, npoints
            global addedRefinementLvl   = 0;
            global n_lbl                = 0;
            global iso_show             = 1;
            global data_plot, data_reaction, data_grid, layout, data_isopleth, data_isopleth_out, data_isopleth_out_export, PT_infos, infos, heat_map_export;
            global assemblage_rows, list_compacted_idx, raw_field_id, poly_phases, poly_pcoor
            global Out_XY =  Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,0)
            global CompProgress

            CompProgress.title = "Calculation Progress"
        
            CompProgress.stage = "Initial G isopleth"
            data_isopleth = initialize_g_isopleth(; n_iso_max = 32)

            if fieldname == "Variance"
                rangeColor = [1,7]
                colorm, reverseColorMap         = get_colormap_prop(colorMap, rangeColor, reverse)
            end

            data_plot, layout, npoints, meant, txt_list, heat_map_export, assemblage_rows, list_compacted_idx, raw_field_id  =  compute_new_phaseDiagram(  xtitle,     ytitle,     lbl,        field_size,
                                                                                                        Xrange,     Yrange,     compute_field,  customTitle,
                                                                                                        dtb,        dataset,    custW,      diagType,   verbose,    scp,        solver,     boost, phase_selection,
                                                                                                        fixT,       fixP,
                                                                                                        e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,     e1_remain,  e2_remain,
                                                                                                        sub,        refLvl,
                                                                                                        watsat,     watsat_val, cpx,        limOpx,     limOpxVal,  PTpath,
                                                                                                        bulk_L,     bulk_R,     oxi,
                                                                                                        bufferType, bufferN1,   bufferN2,
                                                                                                        minColor,   maxColor,
                                                                                                        smooth,     colorm,     reverseColorMap, set_white,
                                                                                                        test,       refType,
                                                                                                        seismicScheme, seismicWeightFactor,
                                                                                                        seismicCor, aspectRatio, seismicWater, shallowCor, fluidAsMelt, anelasticCor;
                                                                                                        mumu_oxide1_idx=mumu_oxide1_idx, mumu_oxide2_idx=mumu_oxide2_idx,
                                                                                                        optimizer=optimizer, sec_Pbox=sec_Pbox, sec_Tbox=sec_Tbox, sec_limits=sec_limits        )
            if tepm == "true"
                if dtb != "um" && dtb != "ume" && dtb != "mtl"
                    t = @elapsed Out_TE_XY,all_TE_ph = tepm_function(   diagType, dtb,
                                                                        kds_mod, zrsat_mod, ssat_mod, co2sat_mod, P2O5sat_mod, mnzsat_mod,
                                                                        bulkte_L, bulkte_R, elem)

                    println("Computed trace element partitioning in $t s")
                else
                    println("Cannot compute trace-element partitioning for $dtb database as it does not include a melt model\n")
                end
            end

            t = @elapsed Out_O18_XY, all_O18_ph = o18_diagram(  o18, diagType, o18_delta, o18_delta2, o18_anchor, o18_anchor_delta, o18_melt, o18_unmapped, o18_tmax,
                                                                bulk_L, bulk_R, oxi)
            o18 == "true" && println("Computed oxygen isotope fractionation in $t s")
            if is_o18_field(fieldname) && o18_available()
                data_plot, layout, heat_map_export = update_displayed_field_phaseDiagram(   xtitle,     ytitle,     Xrange,     Yrange,     fieldname,
                                                                                            dtb,        oxi,        sub,        refLvl,
                                                                                            smooth,     colorm,     reverseColorMap, set_white,
                                                                                            test,       refType )
            else
                fieldname = compute_field
            end

            infos           = get_computation_info(npoints, meant)

            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid       = show_hide_mesh_grid()
            active_tab      = "tab-phase-diagram" 

            minColor, maxColor = field_color_range(fieldname, gridded)
            update_ss_list  = 1
            update_reaction_list  = 1
            clear_selection = []
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

            data_plot, layout, npoints, meant, txt_list, heat_map_export, assemblage_rows, list_compacted_idx, raw_field_id   =  refine_phaseDiagram(   xtitle,     ytitle,     lbl,        field_size,
                                                                                    Xrange,     Yrange,     compute_field,  customTitle,
                                                                                    dtb,        dataset,    custW,      diagType,   watsat,     watsat_val, verbose,    scp,    solver,  boost, phase_selection,
                                                                                    fixT,       fixP,
                                                                                    e1_liq,     e2_liq,     e1_remain_wat,  e2_remain_wat,e1_remain,  e2_remain,
                                                                                    sub,        refLvl,
                                                                                    cpx,        limOpx,     limOpxVal,  PTpath,
                                                                                    bulk_L,     bulk_R,     oxi,
                                                                                    bufferType, bufferN1,   bufferN2,
                                                                                    minColor,   maxColor,
                                                                                    smooth,     colorm,     reverseColorMap, set_white,
                                                                                    test,       refType,    bid,
                                                                                    seismicScheme, seismicWeightFactor,
                                                                                    seismicCor, aspectRatio, seismicWater, shallowCor, fluidAsMelt, anelasticCor;
                                                                                    mumu_oxide1_idx=mumu_oxide1_idx, mumu_oxide2_idx=mumu_oxide2_idx,
                                                                                    optimizer=optimizer, sec_Pbox=sec_Pbox, sec_Tbox=sec_Tbox, sec_limits=sec_limits     )

            if tepm == "true"
                if dtb != "um" && dtb != "ume" && dtb != "mtl"
                    t = @elapsed Out_TE_XY,all_TE_ph = tepm_function(   diagType, dtb,
                                                                        kds_mod, zrsat_mod, ssat_mod, co2sat_mod, P2O5sat_mod, mnzsat_mod,
                                                                        bulkte_L, bulkte_R, elem)
                    println("Computed trace element partitioning in $t s")
                else
                    println("Cannot compute trace-element partitioning for $dtb database as it does not include a melt model\n")
                end
            end

            t = @elapsed Out_O18_XY, all_O18_ph = o18_diagram(  o18, diagType, o18_delta, o18_delta2, o18_anchor, o18_anchor_delta, o18_melt, o18_unmapped, o18_tmax,
                                                                bulk_L, bulk_R, oxi)
            o18 == "true" && println("Computed oxygen isotope fractionation in $t s")
            if is_o18_field(fieldname) && o18_available()
                data_plot, layout, heat_map_export = update_displayed_field_phaseDiagram(   xtitle,     ytitle,     Xrange,     Yrange,     fieldname,
                                                                                            dtb,        oxi,        sub,        refLvl,
                                                                                            smooth,     colorm,     reverseColorMap, set_white,
                                                                                            test,       refType )
            else
                fieldname = compute_field
            end

            infos           = get_computation_info(npoints, meant)
            data_reaction   = show_hide_reaction_lines(sub,refLvl,Xrange,Yrange)
            data_grid       = show_hide_mesh_grid()
            minColor, maxColor = field_color_range(fieldname, gridded)
            update_ss_list  = 1
            update_reaction_list  = 1
            clear_selection = []

        elseif bid == "mc-run-trigger"

            global gridded_fields, addedRefinementLvl, CompProgress

            if diagType != "pt" || watsat == "true"
                mc_done = "failed:diagram"
            elseif !@isdefined(gridded_fields)
                mc_done = "failed:nodata"
            elseif mc_mode == "linear"
                bulk_R_mc = mc_bulk2_from_table(mc_bulk2_data, oxi, sys_unit)
                N_mc      = mc_n_real isa Number ? Int64(round(mc_n_real)) : 0
                if isnothing(bulk_R_mc)
                    mc_done = "failed:nobulk2"
                elseif N_mc < 2
                    mc_done = "failed:steps"
                else
                    mc_opts = mc_ref_options(dtb, dataset, oxi, bufferType, Float64(bufferN1), Int64(scp), solver,
                                              cpx, limOpx, Float64(limOpxVal), phase_selection, custW == true; optimizer = optimizer)
                    refLvl_mc          = Int64(something(refLvl, 0)) + addedRefinementLvl
                    bulks_mc, x_mc     = linear_bulks(bulk_L, bulk_R_mc, N_mc)

                    t_mc = @elapsed mc_res = run_monte_carlo_pt(bulk_L, bulks_mc, Xrange, Yrange, sub, refLvl_mc, mc_opts; x = x_mc)

                    global mc_result
                    mc_result = mc_res

                    mc_done = "ok:$N_mc:$(round(t_mc, digits=1))"
                end
            else
                sigma_mode   = mc_sigma_mode_str == "absolute" ? :absolute : :relative
                mc_defaults  = mc_sigma_for_oxides(oxi)
                sigma_lookup = isempty(mc_sigma_data) ? Dict{String,Float64}() :
                    Dict(String(r[:oxide]) => (r[:sigma] isa String ? parse(Float64, r[:sigma]) : Float64(r[:sigma])) for r in mc_sigma_data)
                sigma_input  = [get(sigma_lookup, oxi[i], mc_defaults[i]) for i in eachindex(oxi)]
                if sigma_mode == :absolute && mc_bulk_unit == 2
                    # the σ table is currently displayed/edited in wt%, but run_monte_carlo_pt
                    # always works against bulk_L (mol) - convert σ to the matching mol basis first
                    bulk_wt      = mol2wt(bulk_L, oxi)
                    sigma_mol    = mc_convert_absolute_sigma(bulk_wt, sigma_input, oxi, false)
                    sigma_input  = [isnan(sigma_mol[i]) ? 0.0 : sigma_mol[i] for i in eachindex(sigma_mol)]
                end
                sigma_mode == :absolute && (sigma_input = sigma_input ./ 100.0)

                mc_opts = mc_ref_options(dtb, dataset, oxi, bufferType, Float64(bufferN1), Int64(scp), solver,
                                          cpx, limOpx, Float64(limOpxVal), phase_selection, custW == true; optimizer = optimizer)

                N_mc      = Int64(mc_n_real)
                refLvl_mc = Int64(something(refLvl, 0)) + addedRefinementLvl
                seed_mc   = isnothing(mc_seed_val) ? nothing : Int64(mc_seed_val)

                t_mc = @elapsed mc_res = run_monte_carlo_pt(bulk_L, sigma_input, sigma_mode, N_mc,
                                                             Xrange, Yrange, sub, refLvl_mc, mc_opts; seed = seed_mc)

                global mc_result
                mc_result = mc_res

                mc_done = "ok:$N_mc:$(round(t_mc, digits=1))"
            end

        elseif bid == "load-state-id"
            if !loaded_state_has_diagram
                return ntuple(_ -> no_update(), 23)
            end

            Xrange_s    = (data.Xrange[1], data.Xrange[2])
            Yrange_s    = (data.Yrange[1], data.Yrange[2])
            oxi_s       = String.(Out_XY[1].oxides)

            is_o18_field(fieldname) && !o18_available() && (fieldname = compute_field)
            data_plot,layout,heat_map_export =  update_displayed_field_phaseDiagram( xtitle,     ytitle,
            Xrange_s,   Yrange_s,   fieldname,
            dtb,        oxi_s,
            sub,        refLvl,
            smooth,     colorm,     reverseColorMap, set_white,
            test,       refType                                 )

            minColor, maxColor = field_color_range(fieldname, gridded)

            active_tab      = "tab-phase-diagram"

            # states saved before assemblage_rows/list_compacted_idx/raw_field_id were part
            # of the saved fields (or a fresh session that never computed a diagram) won't
            # have these defined yet -- fall back to empty rather than crashing below
            global assemblage_rows, list_compacted_idx, raw_field_id
            @isdefined(assemblage_rows)     || (assemblage_rows     = Vector{Dict{String,String}}())
            @isdefined(list_compacted_idx)  || (list_compacted_idx  = Int[])
            @isdefined(raw_field_id)        || (raw_field_id        = Int[])

            global gridded_info, gridded_fields, poly_phases, poly_pcoor
            phase_infos     = get_phase_infos(Out_XY)
            _, gridded_info, gridded_fields, _, _, _, _ = get_gridded_map( compute_field, "major", oxi_s, Out_XY, nothing, Hash_XY,
                                                                            sub, refLvl + addedRefinementLvl, refType, data, Xrange_s, Yrange_s )
            poly_phases, poly_pcoor     = compute_assemblage_boundaries(gridded_fields, Xrange_s, Yrange_s)
            data_grid                   = show_hide_mesh_grid()
            isopleths, isoplethsHid     = isopleth_dropdown_options(data_isopleth)
            data_isopleth_out_export    = data_isopleth.isoPexp[data_isopleth.active]
            update_ss_list              = 1
            update_reaction_list        = 1
            clear_selection             = []
        elseif bid == "set-min-white" || bid == "min-color-id" || bid == "max-color-id" || bid == "colormaps_cross" || bid == "smooth-colormap" || bid == "range-slider-color" || bid == "reverse-colormap"

            data_plot, layout, heat_map_export =  update_colormap_phaseDiagram(  xtitle,     ytitle,     
                                                                                Xrange,     Yrange,     fieldname,
                                                                                dtb,        diagType,
                                                                                sub,        refLvl,
                                                                                minColor,   maxColor,
                                                                                smooth,     colorm,     reverseColorMap, set_white,
                                                                                test                                                    )

        elseif bid == "fields-dropdown" || (o18_field_sel && bid in ("fields-dropdown-o18-q-pd", "fields-dropdown-o18-p1-pd", "fields-dropdown-o18-p2-pd"))

            if is_o18_field(fieldname) && !o18_available()
                println("δ18O is not available: activate the δ18O model in Setup -> Oxygen isotopes and compute the phase diagram")
                fieldname = compute_field
            end

            data_plot,layout,heat_map_export =  update_displayed_field_phaseDiagram( xtitle,     ytitle,     
                                                                    Xrange,     Yrange,     fieldname,
                                                                    dtb,        oxi,
                                                                    sub,        refLvl,
                                                                    smooth,     colorm,     reverseColorMap, set_white,
                                                                    test,       refType                                 )

            minColor, maxColor = field_color_range(fieldname, gridded)
                                                                                                 
        elseif bid == "show-full-grid"

            if full_grid == "true"
                field2plot[3] = 1
            end
                                                        
        elseif bid == "button-add-isopleth"

            data_isopleth, isopleths = add_isopleth_phaseDiagram(   Xrange,     Yrange,
                                                                    sub,        refLvl,
                                                                    dtb,        oxi,
                                                                    isopleths,  phase,      ss,     em,  ox,   of,     ot, sys, rmf,    calc, cust, calc_sf, calc_ox, cust_sf, cust_ox,
                                                                    isoLineStyle,   isoLineWidth, isoColorLine,           isoLabelSize,   
                                                                    minIso,     stepIso,    maxIso;
                                                                    label_bg = iso_lbl_bg == "true" )
            data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
            data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
            field2plot[4] = 1
            iso_show      = 1

        elseif bid == "button-hide-isopleth"

            if (isoplethsID) in data_isopleth.active
                data_isopleth, isopleths, isoplethsHid = hide_single_isopleth_phaseDiagram(isoplethsID)
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
                field2plot[4] = 1
            else
                println("Cannot hide isopleth, did you select one?")
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
                field2plot[4] = 1
            end
        elseif bid == "button-show-isopleth"

            if (isoplethsHidID) in data_isopleth.hidden
                data_isopleth, isopleths, isoplethsHid = show_single_isopleth_phaseDiagram(isoplethsHidID)
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
                field2plot[4] = 1
            else
                println("Cannot show isopleth, did you select one?")
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
                field2plot[4] = 1
            end
        elseif bid == "button-remove-isopleth"

            if (isoplethsID) in data_isopleth.active
                if data_isopleth.n_iso > 1
                    data_isopleth, isopleths = remove_single_isopleth_phaseDiagram(isoplethsID)
                    data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                    data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
                    field2plot[4] = 1
                else
                    data_isopleth, isopleths, isoplethsHid, data_plot = remove_all_isopleth_phaseDiagram()
                end

            else
                println("Cannot remove isopleth, did you select one?")
                data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
                data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
                field2plot[4] = 1
            end

        elseif bid == "button-remove-all-isopleth"

            data_isopleth, isopleths, isoplethsHid, data_plot = remove_all_isopleth_phaseDiagram()

        elseif bid == "button-show-all-isopleth"

            iso_show          = 1
            data_isopleth_out = data_isopleth.isoP[data_isopleth.active]
            data_isopleth_out_export = data_isopleth.isoPexp[data_isopleth.active]
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

        elseif bid == "mineral-naming-dropdown"
            if !@isdefined(Out_XY) || isempty(Out_XY) || !@isdefined(PT_infos)
                return no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
            end
            global assemblage_rows, list_compacted_idx, raw_field_id
            label_plot, annotations, txt_list, assemblage_rows, list_compacted_idx, raw_field_id = get_diagram_labels(
                Out_XY, Hash_XY, refType, data, PT_infos; field_size = field_size)
            label_plot[1]        = data_plot[1]
            data_plot            = vcat(label_plot, data_plot[end])
            layout[:annotations] = annotations

        elseif bid == "pressure-unit-dropdown"
            if !@isdefined(data_plot) || !@isdefined(layout)
                return no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
            end
            # redraw only: data_plot/layout stay in kbar, apply_pressure_display() rescales for display below

        elseif bid == "phase-assemblage-table-id"
            if !@isdefined(data_plot) || !@isdefined(layout) || !@isdefined(list_compacted_idx) || !@isdefined(raw_field_id)
                return no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
            end
            # clear any previously highlighted field (reset every field trace back to its inert placeholder)
            # before (possibly) drawing a new one -- data_plot[1] is the heatmap, data_plot[end] is the hidden hover layer
            for k = 2:length(data_plot)-1
                data_plot[k] = scatter(; x = nothing, y = nothing, fill = "toself", fillcolor = "transparent",
                                        line_width = 0.0, mode = "lines", hoverinfo = "text", showlegend = false,
                                        text = data_plot[k][:text])
            end

            if !isempty(assemblage_selected_cells)
                row = assemblage_selected_cells[1]["row"] + 1
                if row <= length(list_compacted_idx) && @isdefined(poly_phases) && @isdefined(poly_pcoor)
                    compacted_idx   = list_compacted_idx[row]
                    raw_id          = raw_field_id[compacted_idx]
                    matches         = findall(==(raw_id), poly_phases)
                    geom_hl         = smooth_bnd == true ? pd_get_smooth_geometry(something(smooth_sigma, pd_smooth_sigma_default)) : nothing
                    if !isempty(matches)
                        px, py = Union{Float64,Nothing}[], Union{Float64,Nothing}[]
                        if geom_hl !== nothing
                            px, py = pd_domain_rings(geom_hl, raw_id)
                        else
                            for (n, m) in enumerate(matches)
                                n > 1 && (push!(px, nothing); push!(py, nothing))
                                append!(px, poly_pcoor[m][:,1]); append!(py, poly_pcoor[m][:,2])
                            end
                        end
                        data_plot[compacted_idx+1] = scatter(; x = px, y = py, fill = "toself", fillcolor = "transparent",
                                                            line = attr(color = "red", width = 3), mode = "lines",
                                                            hoverinfo = "text", showlegend = false,
                                                            text = data_plot[compacted_idx+1][:text])
                    end
                end
            end

        elseif bid in subd_input_ids("") || bid == "smooth-boundaries-switch" || bid == "smooth-boundaries-sigma"
            if !@isdefined(data_plot) || !@isdefined(layout)
                return no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
            end

        elseif bid in ("fields-dropdown-o18-q-pd", "fields-dropdown-o18-p1-pd", "fields-dropdown-o18-p2-pd")

        elseif bid == "clear-assemblage-highlight-button"
            if !@isdefined(data_plot) || !@isdefined(layout)
                return no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update(), no_update()
            end
            for k = 2:length(data_plot)-1
                data_plot[k] = scatter(; x = nothing, y = nothing, fill = "toself", fillcolor = "transparent",
                                        line_width = 0.0, mode = "lines", hoverinfo = "text", showlegend = false,
                                        text = data_plot[k][:text])
            end
            clear_selection = []

        else
            fig = plot()
        end

        for i=1:n_lbl
            layout[:annotations][i][:visible] = lbl == "true"
            layout[:annotations][i][:name]    = "pd-label"
        end
        show_text_list  = Dict("display" => lbl == "true" ? "block" : "none")
        pd_apply_label_bg!(layout[:annotations], lbl_bg == "true")

        # check state of unchanged variables ["data_plot","data_reaction","data_grid"]
        if @isdefined(data_reaction) && !isempty(data_reaction)
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
            geom     = smooth_bnd == true ? pd_get_smooth_geometry(something(smooth_sigma, pd_smooth_sigma_default)) : nothing

            fills_on = geom !== nothing && is_integer_field(fieldname) && @isdefined(heat_map_export) && @isdefined(gridded)
            iso_anns = PlotlyBase.PlotlyAttribute[]
            if fills_on
                data_all = vcat(data_all[1:1], pd_fill_traces(geom, heat_map_export, gridded), data_all[2:end])
            end

            for i=2:np
                if field2plot[i] == 1
                    layer    = eval(Symbol(fieldNames[i]))
                    if i == 2
                        layer = geom !== nothing ? pd_smooth_reaction(layer, geom) : layer
                        layer === data_reaction && (layer = [GenericTrace(copy(tr.fields)) for tr in layer])
                        for tr in layer
                            tr[:visible] = grid == "true"
                            tr[:meta]    = "pd-reaction"
                        end
                    elseif i == 4 && geom !== nothing
                        layer, iso_anns = pd_isopleth_overlay(data_isopleth, data.Xrange, data.Yrange; sigma = geom.sigma)
                    end
                    data_all = vcat( data_all, layer )
                end
            end

            if @isdefined(data)
                data_all = vcat(data_all, subduction_geotherm_update!("pd", subd_show, subd_vel, subd_dip, subd_depth, subd_T0, subd_T1, subd_h, subd_d, subd_kappa, subd_rho,
                                                                      data.Xrange, data.Yrange, diagType))
                data_all = vcat(data_all, pd_select_anchor(data))
            end

            layout_iso = layout
            if !isempty(iso_anns)
                layout_iso = deepcopy(layout)
                layout_iso[:annotations] = vcat(layout_iso[:annotations], iso_anns)
            end
            data_all_disp, layout_disp = apply_pressure_display(data_all, layout_iso, diagType)
            fig = plot_diagram(data_all_disp,layout_disp)

        end

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

        config   = PlotConfig(    toImageButtonOptions  = attr(     name     = "Download as svg",
                                                                    format   = "svg",
                                                                    filename =  replace(customTitle, " " => "_"),
                                                                    height   =  900,
                                                                    width    =  720,
                                                                    scale    =  2.0,       ).fields)


        if field2plot[4] == 0
            fig_cap = plot(layoutCap)
        else
            caps = [scatter(x           = [nothing],
                            y           = [nothing],
                            mode        = "lines",
                            line        = data_isopleth.isoCap[data_isopleth.active[i]][:line],
                            name        = display_iso_label(data_isopleth.label[data_isopleth.active[i]]),
                            showlegend  = true)
                    for i in 1:length(data_isopleth.active)]
            fig_cap = plot(caps, layoutCap)
        end
        
        config_cap  = PlotConfig(    toImageButtonOptions  = attr(      name     = "Download as svg",
                                                                        format   = "svg",
                                                                        filename =  (replace(customTitle, " " => "_"))*"_label",
                                                                        height   =  30,
                                                                        width    =  900,
                                                                        scale    =  2.0,       ).fields)

        if isempty(update_ss_list) && isempty(update_reaction_list)
            return grid, full_grid, fig_cap, config_cap, fig, config, infos, assemblage_rows, clear_selection, txt_list, isopleths, isoplethsHid, smooth, active_tab, minColor,   maxColor, loading, no_update(), no_update(), show_text_list, store_stop, rangeColor, mc_done
        else
            return grid, full_grid, fig_cap, config_cap, fig, config, infos, assemblage_rows, clear_selection, txt_list, isopleths, isoplethsHid, smooth, active_tab, minColor,   maxColor, loading, update_ss_list, update_reaction_list, show_text_list, store_stop, rangeColor, mc_done
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
        if @isdefined(data_isopleth) && !isempty(data_isopleth.active)

            isoT = data_isopleth.isoT[data_isopleth.active]
            lbl = data_isopleth.label[data_isopleth.active]

            for i in eachindex(isoT)
                export_contours_to_txt(isoT[i], lbl[i], output_dir[1]*"isopleth_"*replace(title, " " => "_")*"_"*lbl[i]*".txt")
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
        [State("collapse", "is_open")],

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


    """
        Callback function to toggle the visibility of the collapse element
    """
    callback!(app,
        Output("collapse-infos-phase-diagram", "is_open"),
        [Input("infos-phase-diagram", "n_clicks")],
        [State("collapse-infos-phase-diagram", "is_open")],

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
        Output("collapse-phase-label", "is_open"),
        [Input("phase-label", "n_clicks")],
        [State("collapse-phase-label", "is_open")],

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
        Output("collapse-export-figure", "is_open"),
        [Input("export-figure", "n_clicks")],
        [State("collapse-export-figure", "is_open")],

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

    # Draw path — disable record switch when leaving the Draw path tab
    callback!(
        app,
        Output("draw-path-record-switch", "value"),
        Input("pd-sidebar-tabs",          "active_tab"),
        prevent_initial_call = true,
    ) do active_tab
        return active_tab == "tab-3" ? no_update() : false
    end

    # Draw path — record clicks and clear; also updates coordinate table
    callback!(
        app,
        Output("draw-path-point-count",  "children"  ),
        Output("draw-path-table",        "columns"   ),
        Output("draw-path-table",        "data"      ),
        Input("phase-diagram",           "clickData" ),
        Input("draw-path-clear-button",  "n_clicks"  ),
        Input("draw-path-remove-button", "n_clicks"  ),
        Input("pressure-unit-dropdown",  "value"     ),
        State("draw-path-record-switch", "value"     ),
        State("diagram-dropdown",        "value"     ),
        prevent_initial_call = true,
    ) do click_info, _n_clear, _n_remove, pressure_unit, is_recording, diagType  # _n_clear/_n_remove trigger via callback_context

        global draw_path_ids, use_GPa
        use_GPa[1] = (pressure_unit == "gpa")

        if !@isdefined(draw_path_ids)
            draw_path_ids = Vector{Int64}()
        end

        bid = pushed_button( callback_context() )

        if bid == "draw-path-clear-button"
            draw_path_ids = Vector{Int64}()
        elseif bid == "draw-path-remove-button"
            if !isempty(draw_path_ids)
                pop!(draw_path_ids)
            end
        elseif bid == "phase-diagram" && is_recording && !isnothing(click_info)
            pid = pd_click_point_id(click_info)
            pid === nothing || push!(draw_path_ids, pid)
        end

        cols, rows = draw_path_table_data(diagType, draw_path_ids)
        return "$(length(draw_path_ids)) point(s)", cols, rows
    end

    # Draw path — show/hide field dropdown depending on display mode
    callback!(
        app,
        Output("draw-path-field-id", "style"),
        Input("draw-path-mode-dropdown", "value"),
        prevent_initial_call = true,
    ) do mode
        return mode == "field" ? Dict("display" => "block") : Dict("display" => "none")
    end

    # Draw path — generate stacked area / field profile diagram
    callback!(
        app,
        Output("draw-path-diagram", "figure" ),
        Output("draw-path-diagram", "config" ),
        Output("draw-path-canvas",  "is_open"),
        Input("draw-path-generate-button", "n_clicks"),
        Input("mineral-naming-dropdown",   "value"   ),
        State("draw-path-sysunit",         "value"   ),
        State("diagram-dropdown",          "value"   ),
        State("draw-path-mode-dropdown",   "value"   ),
        State("draw-path-field-dropdown",  "value"   ),
        State("database-dropdown",         "value"   ),
        prevent_initial_call = true,
    ) do _n, warr_naming, sysunit, diagType, mode, field_value, dtb
        global use_warr_names
        use_warr_names[1] = (warr_naming == "warr")

        global draw_path_ids

        bid = pushed_button( callback_context() )

        if !@isdefined(draw_path_ids) || isempty(draw_path_ids)
            return plot(Layout(height=360)), PlotConfig(), (bid == "mineral-naming-dropdown" ? no_update() : false)
        end

        if mode == "field"
            traces  = get_draw_path_field_plot(diagType, field_value, draw_path_ids)
            ytitle  = get(OTHER_FIELD_LABELS, field_value, field_value)
            fname   = "draw_path_field_profile"
        else
            traces, _phase_list = get_draw_path_plot(diagType, sysunit, draw_path_ids, dtb)
            ytitle  = "Phase fraction [$(sysunit)%]"
            fname   = "draw_path_phase_fractions"
        end

        xtitle = diagType == "px"  ? "X; P [$(pressure_unit_label())]" :
                 diagType == "tx"  ? "X; T [°C]"   :
                 diagType == "pmu" ? "μ; P [$(pressure_unit_label())]" :
                 diagType == "tmu" ? "μ; T [°C]"   : "T [°C]; P [$(pressure_unit_label())]"

        layout = Layout(
            font        = attr(size=10),
            height      = 360,
            margin      = attr(autoexpand=false, l=55, r=12, b=50, t=10),
            autosize    = true,
            paper_bgcolor = "white",
            plot_bgcolor  = "white",
            xaxis       = attr(title=xtitle, showgrid=false, zeroline=false,
                                showline=true, linecolor="black", linewidth=1, mirror=true,
                                ticks="outside", tickcolor="black"),
            yaxis       = attr(title=ytitle, autorange=true, showgrid=false, zeroline=false,
                                showline=true, linecolor="black", linewidth=1, mirror=true,
                                ticks="outside", tickcolor="black"),
            showlegend  = (mode != "field"),
        )

        fig    = plot(traces, layout)
        config = PlotConfig(
            toImageButtonOptions = attr(
                name     = "Download as svg",
                format   = "svg",
                filename = fname,
                width    = 800,
                height   = 300,
                scale    = 2.0,
            ).fields
        )

        return fig, config, (bid == "mineral-naming-dropdown" ? no_update() : true)
    end

    # ── Thermobarometric intersection callbacks ───────────────────────────────

    # Populate phase dropdown when tab becomes active or refresh button is clicked
    callback!(app,
        Output("tb-phase-dropdown",       "options"),
        Input("pd-sidebar-tabs",          "active_tab"),
        Input("tb-refresh-phases-button", "n_clicks"),
        prevent_initial_call = true,
    ) do active_tab, _n_refresh
        bid = pushed_button(callback_context())
        if bid == "pd-sidebar-tabs" && active_tab != "tab-4"
            return no_update()
        end
        global Out_XY
        if !@isdefined(Out_XY) || isempty(Out_XY)
            return []
        end
        ph_all = unique(vcat([Out_XY[i].ph for i in 1:length(Out_XY)]...))
        sort!(ph_all)
        return [Dict("label" => display_ph_name(p), "value" => p) for p in ph_all]
    end

    # CSV upload → csv-store + info message
    # Filters oxides to those present in the database and renormalises to 100.
    callback!(app,
        Output("tb-csv-store", "data"),
        Output("tb-csv-info",  "children"),
        Input("tb-csv-upload", "contents"),
        State("tb-csv-upload", "filename"),
        prevent_initial_call = true,
    ) do contents, filename
        if isnothing(contents)
            return [], "No file loaded"
        end
        try
            _, content_string = split(contents, ',')
            decoded    = base64decode(content_string)
            input      = strip_bom(String(decoded))
            first_line = split(input, '\n')[findfirst(l -> !isempty(strip(l)) && !startswith(strip(l), '#'), split(input, '\n'))]
            delim = occursin(';', first_line) ? ';' : ','
            raw   = strip.(string.(readdlm(IOBuffer(input), delim, comments=true, comment_char='#')))
            if size(raw, 1) < 2
                return [], "File has no data rows"
            end
            headers = String.(raw[1, :])

            # Identify which header columns are oxides present in the database
            global Out_XY
            diag_ox = (@isdefined(Out_XY) && !isempty(Out_XY)) ? Out_XY[1].oxides : String[]
            ox_idx  = [j for j in eachindex(headers) if headers[j] in diag_ox]

            rows = Vector{Dict{String,Any}}()
            for i in axes(raw, 1)[2:end]
                row = Dict{String,Any}()
                row["mineral_name"] = raw[i, findfirst(==("mineral_name"), headers)]
                row["comments"]     = findfirst(==("comments"), headers) !== nothing ? raw[i, findfirst(==("comments"), headers)] : ""

                # Parse and filter oxide values, defaulting missing/non-numeric to 0
                ox_vals = Dict{String,Float64}()
                for j in ox_idx
                    v = tryparse(Float64, raw[i, j])
                    ox_vals[headers[j]] = (v === nothing || isnan(v)) ? 0.0 : v
                end

                # Renormalise to 100 over the database oxides
                total = sum(values(ox_vals))
                if total > 0.0
                    for (k, v) in ox_vals
                        ox_vals[k] = v / total * 100.0
                    end
                end

                for (k, v) in ox_vals
                    row[k] = v
                end
                push!(rows, row)
            end

            n = length(rows)
            ox_kept = isempty(diag_ox) ? "all columns kept (no diagram loaded)" :
                      "kept $(length(ox_idx)) of $(length(diag_ox)) database oxides"
            return rows, "$(n) sample(s) from $(filename) — $(ox_kept)"
        catch e
            return [], "Error: $(sprint(showerror, e))"
        end
    end

    # Phase selection → color picker (read default from color-store or mineral_style)
    callback!(app,
        Output("tb-color-picker", "value"),
        Input("tb-phase-dropdown", "value"),
        State("tb-color-store",    "data"),
        prevent_initial_call = true,
    ) do ph, color_store
        if isnothing(ph)
            return "#808080"
        end
        cs = isnothing(color_store) ? Dict{String,Any}() : Dict{String,Any}(String(k) => v for (k,v) in pairs(color_store))
        if haskey(cs, ph)
            return String(cs[ph])
        end
        return get_phase_color(ph; default="#808080")
    end

    # Color picker change → update color-store
    callback!(app,
        Output("tb-color-store",   "data"),
        Input("tb-color-picker",   "value"),
        State("tb-phase-dropdown", "value"),
        State("tb-color-store",    "data"),
        prevent_initial_call = true,
    ) do color, ph, color_store
        if isnothing(ph) || isnothing(color)
            return isnothing(color_store) ? Dict{String,Any}() : Dict{String,Any}(String(k) => v for (k,v) in pairs(color_store))
        end
        cs = isnothing(color_store) ? Dict{String,Any}() : Dict{String,Any}(String(k) => v for (k,v) in pairs(color_store))
        cs[ph] = color
        return cs
    end

    # Add / Remove / Remove-all formula → formula-store + formula-table
    callback!(app,
        Output("tb-formula-store", "data"),
        Output("tb-formula-table", "data"),
        Input("tb-add-formula-button",        "n_clicks"),
        Input("tb-remove-formula-button",     "n_clicks"),
        Input("tb-remove-all-formula-button", "n_clicks"),
        State("tb-phase-dropdown",   "value"),
        State("tb-formula-input",    "value"),
        State("tb-formula-store",    "data"),
        prevent_initial_call = true,
    ) do _n_add, _n_remove, _, ph, formula, formula_store
        bid = pushed_button(callback_context())
        # Always convert to a plain mutable Vector{Dict{String,Any}} to avoid
        # JSON3.Array element-type coercion errors on push!
        store = Vector{Dict{String,Any}}(
            isnothing(formula_store) ? [] :
            [Dict{String,Any}(String(k) => string(v) for (k,v) in pairs(d)) for d in formula_store]
        )

        if bid == "tb-add-formula-button"
            if !isnothing(ph) && !isnothing(formula) && !isempty(strip(formula))
                push!(store, Dict{String,Any}("phase" => ph, "formula" => strip(formula), "label" => strip(formula)))
            end
        elseif bid == "tb-remove-formula-button"
            if !isempty(store)
                pop!(store)
            end
        elseif bid == "tb-remove-all-formula-button"
            empty!(store)
        end

        rows = [Dict{String,Any}("#" => k, "phase" => d["phase"], "formula" => d["formula"]) for (k,d) in enumerate(store)]
        return store, rows
    end

    # Generate → thermobar canvas figure + open canvas + stats table
    callback!(app,
        Output("tb-canvas-plot",  "figure"),
        Output("tb-canvas-plot",  "config"),
        Output("tb-canvas",       "is_open"),
        Output("tb-stats-table",  "data"),
        Input("tb-generate-button", "n_clicks"),
        State("tb-formula-store",   "data"),
        State("tb-color-store",     "data"),
        State("tb-compunit-dropdown", "value"),
        State("tb-csv-store",       "data"),
        State("gsub-id",            "value"),
        State("refinement-levels",  "value"),
        State("diagram-dropdown",   "value"),
        State("pressure-unit-dropdown", "value"),
        prevent_initial_call = true,
    ) do _n, formula_store, color_store, comp_unit, csv_data, sub, refLvl, diagType, pressure_unit

        global use_GPa
        use_GPa[1] = (pressure_unit == "gpa")

        if isnothing(formula_store) || isempty(formula_store) ||
           isnothing(csv_data)      || isempty(csv_data)
            return plot(Layout(height=600)), PlotConfig(), false, []
        end

        cs = isnothing(color_store) ? Dict{String,Any}() : Dict{String,Any}(String(k) => v for (k,v) in pairs(color_store))
        tb_traces, stats = get_thermobar_contour_plot(formula_store, cs, comp_unit, csv_data, sub, refLvl)

        global data, data_reaction, layout
        Xrange = @isdefined(data) ? data.Xrange : (0.0, 1000.0)
        Yrange = @isdefined(data) ? data.Yrange : (0.0,  100.0)

        # Reaction lines first, thermobar isopleths on top
        reaction_traces = (@isdefined(data_reaction) && !isempty(data_reaction)) ? data_reaction : GenericTrace[]
        traces = vcat(reaction_traces, tb_traces)

        if diagType == "pt"
            xtitle = "Temperature [°C]";  ytitle = "Pressure [kbar]"
        elseif diagType == "px"
            xtitle = "Composition [X]";   ytitle = "Pressure [kbar]"
        elseif diagType == "tx"
            xtitle = "Composition [X]";   ytitle = "Temperature [°C]"
        elseif diagType == "tt"
            xtitle = "Event 2 T [°C]";    ytitle = "Event 1 T [°C]"
        elseif @isdefined(pd_fig_meta) && !isnothing(pd_fig_meta)
            xtitle = pd_fig_meta.xtitle;  ytitle = pd_fig_meta.ytitle
        else
            xtitle = "X";                 ytitle = "Y"
        end

        # Carry over phase-label annotations from the main diagram layout
        ann = (@isdefined(layout) && haskey(layout.fields, :annotations)) ?
              layout[:annotations] : []

        ticks = 4
        frame = get_plot_frame(Xrange, Yrange, ticks)

        canvas_layout = Layout(
            images        = frame,
            font          = attr(size=10),
            height        = 700,
            margin        = attr(autoexpand=false, l=60, r=12, b=55, t=80),
            autosize      = true,
            paper_bgcolor = "white",
            plot_bgcolor  = "white",
            xaxis         = attr(title    = xtitle,
                                 range    = [Xrange[1], Xrange[2]],
                                 tickmode = "linear",
                                 tick0    = Xrange[1],
                                 dtick    = (Xrange[2] - Xrange[1]) / (ticks + 1),
                                 showgrid = false,
                                 zeroline = false),
            yaxis         = attr(title    = ytitle,
                                 range    = [Yrange[1], Yrange[2]],
                                 tickmode = "linear",
                                 tick0    = Yrange[1],
                                 dtick    = (Yrange[2] - Yrange[1]) / (ticks + 1),
                                 showgrid = false,
                                 zeroline = false),
            annotations   = ann,
            showlegend    = true,
        )

        traces, canvas_layout = apply_pressure_display(traces, canvas_layout, diagType)
        fig    = plot(traces, canvas_layout)
        config = PlotConfig(
            toImageButtonOptions = attr(
                name     = "Download as svg",
                format   = "svg",
                filename = "thermobarometric_intersection",
                width    = 700,
                height   = 700,
                scale    = 2.0,
            ).fields
        )

        return fig, config, true, stats
    end

    # ── Auto-range: populate iso-min/step/max from selected isopleth field ──
    callback!(
        app,
        Output("iso-min-id",  "value"),
        Output("iso-step-id", "value"),
        Output("iso-max-id",  "value"),
        Input("phase-dropdown",               "value"),
        Input("ss-dropdown",                  "value"),
        Input("em-dropdown",                  "value"),
        Input("ox-dropdown",                  "value"),
        Input("of-dropdown",                  "value"),
        Input("other-dropdown",               "value"),
        Input("sys-unit-isopleth-dropdown",   "value"),
        Input("rm-exfluid-isopleth-dropdown", "value"),
        Input("fields-dropdown-o18-q-iso",    "value"),
        Input("fields-dropdown-o18-p1-iso",   "value"),
        Input("fields-dropdown-o18-p2-iso",   "value"),
        Input("input-calc-id",                "n_blur"),
        Input("input-calc-id",                "n_submit"),
        Input("input-calc-sf-id",             "n_blur"),
        Input("input-calc-sf-id",             "n_submit"),
        Input("input-calc-ox-id",             "n_blur"),
        Input("input-calc-ox-id",             "n_submit"),
        State("input-calc-id",                "value"),
        State("input-calc-sf-id",             "value"),
        State("input-calc-ox-id",             "value"),
        State("gsub-id",                      "value"),
        State("refinement-levels",            "value"),
        prevent_initial_call = true,
    ) do phase, ss, em, ox, of, ot, sys, rmf, o18_q, o18_p1, o18_p2, _cb, _cs, _sb, _ss, _ob, _os, calc, calc_sf, calc_ox, sub, refLvl

        global Out_XY, data, addedRefinementLvl

        no_range = (no_update(), no_update(), no_update())

        (!@isdefined(Out_XY) || isnothing(Out_XY) || isempty(Out_XY)) && return no_range
        (!@isdefined(data))  && return no_range
        isnothing(phase)     && return no_range

        try
            # dropdowns default to value=0 (Int64) until set — treat any non-string as default
            to_str(x, d) = (isnothing(x) || !(x isa AbstractString)) ? d : String(x)
            ss      = to_str(ss,  "")
            em      = to_str(em,  "")
            ox      = to_str(ox,  "")
            of      = to_str(of,  "G_system")
            ot      = to_str(ot,  "mode")
            sys     = to_str(sys, "mol")
            rmf_b   = something(rmf, false) == true
            calc    = to_str(calc,    " ... ")
            calc_sf = to_str(calc_sf, " ... ")
            calc_ox = to_str(calc_ox, " ... ")

            # Mirror mod determination from add_isopleth_phaseDiagram
            if (phase == "ss" && ot == "mode") || phase == "pp"
                mod = sys == "mol" ? "ph_frac" : (sys == "vol" ? "ph_frac_vol" : "ph_frac_wt")
                em  = ""
            elseif phase == "ss" && ot == "emMode"
                mod = sys == "mol" ? "em_frac" : "em_frac_wt"
            elseif phase == "ss" && ot == "oxComp"
                sys_cor = sys == "vol" ? "wt" : sys
                mod = sys_cor == "mol" ? "ox_comp" : "ox_comp_wt"
            elseif phase == "ss" && ot == "MgNum"
                mod = "ss_MgNum"; em = ""
            elseif phase == "ss" && ot == "calc"
                mod = "ss_calc"; em = ""
            elseif phase == "ss" && ot == "calc_sf"
                mod = "ss_calc_sf"
            elseif phase == "ss" && ot == "calc_ox"
                sys_cor = sys == "vol" ? "wt" : sys
                mod = "ss_calc_ox_" * sys_cor
            elseif phase == "of"
                mod = "of_mod"; em = ""; ss = ""
            elseif phase == "o18"
                o18_available() || return no_range
                mod = "o18"; em = ""; ss = ""; of = "o18:" * o18_fieldname(o18_q, o18_p1, o18_p2)
            else
                return no_range
            end

            oxi          = String.(Out_XY[1].oxides)
            total_refLvl = Int64(something(refLvl, 0)) + addedRefinementLvl
            Xrange_t     = (Float64(data.Xrange[1]), Float64(data.Xrange[2]))
            Yrange_t     = (Float64(data.Yrange[1]), Float64(data.Yrange[2]))

            gridded, _, _ = get_isopleth_map(
                mod, ss, em, ox, of, ot, calc, calc_sf, calc_ox,
                rmf_b, oxi, Out_XY,
                Int64(something(sub, 3)), total_refLvl,
                data, Xrange_t, Yrange_t;
                absent = NaN,
            )

            rng = iso_auto_range(filter(isfinite, Float64.(collect(skipmissing(vec(gridded))))))
            return rng === nothing ? no_range : rng

        catch _
            return no_range
        end
    end

    """
        Save the phase diagram as one clean layered SVG ([`pd_export_svg`](@ref)) into
        the figure directory (`output_dir`), replacing the old "Export all layers",
        which wrote one Kaleido SVG per layer. Writes `<title>_<field>.svg` and, when
        the diagram has numbered assemblages, `<title>_phase_equilibria.txt` beside it
        (the list the small numbers refer to; it is also a text layer in the SVG). The
        layers follow the current toggles: reaction lines (`show-grid`), mesh
        (`show-full-grid`), labels (`show-lbl-id`) and the active isopleths. The status
        line gives the path, size and path count, or why nothing was written. A
        separate callback that reads the figure's globals: it neither rebuilds the
        diagram nor touches its annotations.
    """
    callback!(
        app,
        Output("export-svg-status", "children"),

        Input("export-layers", "n_clicks"),

        State("show-grid",        "value"),
        State("show-full-grid",   "value"),
        State("show-lbl-id",      "value"),
        State("fields-dropdown",  "value"),
        State("smooth-boundaries-switch", "value"),
        State("smooth-boundaries-sigma",  "value"),
        State("pd-pie-list",      "data"),
        State("pd-pie-radius",    "value"),
        State("pd-pie-unit",      "value"),

        prevent_initial_call = true,
    ) do _n, show_reaction, show_mesh, show_labels, fieldname, smooth_bnd, smooth_sigma, pies, pie_radius, pie_unit

        global data, gridded, layout, data_reaction, data_isopleth, iso_show, heat_map_export, assemblage_rows, pd_fig_meta, output_dir

        if !(@isdefined(heat_map_export) && @isdefined(gridded) && @isdefined(layout) && @isdefined(data)) || isnothing(pd_fig_meta)
            return pd_export_status("Compute a phase diagram first."; ok = false)
        end

        try
            geom     = smooth_bnd == true ? pd_get_smooth_geometry(something(smooth_sigma, pd_smooth_sigma_default)) : nothing
            reaction = @isdefined(data_reaction) ? data_reaction : nothing
            fills    = Tuple{Vector{Matrix{Float64}},NTuple{4,Float64}}[]
            if geom !== nothing
                reaction === nothing || (reaction = pd_smooth_reaction(reaction, geom))
                if is_integer_field(fieldname)
                    cols  = pd_fill_colors(heat_map_export, pd_domain_values(geom, gridded))
                    fills = [(p.rings, c) for (p, c) in zip(geom.polys, cols) if c !== nothing]
                end
            end
            parts = pd_figure_parts(data = data, gridded = gridded, heat_map = heat_map_export, layout_g = layout,
                                    reaction = reaction, fills = fills, iso_sigma = geom === nothing ? 0.0 : geom.sigma,
                                    data_isopleth = data_isopleth, iso_show = @isdefined(iso_show) ? iso_show : 0,
                                    assemblage_rows = @isdefined(assemblage_rows) ? assemblage_rows : Dict{String,String}[],
                                    xtitle = pd_fig_meta.xtitle, ytitle = pd_fig_meta.ytitle, diagType = pd_fig_meta.diagType,
                                    show_reaction = show_reaction == "true", show_mesh = show_mesh == "true", show_labels = show_labels == "true",
                                    geotherms = SUBD_TRACES["pd"],
                                    pies = isnothing(pies) ? Any[] : collect(Any, pies), pie_radius = something(pie_radius, 20), pie_unit = something(pie_unit, "wt"))
            mkpath(output_dir[1])
            base = output_dir[1] * replace(isempty(parts.title) ? "phase_diagram" : parts.title, r"[ /\\:]" => "_")
            path = base * "_" * strip(replace(string(fieldname), r"[^A-Za-z0-9]+" => "_"), '_') * ".svg"
            r    = pd_export_svg(parts, path)
            msg  = "Saved $(r.path) ($(round(r.bytes / 1024, digits = 1)) KB, $(r.n_paths) paths)."
            if !isempty(parts.assemblages)
                open(base * "_phase_equilibria.txt", "w") do io
                    write(io, join(parts.assemblages, "\n") * "\n")
                end
                msg *= " Assemblage list: $(base)_phase_equilibria.txt."
            end
            return pd_export_status(msg; ok = true)
        catch e
            return pd_export_status("Export failed: " * sprint(showerror, e); ok = false)
        end
    end

    callback!(
        """
        function(v) {
            var gd = document.querySelector('#phase-diagram .js-plotly-plot');
            if (!gd || !gd.data) { return window.dash_clientside.no_update; }
            var idx = [];
            gd.data.forEach(function(t, i) { if (t.meta === 'pd-reaction') { idx.push(i); } });
            if (idx.length) { Plotly.restyle(gd, {visible: v === 'true'}, idx); }
            return v;
        }
        """,
        app,
        Output("pd-cs-grid",    "data"),
        Input("show-grid",      "value"),
        prevent_initial_call = true,
    )

    callback!(
        """
        function(v) {
            var on = v === 'true';
            var el = document.getElementById('show-text-list-id');
            if (el) { el.style.display = on ? 'block' : 'none'; }
            var gd = document.querySelector('#phase-diagram .js-plotly-plot');
            if (!gd || !gd.layout || !gd.layout.annotations) { return window.dash_clientside.no_update; }
            var upd = {};
            gd.layout.annotations.forEach(function(a, i) { if (a.name === 'pd-label') { upd['annotations[' + i + '].visible'] = on; } });
            if (Object.keys(upd).length) { Plotly.relayout(gd, upd); }
            return v;
        }
        """,
        app,
        Output("pd-cs-lbl",     "data"),
        Input("show-lbl-id",    "value"),
        prevent_initial_call = true,
    )

    callback!(
        """
        function(v) {
            var on = v === 'true';
            var gd = document.querySelector('#phase-diagram .js-plotly-plot');
            if (!gd || !gd.layout || !gd.layout.annotations) { return window.dash_clientside.no_update; }
            var upd = {};
            gd.layout.annotations.forEach(function(a, i) {
                if (a.name !== 'pd-label' || !a.text) { return; }
                upd['annotations[' + i + '].bgcolor']   = on ? '$(PD_LABEL_BG)' : null;
                upd['annotations[' + i + '].borderpad'] = on ? 1 : null;
            });
            if (Object.keys(upd).length) { Plotly.relayout(gd, upd); }
            return v;
        }
        """,
        app,
        Output("pd-cs-lbl-bg",  "data"),
        Input("lbl-bg-id",      "value"),
        prevent_initial_call = true,
    )

    callback!(
        app,
        Output("style-canvas-pd",           "is_open"),
        Input("style-canvas-button-pd",     "n_clicks"),
        State("style-canvas-pd",            "is_open"),
        prevent_initial_call = true,
    ) do n, is_open
        return n > 0 ? is_open != true && is_open != 1 : is_open
    end

    callback!(
        app,
        Output("colorpicker-mineral-id-pd", "value"),
        Input("color-table-change-id-pd",   "selected_cells"),
        State("color-table-id-pd",          "data"),
        prevent_initial_call = true,
    ) do selected, data
        (isnothing(selected) || isempty(selected)) && return no_update()
        return data[selected[1]["row"] + 1]["Color"]
    end

    callback!(
        app,
        Output("color-table-id-pd",         "data"),
        Output("color-table-id-pd",         "style_data_conditional"),
        Output("color-table-change-id-pd",  "data"),
        Output("colorpicker-mineral-id-pd", "style"),
        Input("style-canvas-pd",            "is_open"),
        Input("colorpicker-mineral-id-pd",  "value"),
        State("color-table-change-id-pd",   "selected_cells"),
        State("color-table-id-pd",          "data"),
        State("color-table-id-pd",          "style_data_conditional"),
        prevent_initial_call = true,
    ) do is_open, color, selected, data, style
        bid = pushed_button( callback_context() )
        if bid == "colorpicker-mineral-id-pd"
            (isnothing(selected) || isempty(selected) || isnothing(data)) && return no_update(), no_update(), no_update(), no_update()
            k       = selected[1]["row"] + 1
            dataout = [Dict(String(c) => v for (c, v) in pairs(r)) for r in data]
            styleout = [Dict(String(c) => v for (c, v) in pairs(r)) for r in something(style, [])]
            dataout[k]["Color"] = color
            k <= length(styleout) && (styleout[k]["background-color"] = color)
            get!(AppData.mineral_style[1], dataout[k]["LegacyMineral"], Any["grey", "solid", 1])[1] = color
            return dataout, styleout, no_update(), no_update()
        end
        is_open == true || return no_update(), no_update(), no_update(), no_update()
        phases = @isdefined(phase_infos) && !isnothing(phase_infos) ? vcat(phase_infos.act_ss, phase_infos.act_pp) : String[]
        phases = isempty(phases) ? sort(collect(keys(AppData.mineral_style[1]))) : String.(phases)
        dataout  = [Dict("Mineral" => display_ph_name(ph), "LegacyMineral" => ph, "Color" => get_phase_color(ph)) for ph in phases]
        styleout = [Dict("if" => Dict("row_index" => i - 1, "column_id" => "Color"), "background-color" => r["Color"]) for (i, r) in enumerate(dataout)]
        return dataout, styleout, [Dict("Change" => " ") for _ in dataout], Dict("height" => "$((24 + 6) * (length(dataout) + 1))px", "padding" => "0", "margin" => "0")
    end

    callback!(
        app,
        Output("color-style-save-pd",       "is_open"),
        Input("save-color-style-pd",        "n_clicks"),
        prevent_initial_call = true,
    ) do n_clicks
        n_clicks == 0 && return false
        save_style(AppData.mineral_style[1])
        return true
    end

    callback!(
        app,
        Output("pd-pie-mode",   "data"),
        Output("pd-pie-record", "color"),
        Input("pd-pie-record",  "n_clicks"),
        Input("pd-pie-stop",    "n_clicks"),
        prevent_initial_call = true,
    ) do _, _
        on = pushed_button( callback_context() ) == "pd-pie-record"
        return on, on ? "danger" : "light"
    end

    callback!(
        app,
        Output("pd-pie-list",           "data"),
        Input("phase-diagram",          "clickData"),
        Input("pd-pie-clear",           "n_clicks"),
        Input("compute-button",         "value"),
        Input("load-state-id",          "value"),
        Input("style-canvas-pd",        "is_open"),
        State("pd-pie-mode",            "data"),
        State("pd-pie-list",            "data"),
        State("diagram-dropdown",       "value"),
        State("database-dropdown",      "value"),
        State("pressure-unit-dropdown", "value"),
        prevent_initial_call = true,
    ) do click_info, _, _, _, canvas_open, recording, pies, diagType, dtb, punit

        bid = pushed_button( callback_context() )
        if bid == "style-canvas-pd"
            (canvas_open == true || canvas_open == 1 || isnothing(pies) || isempty(pies)) && return no_update()
            return pd_minipie_recolor(pies)
        end
        bid == "phase-diagram" || return Any[]
        recording == true || return no_update()

        pid = pd_click_point_id(click_info)
        (pid === nothing || !@isdefined(Out_XY) || pid > length(Out_XY)) && return no_update()

        p   = click_info[:points][1]
        (get(p, :x, nothing) isa Real && get(p, :y, nothing) isa Real) || return no_update()
        dt  = isnothing(pd_fig_meta) ? diagram_type_2d(diagType) : pd_fig_meta.diagType
        py  = pressure_on_y_axis(dt)
        y   = py && punit == "gpa" ? Float64(p[:y]) * 10.0 : Float64(p[:y])

        entry = pd_minipie_entry(Out_XY[pid], Float64(p[:x]), y, py, dtb)
        return vcat(isnothing(pies) ? Any[] : collect(Any, pies), [entry])
    end

    callback!(
        """
        function(pies, radius, fig, punit, unit) {
            var host = document.getElementById('phase-diagram');
            if (!host) { return window.dash_clientside.no_update; }
            host.__pdPieState = {pies: pies || [], r: radius || 20, gpa: punit === 'gpa', unit: unit || 'wt'};
            var isPie = function(t) { return t.meta && t.meta.kind === 'pd-minipie'; };
            var build = function(gd) {
                var st = host.__pdPieState, xa = gd._fullLayout.xaxis, ya = gd._fullLayout.yaxis, out = [];
                if (!xa || !ya || !xa.l2p || !ya.l2p) { return out; }
                st.pies.forEach(function(p, k) {
                    var y   = (p.py && st.gpa) ? p.y / 10 : p.y;
                    var cx  = xa.l2p(p.x), cy = ya.l2p(y);
                    if (!isFinite(cx) || !isFinite(cy)) { return; }
                    var vals = st.unit === 'mol' ? (p.values_mol || p.values) : (st.unit === 'vol' ? (p.values_vol || p.values) : p.values);
                    var ulab = st.unit === 'mol' ? ' mol%' : (st.unit === 'vol' ? ' vol%' : ' wt%');
                    var tot = vals.reduce(function(a, b) { return a + b; }, 0);
                    if (!(tot > 0)) { return; }
                    var a0 = 0;
                    vals.forEach(function(v, i) {
                        var a1 = a0 + 2 * Math.PI * v / tot;
                        var n  = Math.max(2, Math.ceil(72 * (a1 - a0) / (2 * Math.PI)));
                        var xs = [], ys = [];
                        if (vals.length > 1) { xs.push(p.x); ys.push(y); }
                        for (var j = 0; j <= n; j++) {
                            var a = a0 + (a1 - a0) * j / n;
                            xs.push(xa.p2l(cx + st.r * Math.sin(a)));
                            ys.push(ya.p2l(cy - st.r * Math.cos(a)));
                        }
                        if (vals.length > 1) { xs.push(p.x); ys.push(y); }
                        out.push({type: 'scatter', mode: 'lines', x: xs, y: ys, fill: 'toself', fillcolor: p.colors[i],
                                  line: {color: '#000000', width: 0.6}, hoveron: 'fills', hoverinfo: 'name',
                                  name: p.labels[i] + ' ' + v.toFixed(1) + ulab, hoverlabel: {namelength: -1},
                                  showlegend: false, meta: {kind: 'pd-minipie', pie: k}});
                        a0 = a1;
                    });
                });
                return out;
            };
            var isLeg = function(o) { return o && o.name === 'pd-pie-legend'; };
            var legendItems = function() {
                var seen = {}, items = [];
                host.__pdPieState.pies.forEach(function(p) {
                    p.phases.forEach(function(ph, i) {
                        var it = {ph: ph, name: (p.names || p.labels)[i], color: p.colors[i], rank: p.ranks ? p.ranks[i] : 1e6};
                        if (seen[ph] === undefined) { seen[ph] = items.length; items.push(it); } else { items[seen[ph]] = it; }
                    });
                });
                items.sort(function(a, b) { return a.rank - b.rank || (a.ph < b.ph ? -1 : 1); });
                return items;
            };
            var legendUpdate = function(gd) {
                var fl = gd._fullLayout;
                if (!fl || !fl._size) { return; }
                var items = legendItems();
                var gr    = gd.getBoundingClientRect();
                var pbot  = gr.top + fl._size.t + fl._size.h;
                var xt    = gd.querySelector('.g-xtitle');
                var a     = xt ? xt.getBoundingClientRect().bottom - pbot : 45;
                var b     = Infinity;
                (fl.annotations || []).forEach(function(an, k) {
                    if (an.xref !== 'paper' || an.yref !== 'paper' || an.y !== 0 || !(an.yshift < -100)) { return; }
                    var el = gd.querySelector('.annotation[data-index="' + k + '"]');
                    if (el) { b = Math.min(b, el.getBoundingClientRect().top - pbot); }
                });
                if (!isFinite(b) || b - a < 30) { b = a + 40; }
                var tpx   = Math.round(a + Math.max(2, (b - a - 28) / 2)) + 12;
                var sig   = items.map(function(it) { return it.ph + ':' + it.color + ':' + it.name; }).join('|') + '@' + fl._size.w + 'x' + fl._size.h + ':' + tpx;
                var anns  = (gd.layout.annotations || []), shps = (gd.layout.shapes || []);
                var shown = anns.some(isLeg);
                if (sig === gd.__pdLegSig && shown === (items.length > 0)) { return; }
                gd.__pdLegSig = sig;
                var newAnn = anns.filter(function(a) { return !isLeg(a); });
                var newShp = shps.filter(function(a) { return !isLeg(a); });
                if (items.length) {
                    var w = fl._size.w, h = fl._size.h;
                    var bw = Math.min(50, w / items.length), x0 = (w - bw * items.length) / 2;
                    var top = -tpx / h, bot = -(tpx + 15) / h;
                    items.forEach(function(it, i) {
                        var a = (x0 + i * bw) / w, b = (x0 + (i + 1) * bw) / w;
                        newShp.push({type: 'rect', xref: 'paper', yref: 'paper', x0: a, x1: b, y0: bot, y1: top,
                                     line: {color: '#000000', width: 1}, fillcolor: it.color, layer: 'above', name: 'pd-pie-legend'});
                        newAnn.push({xref: 'paper', yref: 'paper', x: (a + b) / 2, y: top, xanchor: 'center', yanchor: 'bottom',
                                     text: it.name, showarrow: false, font: {size: 10, color: '#000000'}, name: 'pd-pie-legend'});
                    });
                }
                Plotly.relayout(gd, {annotations: newAnn, shapes: newShp});
            };
            var redraw = function(gd) {
                if (!gd || !gd.data || !gd._fullLayout) { return; }
                var idx = [];
                gd.data.forEach(function(t, i) { if (isPie(t)) { idx.push(i); } });
                var traces = build(gd);
                gd.__pdPieN = traces.length;
                if (idx.length) { Plotly.deleteTraces(gd, idx); }
                if (traces.length) { Plotly.addTraces(gd, traces); }
                legendUpdate(gd);
            };
            var gd = host.querySelector('.js-plotly-plot');
            if (!gd || !gd.on) { return window.dash_clientside.no_update; }
            if (!gd.__pdPieHook) {
                gd.__pdPieHook = true;
                gd.on('plotly_relayout', function() { redraw(gd); });
                gd.on('plotly_afterplot', function() {
                    var n = gd.data ? gd.data.filter(isPie).length : 0;
                    var legShown = (gd.layout.annotations || []).some(isLeg);
                    if (n !== (gd.__pdPieN || 0) || (n === 0 && host.__pdPieState.pies.length) || legShown !== (host.__pdPieState.pies.length > 0)) { redraw(gd); }
                });
            }
            redraw(gd);
            return window.dash_clientside.no_update;
        }
        """,
        app,
        Output("pd-pie-cs",              "data"),
        Input("pd-pie-list",             "data"),
        Input("pd-pie-radius",           "value"),
        Input("phase-diagram",           "figure"),
        Input("pressure-unit-dropdown",  "value"),
        Input("pd-pie-unit",             "value"),
        prevent_initial_call = true,
    )

    callback!(
        """
        function(f1, f2) {
            var install = function() {
                ['phase-diagram', 'phase-diagram-te'].forEach(function(id) {
                    var gd = document.querySelector('#' + id + ' .js-plotly-plot');
                    if (!gd || !gd.on || gd.__pdTip) { return; }
                    gd.__pdTip = true;
                    var tip = document.createElement('div');
                    tip.style.cssText = 'position:fixed;pointer-events:none;display:none;z-index:2000;background:#566573;' +
                        'border:1px solid #f8f9f9;color:#ffffff;font:13px "Open Sans",verdana,arial,sans-serif;' +
                        'padding:3px 6px;border-radius:3px;white-space:nowrap;';
                    document.body.appendChild(tip);
                    gd.on('plotly_hover', function(ev) {
                        var p = ev.points && ev.points[0];
                        var m = p && p.data && p.data.meta;
                        if (!m || m.kind !== 'pd-hover' || !p.z) { tip.style.display = 'none'; return; }
                        var a = m.pa[p.z - 1];
                        tip.textContent = '#' + p.z + '# ' + (a ? m.asm[a - 1] : '');
                        tip.style.left = (ev.event.clientX + 14) + 'px';
                        tip.style.top  = (ev.event.clientY + 14) + 'px';
                        tip.style.display = 'block';
                    });
                    gd.on('plotly_unhover', function() { tip.style.display = 'none'; });
                });
            };
            install();
            setTimeout(install, 500);
            return window.dash_clientside.no_update;
        }
        """,
        app,
        Output("pd-cs-hover",       "data"),
        Input("phase-diagram",      "figure"),
        Input("phase-diagram-te",   "figure"),
        prevent_initial_call = true,
    )

    register_svg_exports!(app, PD_CLASSIFICATION_SVG_EXPORTS)

    callback!(
        app,
        Output("show-o18-pd-id",    "style"),
        Input("fields-dropdown",    "value"),
        prevent_initial_call = false,
    ) do field
        return field == "o18" ? Dict("display" => "block") : Dict("display" => "none")
    end

    for suffix in ("-pd", "-iso")
        callback!(
            app,
            Output("o18-p1-row" * suffix,           "style"),
            Output("o18-p2-row" * suffix,           "style"),
            Input("fields-dropdown-o18-q" * suffix, "value"),
            prevent_initial_call = false,
        ) do q
            return o18_phase_rows_style(q)
        end
    end

    callback!(
        app,
        Output("o18-iso-id",        "style"),
        Input("phase-dropdown",     "value"),
        prevent_initial_call = false,
    ) do phase
        return phase == "o18" ? Dict("display" => "block") : Dict("display" => "none")
    end

    callback!(
        app,
        Output("fields-dropdown-o18-p1-pd",     "options"),
        Output("fields-dropdown-o18-p2-pd",     "options"),
        Output("fields-dropdown-o18-p1-iso",    "options"),
        Output("fields-dropdown-o18-p2-iso",    "options"),
        Output("fields-dropdown-o18-p1-pd",     "value"),
        Output("fields-dropdown-o18-p2-pd",     "value"),
        Output("fields-dropdown-o18-p1-iso",    "value"),
        Output("fields-dropdown-o18-p2-iso",    "value"),
        Input("trigger-update-ss-list",         "value"),
        Input("load-state-id",                  "value"),
        Input("mineral-naming-dropdown",        "value"),
        State("fields-dropdown-o18-p1-pd",      "value"),
        State("fields-dropdown-o18-p2-pd",      "value"),
        State("fields-dropdown-o18-p1-iso",     "value"),
        State("fields-dropdown-o18-p2-iso",     "value"),

        prevent_initial_call = true,
    ) do _update, _load, warr_naming, p1, p2, p1_iso, p2_iso

        global use_warr_names
        use_warr_names[1] = (warr_naming == "warr")

        opts    = o18_phase_options()
        isempty(opts) && return ntuple(_ -> no_update(), 8)
        names   = [o["value"] for o in opts]
        d1, d2  = o18_default_phases()
        keep(v, d) = v in names ? v : d

        return opts, opts, opts, opts, keep(p1, d1), keep(p2, d2), keep(p1_iso, d1), keep(p2_iso, d2)
    end

    callback!(
        app,
        Output("o18-point-section-id",      "style"     ),
        Output("o18-point-pd",              "figure"    ),
        Output("o18-point-info-pd",         "children"  ),
        Input("phase-diagram",              "clickData" ),
        Input("mineral-naming-dropdown",    "value"     ),

        prevent_initial_call = true,
    ) do click_info, warr_naming

        global use_warr_names
        use_warr_names[1] = (warr_naming == "warr")

        hidden  = Dict("display" => "none")
        o18_available() || return hidden, no_update(), no_update()
        pid     = pd_click_point_id(click_info)
        (pid === nothing || pid > length(Out_O18_XY)) && return no_update(), no_update(), no_update()

        return Dict("display" => "block"), get_o18_point_plot(pid), get_o18_point_info(pid)
    end

    return app

end