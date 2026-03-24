;; Exercise 2.5 - Test 1
;; Purpose:
;;   - Tests immediate values
;;   - Tests binary addition
;;   - Tests returning a computed value
;;
;; Instruction selection should generate:
;;   movq $10, %rax
;;   addq $32, %rax
;;   retq
(+ 10 32)