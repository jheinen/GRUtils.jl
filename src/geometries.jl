mutable struct Geometry{K}
    x::Vector{Float64}
    y::Vector{Float64}
    z::Vector{Float64}
    c::Vector{Float64}
    spec::String
    label::String
    attributes::Dict{Symbol,Float64}
end

# Partial constructor with keyword arguments
emptyvector(T::DataType) = Array{T,1}(undef,0)

Geometry{K}(;
    x=emptyvector(Float64),
    y=emptyvector(Float64),
    z=emptyvector(Float64),
    c=emptyvector(Float64),
    spec="",
    label="",
    kwargs...) where K =
    Geometry{K}(x, y, z, c, spec, label, Dict{Symbol,Float64}(kwargs...))

function Geometry(g::Geometry{K}; kwargs...) where K
    kwargs = (; g.attributes..., kwargs...)
    typeof(g)(; x=g.x, y=g.y, z=g.z, c=g.z, spec=g.spec, label=g.label, kwargs...)
end

# Complex arguments processed as pair of real, imaginary values
geometries(G, x::AbstractVecOrMat{<:Complex}, args...; kwargs...) =
    geometries(G, real(x), imag(x), args...; kwargs...)

# Parse function arguments
geometries(G, x::AbstractVecOrMat{<:Real},
    f::Function, args...; kwargs...) = geometries(G, x, f.(x), args...; kwargs...)

geometries(G, x::AbstractVecOrMat{<:Real}, y::AbstractVecOrMat{<:Real},
    f::Function, args...; kwargs...) =
    geometries(G, x, y, f.(x, y), args...; kwargs...)

geometries(G, x::AbstractVecOrMat{<:Real}, y::AbstractVecOrMat{<:Real}, z::AbstractVecOrMat{<:Real},
    f::Function, args...; kwargs...) = geometries(G, x, y, z, f.(x, y, z), args...; kwargs...)

# Generic functions with given x, y, z, etc. as `AbstractVector`
geometries(G::Type{<:Geometry},
    x::AbstractVecOrMat, y::AbstractVecOrMat, z::AbstractVecOrMat,
    c::AbstractVecOrMat; kwargs...) = [G(; x=x, y=y, z=z, c=c, kwargs...)]

geometries(G::Type{<:Geometry},
    x::AbstractVecOrMat, y::AbstractVecOrMat, z::AbstractVecOrMat;
    kwargs...) = [G(; x=x, y=y, z=z, kwargs...)]

geometries(G::Type{<:Geometry}, x::AbstractVecOrMat, y::AbstractVecOrMat;
    kwargs...) = [G(; x=x, y=y, kwargs...)]

geometries(G::Type{<:Geometry}, y; kwargs...) = [G(; x=1:length(y), y=y, kwargs...)]

# Particular functions

column(a::Vector, i::Int) = a
column(a::AbstractVector, i::Int) = collect(a)
column(a::AbstractMatrix, i::Int) = a[:,i]

## Line, step and stem (lines with specification):
const MarkedLine = Union{Geometry{:line}, Geometry{:step}, Geometry{:stem}}
function geometries(G::Type{<:MarkedLine},
    x::AbstractVecOrMat, y::AbstractVecOrMat, spec::String=""; kwargs...)

    # tbd: check size of x, y
    [G(; x=column(x,i), y=column(y,i), spec=spec, kwargs...)
    for i = 1:size(y,2)]
end

geometries(G::Type{<:MarkedLine}, y::AbstractVecOrMat, spec::String=""; kwargs...) =
    geometries(G, 1:size(y,1), y, spec; kwargs...)

# Scatter
function geometries(G::Type{Geometry{:scatter}},
    x::AbstractVector, y::AbstractVector,
    z::AbstractVector=emptyvector(Float64),
    c::AbstractVector=emptyvector(Float64); kwargs...)

    # tbd: check size of x, y
    [G(; x=column(x,1), y=column(y,1), z=column(z,1), c=column(c,1), kwargs...)]
end

# 3D line
function geometries(G::Type{Geometry{:line3d}},
    x::AbstractVecOrMat, y::AbstractVecOrMat, z::AbstractVecOrMat, spec::String=""; kwargs...)

    [G(; x=column(x,i), y=column(y,i), z=column(z,i), spec=spec, kwargs...)
    for i = 1:size(y,2)]
end


# Polar plot
function geometries(G::Type{Geometry{:polarline}},
    x::AbstractVecOrMat, y::AbstractVecOrMat, spec::String=""; kwargs...)

    [G(; x=column(x,i), y=column(y,i), spec=spec, kwargs...)
    for i = 1:size(y,2)]
end

# `draw` methods

