;; Fibonacci via iterative while loop.
;; a=1, b=1: after 8 swaps the sequence is 1,1,2,3,5,8,13,21,34,55
;; b ends at 55 after 8 iterations.
;; Expected: 55
(let ([a 1])
  (let ([b 1])
    (let ([i 0])
      (begin
        (while (< i 8)
          (begin
            (let ([tmp (+ a b)])
              (begin
                (set! a b)
                (set! b tmp)))
            (set! i (+ i 1))))
        b))))
