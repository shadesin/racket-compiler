;; Test 20: update a nested vector's element through the outer vector
;; Expected: 55
(let ([inner (vector 0)])
  (let ([outer (vector inner)])
    (begin
      (vector-set! (vector-ref outer 0) 0 55)
      (vector-ref inner 0))))
