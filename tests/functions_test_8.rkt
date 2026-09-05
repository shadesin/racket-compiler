; Test: tail-recursive sum (exercises tail-call optimization)
(define (sum-tail [n : Integer] [acc : Integer]) : Integer
  (if (eq? n 0)
      acc
      (sum-tail (- n 1) (+ acc n))))
(sum-tail 20 0)
