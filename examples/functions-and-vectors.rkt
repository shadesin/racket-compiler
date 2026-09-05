;; Higher-order functions and a typed vector. Returns 42.
(define (increment [n : Integer]) : Integer
  (+ n 1))

(define (apply-twice [f : (Integer -> Integer)] [n : Integer]) : Integer
  (f (f n)))

(let ([values (vector 10 40)])
  (apply-twice increment (vector-ref values 1)))
