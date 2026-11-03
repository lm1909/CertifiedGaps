"""
    CertifiedGaps.IntervalFunctions

Internal transcendental evaluations for the certificate pipeline. The pinned CRlibm binary on
aarch64 can return non-enclosures for `exp`, `log1p`, and `expm1`. For machine-float intervals,
use MPFR through BigFloat intervals, then convert outward to the original endpoint type. Both
conversions preserve interval decorations and guarantees. Other input types keep their original
dispatch.

This avoids redefining dependency methods with the process-wide `CRlibm.setup(true)` switch.
"""
module IntervalFunctions

using IntervalArithmetic

for f in (:exp, :expm1, :log, :log1p, :sinpi, :cospi)
    local_name = Symbol(:_, f)
    @eval begin
        $local_name(x) = $f(x)
        $local_name(x::Interval{T}) where {T<:Union{Float16,Float32,Float64}} =
            interval(T, $f(interval(BigFloat, x)))
    end
end

end
