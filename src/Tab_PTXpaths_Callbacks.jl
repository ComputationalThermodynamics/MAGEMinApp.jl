function Tab_PTXpaths_Callbacks(app)



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
        # prevent_initial_call = true,
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
    
        layout  = Layout(
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
        )

        fig = plot(df, x=:x, y=:y, layout)
    
        return fig
    end


    callback!(
        app,
        Output("output-data-uploadn-ptx", "is_open"),
        Output("output-data-uploadn-failed-ptx", "is_open"),
        Input("upload-bulk-ptx", "contents"),
        State("upload-bulk-ptx", "filename"),
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
                                    format   = "svg", # one of png, svg, jpeg, webp
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
            tas, layout = get_TAS_diagram(phases)
            figTAS      = plot( tas, layout)
        else
            figTAS      =  plot(Layout( height= 360 ))
        end

        configTAS   = PlotConfig(      toImageButtonOptions  = attr(     name     = "Download as svg",
                                        format   = "svg", # one of png, svg, jpeg, webp
                                        filename = "TAS_diagram_"*replace(title, " " => "_"),
                                        width       = 760,
                                        height      = 480,
                                        scale    =  2.0,       ).fields)

        return figTAS, configTAS
    end


    """
        Callback to compute and display PTX path
    """
    callback!(
        app,
        Output("ptx-plot",              "figure"),
        Output("ptx-plot",              "config"),
        Output("phase-selector-id",     "options"),
        
        Input("compute-path-button",    "n_clicks"),
        Input("sys-unit-ptx",           "value"),

        State("phase-selector-id",      "options"),
        State("n-steps-id-ptx",         "value"),
        State("ptx-table",              "data"),
        State("mode-dropdown-ptx",      "value"),
        State("database-dropdown-ptx",  "value"),
        State("buffer-dropdown-ptx",    "value"),
        State("solver-dropdown-ptx",    "value"),    
        State("verbose-dropdown-ptx",   "value"),   
        State("table-bulk-rock-ptx",    "data"),  
        State("buffer-1-mul-id-ptx",    "value"),  

        State("mb-cpx-switch-ptx",      "value"),           # false,true -> 0,1
        State("limit-ca-opx-id-ptx",    "value"),           # ON,OFF -> 0,1
        State("ca-opx-val-id-ptx",      "value"),           # 0.0-1.0 -> 0,1
        State("test-dropdown-ptx",      "value"),
        State("sys-unit-ptx",           "value"),

        State("connectivity-id",        "value"),
        State("residual-id",            "value"),
        
    
        prevent_initial_call = true,

        ) do    compute,    upsys,      phase_list, nsteps,     PTdata,     mode,
                dtb,        bufferType, solver,
                verbose,    bulk,       bufferN,
                cpx,        limOpx,     limOpxVal,  test,   sysunit,
                nCon,       nRes  


        bid                     = pushed_button( callback_context() )    # get which button has been pushed

        title = db[(db.db .== dtb), :].title[test+1]

        if bid == "compute-path-button"

            global Out_PTX, ph_names, layout, data_plot, fracEvol

            bufferN                 = Float64(bufferN)               # convert buffer_n to float
            bulk_ini, bulk_ini, oxi = get_bulkrock_prop(bulk, bulk)  

            compute_new_PTXpath(    nsteps,     PTdata,     mode,       bulk_ini,   oxi,
                                    dtb,        bufferType, solver,
                                    verbose,    bulk,       bufferN,
                                    cpx,        limOpx,     limOpxVal,
                                    nCon,       nRes                                  )


            layout                  = initialize_layout(title,sysunit)

            data_plot, phase_list   = get_data_plot(sysunit)

            figPTX                  = plot(data_plot,layout)

        elseif bid == "sys-unit-ptx"
            data_plot, phase_list   = get_data_plot(sysunit)
            ytitle                  = "Phase fraction ["*sysunit*"%]"
            
            layout[:yaxis_title]    = ytitle

            figPTX                  = plot(data_plot,layout)

        else
            figPTX                  = plot(    Layout( height= 320 ))
        end

        configPTX   = PlotConfig(   toImageButtonOptions  = attr(     name     = "Download as svg",
                                    format   = "svg", # one of png, svg, jpeg, webp
                                    filename =  "path_1_"*replace(title, " " => "_"),
                                    height   =  360,
                                    width    =  960,
                                    scale    =  2.0,       ).fields)

        return figPTX, configPTX, phase_list
    end


    # callback to display ca-orthopyroxene limiter
    callback!(
        app,
        Output("switch-opx-id-ptx", "style"),
        Input("database-dropdown-ptx", "value"),
    ) do value
        # global db
        if value == "ig"
            style  = Dict("display" => "block")
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
        Output("switch-cpx-id-ptx",     "style"),
        Input("database-dropdown-ptx",  "value"),
    ) do value

        if value == "mb"
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
        Output("buffer-1-id-ptx", "style"),
        Input("buffer-dropdown-ptx", "value"),
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
        Output("table-bulk-rock-ptx","data"),
        Output("test-dropdown-ptx","options"),
        Output("test-dropdown-ptx","value"),
        Output("database-caption-ptx","value"),
        Input("test-dropdown-ptx","value"),
        Input("database-dropdown-ptx","value"),
        Input("output-data-uploadn-ptx", "is_open"),        # this listens for changes and updated the list
        prevent_initial_call=true,
    ) do test, dtb, update

        # catching up some special cases
        if test > length(db[(db.db .== dtb), :].test) - 1 
            t = 0
        else
            t = test
        end

        data        =   [Dict(  "oxide"         => db[(db.db .== dtb) .& (db.test .== t), :].oxide[1][i],
                                "mol_fraction"  => db[(db.db .== dtb) .& (db.test .== t), :].frac[1][i])
                                    for i=1:length(db[(db.db .== dtb) .& (db.test .== t), :].oxide[1]) ]


        opts        =  [Dict(   "label" => db[(db.db .== dtb), :].title[i],
                                "value" => db[(db.db .== dtb), :].test[i]  )
                                    for i=1:length(db[(db.db .== dtb), :].test)]

        cap         = dba[(dba.acronym .== dtb) , :].database[1]      
        
        val         = t
        return data, opts, val, cap                  
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

    callback!(app,
        Output("ptx-table", "data"),
        Input("add-row-button", "n_clicks"),
        State("ptx-table", "data"),
        State("ptx-table", "columns"),
        prevent_initial_call = true,
        ) do n_clicks, data, columns

        dataout = copy(data)

        if n_clicks > 0
            add = Dict(Symbol("col-1") => 7.5, Symbol("col-2") => 1000)
            push!(dataout,add)
        end

        return dataout
    end

    return app
end