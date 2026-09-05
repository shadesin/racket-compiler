;; cond_test_22: Boolean short-circuit: or/and with side-effectful reads.
;; Tests that shrink correctly turns (or e1 e2) into (if e1 #t e2) so e2
;; is NOT evaluated when e1 is true.
;;
;; x=5: (or (> x 3) (< x 0))
;;   (> 5 3) = #t => short-circuit, result is #t => outer if takes then: 99
;; Second read is never triggered.
;; Expected: 99
(let ([x 5])
  (if (or (> x 3) (< x 0))
    99
    0))
