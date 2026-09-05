;; cond_test_34: nested if in assignment position - tests create-block avoidance
;; Both branches share a continuation; create-block ensures no code duplication.
;; Expected: 52
(let ([y 10])
  (let ([x (if (< y 5) 40 42)])
    (+ x y)))
