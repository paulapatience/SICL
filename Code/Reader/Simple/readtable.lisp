(cl:in-package #:sicl-reader)

(defparameter *readtable* nil)

(defclass readtable ()
  ((%syntax-types :initform (make-hash-table) :reader syntax-types)
   (%macro-characters :initform (make-hash-table) :reader macro-characters)
   (%readtable-case :initform :upcase :accessor readtable-case)))

(defun syntax-type (char)
  (or (gethash char (syntax-types *readtable*))
      :constituent))

(defun make-dispatch-macro-character
    (char &optional (non-terminating-p nil) (readtable *readtable*))
  (setf (gethash char (syntax-types readtable))
	(if non-terminating-p
	    :non-terminating-macro
	    :terminating-macro))
  (setf (gethash char (macro-characters readtable))
	(make-hash-table))
  t)

(defun set-macro-character
    (char function &optional (non-terminating-p nil) (readtable *readtable*))
  (setf (gethash char (syntax-types readtable))
	(if non-terminating-p
	    :non-terminating-macro
	    :terminating-macro))
  (setf (gethash char (macro-characters readtable))
	function)
  t)

(defun get-macro-character (char &optional (readtable *readtable*))
  (let ((entry (gethash char (macro-characters readtable))))
    (values
     (if (functionp entry) entry nil)
     (eq (gethash char (syntax-types readtable)) :non-terminating-macro))))

(defun set-dispatch-macro-character
    (disp-char sub-char function &optional (readtable *readtable*))
  (when (digit-char-p sub-char)
    (error 'sub-char-must-not-be-a-decimal-digit
	   :disp-char disp-char
	   :sub-char sub-char))
  (setf sub-char (char-upcase sub-char))
  (let ((entry (gethash disp-char (macro-characters readtable))))
    (unless (hash-table-p entry)
      (error 'char-must-be-a-dispatching-character
	     :disp-char disp-char))
    (setf (gethash sub-char entry) function)))

(defun get-dispatch-macro-character
    (disp-char sub-char &optional (readtable *readtable*))
  ;; The HyperSpec does not say whether we should convert
  ;; to upper case here, but we think we should.
  (setf sub-char (char-upcase sub-char))
  (let ((entry (gethash disp-char (macro-characters readtable))))
    (unless (hash-table-p entry)
      (error 'char-must-be-a-dispatching-character
	     :disp-char disp-char))
    (gethash sub-char entry)))

(defun copy-readtable (&optional (from-readtable *readtable*) to-readtable)
  (when (null to-readtable)
    (setf to-readtable (make-instance 'readtable)))
  (clrhash (syntax-types to-readtable))
  (clrhash (macro-characters to-readtable))
  (maphash (lambda (key value)
	     (setf (gethash key (syntax-types to-readtable)) value))
	   (syntax-types from-readtable))
  (maphash (lambda (char entry)
	     (if (functionp entry)
		 (setf (gethash char (macro-characters to-readtable))
		       entry)
		 (let ((table (make-hash-table)))
		   (maphash (lambda (sub-char function)
			      (setf (gethash sub-char table) function))
			    entry)
		   (setf (gethash char (macro-characters to-readtable))
			 table))))
	   (macro-characters from-readtable))
  (setf (readtable-case to-readtable)
	(readtable-case from-readtable))
  to-readtable)
