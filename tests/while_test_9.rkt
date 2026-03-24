;; Nested while loops: compute 3 * 5 via repeated increment.
;; Outer loop runs 3 times; inner loop adds 1 to result 5 times each.
;; Expected: 15
(let ([result 0])
  (let ([i 0])
    (begin
      (while (< i 3)
        (begin
          (let ([j 0])
            (while (< j 5)
              (begin
                (set! result (+ result 1))
                (set! j (+ j 1)))))
          (set! i (+ i 1))))
      result)))
