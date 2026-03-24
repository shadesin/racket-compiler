;; cond_test_9: if expression as an operand to +
;; Exercises rco-atom treating if as a complex expression:
;; the if gets bound to a fresh temporary variable.
;; Expected: 21
(let ([x 5])
  (+ (if (< x 3) 10 20) 1))
