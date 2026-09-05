;; Test 10: vector-length used in arithmetic
;; Expected: 10  (length 5 + length 5)
(let ([v (vector 0 1 2 3 4)])
  (+ (vector-length v) (vector-length v)))
