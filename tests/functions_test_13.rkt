; Test: tail-recursive triangular sum
(define (tri-tail [n : Integer] [acc : Integer]) : Integer
  (if (eq? n 0)
      acc
  (tri-tail (- n 1) (+ n acc))))
(tri-tail 15 0)