;; cond_test_15: Nested 'and' with comparison operators, and nested if in the then-branch.
;; x=3: (and (> 3 1) (< 3 5)) = (and #t #t) = #t
;; Then branch: (if (eq? 3 3) 42 91) = (if #t 42 91) = 42
;; Expected: 42
(let ([x 3])
  (if (and (> x 1) (< x 5))
    (if (eq? x 3) 42 91)
    59))
