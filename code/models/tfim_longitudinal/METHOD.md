# Method: core pipeline, checker semantics, and the regeneration audits

## Pipeline

Each grid point is one call of the shared core driver:

```julia
model = RingModel(2, -kron(Z, Z), -g * X - h * Z; reflection = I)   # exact, physical σᶻ frame
certify_point(path, model; n0 = 6, β0 = BETA0[(g, h)], params = Dict("g" => g, "h" => h),
    model_dir = ROOT, rp = rp_certificate(model; factors = [Z]))
```

`certify_point` runs `certify_gap`, attaches the params and run metadata and writes the file.
`certify_gap` performs these steps, all in `julia/src`:

1. **RP.** `verify_rp` checks $-h_{\text{bond}} = Z \otimes Z$ and the reality of $o = -gX - hZ$
   exactly. The `RingModel` constructor checks the lattice reflection $P = I$ exactly
   ($`(P \otimes P)\, h\, (P \otimes P) = S h S`$ with $S$ the site swap, and $P o P = o$).
2. **Sectors.** `ring_blocks` builds the translation orbits of the $2^L$ configurations and, for
   each momentum, the block $`\langle s,k|H|r,k\rangle = \sqrt{p_r/p_s}\sum_l c(r \to T^l s)\,e^{ikl}`$
   in interval arithmetic (exact couplings, enclosed phases and norm ratios), and the Frobenius
   norm of the entrywise radii bounds $`\|A - M\|_2`$. The reflection maps $k$ to $-k$, so only
   $0 \le k \le L/2$ is built, with multiplicity 2 for $0 < k < L/2$; since the model is real,
   the antiunitary reflection fixes every momentum and each block at $0 < k < L/2$ is built in a
   real basis, so every center is real symmetric. No charge is conserved for $h > 0$, so there
   is one sector. At $L = 12$: 7 blocks, the largest of dimension 352.
3. **Enclosure.** `verified_eigen` turns the LAPACK eigenpairs of each center into a guarantee:
   residual $R = MX - X\Lambda$ and orthogonality defect $G = X^\top X - I$ in `Float64` with
   the a priori bound $\gamma_K \sum |a_i b_i|$ ($K = N + 8$ for real blocks) and Frobenius
   norms; then the smaller of the Ostrowski and polar-factor radii, plus the construction error,
   by Weyl. Radii at $L = 12$ are at most $1.1 \times 10^{-9}$.
4. **Seeds.** `log_partition_enclosure` encloses $\log Z_6(\beta_0)$, $\log Z_{12}(\beta_0)$ and
   $\log Z_{12}(2\beta_0)$; the defect enclosures' upper ends are rounded up to the grid
   $10^{-15}$ to give the exact $\varepsilon_{\mathrm{s}}, \varepsilon_\tau$.
5. **Chain.** `rational_gap_chain` (the number of doublings that gives the best bound) yields the
   exact strict lower bound `gap_lower_bound`; `certified_gap_bound` gives the interval bound
   `interval_bound_decimal` ($\Delta_L \ge$ it), used as the admissibility screen. The README
   headline quotes the interval bound and lists the chain bound beside it.

The certificate stores the model (with its reflection), RP data, seed, $\log Z$ intervals,
spectrum summaries (block count, largest block, largest radius) and chain, plus the `params`
$(g, h)$ and the run metadata with `model_provenance` hashes.

## Checker semantics

`check.jl` (fast) runs the core `check_point` for every grid point: it enforces the model-local
source hashes, compares the stored model (including the reflection), RP factor, seed and params
exactly with `longitudinal(g, h)`, `C = Z`, `BETA0` and $(g, h)$, requires the stored defects
to be at most the seed defects of `IsingLongitudinal.lean` (read by the core `lean_points`,
which must list exactly the 30 grid points at their $\beta_0$), and reruns the core
`check_certificate(cert; spectra = false)`: the exact RP identity, the exact chain, which must
reproduce the stored bound from the stored seed, and the interval bound. `check.jl --full` adds
`spectra = true`: both seed spectra are re-enclosed from scratch and the fresh defect
enclosures must not exceed the stored $\varepsilon_{\mathrm{s}}, \varepsilon_\tau$. This is the
sound replay criterion: the stored defects are the only spectral input of the chain, so
re-proving that they are upper bounds re-proves the certificate, independent of the LAPACK
build that produced it. (The earlier local checker instead required each fresh eigenvalue
interval to lie inside a stored interval of doubled radius $2\eta$; the core certificate stores
no eigenvalues.)

