; Test: vector containing a function pointer (exercises is-gc-pointer-type? fix)
; Stores a function reference in a vector, then calls it through vector-ref
(define (double [x : Integer]) : Integer (+ x x))
(define (triple [x : Integer]) : Integer (+ x (+ x x)))
(let ([v (vector double triple)])
  (let ([f (vector-ref v 0)])
    (f 21)))
