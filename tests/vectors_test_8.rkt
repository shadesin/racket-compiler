;; Test 6: nested vector (vector of vectors)
;; Expected: 42
(let ([inner (vector 42)])
  (let ([outer (vector inner)])
    (vector-ref (vector-ref outer 0) 0)))
