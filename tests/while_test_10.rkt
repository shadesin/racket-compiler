;; Nested while where inner loop's start depends on outer variable.
;; Count pairs (i, j) where 1 <= i <= j <= 4.
;; i=1: j in {1,2,3,4} -> 4 pairs
;; i=2: j in {2,3,4}   -> 3 pairs
;; i=3: j in {3,4}     -> 2 pairs
;; i=4: j in {4}       -> 1 pair
;; Total = 4+3+2+1 = 10
;; Expected: 10
(let ([count 0])
  (let ([i 1])
    (begin
      (while (<= i 4)
        (begin
          (let ([j i])
            (while (<= j 4)
              (begin
                (set! count (+ count 1))
                (set! j (+ j 1)))))
          (set! i (+ i 1))))
      count)))
