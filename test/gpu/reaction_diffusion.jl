using OrdinaryDiffEq, RecursiveArrayTools, LinearAlgebra, Test

# Define the constants for the PDE
const α₂ = 1.0
const α₃ = 1.0
const β₁ = 1.0
const β₂ = 1.0
const β₃ = 1.0
const r₁ = 1.0
const r₂ = 1.0
const D = 100.0
const γ₁ = 0.1
const γ₂ = 0.1
const γ₃ = 0.1
const N = 256
const X = reshape([i for i in 1:N for j in 1:N],N,N)
const Y = reshape([j for i in 1:N for j in 1:N],N,N)
const α₁ = 1.0.*(X.>=4*N/5)

const Mx = Tridiagonal([1.0 for i in 1:N-1],[-2.0 for i in 1:N],[1.0 for i in 1:N-1])
const My = copy(Mx)
Mx[2,1] = 2.0
Mx[end-1,end] = 2.0
My[1,2] = 2.0
My[end,end-1] = 2.0

# Define the initial condition as normal arrays
A = zeros(N,N); B  = zeros(N,N); C = zeros(N,N); u0 = ArrayPartition((A,B,C))
#u0 = zeros(Float64,N,N,3)

const MyA = zeros(N,N);
const AMx = zeros(N,N);
const DA = zeros(N,N);
# Define the discretized PDE as an ODE function
function f(du,u,p,t)
  A,B,C = u.x
  dA,dB,dC = du.x
  # A = @view  u[:,:,1]
  # B = @view  u[:,:,2]
  # C = @view  u[:,:,3]
  #dA = @view du[:,:,1]
  #dB = @view du[:,:,2]
  #dC = @view du[:,:,3]
  mul!(MyA,My,A)
  mul!(AMx,A,Mx)
  @. DA = D*(MyA + AMx)
  @. dA = DA + α₁ - β₁*A - r₁*A*B + r₂*C
  @. dB = α₂ - β₂*B - r₁*A*B + r₂*C
  @. dC = α₃ - β₃*C + r₁*A*B - r₂*C
end

# Solve the ODE
prob = ODEProblem(f,u0,(0.0,100.0))
sol = solve(prob,BS3(),progress=true,save_everystep=false,save_start=false)

using CuArrays
gA = CuArray(Float32.(A)); gB = CuArray(Float32.(B)); gC = CuArray(Float32.(C)); gu0 = ArrayPartition((gA,gB,gC))
#gu0 = CuArray(Float32.(u0))
const gMx = CuArray(Float32.(Mx))
const gMy = CuArray(Float32.(My))
const gα₁ = CuArray(Float32.(α₁))


const gMyA = CuArray(zeros(Float32,N,N))
const gAMx = CuArray(zeros(Float32,N,N))
const gDA = CuArray(zeros(Float32,N,N))

function gf(du,u,p,t)
  A,B,C = u.x
  dA,dB,dC = du.x
  # A = @view  u[:,:,1]
  # B = @view  u[:,:,2]
  # C = @view  u[:,:,3]
  #dA = @view du[:,:,1]
  #dB = @view du[:,:,2]
  #dC = @view du[:,:,3]
  mul!(gMyA,gMy,A)
  mul!(gAMx,A,gMx)
  @. gDA = D*(gMyA + gAMx)
  @. dA = gDA + gα₁ - β₁*A - r₁*A*B + r₂*C
  @. dB = α₂ - β₂*B - r₁*A*B + r₂*C
  @. dC = α₃ - β₃*C + r₁*A*B - r₂*C
end

prob2 = ODEProblem(gf,gu0,(0.0,100.0))
#CuArray.allowslow(false) # makes sure none of the slow fallbacks are used
CuArrays.allowscalar(false) # so that the error generates
sol = solve(prob2,BS3(),save_everystep=false,save_start=false)
@test sol.t[end] == 100.0
