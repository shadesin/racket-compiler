;; cond_test_30: explicate-pred with (not (not e)) -- double negation
;; (not (not e)) should cancel: swap-swap => original branches.
;; Expected: 42
(let ([x 5])
  (if (not (not (< x 10)))
    42
    0))
