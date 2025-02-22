(cl:in-package #:sicl-expression-to-ast)

(defmethod convert-variable (client cooked-symbol environment)
  #+sbcl(declare (sb-ext:muffle-conditions sb-ext:compiler-note))
  (let* ((symbol (c:raw cooked-symbol))
         (info (trucler:describe-variable client environment symbol)))
    (loop while (null info)
          do (restart-case (error "No variable-description for ~s" symbol)
               (continue ()
                 :report (lambda (stream)
                           (format stream "Consider the variable as special."))
                 (setf info
                       (make-instance 'trucler:special-variable-description
                                      :name symbol)))
               ;; This is identical to CONTINUE, but more specifically named.
               (consider-special ()
                 :report (lambda (stream)
                           (format stream "Consider the variable as special."))
                 (setf info
                       (make-instance 'trucler:special-variable-description
                         :name symbol)))
               (substitute (new-symbol)
                 :report (lambda (stream)
                           (format stream "Substitute a different name."))
                 :interactive (lambda ()
                                (format *query-io* "Enter new name: ")
                                (list (read *query-io*)))
                 (setq info (trucler:describe-variable client environment new-symbol)))))
    (convert-with-description client cooked-symbol info environment)))
