#Base file for defining DoubleIndexedSums

"""

    IndexedDoubleSum <: QTerm

Defines a symbolic summation over another [`SingleSum`](@ref), using one [`Index`](@ref) entity. This corresponds to a double-summation over a multiplication of terms.

Fields:
======

* innerSum: A [`SingleSum`](@ref) entity.
* sum_index: The index, for which the (outer) summation will go over.
* NEI: (optional) A vector of indices, for which the (outer) summation-index can not be equal with.

"""
struct IndexedDoubleSum{M} <:QTerm
    innerSum::SingleSum
    sum_index::Index
    NEI::Vector{Index}
    metadata::M
    function IndexedDoubleSum(innerSum::SingleSum,sum_index::Index,NEI::Vector,metadata)
        try
            return new{typeof(metadata)}(innerSum,sum_index,NEI,metadata)
        catch e
            println("Could not create DoubleSum with input: term= $(innerSum) ; sum_index=c$(sum_index) ; NEI= $(NEI) ; metadata= $(metadata)")
            rethrow(e)
        end

    end
end
function IndexedDoubleSum(innerSum::SingleSum,sum_index::Index,NEI;metadata=NO_METADATA)
        if innerSum.sum_index == sum_index
            error("summation index is the same as the index of the inner sum")
        else
            extraterm = 0
            NEI_ = copy(NEI)
            for index in get_indices(innerSum.term)
                if sum_index in innerSum.non_equal_indices && isequal(index,innerSum.sum_index)
                    (innerSum.sum_index ∉ NEI_) && push!(NEI_,index)
                    continue
                end
                if index != sum_index && index ∉ NEI && isequal(index.aon,sum_index.aon)
                    extraterm = SingleSum(change_index(innerSum.term,sum_index,index),innerSum.sum_index,innerSum.non_equal_indices)
                    push!(NEI_,index)
                end 
            end
            if innerSum.term isa QMul
                # put terms of the outer index in front
                indicesToOrder = sort([innerSum.sum_index,sum_index],by=getIndName)
                newargs = order_by_index(innerSum.term.args_nc,indicesToOrder)
                qmul = 0
                if length(newargs) == 1
                    qmul = *(innerSum.term.arg_c,newargs[1])
                else
                    qmul = *(innerSum.term.arg_c,newargs...)
                end
                sort!(NEI_)
                innerSum_ = SingleSum(qmul,innerSum.sum_index,innerSum.non_equal_indices)
                if innerSum_ isa SingleSum
                    if extraterm == 0
                        return IndexedDoubleSum(innerSum_,sum_index,NEI_,metadata)
                    end
                    return IndexedDoubleSum(innerSum_,sum_index,NEI_,metadata) + extraterm
                else
                    return IndexedDoubleSum(innerSum_,sum_index,NEI_;metadata=metadata)
                end
            else
                sort!(NEI)
                return IndexedDoubleSum(innerSum,sum_index,NEI,metadata)
            end
        end
end
function IndexedDoubleSum(innerSum::IndexedAdd,sum_index::Index,NEI;metadata=NO_METADATA)
    sums = [IndexedDoubleSum(arg,sum_index,NEI;metadata=metadata) for arg in arguments(innerSum)]
    isempty(sums) && return 0
    length(sums) == 1 && return sums[1]
    return +(sums...)
end
IndexedDoubleSum(x,ind::Index,NEI;metadata=NO_METADATA) = SingleSum(x,ind,NEI)
IndexedDoubleSum(x,ind::Index;metadata=NO_METADATA) = IndexedDoubleSum(x,ind,Index[])

#In this constructor the NEI is considered so, that all indices given in ind are unequal to any of the NEI
function IndexedDoubleSum(term::QMul,ind::Vector{Index},NEI::Vector{Index};metadata=NO_METADATA)
    if length(ind) != 2
        error("Can only create Double-Sum with 2 indices!")
    end
    return IndexedDoubleSum(SingleSum(term,ind[1],NEI),ind[2],NEI;metadata=metadata)
end
function IndexedDoubleSum(term::QMul,outerInd::Index,innerInd::Index;non_equal::Bool=false,metadata=NO_METADATA)
    if non_equal
        innerSum = SingleSum(term,innerInd,[outerInd])
        return IndexedDoubleSum(innerSum,outerInd,[];metadata=metadata)
    else
        innerSum = SingleSum(term,innerInd,[])
        return IndexedDoubleSum(innerSum,outerInd,[];metadata=metadata)
    end
end

