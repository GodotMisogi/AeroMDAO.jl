include("../src/AeroMDAO.jl")
include("../src/FoilParametrization.jl")

using .AeroMDAO:  Point3D, Point2D, Wing, projected_area, Foil
using .FoilParametrization: read_foil, linspace, coords_to_camthick, split_foil, cosine_foil
using PyPlot

foilpath = "airfoil_database/ys930.dat"

# Wing section setup
num_secs = 5
xs = zeros(num_secs)
ys = linspace(0, 2, num_secs)
zs = zeros(num_secs)

chords = repeat([2.0], num_secs)    # Chord lengths
twists = zeros(num_secs)            # Twists
coords = read_foil(foilpath)
airfoil = Foil(coords)

foils = [ coords for n in 1:num_secs ]
airfoils = Foil.(foils) # Airfoils

# Camber-thickness transformations
xs = coords_to_camthick(coords)
println(xs)
# plot(xs[:,1], xs[:,2], marker="o")
# plot(xs[:,1], xs[:,3])
# axis("equal")
# show()

# secs = [ WingSection(x...) for x in zip(locs, chords, twists, foils) ]

# wing_loc = Point3D{Float64}(0.0, 0.0, 0.0)
# wing = Wing(wing_loc, secs)

# println(projected_area(wing))