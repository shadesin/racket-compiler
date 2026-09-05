;; while_test_13: Countdown with if-inside-while choosing different step sizes.
;; Tests: while condition, if inside body affecting loop variable, liveness
;; of multiple mutable vars across cyclic CFG edges.
;;
;; i starts at 20. Each iteration:
;;   if i is divisible by 3 (eq? (- i (* 3 (/ i 3))) 0): subtract 3
;;   else: subtract 2
;; Loop until i <= 0. Count iterations.
;;
;; But / isn't in LWhile. Use a simpler formulation:
;; i=20, step alternates: even iteration subtract 3, odd subtract 2.
;; Actually: if (> i 10) step=3 else step=2
;;   i=20,17,14,11 -> 8 (4 big steps), then 8,6,4,2,0 -> done (4 small steps). count=8
;; Expected: 8
(let ([i 20])
  (let ([count 0])
    (begin
      (while (> i 0)
        (begin
          (set! count (+ count 1))
          (if (> i 10)
            (set! i (- i 3))
            (set! i (- i 2)))))
      count)))
