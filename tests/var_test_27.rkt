;; var_test_27: RCO must NOT introduce a temp for an atomic RHS.
;; (let ([b a]) ...) should stay as-is per EoC §2.4 "Take special care".
;; Checks that we don't generate unnecessary movq temp, temp -> temp2 chains.
;; Expected: 42
(let ([a 42])
  (let ([b a])
    b))
