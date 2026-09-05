;; functions_test_33: mutual recursion (even? and odd? defined as separate functions)
;; Tests that the function pipeline correctly handles cross-function calls.
;; even(10) = true => 1, result: 1
;; Expected: 1
(define (even? [n : Integer]) : Integer
  (if (eq? n 0)
    1
    (odd? (- n 1))))
(define (odd? [n : Integer]) : Integer
  (if (eq? n 0)
    0
    (even? (- n 1))))
(even? 10)
