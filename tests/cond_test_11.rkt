;; cond_test_11: Boolean variable in predicate position
;; Exercises the (Var x) case in explicate-pred.
;; flag is bound to a boolean (result of eq?), then used directly as the
;; condition of an if — hitting the Var case in explicate-pred.
;; Input: 0  Expected: 100
(let ([x (read)])
  (let ([flag (eq? x 0)])
    (if flag 100 200)))
