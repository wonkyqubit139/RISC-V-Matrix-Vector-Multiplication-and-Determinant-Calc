# File Name: matvec_det_rv32imf.s
# Objectives: a) General n x n matrix * vector, b) determinant (partial pivoting), c) comparision between determinant and sum(Y)
# Integer registers used: x5 to x15 (plus ra/sp)
# Floating registers: fa0 to fa7, ft0 to ft3, and fs0

# I have added multiple comments which explain the purpose of various parts of code,
# register usage, and the purpose of each code block so that the algorithm can be
# understood while reading through the code
##########################################################################################

.data
.align 2
N:      .word 6         # We can change this to set n (matrix dimension)

.align 2
# Example 6x6 matrix (can change to any n x n; ensure to keep N consistent)
# Also here Matrix A is stored in row-major format: row0, row1, ..., row(n-1)
A:
    .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0    # A[0][0..5] (row_1)
    .float 2.0, 1.0, 2.0, 1.0, 2.0, 1.0    # A[1][0..5] (row_2)
    .float 3.0, 0.0, 1.0, 2.0, 1.0, 0.0    # A[2][0..5] (row_3)
    .float 1.0, 2.0, 3.0, 4.0, 3.0, 2.0    # A[3][0..5] (row_4)
    .float 2.0, 1.0, 0.0, 1.0, 2.0, 1.0    # A[4][0..5] (row_5)
    .float 1.0, 3.0, 2.0, 4.0, 1.0, 5.0    # A[5][0..5] (row_6)

.align 2
# Example 1 x n row-vector X (change to any values)
X:
    .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0    # X[0..5]

.align 2
# Allocating space for Result Vector Y (n floats)
# Note to reserve space for n floats; here n=6 so .space 24 (6 * 4 bytes)
Y:  .space 24

.align 2
# Determinant result (float) and comparison flag (word) storage
det_result:      .float 0.0
.align 2
comparison_flag: .word  0

.align 2
# Useful constant floats
ONE_F:   .float 1.0
NEGONE_F:.float -1.0

# Output format used for printing outputs (i.e. RARS ecall strings)
msgY:    .asciz "Y vector:\n"
msgDet:  .asciz "\nDeterminant:\n"
msgFlag: .asciz "\nComparison flag (1 = sum<det):\n"
newline: .asciz "\n"

.text
.globl main

# Register mapping/comments (kept consistent with the given register constraints):
# x5  = t0    (used as general temp / base pointer)
# x6  = t1
# x7  = t2
# x8  = s0    (callee-saved; used for N or preserved values)
# x9  = s1    (callee-saved; used for sign or saved values)
# x10 = a0    (argument or return register)
# x11 = a1
# x12 = a2
# x13 = a3
# x14 = a4
# x15 = a5
# ra (x1) and sp (x2) used per ABI for return and stack pointer.


# main
# Sets up arguments and calls matvec_mul, det_comp, compare_sum_det, and then prints on console
main:
    # Load addresses and n into integer registers (Here we use x10 to x13 as a0 to a3)
    la   x10, A         # a0 = &A (base address of matrix)
    la   x11, X         # a1 = &X (base address of input vector)
    la   x12, Y         # a2 = &Y (base address for output vector)
    lw   x13, N         # a3 = N (matrix/vector dimension)
    # Call matvec_mul(a0=&A, a1=&X, a2=&Y, a3=N)
    jal  ra, matvec_mul # jump-and-link to matrix-vector multiply

    # (Following 5 lines are for Determinant computation)
    # Prepare args for det_comp(a0=&A, a1=N)
    la   x10, A         # a0 = &A (we operate in-place on A for elimination)
    lw   x11, N         # a1 = N
    # Call det_comp; result returned in floating register fa0
    jal  ra, det_comp

    # Store determinant float result into det_result label
    la   x5, det_result # x5 = address of det_result
    fsw  fa0, 0(x5)     # write fa0 -> memory at det_result

    # (Following lines are for sum(Y) < det_result computation into comparision_flag)
    # Prepare args for compare_sum_det(a0=&Y, a1=&det_result, a2=N)
    la   x10, Y
    la   x11, det_result
    lw   x12, N
    # Call compare_sum_det; integer return in a0 (x10)
    jal  ra, compare_sum_det

    # Store comparison (a0) into comparison_flag (memory)
    la   x6, comparison_flag
    sw   x10, 0(x6)     # store a0 (x10) -> comparison_flag

    # (These lines to print outputs (Y vector, determinant, flag))
    # Print header for Y
    la   x10, msgY
    li   a7, 4          # ecall 4 = print_string (in RARS)
    ecall

    # Loop to print each element of Y
    la   x5, Y          # x5 = base of Y
    lw   x6, N          # x6 = n
    li   x7, 0          # x7 = loop index i