## Finite gap bridge (2026-11-04)

Let $b$ be the exact binary rational represented by the seed certificate's
`interval_bound_decimal`. The spacetime bootstrap already proves uniqueness and
$\Delta_L\ge b$ for every even $L\ge6$. The only missing lengths below six are two and four.
For each, the shared verified-spectra pipeline encloses the full spectrum, with multiplicities
adding to $2^L$, and `spectral_gap_enclosure` gives exact rational endpoints
$a_L\le\Delta_L\le c_L$. Round $a_L$ down and $c_L$ up to multiples of $10^{-9}$ to leave room
for platform-dependent eigensolver residuals while keeping the certificate portable.

- If $a_2,a_4\ge b$, the same bound and uniqueness hold for every even $L\ge2$.
- If $a_4\ge b$ but $c_2<b$, the minimal threshold is four.
- If $c_4<b$, the minimal threshold is six.

The computed intervals decide all 30 points: respectively 14, eight, and eight. These are
finite gap estimates independent of $\beta_0$, not new seed defects. At two sites, both terms
in the periodic bond sum remain present. A regression test compares the shared spectrum
with the independently assembled matrix

```math
H_2=-2Z\otimes Z-g(X\otimes I+I\otimes X)-h(Z\otimes I+I\otimes Z).
```

`src/FiniteBridge.jl` contains only orchestration around the shared verifier. The JSON bridge
stores exact endpoints, thresholds, and the original seed's parameters and bound. Each row
pins its source seed certificate by SHA-256. Both checker modes rerun the small spectra and
require the fresh intervals inside the stored rational endpoints. They also check the
original model, RP identity, seeds, recurrence and source provenance with `check_point`.
The full mode adds the six- and twelve-site seed spectra. Tests corrupt parameters, seeds,
source hashes, ring lengths, gap endpoints and thresholds to check rejection paths.

The existing Lean theorems still quantify over even rings of at least six sites. The YAML
field `lean.L0` records that scope separately from the computer certificate's `lengths.L0`.
The validator compares it to the Lean audit data and permits a Lean headline tier only if
the theorem covers both the value and the lengths. No Lean theorem or seed hypothesis changed.

Adding the finite checker changed the model-local source set. The
`certify.jl --refresh-provenance` mode preserves all mathematical data, refreshes only source
metadata, checks each replacement with the core, and rebuilds the bridge. The old creation
environment is retained; the refresh run and previous certificate hash are separate metadata.
The comparison against upstream commit `682105277771b13301554925e7d3bc314da5dd31` checks every
non-metadata field of all 30 compressed certificates, including complete recurrence data and
spectral summaries, and checks `seeds.json` byte for byte.

On aarch64 Linux, the unmodified checker first failed at $g=3/4,h=1/20$ because the interval
bound did not reproduce. `IntervalArithmetic.CRlibm.setup(true)` selects CRlibm.jl's documented
MPFR implementation in the current Julia process. With that backend all original interval
bounds reproduce exactly and the full spectral replay passes; no custom rounding method or
package edit is used. The README records the invocation and measured timings.

## Seed selection

`BETA0` was selected by the earlier floating-point scan over $`n_0 \in \{2, 4, 6\}`$ and
$`\beta_0 \in \{1/4, \dots, 64\}`$ (best `certified_gap_bound`), kept unchanged so that the seeds of
the Lean statement stay valid. `scripts/scan.jl` repeats the scan from the core
`float_ring_spectrum` and matches 29 of 30 points; at $g = 1/4, h = 1$ its `Float64` defects
are zero to rounding and its preferred $\beta_0 = 23/4$ carries a meaningless float bound. With
the tighter enclosures some points would now admit a better $\beta_0$; that was not pursued.

## Routing through the core drivers (reflection added)

