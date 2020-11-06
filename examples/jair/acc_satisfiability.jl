# acc satisfiability script
include("../../models/problems.jl")
include("../../OverApprox/src/overapprox_nd_relational.jl")
include("../../OverApprox/src/overt_parser.jl")
include("../../MIP/src/overt_to_mip.jl")
include("../../MIP/src/mip_utils.jl")
include("../../models/acc/acc.jl")
include("../../MIP/src/logic.jl")
using JLD2

# ACC CONTROLLER
# 3x20 controller here: https://github.com/souradeep-111/sherlock/tree/master/systems_with_networks/ARCH_2019/ACC
controller = "nnet_files/jair/acc_controller.nnet"
println("Controller is: ", controller)
query = OvertQuery(
    ACC,  # problem
    controller,    # network file
    Id(),      	# last layer activation layer Id()=linear, or ReLU()=relu
    "MIP",     	# query solver, "MIP" or "ReluPlex"
    2, #35,        	# ntime
    0.1,       	# dt
    -1,        	# N_overt
    )

# x1,x2,x3 are lead vehicle variables
# x4,x5,x6 are ego vehicle variables
x_lead = [90,110]
v_lead = [32, 32.2]
gamma_lead = [0,0]
x_ego = [10,11]
v_ego = [30, 30.2]
gamma_ego = [0, 0]
var_list = [x_lead, v_lead, gamma_lead, x_ego, v_ego, gamma_ego]
input_set = Hyperrectangle(
    low=[v_range[1] for v_range in var_list], 
    high=[v_range[2] for v_range in var_list]
    )
# test using Constraint on output instead of hyperrectangle!
# desired property to be proven is:
# D_rel = x_lead - x_ego >= D_safe = D_default + T_gap * v_ego
# x_lead + -1*x_ego - T_gap*v_ego >= D_default = 10
# BUT WE MUST NEGATE THIS (and so we flip >= to <=)
T_gap = 1.4
output_constraint = Constraint([1, 0, 0, -1, -T_gap, 0], :(<=), 10)

# NOTE: I think I will have to load the matlab files here:
# https://github.com/souradeep-111/sherlock/blob/master/systems_with_networks/ARCH_2019/ACC/NN_output.m
# in order to determine how the input mapping works
# TODO: clone repo...play with files...

t1 = Dates.time()
SATus, vals, stats = symbolic_satisfiability(query, input_set, output_constraint)
t2 = Dates.time()
dt = t2 - t1

JLD2.@save "examples/jair/data/new/acc_satisfiability_"*string(controller)*"_data.jld2" query input_set avoid_set SATus vals stats dt controller