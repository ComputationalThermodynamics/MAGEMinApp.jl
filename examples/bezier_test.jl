using PlotlyJS


function cubic(points:: Matrix{Float64}; resolution::Int64 = 32)

    step = 1.0/resolution
    B_t = Matrix{Float64}(undef,resolution,2)

    x0, y0 = points[1,1], points[1,2]
    x1, y1 = points[2,1], points[2,2]
    x2, y2 = points[3,1], points[3,2]
    x3, y3 = points[4,1], points[4,2]

    y(t) = (1 - t)^3 * y0 +
           3 * (1 - t)^2 * t * y1 +
           3 * (1 - t) * t^2 * y2 +
           t^3 * y3

    x(t) = (1 - t)^3 * x0 +
           3 * (1 - t)^2 * t * x1 +
           3 * (1 - t) * t^2 * x2 +
           t^3 * x3

    for i=1:resolution
        t = i*step
        valX = x(t)
        valY = y(t)
        B_t[i,:] = [valX,valY]
    end

    return B_t
end


points = [  0.0 0.2;
            0.5 0.2;
            0.5 0.8;
            1.0 0.8   ]




B = cubic(points)



# section to plot density evolution
trace1 = scatter(   x       = B[:,1], 
                    y       = B[:,2], 
                    name    = "bezier test",
                    line    = attr( color   = "black", 
                                    width   = 2)                )
                      
# trace2 = scatter(   x       = x, 
#                     y       = residual_density, 
#                     name    = "Residual density [kg/m³]",
#                     line    = attr( color   = "firebrick", 
#                                     width   = 2)                )
                      
# trace3 = scatter(   x       = x, 
#                     y       = system_density, 
#                     name    = "System density[kg/m³]",
#                     line    = attr( color   = "coral", 
#                                     width   = 2)                )

layout = Layout(    title           = "Density evolution",
                    xaxis_title     = "PT [kbar, °C]",
                    yaxis_title     = "Density [kg/³]")


plot(trace1, layout)

