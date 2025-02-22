(cl:in-package #:sicl-expression-to-ast)

(defun read-cst (input-stream eof-marker)
  (eclector.concrete-syntax-tree:read input-stream nil eof-marker))

(defun ast-from-stream (client input-stream compilation-environment)
  (let* ((*package* *package*)
         (asts
           (loop with eof-marker = input-stream
                 for cst = (read-cst input-stream eof-marker)
                 until (eq cst eof-marker)
                 collect (expression-to-ast client cst compilation-environment))))
    (make-instance 'ico:progn-ast
      :form-asts asts)))

(defun ast-from-file (client file compilation-environment)
  (sicl-source-tracking:with-source-tracking-stream-from-file
      (input-stream file)
    (ast-from-stream client input-stream compilation-environment)))
