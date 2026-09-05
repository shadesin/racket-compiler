; Test: function that creates and uses a tuple (vector)
(define (make-pair [a : Integer] [b : Integer]) : (Vector Integer Integer)
  (vector a b))
(define (sum-pair [v : (Vector Integer Integer)]) : Integer
  (+ (vector-ref v 0) (vector-ref v 1)))
(sum-pair (make-pair 20 22))
