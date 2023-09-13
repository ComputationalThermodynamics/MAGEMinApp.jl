
# function house()
#     trace1 = scatter()
#     x0 = [2,   2,   5.5, 9,   9, 2,   5, 5, 6]
#     y0 = [1,   5.5, 9.5, 5.5, 1, 5.5, 1, 4, 4]
#     x1 = [2,   5.5, 9,   9,   2, 9,   5, 6, 6]
#     y1 = [5.5, 9.5, 5.5, 1,   1, 5.5, 4, 4, 1]
#     shapes = line(x0, x1, y0, y1; xref="x", yref="y")
#     plot([trace1],
#          Layout(;shapes=shapes, xaxis_range=(1, 10), yaxis_range=(0, 10)))
# end
# house()












# # x = mesh.points[m[1,:],1];
# # y = mesh.points[m[1,:],2];

# # plot(x,kind="scatter", x=x, y=y, fill="toself", fillcolor="#d6f5d6")
# # # plot(data=>["x"=>x,"y"=>y])

# # s = Dict("data"=>x,"kind"=>"scatter", "x"=>x, "y"=>y,"fill"=>"toself", "fillcolor"=>"#d6f5d6")
# # p = plot()
# # relayout!(p, shapes=s)


# shape_list = []
# for i=1:n
#     x = mesh.points[m[i,:],1];
#     y = mesh.points[m[i,:],2];
#     push!(shape_list,Dict("kind"=>"scatter", "x"=>x, "y"=>y,"fill"=>"toself", "fillcolor"=>"#FFF"))
# end

# p = plot()
# relayout!(p, shapes=shape_list)

# fig = dict({
#     "data": [{"type": "bar",
#               "x": [1, 2, 3],
#               "y": [1, 3, 2]}],
#     "layout": {"title": {"text": "A Figure Specified By Python Dictionary"}}
# })


# fig = dict({
#     "data": [{"type": "bar",
#               "x": [1, 2, 3],
#               "y": [1, 3, 2]}],
#     "layout": {"title": {"text": "A Figure Specified By Python Dictionary"}}
# })
# Dict("orientation"=>"h", "len"=>0.5, "thickness"=>10,"title"=>"elevat"),
# fig = plot(db, kind="bar", x=:Who, y=:Hours, color=:Activity, width=AppData.Hours_Width, layout)

# fig = plot()


# # Update plot sizing

# relayout!(fig,
#     width=800,
#     height=900,
#     autosize=false,
#     margin=attr(t=100, b=0, l=0, r=0),

# )

# for i=1:n
#     x = mesh.points[m[i,:],1];
#     y = mesh.points[m[i,:],2];
#     add_trace!(fig, scatter(x=x, y=y, fill="toself", fillcolor="#d6f5d6"))
# end










    #     # create actual figure
    #     pl = (
    #         id = "fig_3D",
            
    #         # Topography
    #         data = data_plot,
            
    #         colorbar=Dict("orientation"=>"h", "len"=>0.5, "thickness"=>10,"title"=>"elevat"),
    #         layout = (  autosize=false,
    #                     width=1000, height=500,                 # need to check that this works fine on different screens/OS
    #                     scene = attr(  yaxis=attr(
    #                                     showspikes=false,
    #                                     title="Latitude",
    #                                     tickfont_size= 14,
    #                                     tickfont_color="rgb(100, 100, 100)"),
    #                                 xaxis=attr(
    #                                     showspikes=false,
    #                                     title="Longitude",
    #                                     tickfont_size= 14,
    #                                     tickfont_color="rgb(100, 100, 100)"
    #                                 ),
    #                                 zaxis=attr(
    #                                     showspikes=false,
    #                                     title="Depth",
    #                                     tickfont_size= 14,
    #                                     tickfont_color="rgb(10, 10, 10)"
    #                                 ),
    #                                 aspectmode="manual", 
    #                                 aspectratio=attr(x=3, y=3, z=1)
    #                                 )

    #                     ),
    #         config = (edits    = (shapePosition =  true,)),                              
    #     )
    # else
    #     pl = ()
    # end


# fig = plot()

# for i=1
#     x = mesh.points[m[i,:],1];
#     y = mesh.points[m[i,:],2];
#     trace = scatter(x=x, y=y, fill="toself", fillcolor="#d6f5d6", line_color="#000000")
#     plot(trace)
# end

# plot(trace)


# p = [];
# for i=1:n
#     x = mesh.points[m[n,:],1];
#     y = mesh.points[m[n,:],2];
#     push!(p,scatter(x=x, y=y, fill="toself", fillcolor="#d6f5d6", line_color="#000000"))
# end
# plot(p)


# fig = go.Figure()

# shapes = []
# for data in datapoints:
#     x0 = data[0]
#     y0 = data[1]        
#     x1 = data[2]
#     y1 = data[3]
#     shapes.append(dict(type="circle",
#                     xref="x", yref="y",
#                     x0=x0, y0=y0, x1=x1, y1=y1,
#                     line_color='gold',
#                     fillcolor='gold',
#                     ))
# fig.update_layout(shapes=shapes)



# colors = ["blue", "orange", "green", "brown"]

# plot(scatter(x=tri_x, y=tri_y, fill="toself", colors=["blue", "orange", "green", "brown"], line_color="#000000"))


# x=[0.686548323803941, 0.8355623735037675, 0.45019416120886535, 0.686548323803941, nothing, 0.686548323803941, 0.8355623735037675, 0.45019416120886535, 0.686548323803941]
# y=[0.39684832141770576, 0.8364811146501603, 0.22480843430734732, 0.39684832141770576, nothing, 0.39684832141770576, 0.8364811146501603, 0.22480843430734732, 0.39684832141770576]
# plot(scatter(x=x, y=y, fill="toself"))



# tri_x   = []
# tri_y   = []
# inc=1
# for i=1:n

#     for j=1:3
#         tx = mesh.points[mesh.simplices[j],1]
#         ty = mesh.points[mesh.simplices[j],2]
#         push!(tri_x,tx)
#         push!(tri_y,ty)
#     end
#     tx = mesh.points[mesh.simplices[1],1]
#     ty = mesh.points[mesh.simplices[1],2]
#     push!(tri_x,tx)
#     push!(tri_y,ty)

#     push!(tri_x,nothing)
#     push!(tri_y,nothing)
# end

# inc=1
# for i=1:n

#     for j=1:3
#         tri_x[inc] = mesh.points[mesh.simplices[j],1]
#         tri_y[inc] = mesh.points[mesh.simplices[j],2]
#         inc       += 1
#     end
#     tri_x[inc] = mesh.points[mesh.simplices[1],1]
#     tri_y[inc] = mesh.points[mesh.simplices[1],2]
#     inc       += 1

#     tri_x[inc] = nothing
#     tri_y[inc] = nothing
#     inc       += 1
# end




# cx = [0,1,2,0,nothing,1,2,2,1]
# cy = [0,2,0,0,nothing,2,0,2,2]

# plot(scatter(x=cx, y=cy, fill="toself"))


# # c = [0. 0; 1 0; 0 1; 1 1]

