;; Test 18: store computed values from arithmetic into vector fields
;; Expected: 100
(let ([v (vector 0 0 0)])
  (begin
    (vector-set! v 0 (+ 30 5))        ;; 35
    (vector-set! v 1 (- 100 59))      ;; 41
    (vector-set! v 2 (+ 1 23))        ;; 24
    (+ (vector-ref v 0)
       (+ (vector-ref v 1) (vector-ref v 2)))))
