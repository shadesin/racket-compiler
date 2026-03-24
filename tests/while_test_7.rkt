;; If-inside-while: count how many integers in 1..10 are greater than 5.
;; Numbers > 5: 6, 7, 8, 9, 10 -> count = 5
;; Expected: 5
(let ([count 0])
  (let ([i 1])
    (begin
      (while (<= i 10)
        (begin
          (if (> i 5)
              (set! count (+ count 1))
              (void))
          (set! i (+ i 1))))
      count)))
