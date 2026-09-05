;; vectors_test_29: vector-length of a 5-element vector
;; Tests that vector-length extracts the length field from the GC tag correctly:
;; andq $126, tag_word; sarq $1, tag_word => length = 5.
;; Expected: 5
(let ([v (vector 10 20 30 40 50)])
  (vector-length v))
