;; Exercise 2.5 - Test 2
;; Purpose:
;;   - Tests assignment to variables
;;   - Tests unary minus
;;   - Tests negq instruction
;;
;; Expected lowering shape:
;;   x = 7
;;   x = -x
;;   return x
(let ([x 7])
  (- x))