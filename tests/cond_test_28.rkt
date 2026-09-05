;; cond_test_28: shrink: (or e1 e2) => (if e1 #t e2)
;; (or #t (read)) short-circuits and returns 1 (true) without calling read.
;; Expected: 1
(if (or #t #f) 1 0)
