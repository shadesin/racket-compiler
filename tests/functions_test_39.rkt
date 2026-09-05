;; These names collided under the old punctuation-to-underscore mangling.
(define (foo-bar) : Integer 20)
(define (foo_bar) : Integer 22)
(+ (foo-bar) (foo_bar))
