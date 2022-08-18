"""
    doublet_matrix(panels_1, panels_2)

Create the matrix of doublet potential influence coefficients between pairs of `panels₁` and `panels₂`.
"""
doublet_matrix(panels_1, panels_2) = [ doublet_influence(panel_j, panel_i) for panel_i in panels_1, panel_j in panels_2 ]

"""
    doublet_matrix(panels_1, panels_2)

Create the matrix of source potential influence coefficients between pairs of `panels₁` and `panels₂`.
"""
source_matrix(panels_1, panels_2) = [ source_influence(panel_j, panel_i) for panel_i in panels_1, panel_j in panels_2 ]

"""
    kutta_condition(panels)

Create the vector describing Morino's Kutta condition given `Panel2Ds`.
"""
kutta_condition(panels :: AbstractVector{<:AbstractPanel2D}) = [ 1 zeros(length(panels) - 2)' -1 ]

"""
    wake_vector(woke_panel :: AbstractPanel2D, panels)

Create the vector of doublet potential influence coefficients from the wake on the panels given the wake panel and the array of `Panel2Ds`.
"""
wake_vector(woke_panel :: AbstractPanel2D, panels) = doublet_influence.(Ref(woke_panel), panels)

"""
    influence_matrix(panels, wake_panel :: AbstractPanel2D)

Assemble the Aerodynamic Influence Coefficient matrix consisting of the doublet matrix, wake vector, Kutta condition given `Panel2Ds` and the wake panel.
"""
influence_matrix(panels, woke_panel :: AbstractPanel2D) =
    [ doublet_matrix(panels, panels)  wake_vector(woke_panel, panels) ;
        kutta_condition(panels)                      1.               ]

"""
    source_strengths(panels, freestream)

Create the vector of source strengths for the Dirichlet boundary condition ``σ = \\vec U_{\\infty} \\cdot \\hat{n}`` given Panel2Ds and a Uniform2D.
"""
source_strengths(panels, u) = dot.(Ref(u), panel_normal.(panels))

"""
    boundary_vector(panels, u)

Create the vector for the boundary condition of the problem given an array of Panel2Ds and velocity ``u``.
"""
boundary_vector(panels, u) = [ - source_matrix(panels, panels) * source_strengths(panels, u); 0 ]

# boundary_vector(colpoints, u, r_te) = [ dot.(colpoints, Ref(u)); dot(u, r_te) ]

boundary_vector(panels, u, r_te) = [ dot.(collocation_point.(panels), Ref(u)); dot(u, r_te) ]

function boundary_vector(panels :: Vector{<: AbstractPanel2D}, wakes :: Vector{<: AbstractPanel2D}, u)
    source_panels = [ panels; wakes ]
    [ - source_matrix(panels, source_panels) * source_strengths(source_panels, u); 0 ]
end

"""
    solve_linear(panels, u, sources, bound)

Solve the system of equations ``[AIC][\\phi] = [\\vec{U} \\cdot \\hat{n}] - B[\\sigma]`` condition given the array of Panel2Ds, a velocity ``\\vec U``, a condition whether to disable source terms (``σ = 0``), and an optional named bound for the length of the wake.
"""
function solve_linear(panels, u, α, r_te, sources :: Bool; bound = 1e2)
    # Wake
    woke_panel  = wake_panel(panels, bound, α)
    woke_vector = wake_vector(woke_panel, panels)
    woke_matrix = [ -woke_vector zeros(length(panels), length(panels) -2) woke_vector ]

    # AI
    AIC     = doublet_matrix(panels, panels) + woke_matrix
    boco    = dot.(collocation_point.(panels), Ref(u)) - woke_vector * dot(u, r_te)

    # AIC
    # AIC   = influence_matrix(panels, woke_panel)
    # boco  = boundary_vector(ifelse(sources, panels, collocation_point.(panels)), u, r_te) - [ woke_vector; 0 ] .* dot(u, r_te)

    AIC \ boco, AIC, boco
end

"""
    surface_velocities(panels, φs, u, sources :: Bool)

Compute the surface speeds and panel distances given the array of `Panel2D`s, their associated doublet strengths ``φ``s, the velocity ``u``, and a condition whether to disable source terms (``σ = 0``).
"""
function surface_velocities(φs, Δrs, θs, u, sources :: Bool)
    # Δrs   = midpair_map(distance, panels)
    # Δφs   = -midpair_map(-, φs[1:end-1])

    Δφs  = @views φs[1:end-1] - φs[2:end]
    vels = map((Δφ, Δr, θ) -> Δφ / Δr + ifelse(sources, dot(u, θ), 0.), Δφs, Δrs, θs)

    vels
end

## WAKE VERSIONS
#==========================#

"""
    solve_linear(panels, u, wakes)

Solve the linear aerodynamic system given the array of Panel2Ds, a velocity ``\\vec U``, a vector of wake `Panel2D`s, and an optional named bound for the length of the wake.

The system of equations ``A[\\phi] = [\\vec{U} \\cdot \\hat{n}] - B[\\sigma]`` is solved, where ``A`` is the doublet influence coefficient matrix, ``\\phi`` is the vector of doublet strengths, ``B`` is the source influence coefficient matrix, and ``\\sigma`` is the vector of source strengths.
"""
function solve_linear(panels :: AbstractArray{<:AbstractPanel2D}, u, wakes)
    AIC  = influence_matrix(panels, wakes)
    boco = boundary_vector(panels, u, [0., 0.])

    AIC \ boco, AIC, boco
end

# ==========================
#      3D Wake Version
# ==========================

# kutta_condition(npanf, npanw) = [I(npanw) zeros(npanw, npanf-2*npanw) -I(npanw) -I(npanw)]

# function solve_linear(panels :: AbstractMatrix{<:AbstractPanel3D}, U, fs, wakes)
#     V∞ = U * velocity(fs)

#     AIC = influence_matrix(panels, wakes)
#     boco = boundary_vector(panels, wakes, V∞)

#     return AIC \ boco, AIC, boco
# end

# function influence_matrix(panels :: AbstractMatrix{<:AbstractPanel3D}, wakes)
#     # Reshape panel into column vector
#     panelview = @view permutedims(panels)[:]

#     npanf, npanw = length(panels), length(wakes)

#     AIC = zeros(npanf+npanw, npanf+npanw)
#     AIC_ff = @view AIC[1:npanf,     1:npanf     ]
#     AIC_wf = @view AIC[1:npanf,     npanf+1:end ]
#     AIC_kc = @view AIC[npanf+1:end,     :       ]

#     # Foil-Foil interaction
#     AIC_ff .= doublet_matrix(panelview, panelview)

#     # Wake-Foil interaction
#     AIC_wf .= doublet_matrix(panelview, wakes)

#     # Kutta Condition
#     AIC_kc .= kutta_condition(npanf, npanw)

#     return AIC
# end

# function boundary_vector(panels :: AbstractMatrix{<: AbstractPanel3D}, wakes, V∞)
#     panelview = @view permutedims(panels)[:]
#     B = source_matrix(panelview, panelview)
#     σ = dot.(Ref(V∞), panel_normal.(panelview))

#     return -[B * σ, zeros(length(wakes))]
# end

# ==========================
#   Needs to be optimised
# ==========================
# function influence_matrix(panels :: AbstractMatrix{<:AbstractPanel3D}, wakes)
#     # Reshape panel into column vector
#     panelview = @view permutedims(panels)[:]
#     allpans = [panelview; wakes]

#     npanf, npanw = length(panels), length(wakes)

#     AIC = zeros(npanf+npanw, npanf+npanw)
#     AIC_wf = @view AIC[1:npanf, :]
#     AIC_ku = @view AIC[npanf+1:end, :]

#     for k=1:npanf+npanw
#         panelK = allpans[k]
#         tr = get_transformation(panelK)
#         for i=1:npanf
#             panelI = allpans[i]
#             panel, point = tr(panelK), tr(collocation_point(panelI))
#             AIC_wf[i,k] = ifelse(panelK == panelI, 0.5, quadrilateral_doublet_potential(1, panel, point))
#         end
#     end

#     for i=1:npanw
#         AIC_ku[i, i] = 1
#         AIC_ku[i, i+npanf-npanw] = -1
#         AIC_ku[i, i+npanf] = -1
#     end

#     return AIC
# end

function doublet_velocity_matrix(collpanels, inflpanels)
    VIM = zeros(Point3D{eltype(collpanels[1].p1)}, length(collpanels), length(inflpanels))
    for i ∈ indices(collpanels)
        point_i = collocation_point(collpanels[i])
        for j ∈ indices(inflpanels)
            panel_j = inflpanels[j]
            VIM[i,j] = quadrilateral_doublet_velocity(panel_j, point_i)
        end
    end
    return VIM
end

function kutta_condition!(AIC_ku, npanf, npanw)
    AIC_ku[ : ,     2       : npanw+1] .=  I(npanw)
    AIC_ku[ : , npanf-npanw : npanf-1] .= -I(npanw)
    AIC_ku[ : , end-npanw+1 : end    ] .= -I(npanw)
end

@views function velocity_influence_matrix(panels :: AbstractMatrix{<:AbstractPanel3D}, wakes)
    # Reshape panel into column vector
    ps = permutedims(panels)[:]
    allps = [ps; wakes]
    npanf, npanw = length(panels), length(wakes)

    # # ------------ Resulted AIC is singular ------------
    # AIC = zeros(npanf+npanw, npanf+npanw)
    # AIC_wf = AIC[1:npanf, :]
    # AIC_ku = AIC[npanf+1:end, :]

    # AIC_wf .= doublet_velocity_matrix(ps, allps) .⋅ panel_normal.(ps)
    # kutta_condition!(AIC_ku, npanf, npanw)
    # # ------------ Resulted AIC is singular ------------

    AIC = zeros(npanf+npanw+1, npanf+npanw)
    VIM = doublet_velocity_matrix(ps, allps)
    AIC[1:npanf,:] .= VIM .⋅ panel_normal.(ps)
    kutta_condition!(AIC[npanf+1:end-1,:], npanf, npanw)
    AIC[end,1:npanf] .= 1

    return AIC, VIM
end

@views function velocity_boundary_vector(panels :: AbstractMatrix{<: AbstractPanel3D}, wakes, V∞)
    ps = permutedims(panels)[:]
    # # ------------------------ Resulted BV is singular ------------------------
    # [-dot.(Ref(V∞), panel_normal.(ps)); zeros(length(wakes))]
    # # ------------------------ Resulted BV is singular ------------------------
    npanf, npanw = length(panels), length(wakes)
    bv = zeros(npanw + npanf + 1)
    bv[1:npanf] .= -dot.(Ref(V∞), panel_normal.(ps))
    bv[npanf+1:end] .= 0
    return  bv
end

function solve_linear_neumann(panels :: AbstractMatrix{<:AbstractPanel3D}, U, fs, wakes)
    V∞ = U * velocity(fs)

    AIC, VIM = velocity_influence_matrix(panels, wakes)
    boco = velocity_boundary_vector(panels, wakes, V∞)
    φ = AIC \ boco    # solve least square problem by (AIC' * AIC) \ (AIC' * boco)
    return φ, AIC, boco, VIM
end