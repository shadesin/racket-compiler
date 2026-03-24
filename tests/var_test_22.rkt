;; Test 22: More variables to test register pressure
(let ([a 1])
  (let ([b 2])
    (let ([c 3])
      (let ([d 4])
        (let ([e 5])
          (+ a (+ b (+ c (+ d e)))))))))
