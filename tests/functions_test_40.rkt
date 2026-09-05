;; Mutable reads must remain correctly ordered around calls inside a loop.
(define (increment [x : Integer]) : Integer (+ x 1))

(let ([value 0])
  (let ([i 0])
    (begin
      (while (< i 10)
        (begin
          (set! value (increment value))
          (set! i (+ i 1))))
      (+ value 32))))
