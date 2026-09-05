;; cond_test_36: complex boolean variable in predicate position
;; Tests: (Var x) in predicate -- generates (eq? x #t) comparison
;; After uncover-get!/shrink, x is a Bool var; explicate-pred must emit cmpq.
;; Expected: 42
(let ([x (eq? 5 5)])
  (if x 42 0))
