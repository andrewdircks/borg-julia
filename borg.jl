using Libdl

# TODO: make this variable
const temp = "borg/libborg.so"

mutable struct Configuration
    so_dir::String
    lib::Ptr{Nothing}
end

function Configure()::Configuration
    so_dir = "borg/libborg.so"
    lib = dlopen(so_dir)
    return Configuration(so_dir, lib)
end

# configure and set finalizer
config = Configure()
finalizer(config) do x
  dlclose(x.lib)
end

struct Borg
    nVars::Int32
    nObjs::Int32
    nCons::Int32
    bounds::Vector{Tuple{Float64, Float64}}
    epsilons::Vector{Float64}
    nfe::Int32
    problem::Base.CFunction
end

struct Solution 
    vars::Vector{Float64}
    objs::Vector{Float64}
    constrs::Vector{Float64}
end

function borg(nVars, nObjs, nCons, bounds, epsilons, nfe, julia_problem)::Borg
    c_problem = @cfunction($julia_problem, Cvoid, (Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}))
    return Borg(nVars, nObjs, nCons, bounds, epsilons, nfe, c_problem)
end


# set the bounds to this BORG_Problem reference
function setBounds(bounds, nvars, ref)
  for i = 0:(nvars-1)
      ccall((:BORG_Problem_set_bounds, temp), Cvoid, (Ptr{Cvoid}, Int32, Cdouble, Cdouble), ref, i, bounds[i+1][1], bounds[i+1][2])
  end
end


# set the epsilons to this BORG_Problem reference
function setEpsilons(epsilons, nobjs, ref)
  for i = 0:nobjs-1
      ccall((:BORG_Problem_set_epsilon, temp), Cvoid, (Ptr{Cvoid}, Int32, Cdouble), ref, i, epsilons[i+1])
  end
end


function getObjectives(sol, nObjs)
  return [ccall((:BORG_Solution_get_objective), Cdouble, (Ptr{Cvoid}, Int32), sol, i) for i = 0:(nObjs-1)]
end

function getVariables(sol, nVars)
  return [ccall((:BORG_Solution_get_variable), Cdouble, (Ptr{Cvoid}, Int32), sol, i) for i = 0:(nVars-1)]
end

function getConstraints(sol, nCons)
  return [ccall((:BORG_Solution_get_constraint), Cdouble, (Ptr{Cvoid}, Int32), sol, i) for i = 0:(nCons-1)]
end


# process the result (pointer to archive)
function process(result, borg) 
    archive_size = ccall((:BORG_Archive_get_size, temp), Int32, (Ptr{Cvoid},), result)
    solutions = Vector{Solution}(undef, archive_size)

    for i = 0:(archive_size-1)
      sol = ccall((:BORG_Archive_get, temp), Ptr{Cvoid}, (Ptr{Cvoid}, Int32), result, i)
      vars = getVariables(sol, borg.nVars)
      objs = getObjectives(sol, borg.nObjs)
      constrs = getConstraints(sol, borg.nCons)
      solutions[i+1] = Solution(vars, objs, constrs)
  end

  return solutions

end

function run(borg::Borg)
    # create problem
    ref = ccall((:BORG_Problem_create), Ptr{Cvoid}, (Int64, Int64, Int64, Ptr{Cvoid}), borg.nVars, borg.nObjs, borg.nCons, borg.problem)

    # set bounds
    setBounds(borg.bounds, borg.nVars, ref)

    # set epsilons
    setEpsilons(borg.epsilons, borg.nObjs, ref)

    # run
    result = ccall((:BORG_Algorithm_run, temp), Ptr{Cvoid}, (Ptr{Cvoid}, Int32), ref, borg.nfe)

    # process results
    solutions = process(result, borg)
end


