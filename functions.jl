"""
    function to parce bulk-rock composition file
"""
function bulk_file_to_db(datain)

    global db;
    
    db = db[(db.bulk .== "predefined"), :];

    for i=2:size(datain,1)
        bulk   		= "custom";

        idx 		= findall(datain[1,:] .== "title")[1];
        title   	= datain[i,idx];

        idx 		= findall(datain[1,:] .== "comments")[1];
        comments   	= datain[i,idx];

        idx 		= findall(datain[1,:] .== "db")[1];
        dbin   		= datain[i,idx];

        test 		= length(db[(db.db .== dbin), :].test);

        idx 		= findall(datain[1,:] .== "sysUnit")[1];
        sysUnit   	= datain[i,idx];

        idx 		= findall(datain[1,:] .== "oxide")[1];
        oxide   	= rsplit(datain[i,idx],",");
        oxide 		= strip.(convert.(String,oxide));
        oxide 		= replace.(oxide,r"\]"=>"");
        oxide 		= replace.(oxide,r"\["=>"");

        idx 		= findall(datain[1,:] .== "frac")[1];
        frac   		= rsplit(datain[i,idx],",");
        frac 		= strip.(convert.(String,frac));
        frac 		= replace.(frac,r"\]"=>"");
        frac 		= replace.(frac,r"\["=>"");
        frac 		= parse.(Float64,frac);

        push!(db,Dict(  :bulk       => bulk,
                        :title      => title,
                        :comments   => comments,
                        :db         => dbin,
                        :test       => test,
                        :sysUnit    => sysUnit,
                        :oxide      => oxide,
                        :frac       => frac,
                    ), cols=:union)
    end

end


function parse_bulk_rock(contents, filename)

    try
        content_type, content_string = split(contents, ',');
        decoded = base64decode(content_string);
        input   = String(decoded) ;
        datain  = strip.(readdlm(IOBuffer(input), ';', comments=true, comment_char='#'));
        bulk_file_to_db(datain);

        return html_div([
            "Bulk-rock file successfully loaded"
        ], style = Dict("textAlign" => "center","font-size" => "100%"))
    catch e
        return html_div([
            "File format wrong, correct it"
        ], style = Dict("textAlign" => "center","font-size" => "100%"))
    end

  end

function get_initial_vertices(Xsub,Ysub,tmin,tmax,pmin,pmax)
    x0      = tmin;
    y0      = pmin;
    xrng    = tmax-tmin;
    yrng    = pmax-pmin;

    Xsub = Int64(Xsub)
    Ysub = Int64(Ysub)

    nb      = (Ysub + 1 )*(Xsub + 1);   # main quads
    ns      = (Ysub)*(Xsub + 2);        # tri subdivision

    vert_list = zeros(nb+ns,2);         # declare vertice coordinate matrix

    b_xs = Float64(1.0/Xsub);                    # x step
    b_ys = Float64(1.0/Ysub);                    # y step

    # get coarse grid vertice position
    inc = 1;
    for i=1:Xsub+1
        for j=1:Ysub+1
            vert_list[inc,1] = (Float64(i)-1)*b_xs;
            vert_list[inc,2] = (Float64(j)-1)*b_ys;
            inc += 1;
        end
    end

    # intermediate vertices boundary position
    for j=1:Ysub
        vert_list[inc,1] = 0.0;
        vert_list[inc,2] = (Float64(j)-1)*b_ys + b_ys/2.0;
        inc += 1;
    end
    for j=1:Ysub
        vert_list[inc,1] = 1.0;
        vert_list[inc,2] = (Float64(j)-1)*b_ys + b_ys/2.0;
        inc += 1;
    end

    # intermediate vertices inner position
    for i=1:Xsub
        for j=1:Ysub
            vert_list[inc,1] = (Float64(i)-1)*b_xs + b_xs/2.0;
            vert_list[inc,2] = (Float64(j)-1)*b_ys + b_ys/2.0;
            inc += 1;
        end
    end

    for inc=1:size(vert_list,1);
        vert_list[inc,1] = vert_list[inc,1] * xrng + x0;
        vert_list[inc,2] = vert_list[inc,2] * yrng + y0;
    end

    return vert_list
end

function get_field_from_vert(vert,tmin,tmax,pmin,pmax)

    n       = size(vert,1);
    field   = zeros(n);

    for i=1:n
        field[i]   = circle_eq(vert[i,1],vert[i,2],tmin,tmax,pmin,pmax);             # function to test AMR with triangles
    end

    return field
end

function circle_eq(xc,yc,tmin,tmax,pmin,pmax)
    x0      = tmin;
    y0      = pmin;
    xrng    = tmax-tmin;
    yrng    = pmax-pmin;

    r = 0.25;
    x = (xc - (x0 + xrng/4))/(xrng/2);
    y = (yc - y0)/yrng;

    if (x - 0.5)*(x - 0.5) + (y - 0.5)*(y - 0.5) - r*r < 0
        z = 1;
    else
        z = 0;
    end

    return z
end


function generator_scatter_traces(tmin,tmax,pmin,pmax)
    # print("$(AppData.vertice_list)\n\n")
    mesh    = delaunay(AppData.vertice_list[]);
    mcat    = cat(mesh.simplices,mesh.simplices[:,1],dims=2);
    n       = size(mesh.simplices,1);
    data    = Vector{GenericTrace{Dict{Symbol, Any}}}(undef, n);

    for i=1:n
        x   = mesh.points[mcat[i,:],1]
        y   = mesh.points[mcat[i,:],2]

        tmp = AppData.field[];
        z   = tmp[mcat[i,:]]
 
        # ugly way to have different colors -> will use heatmap here
        if sum(z)/4.0 == 0.0
            color = "#9999FF"
        elseif sum(z)/4.0 == 1.0
            color = "#FF99FF"
        else
            color = "#6633FF"
        end
        
        data[i]=scatter(;   x           = x,
                            y           = y,
                            fill        = "toself",
                            fillcolor   = color,
                            line_color  = "#000000",
                            line_width  = 0.1, #0.5
                            marker      = attr( color   = "LightSkyBlue",
                                                size    = 0.1, #4
                                                line    = attr(width=0.1, color="#000000")),
                            hoverinfo   = "skip",
                        );
    end

    return data, mesh;
end    

