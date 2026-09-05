;; vectors_test_26: vector-set! return value is void (encoded as 0)
;; The result of (vector-set! ...) should be 0 (Void). Test this is handled.
;; We use the result of vector-set! in a let, then return a different value.
;; Expected: 42
(let ([v (vector 1 2 3)])
  (let ([_ (vector-set! v 0 99)])
    (vector-ref v 0)))
