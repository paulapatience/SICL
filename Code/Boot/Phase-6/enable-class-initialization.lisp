(cl:in-package #:sicl-boot-phase-6)

(defun define-add-remove-direct-subclass (eb)
  (load-fasl "CLOS/add-remove-direct-subclass-support.fasl" eb)
  (load-fasl "CLOS/add-remove-direct-subclass-defgenerics.fasl" eb)
  (load-fasl "CLOS/add-remove-direct-subclass-defmethods.fasl" eb))

(defun define-add-remove-method (eb)
  (load-fasl "CLOS/add-remove-method-defgenerics.fasl" eb)
  (load-fasl "CLOS/add-remove-method-support.fasl" eb)
  (load-fasl "CLOS/add-remove-method-defmethods.fasl" eb))

(defun define-add-remove-direct-method (eb)
  (load-fasl "CLOS/add-remove-direct-method-defgenerics.fasl" eb)
  (load-fasl "CLOS/add-remove-direct-method-support.fasl" eb)
  (load-fasl "CLOS/add-remove-direct-method-defmethods.fasl" eb))

(defun define-reader/writer-method-class (ea eb)
  (sicl-boot:with-straddled-function-definitions
      ((sicl-clos::reader-method-class-default
        sicl-clos::writer-method-class-default)
       eb)
    (load-fasl "CLOS/reader-writer-method-class-support.fasl" ea))
  (load-fasl "CLOS/reader-writer-method-class-defgenerics.fasl" eb)
  (load-fasl "CLOS/reader-writer-method-class-defmethods.fasl" eb))

(defun define-direct-slot-definition-class (ea eb)
  (sicl-boot:with-straddled-function-definitions
      ((sicl-clos::direct-slot-definition-class-default)
       eb)
    (load-fasl "CLOS/direct-slot-definition-class-support.fasl" ea))
  (load-fasl "CLOS/direct-slot-definition-class-defgeneric.fasl" eb)
  (load-fasl "CLOS/direct-slot-definition-class-defmethods.fasl" eb))

(defun define-find-or-create-generic-function (eb ec)
  (setf (sicl-genv:fdefinition 'sicl-clos::find-or-create-generic-function eb)
        (lambda (name lambda-list)
          (declare (ignore lambda-list))
          (sicl-genv:fdefinition name ec))))

(defun define-validate-superclass (eb)
  (load-fasl "CLOS/validate-superclass-defgenerics.fasl" eb)
  (load-fasl "CLOS/validate-superclass-defmethods.fasl" eb))

(defun define-dependent-protocol (eb)
  (setf (sicl-genv:fdefinition 'sicl-clos:map-dependents eb)
        (constantly nil))
  (setf (sicl-genv:fdefinition 'sicl-clos:update-dependent eb)
        (constantly nil)))

(defun define-ensure-class (eb)
  (load-fasl "CLOS/ensure-class-using-class-support.fasl" eb)
  (load-fasl "CLOS/ensure-class-using-class-defgenerics.fasl" eb)
  (load-fasl "CLOS/ensure-class-using-class-defmethods.fasl" eb)
  (load-fasl "Environment/find-class-defun.fasl" eb)
  (load-fasl "Environment/standard-environment-functions.fasl" eb)
  (load-fasl "CLOS/ensure-class.fasl" eb))

(defun enable-class-initialization (ea eb ec)
  (setf (sicl-genv:fdefinition 'typep eb)
        (lambda (object type)
          (sicl-genv:typep object type eb)))
  (define-validate-superclass eb)
  (define-direct-slot-definition-class ea eb)
  (define-add-remove-direct-subclass eb)
  (setf (sicl-genv:special-variable 'sicl-clos::*class-t* eb t) nil)
  (define-add-remove-method eb)
  (load-fasl "CLOS/add-accessor-method.fasl" eb)
  (define-find-or-create-generic-function eb ec)
  (load-fasl "CLOS/default-superclasses-defgeneric.fasl" eb)
  (load-fasl "CLOS/default-superclasses-defmethods.fasl" eb)
  (load-fasl "CLOS/class-initialization-support.fasl" eb)
  (load-fasl "CLOS/class-initialization-defmethods.fasl" eb)
  (load-fasl "CLOS/reinitialize-instance-defgenerics.fasl" eb)
  (define-ensure-class eb)
  ;; FIXME: load files containing the definition instead.
  (setf (sicl-genv:fdefinition 'sicl-clos:add-direct-method eb)
        (constantly nil))
  (define-dependent-protocol eb)
  (define-reader/writer-method-class ea eb))
