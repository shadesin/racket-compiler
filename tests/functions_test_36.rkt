;; functions_test_36: function stored in a variable then called
;; Tests that function references are properly passed and called through a variable.
;; Expected: 42
(define (add1 [x : Integer]) : Integer
  (+ x 1))
(define (apply-fn [f : (Integer -> Integer)] [x : Integer]) : Integer
  (f x))
(apply-fn add1 41)
