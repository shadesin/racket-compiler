; Test: functions + while + vectors in one program (partitioned accumulation)
(define (accumulate-split [n : Integer]) : Integer
  (let ([v (vector 0 0)])
    (let ([i 0])
      (let ([flag #t])
        (begin
          (while (< i n)
            (begin
              (if (eq? flag #t)
                  (vector-set! v 0 (+ (vector-ref v 0) i))
                  (vector-set! v 1 (+ (vector-ref v 1) i)))
              (set! flag (not flag))
              (set! i (+ i 1))))
          (+ (vector-ref v 0) (vector-ref v 1)))))))
(accumulate-split 10)
