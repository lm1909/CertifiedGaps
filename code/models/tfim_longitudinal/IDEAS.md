# Transverse-field Ising model with longitudinal field: route analysis

Each unit cell is a single spin-1/2 site. The single-cell reflection theorem requires an even seed length $n_0$; odd $n_0$ values serve only as diagnostics.

## Candidate routes

1. **Free fermions.** Only the $h = 0$ limit is solvable by Jordan–Wigner transformation into free fermions. For $h > 0$, the longitudinal field breaks $\mathbb{Z}_2$ fermion parity and renders the chain non-integrable (giving $E_8$ meson confinement in the ferromagnetic phase), so the $h = 0$ formula is used solely as a numerical cross-check.
2. **Cluster expansions or transfer-operator contraction.** High-field or strong-coupling expansions could reach large $n_0$, but require proved remainder bounds not yet implemented in the core library. Since a longitudinal field opens a substantial gap across the phase diagram, small rings are expected to suffice.
3. **Translation-resolved complete spectra with verified enclosures (chosen).** For $h > 0$, $\mathbb{Z}_2$ spin-flip parity is broken, and spatial reflection exchanges momentum $`k`$ with $`-k`$ (giving an independent parity only at $`k = 0, \pi`$). We therefore block-diagonalize $`H_L`$ into translation momentum sectors of dimension $`\approx 2^L / L`$ and enclose the complete spectrum of each block with verified residual, orthogonality, polar-factor and Weyl bounds under explicit IEEE binary64 rounding-error allowances (now the shared core pipeline `certify_gap`, which also uses $`A_{-k} = \overline{A_k}`$ to build only $0 \le k \le L/2$).

## Extending the length coverage (2026-11-04)

The stored seeds already control every even ring of at least six sites. To lower that
threshold without weakening a bound, only the two- and four-site rings remain. The candidate
routes are:

1. **Smaller bootstrap seeds.** Reoptimizing the inverse temperature at seed lengths two or
   four could cover shorter rings, but also changes the asymptotic bound and requires new
   thermal calculations. Their admissible region can be worse than the six-site seed's.
2. **Exact characteristic polynomials.** Rational matrices allow algebraic isolation of the
   two lowest eigenvalues. This is inexpensive at two sites, but needs a second verifier at
   four sites and duplicates the shared core's spectral certification.
3. **Verified finite gaps (chosen).** Compute the complete spectra at lengths two and four
   with `VerifiedSpectra.verified_ring_spectrum`, then use `spectral_gap_enclosure`. Compare
   their exact rational lower endpoints with the existing interval bound. This costs at most
   dense diagonalization of a 16-dimensional space per point, independent of the seed inverse
   temperature. In general, bridging every even length below a seed length has exponential
   cost in that length; here the finite remainder is fixed and small.

The two-site periodic convention counts both directed bonds, so its interaction is
`-2 Z ⊗ Z`. Check that convention against an independently assembled matrix. Preserve every
existing seed, chain, and interval bound. Replaying a small-ring gap cannot extend the Lean
theorem, which still starts at six sites; any stronger length claim must have computer tier
and must not reuse that theorem as though it covered the additional lengths. If a short-ring
gap is below the existing bound, report the obstruction rather than weakening that bound.

Adding a checker changes model-local source hashes. Refresh provenance only after checking
the old certificates, compare every non-metadata field with the original files, and run the
full checker. The new finite certificate must pin the old certificate files and check its
own sources. Record the measured cost and any platform limitations in `README.md`.

## Outcome

The even seed length $n_0 = 6$ (requiring complete spectra of $6$- and $12$-site rings, with maximum sector dimension $352$ at $L = 12$) produced admissible seeds at all 30 grid points $(g, h)$, certifying uniform spectral gaps across the entire parameter grid without needing larger rings (see [`README.md`](README.md)).

The route was later re-implemented on the shared core (`RingModel` in the physical frame, `certify_gap` per point) at the same seeds; the core enclosures are tighter, so every seed defect decreased and all 30 points remain certified (see [`METHOD.md`](METHOD.md)).

The finite-gap extension succeeded at 22 points without changing a seed or bound: 14 now
cover every even length from two sites, and eight from four sites. Eight points retain their
threshold of six sites; verified upper endpoints prove that their four-site gaps are below
the stored interval bounds. At each threshold-four point the two-site gap likewise proves
the obstruction. The default checker replays all 60 finite spectra; the full checker also
replayed the 60 seed spectra successfully.

The host's default CRlibm backend did not reproduce one original interval bound. Using the
package's documented, process-local MPFR backend reproduced all 30 and passed the full replay.
The old seed certificates require only a metadata refresh for the added source/checker;
their non-metadata contents are preserved. The leaderboard now supports an explicit
companion Lean threshold, so the existing theorems remain linked and audited at six sites
while the shorter coverage has computer-certified tier.
