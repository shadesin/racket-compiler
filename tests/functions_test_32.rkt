; Test: 8 parameter function - exercises limit-functions more aggressively
; First 5 go in registers, params 5-7 packed into a tuple as 6th arg
(define (sum8 [a : Integer] [b : Integer] [c : Integer]
              [d : Integer] [e : Integer] [f : Integer]
              [g : Integer] [h : Integer]) : Integer
  (+ a (+ b (+ c (+ d (+ e (+ f (+ g h))))))))
(sum8 1 2 3 4 5 6 7 8)
