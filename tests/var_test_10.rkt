;; remove complex operands test
;; Complex operand with let
(+ (let ([x 10]) (+ x 2))
   3)
;; this directly tests the monadic structure described in fig 2.15 of the book, page 27