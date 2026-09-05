;; cond_test_35: all comparison operators in sequence
;; Tests full set: eq?, <, <=, >, >= -- each used as condition
;; Expected: 5 (each condition true contributes 1)
(let ([x 5])
  (let ([y 5])
    (+ (+ (+ (+ (if (eq? x y) 1 0)
                 (if (< x 10) 1 0))
              (if (<= x y) 1 0))
           (if (> y 3) 1 0))
        (if (>= x 5) 1 0))))
