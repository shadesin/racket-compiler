;; Test 12: accumulate sum into a vector slot using a while loop
;; Simulates a simple mutable accumulator: sum 0..9 = 45
;; Expected: 45
(let ([acc (vector 0)])
  (let ([i 0])
    (begin
      (while (< i 10)
        (begin
          (vector-set! acc 0 (+ (vector-ref acc 0) i))
          (set! i (+ i 1))))
      (vector-ref acc 0))))
