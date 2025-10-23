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

using ProgressMeter

# Callback that prints progress information to the user 
function Progress_Callbacks(app)
    # Update the progress information (when a simulation is running)
    callback!(
        app,
        Output( "pd-progress-bar",               "figure"       ),
        Input(  "interval-simulation_progress",  "n_intervals"  ),
        Input(  "compute-path-button-isoS",      "n_clicks"     ),
        Input(  "compute-path-button",           "n_clicks"     ),
        
        prevent_initial_call = true,         # don't run at startup
    ) do n_progress, but1, but2

        bid     = pushed_button( callback_context() ) 

        if bid != "interval-simulation_progress"
            return progress_bar_fig()
        else
            global CompProgress
            
            lev     = CompProgress.refinement_level
            nlev    = CompProgress.total_levels
        
            p1, p2, p3 = "", "", ""    
            if lev>0 && nlev>0
                p1 = " $(lev)/$(nlev)"
            end

            if CompProgress.total_points > 0

                perc            = round(CompProgress.current_point/CompProgress.total_points*100)
                
                p2              = "Point $(CompProgress.current_point)/$(CompProgress.total_points) | $perc%"
                t_s             = round(CompProgress.tlast-CompProgress.tinit, digits=2)    
                t_left          = t_s/CompProgress.current_point*(CompProgress.total_points-CompProgress.current_point)
                r_str           = ProgressMeter.durationstring(t_s)    
                eta_str         = ProgressMeter.durationstring(t_left)
                p3              = "Time: $r_str | ETA: $eta_str"

                top = "$(CompProgress.title): $(CompProgress.stage) $p1"
                bot = "$p3 | $p2"

                fig     = progress_bar_fig(percent=perc, an1=top, an2=bot)
            else
                fig     = progress_bar_fig()
            end
            return fig
        end
    end


    return app
end
