##
using Zygote
import Base: +, -, zero
import Base.Iterators
using StaticArrays

struct Point
    x :: Real
    y :: Real
end
  
width(p::Point) = p.x
height(p::Point) = p.y

a::Point + b::Point = Point(width(a) + width(b), height(a) + height(b))
a::Point - b::Point = Point(width(a) - width(b), height(a) - height(b))
dist(p::Point) = sqrt(width(p)^2 + height(p)^2)
zero(:: Point) = Point(0, 0)

##
@Zygote.adjoint (T :: Type{<:SVector})(xs :: Number ...) = T(xs...), dv -> (nothing, dv...)
@Zygote.adjoint (T :: Type{<:SVector})(x :: AbstractVector) = T(x), dv -> (nothing, dv)

@Zygote.adjoint enumerate(xs) = enumerate(xs), diys -> (map(last, diys),)

_ndims(::Base.HasShape{d}) where {d} = d
_ndims(x) = Base.IteratorSize(x) isa Base.HasShape ? _ndims(Base.IteratorSize(x)) : 1

@Zygote.adjoint function Iterators.product(xs...)
                    d = 1
                    Iterators.product(xs...), dy -> ntuple(length(xs)) do n
                        nd = _ndims(xs[n])
                        dims = ntuple(i -> i < d ? i : i+nd, ndims(dy)-nd)
                        d += nd
                        func = sum(y->y[n], dy; dims=dims)
                        ax = axes(xs[n])
                        reshape(func, ax)
                    end
                end

@Zygote.adjoint width(p::Point) = p.x, x̄ -> (Point(x̄, 0),)
@Zygote.adjoint height(p::Point) = p.y, ȳ -> (Point(0, ȳ),)
@Zygote.adjoint Point(a, b) = Point(a, b), p̄ -> (p̄.x, p̄.y)


##
xs = Point.((1:4), (11:14))
not_perimeter(p1 :: Point, p2 :: Point) = p1 === p2 ? 0.5 : 1 / width(p1)  + 1 / height(p2)
gradient(not_perimeter, xs[3], xs[5])

##
grad_pts = gradient(xs -> sum(map(pts -> not_perimeter(pts...), product(xs, xs))), xs)
