    # using BenchmarkTools

    # function neg_log_lik_v1(weights)
    #     x = weights[P1] .- weights[P2]
    #     loglik = @. log(1/(1 + exp(-x)))
    #     -sum(loglik)
    # end
    # # @benchmark neg_log_lik_v1(init_w)

    # function loglik1(w1, w2)
    #     x = w1-w2
    #     log(1/(1 + exp(-x)))
    # end
    # function neg_log_lik_v2(weights)
    #     -mapreduce(((p1, p2),)->loglik1(weights[p1], weights[p2]), +, zip(P1, P2))
    # end

    # # @benchmark neg_log_lik_v2(init_w)
    # using LoopVectorization
    # function neg_log_lik_v3(weights)
    #     s = 0.0
    #     @vectorize for i in 1:length(P1)
    #         a = P1[i]
    #         b = P2[i]
    #         x = weights[a] - weights[b]
    #         s += log(1/(1+exp(-x)))
    #     end
    #     return -s
    # end
    # @benchmark neg_log_lik_v3(init_w)

    # neg_log_lik_v1(init_w)
    # neg_log_lik_v2(init_w)
    # neg_log_lik_v3(init_w)



    # using RCall

    # @rput P1 P2

    # @time R"""
    # w = runif(max(c(P1, P2)), -1, 1)
    # system.time(m <- optim(w, function(w) {
    #   x  = w[P1] - w[P2]
    #   p = 1/(1 + exp(-x))
    #   -sum(log(p))
    # }, method="BFGS"))

    # ping = m$par
    # """;

    # @rget ping

    # @code_warntype neg_log_lik(init_w)
    # @benchmark neg_log_lik(init_w)

    # BenchmarkTools.Trial:
    #   memory estimate:  16 bytes
    #   allocs estimate:  1
    #   --------------
    #   minimum time:     71.200 μs (0.00% GC)
    #   median time:      73.500 μs (0.00% GC)
    #   mean time:        75.843 μs (0.00% GC)
    #   maximum time:     451.100 μs (0.00% GC)
    #   --------------
    #   samples:          10000
    #   evals/sample:     1