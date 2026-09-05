;; while_test_25: while-loop with counter counting DOWN using >=
;; Exercises the >= comparison operator in a while condition.
;; Counts from 10 down to 1: sum = 10+9+8+...+1 = 55
;; Expected: 55
(let ([i 10])
  (let ([sum 0])
    (begin
      (while (>= i 1)
        (begin
          (set! sum (+ sum i))
          (set! i (- i 1))))
      sum)))
