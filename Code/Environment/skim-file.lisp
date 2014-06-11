(cl:in-package #:sicl-global-environment)

;;;; Skimming a file means processing the top-level forms the way
;;;; COMPILE-FILE does in terms of compile-time side effects on the
;;;; environment.  No code is generated. 
;;;;
;;;; This file is part of the bootstrapping process, so we can assume
;;;; that the files that are processed are well formed.  For that
;;;; reason, no sophisticated error handling is required. 

;;; Skim a compound form with respect to ENVIRONMENT, where HEAD is
;;; the CAR of the form, FORM is the entire form. 
(defgeneric skim-compound-form (head form environment))

;;; Skim FORM with respect to ENVIRONMENT.
(defun skim-form (form environment)
  (let ((expanded-form (fully-expand-form form environment)))
    (when (consp expanded-form)
      (skim-compound-form (car expanded-form) expanded-form environment))))

(defmethod skim-compound-form (head form environment)
  (declare (ignore head form environment))
  nil)

;;; The subforms of a PROGN form are considered to be top-level forms
;;; so they should be processed just like the form itself.
(defmethod skim-compound-from ((head (eql 'progn)) form environment)
  (loop for subform in (rest form)
	do (skim-form subform environment)))

;;; The subforms of a LOCALLY form are considered to be top-level
;;; forms so they should be processed just like the form itself.  We
;;; cheat a bit here because we treat the declarations of the LOCALLY
;;; form as if they were forms as well.  We can get away with that
;;; because when a declaration is processed as a form (with DECLARE as
;;; the head symbol), then we will invoke the default method which
;;; does nothing. 
(defmethod skim-compound-from ((head (eql 'locally)) form environment)
  (loop for subform in (rest form)
	do (skim-form subform environment)))

;;; The main action happens when we see an EVAL-WHEN form with
;;; :COMPILE-TOPLEVEL or COMPILE being one of the situations.
(defmethod skim-compound-form ((head (eql 'eval-when)) form environment)
  (destructuring-bind (situations . forms) (rest form)
    (unless (null (intersection '(:compile-toplevel compile) situations))
      (mapc #'eval forms))))
