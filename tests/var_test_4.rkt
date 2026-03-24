;; simple shadowing
;; expected result: 10
(let ([x 32])
  (let ([x 10])
    x))