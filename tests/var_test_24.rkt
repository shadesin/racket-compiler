;; Test 24: Interference pattern
(let ([a 10])
  (let ([b 20])
    (let ([c (+ a b)])
      (let ([d (+ a c)])
        (+ c d)))))
