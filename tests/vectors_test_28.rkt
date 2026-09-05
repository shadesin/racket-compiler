;; vectors_test_28: eq? distinguishes aliased vs. distinct vectors.
;; t1 and t2 are aliases (eq?=#t), t3 is a separate vector (eq? t1 t3 = #f).
;; (from EoC §6.1)
;; Expected: 42
(let ([t1 (vector 3 7)])
  (let ([t2 t1])
    (let ([t3 (vector 3 7)])
      (if (and (eq? t1 t2) (not (eq? t1 t3)))
          42
          0))))
