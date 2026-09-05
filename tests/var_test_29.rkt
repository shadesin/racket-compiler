;; var_test_29: variable aliasing (x and y same value, y = x case)
;; Tests that (+ y x) where y == x correctly resolves to a single register.
;; Also tests patch-instructions: y=x assignment may be a movq var, var
;; that becomes movq mem, mem -- must be patched through rax.
;; Expected: 84
(let ([x 42])
  (let ([y x])
    (+ y x)))
