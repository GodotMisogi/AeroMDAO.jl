## Nearfield dynamics
#==========================================================================================#

kutta_joukowsky(ρ, Γ, V, l) = ρ * Γ * V × l

"""

Evaluate the induced velocity at a given location ``r``, by summing over the trailing legs' velocities of Horseshoes with vortex strengths ``\\Gamma``s pointing in the direction ``\\hat U``.
"""
induced_trailing_velocity(r, horseshoes, Γs, U_hat) = sum(trailing_velocity.(Ref(r), horseshoes, Γs, Ref(U_hat)))

"""
    midpoint_velocity(r, Ω, horseshoes, Γs, U)

Evaluate the total velocity at a given location ``r`` by summing over the velocities induced by the trailing legs of Horseshoes with vortex strengths ``\\Gamma``s, of the rotation rates ``\\Omega``, and of the freestream flow vector ``U`` in the aircraft reference frame.
"""
midpoint_velocity(r, horseshoes, Γs, U, Ω) = induced_trailing_velocity(r, horseshoes, Γs, -normalize(U)) - (U + Ω × r)

"""
    nearfield_forces(Γ_comp, hs_comp, Γs, horseshoes, U, Ω, ρ)

Compute the nearfield forces via the local Kutta-Jowkowski theorem given an array of horseshoes `hs_comp` to compute the forces on a component, their associated vortex strengths `Γ_comp`, the arrays of horseshoes and vortex strengths `Γs`  of the entire aircraft, the freestream flow vector ``U``, rotation rates ``\\Omega``, and a density ``\\rho``. The velocities are evaluated at the midpoint of the bound leg of each horseshoe, excluding the contribution of the bound leg.
"""
nearfield_forces(Γ_focus, hs_focus, Γs, horseshoes, U, Ω, ρ) = kutta_joukowsky.(Ref(ρ), Γ_focus, midpoint_velocity.(bound_leg_center.(hs_focus), Ref(horseshoes), Ref(Γs), Ref(U), Ref(Ω)), bound_leg_vector.(hs_focus))

nearfield_drag(force, U) = -dot(force, normalize(U))

horseshoe_moment(horseshoe :: Horseshoe, force, r_ref) = (bound_leg_center(horseshoe) - r_ref) × force

nearfield_moments(horseshoes, forces, r_ref) = horseshoe_moment.(horseshoes, forces, Ref(r_ref))

function nearfield_dynamics(Γ_focus, hs_focus, Γs, horseshoes, U, Ω, ρ, r_ref)
    geom_forces  = nearfield_forces(Γ_focus, hs_focus, Γs, horseshoes, U, Ω, ρ)
    geom_moments = nearfield_moments(hs_focus, geom_forces, r_ref)

    geom_forces, geom_moments
end