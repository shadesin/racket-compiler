;; While loop with and-condition (both must hold).
;; Sum values of i while (i > 0 and i < 6), starting from i=10, decrementing.
;; i=10: 10>0 and 10<6? no -> skip
;; Actually start i=1, go up, stop when NOT (i>0 AND i<6) i.e. when i>=6.
;; sum = 1+2+3+4+5 = 15, but we've already tested that. Let's use a tighter variant:
;;
;; Accumulate sum while i<8 AND sum<20.
;; i=1: sum=1  (1<8,  1<20 -> continue)
;; i=2: sum=3  (2<8,  3<20 -> continue)
;; i=3: sum=6  (3<8,  6<20 -> continue)
;; i=4: sum=10 (4<8, 10<20 -> continue)
;; i=5: sum=15 (5<8, 15<20 -> continue)
;; i=6: sum=21 (6<8, 21<20 -> FALSE: sum>=20, stop)
;; Loop exits after 5 iterations. sum = 15 + 6 = 21.
;; Expected: 21
(let ([sum 0])
  (let ([i 1])
    (begin
      (while (and (< i 8) (< sum 20))
        (begin
          (set! sum (+ sum i))
          (set! i (+ i 1))))
      sum)))
