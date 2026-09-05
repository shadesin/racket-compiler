;; cond_test_27: shrink: (and e1 e2) => (if e1 e2 #f)
;; Short-circuits: if e1=#f, e2 is NOT evaluated.
;; (and #f (read)) should short-circuit and return 0 (false) without calling read.
;; Expected: 0  (the 'false' branch, since #f short-circuits)
(if (and #f #t) 1 0)
