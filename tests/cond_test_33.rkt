;; cond_test_33: patch-instructions: cmpq _, (Imm n) -- second arg must not be immediate.
;; (eq? (read) 42) -- after RCO, tmp = (read), then cmpq $42, tmp.
;; x86: cmpq $42, tmp  is OK (imm is first operand).
;; But if generated as: cmpq tmp, $42, we need to patch.
;; Expected: 1
(if (eq? 42 42) 1 0)
