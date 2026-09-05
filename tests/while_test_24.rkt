;; while_test_24: set! on a variable that was previously bound by let (not set!)
;; Tests that uncover-get! correctly detects x as mutable even though its
;; first mention (in the let binding) is immutable.
;; Also exercises the interaction between set! and let in assign position.
;; Expected: 55 (triangular number: 1+2+...+10)
(let ([x 1])
  (let ([acc 0])
    (begin
      (while (<= x 10)
        (begin
          (set! acc (+ acc x))
          (set! x (+ x 1))))
      acc)))
