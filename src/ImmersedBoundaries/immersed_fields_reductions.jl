using Oceananigans.Fields: AbstractField, ReducedField
using Oceananigans.AbstractOperations: AbstractOperation, MaskedOperation
using CUDA: @allowscalar

import Statistics: norm
import Oceananigans.Fields: mask_operator

# ###
# ###  reduction operations involving immersed boundary grids exclude the immersed region 
# ### (we exclude also the values on the faces of the immersed boundary with `solid_interface`)
# ###

const ImmersedField = AbstractField{<:Any, <:Any, <:Any, <:ImmersedBoundaryGrid}
const ImmersedMask  = MaskedOperation{<:Any, <:Any, <:Any, <:Any, <:ImmersedBoundaryGrid}

@inline immersed_condition(i, j, k, mo::ImmersedMask{LX, LY, LZ}) where {LX, LY, LZ} = solid_interface(LX(), LY(), LZ(), i, j, k, mo.grid) 

@inline function masked_operation(obj::ImmersedField, mask) 
    return mask_operator(location(obj)..., obj, obj.grid, mask, immersed_condition)
end

@inline masked_length(c::AbstractField) = length(c)
@inline masked_length(c::ImmersedField) = sum(mask_operator(c, 0))

Statistics.dot(a::ImmersedField, b::Field) = Statistics.dot(mask_operator(a, 0), b)
Statistics.dot(a::Field, b::ImmersedField) = Statistics.dot(mask_operator(a, 0), b)

function Statistics.norm(c::ImmersedField)
    r = zeros(c.grid, 1)
    Base.mapreducedim!(x -> x * x, +, r, mask_operator(c, 0))
    return @allowscalar sqrt(r[1])
end

Statistics._mean(f, c::ImmersedField, ::Colon) = sum(f, c) / masked_length(c)

function Statistics._mean(f, c::ImmersedField; dims)
    r = sum(f, c; dims = dims)
    n = sum(f, mask_operator(c / c, 0); dims = dims)

    @show r, n
    return r ./ n
end

Statistics._mean(c::ImmersedField; dims) = Statistics._mean(identity, c, dims=dims)