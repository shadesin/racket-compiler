; Test: functions + while + vectors in one program (builder + consumer)
(define (build-state [n : Integer]) : (Vector Integer Integer)
  (let ([v (vector 1 1)])
    (let ([i 0])
      (begin
        (while (< i n)
          (begin
            (vector-set! v 0 (+ (vector-ref v 0) (vector-ref v 1)))
            (vector-set! v 1 (+ (vector-ref v 1) 1))
            (set! i (+ i 1))))
        v))))

(define (score [v : (Vector Integer Integer)]) : Integer
  (- (vector-ref v 0) (vector-ref v 1)))

(score (build-state 5))
