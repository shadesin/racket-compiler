;; Alternating increment/decrement: two variables chasing each other.
;; a starts at 0, b starts at 20.
;; Each iteration: a += 3, b -= 2.
;; They meet when a >= b. Count iterations until that happens.
;; iter 1: a=3,  b=18
;; iter 2: a=6,  b=16
;; iter 3: a=9,  b=14
;; iter 4: a=12, b=12  -> a >= b, stop (loop condition fails)
;; 4 iterations completed; a=12 at exit.
;; Expected: 12
(let ([a 0])
  (let ([b 20])
    (begin
      (while (< a b)
        (begin
          (set! a (+ a 3))
          (set! b (- b 2))))
      a)))
