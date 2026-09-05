; Test: GetBang in effect position (discarded read)
; Tests the new explicate-effect GetBang case - reading a mutable variable
; for its side-effect position (value discarded) should just continue.
(let ([x 0])
  (let ([y 10])
    (begin
      (set! x 42)
      x  ;; GetBang in effect position - value discarded
      (set! y (+ x y))
      x)))
