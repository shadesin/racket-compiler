;; Test 9: eq? on same vector is #t, eq? on equal-content vectors is #f
;; (tests identity vs structural equality from §6.1)
;; Expected: 42
(let ([t1 (vector 3 7)])
  (let ([t2 t1])
    (let ([t3 (vector 3 7)])
      (if (and (eq? t1 t2) (not (eq? t1 t3)))
          42
          0))))
