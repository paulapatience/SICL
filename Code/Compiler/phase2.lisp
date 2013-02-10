(in-package #:sicl-compiler-phase-2)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Instruction graph.

(defclass instruction ()
  ((%successors :initform '() :initarg :successors :accessor successors)
   (%inputs :initform '() :initarg :inputs :reader inputs)
   (%outputs :initform '() :initarg :outputs :reader outputs)))

(defmethod initialize-instance :after ((obj instruction) &key &allow-other-keys)
  (unless (and (listp (successors obj))
	       (every (lambda (successor)
			(typep successor 'instruction))
		      (successors obj)))
    (error "successors must be a list of instructions")))

(defclass end-instruction (instruction)
  ())

(defclass nop-instruction (instruction)
  ())

(defclass constant-assignment-instruction (instruction)
  ((%constant :initarg :constant :accessor constant)))

(defclass variable-assignment-instruction (instruction)
  ())

(defclass test-instruction (instruction)
  ())

(defclass funcall-instruction (instruction)
  ((%fun :initarg :fun :accessor fun)))

(defclass get-arguments-instruction (instruction)
  ((%lambda-list :initarg :lambda-list :accessor lambda-list)))

(defclass get-values-instruction (instruction)
  ())

(defclass put-arguments-instruction (instruction)
  ())

(defclass put-values-instruction (instruction)
  ())

(defmethod outputs ((instruction get-arguments-instruction))
  (p1:required (lambda-list instruction)))

(defclass enter-instruction (instruction)
  ())

(defclass leave-instruction (instruction)
  ())

(defclass return-instruction (instruction)
  ())

(defclass enclose-instruction (instruction)
  ((%code :initarg :code :accessor code)))  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compilation context.
;;;
;;; Each AST is compiled in a particular COMPILATION CONTEXT or
;;; CONTEXT for short.  A context object has three components: 
;;;
;;; 1. RESULTS which indicates how many values are required from the
;;; compilation of this AST.  The results can be either a proper list
;;; or T.  If it is a proper list, then it contains a list of lexical
;;; locations into which the generated code must put the values of
;;; this AST.  If the list is empty, it means that no values are
;;; required.  If the list contains more elements than the number of
;;; values generated by this AST, then the remaining lexical locations
;;; in the list must be filled with NIL by the code generated from
;;; this AST.  If the RESULTS component is T, this means that all the
;;; values that this AST generates are required.
;;;
;;; 2. SUCCESSORS which is a proper list containing one or two
;;; elements.  These elements are instructions resulting from the
;;; generation of the code that should be executed AFTER the code
;;; generated from this AST.  If the list contains two elements, then
;;; this AST is compiled in a context where a Boolean result is
;;; required.  In this case, the first element of the list is the
;;; successor to use when the value generated by the AST is NIL, and
;;; the second element is the successor to use when the value
;;; generated by the AST is something other than NIL.
;;;
;;; 3. FALSE-REQUIRED-P, which is a Boolean value indicating whether a
;;; NIL Boolean value is required as explained below.
;;;
;;; The following combinations can occur:
;;;
;;;  * There is a single successor.  Then any RESULTS are possible.
;;;    FALSE-REQUIRED-P is ignored.
;;;
;;;  * There are two successors and the RESULTS is the empty list.
;;;    Then the generated code should determine whether the AST
;;;    generates a false or a true value and select the appropriate
;;;    successor.  FALSE-REQUIRED-P is ignored.  Such a context is
;;;    used to compile the test of an IF form.  The two successors
;;;    then correspond to the code for the ELSE branch and the code
;;;    for the THEN branch respectively. 
;;;
;;;  * There are two successors and the RESULTS is a list with more
;;;    than one element.  FALSE-REQUIRED-P is ignored.  The code
;;;    generated from the AST should do two things.  Code should be
;;;    generated to assign values to the results, and according to
;;;    whether the FIRST value is false or true, the appropriate
;;;    successor should be selected.  This kind of context could be
;;;    used to compile the FORM in (if (setf (values x y) FORM) ...).
;;;
;;;  * There are two successors and the RESULTS is a list with exactly
;;;    one element.  FALSE-REQUIRED-P is true.  The code generated
;;;    from the AST should do two things.  First, it should generate
;;;    code to compute the value from the AST and store it in the
;;;    result.  Next, it should determine whether that value is false
;;;    or true, and select the appropriate successor.  This kind of
;;;    context could be used to compile the FORM in code such as 
;;;    (if (setq x FORM) ...)
;;;
;;;  * There are two successors and the RESULTS is a list with exactly
;;;    one element.  FALSE-REQUIRED-P is false.  The code generated
;;;    should determine whether the result is false or true.  If it is
;;;    false, the first successor should be selected.  If it is true,
;;;    then that true value should be assigned to the lexical location
;;;    in RESULTS and the second successor should be selected.  This
;;;    kind of context could be used to compile FORM in code such as
;;;    (setq x (or FORM ...)). 

(defclass context ()
  ((%results :initarg :results :reader results)
   (%successors :initarg :successors :reader successors)
   (%false-required-p :initarg :false-required-p :reader false-required-p)))

(defun context (results successors &optional (false-required-p t))
  (unless (or (eq results t)
	      (and (listp results)
		   (every (lambda (result)
			    (typep result 'sicl-env:lexical-location-info))
			  results)))
    (error "illegal results: ~s" results))
  (unless (and (listp successors)
	       (every (lambda (successor)
			(typep successor 'instruction))
		      successors))
    (error "illegal successors: ~s" results))
  (if (and (= (length successors) 2)
	   (eq results t))
      (error "Illegal combination of results and successors")
      (make-instance 'context
		     :results results
		     :successors successors
		     :false-required-p false-required-p)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile an abstract syntax tree in a compilation context.
;;;
;;; The result of the compilation is a single value, namely the first
;;; instruction of the instruction graph resulting from the
;;; compilation of the entire AST.

(defun new-temporary ()
  (make-instance 'sicl-env:lexical-location-info
		 :name (gensym)
		 :location (make-instance 'sicl-env:lexical-location)
		 :type t
		 :inline-info nil
		 :ignore-info nil
		 :dynamic-extent-p nil))

;;; Given a list of results and a successor, generate a sequence of
;;; instructions preceding that successor, and that assign NIL to each
;;; result in the list.
(defun nil-fill (results successor)
  (let ((next successor))
    (loop for value in results
	  do (setf next
		   (make-instance 'constant-assignment-instruction
				  :outputs (list value)
				  :constant nil
				  :successors (list next)))
	  finally (return next))))

(defgeneric compile-ast (ast context))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a CONSTANT-AST.  

(defmethod compile-ast ((ast p1:constant-ast) context)
  (with-accessors ((results results)
		   (successors successors))
      context
    (ecase (length successors)
      (1 (cond ((null results)
		;; If there is a single successor and no value required,
		;; then this constant is compiled in a context where its
		;; value makes no difference.  
		(error "Constant found in a context where no value required."))
	       ((eq results t)
		(let ((temp (new-temporary)))
		  (make-instance 'constant-assignment-instruction
		    :outputs (list temp)
		    :constant (p1:value ast)
		    :successors (list (make-instance 'put-values-instruction
				        :inputs (list temp)
					:successors successors)))))
	       (t
		(make-instance 'constant-assignment-instruction
	          :outputs (list (car results))
		  :constant (p1:value ast)
		  :successors (list (nil-fill (cdr results)
					      (car successors)))))))
      (2 (cond ((null (p1:value ast))
		(car successors))
	       ((null results)
		(cadr successors))
	       (t
		(make-instance 'constant-assignment-instruction
	          :outputs (list (car results))
		  :constant (p1:value ast)
		  :successors (cadr successors))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile an IF-AST.  
;;;
;;; We compile the test of the IF-AST in a context where no value is
;;; required and with two successors, the else branch and the then
;;; branch.  The two branches are compiled in the same context as the
;;; IF-AST itself.

(defmethod compile-ast ((ast p1:if-ast) context)
  (let ((then-branch (compile-ast (p1:then ast) context))
	(else-branch (compile-ast (p1:else ast) context)))
    (compile-ast (p1:test ast)
		 (context '() (list else-branch then-branch)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a PROGN-AST.
;;;
;;; The last sub-ast is compiled in the same context as the progn-ast
;;; itself.  All the others are copiled in a context where no value is
;;; required, and with the code for the following form as a single
;;; successor.

(defmethod compile-ast ((ast p1:progn-ast) context)
  (let ((next (compile-ast (car (last (p1:form-asts ast))) context)))
    (loop for sub-ast in (cdr (reverse (p1:form-asts ast)))
	  do (setf next (compile-ast sub-ast (context '() (list next)))))
    next))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a BLOCK-AST.
;;;
;;; A BLOCK-AST is compiled by compiling its body in the same context
;;; as the block-ast itself.  However, we store that context in the
;;; *BLOCK-INFO* hash table using the block-ast as a key, so that a
;;; RETURN-FROM-AST that refers to this block can be compiled in the
;;; same context.

(defparameter *block-info* nil)

(defmethod compile-ast ((ast p1:block-ast) context)
  (setf (gethash ast *block-info*) context)
  (compile-ast (p1:body ast) context))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a RETURN-FROM-AST.
;;;
;;; A RETURN-FROM-AST is compiled as follows: The context is ignored,
;;; because the RETURN-FROM does not return a value in its own
;;; context.  Instead, the FORM-AST of the RETURN-FROM-AST is compiled
;;; in the same context as the corresponding BLOCK-AST was compiled
;;; in.

(defmethod compile-ast ((ast p1:return-from-ast) context)
  (declare (ignore context))
  (let ((block-context (gethash (p1:block-ast ast) *block-info*)))
    (compile-ast (p1:form-ast ast) block-context)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a TAGBODY-AST.
;;;
;;; A TAGBODY-AST is compiled as follows: A single successor is
;;; detemined.  If the RESULTS in the context is the empty list, i.e.,
;;; the value of this AST is not required at all, then the successor
;;; is the first of the list of successors received as an argument.
;;; It can never be the second one, because that one is taken only if
;;; the value of the AST is true, and the value of a TABODY-AST is
;;; always NIL.
;;;
;;; For each TAG-AST in the tagbody, a NOP instruction is created and
;;; that instruction is entered into the hash table *GO-INFO* using
;;; the TAG-AST as a key.  Then the items are compiled in the reverse
;;; order, stacking new instructions before the successor computed
;;; previously.  Compiling a TAG-AST results in the successor of the
;;; corresponding NOP instruction being modified to point to the
;;; remining instructions already computed.  Compiling something else
;;; is done in a context with an empty list of results, using the
;;; remaining instructions already computed as a single successor.

(defparameter *go-info* nil)

(defmethod compile-ast ((ast p1:tagbody-ast) context)
  (loop for item in (p1:items ast)
	do (when (typep item 'p1:tag-ast)
	     (setf (gethash item *go-info*)
		   (make-instance 'nop-instruction))))
  (let ((next (if (null (results context))
		  (car (successors context))
		  (compile-ast (make-instance 'p1:constant-ast :value nil)
			       context))))
    (loop for item in (reverse (p1:items ast))
	  do (setf next
		   (if (typep item 'p1:tag-ast)
		       (let ((instruction (gethash item *go-info*)))
			 (setf (successors instruction) (list next))
			 instruction)
		       (compile-ast item (context '() (list next))))))
    next))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a GO-AST.
;;;
;;; The CONTEXT is ignored.  Instead, the successor becomes the NOP
;;; instruction that was entered into the hash table *GO-INFO* when
;;; the TAGBODY-AST was compiled.

(defmethod compile-ast ((ast p1:go-ast) context)
  (declare (ignore context))
  (gethash (p1:tag-ast ast) *go-info*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a FUNCTION-CALL-AST.
;;;
;;; The first instruction generated is a PUT-ARGUMENTS-INSTRUCTION.
;;; This instruction supplies the arguments to the call.  Then the
;;; FUNCALL-INSTRUCTION is emitted.  Finally, if the FUNCTION-CALL-AST
;;; is compiled in a context where all the values are needed, i.e,
;;; with a RESULTS of T, then there is nothing more to do.
;;; Furthermore, in that case, there can only be a single successor.
;;;
;;; If the RESULTS is not T, then we must put the values generated by
;;; the call into the syntactic location indicated by the RESULTS.
;;; This is done by the GET-VALUES-INSTRUCTION.  That instruction may
;;; use one or two successors, in which case it tests the first value
;;; received and selects a successor based on whether that value is
;;; NIL or something else.

(defmethod compile-ast ((ast p1:function-call-ast) context)
  (with-accessors ((results results)
		   (successors successors))
      context
    (let ((next (if (eq results t)
		    (car successors)
		    (make-instance 'get-values-instruction
				   :outputs results
				   :successors successors))))
      (let ((temps (loop for arg in (p1:arguments ast)
			 collect (new-temporary))))
	(setf next
	      (make-instance 'funcall-instruction
			     :fun (p1:function-location ast)
			     :successors (list next)))
	(setf next
	      (make-instance 'put-arguments-instruction
			     :inputs temps
			     :successors (list next)))
	(loop for temp in (reverse temps)
	      for arg in (reverse (p1:arguments ast))
	      do (setf next
		       (compile-ast arg (context (list temp) (list next))))))
      next)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a function consisting of an ordinary LAMBDA-LIST and a
;;; BODY-AST.  
;;;
;;; The result is a graph of instructions starting with a
;;; GET-ARGUMENTS-INSTRUCTION that uses the LAMBDA-LIST to supply
;;; values to the lexical locations that the body needs, and ending
;;; with a RETURN-INSTRUCTION which has no successors. 

(defun compile-function (lambda-list body-ast)
  (let ((next (make-instance 'return-instruction)))
    (setf next (compile-ast body-ast (p2:context t (list next))))
    (make-instance 'get-arguments-instruction
		   :lambda-list lambda-list
		   :successors (list next))))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a FUNCTION-AST.
;;;
;;; The FUNCTION-AST represents a closure, so we compile it by
;;; compiling its LAMBDA-LIST and BODY-AST into some code, represented
;;; by the first instruction in the body.  We then generate an
;;; ENCLOSE-INSTRUCTION that takes this code as input.
;;;
;;; The value computed by the FUNCTION-AST is always a function, so it
;;; is always a single non-NIL value.  If the value context is T,
;;; i.e., all the values are needed, we also generate a
;;; PUT-VALUES-INSTRUCTION with the single value as input.  If there
;;; is more than one successor, chose the second one for the true
;;; value. 

(defmethod compile-ast ((ast p1:function-ast) context)
  (with-accessors ((results results)
		   (successors successors))
      context
    (let ((code (compile-function (p1:lambda-list ast) (p1:body-ast ast)))
	  (next (if (= (length successors) 2)
		    (cadr successors)
		    (car successors))))
      (cond ((eq results t)
	     (let ((temp (new-temporary)))
	       (make-instance 'enclose-instruction
		 :outputs (list temp)
		 :code code
		 :successors (list (make-instance 'put-values-instruction
				     :inputs (list temp)
				     :successors (list next))))))
	    ((null results)
	     (warn "closure compiled in a context with no values"))
	    (t
	     (make-instance 'enclose-instruction
	       :outputs (list (car results))
	       :code code
	       :successors (list (nil-fill (cdr results) next))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a LEXICAL-LOCATION-INFO object. 
;;;
;;; If the RESULTS is T, then we generate a PUT-VALUES-INSTRUCTION.
;;; In that case, we know that there is only one successor.  If there
;;; is a single successor and the RESULTS is the empty list, then a
;;; lexical variable occurs in a context where its value is not
;;; required, so we warn, and generate no additional code.  If there
;;; is a single successor and the RESULTS contains a single element,
;;; we generate a VARIABLE-ASSIGNMENT-INSTRUCTION.
;;;
;;; If there are two successors, we must generate a TEST-INSTRUCTION
;;; with those two successor.  If in addition the RESULTS is not
;;; the empty list, we must also generate a
;;; VARIABLE-ASSIGNMENT-INSTRUCTION.

(defmethod compile-ast ((ast sicl-env:lexical-location-info) context)
  (with-accessors ((results results)
		   (successors successors))
      context
    (ecase (length successors)
      (1 (cond ((eq results t)
		(make-instance 'put-values-instruction
		  :inputs (list ast)
		  :successors successors))
	       ((null results)
		(warn "variable compiled in a context with no values")
		(car successors))
	       (t
		(make-instance 'variable-assignment-instruction
		  :inputs (list ast)
		  :outputs (list (car results))
		  :successors (list (nil-fill (cdr results)
					      (car successors)))))))
      (2 (if (null results)
	     (make-instance 'test-instruction
	       :inputs (list ast)
	       :outputs '()
	       :successors successors)
	     (make-instance 'variable-assignment-instruction
	       :inputs (list ast)
	       :outputs (list (car results))
	       :successors (list (make-instance 'test-instruction
				   :inputs (list ast)
				   :outputs '()
				   :successors successors))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Compile a GLOBAL-LOCATION-INFO object.
;;;
;;; We compile in the exact same way as the LEXICAL-LOCATION-INFO
;;; object.  

(defmethod compile-ast ((ast sicl-env:global-location-info) context)
  (with-accessors ((results results)
		   (successors successors))
      context
    (ecase (length successors)
      (1 (cond ((eq results t)
		(make-instance 'put-values-instruction
		  :inputs (list ast)
		  :successors successors))
	       ((null results)
		(warn "variable compiled in a context with no values")
		(car successors))
	       (t
		(make-instance 'variable-assignment-instruction
		  :inputs (list ast)
		  :outputs (list (car results))
		  :successors (list (nil-fill (cdr results)
					      (car successors)))))))
      (2 (if (null results)
	     (make-instance 'test-instruction
	       :inputs (list ast)
	       :outputs '()
	       :successors successors)
	     (make-instance 'variable-assignment-instruction
	       :inputs (list ast)
	       :outputs (list (car results))
	       :successors (list (make-instance 'test-instruction
				   :inputs (list ast)
				   :outputs '()
				   :successors successors))))))))

(defun compile-toplevel (ast)
  (let ((*block-info* (make-hash-table :test #'eq))
	(*go-info* (make-hash-table :test #'eq))
	(end (make-instance 'end-instruction)))
    (compile-ast ast (context t (list end)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Drawing instructions.

(defparameter *instruction-table* nil)

(defgeneric draw-instruction (instruction stream))
  
(defmethod draw-instruction :around (instruction stream)
  (when (null (gethash instruction *instruction-table*))
    (setf (gethash instruction *instruction-table*) (gensym))
    (format stream "  ~a [shape = box];~%"
	    (gethash instruction *instruction-table*))
    (call-next-method)))

(defmethod draw-instruction :before ((instruction instruction) stream)
  (loop for next in (successors instruction)
	do (draw-instruction next stream))
  (loop for next in (successors instruction)
	do (format stream
		   "  ~a -> ~a [style = bold];~%"
		   (gethash instruction *instruction-table*)
		   (gethash next *instruction-table*))))
  
(defmethod draw-instruction (instruction stream)
  (format stream "   ~a [label = \"~a\"];~%"
	  (gethash instruction *instruction-table*)
	  (class-name (class-of instruction))))

(defgeneric draw-location (location stream &optional name))

(defmethod draw-location :around (location stream &optional name)
  (declare (ignore name))
  (when (null (gethash location *instruction-table*))
    (setf (gethash location *instruction-table*) (gensym))
    (format stream "  ~a [shape = ellipse];~%"
	    (gethash location *instruction-table*))
    (call-next-method)))

(defmethod draw-location (location stream &optional (name "?"))
  (format stream
	  "   ~a [label = \"~a\"];~%"
	  (gethash location *instruction-table*)
	  name))

(defmethod draw-location
    ((location sicl-env:global-location) stream &optional (name "?"))
  (format stream "   ~a [label = \"~a\", style = filled, fillcolor = green];~%"
	  (gethash location *instruction-table*)
	  name))

(defmethod draw-location
    ((location sicl-env:lexical-location) stream &optional (name "?"))
  (format stream "   ~a [label = \"~a\", style = filled, fillcolor = yellow];~%"
	  (gethash location *instruction-table*)
	  name))

(defun draw-location-info (info stream)
  (when (null (gethash info *instruction-table*))
    (setf (gethash info *instruction-table*) (gensym))
    (draw-location (sicl-env:location info) stream (sicl-env:name info))
    (format stream "  ~a [shape = box, label = \"~a\"]~%" 
	    (gethash info *instruction-table*)
	    (sicl-env:name info))
    (format stream "  ~a -> ~a [color = green]~%"
	    (gethash info *instruction-table*)
	    (gethash (sicl-env:location info) *instruction-table*))))

(defmethod draw-instruction :after (instruction stream)
  (loop for location in (inputs instruction)
	do (draw-location-info location stream)
	   (format stream "  ~a -> ~a [color = red, style = dashed];~%"
		   (gethash location *instruction-table*)
		   (gethash instruction *instruction-table*)))
  (loop for location in (outputs instruction)
	do (draw-location-info location stream)
	   (format stream "  ~a -> ~a [color = blue, style = dashed];~%"
		   (gethash instruction *instruction-table*)
		   (gethash location *instruction-table*))))

(defmethod draw-instruction ((instruction enclose-instruction) stream)
  (format stream "   ~a [label = \"close\"];~%"
	  (gethash instruction *instruction-table*))
  (draw-instruction (code instruction) stream)
  (format stream "  ~a -> ~a [color = pink, style = dashed];~%"
	  (gethash (code instruction) *instruction-table*)
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction get-arguments-instruction) stream)
  (format stream "   ~a [label = \"get-arguments\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction get-values-instruction) stream)
  (format stream "   ~a [label = \"get-values\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction put-arguments-instruction) stream)
  (format stream "   ~a [label = \"put-values\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction put-values-instruction) stream)
  (format stream "   ~a [label = \"put-values\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction
    ((instruction constant-assignment-instruction) stream)
  (format stream "   ~a [label = \"<=\"];~%"
	  (gethash instruction *instruction-table*))
  (let ((name (gensym)))
    (format stream "   ~a [label = \"~a\", style = filled, fillcolor = pink];~%"
	    name
	    (constant instruction))
    (format stream "   ~a [fillcolor = pink];~%"
	    name)
    (format stream "   ~a -> ~a [color = pink, style = dashed];~%"
	    name
	    (gethash instruction *instruction-table*))))

(defmethod draw-instruction
    ((instruction variable-assignment-instruction) stream)
  (format stream "   ~a [label = \"<-\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction enter-instruction) stream)
  (format stream "   ~a [label = \"enter\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction leave-instruction) stream)
  (format stream "   ~a [label = \"leave\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction return-instruction) stream)
  (format stream "   ~a [label = \"ret\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction end-instruction) stream)
  (format stream "   ~a [label = \"end\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction nop-instruction) stream)
  (format stream "   ~a [label = \"nop\"];~%"
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction funcall-instruction) stream)
  (draw-location-info (fun instruction) stream)
  (format stream "   ~a [label = \"funcall\"];~%"
	  (gethash instruction *instruction-table*))
  (format stream "   ~a -> ~a [color = red, style = dashed];~%"
	  (gethash (fun instruction) *instruction-table*)
	  (gethash instruction *instruction-table*)))

(defmethod draw-instruction ((instruction test-instruction) stream)
  (format stream "   ~a [label = \"test\"];~%"
	  (gethash instruction *instruction-table*)))

(defun draw-flowchart (start filename)
  (with-open-file (stream filename
			  :direction :output
			  :if-exists :supersede)
    (let ((*instruction-table* (make-hash-table :test #'eq))
	  (p1::*table* (make-hash-table :test #'eq)))
	(format stream "digraph G {~%")
	(draw-instruction start stream)
	(format stream "}~%"))))
