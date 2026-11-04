# Transverse-field Ising model with longitudinal field: route analysis

Each unit cell is a single spin-1/2 site. The single-cell reflection theorem requires an even seed length $n_0$; odd $n_0$ values serve only as diagnostics.

## Recurrence portability audit (November 2026)

On aarch64 Linux, the pinned CRlibm binary returns incorrect directed `log1p` values for
some binary64 inputs. Exact rational series enclosures prove failures in both directions;
the unchanged checker also fails to reproduce a stored interval bound. This affects the
shared recurrence used by several models, so its repair belongs in the core package.

Candidate routes, before implementation:

1. **Select the package's MPFR backend globally.** The documented
   `IntervalArithmetic.CRlibm.setup(true)` repairs manual replay, but redefines dependency
   methods throughout the process. Doing this during package initialization would complicate
   downstream precompilation and change unrelated users of IntervalArithmetic.
2. **Recompute all bounds with a different interval precision.** This would change stored
   certified numbers and require unnecessary certificate regeneration. It does not address
   the defective binary64 operation for other callers.
3. **Evaluate interval `log1p` locally through MPFR (chosen).** Lift machine-float intervals to
   BigFloat intervals, evaluate `log1p` with directed rounding, and convert outward to the
   original type. Route both the defect map and the logarithmic tail through the helper.
   Ordinary floating-point diagnostics keep their existing dispatch. This needs no global
   settings, dependency changes, or certificate edits. Exact rational series tests will check
   both rounding directions independently of MPFR, and existing certificate replay will test
   compatibility.

The repair adds a constant amount of scalar work per recurrence step, independent of $n_0$
and $\beta_0$; it does not increase the required seed sizes or the asymptotic cost of their
spectra. Validation must include all model checkers and tests because they share the core
arithmetic. Passing a finite regression set does not verify the entire external rounding
library, and this work does not address the separate high-precision BigFloat seed-defect issue.

The first exact regression run exposed another failure in `expm1`: at binary64 input
`0xbfc3aa3729f5df13`, the directed lower endpoint lies above the exact value. Fixing that
still left a stored bound unreproduced; tracing its orbit exposed incorrect upper endpoints
of `exp` at `0xbff5c2f012268edd` and `0xbff5c2f012268ec1`. Alternating Taylor bounds prove
these failures with exact rationals. A `log1p`-only repair is therefore insufficient.

The chosen route now covers the core pipeline's interval exponential, logarithm, `expm1`,
`log1p`, and Fourier-phase sine/cosine calls through one shared helper. It leaves the
existing basic arithmetic and spectral perturbation proofs in place. Partition summation
still takes linear work in the number of stored levels, with a larger constant per
transcendental evaluation. Model-specific calls directly to IntervalArithmetic remain
outside this helper; the documented process-wide MPFR switch remains relevant for those
on an affected platform. A successful core replay is not a validation of the native library.

## Candidate routes

1. **Free fermions.** Only the $h = 0$ limit is solvable by Jordan–Wigner transformation into free fermions. For $h > 0$, the longitudinal field breaks $\mathbb{Z}_2$ fermion parity and renders the chain non-integrable (giving $E_8$ meson confinement in the ferromagnetic phase), so the $h = 0$ formula is used solely as a numerical cross-check.
2. **Cluster expansions or transfer-operator contraction.** High-field or strong-coupling expansions could reach large $n_0$, but require proved remainder bounds not yet implemented in the core library. Since a longitudinal field opens a substantial gap across the phase diagram, small rings are expected to suffice.
3. **Translation-resolved complete spectra with verified enclosures (chosen).** For $h > 0$, $\mathbb{Z}_2$ spin-flip parity is broken, and spatial reflection exchanges momentum $`k`$ with $`-k`$ (giving an independent parity only at $`k = 0, \pi`$). We therefore block-diagonalize $`H_L`$ into translation momentum sectors of dimension $`\approx 2^L / L`$ and enclose the complete spectrum of each block with verified residual, orthogonality, polar-factor and Weyl bounds under explicit IEEE binary64 rounding-error allowances (now the shared core pipeline `certify_gap`, which also uses $`A_{-k} = \overline{A_k}`$ to build only $0 \le k \le L/2$).

## Outcome

The November 2026 portability audit found that correcting only `log1p`, or only `log1p`
and `expm1`, did not restore ordinary checker replay on aarch64. The expanded local MPFR
helper reproduces all 30 stored interval bounds exactly, without changing a certificate or
its model-local source hashes. The longitudinal-Ising tests also pass a fresh spectral replay
at $g = 1$, $h = 1/20$. This is a mitigation of the shared pipeline: it neither diagnoses
the native library's rounding failure nor validates model-specific calls outside the helper.

The even seed length $n_0 = 6$ (requiring complete spectra of $6$- and $12$-site rings, with maximum sector dimension $352$ at $L = 12$) produced admissible seeds at all 30 grid points $(g, h)$, certifying uniform spectral gaps across the entire parameter grid without needing larger rings (see [`README.md`](README.md)).

The route was later re-implemented on the shared core (`RingModel` in the physical frame, `certify_gap` per point) at the same seeds; the core enclosures are tighter, so every seed defect decreased and all 30 points remain certified (see [`METHOD.md`](METHOD.md)).
