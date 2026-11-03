# Included in LongitudinalCertificate. The bootstrap covers L ≥ 6; these two finite
# spectra cover the remaining even lengths when their gaps exceed the same bound.
using CertifiedGaps.VerifiedSpectra: verified_ring_spectrum, spectral_gap_enclosure

const BRIDGE_PATH = joinpath(ROOT, "results", "finite_bridge.json")
const BRIDGE_FORMAT = "Longitudinal Ising finite gap bridge v1"
const SHORT_LENGTHS = (2, 4)
const GAP_GRID = big(10)^9

"Exact gap enclosures at L = 2,4, with every eigenvalue counted with its multiplicity."
function short_gap_enclosures(g, h)
    model = longitudinal(g, h)
    map(SHORT_LENGTHS) do L
        spec = verified_ring_spectrum(model, L)
        sum(length(b.centers) * b.multiplicity for b in spec) == model.d^L ||
            error("incomplete spectrum at L = $L")
        spectral_gap_enclosure(spec)
    end
end

"Smallest even threshold supported by the two finite lower bounds and the seed certificate."
function bridge_threshold(gaps, bound)
    gaps[2][1] >= bound || return N0
    return gaps[1][1] >= bound ? 2 : 4
end

"""
    write_bridge(; path = BRIDGE_PATH)

Check the seed certificates and write the finite gap bridge for the whole grid. Endpoints
are rounded outward to a rational grid so fresh LAPACK enclosures can vary within their
rounding allowance. The source certificate hashes bind the finite and bootstrap claims.
"""
function write_bridge(; path = BRIDGE_PATH)
    rows = Dict{String,Any}[]
    lean = lean_seeds()
    for (g, h) in points()
        check(g, h; lean)
        source = certificate_path(g, h)
        cert = read_result(source)
        bound = Rational{BigInt}(cert["interval_bound_decimal"])
        gaps = map(short_gap_enclosures(g, h)) do (lo, hi)
            (floor(BigInt, GAP_GRID * lo) // GAP_GRID,
                ceil(BigInt, GAP_GRID * hi) // GAP_GRID)
        end
        L0 = bridge_threshold(gaps, bound)
        # Prove that any rejected shorter threshold really fails at a finite ring.
        L0 == 4 && gaps[1][2] >= bound && error("two-site comparison is inconclusive")
        L0 == N0 && gaps[2][2] >= bound && error("four-site comparison is inconclusive")
        push!(rows, Dict(
            "g" => string(g), "h" => string(h), "n0" => string(N0),
            "beta0" => cert["seed"]["beta0"], "eps_s" => cert["seed"]["eps_s"],
            "eps_t" => cert["seed"]["eps_t"], "bound" => string(bound), "L0" => string(L0),
            "source_certificate" => basename(source), "source_sha256" => sha256_file(source),
            "rings" => [Dict("L" => string(L), "gap_lower" => string(lo),
                "gap_upper" => string(hi)) for (L, (lo, hi)) in zip(SHORT_LENGTHS, gaps)]))
    end
    metadata = model_metadata(ROOT, Dict("lengths" => string.(SHORT_LENGTHS),
        "gap_grid_denominator" => string(GAP_GRID)); packages = (CertifiedGaps,), certified = true)
    write_result(path, Dict("format" => BRIDGE_FORMAT, "points" => rows, "metadata" => metadata))
    return rows
end

"""
    check_bridge(; path = BRIDGE_PATH, full = false)

Replay the original seed certificates and both short-ring spectra at every grid point.
Require fresh gap enclosures inside the stored outward-rounded intervals, the claimed
length threshold, and rigorous obstructions to any smaller threshold. `full = true` also
replays the six- and twelve-site seed spectra. No stored finite gap is trusted without replay.
"""
function check_bridge(; path = BRIDGE_PATH, full = false)
    data = read_result(path)
    data["format"] == BRIDGE_FORMAT || error("unknown finite bridge format")
    verify_model_metadata(data["metadata"], ROOT)
    rows = data["points"]
    length(rows) == length(points()) || error("finite bridge does not cover the grid")
    lean = lean_seeds()
    for (row, (g, h)) in zip(rows, points())
        (parse_rational(row["g"]), parse_rational(row["h"])) == (g, h) ||
            error("finite bridge point order differs from the grid")
        source = certificate_path(g, h)
        row["source_certificate"] == basename(source) || error("wrong seed certificate path")
        row["source_sha256"] == sha256_file(source) || error("seed certificate hash mismatch")
        check(g, h; full, lean)
        cert = read_result(source)
        all(parse_rational(row[k]) == parse_rational(cert["seed"][k])
            for k in ("n0", "beta0", "eps_s", "eps_t")) || error("bridge seed mismatch")
        bound = parse_rational(row["bound"])
        bound == Rational{BigInt}(cert["interval_bound_decimal"]) || error("bridge bound mismatch")
        bound > 0 || error("nonpositive bridge bound")
        rings = row["rings"]
        parse_rational.(getindex.(rings, "L")) == collect(SHORT_LENGTHS) ||
            error("finite bridge must check exactly the two- and four-site rings")
        gaps = [(parse_rational(r["gap_lower"]), parse_rational(r["gap_upper"])) for r in rings]
        for ((lo, hi), (fresh_lo, fresh_hi)) in zip(gaps, short_gap_enclosures(g, h))
            0 <= lo <= fresh_lo <= fresh_hi <= hi || error("finite gap enclosure does not replay")
        end
        L0 = bridge_threshold(gaps, bound)
        parse_rational(row["L0"]) == L0 || error("incorrect finite bridge threshold")
        L0 == 4 && gaps[1][2] >= bound && error("two-site obstruction not proved")
        L0 == N0 && gaps[2][2] >= bound && error("four-site obstruction not proved")
    end
    return rows
end

"""
    refresh_provenance()

Refresh only the model-local source hashes of existing seed certificates after a checker
change. Preserve their original run metadata and all mathematical inputs and outputs. Check
each proposed replacement with the core before writing it; record the old file hash and
the refresh environment separately. This does not substitute for `check.jl --full`.
"""
function refresh_provenance()
    lean = lean_seeds()
    metadata = model_metadata(ROOT, Dict("operation" => "source provenance refresh only");
        packages = (CertifiedGaps,), certified = true)
    mktempdir() do dir
        for (g, h) in points()
            path = certificate_path(g, h)
            original = read_result(path)
            original["metadata"]["source_sha256"] == metadata["source_sha256"] && continue
            updated = deepcopy(original)
            updated["metadata"]["source_sha256"] = metadata["source_sha256"]
            updated["metadata"]["source_refresh"] = Dict(
                "previous_certificate_sha256" => sha256_file(path), "run" => metadata)
            proposed = joinpath(dir, basename(path))
            write_result(proposed, updated)
            check(g, h; path = proposed, lean)
            back = read_result(proposed)
            without_metadata(c) = Dict(k => v for (k, v) in c if k != "metadata")
            without_metadata(back) == without_metadata(original) ||
                error("provenance refresh changed certificate data")
            write_result(path, updated)
        end
    end
    return nothing
end
