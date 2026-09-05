;; var_test_32: chained let bindings, last variable only referenced once.
;; Tests that dead variables (never used after binding) still work correctly.
;; The allocator may assign dead variables anywhere without issue.
;; a=10, b=20, c=(+a b)=30, d=50 => (+ c d) = 80
;; Expected: 80
(let ([a 10])
  (let ([b 20])
    (let ([c (+ a b)])
      (let ([d 50])
        (+ c d)))))
