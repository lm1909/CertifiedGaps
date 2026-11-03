# Checker for the 30 longitudinal-field TFIM certificates in results/certificate_g*_h*.json.gz.
#
#     julia --project=code/julia code/models/tfim_longitudinal/check.jl [--full]
#
# Fast mode (default): per certificate, the core `check_point` against the grid point's
# definition (recorded model-local source hashes; the stored model, lattice reflection, RP
# factor, seed and params; the seed defects at most those of the Lean statement), the exact RP
# identity, the exact rational chain and the interval bound; then the seed table.
# Both modes replay the two- and four-site finite gaps. `--full` additionally re-encloses
# the complete spectra of the rings of 6 and 12 sites and requires the fresh
# seed defects not to exceed the stored εₛ, εₜ. Any failure throws.
include(joinpath(@__DIR__, "src", "LongitudinalCertificate.jl"))
using .LongitudinalCertificate
const C = LongitudinalCertificate

full = "--full" in ARGS
C.check_grid(C.result_paths())
for row in C.check_bridge(; full)
    println(row["source_certificate"], ": gap ≥ ", row["bound"],
        " for every even L ≥ ", row["L0"])
end
C.check_seed_table()
println("All $(length(C.points())) certificates and finite bridges verified",
    full ? " (full replay)." : ".")
