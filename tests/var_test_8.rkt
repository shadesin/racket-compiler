;; deep reuse of the same variable name
;; expected result: 4
(let ([x 1])
  (let ([x (let ([x 3]) x)])
    (+ x 1)))