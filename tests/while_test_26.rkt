;; while_test_26: while with a (begin ...) as the condition (side-effects in cond)
;; AND a nested while inside to test liveness convergence across 2 levels.
;; Outer: i from 1 to 3. Inner: j from 1 to i. Total pairs = 1+2+3 = 6.
;; Expected: 6
(let ([i 1])
  (let ([count 0])
    (begin
      (while (<= i 3)
        (begin
          (let ([j 1])
            (while (<= j i)
              (begin
                (set! count (+ count 1))
                (set! j (+ j 1)))))
          (set! i (+ i 1))))
      count)))