print_y:
    beq  x7, x6, print_y_done  # if i == n, we are done
    slli x8, x7, 2            # offset = i * 4
    add  x11, x5, x8          # x11 = &Y[i]
    flw  fa0, 0(x11)          # load Y[i] into fa0
    li   a7, 2                # ecall 2 = print_float
    ecall
    la   x10, newline
    li   a7, 4
    ecall
    addi x7, x7, 1            # i++ ; increment loop index and loop again
    j    print_y
print_y_done:

    # Print determinant header and value
    la   x10, msgDet		# load the address of the message string msgDet
    li   a7, 4			
    ecall			# print "Determinant =" on screen
    la   x11, det_result	# load the determinant value
    flw  fa0, 0(x11)
    li   a7, 2			# print the float value of determinant on screen
    ecall
    la   x10, newline		# move to new line
    li   a7, 4
    ecall

    # Print comparison flag header and value
    la   x10, msgFlag		# load address of the msgFlag label
    li   a7, 4
    ecall			# print "Comparison flag (1 = sum<det):"
    la   x10, comparison_flag
    lw   a0, 0(x10)     # load integer flag into a0 for print_int
    li   a7, 1          # ecall 1 = print_int; prints comparision flag value on screen
    ecall
    la   x10, newline
    li   a7, 4
    ecall

    # Exit program
    li   a7, 10         # ecall 10 = exit
    ecall

########################################################################
# Here I implement matvec_mul(a0=&A, a1=&X, a2=&Y, a3=N) subroutine 
# This performs Y = A * X, and uses only x5 to x15 for integer work and fa* for FP.
# Also saves ra and s0 (x8) on stack per calling convention.

matvec_mul:
    addi sp, sp, -8     # make room on stack (2 words)
    sw   ra, 4(sp)      # save return address
    sw   x8, 0(sp)      # save s0 because we will use it

    # Map incoming argument registers to our chosen regs
    mv   x5, x10        # x5 = &A
    mv   x6, x11        # x6 = &X
    mv   x7, x12        # x7 = &Y
    mv   x8, x13        # x8 = N
    li   x9, 0          # x9 = i = 0 (outer loop index)

mv_outer:
    beq  x9, x8, mv_done    # if i == N, done
    fmv.s.x fa0, x0         # fa0 = 0.0 ; accumulator for row sum
    li   x10, 0             # x10 = j = 0 (inner loop index)

mv_inner:
    beq  x10, x8, mv_store  # if j == N, store Y[i]
    # Computing the linear index = i*N + j
    mul  x11, x9, x8        # x11 = i*N
    add  x11, x11, x10      # x11 = i*N + j
    slli x11, x11, 2        # byte offset = (i*N + j)*4
    add  x12, x5, x11       # x12 = &A[i][j]
    flw  fa1, 0(x12)        # fa1 = A[i][j]

    # Load X[j]
    slli x11, x10, 2        # offset = j*4
    add  x12, x6, x11       # x12 = &X[j]
    flw  fa2, 0(x12)        # fa2 = X[j]

    # sum += A[i][j] * X[j]
    fmul.s fa3, fa1, fa2
    fadd.s fa0, fa0, fa3

    addi x10, x10, 1        # j++; increment loop index and repeat
    j    mv_inner

mv_store:
    # Store accumulated sum into Y[i]
    slli x11, x9, 2	    # x9 << 2 ; multiply by 4
    add  x12, x7, x11	    # add offset to the base address of Y
    fsw  fa0, 0(x12)        # Y[i] = fa0

    addi x9, x9, 1          # i++
    j    mv_outer

mv_done:
    # Restore saved registers and return
    lw   ra, 4(sp)
    lw   x8, 0(sp)
    addi sp, sp, 8 	    # restores stack pointer
    ret

########################################################################
# Here I calculate the determinant in the det_comp(a0=&A, a1=N) subroutine
# To find determinant I use Gaussian elimination with partial pivoting algorithm:
# 1) performs in-place row operations on matrix A
# 2) returns determinant in fa0
# 3) uses x5 to x15 and floating regs (fs0 for holding abs value)
# 4) saves ra and a few callee-saved regs on stack

