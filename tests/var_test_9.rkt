;; remove complex operands test
;; Nested arithmetic as an operand
;; expected shape after removing complex operands:
;; (let ([tmp (+ 2 3)])
;; (+ 1 tmp))

(+ 1 (+ 2 3))