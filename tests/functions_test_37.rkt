;; functions_test_37: function that takes and returns a vector
;; Tests that vector-typed arguments and return values are treated as
;; GC-traced pointers in the root stack during function calls.
;; Expected: 99
(define (update-first [v : (Vector Integer)] [val : Integer]) : Integer
  (begin
    (vector-set! v 0 val)
    (vector-ref v 0)))
(let ([v (vector 0)])
  (update-first v 99))
