(cl:in-package #:sicl-clos)

(defun check-argument-precedence-order
    (argument-precedence-order required-parameters)
  (unless (cleavir-code-utilities:proper-list-p argument-precedence-order)
    (error "argument-precedence-order must be a proper list"))
  (unless (and (= (length argument-precedence-order)
		  (length required-parameters))
	       (null (set-difference argument-precedence-order
				     required-parameters))
	       (null (set-difference required-parameters
				     argument-precedence-order)))
    (error "argument precedence order must be a permutation~@
            of the required parameters")))

(defun check-documentation (documentation)
  (unless (or (null documentation) (stringp documentation))
    (error "documentation must be NIL or a string")))

;;; FIXME: check the syntax of each declaration. 
(defun check-declarations (declarations)
  (unless (cleavir-code-utilities:proper-list-p declarations)
    (error "declarations must be a proper list")))

(defun check-method-combination (method-combination)
  ;; FIXME: check that method-combination is a method-combination
  ;; metaobject.
  (declare (ignore method-combination))
  nil)

(defun check-method-class (method-class)
  ;; FIXME: check that the method-class is a subclss of METHOD.
  (declare (ignore method-class))
  nil)

(defun shared-initialize-around-generic-function-default
    (call-next-method
     invalidate-discriminating-function
     generic-function
     slot-names
     &rest initargs
     &key
       documentation
       declarations
       (lambda-list nil lambda-list-p)
       (argument-precedence-order nil argument-precedence-order-p)
       method-combination
       (method-class (find-class 'standard-method))
       name
     &allow-other-keys)
  (check-documentation documentation)
  (check-declarations declarations)
  (check-method-combination method-combination)
  (check-method-class method-class)
  (if lambda-list-p
      (let* ((parsed-lambda-list
	       (cleavir-code-utilities:parse-generic-function-lambda-list
		lambda-list))
	     (required (cleavir-code-utilities:required parsed-lambda-list)))
	(if argument-precedence-order-p
	    (check-argument-precedence-order argument-precedence-order required)
	    (setf argument-precedence-order required))
	(apply call-next-method
	       generic-function
	       slot-names
	       :documentation documentation
	       :declarations declarations
	       :argument-precedence-order argument-precedence-order
	       :specializer-profile (make-list (length required)
					       :initial-element nil)
	       :method-class method-class
	       :name name
	       initargs))
      (if argument-precedence-order-p
	  (error "when argument precedence order appears,~@
                  so must lambda list")
	  (apply call-next-method
		 generic-function
		 slot-names
		 :documentation documentation
		 :declarations declarations
		 :method-class method-class
		 :name name
		 initargs)))
  (funcall invalidate-discriminating-function generic-function)
  generic-function)
