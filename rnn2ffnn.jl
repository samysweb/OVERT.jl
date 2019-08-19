using Flux, LinearAlgebra

include("relubypass.jl")



################################################################################
# This is the RNN we want to convert to FFNN.
rnn = Chain(Dense(2, 4, relu), RNN(4, 4, relu), Dense(4, 1, identity))

# Create the FFNN from the given RNN model. Currently the list "new" is hardcoded
function new_net(model, state_size)
    W, b = new_params(model, state_size)
    bypass = bypass_nodes(model, state_size); #bypass = bypass .+ state_size
    # new = [Dense(W[i], b[i], ReLUBypass(bypass[i])) for i=1:num_layers(model)-2]
    # new = append!(new, [Dense(W[end], b[end], identity)])
    # print("\n\nNEW: \n", new, "\n")
    new = [Dense(W[1], b[1], ReLUBypass(bypass[1])), Dense(W[2], b[2], ReLUBypass(bypass[2])), Dense(W[3], b[3], identity)]
    out = relu_bypass(Chain(new...))
end

# Returns weights and biases of new FFNN based on input RNN
function new_params(model, state_size)
    W_s = Matrix(1I, state_size, state_size)
    b_s = zeros(state_size)
    sizes_layers = layer_sizes(model)
    rnn_index = rnn_layer(model)
    size_latent = size(model[rnn_layer(model)].init)[1]
    weights = Vector{Array{Float64}}(undef, length(model))
    biases  = Vector{Array{Float64}}(undef, length(model))
    for i = 1:length(model)
        if i < rnn_index
            weights[i] = hcat(zeros(sizes_layers[i+1], size_latent), Tracker.data(model.layers[i].W))
            weights[i] = vcat(Matrix(1I, size_latent, sizes_layers[i]+size_latent), weights[i])
            weights[i] = hcat(zeros(size(weights[i])[1], state_size), weights[i])
            weights[i] = vcat(Matrix(1I, state_size, size(weights[i])[2]), weights[i])
            biases[i]  = vcat(zeros(size_latent+state_size), Tracker.data(model.layers[i].b))
        elseif i == rnn_index
            weights[i] = vcat(hcat(Tracker.data(model.layers[i].cell.Wh), Tracker.data(model.layers[i].cell.Wi)), hcat(Tracker.data(model.layers[i].cell.Wh), Tracker.data(model.layers[i].cell.Wi)))
            weights[i] = hcat(zeros(size(weights[i])[1], state_size), weights[i])
            weights[i] = vcat(Matrix(1I, state_size, size(weights[i])[2]), weights[i])
            biases[i]  = vcat(Tracker.data(model.layers[i].cell.h) + Tracker.data(model.layers[i].cell.b), Tracker.data(model.layers[i].cell.h) + Tracker.data(model.layers[i].cell.b))
            biases[i]  = vcat(zeros(state_size), biases[i])
        elseif i > rnn_index
            weights[i] = hcat(zeros(sizes_layers[i+1], size_latent), Tracker.data(model.layers[i].W))
            weights[i] = vcat(weights[i], Matrix(1I, size_latent, sizes_layers[i]+size_latent))
            weights[i] = hcat(zeros(size(weights[i])[1], state_size), weights[i])
            weights[i] = vcat(Matrix(1I, state_size, size(weights[i])[2]), weights[i])
            biases[i]  = vcat(zeros(state_size), Tracker.data(model.layers[i].b), zeros(size_latent))
        end
    end
    return weights, biases
end

# Returns which indices of each layer to ReLUBypass
function bypass_nodes(model, state_size)
    size_latent = size(model[rnn_layer(model)].init)[1]
    [i == rnn_layer(model) ? collect(1:state_size) : collect(1:size_latent+state_size) for i = 1:length(model)]
end

# Returns number of layers of a model, including input layer
num_layers(model) = length(model) + 1

# Return list of size of each layer in flux model. Input layer included.
layer_sizes(x) = [layer_size(x[1], 2); layer_size.(x, 1)]


weights(D::Dense) = D.W
weights(R::Flux.Recur) = R.cell.Wi
layer_size(L, i = nothing) = i == nothing ? size(weights(L)) : size(weights(L), i)

# Return RNN Layer. (Input limited to one RNN layer)
rnn_layer(model) = findfirst(l->l isa Flux.Recur, model.layers)




## CHECK CORRECTNESS ##
size_latent = size(rnn[rnn_layer(rnn)].init)[1]
state = [1.1, -11.5]; state_size = size(state)[1]
input = 2rand(2) - 1.0
eval_point = input
eval_point2 = vcat(state, zeros(size_latent), input)

ffnn = new_net(rnn, state_size)
ans_old = Tracker.data(rnn(eval_point))
ans_new = Tracker.data(ffnn(eval_point2))
print("\nCheck for same control output and latent state:")
print("\nRNN: ", ans_old[1], Tracker.data(rnn.layers[rnn_layer(rnn)].state))
print("\nFFNN: ", ans_new)  # Outputs [theta, theta_dot, u, l1, l2, l3, l4] l1 is first value of latent state
# ans_old[1] == ans_new[1] ? print("\nMatching Control Output✅") : print("\nNot Matching Control Output ❌")
# model.layers[2].state == ans_new[2:end] ? print("\nMatching RNN State ✅") : print("\nNot Matching RNN State ❌")







## EXTRANEOUS FUNCTIONS ##
# # Creates a network where the input is ReLUBypassed for a given number of layers
# function state_bypass(state_size, layer_count)
#     layer_list = fill(Dense(Matrix(1I, state_size, state_size), zeros(state_size), ReLUBypass(collect(1:state_size)...)), (layer_count))
#     out = relu_bypass(Chain(layer_list...))
# end

## EXTRANEOUS PRINTING OF INPUT RNN ##
# # print weights #
# for layer in model.layers
#     if layer isa Flux.Dense
#         print("\n\nDense Weights:\n")
#         print(Tracker.data(layer.W))
#     elseif layer isa Flux.Recur
#         print("\n\nRNN Weights:\n")
#         print("In:     ", Tracker.data(layer.cell.Wi), "\n")
#         print("Latent: ", Tracker.data(layer.cell.Wh))
#     end
# end
# # print biases #
# for layer in model.layers
#     if layer isa Flux.Dense
#         print("\n\nDense Biases:\n")
#         print(Tracker.data(layer.b))
#     elseif layer isa Flux.Recur
#         print("\n\nRNN Biases:\n")
#         print("In:     ", Tracker.data(layer.cell.b), "\n")
#         print("Latent: ", Tracker.data(layer.cell.h))
#     end
# end
# print("\n\n")
