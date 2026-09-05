;; Allocate more than the 64 KiB initial heap while retaining a live root.
(let ([root (vector 42)])
  (let ([i 0])
    (begin
      (while (< i 2000)
        (begin
          (vector-set! (vector 0 0 0 0) 0 i)
          (set! i (+ i 1))))
      (vector-ref root 0))))
