(cl:in-package #:sicl-extrinsic-environment)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Main entry point.

(defun tie (untied arg-forms environment1 environment2)
  (let* ((args (loop for arg-form in arg-forms
		     collect (cleavir-env:eval
			      arg-form environment1 environment2)))
	 (result (apply untied args)))
    (if (typep result 'fun)
	(let ((tied (make-instance 'fun)))
	  (setf (untied tied) untied)
	  (setf (arg-forms tied) arg-forms)
	  (closer-mop:set-funcallable-instance-function tied result)
	  tied)
	result)))

(defparameter *form-cache* (make-hash-table :test #'eql))

(defparameter *cache-p* nil)

(defun maybe-cache (form function forms)
  (if (and *cache-p*
	   (consp form)
	   (member (car form) '(defun defmacro)))
      (let ((hash (sxhash form)))
	(setf (gethash hash *form-cache*) (cons function forms)))))

(defun compile-form (form environment1 environment2)
  (let* ((hash (sxhash form))
	 (cached-value (gethash hash *form-cache*))
	 (cleavir-generate-ast:*compiler* 'cl:eval)
	 (ast (cleavir-generate-ast:generate-ast form environment1 nil)))
    (if (null cached-value)
	(let* ((ast-bis (cleavir-ast-transformations:hoist-load-time-value ast))
	       (hir (cleavir-ast-to-hir:compile-toplevel ast-bis))
	       (ignore (cleavir-hir-transformations:eliminate-typeq hir))
	       (lambda-expr (translate hir environment2))
	       (fun (compile nil lambda-expr)))
	  (declare (ignore ignore))
	  ;; Run this just for test and to check performance.
	  (cleavir-hir-transformations:segregate-only hir)
	  ;; Run this just for test and to check performance.
	  (cleavir-simple-value-numbering:simple-value-numbering hir)
	  ;; Run this for test.  It may do some good too.
	  (cleavir-remove-useless-instructions:remove-useless-instructions hir)
	  (maybe-cache form fun (cleavir-ir:forms hir))
	  (cons fun (cleavir-ir:forms hir)))
	cached-value)))

(defmethod cleavir-env:eval (form environment1 (environment2 environment))
  (cond ((and (consp form)
	      (consp (cdr form))
	      (null (cddr form))
	      (eq (car form) 'quote))
	 (cadr form))
	((and (symbolp form)
	      (nth-value 1 (sicl-global-environment:constant-variable
			    form environment1)))
	 (nth-value 0 (sicl-global-environment:constant-variable
		       form environment1)))
	((and (atom form) (not (symbolp form)))
	 form)
	((and (consp form)
	      (consp (cdr form))
	      (consp (cddr form))
	      (null (cdddr form))
	      (eq (car form) 'sicl-global-environment:function-cell)
	      (eq (caddr form) 'sicl-global-environment:*global-environment*)
	      (consp (cadr form))
	      (consp (cdr (cadr form)))
	      (null (cddr (cadr form)))
	      (eq (car (cadr form)) 'quote))
	 (sicl-global-environment:function-cell (cadr (cadr form))
						environment2))
	((and (consp form)
	      (consp (cdr form))
	      (consp (cddr form))
	      (null (cdddr form))
	      (eq (car form) 'sicl-global-environment:function-cell)
	      (equal (caddr form) '(sicl-global-environment:global-environment))
	      (consp (cadr form))
	      (consp (cdr (cadr form)))
	      (null (cddr (cadr form)))
	      (eq (car (cadr form)) 'quote))
	 (sicl-global-environment:function-cell (cadr (cadr form))
						environment2))
	((and (consp form)
	      (consp (cdr form))
	      (consp (cddr form))
	      (null (cdddr form))
	      (eq (car form) 'sicl-global-environment:variable-cell)
	      (eq (caddr form) 'sicl-global-environment:*global-environment*)
	      (consp (cadr form))
	      (consp (cdr (cadr form)))
	      (null (cddr (cadr form)))
	      (eq (car (cadr form)) 'quote))
	 (sicl-global-environment:variable-cell (cadr (cadr form))
						environment2))
	((and (consp form)
	      (consp (cdr form))
	      (consp (cddr form))
	      (null (cdddr form))
	      (eq (car form) 'sicl-global-environment:variable-cell)
	      (equal (caddr form) '(sicl-global-environment:global-environment))
	      (consp (cadr form))
	      (consp (cdr (cadr form)))
	      (null (cddr (cadr form)))
	      (eq (car (cadr form)) 'quote))
	 (sicl-global-environment:variable-cell (cadr (cadr form))
						environment2))
	((eq form 'sicl-global-environment:*global-environment*)
	 environment2)
	(t
	 (let ((fun-and-forms (compile-form form environment1 environment2)))
	   (tie (car fun-and-forms) (cdr fun-and-forms)
		environment1 environment2)))))
