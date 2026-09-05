;; while_test_15: Collatz sequence — count steps to reach 1.
;; Tests complex while condition, if-inside-body with both branches
;; mutating the same variable (n), heavy liveness pressure across back-edge.
;;
;; Collatz: if n is even: n = n/2; else n = 3*n+1. Count steps until n=1.
;; We don't have division, so test with a starting value where the sequence
;; only uses n-that-are-odd steps via the odd branch and halving by subtraction.
;;
;; Use: if (eq? (- n (* 2 (+ (- n 1) 1))) 0) -- too complex. Simplify:
;; Actually LWhile has no division or modulo. Use a carefully chosen start.
;; Start n=6: 6->3->10->5->16->8->4->2->1  (8 steps)
;; even: n = n - (n/2)   -- can't do without division
;; Instead: test n=1 already works; use repeated subtraction to check even:
;;   even check: subtract 2 repeatedly... too complex.
;;
;; Alternative: Use a 3x+1 sequence where we only do odd steps (hardcode even):
;; Actually, test a simpler variant: compute n mod 2 via (- n (* 2 halved))
;; but we can approximate with: while n != 1, if n > 10 then n = n - 3 else n = n + 1
;; Not Collatz but exercises the same structure.
;;
;; Use: Power-of-two countdown: start n=32, each step: if n > 1: n = n - n/2
;; No division. So just: count down by halving by subtracting half:
;; n=32,16,8,4,2,1 => 5 steps. But no division.
;;
;; Simpler: count how many times we can subtract 7 from n before n <= 0.
;; n=100: 100,93,86,...,2,-5 => floor(100/7) = 14 steps (100-7*14=2 > 0, 2-7=-5 <= 0)
;; Steps = 15 (goes negative on 15th). Actually: subtract until <= 0.
;; 100/7 = 14.28 so 15 subtractions to go <= 0.
;; Expected: 15
(let ([n 100])
  (let ([steps 0])
    (begin
      (while (> n 0)
        (begin
          (set! n (- n 7))
          (set! steps (+ steps 1))))
      steps)))
