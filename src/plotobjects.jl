struct Viewport
    outer::Vector{Float64}
    inner::Vector{Float64}
end

const emptyviewport = Viewport(zeros(4), zeros(4))
Viewport() = emptyviewport

function Viewport(subplot)
    ratio_w, ratio_h = wswindow(gcf())
    outer = [subplot[1]*ratio_w, subplot[2]*ratio_w, subplot[3]*ratio_h, subplot[4]*ratio_h]
    # inner contains the axes
    low, high = 0.375, 0.425
    xcenter = 0.5 * (outer[1] + outer[2])
    ycenter = 0.5 * (outer[3] + outer[4])
    vp_x = outer[2] - outer[1]
    vp_y = outer[4] - outer[3]
    inner = [xcenter - low*vp_x, xcenter + high*vp_x, ycenter - low*vp_y, ycenter + high*vp_y]
    Viewport(outer, inner)
end

function Viewport(subplot, ratio::Real, margins=zeros(4))
    v = Viewport(subplot)
    w = v.inner[2] - v.inner[1] - margins[1] - margins[2]
    h = v.inner[4] - v.inner[3] - margins[3] - margins[4]
    if w/h > ratio
        d = 0.5 * (w - h * ratio)
        v.inner[1] += d
        v.inner[2] -= d
    else
        d = 0.5 * (h - w / ratio)
        v.inner[3] += d
        v.inner[4] -= d
    end
    v.inner .-= margins
    v
end

abstract type AbstractPlot end

mutable struct BasicPlot <: AbstractPlot
    viewport::Viewport
    axes::Axes
    geoms::Vector{<:Geometry}
    specs::Dict
end

function BasicPlot(geoms::Vector{<:Geometry}, axes::Axes, margins=zeros(4); kwargs...)
    subplot = get(kwargs, :subplot, unitsquare)
    if haskey(kwargs, :ratio)
        viewport = Viewport(subplot, kwargs[:ratio], margins)
    else
        viewport = Viewport(subplot)
        viewport.inner .-= margins
    end
    BasicPlot(viewport, axes, geoms; kwargs...)
end

function BasicPlot(viewport, axes, geoms; kwargs...)
    specs = Dict(:subplot => unitsquare, kwargs...)
    BasicPlot(viewport, axes, geoms, specs)
end

BasicPlot(; kwargs...) = BasicPlot(Viewport(), Axes{nothing}(), Geometry[]; kwargs...)

BasicPlot(p::BasicPlot) = p

macro PlotType(typename, extrafields...)
    fields = quote end
    for f in extrafields
        # if typeof(f) <: Expr && f.head ∈ (:(=), :kw)
        #     push!(fields.args, :($(f.args[1])::$(f.args[2])))
        # end
        push!(fields.args, f)
    end
    expr = quote
        mutable struct $typename <: AbstractPlot
            basicplot::BasicPlot
            $fields
        end
        function Base.getproperty(p::$typename, s::Symbol)
            if s ∈ fieldnames(BasicPlot)
                return getfield(getfield(p, :basicplot), s)
            else
                return getfield(p, s)
            end
        end
    end
    esc(expr)
end

@PlotType PlotObject legend::Legend colorbar::Colorbar

# mutable struct PlotObject <: AbstractPlot
#     viewport::Viewport
#     axes::Axes
#     geoms::Vector{<:Geometry}
#     legend::Legend
#     colorbar::Colorbar
#     specs::Dict
# end

function PlotObject(geoms, axes, legend, colorbar; kwargs...)
    margins = zeros(4)
    if get(kwargs, :colorbar, false) && colorbar ≠ emptycolorbar
        margins[2] = 0.1
    end
    location = get(kwargs, :location, 0)
    # Redefine viewport if legend is set outside
    if legend ≠ emptylegend && location ∈ legend_locations[:right_out]
        margins[2] = legend.size[1]
    end
    basicplot = BasicPlot(geoms, axes; kwargs...)
    PlotObject(basicplot, legend, colorbar)
end

PlotObject(; kwargs...) = PlotObject(BasicPlot(; kwargs...), Legend(), Colorbar())
PlotObject(p::PlotObject) = p

mutable struct PolarHeatmapPlot <: AbstractPlot
    plotobject::PlotObject
end

PlotObject(hm::PolarHeatmapPlot) = hm.plotobject
function Base.getproperty(hm::PolarHeatmapPlot, s::Symbol)
    p = getfield(hm, :plotobject)
    if s == :plotobject
        return p
    else
        return getfield(p, s)
    end
end

# `draw` methods
function draw(p::PlotObject)
    (p.viewport == emptyviewport) && return nothing
    colorspecs = [get(p.specs, :colormap, GR.COLORMAP_VIRIDIS),
                  get(p.specs, :scheme, 0x00000000)]
    setcolors(colorspecs...)
    haskey(p.specs, :backgroundcolor) && fillbackground(p.viewport.outer, cv.options[:backgroundcolor])
    # Define the viewport
    GR.setviewport(p.viewport.inner...)
    draw(p.axes)
    # title and labels

    GR.uselinespec(" ")
    for g in p.geoms
        draw(g)
    end
    location = get(p.specs, :location, 0)
    draw(p.legend, p.geoms, location)
    get(p.specs, :colorbar, false) && draw(p.colorbar)
end

function draw(p::PolarHeatmapPlot)
    (p.viewport == emptyviewport) && return nothing
    draw(p.plotobject)
    # Redraw the axes
    GR.setviewport(p.plotobject.viewport.inner...)
    draw(p.plotobject.axes)
end


function setcolors(colormap, scheme)
    GR.setcolormap(colormap)
    scheme == 0 && (return nothing)
    for colorind in 1:8
        color = colors[colorind, scheme]
        if colorind == 1
            background = color
        end
        r, g, b = RGB(color)
        GR.setcolorrep(colorind - 1, r, g, b)
        if scheme != 1
            GR.setcolorrep(distinct_cmap[colorind], r, g, b)
        end
    end
    r, g, b = RGB(colors[1, scheme])
    rdiff, gdiff, bdiff = RGB(colors[2, scheme]) - [r, g, b]
    for colorind in 1:12
        f = (colorind - 1) / 11.0
        GR.setcolorrep(92 - colorind, r + f*rdiff, g + f*gdiff, b + f*bdiff)
    end
    return nothing
end

function fillbackground(rectndc, color)
    GR.savestate()
    GR.selntran(0)
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(color)
    GR.fillrect(rectndc...)
    GR.selntran(1)
    GR.restorestate()
end
