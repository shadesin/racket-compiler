;; Test 11: vector survives after its binding goes out of scope
;; (tests that GC preserves reachable tuples — §6.1 lifetime example)
;; Expected: 42
(let ([v (vector (vector 44))])
  (let ([x (let ([w (vector 42)])
              (begin
                (vector-set! v 0 w)
                0))])
    (+ x (vector-ref (vector-ref v 0) 0))))
