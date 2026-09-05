;; cond_test_21: Triple-nested if in predicate position.
;; Tests the (If cnd^ thn^ els^) predicate case recursively — three levels deep.
;; All three ifs are in predicate context; inner results feed the outer condition.
;;
;; x=3:
;;   outer cond: (if (> x 2) (if (< x 10) (eq? x 3) #f) #f)
;;     (> 3 2) = #t  => inner1: (< 3 10) = #t => inner2: (eq? 3 3) = #t
;;   then: (+ x x) = 6
;; Expected: 6
(let ([x 3])
  (if (if (> x 2)
        (if (< x 10) (eq? x 3) #f)
        #f)
    (+ x x)
    0))
