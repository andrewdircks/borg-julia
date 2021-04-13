include("borg.jl") 

# problem specific globals
nvars = 11
nobjs = 2
k = nvars - nobjs + 1

function dtlz2(vars, objs, constrs)::Cvoid 
    # load vars
    vars = [unsafe_load(vars, i) for i = 1:nvars]

    g = 0
    # i = 2, 3, 4, 5, ... 10
    # iJulia = 3, 4, 5, ... 11
    for i = (nvars - k + 1):nvars
        g += (vars[i] - 0.5)^2
    end

    _objs = [1.0 + g, 1.0 + g]
    
    _objs[1] = _objs[1] * cos(0.5 * pi * vars[1])
    _objs[2] = _objs[2] * sin(0.5 * pi * vars[1])

    # store objs
    for i = 1:nobjs
        unsafe_store!(objs, _objs[i], i)
    end
  
    # appease function type definition
    return Cvoid()
end

bounds = repeat([(0.0, 1.0)], 11)
epsilons = repeat([0.01], 2)
test = borg(11, 2, 0, bounds, epsilons, 1000, dtlz2)
settings = Dict("frequency" => 100, "runtimefile" => "test.txt")
result = run(test, settings)
print(result)