(cl:in-package #:sicl-new-boot-phase-3)

(defmethod sicl-genv:typep
    (object (type-specifier (eql 'function)) (environment environment))
  (typep object 'function))

;;; We only check for the type CLASS for reasons of catching errors,
;;; but during bootstrapping, we completely control the arguments, so
;;; we can simply return true here.
(defmethod sicl-genv:typep
    (object (type-specifier (eql 'class)) (environment environment))
  t)

(defun create-mop-classes (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)
                   (e4 sicl-new-boot:e4))
      boot
    (import-functions-from-host '(sicl-genv:typep) e3)
    (setf (sicl-genv:fdefinition 'typep e3)
          (lambda (object type)
            (sicl-genv:typep object type e3)))
    (setf (sicl-genv:fdefinition 'sicl-clos:validate-superclass e3)
          (lambda (class direct-superclass)
            (declare (ignore class direct-superclass))
            t))
    (setf (sicl-genv:fdefinition 'sicl-clos:direct-slot-definition-class e3)
          (lambda (&rest arguments)
            (declare (ignore arguments))
            (sicl-genv:find-class 'sicl-clos:standard-direct-slot-definition e2)))
    (import-functions-from-host '(remove) e3)
    (load-file "CLOS/add-remove-direct-subclass-support.lisp" e3)
    (load-file "CLOS/add-remove-direct-subclass-defgenerics.lisp" e3)
    (load-file "CLOS/add-remove-direct-subclass-defmethods.lisp" e3)
    (import-functions-from-host
     '(sort mapcar eql position sicl-genv:find-class)
     e3)
    (load-file "CLOS/classp-defgeneric.lisp" e3)
    (load-file "CLOS/classp-defmethods.lisp" e3)
    (load-file "CLOS/compute-applicable-methods-support.lisp" e3)
    (load-file "New-boot/Phase-2/sub-specializer-p.lisp" e3)
    (setf (sicl-genv:special-variable 'sicl-clos::*class-t* e3 t) nil)
    (load-file-protected "CLOS/add-remove-method-support.lisp" e3)
    (load-file-protected "CLOS/add-accessor-method.lisp" e3)
    (load-file "CLOS/default-superclasses-defgeneric.lisp" e3)
    (load-file "CLOS/default-superclasses-defmethods.lisp" e3)
    (load-file "CLOS/class-initialization-support.lisp" e3)
    (load-file "CLOS/class-initialization-defmethods.lisp" e3)
    (sicl-minimal-extrinsic-environment:import-function-from-host
     'sicl-clos:defclass-expander e3)
    (setf (sicl-genv:fdefinition '(setf find-class) e3)
          (lambda (new-class symbol &optional errorp)
            (declare (ignore errorp))
            (setf (sicl-genv:find-class symbol e3) new-class)))
    (define-error-function 'change-class e3)
    (define-error-function 'reinitialize-instance e3)
    (load-file "CLOS/ensure-class-using-class-support.lisp" e3)
    (load-file "CLOS/ensure-class-using-class-defgenerics.lisp" e3)
    (load-file "CLOS/ensure-class-using-class-defmethods.lisp" e3)
    (load-file "CLOS/ensure-class.lisp" e3)
    (load-file "CLOS/defclass-defmacro.lisp" e3)
    (import-function-from-host '(setf sicl-genv:special-variable) e3)
    (load-file "CLOS/t-defclass.lisp" e3)
    (setf (sicl-genv:special-variable 'sicl-clos::*class-t* e2 t)
          (sicl-genv:find-class 't e3))
    (load-file "CLOS/function-defclass.lisp" e3)
    (load-file "CLOS/standard-object-defclass.lisp" e3)
    (load-file "CLOS/metaobject-defclass.lisp" e3)
    (load-file "CLOS/method-defclass.lisp" e3)
    (load-file "CLOS/standard-method-defclass.lisp" e3)
    (load-file "CLOS/standard-accessor-method-defclass.lisp" e3)
    (load-file "CLOS/standard-reader-method-defclass.lisp" e3)
    (load-file "CLOS/standard-writer-method-defclass.lisp" e3)
    (load-file "CLOS/slot-definition-defclass.lisp" e3)
    (load-file "CLOS/standard-slot-definition-defclass.lisp" e3)
    (load-file "CLOS/direct-slot-definition-defclass.lisp" e3)
    (load-file "CLOS/effective-slot-definition-defclass.lisp" e3)
    (load-file "CLOS/standard-direct-slot-definition-defclass.lisp" e3)
    (load-file "CLOS/standard-effective-slot-definition-defclass.lisp" e3)
    (load-file "CLOS/method-combination-defclass.lisp" e3)
    (load-file "CLOS/specializer-defclass.lisp" e3)
    (load-file "CLOS/eql-specializer-defclass.lisp" e3)
    (load-file "CLOS/class-unique-number-defparameter.lisp" e3)
    (load-file "CLOS/class-defclass.lisp" e3)
    (load-file "CLOS/forward-referenced-class-defclass.lisp" e3)
    (load-file "CLOS/real-class-defclass.lisp" e3)
    (load-file "CLOS/regular-class-defclass.lisp" e3)
    (load-file "CLOS/standard-class-defclass.lisp" e3)
    (load-file "CLOS/funcallable-standard-class-defclass.lisp" e3)
    (load-file "CLOS/built-in-class-defclass.lisp" e3)
    (load-file "CLOS/funcallable-standard-object-defclass.lisp" e3)
    (load-file "CLOS/generic-function-defclass.lisp" e3)
    (load-file "CLOS/standard-generic-function-defclass.lisp" e3)))
