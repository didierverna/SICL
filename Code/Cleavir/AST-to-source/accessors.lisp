(cl:in-package #:cleavir-ast-to-source)

(defmethod to-source ((ast cleavir-ast:car-ast) dictionary)
  `(%car ,(to-source (cleavir-ast:cons-ast ast) dictionary)))

