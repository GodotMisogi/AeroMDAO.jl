using Base.Math
using Base.Iterators
using DelimitedFiles

#-------------------------AIRFOIL----------------------#

"""
Airfoil structure consisting of foil coordinates as an array of points.
"""
struct Foil <: Aircraft
    coords :: AbstractArray{<: Real, 2} # The foil profile as an array of coordinates, must be in Selig format.
end

"""
Scales the coordinates of a Foil, usually to some chord length.
"""
scale_foil(foil :: Foil, chord) = chord * foil.coords

"""
Translates the coordinates of a Foil by (x, y, z).
"""
shift_foil(foil :: Foil, x, y, z) = [ x y z ] .+ foil.coords

"""
Returns a Foil with cosine spacing for a given number of points. 
"""
cut_foil(foil :: Foil, num) = Foil(cosine_foil(foil.coords, n = num))

"""
Computes the camber-thickness distribution of a Foil with cosine spacing..
"""
camber_thickness(foil :: Foil, num) = Foil(foil_camthick(cosine_foil(foil.coords), num + 1))

"""
Projects a Foil onto the x-z plane at y = 0.
"""
coordinates(foil :: Foil) = [ foil.coords[:,1] (zeros ∘ length)(foil.coords[:,1]) foil.coords[:,2] ]


#-------------FOIL PROCESSING------------------#

"""
Reads a '.dat' file consisting of 2D coordinates, for an airfoil.
"""
function read_foil(path :: String; header = true)
    readdlm(path, skipstart = header ? 1 : 0)
end

function split_foil(coords)
    for (i, (xp, yp, x, y, xn, yn)) ∈ (enumerate ∘ eachrow ∘ adj3)(coords)
        if x < xp && x < xn
            if slope(x, y, xp, yp) >= slope(x, y, xn, yn)
                return splitat(i, coords)
            else
                return splitat(i, coords[end:-1:1,:])
            end
        end
    end
    (coords, [])
end

paneller(foil :: Foil, num_panels :: Integer) = let coords = cosine_foil(foil.coords, n = num_panels); [ Panel2D((xs, ys), (xe, ye)) for (xs, ys, xe, ye) ∈ eachrow([ coords[2:end,:] coords[1:end-1,:] ]) ][end:-1:1] end

