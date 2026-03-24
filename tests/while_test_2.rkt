;; Count down from 5 to 1, result is final value of i (0). Expected: 0
(let ([i 5])
  (begin
    (while (> i 0)
      (set! i (- i 1)))
    i))
