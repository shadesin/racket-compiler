;; var_test_33: variable used as both operands of +
;; When dest == src1 == src2, addq must be emitted as: addq var, var
;; (not: movq var, rax; addq var, rax; movq rax, var)
;; Expected: 84
(let ([x 42])
  (+ x x))