"""
Discretises a foil profile into panels by projecting the x-coordinates of a circle onto the geometry.
"""
function cosine_foil(coords :: AbstractArray{<: Real, 2}; n :: Integer = 40)
    upper, lower = split_foil(coords)
    upper = [upper; lower[1,:]'] # Append leading edge from lower to upper
    upper_cos, lower_cos = cosine_interp(upper[end:-1:1,:], n), cosine_interp(lower, n)

    [ upper_cos[end:-1:2,:]; 
      lower_cos ]
end

#-------------------CST METHOD--------------------#

# Basic shape function
function shape_function(x :: Real, basis_func :: Function, coeffs :: AbstractVector{<: Real}, coeff_LE :: Real = 0)
    n = length(coeffs)
    terms = [ basis_func(x, n - 1, i) for i in 0:n-1 ]
    sum(coeffs .* terms) + coeff_LE * (x^0.5) * (1 - x)^(n - 0.5)
end

# Computing coordinates
cst_coords(class_func :: Function, basis_func :: Function, x :: Real, alphas :: AbstractVector{<: Real}, dz :: Real, coeff_LE :: Real = 0) = class_func(x) * shape_function(x, basis_func, alphas, coeff_LE) + x * dz

#--------------BERNSTEIN BASIS-----------------#

"""
Bernstein basis for class function.
"""
bernstein_class(x, N1 = 0.5, N2 = 1) = x^N1 * (1 - x)^N2 

"""
Bernstein basis element.
"""
bernstein_basis(x, n, k) = binomial(n, k) * bernstein_class(x, k, n - k)

"""
Defines a cosine-spaced airfoil using the Class Shape Transformation method on a Bernstein polynomial basis, with support for leading edge modifications.
"""
function kulfan_CST(alpha_u :: AbstractVector{<: Real}, alpha_l :: AbstractVector{<: Real}, (dz_u, dz_l) :: NTuple{2, <: Real}, coeff_LE :: Real = 0, num_points :: Integer = 40)
    # Cosine spacing for airfoil of unit chord length
    xs = cosine_dist(0.5, 1, num_points)

    # λ-function for Bernstein polynomials
    bernie = (x, alphas, dz) -> cst_coords(bernstein_class, bernstein_basis, x, alphas, dz, coeff_LE)

    # Upper and lower surface generation
    upper_surf = [ bernie(x, alpha_u, dz_u) for x ∈ xs ]
    lower_surf = [ bernie(x, alpha_l, dz_l) for x ∈ xs ]

    # Counter-clockwise ordering
    [ [xs upper_surf][end:-1:2,:]; 
       xs lower_surf ]
end

function camber_CST(alpha_cam :: AbstractVector{<: Real}, alpha_thicc :: AbstractVector{<: Real}, (dz_cam, dz_thicc) :: NTuple{2, <: Real}, coeff_LE :: Real = 0, num_points :: Integer = 40)
    # Cosine spacing for airfoil of unit chord length
    xs = cosine_dist(0.5, 1, num_points)

    # λ-function for Bernstein polynomials
    bernie = (x, alphas, dz) -> cst_coords(bernstein_class, bernstein_basis, x, alphas, dz, coeff_LE)

    # Upper and lower surface generation
    cam = [ bernie(x, alpha_cam, dz_cam) for x ∈ xs ]
    thicc = [ bernie(x, alpha_thicc, dz_thicc) for x ∈ xs ]

    camthick_foil(xs, cam, thicc)
end

function coords_to_CST(coords, num_dvs)
    S_matrix = hcat((bernstein_class.(coords[:,1]) .* bernstein_basis.(coords[:,1], num_dvs - 1, i) for i in 0:num_dvs - 1)...)

    alphas = S_matrix \ coords[:,2]
    
    return alphas
end

function camthick_to_CST(coords, num_dvs)
    xs, camber, thickness = (columns ∘ foil_camthick)(coords)

    alpha_cam = coords_to_CST([ xs camber ], num_dvs)
    alpha_thick = coords_to_CST([ xs thickness ], num_dvs)
    
    alpha_cam, alpha_thick
end

#--------------CAMBER-THICKNESS REPRESENTATION----------------#


"""
Converts an airfoil to its camber-thickness representation in cosine spacing.
"""
function foil_camthick(coords :: AbstractArray{<: Real, 2}, num :: Integer = 40)
    upper, lower = split_foil(cosine_foil(coords, n = num))

    xs, y_LE = lower[:,1], lower[1,2]   # Getting abscissa and leading edge ordinate
    y_upper, y_lower = upper[end:-1:1,2], lower[2:end,2] # Excluding leading edge point

    camber = [ y_LE; (y_upper .+ y_lower) / 2 ]
    thickness = [ 0; y_upper .- y_lower ]

    [ xs camber thickness ]
end

"""
Converts the camber-thickness representation to coordinates.
"""
camthick_foil(xs, camber, thickness) = [ [xs camber .+ thickness / 2][end:-1:2,:]; xs camber .- thickness / 2 ]

#--------NACA PARAMETRIZATION------------#

# NACA 4-digit parameter functions
naca4_thickness(t_by_c, xc, sharp_trailing_edge :: Bool) = 5 * t_by_c * (0.2969 * √xc - 0.1260 * xc - 0.3516 * xc^2 + 0.2843 * xc^3 - (sharp_trailing_edge ? 0.1036 : 0.1015) * xc^4)
naca4_camberline(pos, cam, xc) = xc < pos ? (cam / pos^2) * xc * (2 * pos - xc) : cam / (1 - pos)^2 * ( (1 - 2 * pos) + 2 * pos * xc - xc^2)
naca4_gradient(pos, cam, xc) = atan(2 * cam / (xc < pos ? pos^2 : (1 - pos)^2) * (pos - xc))

function naca4(digits :: NTuple{4, <: Real}, n :: Integer = 40; sharp_trailing_edge :: Bool = false)
    # Camber
    cam = digits[1] / 100
    # Position
    pos = digits[2] / 10
    # Thickness-to-chord ratio
    t_by_c = (10 * digits[3] + digits[4]) / 100

    # Cosine spacing
    xs = cosine_dist(0.5, 1.0, n)

    # Thickness distribution
    thickness = [ naca4_thickness(t_by_c, xc, sharp_trailing_edge) for xc in xs ]
    
    if pos == 0 || cam == 0
        x_upper = xs
        y_upper = thickness
        x_lower = xs
        y_lower = -thickness
    else
        # Compute camberline
        camber = [ naca4_camberline(pos, cam, xc) for xc in xs ]
        # Compute gradients
        gradients = [ naca4_gradient(pos, cam, xc) for xc in xs ]
        # Upper surface
        x_upper = xs .- thickness .* sin.(gradients) 
        y_upper = camber .+ thickness .* cos.(gradients)
        # Lower surface
        x_lower = xs .+ thickness .* sin.(gradients) 
        y_lower = camber .- thickness .* cos.(gradients)
    end
    [ [x_upper y_upper][end:-1:2,:]; 
       x_lower y_lower ]
end