;; Test 21: Simple register allocation with 3 variables
(let ([x 10])
  (let ([y 20])
    (let ([z 30])
      (+ x (+ y z)))))
