; Test: recursive Euclidean gcd
(define (gcd [a : Integer] [b : Integer]) : Integer
  (if (eq? b 0)
      a
      (gcd b (- a b))))
(gcd 84 42)