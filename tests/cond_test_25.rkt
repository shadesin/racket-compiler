;; cond_test_25: Let inside predicate position — tests explicate-assign sequencing
;; within explicate-pred for the (Let x rhs body) case.
;;
;; Read a, b. Compute (let ([diff (- a b)]) (> diff 0)) as the condition.
;; This forces explicate-pred to emit an assignment for `diff` then recurse.
;;
;; Input: 10, 3
;;   diff = 10-3 = 7; (> 7 0) = #t => then: (+ a b) = 13
;; Expected: 13
(let ([a (read)])
  (let ([b (read)])
    (if (let ([diff (- a b)])
          (> diff 0))
      (+ a b)
      0)))
