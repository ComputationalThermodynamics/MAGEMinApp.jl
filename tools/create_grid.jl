using MAGEMin_C

using PlotlyJS
using ProgressMeter
using ConcaveHull
using Statistics,PolygonOps
# using StaticArrays
# using LinearAlgebra


n = 32
# P = range(1, 7, n)
# T = range(500, 900, n)

P = range(1, 7, n)
T = range(500, 1100, n)

Out_XY = Vector{MAGEMin_C.gmin_struct{Float64, Int64}}(undef,n*n)


db          = "mp"
gv, z_b, DB, splx_data  = init_MAGEMin(db);
sys_in      =   "mol"    
test        =   0         
gv          =   use_predefined_bulk_rock(gv, test, db);
gv.verbose  =   -1

id = 1
@showprogress for p in P 
    for t in T
        Out_XY[id]         =   point_wise_minimization(p,t, gv, z_b, DB, splx_data, sys_in);
        id += 1
    end
end

Hash_XY     = Vector{UInt64}(undef,n*n)
Pres        = Vector{Float64}(undef,n*n)
Temp        = Vector{Float64}(undef,n*n)
ph          = Vector{String}(undef,n*n)
phd         = Vector{String}(undef,n*n)
fac         = (maximum(T)-minimum(T))*(maximum(P)-minimum(P))


for i = 1:n*n 
    Hash_XY[i]  = hash(sort(Out_XY[i].ph))
    Pres[i]     = Out_XY[i].P_kbar
    Temp[i]     = Out_XY[i].T_C
    phd[i]      = ""
    for k=1:length(Out_XY[i].ph)
        phd[i] *= Out_XY[i].ph[k]*" "
        if k % 3 == 0
            phd[i] *= "<br>" 
        end
    end

    ph[i]       = join(Out_XY[i].ph," ")

end
# mesh        = delaunay(hcat(Temp,Pres))

n_hull      = length(unique(Hash_XY))
hull_list   = Vector{Any}(undef,n_hull)
ph_list     = Vector{String}(undef,n_hull)
phd_list    = Vector{String}(undef,n_hull)
id          = 0
for i in unique(Hash_XY)
    field_tmp = findall(Hash_XY .== i)

    t2      = Temp[field_tmp]
    p2      = Pres[field_tmp]

    phase   = ph[field_tmp]
    phased  = phd[field_tmp]

    np = length(t2)
    if np > 2
        id             += 1
        points          =  [[ t2[i]+rand()/2, p2[i]+rand()/100] for i=1:np]
        hull_list[id]   = concave_hull(points,1024)
        ph_list[id]     = phase[1]
        phd_list[id]    = phased[1]
    end
end


n_trace     = id;
data        = Vector{GenericTrace{Dict{Symbol, Any}}}(undef,n_trace);
annotations = Vector{PlotlyBase.PlotlyAttribute{Dict{Symbol, Any}}}(undef,n_trace+1)
labelCoor   = Matrix{Float64}(undef,n_trace,2)

