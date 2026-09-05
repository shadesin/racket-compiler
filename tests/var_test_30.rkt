;; var_test_30: unary negation of a let-bound variable.
;; Tests: movq $7, var; negq var  (or negq var when dst == src).
;; Adding 49 so the result is positive (exit codes are unsigned bytes).
;; -(7) + 49 = 42
;; Expected: 42
(let ([x 7])
  (+ (- x) 49))
