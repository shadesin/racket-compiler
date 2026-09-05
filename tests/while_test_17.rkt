;; while_test_17: Interleaved set! and if — tests evaluation order correctness.
;; Exercises the key ordering guarantee of uncover-get!: reads of mutable
;; variables must not be reordered past set! operations.
;;
;; Classify x=1..10: if x<=6, add x to `lo`; else add x to `hi`.
;; Then return lo + hi*2 to mix both values.
;;
;; lo = 1+2+3+4+5+6 = 21
;; hi = 7+8+9+10 = 34
;; result = 21 + 34*2 = 21 + 68 = 89
;; Expected: 89
(let ([x 1])
  (let ([lo 0])
    (let ([hi 0])
      (begin
        (while (<= x 10)
          (begin
            (if (<= x 6)
              (set! lo (+ lo x))
              (set! hi (+ hi x)))
            (set! x (+ x 1))))
        (+ lo (+ hi hi))))))
