;; inner and outer x both used
;; expected result: 42
(let ([x 32])
  (+ (let ([x 10]) x)
     x))