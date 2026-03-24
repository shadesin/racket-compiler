;; Exercise 2.7 - Test 20 - Large Immediate
;; 100000 is > 65536.
;; Assigning this to 'x' (stack) requires moving to a register first.
(let ([x 100000])
  (+ x 1))