The certify loop, the stored-certificate checker and the Lean regex of the tests were replaced
by the core `certify_point`, `check_point` and `lean_points`, and the scan's own float block
diagonalization by `float_ring_spectrum`; the site reflection $P = I$ and the params were added.
All 30 certificates were regenerated at the same seeds and compared exactly with the previous
ones: no $\varepsilon_{\mathrm{s}}$ or $\varepsilon_\tau$ increased (17 and 18 of them decreased
by a few units of $10^{-15}$, e.g. $\varepsilon_{\mathrm{s}}$ at $g = 1, h = 1/20$ from
$0.18399987309439$ to $0.183999873093926$), no `interval_bound_decimal` or `gap_lower_bound`
decreased (7 chain bounds grew), and every defect is at most its Lean seed. The real blocks
reduce the largest eigenvalue radius at $L = 12$ from $2.6 \times 10^{-9}$ to
$1.1 \times 10^{-9}$ and its mean recorded enclosure time from 1.7 s to 0.5 s. The table below
is the earlier regeneration and is unchanged at its four significant digits.

## Regeneration with the core (old versus new)

Old: the local pipeline (radius $2\eta$ with $\gamma_{16d+32}$ allowances), interval bound
`certified_gap_bound`. New: the core pipeline at the same $(n_0, \beta_0)$; "chain" is the exact
`gap_lower_bound`, "interval" the core `interval_bound_decimal`. Lean $s_0, t_0$ are the seed
defects assumed in `IsingLongitudinal.lean`; every new $\varepsilon \le$ Lean value exactly.

