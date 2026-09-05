; Test: mutual recursion as a predicate
(define (is-even [n : Integer]) : Boolean
  (if (eq? n 0) #t (is-odd (- n 1))))
(define (is-odd [n : Integer]) : Boolean
  (if (eq? n 0) #f (is-even (- n 1))))
(if (is-odd 15) 1 0)