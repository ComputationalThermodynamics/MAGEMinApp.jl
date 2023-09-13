using PlotlyJS, Delaunay, BenchmarkTools


function mesh_fct(np)
    c       = rand(np, 2);
    c[end-3:end,:] = [0. 0.; 0. 1.; 1. 1.; 1. 0.]

    mesh    = delaunay(c);
    mcat    = cat(mesh.simplices,mesh.simplices[:,1],dims=2);
    n       = size(mesh.simplices,1);
    data    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,n);
    for i=1:n
        x = mesh.points[mcat[i,:],1];
        y = mesh.points[mcat[i,:],2];
        data[i]=scatter(;   x           = x,
                            y           = y,
                            fill        = "toself",
                            fillcolor   = "#d6f5d6",
                            line_color  = "#000000",
                            line_width  = 0.5,
                            marker      = attr( color   = "LightSkyBlue",
                                                size    = 4,
                                                line    = attr(width=0.5, color="#000000")),
                            hoverinfo   = "skip",
                            );
    end

    return data;
end        