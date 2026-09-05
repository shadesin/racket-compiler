;; A live vector may contain raw function addresses, which GC must not trace.
(define (double [x : Integer]) : Integer (+ x x))

(let ([functions (vector double)])
  (let ([i 0])
    (begin
      (while (< i 2000)
        (begin
          (vector-set! (vector 0 0 0 0) 0 i)
          (set! i (+ i 1))))
      (let ([f (vector-ref functions 0)])
        (f 21)))))
