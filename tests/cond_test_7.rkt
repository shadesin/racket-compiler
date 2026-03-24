;; Test 1: Simple 'and' expression
;; Expected: (and #t #f) => #f => 0
(if (and #t #f) 1 0)
