;; cond_test_31: (>= x y) comparison operator -- tests select-instructions for >=
;; Expected: 42 (10 >= 10 is true)
(let ([x 10])
  (let ([y 10])
    (if (>= x y) 42 0)))
