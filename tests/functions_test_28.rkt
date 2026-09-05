; Test: and/or in the condition of a function call result used as bool
; Exercises shrink-exp seeing Apply in condition context
(define (add [x : Integer] [y : Integer]) : Integer (+ x y))
(if (and (eq? (add 3 4) 7) (eq? (add 1 1) 2)) 1 0)
