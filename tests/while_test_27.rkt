;; while_test_27: compute fibonacci iteratively using while loop + set!.
;; fib(10) = 55 (0,1,1,2,3,5,8,13,21,34,55)
;; Expected: 55
(let ([a 0])
  (let ([b 1])
    (let ([i 0])
      (begin
        (while (< i 9)
          (begin
            (let ([tmp (+ a b)])
              (begin
                (set! a b)
                (set! b tmp)))
            (set! i (+ i 1))))
        b))))
