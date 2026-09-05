; Test: returning and invoking function pointers
(define (add [x : Integer] [y : Integer]) : Integer (+ x y))
(define (sub [x : Integer] [y : Integer]) : Integer (- x y))
(define (pick [flag : Boolean]) : (Integer Integer -> Integer)
  (if flag add sub))
(+ ((pick #t) 10 20) ((pick #f) 20 5))