hasline(mask) = ( mask == 0x00 || (mask & 0x01 != 0) )
hasmarker(mask) = ( mask & 0x02 != 0)

function draw(g::Geometry{:line})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    mask = GR.uselinespec(g.spec)
    hasline(mask) && GR.polyline(g.x, g.y)
    hasmarker(mask) && GR.polymarker(g.x, g.y)
    GR.restorestate()
end

function draw(g::Geometry{:step})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    mask = GR.uselinespec(g.spec)
    if hasline(mask)
        n = length(g.x)
        if g.attributes[:step_position] < 0
            xs = zeros(2n - 1)
            ys = zeros(2n - 1)
            xs[1] = g.x[1]
            ys[1] = g.y[1]
            for i in 1:n-1
                xs[2i]   = g.x[i]
                xs[2i+1] = g.x[i+1]
                ys[2i]   = g.y[i+1]
                ys[2i+1] = g.y[i+1]
            end
        elseif g.attributes[:step_position] > 0
            xs = zeros(2n - 1)
            ys = zeros(2n - 1)
            xs[1] = g.x[1]
            ys[1] = g.y[1]
            for i in 1:n-1
                xs[2i]   = g.x[i+1]
                xs[2i+1] = g.x[i+1]
                ys[2i]   = g.y[i]
                ys[2i+1] = g.y[i+1]
            end
        else
            xs = zeros(2n)
            ys = zeros(2n)
            xs[1] = g.x[1]
            for i in 1:n-1
                xs[2i]   = 0.5 * (g.x[i] + g.x[i+1])
                xs[2i+1] = 0.5 * (g.x[i] + g.x[i+1])
                ys[2i-1] = g.y[i]
                ys[2i]   = g.y[i]
            end
            xs[2n]   = g.x[n]
            ys[2n-1] = g.y[n]
            ys[2n]   = g.y[n]
        end
        GR.polyline(xs, ys)
    end
    hasmarker(mask) && GR.polymarker(g.x, g.y)
    GR.restorestate()
end

function draw(g::Geometry{:stem})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    GR.setlinecolorind(1)
    GR.polyline([minimum(g.x), maximum(g.x)], [0.0, 0.0])
    GR.setmarkertype(GR.MARKERTYPE_SOLID_CIRCLE)
    GR.uselinespec(g.spec)
    for i = 1:length(g.y)
        GR.polyline([g.x[i], g.x[i]], [0.0, g.y[i]])
        GR.polymarker([g.x[i]], [g.y[i]])
    end
    GR.restorestate()
end

# Normalize a color c with the range [cmin, cmax]
#   0 <= normalize_color(c, cmin, cmax) <= 1
function normalize_color(c, cmin, cmax)
    c = clamp(float(c), cmin, cmax) - cmin
    (cmin != cmax) && (c /= cmax - cmin)
    return c
end

function draw(g::Geometry{:scatter})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    GR.setmarkertype(GR.MARKERTYPE_SOLID_CIRCLE)
    if !isempty(g.z) || !isempty(g.c)
        if !isempty(g.c)
            # cmin, cmax = plt.kvs[:crange]
            cmin, cmax = extrema(g.c)
            cnorm = map(x -> normalize_color(x, cmin, cmax), g.c)
            cind = Int[round(Int, 1000 + _i * 255) for _i in cnorm]
        end
        for i in 1:length(g.x)
            !isempty(g.z) && GR.setmarkersize(g.z[i] / 100.0)
            !isempty(g.c) && GR.setmarkercolorind(cind[i])
            GR.polymarker([g.x[i]], [g.y[i]])
        end
    else
        GR.polymarker(g.x, g.y)
    end
    GR.restorestate()
end

function draw(g::Geometry{:bar})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    for i = 1:2:length(g.x)
        GR.setfillcolorind(989)
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        GR.fillrect(g.x[i], g.x[i+1], g.y[i], g.y[i+1])
        GR.setfillcolorind(1)
        GR.setfillintstyle(GR.INTSTYLE_HOLLOW)
        GR.fillrect(g.x[i], g.x[i+1], g.y[i], g.y[i+1])
    end
    GR.restorestate()
end

function draw(g::Geometry{:line3d})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    GR.uselinespec(g.spec)
    GR.polyline3d(g.x, g.y, g.z)
    GR.restorestate()
end

function draw(g::Geometry{:scatter3})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    GR.setmarkertype(GR.MARKERTYPE_SOLID_CIRCLE)
    if !isempty(g.c)
        cmin, cmax = extrema(g.c)
        cnorm = map(x -> normalize_color(x, cmin, cmax), g.c)
        cind = Int[round(Int, 1000 + _i * 255) for _i in cnorm]
        for i in 1:length(g.x)
            GR.setmarkercolorind(cind[i])
            GR.polymarker3d([g.x[i]], [g.y[i]], [g.z[i]])
        end
    else
        GR.polymarker3d(g.x, g.y, g.z)
    end
    GR.restorestate()
