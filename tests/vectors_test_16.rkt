;; Test 14: vector as rhs of set! (mutable variable holds a vector pointer)
;; Expected: 99
(let ([v1 (vector 1)])
  (let ([v2 (vector 99)])
    (begin
      (set! v1 v2)
      (vector-ref v1 0))))
