;; cond_test_20: TYPE ERROR — mismatched branch types in 'if'.
;; The then-branch returns Boolean (#f) and the else-branch returns Integer (1).
;; The type checker requires both branches to have the same type.
;; This exercises the (check-type-equal? Tt Te e) check in type-check-Lif.
(if (> 1 1) #f 1)
