;; while_test_18: Nested loops with if controlling the inner loop bound.
;; Outer loop: i from 1 to 5.
;; Inner loop bound is data-dependent on i: inner runs j from 1 to i.
;; Also has an if inside the inner loop: only add j to sum when j is odd
;; (checked via (eq? (- j (* ... )) 0) -- no mod, so use (eq? (- j 1) (- j 1))...
;; Instead: track parity with a flip bit per inner iteration.
;;
;; outer i=1: inner j=1 (odd?=yes, parity=1) => sum+=1 => sum=1
;; outer i=2: inner j=1(odd,sum+=1=2), j=2(even,skip) => sum=2
;; outer i=3: inner j=1(odd,sum+=1=3), j=2(even), j=3(odd,sum+=3=6)
;; outer i=4: j=1(sum+=1=7), j=2(skip), j=3(sum+=3=10), j=4(skip)
;; outer i=5: j=1(sum+=1=11), j=2(skip), j=3(sum+=3=14), j=4(skip), j=5(sum+=5=19)
;; Expected: 19
(let ([i 1])
  (let ([sum 0])
    (begin
      (while (<= i 5)
        (begin
          (let ([j 1])
            (let ([parity 1])
              (while (<= j i)
                (begin
                  (if (eq? parity 1)
                    (set! sum (+ sum j))
                    (set! sum sum))
                  (set! parity (- 1 parity))
                  (set! j (+ j 1))))))
          (set! i (+ i 1))))
      sum)))
