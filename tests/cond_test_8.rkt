;; cond_test_8: Bool constant as if condition
;; Exercises the (Bool b) case in rco-exp and atomic?.
;; A Bool is atomic, so the condition needs no temporary.
;; Expected: 2
(if #f 1 2)
