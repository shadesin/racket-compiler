;; Exercise 2.7 - Test 1 - Memory to memory move
;; x and y will both be assigned stack homes.
;; The assignment y = x will trigger a movq mem, mem.
(let ([x 50])
  (let ([y x])
    (+ y 10)))