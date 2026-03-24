;; Sum 1..5 using a while loop. Expected: 15
(let ([sum 0])
  (let ([i 1])
    (begin
      (while (<= i 5)
        (begin
          (set! sum (+ sum i))
          (set! i (+ i 1))))
      sum)))