det_comp:
    addi sp, sp, -20         # allocate 20 bytes to save registers
    sw   ra, 16(sp)          # save return address
    sw   x8, 12(sp)          # save s0
    sw   x9, 8(sp)           # save s1
    sw   x10, 4(sp)          # save a0 (temp)
    sw   x11, 0(sp)          # save a1 (temp)

    mv   x5, x10             # x5 = &A (argument a0)
    mv   x8, x11             # x8 = N  (argument a1)
    li   x6, 0               # x6 = i (outer loop pivot index)
    li   x9, 1               # x9 = sign multiplier (1 or -1)

outer_pivot:
    beq  x6, x8, compute_product  # when i == N, elimination finished

    mv   x7, x6              # x7 = max_row (initially i)

    # Load the pivot A[i][i] into fa0
    mul  x11, x6, x8
    add  x11, x11, x6        # x11 = i*N + i (linear index)
    slli x11, x11, 2        # byte offset = (i*N + i) * 4
    add  x12, x5, x11       # x12 = &A[i][i]
    flw  fa0, 0(x12)        # fa0 = A[i][i]

    # Compute absolute value of pivot into fs0:
    # ft0 = fa0 ; ft1 = 0 ; if fa0 < 0 then ft0 = -fa0 ; fs0 = ft0
    fmv.s  ft0, fa0	     # float ft0 = fa0;
    fmv.s.x ft1, x0	     # float ft1 = 0.0;
    flt.s  x13, fa0, ft1     # x13 = 1 if fa0 < 0.0
    beqz  x13, no_neg_p0     # if the number is already ≥ 0, we don’t want to change it.
    fsub.s ft0, ft1, fa0     # ft0 = 0.0 - fa0 = -fa0
no_neg_p0:
    fmv.s fs0, ft0           # fs0 = |pivot|

    addi x11, x6, 1          # start k = i+1 to search for max pivot

find_max_loop:
    beq  x11, x8, pivot_found # if k == N end search

    # Load candidate A[k][i]
    mul  x12, x11, x8
    add  x12, x12, x6
    slli x12, x12, 2
    add  x13, x5, x12
    flw  fa1, 0(x13)         # fa1 = A[k][i]

    # Compute abs(fa1) and move to ft2
    fmv.s ft2, fa1
    fmv.s.x ft3, x0
    flt.s x14, fa1, ft3
    beqz x14, no_neg_cand
    fsub.s ft2, ft3, fa1     # ft2 = -fa1 if negative
no_neg_cand:
    # Compare current max abs (fs0) with candidate abs (ft2)
    flt.s x14, fs0, ft2
    beqz x14, skip_update_max
    fmv.s fs0, ft2           # update fs0 = candidate abs
    mv   x7, x11             # update max_row = k
skip_update_max:
    addi x11, x11, 1
    j    find_max_loop

pivot_found:
    # If max_row != i then swap rows i and max_row (full row swap)
    beq  x7, x6, no_row_swap
    li   x11, 0              # column index j = 0

swap_row_loop:
    beq  x11, x8, swap_done  # finished swapping all columns
    # Load A[i][j] into fa2
    mul  x12, x6, x8
    add  x12, x12, x11
    slli x12, x12, 2
    add  x13, x5, x12
    flw  fa2, 0(x13)
    # Load A[max_row][j] into fa3
    mul  x14, x7, x8
    add  x14, x14, x11
    slli x14, x14, 2
    add  x15, x5, x14
    flw  fa3, 0(x15)
    # Swap memory words
    fsw  fa3, 0(x13)
    fsw  fa2, 0(x15)
    addi x11, x11, 1
    j    swap_row_loop
swap_done:
    li   x11, -1
    mul  x9, x9, x11        # flip sign multiplier s1 *= -1

no_row_swap:
    # Reload pivot (A[i][i]) because swap may have changed it
    mul  x11, x6, x8	    # compute row offset: x11 = x6*x8 = i*N
    add  x11, x11, x6	    # x11 = i*N + i
    slli x11, x11, 2	    # multiplying by 4 to compute byte offset
    add  x12, x5, x11	    # x12 = (base address of A) + (byte offset)
    flw  fa0, 0(x12)

    # If pivot is zero => singular matrix => determinant is zero
    fmv.x.w x11, fa0
    beqz x11, det_zero

    # Perform elimination for rows k = i+1 .. N-1
    addi x11, x6, 1