hilbert(elem::IndexedDoubleSum) = hilbert(elem.sum_index)
#multiplications
*(elem::SNuN, sum::IndexedDoubleSum) = IndexedDoubleSum(elem*sum.innerSum,sum.sum_index,sum.NEI)
*(sum::IndexedDoubleSum,elem::SNuN) = IndexedDoubleSum(sum.innerSum*elem,sum.sum_index,sum.NEI)
*(sum::IndexedDoubleSum,qmul::QMul) = qmul.arg_c*(*(sum,qmul.args_nc...))
function *(qmul::QMul,sum::IndexedDoubleSum)
    sum_ = sum
    for i = length(qmul.args_nc):-1:1
        sum_ = qmul.args_nc[i] * sum_
    end
    return qmul.arg_c*sum_ 
end
function *(elem::IndexedObSym,sum::IndexedDoubleSum)
    NEI = copy(sum.NEI)
    if elem.ind != sum.sum_index && elem.ind ∉ NEI
        if ((sum.sum_index.aon != sum.innerSum.sum_index.aon) && isequal(elem.ind.aon,sum.sum_index.aon))
            push!(NEI,elem.ind) 
            addterm = SingleSum(elem*change_index(sum.innerSum.term,sum.sum_index,elem.ind),sum.innerSum.sum_index,sum.innerSum.non_equal_indices)
            return IndexedDoubleSum(elem*sum.innerSum,sum.sum_index,NEI) + addterm
        end
    end
    return IndexedDoubleSum(elem*sum.innerSum,sum.sum_index,NEI)
end
function *(sum::IndexedDoubleSum,elem::IndexedObSym)
    NEI = copy(sum.NEI)
    if elem.ind != sum.sum_index && elem.ind ∉ NEI
        if ((sum.sum_index.aon != sum.innerSum.sum_index.aon) && isequal(elem.ind.aon,sum.sum_index.aon))
            push!(NEI,elem.ind)
            addterm = SingleSum(change_index(sum.innerSum.term,sum.sum_index,elem.ind)*elem,sum.innerSum.sum_index,sum.innerSum.non_equal_indices)
            return IndexedDoubleSum(sum.innerSum*elem,sum.sum_index,NEI) + addterm
        end
    end
    return IndexedDoubleSum(sum.innerSum*elem,sum.sum_index,NEI)
end
*(sum::IndexedDoubleSum,x) = IndexedDoubleSum(sum.innerSum*x,sum.sum_index,sum.NEI)
*(x,sum::IndexedDoubleSum) = IndexedDoubleSum(x*sum.innerSum,sum.sum_index,sum.NEI) 

SymbolicUtils.istree(a::IndexedDoubleSum) = false
SymbolicUtils.arguments(a::IndexedDoubleSum) = SymbolicUtils.arguments(a.innerSum)
checkInnerSums(sum1::IndexedDoubleSum, sum2::IndexedDoubleSum) = ((sum1.innerSum + sum2.innerSum) == 0)
reorder(dsum::IndexedDoubleSum,indexMapping::Vector{Tuple{Index,Index}}) = IndexedDoubleSum(reorder(dsum.innerSum,indexMapping),dsum.sum_index,dsum.NEI)
#Base functions
function Base.show(io::IO,elem::IndexedDoubleSum)
    write(io,"Σ", "($(elem.sum_index.name)=1:$(elem.sum_index.range))")
    if !(isempty(elem.NEI))
        write(io,"($(elem.sum_index.name)≠")
        for i = 1:length(elem.NEI)
            write(io, "$(elem.NEI[i].name))")
        end
    end
    show(io,elem.innerSum)
end
Base.isequal(a::IndexedDoubleSum,b::IndexedDoubleSum) = isequal(a.innerSum,b.innerSum) && isequal(a.sum_index,b.sum_index) && isequal(a.NEI,b.NEI)
_to_expression(x::IndexedDoubleSum) = :( IndexedDoubleSum($(_to_expression(x.innerSum)),$(x.sum_index.name),$(x.sum_index.range),$(writeNEIs(x.NEI))))

function *(sum1::SingleSum,sum2::SingleSum; ind=nothing)
    if sum1.sum_index != sum2.sum_index
        term = sum1.term*sum2.term
        return IndexedDoubleSum(SingleSum(term,sum1.sum_index,sum1.non_equal_indices),sum2.sum_index,sum2.non_equal_indices)
    else
        if !(ind isa Index)
            error("Specification of an extra Index is needed!")
        end
        term2 = change_index(sum2.term,sum2.sum_index,ind)
        return IndexedDoubleSum(SingleSum(sum1.term*term2,sum1.sum_index,sum1.non_equal_indices),ind,sum1.non_equal_indices)

    end
end

