# this loads scientific colormaps 
# Colormaps should be given in text format in the direc
using DelimitedFiles

dir_colormaps = "assets/colormaps/"

"""
This reads colormaps and transfers them into plotly format. The colormaps are supposed to be provided in ascii text format 
"""
function read_colormaps(; dir_colormaps = "assets/colormaps/", scaling=256)
    # Read all colormaps
    colormaps = NamedTuple();
    for map in readdir(dir_colormaps)
        data = readdlm(dir_colormaps*map)
        name_str = map[1:end-4]

        if contains(name_str,"reverse")
            reverse=true
            data = data[end:-1:1,:]
        else
            reverse=false
        end

        name = Symbol(name_str)

        # apply scaling
        data_rgb = Int64.(round.(data*scaling))

        # Create the format that plotly wants:
        n = size(data,1)
        fac = range(0,1,n)
        data_col = [ [fac[i], "rgb($(data_rgb[i,1]),$(data_rgb[i,2]),$(data_rgb[i,3]))"] for i=1:n]

        col = NamedTuple{(name,)}((data_col,))
        colormaps = merge(colormaps, col)
    end

    return colormaps
end