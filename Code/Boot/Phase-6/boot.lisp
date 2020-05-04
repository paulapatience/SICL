(cl:in-package #:sicl-boot-phase-6)

(defun boot (boot)
  (format *trace-output* "Start of phase 6~%")
  (with-accessors ((e4 sicl-boot:e4)
                   (e5 sicl-boot:e5)
                   (e6 sicl-boot:e6)
                   (e7 sicl-boot:e7))
      boot
    (change-class e6 'environment)
    (import-from-host boot)
    (sicl-boot:enable-class-finalization #'load-fasl e4 e5)
    (finalize-all-classes boot)
    (sicl-boot:enable-defmethod #'load-fasl e5 e6)
    (enable-allocate-instance e5)
    (define-class-of e6)
    (sicl-boot:enable-object-initialization #'load-fasl e5 e6)
    (load-fasl "Conditionals/macros.fasl" e5)
    (sicl-boot:enable-method-combinations #'load-fasl e5 e6)
    (define-stamp e6)
    (define-compile e5 e6)
    (sicl-boot:enable-generic-function-invocation #'load-fasl e5 e6)
    (sicl-boot:define-accessor-generic-functions #'load-fasl e5 e6 e7)
    (enable-class-initialization e5 e6 e7)
    (sicl-boot:create-mop-classes #'load-fasl e6)
    (load-fasl "CLOS/satiation.fasl" e6)))
