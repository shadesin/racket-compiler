;; Test 16: GC pressure with nested vectors — keeps a chain of vectors live
;; Allocates many short-lived vectors while keeping a live nested chain.
;; Expected: 11
(let ([live (vector (vector 11))])
  (let ([i 0])
    (begin
      (while (< i 400)
        (begin
          (vector-set! (vector 0 0 0 0) 0 i)
          (set! i (+ i 1))))
      (vector-ref (vector-ref live 0) 0))))
