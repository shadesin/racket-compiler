;; Power of 2: compute 2^7 by repeated doubling.
;; result doubles each iteration: 1->2->4->8->16->32->64->128
;; Expected: 128
(let ([result 1])
  (let ([i 0])
    (begin
      (while (< i 7)
        (begin
          (set! result (+ result result))
          (set! i (+ i 1))))
      result)))
