;; cond_test_14: Variable shadowing inside the condition of an if.
;; The inner (let ([x 1]) x) creates a new binding x=1 that shadows the outer x=2.
;; So the condition becomes (> 1 2) = #f, which takes the else branch.
;; Expected: 42
(let ([x 2])
  (if (> (let ([x 1]) x) x)
    24
    42))
