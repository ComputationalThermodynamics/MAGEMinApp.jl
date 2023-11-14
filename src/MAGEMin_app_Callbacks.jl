function MAGEMin_app_Callbacks(app)


    #save all to file
    callback!(
        app,
        Output("export-to-lamem-text", "is_open"),
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
        prevent_initial_call=true,
    ) do n_clicks, dtb, dtype, sub, refLvl,
            tmin, tmax, pmin, pmax, bulk1

        if dtype == "pt"

            Xrange          = (Float64(tmin),Float64(tmax))
            Yrange          = (Float64(pmin),Float64(pmax))

            testName = replace(db[(db.db .== dtb), :].title[1], " " => "_")
            fileout = testName*".in"
            file    = save_rho_for_LaMEM(   dtb,
                                            sub,
                                            refLvl,
                                            Xrange,
                                            Yrange,
                                            bulk1 )
            output  = Dict("content" => file,"filename" => fileout)

            print(file)
        else

        end

        
        # if fname != "... filename ..."
        #     datab   = "_"*dtb
        #     fileout = fname*datab*".txt"
        #     file    = save_all_to_file(dtb)            #point_id is defined as global variable in clickData callback
        #     output  = Dict("content" => file,"filename" => fileout)
            
        #     return output, "Successfully saved all points information"
        # else
        #     return nothing, "Provide a valid filename (without extension)"
        # end

        return "saved"

    end

    return(app)
end