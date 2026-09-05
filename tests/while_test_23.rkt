;; while_test_23: while whose body contains an if; tests liveness across back-edge
;; when the condition of the if depends on the loop variable.
;; Sum of absolute values of: -3, -2, -1, 0, 1, 2, 3 (7 values from i = -3 to 3)
;; |i| for i=-3..3: 3+2+1+0+1+2+3 = 12
;; Expected: 12
(let ([i -3])
  (let ([sum 0])
    (begin
      (while (<= i 3)
        (begin
          (if (< i 0)
            (set! sum (+ sum (- i)))
            (set! sum (+ sum i)))
          (set! i (+ i 1))))
      sum)))
