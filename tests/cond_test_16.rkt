;; cond_test_16: TYPE ERROR — non-Boolean condition in 'if'.
;; (+ 1 2) has type Integer, but the condition of 'if' must be Boolean.
;; The type checker should reject this program.
(if (+ 1 2) 3 4)
