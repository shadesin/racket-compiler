; Test: mutable variable passed as function argument (exercises collect-set! + uncover-get!-exp Apply fix)
(define (double [x : Integer]) : Integer (+ x x))
(let ([n 0])
  (begin
    (set! n 21)
    (double n)))
