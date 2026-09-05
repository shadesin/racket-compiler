;; Test 7: deep nesting — vector of vector of vector
;; Expected: 7
(let ([v (vector (vector (vector 7)))])
  (vector-ref (vector-ref (vector-ref v 0) 0) 0))
