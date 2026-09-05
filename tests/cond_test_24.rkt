;; cond_test_24: not with a complex boolean predicate (double negation + and).
;; Tests (not (not e)) = e and (not (and ...)) interaction.
;;
;; x=4, y=8:
;;   (not (not (and (> x 0) (< y 10))))
;;   = (not (not (and #t #t)))
;;   = (not (not #t))
;;   = (not #f) = #t
;;   => then: (- y x) = 4
;; Expected: 4
(let ([x 4])
  (let ([y 8])
    (if (not (not (and (> x 0) (< y 10))))
      (- y x)
      0)))
