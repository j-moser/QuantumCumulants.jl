Base.show(io::IO,x::BasicOperator) = write(io, x.name)
Base.show(io::IO,x::Create) = write(io, string(x.name, "′"))
Base.show(io::IO,x::Transition) = write(io, Symbol(x.name,x.i,x.j))

show_brackets = Ref(true)
function Base.show(io::IO,x::Union{OperatorTerm,NumberTerm})
    show_brackets[] && write(io,"(")
    show(io, x.arguments[1])
    for i=2:length(x.arguments)
        show(io, x.f)
        show(io, x.arguments[i])
    end
    show_brackets[] && write(io,")")
end

Base.show(io::IO, x::Parameter) = write(io, x.name)
function Base.show(io::IO,x::Average)
    write(io,"⟨")
    show_brackets[] = false
    show(io, x.operator)
    show_brackets[] = true
    write(io,"⟩")
end

Base.show(io::IO, ::MIME"text/latex", op::AbstractOperator) = write(io, latexify(op))
Base.show(io::IO, ::MIME"text/latex", de::AbstractEquation) = write(io, latexify(de))
Base.show(io::IO, ::MIME"text/latex", p::SymbolicNumber) = write(io, latexify(p))
