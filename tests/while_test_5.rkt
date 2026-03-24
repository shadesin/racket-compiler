;; Sum of even numbers from 0 to 10 (inclusive) by stepping i by 2.
;; 0 + 2 + 4 + 6 + 8 + 10 = 30
;; Expected: 30
(let ([sum 0])
  (let ([i 0])
    (begin
      (while (<= i 10)
        (begin
          (set! sum (+ sum i))
          (set! i (+ i 2))))
      sum)))
