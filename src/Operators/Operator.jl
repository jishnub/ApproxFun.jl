export Operator,RowOperator,InfiniteOperator
export bandrange, linsolve



abstract Operator{T} #T is the entry type, Flaot64 or Complex{Float64}
abstract RowOperator{T} <: Operator{T}
abstract InfiniteOperator{T} <: Operator{T}
abstract BandedBelowOperator{T} <: InfiniteOperator{T}
abstract BandedOperator{T} <: BandedBelowOperator{T}

abstract ShiftOperator{T} <: Operator{T} #For biinfinite operators
abstract InfiniteShiftOperator{T} <: ShiftOperator{T}
abstract BandedShiftOperator{T} <: InfiniteShiftOperator{T}
abstract RowShiftOperator{T} <: ShiftOperator{T}


## We assume operators are T->T
rangespace(A::InfiniteOperator)=0
domainspace(A::InfiniteOperator)=0
domain(A::Operator)=Any

domain(f::IFun)=f.domain
domain(::Number)=Any

function domain(P::Vector)
    ret = Any
    
    for op in P
        d = domain(op)
        @assert ret == Any || d == Any || ret == d
        
        if d != Any
            ret = d
        end
    end
    
    ret
end


Base.size(::InfiniteOperator)=[Inf,Inf]
Base.size(::RowOperator)=Any[1,Inf] #use Any vector so the 1 doesn't become a float
Base.size(op::Operator,k::Integer)=size(op)[k]


Base.getindex(op::Operator,k::Integer,j::Integer)=op[k:k,j:j][1,1]
Base.getindex(op::Operator,k::Integer,j::Range1)=op[k:k,j][1,:]
Base.getindex(op::Operator,k::Range1,j::Integer)=op[k,j:j][:,1]


Base.getindex(op::RowOperator,k::Integer)=op[k:k][1]

function Base.getindex(op::RowOperator,j::Range1,k::Range1)
  @assert j[1]==1 && j[end]==1
  op[k]' #TODO conjugate transpose?
end
function Base.getindex(op::RowOperator,j::Integer,k::Range1)
  @assert j==1
  op[k]' #TODO conjugate transpose?
end



function Base.getindex(B::Operator,k::Range1,j::Range1)
    BandedArray(B,k,j)[k,j]
end




## Multiplication of operator * fun


ultraiconversion(g::Vector,m::Integer)=(m==0)? g : backsubstitution!(MutableAlmostBandedOperator(Operator[ConversionOperator(0:m)]),copy(g))
ultraconversion(g::Vector,m::Integer)=(m==0)? g : ConversionOperator(0:m)*g

function *{T<:Number}(A::BandedOperator,b::Vector{T})
    n=length(b)
    m=n-bandrange(A)[1]
    ret = zeros(T,m)
    BA = BandedArray(A,1:m)
    
    for k=1:n - bandrange(A)[end]
        for j=indexrange(BA,k)
            ret[k] += BA[k,j]*b[j] 
        end
    end
    
    for k=max(n-bandrange(A)[end]+1,1):m
        for j=indexrange(BA,k)[1]:n
            ret[k] += BA[k,j]*b[j]             
        end
    end

    ret
end



*(A::InfiniteOperator,b::IFun)=IFun(ultraiconversion(A*ultraconversion(b.coefficients,domainspace(A)),rangespace(A)),b.domain)

*(A::RowOperator,b::Vector)=dot(A[1:length(b)],b)
*(A::RowOperator,b::IFun)=A*b.coefficients
*{T<:Operator}(A::Vector{T},b::IFun)=map(a->a*b,convert(Array{Any,1},A))



## Linear Solve



function linsolve{T<:Operator}(A::Vector{T},b::Vector;tolerance=eps(),maxlength=Inf)
    d=domain([A,b])
    u=adaptiveqr(A,b,tolerance,maxlength)
    
    d != Any ? 
        IFun(u,d) :
        u
end


##Todo nxn operator
function linsolve{T<:Operator}(A::Array{T,2},b)
    ret=adaptiveqr(interlace(A),b)
    [IFun(ret[1:2:end],domain(A[:,1])),
    IFun(ret[2:2:end],domain(A[:,2]))]
end

\{T<:Operator}(A::Vector{T},b::Vector)=linsolve(A,b)
\{T<:Operator}(A::Array{T,2},b::Vector)=linsolve(A,b)
\(A::Operator,b::Vector)=[A]\b
\(A::Operator,b::IFun)=[A]\[b]



include("ShiftArray.jl")


include("ToeplitzOperator.jl")

include("Ultraspherical/MultiplicationOperator.jl")
include("Ultraspherical/EvaluationOperator.jl")
include("Ultraspherical/ConversionOperator.jl")
include("Ultraspherical/DerivativeOperator.jl")
include("Ultraspherical/IntegrationOperator.jl")

include("AlmostBandedOperator.jl")
include("adaptiveqr.jl")


include("OperatorAlgebra.jl")
include("RowOperatorAlgebra.jl")

include("specialfunctions.jl")

include("TransposeOperator.jl")
include("StrideOperator.jl")

include("Fourier/FourierDerivativeOperator.jl")

include("null.jl")



## Convenience routines

Base.diff(d::IntervalDomain,μ::Integer)=DerivativeOperator(0:μ,d)
Base.diff(d::IntervalDomain)=Base.diff(d,1)
Base.eye(d::IntervalDomain)=MultiplicationOperator(IFun([1.],d))
integrate(d::IntervalDomain)=IntegrationOperator(1,d)

evaluate(d::IntervalDomain,x)=EvaluationOperator(d,x)
dirichlet(d::IntervalDomain)=[evaluate(d,d.a),evaluate(d,d.b)]
neumann(d::IntervalDomain)=[EvaluationOperator(d,d.a,1),EvaluationOperator(d,d.b,1)]

Base.start(d::IntervalDomain)=evaluate(d,d.a)
Base.endof(d::IntervalDomain)=evaluate(d,d.b)

## Conversion

Base.convert{N<:Number}(A::Type{Operator},n::N)=ConstantOperator(1.n,0)
