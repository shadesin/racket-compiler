;; while_test_14: Accumulate max of a sequence read from stdin.
;; Tests: while loop reading multiple inputs, mutable variable holding running max,
;; if-inside-while updating max only when new value is larger.
;; Exercises liveness with multiple mutable vars live across loop back-edge.
;;
;; Input: n=5, values: 3 7 2 9 1
;; Max = 9
;; Expected: 9
(let ([n (read)])
  (let ([mx (read)])
    (let ([i 1])
      (begin
        (while (< i n)
          (begin
            (let ([v (read)])
              (if (> v mx)
                (set! mx v)
                (set! mx mx)))
            (set! i (+ i 1))))
        mx))))
