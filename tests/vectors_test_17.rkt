;; Test 15: GC pressure — allocate many vectors in a loop
;; The heap is 65536 bytes; each vector(1 int) = 16 bytes.
;; We allocate 500 small vectors; only the last one is kept live.
;; This guarantees at least one GC cycle runs.
;; Expected: 499
(let ([result (vector 0)])
  (let ([i 0])
    (begin
      (while (< i 500)
        (begin
          (vector-set! result 0 i)
          (set! i (+ i 1))))
      (vector-ref result 0))))
