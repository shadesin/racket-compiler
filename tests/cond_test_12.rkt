;; cond_test_12: (not ...) in predicate position
;; Exercises the (Prim 'not ...) case in explicate-pred,
;; which swaps the then/else branches and recurses.
;; Also exercises the (if ...) case in explicate-assign (if on rhs of let).
;; Input: 3   => (< 3 5) = #t, (not #t) swaps => else branch => 0
;; Input: 7   => (< 7 5) = #f, (not #f) swaps => then branch => 1
;; Expected (input 3): 0
(let ([x (read)])
  (if (not (< x 5))
    1
    0))
