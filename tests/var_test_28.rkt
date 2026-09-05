;; var_test_28: binary subtraction (- e1 e2) exercises subq instruction.
;; EoC §2.7: "Do not translate (- e1 e2) to (+ e1 (- e2)) — use subq directly."
;; Expected: 30
(let ([x 50])
  (let ([y 20])
    (- x y)))
