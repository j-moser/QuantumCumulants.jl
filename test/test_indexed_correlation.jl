using Test
using QuantumCumulants
using SymbolicUtils
using Symbolics
using OrdinaryDiffEq
using SteadyStateDiffEq
using ModelingToolkit

const qc = QuantumCumulants

@testset "indexed_correlation" begin

order = 2 #order of the cumulant expansion
@cnumbers N Δ g κ Γ R ν M

# Hilbertspace
hc = FockSpace(:cavity)
ha = NLevelSpace(:atom,2)

h = hc ⊗ ha

# Indices and Operators

k = Index(h,:k,N,ha)
l = Index(h,:l,N,ha)
m = Index(h,:m,N,ha)
n = Index(h,:n,N,ha)

extra_indices = [n]

@qnumbers a::Destroy(h)

σ(i,j,k) = IndexedOperator(Transition(h,:σ,i,j),k)
σn(i,j,k) = NumberedOperator(Transition(h,:σ,i,j),k)

# Define the Hamiltonian
H = -Δ*a'a + g*(Σ(a'*σ(1,2,k),k) + Σ(a*σ(2,1,k),k))

J = [a,σ(1,2,l),σ(2,1,l),σ(2,2,l)]
rates = [κ, Γ, R, ν]
ops = [a'*a,σ(2,2,m)]
eqs = meanfield(ops,H,J;rates=rates,order=order)

@test length(eqs) == 2

φ(x::Average) = φ(x.arguments[1])
φ(::Destroy) = -1
φ(::Create) =1
φ(x::QTerm) = sum(map(φ, x.args_nc))
φ(x::Transition) = x.i - x.j
φ(x::IndexedOperator) = φ(x.op)
φ(x::SingleSum) = φ(x.term)
φ(x::AvgSums) = φ(arguments(x))
phase_invariant(x) = iszero(φ(x))

eqs_c = qc.complete(eqs;filter_func=phase_invariant);


eqs_sc1 = scale(eqs_c)

@test length(eqs_sc1) == 4
@test length(eqs_c) == 4


# define the ODE System and Problem
@named sys = ODESystem(eqs_sc1)

# Initial state
u0 = zeros(ComplexF64, length(eqs_sc1))
# System parameters
N_ = 2e5
Γ_ = 1.0 #Γ=1mHz
Δ_ = 2500Γ_ #Δ=2.5Hz
g_ = 1000Γ_ #g=1Hz
κ_ = 5e6*Γ_ #κ=5kHz
R_ = 1000Γ_ #R=1Hz
ν_ = 1000Γ_ #ν=1Hz

ps = [N, Δ, g, κ, Γ, R, ν]
p0 = [N_, Δ_, g_, κ_, Γ_, R_, ν_]

prob = ODEProblem(sys,u0,(0.0, 1.0/50Γ_), ps.=>p0);

# Solve the Problem
sol = solve(prob,Tsit5(),maxiters=1e7)

avrgSum = arguments(arguments(eqs_c[1].rhs)[1])[2]

split0 = split_sums(avrgSum,l,15)

@test isequal(split0,avrgSum)

split1 = split_sums(avrgSum,k,4)

@test split1 isa SymbolicUtils.Mul
@test !isequal(split1,avrgSum)
@test isequal(4,arguments(split1)[1])
@test isequal(N/4,arguments(split1)[2].metadata.sum_index.range)

split2 = split_sums(avrgSum,k,M)

@test !isequal(split2,split1)
@test !isequal(split2,avrgSum)
@test isequal(M,arguments(split2)[1])
@test isequal(N/M,arguments(split2)[2].metadata.sum_index.range)

avrgSum2 = arguments(arguments(eqs_c[3].rhs)[1])[2]

_split0 = split_sums(avrgSum2,l,15)

@test isequal(avrgSum2,_split0)
@test isequal(avrgSum2,split_sums(avrgSum2,k,1))

_split1 = split_sums(avrgSum2,k,3)

@test !isequal(_split1,avrgSum2)
@test _split1 isa SymbolicUtils.Add
@test isequal(2,length(arguments(_split1)))

op1 = a'
op2 = a

corr = IndexedCorrelationFunction(a', a, eqs_c; steady_state=true, filter_func=phase_invariant,extra_indices=extra_indices);
corr = scale(corr)

ps = [N, Δ, g, κ, Γ, R, ν]

@test length(corr.de0) == 4
@test length(corr.de) == 2

all_states = [corr.de0.states;corr.de.states]
m_de = find_missing(corr.de)
filter!(x->x in all_states,m_de)
filter!(x->x in conj.(all_states),m_de)
@test isempty(m_de)

S = Spectrum(corr, ps);

prob_ss = SteadyStateProblem(prob)
sol_ss = solve(prob_ss, DynamicSS(Tsit5(); abstol=1e-8, reltol=1e-8),
    reltol=1e-14, abstol=1e-14, maxiters=5e7);


limits = Dict{SymbolicUtils.Sym,Int64}(N=>5)
evals = evaluate(eqs_c;limits=limits)


@test length(evals) == 21
@test length(unique(evals.states)) == length(evals.states)

@cnumbers N_

i = Index(h,:i,N_,ha)
j = Index(h,:j,N_,ha)

Γ_ij = DoubleIndexedVariable(:Γ,i,j)
Ω_ij = DoubleIndexedVariable(:Ω,i,j;identical=false)
gi = IndexedVariable(:g,i)

ΓMatrix = [1.0 1.0
            1.0 1.0]

ΩMatrix = [0.0 0.5
            0.5 0.0]

gn = [1.0,2.0]
κn = 3.0

ps = [Γ_ij,Ω_ij,gi,κ]
p0 = [ΓMatrix,ΩMatrix,gn,κn]

limits = Dict{SymbolicUtils.Sym,Int64}(N_=>2)
valmap = value_map(ps,p0;limits=limits)

map_ = Dict{SymbolicUtils.Sym{Parameter, Base.ImmutableDict{DataType, Any}},ComplexF64}()
push!(map_,qc.DoubleNumberedVariable(:Γ,1,1)=>1.0)
push!(map_,qc.DoubleNumberedVariable(:Γ,2,1)=>1.0)
push!(map_,qc.DoubleNumberedVariable(:Γ,1,2)=>1.0)
push!(map_,qc.DoubleNumberedVariable(:Γ,2,2)=>1.0)
push!(map_,qc.DoubleNumberedVariable(:Ω,2,2)=>0.0)
push!(map_,qc.DoubleNumberedVariable(:Ω,1,2)=>0.5)
push!(map_,qc.DoubleNumberedVariable(:Ω,1,1)=>0.0)
push!(map_,qc.DoubleNumberedVariable(:Ω,2,1)=>0.5)
push!(map_,qc.SingleNumberedVariable(:g,1)=>1.0)
push!(map_,qc.SingleNumberedVariable(:g,2)=>2.0)
push!(map_,κ=>3.0)



@test length(valmap) == 11
@test length(valmap) == length(map_)
for arg in valmap
    @test arg in map_
end

@test isequal(qc.scaleTerm(σ(1,2,k)), σn(1,2,1))
@test isequal(qc.scaleTerm(σ(2,1,k)*σ(1,2,j)), σn(2,1,1)*σn(1,2,2))

sum_ = average(Σ(σ(2,1,i)*σ(1,2,j),i))

split = split_sums(sum_,i,3)

@test split isa SymbolicUtils.Add
@test length(arguments(split)) == 3

hc = FockSpace(:cavity)
ha = NLevelSpace(:atom,2)

h = hc ⊗ ha

k = Index(h,:k,N,ha)
l = Index(h,:l,N,ha)

m = Index(h,:m,N,hc)
n = Index(h,:n,N,hc)

order = 2

σ(i,j,k) = IndexedOperator(Transition(h,:σ,i,j),k)
ai(k) = IndexedOperator(Destroy(h,:a),k)

H_2 = -Δ*∑(ai(m)'ai(m),m) + g*(∑(Σ(ai(m)'*σ(1,2,k),k),m) + ∑(Σ(ai(m)*σ(2,1,k),k),m))

J_2 = [ai(m),σ(1,2,k),σ(2,1,k),σ(2,2,k)]
rates_2 = [κ, Γ, R, ν]
ops_2 = [ai(n)'*ai(n),σ(2,2,l)]

q = Index(h,:q,N,ha)
r = Index(h,:r,N,hc)

extra_indices = [q,r]
eqs_2 = meanfield(ops_2,H_2,J_2;rates=rates_2,order=order)

eqs_s1 = scale(eqs_2;h=2)
inds_s1 = qc.get_indices_equations(eqs_s1)

for ind in inds_s1
    @test isequal(ind.aon,1)
end

eqs_s2 = scale(eqs_2;h=1)
inds_s2 = qc.get_indices_equations(eqs_s2)

for ind in inds_s2
    @test isequal(ind.aon,2)
end

sum1 = ∑(σ(2,1,i),i)
op1 = a'
op2 = a
h1 = qc.hilbert(op1)
h2 = qc._new_hilbert(qc.hilbert(op2), acts_on(op2))
h_ = h1⊗h2
new_sum = qc._new_operator(sum1,h_)
@test isequal(qc.hilbert(new_sum),h_)



end
