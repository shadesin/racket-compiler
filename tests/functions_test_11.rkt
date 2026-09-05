; Test: chained calls across helper functions
(define (inc [x : Integer]) : Integer (+ x 1))
(define (double [x : Integer]) : Integer (+ x x))
(define (compute [x : Integer]) : Integer
  (inc (double x)))
(compute 20)