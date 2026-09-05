; Test: (void) appears as the result of a set! in tail position
; The program computes 42 and returns it. Tests Void in tail position.
(let ([x 0])
  (begin
    (set! x 42)
    x))
