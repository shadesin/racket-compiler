;; Test 19: two independent vectors, cross-reference mutation
;; Write element from v1 into v2, then read from v2
;; Expected: 77
(let ([v1 (vector 77 88)])
  (let ([v2 (vector 0 0)])
    (begin
      (vector-set! v2 0 (vector-ref v1 0))
      (vector-ref v2 0))))
