export EntropicVector
export PrimalEntropy, cardminusentropy, cardentropy, invalidfentropy, matusrentropy, entropyfrompdf, subpdf, toTikz
export DualEntropy, DualEntropyLift, nonnegative, nondecreasing, submodular, submodulareq, ingleton

# Entropic Vector

function ntodim(n::Int)
  # It will works with bitsets which are unsigned
  Unsigned((1 << n) - 1)
end
function ntodim(n::Vector{Int})
  map(ntodim, n)
end

function dimton(N)
  n = Int(round(log2(N + 1)))
  if ntodim(n) != N
    error("Illegal size of entropic constraint")
  end
  n
end

abstract EntropicVector{N, T<:Real} <: AbstractArray{T, 1}

Base.size{N}(h::EntropicVector{N}) = (N,)
Base.linearindexing(::Type{EntropicVector}) = Base.LinearFast()
#Base.getindex(h::EntropicVector, i::Int) = h.h[i]
#Base.getindex{T}(h::EntropicVector, i::AbstractArray{T,1}) = EntropicVector(h.h[i])
Base.getindex(h::EntropicVector, i) = h.h[i]
Base.setindex!{N, T}(h::EntropicVector{N, T}, v::T, i::Int) = h.h[i] = v

#function *(x, h::EntropicVector)
#  EntropicVector(x * h.h)
#end

#function entropyof(p::AbstractArray{Real, n})
#  println(n)
#  for i in 0b1:ntodim(n)
#  end
#end

abstract AbstractDualEntropy{N, T<:Real} <: EntropicVector{N, T}

type DualEntropy{N, T<:Real} <: AbstractDualEntropy{N, T}
  n::Int
  h::AbstractArray{T, 1}
  liftid::Int
  equality::Bool

  function DualEntropy(n::Int, liftid::Int=1, equality::Bool=false)
    if ntodim(n) != N
      error("Number of variables and dimension does not match")
    end
    if liftid < 1
      error("liftid must be positive")
    end
    new(n, Array{T, 1}(N), liftid, equality)
  end

  function DualEntropy(h::AbstractArray{T, 1}, liftid::Int=1, equality::Bool=false)
    if N != length(h)
      error("Dimension N should be equal to the length of h")
    end
    n = Int(round(log2(N + 1)))
    if ntodim(n) != N
      error("Illegal size of entropic constraint")
    end
    new(n, h, liftid, equality)
  end

end

DualEntropy{T<:Real}(h::AbstractArray{T, 1}, liftid::Int=1, equality::Bool=false) = DualEntropy{length(h), T}(h, liftid, equality)

function Base.convert{N, T<:Real}(::Type{HRepresentation{T}}, h::Vector{DualEntropy{N, T}})
  linset = IntSet([])
  m = length(h)
  A = Matrix{T}(m, N)
  for i in 1:m
    A[i,:] = -h[i].h
    if h[i].equality
      push!(linset, i)
    end
  end
  HRepresentation(A, zeros(T, m), linset)
