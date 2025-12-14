# Title: RV32IMF Matrix–Vector Multiplication & Determinant Computation

## Description:
> A low-level numerical computing project in RISC-V RV32IMF assembly, implementing matrix–vector multiplication and determinant computation for a fixed 6×6 matrix under strict register and ISA constraints.
> This project emphasizes floating-point arithmetic, register discipline, and algorithmic correctness in a constrained assembly environment.

## Subroutines implemented:
- **matvec_mul:** Matrix–vector multiplication (6×6)
- **det_comp:** Determinant computation using Gaussian elimination
- **compare_sum_det:** Comparison of `sum(Y)` with `det(A)`

## Constraints
- ISA: RV32IMF
- Integer registers: **x5–x15 only**
- Single-precision floating point only

## Output
- Correct Y vector computation in all cases
- Correct det(A) computation in all cases (also compared with equivalent python code output)
- Correct comparison flag

## Performance
Measured using **RARS instruction statistics**:
- Instruction count: obtained from RARS execution statistics
- Cycle estimate: analyzed assuming an ideal 5-stage pipeline
- No dynamic memory allocation
- Deterministic runtime (fixed-size 6×6 matrix)

## Run
Open `matvec_det_rv32imf.s` in **RARS**, assemble, and run.
