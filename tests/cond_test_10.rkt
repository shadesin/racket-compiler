;; cond_test_10: if nested in the condition of another if
;; Exercises that the condition of if is processed with rco-exp (not rco-atom),
;; so the inner if is NOT replaced by a temporary variable.
;; Expected: 42
(let ([x 2])
  (if (if (< x 1) #f (eq? x 2))
    42
    0))
