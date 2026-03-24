;; Test 2: Simple 'or' expression
;; Expected: (or #f #t) => #t => 1
(if (or #f #t) 1 0)
