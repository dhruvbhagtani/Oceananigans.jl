using Oceananigans
using Plots, Printf

using Oceananigans: NoPenetrationBC

####
#### Data from tables 1 and 2 of Ghia et al. (1982).
####

j̃ = [1,   8,      9,      10,     14,     23,     37,     59,     65,  80,     95,     110,    123,    124,    156,    126,    129]
ỹ = [0.0, 0.0547, 0.0625, 0.0703, 0.1016, 0.1719, 0.2813, 0.4531, 0.5, 0.6172, 0.7344, 0.8516, 0.9531, 0.9609, 0.9688, 0.9766, 1.0]

ũ = Dict(
    100 => [0.0, -0.03717, -0.04192, -0.04775, -0.06434, -0.10150, -0.15662, -0.21090, -0.20581, -0.13641, 0.00332, 0.23151, 0.68717, 0.73722, 0.78871, 0.84123, 1.0],
    400 => [0.0, -0.08186, -0.09266, -0.10338, -0.14612, -0.24299, -0.32726, -0.17119, -0.11477,  0.02135, 0.16256, 0.29093, 0.55892, 0.61756, 0.68439, 0.75837, 1.0]
)

####
#### Model setup
####

Nx, Ny, Nz = 1, 128, 128
Lx, Ly, Lz = 1, 1, 1

vbcs = ChannelBCs(top    = BoundaryCondition(Value, 1),
                  bottom = BoundaryCondition(Value, 0),
                  north  = NoPenetrationBC(),
                  south  = NoPenetrationBC())

wbcs = ChannelBCs(top    = NoPenetrationBC(),
                  bottom = NoPenetrationBC(),
                  north  = BoundaryCondition(Value, 0),
                  south  = BoundaryCondition(Value, 0))

bcs = ChannelSolutionBCs(v=vbcs, w=wbcs)

Re = 400

model = NonDimensionalModel(grid=RegularCartesianGrid(size=(Nx, Ny, Nz), length=(Lx, Ly, Lz)),
                            Re=Re, Pr=Inf, Ro=Inf, tracers=nothing, buoyancy=nothing, boundary_conditions=bcs)

Δ = max(model.grid.Δy, model.grid.Δz)

y = collect(model.grid.yC)
z = collect(model.grid.zC)
# p = heatmap(y, z, zeros(Ny, Nz), color=:viridis, clims=(1e-3, 1), show=true)

Δt = 0.1e-4

# wizard = TimeStepWizard(cfl=0.2, Δt=0.5e-4, max_change=1.1, max_Δt=5.0)

while model.clock.time < 1e-2
    time_step!(model; Δt=Δt, Nt=1, init_with_euler=model.clock.time == 0 ? true : false)

    v = model.velocities.v.data[1, :, :]
    w = model.velocities.w.data[1, :, :]

    Δy, Δz = model.grid.Δy, model.grid.Δz
    dvdz = (v[1:Ny, 2:Nz+1] - v[1:Ny, 1:Nz]) / Δz
    dwdy = (w[2:Ny+1, 1:Nz] - w[1:Ny, 1:Nz]) / Δy
    ζ = dwdy - dvdz
    ζ = reverse(log10.(abs.(ζ)), dims=1)

    # heatmap!(p, y, z, ζ, color=:viridis, clims=(-3, 1), show=true)

    u, v, w = model.velocities
    u_max = max(maximum(v.data), maximum(w.data))
    CFL = u_max * Δt / Δ
    dCFL = (1/Re) * Δt / Δ^2
    @printf("Time: %.4f, CFL: %.3g, dCFL: %.3g, max (v, w, ζ): %.2g, %.2g, %.2g\n",
            model.clock.time, CFL, dCFL, maximum(v.data.parent), maximum(w.data.parent), maximum(ζ))
end
