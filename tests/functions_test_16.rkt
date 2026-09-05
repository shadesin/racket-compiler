; Test: tail-recursive iteration with helper function
(define (step [x : Integer]) : Integer (+ x 2))
(define (iter2 [n : Integer] [x : Integer]) : Integer
  (if (eq? n 0)
      x
  (iter2 (- n 1) (step x))))
(iter2 21 0)