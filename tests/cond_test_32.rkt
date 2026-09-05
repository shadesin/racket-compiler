;; cond_test_32: (> x y) operator -- tests select-instructions for >
;; Expected: 0 (5 > 10 is false)
(let ([x 5])
  (let ([y 10])
    (if (> x y) 1 0)))
