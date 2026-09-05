;; vectors_test_27: vector aliasing -- t1 and t2 point to same vector.
;; Mutation through t2 must be visible through t1. Tests eq? for same-vector.
;; (from EoC §6.1 example)
;; Expected: 42
(let ([t1 (vector 3 7)])
  (let ([t2 t1])
    (let ([_ (vector-set! t2 0 42)])
      (vector-ref t1 0))))
