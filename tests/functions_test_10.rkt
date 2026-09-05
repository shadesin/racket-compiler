; Test: mutual recursion (even/odd check via mutual tail calls)
(define (my-even [n : Integer]) : Boolean
  (if (eq? n 0) #t (my-odd (- n 1))))
(define (my-odd [n : Integer]) : Boolean
  (if (eq? n 0) #f (my-even (- n 1))))
(if (my-even 42) 1 0)
