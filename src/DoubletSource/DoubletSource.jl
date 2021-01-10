module DoubletSource

using LinearAlgebra
using Base.Iterators
using StaticArrays
using Statistics
using TimerOutputs

## Non-dimensionalization
#===========================================================================#

include("../Tools/NonDimensional.jl")
import .NonDimensional: pressure_coefficient

## Math tools
#===========================================================================#

include("../Tools/MathTools.jl")
using .MathTools: rotation, inverse_rotation, midpair_map

## Solutions to Laplace's equation
#===========================================================================#

include("../Tools/Laplace.jl")
import .Laplace: source_potential, doublet_potential

## Panels
#===========================================================================#

include("../Geometry/PanelGeometry.jl")
using .PanelGeometry: Panel, Panel2D, split_panels, panel_dist, panel_length, panel_normal, panel_angle, panel_normal, panel_tangent, point1, point2, collocation_point, trans_panel

export Panel, Panel2D, collocation_point

## Matrix helpers
#===========================================================================#

function doublet_influence(panel_j :: Panel2D, panel_i :: Panel2D)
    xp, yp = trans_panel(panel_j, panel_i)
    doublet_potential(1., xp, yp, 0., panel_length(panel_j))
end

function source_influence(panel_j :: Panel2D, panel_i :: Panel2D)
    xp, yp = trans_panel(panel_j, panel_i)
    source_potential(1., xp, yp, 0., panel_length(panel_j))
end

boundary_condition(panel_j :: Panel2D, panel_i :: Panel2D, u) = source_influence(panel_j, panel_i) * dot(u, panel_normal(panel_j))

function wake_panel(panels, bound)
    lastx, lasty = (point2 ∘ last)(panels)
    Panel2D(SVector(lastx, lasty), SVector(bound * lastx, lasty))
end

## Dynamics helpers
#===========================================================================#

panel_velocity(dφ, dr, u, α) = dφ / dr + dot(u, α)

lift_coefficient(cp :: Real, dist_colpoints :: Real, panel_angle :: Real) = - cp * dist_colpoints * cos(panel_angle)

lift_coefficient(wake_strength :: Real, speed :: Real) = - 2. * wake_strength / speed

## Matrix assembly
#===========================================================================#

include("matrix_func.jl")
include("matrix_prealloc.jl")

export solve_problem

function solve_problem(panels :: AbstractVector{<: Panel2D}, u :: SVector{2, <: Real})
    # @timeit "Solve System" 
    φs = solve_strengths(panels, u)
    # @timeit "Lift Coefficient" 
    cl = lift_coefficient(panels, φs, u)

    # @timeit "Solve System (Pre-allocated)" 
    # φs = solve_strengths_prealloc(panels, u)
    # @timeit "Lift Coefficient (Pre-allocated)" 
    # cl = lift_coefficient_prealloc(panels, φs, u)

    φs, cl
end


end