using Qumulants
using Test

hm = FockSpace(:fock)
ha = NLevelSpace(:atom,(:g,:e))
h = hm⊗ha

a = Destroy(h,:a)
σ(i,j) = Transition(h,:σ,i,j)

@parameters m k Ω sq2
x = (a+a')
p = -im*(a-a')
H = Ω*cos(k*x)*σ(:g,:e) + Ω*cos(k*x)*σ(:e,:g) + p^2/(2m)

@test iszero(commutator(exp(x),x))
@test iszero(commutator(exp(im*k*x),m*x))
@test iszero(commutator(cos(k*x), m*x))
@test iszero(commutator(sin(k*x), m*x))

dx = simplify_operators(im*commutator(H,x;simplify=false))
@test iszero(simplify_operators(dx - 2p/m))
dp = simplify_operators(im*commutator(H,p;simplify=false))
@test iszero(simplify_operators(dp - 4k*Ω*sin(k*x)*(σ(:g,:e) + σ(:e,:g))))
