; Test: vector transformation using multiple helper functions
(define (double [x : Integer]) : Integer (+ x x))
(define (inc [x : Integer]) : Integer (+ x 1))
(define (transform-pair [a : Integer] [b : Integer]) : (Vector Integer Integer)
  (vector (double a) (inc b)))
(let ([v (transform-pair 10 21)])
  (+ (vector-ref v 0) (vector-ref v 1)))