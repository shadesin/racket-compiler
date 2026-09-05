;; Exercise the exact zero- and six-register-argument ABI boundaries.
(define (answer) : Integer 21)
(define (sum6 [a : Integer] [b : Integer] [c : Integer]
              [d : Integer] [e : Integer] [f : Integer]) : Integer
  (+ a (+ b (+ c (+ d (+ e f))))))
(+ (answer) (sum6 1 2 3 4 5 6))
