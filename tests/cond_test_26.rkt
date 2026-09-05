;; cond_test_26: Diamond CFG — two separate ifs sharing the same final let.
;; Tests that both branches of two independent ifs correctly chain into
;; a common tail expression. Exercises deep block structure in explicate-control.
;;
;; Read x, y.
;; a = if (> x 0) then 1 else -1
;; b = if (< y 0) then 10 else 20
;; result = a + b
;;
;; Input: 3, -5
;;   a=1, b=10, result=11
;; Expected: 11
(let ([x (read)])
  (let ([y (read)])
    (let ([a (if (> x 0) 1 -1)])
      (let ([b (if (< y 0) 10 20)])
        (+ a b)))))
