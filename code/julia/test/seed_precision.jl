using Test, IntervalArithmetic, CertifiedGaps

@testset "BigFloat seed endpoint precision" begin
    # Conversion itself must run at the endpoint precision to avoid rounding in ldexp.
    exact(x::BigFloat) = setprecision(() -> Rational{BigInt}(x), BigFloat, precision(x))

    # For |x| <= 1 the absolute Taylor tail is bounded by a geometric series, since
    # the ratio of consecutive omitted terms is at most |x|/(N+2).
    function defect_bounds(x)
        q = exact(x)
        @assert abs(q) <= 1
        term, total = one(q), zero(q)
        for k in 1:256
            term *= q / k
            total += term
        end
        tail = abs(term * q / 257) / (1 - abs(q) / 258)
        return -total - tail, -total + tail
    end

    tiny, ordinary, positive, zero512 = setprecision(BigFloat, 512) do
        (BigFloat(-2.2318473424252034e-38) * (1 + BigFloat(2)^-200),
            -big(1) / 8, big(1) / 4, BigFloat(0))
    end
    # Either endpoint can carry the greater precision; interval construction preserves it.
    lower768 = setprecision(() -> -big(1) / 2, BigFloat, 768)
    upper768 = setprecision(() -> -big(1) / 16, BigFloat, 768)
    inputs = (interval(tiny), interval(ordinary), interval(positive), interval(zero512),
        interval(lower768, ordinary), interval(ordinary, upper768))
    @test (precision(inf(inputs[5])), precision(sup(inputs[5]))) == (768, 512)
    @test (precision(inf(inputs[6])), precision(sup(inputs[6]))) == (512, 768)
    witnesses = [(defect_bounds(sup(x))[1], defect_bounds(inf(x))[2]) for x in inputs]

    for ambient in (64, 256, 512, 1024)
        setprecision(BigFloat, ambient) do
            for (x, (lo, hi)) in zip(inputs, witnesses)
                z = interval(zero512)
                # Point inputs give 1-exp(x) in both outputs. Wide inputs enclose the same
                # endpoint choices; forming 3x and subtracting 2x uses directed intervals.
                result = CertifiedGaps.Seeds.seed_defects(z, x, 3x)
                direct = CertifiedGaps.Seeds._defect(x)
                @test precision(BigFloat) == ambient
                for (d, eps) in ((result.defect_s, result.eps_s),
                        (result.defect_t, result.eps_t), direct)
                    @test !isempty_interval(d)
                    @test exact(inf(d)) <= lo <= hi <= exact(sup(d))
                    @test eps == exact(sup(d))
                    @test hi <= eps
                    @test d isa Interval{BigFloat}
                end
            end
        end
    end
end
