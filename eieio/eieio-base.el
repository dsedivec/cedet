;;; eieio.el --- Enhanced Implementation of Emacs Interpreted Objects
;;               or maybe Eric's Implementation of Emacs Intrepreted Objects

;;;
;; Copyright (C) 2000 Eric M. Ludlam
;;
;; Author: <zappo@gnu.org>
;; RCS: $Id$
;; Keywords: OO, lisp
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, you can either send email to this
;; program's author (see below) or write to:
;;
;;              The Free Software Foundation, Inc.
;;              675 Mass Ave.
;;              Cambridge, MA 02139, USA.
;;
;; Please send bug reports, etc. to zappo@gnu.org
;;
;; Updates can be found at:
;;    ftp://ftp.ultranet.com/pub/zappo

;;; Commentary:
;;
;; Base classes for EIEIO.  These classes perform some basic tasks
;; but are generally useless on their own.  To use any of these classes,
;; inherit from one or more of them.

(require 'eieio)

;;; Code:

;;; eieio-instance-inheritor
;;
;; Enable instance inheritance via the `clone' method.
;; Works by using the `slot-unbound' method which usually throws an
;; error if a slot is unbound.
(defclass eieio-instance-inheritor ()
  ((parent-instance :initarg :parent-instance
		    :type eieio-instance-inheritor
		    :documentation
		    "The parent of this instance.
If a slot of this class is reference, and is unbound, then  the parent
is checked for a value.")
   )
  "This special class can enable instance inheritance.
Use `clone' to make a new object that does instance inheritance from
a parent instance.  When a slot in the child is referenced, and has
not been set, use values from the parent.")

(defmethod slot-unbound ((object eieio-instance-inheritor) class slot-name fn)
  "If a slot OBJECT in this CLASS is unbound, try to inherit, or throw a signal.
SLOT-NAME, is the offending slot.  FN is the function signalling the error."
  (if (slot-boundp object 'parent-instance)
      (eieio-oref (oref object parent-instance) slot-name)
    (call-next-method)))

(defmethod clone ((obj eieio-instance-inheritor) &rest params)
  "Clone OBJ, initializing `:parent' to OBJ.
All slots are unbound, except those initialized with PARAMS."
  (let ((nobj (make-vector (length obj) eieio-unbound))
	(nm (aref obj object-name))
	(passname (and params (stringp (car params))))
	(num 1))
    (aset nobj 0 'object)
    (aset nobj object-class (aref obj object-class))
    ;; The following was copied from the default clone.
    (if (not passname)
	(save-match-data
	  (if (string-match "-\\([0-9]+\\)" nm)
	      (setq num (1+ (string-to-int (match-string 1 nm)))
		    nm (substring nm 0 (match-beginning 0))))
	  (aset nobj object-name (concat nm "-" (int-to-string num))))
      (aset nobj object-name (car params)))
    ;; Now initialize from params.
    (if params (shared-initialize nobj (if passname (cdr params) params)))
    (oset nobj parent-instance obj)
    nobj))


;;; eieio-instance-tracker
;;
;; Track all created instances of this class.
;; The class must initialize the `tracking-symbol' slot, and that
;; symbol is then used to contain these objects.
(defclass eieio-instance-tracker ()
  ((tracking-symbol :type symbol
		    :allocation class
		    :documentation
		    "The symbol used to maintain a list of our instances.
The instance list is treated as a variable, with new instances added to it.")
   )
  "This special class enables instance tracking.
Inheritors from this class must overload `tracking-symbol' which is
a variable symbol used to store a list of all instances.")

(defmethod initialize-instance :AFTER ((this eieio-instance-tracker)
				       &rest fields)
  "Make sure THIS is in our master list of this class.
Optional argument FIELDS are the initialization arguments."
  ;; Theoretically, this is never called twice for a given instance.
  (add-to-list (oref this tracking-symbol) this t))

(defmethod delete-instance ((this eieio-instance-tracker))
  "Remove THIS from the master list of this class."
  (set (oref this tracking-symbol)
       (delq this (symbol-value (oref this tracking-symbol)))))

;; In retrospect, this is a silly function.
(defun eieio-instance-tracker-find (key field list-symbol)
  "Find KEY as an element of FIELD in the objects in LIST-SYMBOL.
Returns the first match."
  (object-assoc key field (symbol-value list-symbol)))


;;; eieio-persistent
;;
;; For objects which must save themselves to disk.  Provides a
;; `object-save' method to save an object to disk, and a
;; `eieio-persistent-read' function to call to read an object
;; from disk.
;;
;; Also provide the method `eieio-persistent-path-relative' to
;; calculate path names relative to a given instance.  This will
;; can make the saved object location independent of all file
;; references are made relative.
(defclass eieio-persistent ()
  ((file :initarg :file
	 :type string
	 :documentation
	 "The save file for this persistent object.
This must be a string, and must be specified when the new object is
instantiated.")
   (file-header-line :type string
		     :allocation class
		     :initform ";; EIEIO PERSISTENT OBJECT"
		     :documentation
		     "Header line for the save file.
This is used with the `object-write' method."))
  "This special class enables persistence through save files.
Use the `object-save' method to write this object to disk.")

(defun eieio-persistent-read (filename)
  "Read a persistent object from FILENAME."
  (save-excursion
    (let ((ret nil))
      (set-buffer (get-buffer-create " *tmp eieio read*"))
      (unwind-protect
	  (progn
	    (erase-buffer)
	    (insert-file filename)
	    (goto-char (point-min))
	    (setq ret (read (current-buffer)))
	    (if (not (child-of-class-p (car ret) 'eieio-persistent))
		(error "Corrupt object on disk"))
	    (setq ret (eval ret))
	    (oset ret file filename))
	(kill-buffer " *tmp eieio read*"))
      ret)))

(defmethod object-write ((this eieio-persistent) &optional comment)
  "Write persistent object THIS out to the current stream.
Optional argument COMMENT is a header line comment."
  (call-next-method this (or comment (oref this file-header-line))))

(defmethod eieio-persistent-path-relative ((this eieio-persistent) file)
  "For object THIS, make absolute file name FILE relative."
  (let* ((src (expand-file-name file))
	 (dest (file-name-directory (oref this file)))
	 (cs1  (compare-strings src 0 nil dest 0 nil))
	 diff abdest absrc)
    ;; Find the common directory part
    (setq diff (substring src 0 cs1))
    (setq cs1 (split-string diff "[\\/]"))
    (setq cs1 (length (nth (1- (length cs1)) cs1)))
    (setq diff (substring diff 0 (- (length diff) cs1)))
    ;; Get the uncommon bits from dest and src.
    (setq abdest (substring dest (length diff))
	  absrc (substring src (length diff)))
    ;; Find number if dirs in absrc, and add those as ".." to dest.
    ;; Rember we have a file name, so that is the 1-.
    (setq cs1 (1- (length (split-string absrc "[\\/]"))))
    (while (> cs1 0)
      (setq abdest (concat "../" abdest)
	    cs1 (1- cs1)))
    absrc))

(defmethod eieio-persistent-save ((this eieio-persistent) &optional file)
  "Save persistent object THIS to disk.
Optional argument FILE overrides the file name specified in the object
instance."
  (save-excursion
    (let ((b (set-buffer (get-buffer-create " *tmp object write*")))
	  (cfn (oref this file)))
      (unwind-protect
	  (save-excursion
	    (erase-buffer)
	    (let ((standard-output (current-buffer)))
	      (oset this file
		    (if file
			(eieio-persistent-path-relative this file)
		      (file-name-nondirectory cfn)))
	      (object-write this (oref this file-header-line)))
	    (write-file cfn nil))
	;; Restore :file, and kill the tmp buffer
	(oset this file cfn)
	(kill-buffer b)))))

;; Notes on the persistent object:
;; It should also set up some hooks to help it keep itself up to date.


(provide 'eieio-base)

;;; eieio-base.el ends here
