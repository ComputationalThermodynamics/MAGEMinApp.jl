using MAGEMin_C.Threads, ProgressMeter


mutable struct ComputationalProgress{_T,_I}
    title::String
    stage::String
    total_points::_I
    current_point::_I
    refinement_level::_I
    total_levels::_I
    tinit::_T
    tlast::_T
end

ComputationalProgress() = ComputationalProgress("","",0,0,0,0,time(),time())


function update_progress(pt, n_pts, tlast) 
    global CompProgress
    CompProgress.current_point = pt; 
    CompProgress.total_points = n_pts; 
    CompProgress.tlast = tlast; 
    return nothing
end
