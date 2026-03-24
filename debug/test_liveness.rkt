#lang racket
(require "../compiler.rkt")
(require "../utilities.rkt")
(require racket/set)

;; Create a small manual x86 program
(define p
  (X86Program '()
    (list (cons 'start
                (Block '()
                       (list (Instr 'movq (list (Imm 10) (Var 'x)))   ; Write x
                             (Instr 'addq (list (Imm 5) (Var 'x)))    ; Read/Write x
                             (Instr 'movq (list (Var 'x) (Reg 'rax))) ; Read x, Write rax
                             (Jmp 'conclusion)))))))

;; Run the pass
(define result (uncover-live p))

;; Extract and print the live-after sets
(match result
  [(X86Program info blocks)
   (match (car blocks)
     [(cons label (Block b-info instrs))
      (displayln "Live-after sets:")
      (for ([s (dict-ref b-info 'live-after)])
        (displayln (set->list s)))])])