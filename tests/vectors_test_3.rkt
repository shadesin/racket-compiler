;; Test 1: basic vector creation and element access
;; Expected: 4
(let ([t (vector 1 2 3)])
  (+ (vector-ref t 0) (vector-ref t 2)))
