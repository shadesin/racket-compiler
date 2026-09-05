; Test: 7 parameter function (exercises limit-functions)
; First 5 args passed in regs, 6th+7th packed in a vector
(define (sum7 [a : Integer] [b : Integer] [c : Integer]
              [d : Integer] [e : Integer] [f : Integer]
              [g : Integer]) : Integer
  (+ a (+ b (+ c (+ d (+ e (+ f g)))))))
(sum7 1 2 3 4 5 6 7)
