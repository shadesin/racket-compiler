;; var_test_31: RCO for nested complex operand in subtraction.
;; (- (+ 20 5) (+ 3 4)) - both args of - are complex, must be bound to temps.
;; Expected: 18
(- (+ 20 5) (+ 3 4))
