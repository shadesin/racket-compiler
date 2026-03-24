;; Exercise 2.7 - Test 19 - Memory to Memory Arithmetic
;; sum and n are on the stack.
;; (+ sum n) inside the let will likely generate an instruction 
;; that tries to add one stack slot to another directly.
(let ([sum 100])
  (let ([n 42])
    (+ sum n)))