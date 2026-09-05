;; Test 5: vector aliasing -- two vars pointing to same vector
;; Expected: 100
(let ([t (vector 1 2 3)])
  (let ([alias t])
    (begin
      (vector-set! alias 0 100)
      (vector-ref t 0))))
