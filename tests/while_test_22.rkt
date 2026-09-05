; Test: begin in predicate position with set! side-effect
; (begin (set! x ...) (< x 10)) — begin appears as the condition of while
; This specifically tests that begin in predicate position properly
; executes the side effects before evaluating the final boolean.
(let ([x 0])
  (let ([sum 0])
    (begin
      (while (begin (set! x (+ x 1)) (<= x 5))
        (set! sum (+ sum x)))
      sum)))