| $g$ | $h$ | old $\varepsilon_{\mathrm{s}}$ | new $\varepsilon_{\mathrm{s}}$ | Lean $s_0$ | old $\varepsilon_\tau$ | new $\varepsilon_\tau$ | Lean $t_0$ | old bound | chain | interval |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1//4 | 1//20 | 9.064e-06 | 1.214e-06 | 9.064e-06 | 3.14e-05 | 4.17e-08 | 3.141e-05 | 0.3923 | 0.5319 | 0.5324 |
| 1//4 | 1//10 | 4.674e-06 | 1.79e-07 | 4.675e-06 | 1.799e-05 | 2.473e-08 | 1.799e-05 | 0.7332 | 1.0734 | 1.0743 |
| 1//4 | 1//4 | 2.225e-06 | 1.173e-08 | 2.226e-06 | 8.857e-06 | 1.319e-08 | 8.857e-06 | 1.6606 | 2.6111 | 2.6130 |
| 1//4 | 1//2 | 2.063e-06 | 3.287e-09 | 2.063e-06 | 8.242e-06 | 1.31e-08 | 8.242e-06 | 1.9757 | 3.1451 | 3.1474 |
| 1//4 | 1//1 | 2.494e-06 | 4.133e-09 | 2.494e-06 | 9.964e-06 | 1.647e-08 | 9.964e-06 | 2.0336 | 3.2512 | 3.2536 |
| 1//2 | 1//20 | 0.001314 | 0.001309 | 0.001314 | 1.872e-05 | 6.067e-07 | 1.872e-05 | 0.4564 | 0.4567 | 0.4572 |
| 1//2 | 1//10 | 0.0002267 | 0.0002239 | 0.0002267 | 1.128e-05 | 3.349e-08 | 1.129e-05 | 0.9592 | 0.9631 | 0.9639 |
| 1//2 | 1//4 | 7.236e-06 | 5.595e-06 | 7.237e-06 | 7.137e-06 | 5.785e-07 | 7.138e-06 | 2.3616 | 2.5189 | 2.5217 |
| 1//2 | 1//2 | 1.625e-06 | 3.667e-08 | 1.625e-06 | 6.516e-06 | 1.707e-07 | 6.517e-06 | 2.7754 | 3.6860 | 3.6891 |
| 1//2 | 1//1 | 1.974e-06 | 3.535e-09 | 1.974e-06 | 7.885e-06 | 1.418e-08 | 7.885e-06 | 2.7276 | 4.3048 | 4.3080 |
| 3//4 | 1//20 | 0.0371 | 0.03709 | 0.0371 | 0.0003653 | 0.000353 | 0.0003654 | 0.3170 | 0.3167 | 0.3171 |
| 3//4 | 1//10 | 0.008573 | 0.00857 | 0.008573 | 6.931e-05 | 6.112e-05 | 6.931e-05 | 0.7712 | 0.7708 | 0.7714 |
| 3//4 | 1//4 | 0.0002371 | 0.0002357 | 0.0002372 | 0.000133 | 0.0001274 | 0.0001331 | 2.1018 | 2.1048 | 2.1066 |
| 3//4 | 1//2 | 4.347e-06 | 2.835e-06 | 4.348e-06 | 1.065e-05 | 4.605e-06 | 1.065e-05 | 3.0117 | 3.2174 | 3.2211 |
| 3//4 | 1//1 | 1.856e-06 | 3.028e-08 | 1.856e-06 | 7.341e-06 | 4.862e-08 | 7.342e-06 | 3.1374 | 4.5166 | 4.5202 |
| 1//1 | 1//20 | 0.184 | 0.184 | 0.1841 | 0.007424 | 0.007413 | 0.007425 | 0.0763 | 0.0763 | 0.0763 |
| 1//1 | 1//10 | 0.05123 | 0.05122 | 0.05123 | 0.004667 | 0.004659 | 0.004667 | 0.5043 | 0.5039 | 0.5043 |
| 1//1 | 1//4 | 0.002469 | 0.002467 | 0.002469 | 0.002244 | 0.002239 | 0.002245 | 1.6092 | 1.6076 | 1.6097 |
| 1//1 | 1//2 | 5.079e-05 | 4.936e-05 | 5.079e-05 | 9.929e-05 | 9.358e-05 | 9.929e-05 | 2.7523 | 2.7672 | 2.7693 |
| 1//1 | 1//1 | 2.206e-06 | 5.276e-07 | 2.207e-06 | 7.689e-06 | 9.832e-07 | 7.69e-06 | 3.6403 | 4.2822 | 4.2864 |
| 3//2 | 1//20 | 0.1477 | 0.1477 | 0.1478 | 0.05423 | 0.05423 | 0.05424 | 0.1692 | 0.1690 | 0.1692 |
| 3//2 | 1//10 | 0.09847 | 0.09847 | 0.09848 | 0.04084 | 0.04083 | 0.04085 | 0.3601 | 0.3596 | 0.3601 |
| 3//2 | 1//4 | 0.01818 | 0.01818 | 0.01818 | 0.01277 | 0.01277 | 0.01278 | 1.0556 | 1.0546 | 1.0557 |
| 3//2 | 1//2 | 0.001195 | 0.001193 | 0.001195 | 0.001672 | 0.001666 | 0.001673 | 2.1293 | 2.1278 | 2.1303 |
| 3//2 | 1//1 | 2.24e-05 | 2.076e-05 | 2.241e-05 | 3.344e-05 | 2.689e-05 | 3.345e-05 | 3.7050 | 3.7655 | 3.7706 |
| 2//1 | 1//20 | 0.03251 | 0.03251 | 0.03252 | 0.03673 | 0.03672 | 0.03673 | 0.9121 | 0.9114 | 0.9121 |
| 2//1 | 1//10 | 0.0294 | 0.0294 | 0.02941 | 0.03285 | 0.03284 | 0.03285 | 0.9643 | 0.9636 | 0.9643 |
| 2//1 | 1//4 | 0.01577 | 0.01577 | 0.01578 | 0.01668 | 0.01668 | 0.01669 | 1.2728 | 1.2715 | 1.2729 |
| 2//1 | 1//2 | 0.003329 | 0.003327 | 0.003329 | 0.003195 | 0.003189 | 0.003196 | 2.0005 | 1.9996 | 2.0010 |
| 2//1 | 1//1 | 0.0001302 | 0.0001286 | 0.0001302 | 0.0003861 | 0.0003799 | 0.0003862 | 3.4912 | 3.4957 | 3.4989 |

All 60 defects decreased strictly and all 30 interval bounds increased. The exact chain bound is
below the old interval bound at 13 points, by at most $`0.13\%`$ (relative); it is a separate,
slightly more conservative exact rational evaluation of the recurrence, and it is the bound the
certificate claims.
