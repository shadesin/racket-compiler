;; Force vector-typed values live across a call to spill into GC root slots.
(define (identity [x : Integer]) : Integer x)

(let ([v1 (vector 1)])
  (let ([v2 (vector 2)])
    (let ([v3 (vector 3)])
      (let ([v4 (vector 4)])
        (let ([v5 (vector 5)])
          (let ([v6 (vector 6)])
            (let ([result (identity 21)])
              (+ result
                 (+ (vector-ref v1 0)
                    (+ (vector-ref v2 0)
                       (+ (vector-ref v3 0)
                          (+ (vector-ref v4 0)
                             (+ (vector-ref v5 0)
                                (vector-ref v6 0))))))))))))))
