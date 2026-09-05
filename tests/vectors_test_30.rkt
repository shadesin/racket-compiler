;; vectors_test_30: vector outliving its binding variable (lifetime > scope)
;; (from EoC §6.1 motivating example)
;; w goes out of scope inside the inner let, but the vector it bound still
;; lives on the heap and is reachable through v.
;; Expected: 42
(let ([v (vector (vector 44))])
  (let ([x (let ([w (vector 42)])
              (let ([_ (vector-set! v 0 w)])
                0))])
    (+ x (vector-ref (vector-ref v 0) 0))))
