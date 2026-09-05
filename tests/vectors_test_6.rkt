;; Test 4: vector with boolean result
;; Expected: 5
(let ([t (vector 3 5 7)])
  (if (< (vector-ref t 0) (vector-ref t 1))
      (vector-ref t 1)
      (vector-ref t 0)))
