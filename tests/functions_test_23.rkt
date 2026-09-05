; Regression: >6 arguments, using packed extra parameters in the body.
(define (sum-extra [a : Integer] [b : Integer] [c : Integer]
                   [d : Integer] [e : Integer]
                   [u : Integer] [v : Integer]) : Integer
  (+ u v))
(sum-extra 1 2 3 4 5 6 7)
