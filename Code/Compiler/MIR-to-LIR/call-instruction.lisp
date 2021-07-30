 (cl:in-package #:sicl-mir-to-lir)

;;; We need to store arguments into the appropriate registers and
;;; stack slots (relative to RSP now), and then adjust RBP.

;;; The code generated is as per the description in section 27.3
;;; "Calling conventions" of the SICL specification.  The callee
;;; function object and arguments have already been computed by
;;; previous instructions, so we are left to generate code for the
;;; rest of the process.

(defmethod finish-lir-for-instruction
    ((instruction cleavir-ir:funcall-instruction))
  (destructuring-bind (function &rest arguments)
      (cleavir-ir:inputs instruction)
    (let* ((argument-count (length arguments))
           (start-of-sequence (make-instance 'cleavir-ir:nop-instruction))
           (predecessor start-of-sequence)
           (function-register x86-64:*r11*))
      (cleavir-ir:insert-instruction-before
       start-of-sequence
       instruction)
      (flet ((emit (instruction)
               (cleavir-ir:insert-instruction-after
                instruction
                predecessor)
               (setf predecessor instruction)))
        ;; 1. Load the function into some register. We need to get at
        ;; the rack.
        #+(or)
        (emit
         (x86-64:load-from-stack-instruction
          (cleavir-ir:offset function) function-register))
        (cond
          ((<= argument-count (length x86-64:*argument-registers*))
           ;; 2. Store the arguments in RDI, RSI, RDX, RCX, and R8.
           (loop for argument in arguments
                 for register in x86-64:*argument-registers*
                 do (x86-64:load-from-location-instruction argument
                                                           register))
           ;; 3. Store the argument count in R9 as a fixnum.
           ;; (Does this really have to be boxed though?)
           (emit
            (make-instance 'cleavir-ir:assignment-instruction
              :inputs (list (make-instance 'cleavir-ir:immediate-input
                              :value argument-count))
              :outputs (list x86-64:*r9*)))
           ;; 4. Load the static environment of the callee from the
           ;; callee function object into R10.  As per
           ;; CLOS/funcallable-standard-object-defclass.lisp the
           ;; environment is in the second slot of a
           ;; funcallable-standard-object.
           ;; 5. Push the value of RBP on the stack.
           
           ;; 6. Copy the value of RSP into RBP.
           (emit
            (make-instance 'cleavir-ir:assignment-instruction
              :inputs (list x86-64:*rsp*)
              :outputs (list x86-64:*rbp*)))
           ;; 7. Load the entry point address of the callee into an
           ;; available scratch register, typically RAX.

           ;; 8. Use the CALL instruction with that register as an argument.
           ;; We will just reuse this CALL instruction.
           (setf (cleavir-ir:inputs instruction)
                 (list x86-64:*rax*)))
          (t
           (error "Can't handle more than 5 arguments so far.")))))))

;;; However, we don't do anything before a named call.

(defmethod finish-lir-for-instruction
    ((instruction cleavir-ir:named-call-instruction))
  nil)
