;; multiple variables with selective shadowing
;; expected result: 30
(let ([x 5])
  (let ([y 10])
    (let ([x 20])
      (+ x y))))