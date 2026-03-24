#lang racket
(require "../compiler.rkt")
(require "../utilities.rkt")
(require racket/set)

;; Test 2: Multiple variables and overwrites
;; Logic:
;; 1. a = 1
;; 2. b = 2
;; 3. b = b + a   (Reads a, b. Writes b.)
;; 4. c = b       (Reads b. Writes c.)
;; 5. c = -c      (Reads c. Writes c.)
;; 6. rax = c     (Reads c. Writes rax.)
(define p
  (X86Program '()
    (list (cons 'start
                (Block '()
                       (list (Instr 'movq (list (Imm 1) (Var 'a)))
                             (Instr 'movq (list (Imm 2) (Var 'b)))
                             (Instr 'addq (list (Var 'a) (Var 'b)))
                             (Instr 'movq (list (Var 'b) (Var 'c)))
                             (Instr 'negq (list (Var 'c)))
                             (Instr 'movq (list (Var 'c) (Reg 'rax)))
                             (Jmp 'conclusion)))))))

(define result (uncover-live p))

(match result
  [(X86Program info blocks)
   (match (car blocks)
     [(cons label (Block b-info instrs))
      (displayln "Live-after sets (Top to Bottom):")
      (for ([s (dict-ref b-info 'live-after)])
        (displayln (sort (set->list s) symbol<?)))])])
