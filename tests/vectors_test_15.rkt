;; Test 13: multiple sequential vector-set! to different fields
;; Expected: 60  (10 + 20 + 30)
(let ([v (vector 0 0 0)])
  (begin
    (vector-set! v 0 10)
    (vector-set! v 1 20)
    (vector-set! v 2 30)
    (+ (vector-ref v 0)
       (+ (vector-ref v 1) (vector-ref v 2)))))
