; Test: deeply nested vectors (3 levels) to verify pointer mask for multi-level nesting
(let ([v (vector (vector (vector 42)))])
  (vector-ref (vector-ref (vector-ref v 0) 0) 0))
