;; functions_test_34: higher-order function (function passed as argument)
;; apply-twice: takes a function f and an integer n, applies f(f(n)).
;; increment: adds 1 to its argument.
;; apply-twice(increment, 40) = increment(increment(40)) = 42
;; Expected: 42
(define (increment [n : Integer]) : Integer
  (+ n 1))
(define (apply-twice [f : (Integer -> Integer)] [n : Integer]) : Integer
  (f (f n)))
(apply-twice increment 40)
