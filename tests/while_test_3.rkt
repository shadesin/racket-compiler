;; Test mutable variable ordering: (+ x (begin (set! x 40) x))
;; x starts at 2; first read of x is 2, set! sets to 40, second read is 40.
;; Result: 2 + 40 = 42
(let ([x 2])
  (+ x (begin (set! x 40) x)))
