#lang racket

;; System V x86-64 conventions used by instruction selection, liveness, and
;; register allocation. Keeping them together prevents those passes from
;; silently disagreeing about calls or pre-colored registers.

(provide argument-registers
         caller-saved-registers
         callee-saved-registers
         allocatable-registers
         num-allocatable-registers
         reserved-registers
         register-colors
         (rename-out [argument-registers arg-passing-regs]
                     [caller-saved-registers caller-saved-regs]
                     [callee-saved-registers callee-saved-regs]
                     [allocatable-registers allocatable-regs]
                     [num-allocatable-registers num-alloc-regs]
                     [register-colors reg->color]))

(define argument-registers
  '(rdi rsi rdx rcx r8 r9))

(define caller-saved-registers
  (set 'rax 'rcx 'rdx 'rsi 'rdi 'r8 'r9 'r10 'r11))

(define callee-saved-registers
  '(rbx r12 r13 r14))

;; Ordered to prefer caller-saved registers for short-lived values and
;; callee-saved registers for values that survive calls.
(define allocatable-registers
  '(rcx rdx rsi rdi r8 r9 r10 rbx r12 r13 r14))

(define num-allocatable-registers (length allocatable-registers))

;; rsp/rbp implement the frame, r11 is a scratch register, r15 is the GC root
;; stack pointer, and rax carries results and indirect call targets.
(define reserved-registers
  '(rax rsp rbp r11 r15))

(define register-colors
  (make-immutable-hash
   (append
    (for/list ([register allocatable-registers]
               [color (in-naturals)])
      (cons register color))
    '((rax . -1) (rsp . -2) (rbp . -3) (r11 . -4) (r15 . -5)))))
