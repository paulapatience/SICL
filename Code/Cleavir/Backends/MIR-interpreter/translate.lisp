(cl:in-package #:cleavir-mir-interpreter)

;;; The first argument to this function is an instruction that has a
;;; single successor.  Whether a GO is required at the end of this
;;; function is determined by the code layout algorithm.  
;;; 
;;; The inputs are forms to be evaluated.  The outputs are symbols
;;; that are names of variables.
(defgeneric translate-simple-instruction (instruction inputs outputs))

(defgeneric translate-branch-instruction (instruction inputs outputs successors))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on TRANSLATE-SIMPLE-INSTRUCTION.

(defmethod translate-simple-instruction
    ((instruction cleavir-mir:assignment-instruction) inputs outputs)
  `(setq ,(first outputs) ,(first inputs)))

(defmethod translate-simple-instruction
    ((instruction cleavir-mir:return-instruction) inputs outputs)
  `(return (values ,@inputs)))

(defmethod translate-simple-instruction
    ((instruction cleavir-mir:funcall-instruction) inputs outputs)
  (let ((temps (loop for output in outputs collect (gensym))))
    `(multiple-value-bind ,temps (funcall ,(first inputs) ,@(rest inputs))
       (setq ,@(mapcar #'list outputs temps)))))

(defmethod translate-simple-instruction
    ((instruction cleavir-mir:tailcall-instruction) inputs outputs)
  `(return (funcall ,(first inputs) ,@(rest inputs))))