end

function draw(g::Geometry{:polarline})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    GR.uselinespec(g.spec)
    ymin, ymax = extrema(g.y)
    ρ = (g.y .- ymin) ./ (ymax .- ymin)
    n = length(ρ)
    x = ρ .* cos.(g.x)
    y = ρ .* sin.(g.x)
    GR.polyline(x, y)
    GR.restorestate()
end

function draw(g::Geometry{:polarbar})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    xmin, xmax = extrema(g.x)
    ymin, ymax = extrema(g.y)
    ρ = g.y ./ ymax # 2 .* (g.y ./ ymax) .- 0.5)
    θ = 2pi .* (g.x .- xmin) ./ (xmax - xmin)
    for i = 1:2:length(ρ)
        GR.setfillcolorind(989)
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        GR.fillarea([ρ[i] * cos(θ[i]), ρ[i] * cos(θ[i+1]), ρ[i+1] * cos(θ[i+1]), ρ[i+1] * cos(θ[i])],
                    [ρ[i] * sin(θ[i]), ρ[i] * sin(θ[i+1]), ρ[i+1] * sin(θ[i+1]), ρ[i+1] * sin(θ[i])])
        GR.setfillcolorind(1)
        GR.setfillintstyle(GR.INTSTYLE_HOLLOW)
        GR.fillarea([ρ[i] * cos(θ[i]), ρ[i] * cos(θ[i+1]), ρ[i+1] * cos(θ[i+1]), ρ[i+1] * cos(θ[i])],
                    [ρ[i] * sin(θ[i]), ρ[i] * sin(θ[i+1]), ρ[i+1] * sin(θ[i+1]), ρ[i+1] * sin(θ[i])])
    end
    GR.restorestate()
end

function draw(g::Geometry{:contour})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    clabels = get(g.attributes, :clabels, 1.0)
    GR.contour(g.x, g.y, g.c, g.z, Int(clabels))
    GR.restorestate()
end

function draw(g::Geometry{:contourf})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    # clabels limited from 0 to 999
    clabels = rem(get(g.attributes, :clabels, 1.0), 1000)
    GR.contourf(g.x, g.y, g.c, g.z, Int(clabels))
    GR.restorestate()
end

function draw(g::Geometry{:surface})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    if get(g.attributes, :accelerate, 1.0) == 0.0
        GR.surface(g.x, g.y, g.z, GR.OPTION_COLORED_MESH)
    else
        GR.gr3.clear()
        GR.gr3.surface(g.x, g.y, g.z, GR.OPTION_COLORED_MESH)
    end
    GR.restorestate()
end

function draw(g::Geometry{:wireframe})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    GR.setfillcolorind(0)
    GR.surface(g.x, g.y, g.z, GR.OPTION_FILLED_MESH)
    GR.restorestate()
end

function draw(g::Geometry{:heatmap})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    w = length(g.x)
    h = length(g.y)
    cmap = colormap()
    cmin, cmax = extrema(g.c)
    data = map(x -> normalize_color(x, cmin, cmax), g.c)
    rgba = [to_rgba(value, cmap) for value ∈ data]
    GR.drawimage(0.5, w + 0.5, h + 0.5, 0.5, w, h, rgba)
    GR.restorestate()
end

function colormap()
    rgb = zeros(256, 3)
    for colorind in 1:256
        color = GR.inqcolor(999 + colorind)
        rgb[colorind, 1] = float( color        & 0xff) / 255.0
        rgb[colorind, 2] = float((color >> 8)  & 0xff) / 255.0
        rgb[colorind, 3] = float((color >> 16) & 0xff) / 255.0
    end
    rgb
end

function to_rgba(value, cmap)
    if !isnan(value)
        r, g, b = cmap[round(Int, value * 255 + 1), :]
        a = 1.0
    else
        r, g, b, a = zeros(4)
    end
    round(UInt32, a * 255) << 24 + round(UInt32, b * 255) << 16 +
    round(UInt32, g * 255) << 8  + round(UInt32, r * 255)
end

function draw(g::Geometry{:polarheatmap})
    GR.savestate()
    GR.settransparency(get(g.attributes, :alpha, 1.0))
    w = length(g.x)
    h = length(g.y)
    cmap = colormap()
    cmin, cmax = extrema(g.c)
    data = map(x -> normalize_color(x, cmin, cmax), g.c)
    colors = Int[round(Int, 1000 + _i * 255) for _i in data]
    GR.polarcellarray(0, 0, 0, 360, 0, 1, w, h, colors)
    GR.restorestate()
end
