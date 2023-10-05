"""
    Function interpolate AMR grid to regular grid
"""
function get_gridded_map(   fieldname   ::String,
                            oxi         ::Vector{String},
                            Out_XY      ::Vector{MAGEMin_C.gmin_struct{Float64, Int64}},
                            sub         ::Int64,
                            refLvl      ::Int64,
                            xc          ::Vector{Float64},
                            yc          ::Vector{Float64},
                            xf          ::Vector{SVector{4, Float64}},
                            yf          ::Vector{SVector{4, Float64}},
                            Xrange      ::Tuple{Float64, Float64},
                            Yrange      ::Tuple{Float64, Float64} )

    np          = length(data.x)
    len_ox      = length(oxi)
    field       = Vector{Union{Float64,Missing}}(undef,np);
    npoints     = np

    if fieldname == "#Stable_Phases"
        for i=1:np
            field[i] = Float64(length(Out_XY[i].ph));
        end
    elseif fieldname == "Variance"
        for i=1:np
            field[i] = Float64(len_ox - n_phase_XY[i] + 2.0);
        end
    else
        for i=1:np
            field[i] = Float64(get_property(Out_XY[i], fieldname));
        end

        field[isnan.(field)] .= missing
        if fieldname == "frac_M" || fieldname == "rho_M" || fieldname == "rho_S"
            field[isless.(field, 1e-8)] .= missing              #here we use isless instead of .<= as 'isless' considers 'missing' as a big number -> this avoids "unable to check bounds" error
        end
    end

    n           = 2^(sub + refLvl)
    x           = range(minimum(xc), stop = maximum(xc), length = n)
    y           = range(minimum(yc), stop = maximum(yc), length = n)

    X           = repeat(x , n)[:]
    Y           = repeat(y', n)[:]
    gridded     = Matrix{Union{Float64,Missing}}(undef,n,n);
    gridded_info= fill("",n,n)


    Xr = (Xrange[2]-Xrange[1])/n
    Yr = (Yrange[2]-Yrange[1])/n

    for k=1:np
        for i=xf[k][1]+Xr/2 : Xr : xf[k][3]
            for j=yf[k][1]+Yr/2 : Yr : yf[k][3]
                ii = Int64(round((i-Xrange[1] + Xr/2)/(Xr)))
                jj = Int64(round((j-Yrange[1] + Yr/2)/(Yr)))
                gridded[ii,jj] = field[k]
                gridded_info[ii,jj] = replace.(string(Out_XY[k].ph),r"\""=>"")
            end
        end
    end

    return gridded, gridded_info, X, Y, npoints
end


"""
    Function to extract values from structure using structure's member name
"""
function get_property(x, name::String)
    s = Symbol(name)
    return getproperty(x, s)
end


"""
    Function to send back the oxide list of the implemented database
"""
function get_oxide_list(dbin::String)

    if dbin == "ig"
	    MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "H2O"];
    elseif dbin == "igd"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "H2O"];      
    elseif dbin == "alk"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "Cr2O3"; "H2O"];    
    elseif dbin == "mb"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "H2O"];     
    elseif dbin == "um"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "MgO" ;"FeO"; "O"; "H2O"; "S"];
    elseif dbin == "mp"
        MAGEMin_ox      = ["SiO2"; "Al2O3"; "CaO"; "MgO"; "FeO"; "K2O"; "Na2O"; "TiO2"; "O"; "MnO"; "H2O"];
    else
        print("Database not implemented...\n")
    end


    return MAGEMin_ox
end

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
        oxide 		= replace.(oxide,r"\]"=>"",r"\["=>"");

        idx 		= findall(datain[1,:] .== "frac")[1];
        frac   		= rsplit(datain[i,idx],",");
        frac 		= strip.(convert.(String,frac));
        frac 		= replace.(frac,r"\]"=>"",r"\["=>"");
        frac 		= parse.(Float64,frac);

        bulkrock    = convertBulk4MAGEMin(frac,oxide,String(sysUnit),String(dbin)) 
        oxide       = get_oxide_list(String(dbin))

        push!(db,Dict(  :bulk       => bulk,
                        :title      => title,
                        :comments   => comments,
                        :db         => dbin,
                        :test       => test,
                        :sysUnit    => sysUnit,
                        :oxide      => oxide,
                        :frac       => bulkrock,
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
            "Wrong file format: $e"
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

