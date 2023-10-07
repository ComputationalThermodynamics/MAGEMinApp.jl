using PlotlyJS, Delaunay, BenchmarkTools


function mesh_fct(np)
    c       = rand(np, 2);
    mesh    = delaunay(c);
    mcat    = cat(mesh.simplices,mesh.simplices[:,1],dims=2);
    n       = size(mesh.simplices,1);
    data    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,n);
    for i=1:n
        x = mesh.points[mcat[i,:],1];
        y = mesh.points[mcat[i,:],2];
        data[i]=scatter(;x=x, y=y, fill="toself", fillcolor="#d6f5d6", line_color="#000000", line_width=0.5);
    end

    return data;
end