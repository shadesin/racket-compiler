;; var_test_34: patch-instructions: large immediate value in arithmetic.
;; 3000000000 > 2^31-1, cannot be encoded as 32-bit imm in addq/subq.
;; Must be patched: movq $3000000000, %rax; addq %rax, var.
;; We compute (- 3000000000 2999999958) = 42 so the result fits in a byte.
;; Expected: 42
(let ([x 3000000000])
  (- x 2999999958))
