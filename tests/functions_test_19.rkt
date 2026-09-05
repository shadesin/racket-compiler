; Test: selecting predicate functions
(define (is-even [n : Integer]) : Boolean
  (if (eq? n 0) #t (is-odd (- n 1))))
(define (is-odd [n : Integer]) : Boolean
  (if (eq? n 0) #f (is-even (- n 1))))
(define (select-check [flag : Boolean]) : (Integer -> Boolean)
  (if flag is-even is-odd))
(let ([pred (select-check #f)])
  (if (pred 7) 1 0))