txt_list = ""
cnt = 1;
for i=1:n_trace
    
    tmp     = mapreduce(permutedims,vcat,hull_list[i].vertices)
    tmp     = vcat(tmp,tmp[1,:]')

    data[i] = scatter(; x           = tmp[:,1],
                        y           = tmp[:,2],
                        fill        = "toself",
                        fillcolor   = "transparent",
                        line_width  = 0.0,
                        mode        = "scatter",
                        # mode        = "scatter",
                        hoverinfo   = "text",
                        text        = ph_list[i],
                        );


    np          = size(tmp,1) 
    if np > 4
        tmp2    = [tmp[i,:] for i in 1:size(tmp,1)]
        ctr     = PolygonOps.centroid(tmp2)
    else
        ctr     = zeros(2)
        ctr[1]  =  mean(tmp[2:end,1])
        ctr[2]  =  mean(tmp[2:end,2])
    end
    labelCoor[i,1]   = (ctr[1]-minimum(T))/(maximum(T)-minimum(T))
    labelCoor[i,2]   = (ctr[2]-minimum(P))/(maximum(P)-minimum(P))

    if i > 1
        for j=1:i-1
            dist = sqrt((labelCoor[i,1] - labelCoor[j,1])^2+(labelCoor[i,2] - labelCoor[j,2])^2)
            print("$j: $cnt: $dist\n")
        end
        print("\n")
    end

    if area(hull_list[i])/fac < 0.004

        if (labelCoor[i,1]) < 0.05
            ax = 15
        else
            ax = -15
        end
        if (labelCoor[i,2]) > 0.95
            ay =  15
        else
            ay = -15
        end

        annotations[i] =   attr(    xref        = "x",
                                    yref        = "y",
                                    x           = ctr[1],
                                    y           = ctr[2],
                                    ax          = ax,
                                    ay          = ay,
                                    text        = string(cnt),
                                    showarrow   = true,
                                    arrowhead   = 1,
                                    visible     = true
                                )  
        txt_list *= string(cnt)*") "*ph_list[i]*"<br>"
        cnt +=1
    elseif area(hull_list[i])/fac > 0.06 
        annotations[i] =   attr(    xref        = "x",
                                    yref        = "y",
                                    align       = "left",
                                    valign      = "top",
                                    x           = ctr[1],
                                    y           = ctr[2],
                                    text        = phd_list[i],
                                    showarrow   = false,
                                    visible     = true  
                                )                     
    else
        annotations[i] =   attr(    xref        = "x",
                                    yref        = "y",
                                    align       = "left",
                                    valign      = "top",
                                    x           = ctr[1],
                                    y           = ctr[2],
                                    text        = string(cnt),
                                    showarrow   = false,
                                    visible     = true
                                )  

        txt_list *= string(cnt)*") "*ph_list[i]*"<br>" 
        cnt +=1  
    end 
end

annotations[end] =   attr(      xref        = "x",
                                yref        = "y",
                                align       = "left",
                                valign      = "top",
                                x           = minimum(T) - 75,
                                y           = (maximum(P)-minimum(P))/2+minimum(P),
                                text        = txt_list,
                                visible     = true
)  

layout = Layout(
                    height      = 768, 
                    width       = 1024, 
                    showlegend  = false,
                    annotations = annotations,
                )


plot( vcat(data), layout)




v = data[1:4]
w = data[5:end]

plot( v, layout)

plot( vcat(v,w), layout)

























#################################################################################################################################

#################################################################################################################################

    # np      = size(tmpN,1)
    # half    = Int64(floor(np/2))
    # d       = Vector{Float64}(undef,np)

    # for i=1:np
    #     j = i + half
    #     if j > np
    #         j = j - np
    #     end

    #     d[i] = sqrt( (tmpN[i,1]-tmpN[j,1])^2 + (tmpN[i,2]-tmpN[j,2])^2 )
    # end

    # d .= d ./ maximum(d)
    # print("std $cnt: $(std(d)), area: $(area(hull_list[i]))\n")


# var layout = {
#   showlegend: false,
#   annotations: [
#     {
#       x: 2,
#       y: 5,
#       xref: 'x',
#       yref: 'y',
#       text: 'Annotation Text',
#       showarrow: true,
#       arrowhead: 7,
#       ax: 0,
#       ay: -40
#     }
#   ]
# };



# id = 0
# for i in unique(Hash_XY)
#     field_tmp = findall(vec(sum(Hash_XY[mesh.simplices] .== i,dims=2)) .> 0)
#     np        = length(field_tmp)

#     t2 = Vector{Float64}(undef,np)
#     p2 = Vector{Float64}(undef,np)

#     for j=1:np
#         t2[j] = Temp[mesh.simplices[field_tmp[j],1]]/3.0 + Temp[mesh.simplices[field_tmp[j],2]]/3.0 + Temp[mesh.simplices[field_tmp[j],3]]/3.0
#         p2[j] = Pres[mesh.simplices[field_tmp[j],1]]/3.0 + Pres[mesh.simplices[field_tmp[j],2]]/3.0 + Pres[mesh.simplices[field_tmp[j],3]]/3.0
#     end

#     if np > 2
#         id             += 1
#         points          =  [[ t2[i]+rand()/2, p2[i]+rand()/100] for i=1:np]
#         hull            = concave_hull(points,128)
#         hull_list[id]   = hull

#     end
# end


# scatter(Temp,Pres,marker_z = Hash_XY)
# for i=1:id
#     plot!(hull_list[i])
# end
# plot!(hull_list[1])



# fig.add_trace(go.Scatter(x=[3,5,5,3,3],
#                          y=[3,3,1,1,3],
#                          fill='toself',
#                          fillcolor='yellow',
#                          mode='lines',
#                          name="Rectangle"
#                          )
#               )



# using GLMakie
# color = Hash_XY
# fig, ax, pl = Makie.poly(mesh.points, mesh.simplices, color=color, strokewidth=2, figure=(resolution=(800, 400),))


# for i=1:n_trace
#     print("$i\n")
#     tmp    = mapreduce(permutedims,vcat,hull_list[i].vertices)
#     tmp    = vcat(tmp,tmp[1,:]')
#     data[i]=scatter(;   x           = tmp[:,1],
#                         y           = tmp[:,2],
#                         fill        = "toself",
#                         fillcolor   = "#d6f5d6",
#                         # line_color  = "#000000",
#                         line_width  = 0.,
#                         mode        = "lines",
#                         # marker      = attr( color   = "LightSkyBlue",
#                         #                     size    = 4,
#                         #                     # line    = attr(width=0.5, color="#000000")
#                         #                     ),
#                         hovertemplate   = "test"*"$i",
#                         # text        = ,
#                         );
# end
# plot(data, Layout(;height=768, width=1024, showlegend=false))

# using GeometryBasics
# using Polylabel

# using Conda
# using Conda

# Conda.pip("install", "polylabel")

# polylabel = pyimport("polylabel")
# # p1 = Polygon([
# #                GeometryBasics.Point2{Float64}(-10, 0),
# #                GeometryBasics.Point2{Float64}(0, 9),
# #                GeometryBasics.Point2{Float64}(20, 0),
# #                GeometryBasics.Point2{Float64}(0, -10),
# #                GeometryBasics.Point2{Float64}(-10, 0)
# #            ])

# # p1 = Polygon(Point{2, Int}[(3, 1), (4, 4), (2, 4), (1, 2), (3, 1)])
# # labelpoint = polylabel(p1, rtol = 0.001)

