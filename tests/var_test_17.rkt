;; Exercise 2.5 - Test 3
;; Purpose:
;;   - Tests function calls (read)
;;   - Tests use of %rax after a call
;;   - Tests mixing I/O with arithmetic
;;
;; Expected lowering shape:
;;   callq read_int
;;   x = %rax
;;   x = x + 1
;;   return x
(let ([x (read)])
  (+ x 1))