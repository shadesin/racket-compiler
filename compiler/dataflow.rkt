#lang racket

(require data/queue
         graph
         "../multigraph.rkt")

(provide analyze-dataflow)

;; Generic work-list fixed-point analysis. The graph's outgoing neighbors feed
;; the transfer input; when a node changes, its incoming neighbors are queued.
;; This orientation directly supports backward liveness on the raw CFG.
(define (analyze-dataflow graph transfer bottom join)
  (define states (make-hash))
  (for ([vertex (in-vertices graph)])
    (hash-set! states vertex bottom))

  (define worklist (make-queue))
  (for ([vertex (in-vertices graph)])
    (enqueue! worklist vertex))

  (define predecessor-graph (transpose graph))
  (let loop ()
    (unless (queue-empty? worklist)
      (define node (dequeue! worklist))
      (define input
        (for/fold ([state bottom])
                  ([successor (in-neighbors graph node)])
          (join state (hash-ref states successor))))
      (define output (transfer node input))
      (unless (equal? output (hash-ref states node))
        (hash-set! states node output)
        (for ([predecessor (in-neighbors predecessor-graph node)])
          (enqueue! worklist predecessor)))
      (loop)))
  states)
