function MAGEMin_app_Callbacks(app)


    #save all to file
    callback!(
        app,
        Output("download-lamem-in", "data"),
        Output("export-to-lamem-text", "is_open"),
        Output("export-to-lamem-text-failed", "is_open"),
        Input("export-to-lamem",    "n_clicks"),
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
        Output("download-figure", "data"),
        Input("export-figure",    "n_clicks"),
        prevent_initial_call=true,
    ) do n_clicks
        # PlotlyKaleido.start()

        # PlotlyKaleido.savefig(PlotlyJS.plot(data_plot,layout), "plot1.png")
        # PlotlyKaleido.kill_kaleido()
        # save("test.png", fig)
        # savefig(    fig, 
        #             "Phase_diagram.png",
        #             format = "png"   )

    end



    return(app)
end