; Regression: >6 arguments plus non-tail swapped call argument order.
(define (snd [x : Integer] [y : Integer]) : Integer y)

(define (call-extra [a : Integer] [b : Integer] [c : Integer]
                    [d : Integer] [e : Integer]
                    [u : Integer] [v : Integer]) : Integer
  (let ([r (snd v u)])
    r))

(call-extra 1 2 3 4 5 40 2)
