;; Test 25: Deep nesting for register allocation
(let ([v1 1])
  (let ([v2 2])
    (let ([v3 3])
      (let ([v4 (+ v1 v2)])
        (let ([v5 (+ v3 v4)])
          (+ v4 v5))))))
