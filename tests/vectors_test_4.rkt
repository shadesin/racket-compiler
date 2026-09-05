;; Test 2: vector-set! mutation and subsequent read
;; Expected: 99
(let ([t (vector 10 20 30)])
  (begin
    (vector-set! t 1 99)
    (vector-ref t 1)))
