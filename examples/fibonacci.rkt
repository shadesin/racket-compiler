;; Iterative Fibonacci. The compiled program returns 55 as its exit status.
(let ([a 0])
  (let ([b 1])
    (let ([i 0])
      (begin
        (while (< i 9)
          (let ([next (+ a b)])
            (begin
              (set! a b)
              (set! b next)
              (set! i (+ i 1)))))
        b))))
