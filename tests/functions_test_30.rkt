; Test: or inside a function argument
(define (inc [x : Integer]) : Integer (+ x 1))
(inc (if (or #f #t) 41 0))