elim_k:
    beq  x11, x8, next_pivot  # if k == N, go to next pivot
    # Load A[k][i] into fa1
    mul  x12, x11, x8  	      # (similar process of loading as before)
    add  x12, x12, x6
    slli x12, x12, 2
    add  x13, x5, x12
    flw  fa1, 0(x13)
    # factor = A[k][i] / pivot
    fdiv.s fa2, fa1, fa0

    # For each column j = i .. N-1 update A[k][j] -= factor * A[i][j]
    mv   x12, x6            # j = i
elim_j:
    beq  x12, x8, done_row_elim
    # Load A[i][j] into ft0
    mul  x13, x6, x8
    add  x13, x13, x12
    slli x13, x13, 2
    add  x14, x5, x13
    flw  ft0, 0(x14)
    # Load A[k][j] into ft1
    mul  x13, x11, x8
    add  x13, x13, x12
    slli x13, x13, 2
    add  x14, x5, x13
    flw  ft1, 0(x14)
    # Compute ft1 = ft1 - factor * ft0
    fmul.s ft2, fa2, ft0   # fa2 = factor = A[k][i]/A[i][i]
    fsub.s ft1, ft1, ft2
    fsw  ft1, 0(x14)       # store updated A[k][j]
    addi x12, x12, 1	   # j++ ; Move to next col of same row k, repeat loop
    j    elim_j

done_row_elim:
    addi x11, x11, 1       # k++ ; Move to the next row after finished with the kth row
    j    elim_k

next_pivot:
    addi x6, x6, 1       # i++ (next pivot row)
    j    outer_pivot

det_zero:
    fmv.s.x fa0, x0      # set determinant fa0 = 0.0
    j    det_cleanup

compute_product:
    # Multiply diagonal entries to compute determinant
    la   x11, ONE_F
    flw  fa0, 0(x11)     # fa0 = 1.0 (accumulator)
    li   x6, 0           # index i = 0

diag_loop:
    beq  x6, x8, apply_sign  # when i == N end product loop
    mul  x12, x6, x8
    add  x12, x12, x6
    slli x12, x12, 2
    add  x13, x5, x12
    flw  ft0, 0(x13)     # ft0 = A[i][i]
    fmul.s fa0, fa0, ft0 # fa0 *= A[i][i]
    addi x6, x6, 1
    j    diag_loop

apply_sign:
    # Apply sign correction if odd number of row swaps occurred
    li   x11, 1
    beq  x9, x11, det_cleanup # if sign == 1 skip applying -1
    la   x11, NEGONE_F
    flw  ft0, 0(x11)
    fmul.s fa0, fa0, ft0   # fa0 *= -1.0

det_cleanup:
    # Restore saved registers and return (fa0 holds determinant)
    lw   ra, 16(sp)
    lw   x8, 12(sp)
    lw   x9, 8(sp)
    lw   x10, 4(sp)
    lw   x11, 0(sp)
    addi sp, sp, 20
    ret

########################################################################
# Here I calculate for comparison flag with compare_sum_det(a0=&Y, a1=&det_result, a2=N) subroutine
# Algorithm: Sum Y and compare with det_result, return a0 = 1 if sum < det else 0
# This also uses only x5 to x15 (and ra/sp) and FP accumulators

compare_sum_det:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   x8, 0(sp)

    mv   x5, x10   # x5 = base Y (argument a0)
    mv   x6, x11   # x6 = &det_result (argument a1)
    mv   x8, x12   # x8 = N (argument a2)
    fmv.s.x fa0, x0 # fa0 = 0.0 accumulator for sum
    li   x7, 0      # index i = 0

sum_loop:
    beq  x7, x8, sum_done
    slli x13, x7, 2
    add  x14, x5, x13
    flw  fa1, 0(x14)     # fa1 = Y[i]
    fadd.s fa0, fa0, fa1 # sum += Y[i]
    addi x7, x7, 1
    j    sum_loop

sum_done:
    flw  fa2, 0(x6)      # load det_result into fa2
    flt.s x10, fa0, fa2  # x10 = 1 if sum < det else 0
    # Return: a0 must contain the integer return value; x10 is a0 so good.
    lw   ra, 4(sp)
    lw   x8, 0(sp)
    addi sp, sp, 8
    ret


# This marks the end of our code
# We have successfully implemented multiplication of matrix with row vector, determinant computation using Gaussian Elimination,
# and computation of comparison flag

########################################################################