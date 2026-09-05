; Test: passing a function as an argument (higher-order function)
(define (apply-twice [f : (Integer -> Integer)] [x : Integer]) : Integer
  (f (f x)))
(define (inc [n : Integer]) : Integer
  (+ n 1))
(apply-twice inc 40)
