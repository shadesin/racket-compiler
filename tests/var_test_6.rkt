;; shadowing inside initializer
;; expected result: 7
(let ([x (let ([x 4])
           (+ x 1))])
  (+ x 2))