;; cond_test_19: TYPE ERROR - 'or' applied to a non-Boolean first argument.
;; (+ 1 2) has type Integer, but 'or' requires both arguments to be Boolean.
;; The type checker should reject this program.
(or (+ 1 2) (read))
