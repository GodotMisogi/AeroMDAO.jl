"""
    stream_velocity(r, horseshoes, Γs, V, Ω)

Evaluates the total induced velocity at a point `r` given Horseshoes, vortex strengths `Γ`s, rotation rates `Ω`, and freestream flow vector `freestream` in the global reference frame.
"""
stream_velocity(r :: SVector{3, <: Real}, horseshoes :: AbstractVector{<: Horseshoe}, Γs :: AbstractVector{<: Real}, V :: SVector{3, <: Real}, Ω :: SVector{3, Real}) = sum(velocity(r, horseshoe, Γ, V / norm(V)) for (horseshoe, Γ) ∈ zip(horseshoes, Γs)) .+ V .+ Ω × r

"""
    streamlines(point, freestream :: Freestream, horseshoes, Γs, length, num_steps)

Computes the streamlines from a given starting point, a Freestream, Horseshoes and their associated strengths Γs with a specified length of the streamline and number of evaluation points.
"""
function streamlines(point :: SVector{3, <: Real}, freestream :: Freestream, horseshoes :: AbstractVector{<: Horseshoe}, Γs :: AbstractVector{<: Real}, length :: Real, num_steps :: Integer)
    streamlines = fill(point, num_steps)
    V = velocity(freestream)
    cuck(x) = stream_velocity(x, horseshoes, Γs, V, freestream.Ω)
    @timeit "Iterating" for i ∈ 2:num_steps
        @timeit "Updating Velocity" update = cuck(streamlines[i-1])
        @timeit "Adding Streamline" streamlines[i] = streamlines[i-1] .+ (update / norm(update) * length / num_steps)
    end
    streamlines
end

"""
    streamlines(freestream :: Freestream, horseshoes, Γs, length, num_steps)

Computes the streamlines from the collocation points of panels associated with given Horseshoes and their associated strengths Γs, in a given Freestream with a specified length of the streamline and number of evaluation points.
"""
streamlines(freestream :: Freestream, points, horseshoes :: AbstractVector{<: Horseshoe}, Γs :: AbstractVector{<: Real}, length :: Real, num_steps :: Integer) = streamlines.(points, Ref(freestream), Ref(horseshoes), Ref(Γs), length, num_steps)
