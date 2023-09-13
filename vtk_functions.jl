using Dash, DashVtk, DashHtmlComponents, Delaunay

function get_mesh_data(mesh)
    nk      = size(mesh.points,1);
    nl      = size(mesh.simplices,1);
    points  = Vector{Float64}(undef, nk*3);
    lines   = Vector{Int64}(undef, nl*4);
    polys   = Vector{Int64}(undef, nl*4);
    vertc   = Vector{Float64}(undef, nk*3);
    vertbw  = zeros(nk*3);

    k=1;
    for i=1:nk
        vertc[i]    = mesh.points[i,1];
        points[k]   = mesh.points[i,1];
        points[k+1] = mesh.points[i,2];
        points[k+2] = 0.0; 
        k += 3;
    end

    l=1;m=1;
    for i=1:nl
        lines[l]    = 3;        #number of points
        lines[l+1]  = mesh.simplices[i,1]-1; 
        lines[l+2]  = mesh.simplices[i,2]-1;
        lines[l+3]  = mesh.simplices[i,3]-1;
        l += 4;

    end

    polys          .= lines;

    return points, lines, polys, vertc, vertbw
end