end
function Base.convert{N, T<:Real}(::Type{HRepresentation{T}}, h::DualEntropy{N, T})
  linset = IntSet([])
  if h.equality
    push!(linset, 1)
  end
  HRepresentation(-h.h', zeros(T, 1), linset)
end

function setequality(h::DualEntropy, eq::Bool)
  h.equality = eq
  h
end

#Base.convert{N, T}(::Type{HRepresentation{T}}, h::DualEntropy{N, T}) = Base.convert(HRepresentation{T}, [h])
#Doesn't work

type DualEntropyLift{N, T<:Real} <: AbstractDualEntropy{N, T}
  n::Array{Int,1}
  h::AbstractArray{T, 1}
  equality::Bool

  function DualEntropyLift(n::Array{Int,1}, h::Array{T,1}=Array{T, 1}(N), equality::Bool=false)
    if sum(ntodim(n)) != N
      error("Number of variables and dimension does not match")
    end
    if N != length(h)
      error("Dimension N should be equal to the length of h")
    end
    new(n, h, equality)
  end

# function DualEntropyLift(n::Array{Int,1}, equality::Bool=false) # TODO merge the 2 constructors
#   if sum(ntodim(n)) != N
#     error("Number of variables and dimension does not match")
#   end
#   new(n, Array{T, 1}(N), equality)
# end

end

function DualEntropyLift{N, T}(h::DualEntropy{N, T}, m)
  hlift = zeros(T, m*N)
  offset = (h.liftid-1)*N
  hlift[(offset+1):(offset+N)] = h.h
  DualEntropyLift{m*N, T}(N*ones(Int, m), hlift, h.equality)
end

DualEntropyLift{T<:Real}(n::Array{Int,1}, h::Array{T,1}, equality::Bool=false) = DualEntropyLift{length(h), T}(n, h, equality)

abstract AbstractPrimalEntropy{N, T<:Real} <: EntropicVector{N, T}

type PrimalEntropy{N, T<:Real} <: AbstractPrimalEntropy{N, T}
  n::Int
  h::AbstractArray{T, 1}
  liftid::Int # 1 by default: the first cone of the lift

  function PrimalEntropy(n::Int, liftid::Int=1)
    if ntodim(n) != N
      error("Number of variables and dimension does not match")
    end
    new(n, Array{T, 1}(N), liftid)
  end

  function PrimalEntropy(h::AbstractArray{T, 1}, liftid::Int=1)
    if N != length(h)
      error("Dimension N should be equal to the length of h")
    end
    n = Int(round(log2(N + 1)))
    if ntodim(n) != N
      error("Illegal size of entropic constraint")
    end
    new(n, h, liftid)
  end

end

PrimalEntropy{T<:Real}(h::AbstractArray{T, 1}, liftid::Int=1) = PrimalEntropy{length(h), T}(h, liftid)

type PrimalEntropyLift{N, T<:Real} <: AbstractPrimalEntropy{N, T}
  n::Array{Int,1}
  h::AbstractArray{T, 1}
  liftid::Array{Int,1}

  #function PrimalEntropyLift(n::Array{Int,1}, liftid::Array{Int,1})
  #  new(n, sum(ntodim(n)), liftid)
  #end

  function PrimalEntropyLift(n::Array{Int,1}, h::AbstractArray{T, 1}, liftid::Array{Int,1})
    if sum(ntodim(n)) != N
      error("Number of variables and dimension does not match")
    end
    new(n, h, liftid)
  end

end

PrimalEntropyLift{T<:Real}(n::Array{Int,1}, h::AbstractArray{T, 1}, liftid::Array{Int,1}) = PrimalEntropyLift{sum(ntodim(n)), T}(n, h, liftid)

function (*){N1, N2, T<:Real}(h1::AbstractPrimalEntropy{N1, T}, h2::AbstractPrimalEntropy{N2, T})
  if length(h1.liftid) + length(h2.liftid) != length(union(IntSet(h1.liftid), IntSet(h2.liftid)))
    error("liftids must differ")
  end
  PrimalEntropyLift([h1.n; h2.n], [h1.h; h2.h], [h1.liftid; h2.liftid])
end

Base.convert{N, T<:Real,S<:Real}(::Type{PrimalEntropy{N, T}}, h::PrimalEntropy{N, S}) = PrimalEntropy(Array{T}(h.h))

function subpdf{n}(p::Array{Float64,n}, S::Unsigned)
  cpy = copy(p)
  for j = 1:n
    if !myin(j, S)
      cpy = reducedim(+, cpy, j, 0.)
    end
  end
  cpy
end

subpdf{n}(p::Array{Float64,n}, s::Signed) = subpdf(p, set(s))

function entropyfrompdf{n}(p::Array{Float64,n})
  h = PrimalEntropy{ntodim(n), Float64}(n, 1)
  for i = 0x1:ntodim(n)
    h[i] = -sum(map(xlogx, subpdf(p, i)))
  end
  h
end

(-){N, T<:Real}(h::PrimalEntropy{N, T})     = PrimalEntropy{N, T}(-h.h, h.liftid)
(-){N, T<:Real}(h::DualEntropy{N, T})       =   DualEntropy{N, T}(-h.h, h.liftid)
(-){N, T<:Real}(h::PrimalEntropyLift{N, T}) = PrimalEntropyLift{N, T}(h.n, -h.h, h.liftid)
(-){N, T<:Real}(h::DualEntropyLift{N, T})   =   DualEntropyLift{N, T}(h.n, -h.h, h.equality)

function constprimalentropy{T<:Real}(n, x::T)
  PrimalEntropy(x * ones(T, ntodim(n)))
end
function constdualentropy{T<:Real}(n, x::T)
  DualEntropy(x * ones(T, ntodim(n)))
end

function one{N,T<:Real}(h::PrimalEntropy{N,T})
  constprimalentropy(h.n, one(T))
end
function one{N,T<:Real}(h::DualEntropy{N,T})
  constdualentropy(h.n, one(T))
end

#Base.similar(h::EntropicVector) = EntropicVector(h.n)
# Used by e.g. hcat
Base.similar{T}(h::PrimalEntropy, ::Type{T}, dims::Dims) = length(dims) == 1 ? PrimalEntropy{dims[1], T}(dimton(dims[1]), h.liftid) : Array{T}(dims...)
Base.similar{T}(h::DualEntropy, ::Type{T}, dims::Dims) = length(dims) == 1 ? DualEntropy{dims[1], T}(dimton(dims[1]), h.liftid, h.equality) : Array{T}(dims...)
Base.similar{T}(h::PrimalEntropyLift, ::Type{T}, dims::Dims) = length(dims) == 1 ? PrimalEntropyLift{dims[1], T}(dimton(dims[1]), h.liftid) : Array{T}(dims...)
Base.similar{T}(h::DualEntropyLift, ::Type{T}, dims::Dims) = length(dims) == 1 ? DualEntropyLift{dims[1], T}(dimton(dims[1]), h.equality) : Array{T}(dims...)
#Base.similar{T}(h::EntropicVector, ::Type{T}) = EntropicVector(h.n)

# Classical Entropic Inequalities
function dualentropywith(n, pos, neg)
  ret = constdualentropy(n, 0)
  for I in pos
    if I != 0x0
      ret[I] = 1
    end
  end
  for I in neg
    if I != 0x0
      ret[I] = -1
    end
  end
  ret
end

function nonnegative(n, S::Unsigned)
  dualentropywith(n, [S], [])
end
function nonnegative(n, s::Signed)
  nonnegative(n, set(s))
end

function nondecreasing(n, S::Unsigned, T::Unsigned)
  T = union(S, T)
  dualentropywith(n, [T], [S])
end
function nondecreasing(n, s::Signed, t::Signed)
  nondecreasing(n, set(s), set(t))
end

function submodular(n, S::Unsigned, T::Unsigned, I::Unsigned)
  S = union(S, I)
  T = union(T, I)
  U = union(S, T)
  dualentropywith(n, [S, T], [U, I])
end
submodular(n, S::Unsigned, T::Unsigned) = submodular(n, S, T, 0x0)
submodular(n, s::Signed, t::Signed, i::Signed) = submodular(n, set(s), set(t), set(i))
submodular(n, s::Signed, t::Signed) = submodular(n, set(s), set(t), 0x0)

function submodulareq(n, S::Unsigned, T::Unsigned, I::Unsigned)
  h = submodular(n, S, T, I)
  h.equality = true
  h
end
submodulareq(n, S::Unsigned, T::Unsigned) = submodulareq(n, S, T, 0x0)
submodulareq(n, s::Signed, t::Signed, i::Signed) = submodulareq(n, set(s), set(t), set(i))
submodulareq(n, s::Signed, t::Signed) = submodulareq(n, set(s), set(t), 0x0)

function ingleton(n, i, j, k, l)
  pos = []
  I = singleton(i)
  J = singleton(j)
  K = singleton(k)
  L = singleton(l)
  ij = union(I, J)
  kl = union(K, L)
  ijkl = union(ij, kl)
  for s in 0b1:ntodim(n)
    if subset(s, ijkl) && card(s) == 2 && s != ij
      pos = [pos; s]
    end
  end
  ikl = union(I, kl)
  jkl = union(J, kl)
  dualentropywith(n, pos, [ij, K, L, ikl, jkl])
end

function getkl(i, j)
  x = 1:4
  kl = x[(x.!=i) & (x.!=j)]
  (kl[1], kl[2])
end

function ingleton(i, j)
  ingleton(4, i, j, getkl(i, j)...)
end

# Classical Entropic Vectors
function cardminusentropy(n, I::Unsigned)
  h = constprimalentropy(n, 0)
  for J in 0b1:ntodim(n)
    h[J] = card(setdiff(J, I))
  end
  return h
end
cardminusentropy(n, i::Signed) = cardminusentropy(n, set(i))

function cardentropy(n)
  return cardminusentropy(n, 0b0)
end

#min(h1, h2) gives Array{Any,1} instead of EntropicVector :(
function mymin{N, T<:Real}(h1::PrimalEntropy{N, T}, h2::PrimalEntropy{N, T}) # FIXME cannot make it work with min :(
  PrimalEntropy{N, T}(min(h1.h, h2.h))
end

function invalidfentropy(S::Unsigned)
  n = 4
  #ret = min(constentropy(n, 4), 2 * cardentropy(n)) #can't make it work
  h = mymin(constprimalentropy(n, 4), cardentropy(n) * 2)
  for i in 0b1:ntodim(n)
    if i != S && card(i) == 2
      h[i] = 3
    end
  end
  return h
end

function invalidfentropy(s::Signed)
  return invalidfentropy(set(s))
end

function matusrentropy(t, S::Unsigned)
  n = 4
  h = mymin(constprimalentropy(n, t), cardminusentropy(n, S))
  return h
end

function matusrentropy(t, s::Signed)
  return matusrentropy(t, set(s))
end

# Manipulation

function toTikz(h::EntropicVector)
  dens = [el.den for el in h.h]
  hlcm = reduce(lcm, 1, dens)
  x = h.h * hlcm
  println(join(Vector{Int}(x), " "))
end

function toTikz{T}(h::EntropicVector{Rational{T}})
  x = Vector{Real}(h.h)
  i = h.h .== round(h.h)
  x[i] = Vector{Int}(h.h[i])
  println(join(x, " "))
end

function Base.show(io::IO, h::EntropicVector)
  offset = 0
  for i in eachindex(collect(h.n))
    for l in h.n[i]:-1:1
      for j in 0b1:ntodim(h.n[i])
        if card(j) == l
          bitmap = bits(j)[end-h.n[i]+1:end]
          val = h.h[offset+j]
          if val == 0
            print(io, " $(bitmap):$(val)")
          else
            print_with_color(:blue, io, " $(bitmap):$(val)")
          end
        end
      end
      if i != length(h.n) || l != 1
        println(io)
      end
    end
    offset += ntodim(h.n[i])
  end
end