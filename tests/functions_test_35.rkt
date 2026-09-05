;; functions_test_35: tail-recursive accumulator style
;; sum-acc computes the sum 1+2+...+n using an accumulator argument.
;; Tests tail-call optimization (if implemented) and 2-argument functions.
;; sum-acc(10, 0) = 55
;; Expected: 55
(define (sum-acc [n : Integer] [acc : Integer]) : Integer
  (if (eq? n 0)
    acc
    (sum-acc (- n 1) (+ acc n))))
(sum-acc 10 0)
