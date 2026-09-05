; Test: higher-order function (map) with tuple
(define (double [x : Integer]) : Integer
  (+ x x))
(define (map-pair [f : (Integer -> Integer)]
                  [v : (Vector Integer Integer)]) : (Vector Integer Integer)
  (vector (f (vector-ref v 0)) (f (vector-ref v 1))))
(vector-ref (map-pair double (vector 10 11)) 1)
