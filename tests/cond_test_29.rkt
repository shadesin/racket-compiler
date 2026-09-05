;; cond_test_29: explicate-pred (Bool #t) => thn directly (no block created)
;; Tests that #t constant in predicate position just returns thn.
;; Expected: 42
(if #t 42 0)
