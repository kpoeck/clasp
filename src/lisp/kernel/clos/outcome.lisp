(in-package "CLOS")

;;; An "outcome" is a potential "outcome" of a generic function call.
;;; Basically, an outcome represents an effective method function,
;;; only it's simpler in many cases.

;;; Outcomes

(defstruct (outcome (:type vector) :named) methods)
(defstruct (optimized-slot-reader (:type vector) (:include outcome) :named)
  index slot-name class)
(defstruct (optimized-slot-writer (:type vector) (:include outcome) :named)
  index slot-name class)
(defstruct (effective-method-outcome (:type vector) (:include outcome) :named)
 (form nil) (function nil))

(defun outcome= (outcome1 outcome2)
  (or (eq outcome1 outcome2) ; covers effective-method-outcome due to closfastgf caching
      (cond ((optimized-slot-reader-p outcome1)
             (and (optimized-slot-reader-p outcome2)
                  ;; could also do class slot locations somehow,
                  ;; but it doesn't seem like a big priority.
                  (fixnump (optimized-slot-reader-index outcome1))
                  (fixnump (optimized-slot-reader-index outcome2))
                  (= (optimized-slot-reader-index outcome1)
                     (optimized-slot-reader-index outcome2))))
            ((optimized-slot-writer-p outcome1)
             (and (optimized-slot-writer-p outcome2)
                  (fixnump (optimized-slot-writer-index outcome1))
                  (fixnump (optimized-slot-writer-index outcome2))
                  (= (optimized-slot-writer-index outcome1)
                     (optimized-slot-writer-index outcome2))))
            (t nil))))