; Test: Let in effect position (new explicate-effect Let case)
; The inner let binds tmp = (+ x y) for its side-effects,
; but the result is in the begin's effect list and is discarded.
(let ([x 20])
  (let ([y 22])
    (begin
      (let ([tmp (+ x y)])  ;; Let in effect position - result discarded
        (set! x tmp))
      x)))
