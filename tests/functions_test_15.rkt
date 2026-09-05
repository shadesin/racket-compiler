; Test: indirect call through a returned function pointer
(define (add [x : Integer] [y : Integer]) : Integer (+ x y))
(define (sub [x : Integer] [y : Integer]) : Integer (- x y))
(define (pick [flag : Boolean]) : (Integer Integer -> Integer)
  (if flag add sub))
(define (apply-picked [flag : Boolean] [x : Integer] [y : Integer]) : Integer
  ((pick flag) x y))
(apply-picked #f 50 8)