;; Test 23: Variable reuse pattern
(let ([x 5])
  (let ([y (+ x 10)])
    (let ([z (+ y 20)])
      z)))
