;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: CLOS -*-
;;;;
;;;;  Copyright (c) 1992, Giuseppe Attardi.o
;;;;  Copyright (c) 2001, Juan Jose Garcia Ripoll.
;;;;
;;;;    This program is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.


(in-package "CLOS")

(defmethod class-prototype ((class class))
  (unless (slot-boundp class 'prototype)
    (setf (slot-value class 'prototype) (allocate-instance class)))
  (slot-value class 'prototype))

(defmethod slot-value-using-class ((class std-class) self slotd)
  (let* ((location (slot-definition-location slotd))
	 (value (standard-location-access self location)))
    (if (si:sl-boundp value)
	value
	(values (slot-unbound class self (slot-definition-name slotd))))))

(defmethod slot-boundp-using-class ((class std-class) self slotd)
  (declare (ignore class))
  (si:sl-boundp (standard-location-access self (slot-definition-location slotd))))

;;; FIXME: argument precedence of class self slotd val would be preferred.
(defmethod (setf slot-value-using-class) (val (class std-class) self slotd)
  (declare (ignore class))
  (setf (standard-location-access self (slot-definition-location slotd)) val))

(defmethod slot-makunbound-using-class ((class std-class) instance slotd)
  (declare (ignore class))
  (setf (standard-location-access instance (slot-definition-location slotd)) (si:unbound))
  instance)

;;; FIXME: argument precedence of class object slotd old new would be preferred.
;;; FIXME: (cas slot-value-using-class) would be a better name.
#+threads
(defmethod cas-slot-value-using-class
    (old new (class std-class) object
     (slotd standard-effective-slot-definition))
  (let ((loc (slot-definition-location slotd)))
    (ecase (slot-definition-allocation slotd)
      ((:instance) (core::instance-cas old new object loc))
      ((:class) (core::cas-car :sequentially-consistent old new loc)))))

#+threads
(mp::define-simple-cas-expander clos:slot-value-using-class
  cas-slot-value-using-class
  (class instance slotd)
  "Same requirements as STANDARD-INSTANCE-ACCESS, except the slot can
have allocation :class.
Also, methods on SLOT-VALUE-USING-CLASS, SLOT-BOUNDP-USING-CLASS, and
(SETF SLOT-VALUE-USING-CLASS) are ignored (not invoked).
In the future, this may be customizable with a generic function.")

;;; FIXME: Should these even be methods? Semantics getting weird here.
;;; FIXME: Anyway they force sequentially consistent order, eck.

#+threads
(defmethod atomic-slot-value-using-class
    ((class std-class) object (slotd standard-effective-slot-definition))
  (let ((loc (slot-definition-location slotd)))
    (ecase (slot-definition-allocation slotd)
      ((:instance) (mp:atomic (standard-instance-access object loc)))
      ((:class) (mp:atomic (car loc))))))

#+threads
(defmethod (setf atomic-slot-value-using-class)
    (new-value (class std-class) object
     (slotd standard-effective-slot-definition))
  (let ((loc (slot-definition-location slotd)))
    (ecase (slot-definition-allocation slotd)
      ((:instance) (setf (mp:atomic (standard-instance-access object loc))
                         new-value))
      ((:class) (setf (mp:atomic (car loc)) new-value)))))

#+threads
(mp:define-atomic-expander slot-value-using-class (class object slotd)
    (&rest keys)
  (declare (ignore keys))
  (let ((gclass (gensym "CLASS")) (gobject (gensym "OBJECT"))
        (gslotd (gensym "SLOTD")) (oldv (gensym "OLD")) (newv (gensym "NEWV")))
    (values (list gclass gobject gslotd) (list class object slotd) oldv newv
            `(atomic-slot-value-using-class ,gclass ,gobject ,gslotd)
            `(setf (atomic-slot-value-using-class ,gclass ,gobject ,gslotd)
                   ,newv)
            `(cas-slot-value-using-class ,oldv ,newv
                                         ,gclass ,gobject ,gslotd))))

;;;
;;; 3) Error messages related to slot access
;;;

(defmethod slot-missing ((class t) object slot-name operation 
			 &optional new-value)
  (declare (ignore operation new-value class))
  (error "~A is not a slot of ~A" slot-name object))

(defmethod slot-unbound ((class t) object slot-name)
  (declare (ignore class))
  (error 'unbound-slot :instance object :name slot-name))

(defmethod (setf class-name) (new-value (class class))
  (declare (notinline reinitialize-instance)) ; bootstrapping
  (reinitialize-instance class :name new-value)
  new-value)
