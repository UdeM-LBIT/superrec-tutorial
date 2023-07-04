#lang racket
(require
  racket/file
  pollen/core pollen/decode pollen/tag pollen/pagetree
  txexpr)

(current-locale "en")

; URLs

;; Build a site-local path to a page
(provide local-url)
(define (local-url page)
  (string-trim (format "/~a" page) "index.html" #:right? #t))

;; Make an internal link
(provide in-link)
(define (in-link page . contents)
  `(a ((href ,(local-url page)))
      ,@contents))

;; Make an external link
(provide out-link)
(define (out-link url . contents)
  `(a ((href ,url)
       (rel "noopener noreferrer")
       (target "_blank"))
      ,@contents))

;; Make a heading which can be linked to
(provide link-h2)
(define (link-h2 target . contents)
  `(h2 ((id ,target))
     (a ((href ,(string-append "#" target)))
       ,@contents)))

(provide link-h3)
(define (link-h3 target . contents)
  `(h3 ((id ,target))
     (a ((href ,(string-append "#" target)))
       ,@contents)))

; Math

(provide math)
(define (math . xs)
  `(mathjax ,(apply string-append `("\\(" ,@xs "\\)"))))

(provide display-math)
(define (display-math . xs)
  `(mathjax ,(apply string-append `("\\[" ,@xs "\\]"))))

; Code
(require pollen/unstable/pygments)
(provide highlight)

; Decoding

;; Turn double line breaks into new paragraphs but
;; leave single line breaks untouched
(define (decode-paragraphs-only contents)
  (decode-paragraphs contents
    #:linebreak-proc (λ (x) (decode-linebreaks x "\n"))))

(provide root)
(define (root . contents)
   `(@ ,@(decode-elements contents
          #:exclude-tags '(style script)
          #:exclude-attrs '((class "highlight"))
          #:txexpr-elements-proc decode-paragraphs-only)))
