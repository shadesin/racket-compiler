;; cond_test_13: Nested if in predicate position
;; Exercises the (If cnd^ thn^ els^) case in explicate-pred —
;; the key case from the book (figure 4.12).
;; The outer if's condition is itself an if, so both inner branches
;; are compiled in predicate context; thn/els are wrapped in blocks
;; to avoid code duplication.
;; Input: 0, then 5
;;   x=0, y=5
;;   (< 0 1) = #t  => inner then: (eq? 0 0) = #t  => outer then: (+ 5 2) = 7
;; Expected: 7
(let ([x (read)])
  (let ([y (read)])
    (if (if (< x 1) (eq? x 0) (eq? x 2))
      (+ y 2)
      (+ y 10))))
