;;;;;;;;;;;;;;;;;;;
;;; Dll Modules ;;;
;;;;;;;;;;;;;;;;;;;

(define *libc* (dlopen "libc.so.6"))
(if (zero? *libc*) (error "Cannot open libc"))

;;;;;;;;;;;;;;;;;
;;; Constants ;;;
;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;
;;; Functions ;;;
;;;;;;;;;;;;;;;;;

(define malloc
  (let ((f (dlsym *libc* "malloc")))
    (lambda (bytes)
      (dlcall f bytes))))

(define free
  (let ((f (dlsym *libc* "free")))
    (lambda (lpmem)
      (dlcall f lpmem))))

(define realloc
  (let ((f (dlsym *libc* "realloc")))
    (lambda (lpmem bytes)
      (dlcall f bytes lpmem))))

(define printf
  (let ((f (dlsym *libc* "printf")))
    (lambda x
      (apply dlcall f (reverse x)))))

(define fprintf
  (let ((f (dlsym *libc* "fprintf")))
    (lambda x
      (apply dlcall f (reverse x)))))

;;;;;;;;;;;;;;;
;;; Helpers ;;;
;;;;;;;;;;;;;;;
(define (alloc b)
  (make-immutable-string
    (malloc b) b))
