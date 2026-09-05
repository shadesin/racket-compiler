;; Test 8: mutation through alias is visible via original variable
;; (tests shallow copy / aliasing semantics from §6.1)
;; Expected: 42
(let ([t1 (vector 3 7)])
  (let ([t2 t1])
    (begin
      (vector-set! t2 0 42)
      (vector-ref t1 0))))
