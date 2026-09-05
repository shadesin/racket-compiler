; Test: non-tail recursive summation
(define (sum-n [n : Integer]) : Integer
  (if (eq? n 0)
      0
      (+ n (sum-n (- n 1)))))
(sum-n 9)