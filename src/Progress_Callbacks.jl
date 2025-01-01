using ProgressMeter

# Callback that prints progress information to the user 
function Progress_Callbacks(app)

    # Update the progress information (when a simulation is running)
    callback!(
        app,
        Output( "simulation_progress",           "children"     ),
        Input(  "interval-simulation_progress",  "n_intervals"  ),

    prevent_initial_call = true,         # don't run at startup
    ) do n_progress
        global CompProgress
        
        lev     = CompProgress.refinement_level
        nlev    = CompProgress.total_levels
    
        # progress_info = "\n**$(CompProgress.title)**\n"
        # progress_info *= "\n $(CompProgress.stage)"
        p0, p1, p2, p3 = " ", "", "", ""    
        if lev>0 && nlev>0
            p1 = " $(lev)/$(nlev)"
        end
        
        if CompProgress.total_points > 0
            #=
            length_bar = 10
            i_perc  = round(Int,perc/(100/length_bar))
            bar_str  = ["=" for i=1:i_perc]
            bar_str2 = ["*" for i=i_perc+1:length_bar]
            bar_str  = join(bar_str)*join(bar_str2)
           
            #bar_str = ProgressMeter.barstring(20,perc, barglyphs=ProgressMeter.defaultglyphs)
            
            bar_str = "\n|"*bar_str*"|\n"
            bar_str = replace(bar_str," "=>"_")
            bar_str = replace(bar_str,"█"=>"=")
            
           # @show bar_str
            progress_info *= bar_str
            =#
            perc            = round(CompProgress.current_point/CompProgress.total_points*100)
            
            p2              = "Point $(CompProgress.current_point)/$(CompProgress.total_points) | $perc%"
            t_s             = round(CompProgress.tlast-CompProgress.tinit, digits=2)    
            t_left          = t_s/CompProgress.current_point*(CompProgress.total_points-CompProgress.current_point)
            r_str           = ProgressMeter.durationstring(t_s)    
            eta_str         = ProgressMeter.durationstring(t_left)
            p3              = "Time: $r_str | ETA: $eta_str"
        end

        # note that two spaces are added at the end of each line to ensure that the line break is taken into account
        progress_info = """
        **$(CompProgress.title)**  
        $(CompProgress.stage) $p1  
        $p2  
        $p3
        """


        return progress_info
    end


    return app
end
