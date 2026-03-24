;; cond_test_18: TYPE ERROR — 'and' applied to a non-Boolean second argument.
;; 5 has type Integer, but 'and' requires both arguments to be Boolean.
;; The type checker should reject this program.
(and #t 5)
