using Test, IntervalArithmetic, CertifiedGaps
using CertifiedGaps.ExactArithmetic: log_enclosure
import CertifiedGaps.Recurrence as R
import CertifiedGaps.IntervalFunctions as IF

@testset "recurrence log1p enclosures" begin
    # For 0 <= a < 1, sum(a^k/k) <= -log(1-a) <= sum + a^(N+1)/((N+1)(1-a)).
    # These rational witnesses detect both observed ARM errors independently of MPFR.
    function series_enclosure(x)
        q = Rational{BigInt}(x)
        a = q <= 0 ? -q : q / (1 + q)
        partial = sum(a^k / k for k in 1:80)
        tail = a^81 / (81 * (1 - a))
        return q <= 0 ? (-partial - tail, -partial) : (partial, partial + tail)
    end
    cases = (reinterpret(Float64, 0xbfda93c340e4f83c),
        reinterpret(Float64, 0xbfbd03c84b5e1340),
        -0.5, -1e-15, -floatmin(Float64), -nextfloat(0.0), 0.0, 0.25, 0.5)
    for bits in (32, 53, 256)
        setprecision(BigFloat, bits) do
            for x in cases
                lo, hi = series_enclosure(x)
                result = R._log1p(interval(x))
                @test result isa Interval{Float64}
                @test Rational{BigInt}(inf(result)) <= lo
                @test hi <= Rational{BigInt}(sup(result))
                @test isguaranteed(result)
            end
        end
    end

    for T in (Float16, Float32, Float64)
        lo, _ = series_enclosure(T(-0.25))
        _, hi = series_enclosure(T(0.5))
        result = R._log1p(interval(T, -0.25, 0.5))
        @test result isa Interval{T}
        @test Rational{BigInt}(inf(result)) <= lo
        @test hi <= Rational{BigInt}(sup(result))
        @test isempty_interval(R._log1p(emptyinterval(T)))
        @test isnai(R._log1p(nai(T)))
        @test decoration(R._log1p(interval(T, -1, 0))) == trv
        @test inf(R._log1p(interval(T, -1, 0))) == -Inf
    end

    # Exercise the public defect map, including the two former failure inputs, against
    # its exact polynomial identity rather than another transcendental implementation.
    for a in (-cases[1], -cases[2], 0.0, 0.01), b in (0.0, 0.02, 0.125)
        qa, qb = Rational{BigInt}(a), Rational{BigInt}(b)
        exact = 1 - (1 - qb) * (1 - qa)^2
        result = zdefect(interval(a), interval(b))
        @test Rational{BigInt}(inf(result)) <= exact <= Rational{BigInt}(sup(result))
    end

    # The stored staggered-field seed previously returned nothing/NaI on aarch64.
    result = certified_gap_bound(1342500085157 // 125000000000000,
        5576810540003 // 500000000000000, 11 // 2)
    @test result.bound == 0.5948212796982801
    @test R._log1p(0.125) === log1p(0.125)
end

@testset "partition functions and Fourier phases" begin
    for x in (reinterpret(Float64, 0xbff5c2f012268edd),
            reinterpret(Float64, 0xbff5c2f012268ec1), -0.125, 0.0)
        q = Rational{BigInt}(x)
        lo = sum(q^k / factorial(big(k)) for k in 0:81)
        hi = sum(q^k / factorial(big(k)) for k in 0:80)
        result = IF._exp(interval(x))
        @test Rational{BigInt}(inf(result)) <= lo
        @test hi <= Rational{BigInt}(sup(result))
    end
    for x in (0.125, 0.1, 0.5, 1.0, 2.0, 100.0)
        lo, hi = log_enclosure(Rational{BigInt}(x))
        result = IF._log(interval(x))
        @test Rational{BigInt}(inf(result)) <= lo
        @test hi <= Rational{BigInt}(sup(result))
    end
    @test inf(IF._sinpi(interval(1) / 6)) <= 0.5 <= sup(IF._sinpi(interval(1) / 6))
    @test inf(IF._cospi(interval(1) / 3)) <= 0.5 <= sup(IF._cospi(interval(1) / 3))
end

@testset "seed expm1 enclosures" begin
    # Alternating odd/even Taylor truncations enclose expm1(x) for -1 <= x <= 0.
    # The first input demonstrates a second ARM failure, independent of log1p.
    for x in (reinterpret(Float64, 0xbfc3aa3729f5df13), -0.5, -0.01, -1e-15, 0.0)
        q = Rational{BigInt}(x)
        lo = sum(q^k / factorial(big(k)) for k in 1:81)
        hi = sum(q^k / factorial(big(k)) for k in 1:80)
        result = IF._expm1(interval(x))
        @test Rational{BigInt}(inf(result)) <= lo
        @test hi <= Rational{BigInt}(sup(result))

        # The public seed conversion intersects two enclosures; neither may exclude truth.
        seed = CertifiedGaps.Seeds.seed_defects(interval(0.0), interval(x), 3interval(x))
        @test Rational{BigInt}(inf(seed.defect_s)) <= -hi
        @test -lo <= seed.eps_s
    end
    @test IF._expm1(0.125) === expm1(0.125)
end
