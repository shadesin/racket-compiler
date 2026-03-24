;; cond_test_17: TYPE ERROR — '+' applied to a Boolean argument.
;; #t has type Boolean, but '+' requires both arguments to be Integer.
;; The type checker should reject this program.
(+ 5 #t)
