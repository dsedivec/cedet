;;; dlg-class - Class definitions and implementations for config widgets
;;;
;;; Copyright (C) 1996 Eric M. Ludlam
;;;
;;; Author: <zappo@gnu.ai.mit.edu>
;;; RCS: $Id$
;;; Keywords: OO, dialog, configure
;;;                                                                          
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, you can either send email to this
;;; program's author (see below) or write to:
;;;
;;;              The Free Software Foundation, Inc.
;;;              675 Mass Ave.
;;;              Cambridge, MA 02139, USA. 
;;;      
;;; Please send bug reports, etc. to zappo@gnu.ai.mit.edu.
;;;      
;;; dlg-class can be found in the eieio or etalk distributions on:
;;;  ftp://ftp.ultranet.com/pub/zappo
;;;
;;; Commentary:
;;;   This will provide classes needed to create interactive
;;; configuration dialogs using dlg-config.  The data types provided
;;; all know how to edit an emacs init file or Xdefaults file, and how
;;; to modify a running environment using functions found in
;;; dlg-config.
;;;           
(require 'eieio)
(require 'dialog)
(require 'loadhist)			;for feature loading/dumping

;;;
;;; Specialized option button for font styles
;;;
(defclass widget-option-button-dlg-font-style (widget-option-button)
  nil
  "Special kind of option-button whose default face changes with
different values of state")

(defmethod reset-option-label :BEFORE ((this widget-option-button-dlg-font-style))
  "Change our face whenever a new button label is presented."
  (oset this face (aref [ 'default 'bold 'italic 'bold-italic ]
			(get-value (oref this state))))
  (oset this focus-face (aref [ 'bold 'default 'bold-italic 'italic ]
			      (get-value (oref this state)))))

(defmethod verify :AFTER ((this widget-option-button-dlg-font-style) fix)
  "Change our face to be dependent upon our initialization value in state."
  (oset this face (aref [ 'default 'bold 'italic 'bold-italic ]
			(get-value (oref this state))))
  (oset this focus-face (aref [ 'bold 'default 'bold-italic 'italic ]
			      (get-value (oref this state)))))

;;;
;;; Specialized data types
;;;
(defclass data-object-symbol (data-object)
  ((symbol :initarg :symbol
	   :initform nil
	   :docstring "Symbol whose value changes in parallel to :value"
	   :protection private)
   (protect :initarg :protect
	    :initform nil
	    :docstring "t if this symbol is not to be saved into a file"
	    :protection private))
  "This is a type of `data-object' which will initialize itself to the
value stored in the `symbol' field, and which will also (optionally)
save its value back into `symbol' when the user edits it.")

(defmethod dlg-init-symbol ((this data-object-symbol))
  "Make sure that the symbol part of of our data object is correctly
initialized."
  (if (and (not (oref this symbol)) (symbolp (object-name-string this)))
      (oset this symbol (object-name-string this))))

(defmethod constructor :AFTER ((this data-object-symbol) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we are editing"
  (dlg-init-symbol this)
  (oset this value (symbol-value (oref this symbol))))

(defclass data-object-symbol-string-to-int (data-object-symbol)
  ((float-p :initarg :float-p
	    :initform t
	    :docstring "t when this object allows floating point numbers, 
nil indicates that only whole numbers are allowed"
	    :protection private))
  "This data object assumes that `symbol' will be a number.  The
string it maintains will be translated back into a number whenever it
is set back into `symbol'")

(defmethod constructor :AFTER ((this data-object-symbol-string-to-int) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we are editing"
  (dlg-init-symbol this)
  (let ((sv (symbol-value (oref this symbol))))
    (oset this value (if (numberp sv) (int-to-string sv) ""))))

(defclass data-object-symbol-list-index (data-object-symbol)
  ((string-list :initarg :string-list
		:initform nil
		:docstring "List into which `value' indexes."
		:protection private))
  "This type of object will also maintain its value as a number in the
variable associated with the symbol field.  The symbol will be
assigned a value from this string list while the `value' slot
maintains a number.")

(defmethod constructor :AFTER ((this data-object-symbol-list-index) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we are editing"
  (dlg-init-symbol this))

(defclass data-object-symbol-lisp-expression (data-object-symbol)
  nil
  "This type of object will maintain its value as an expression in the
variable associated with the symbol field while `value' remains as a
string.  `read' us used to translate the string, and `symbol' will not
be changed if the read fails.")

(defmethod constructor :AFTER ((this data-object-symbol-lisp-expression) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we are editing."
  (dlg-init-symbol this)
  (if (not (oref this value)) ;; don't override the default
      (let ((sv (symbol-value (oref this symbol))))
	(oset this value
	      (if (not sv) 
		  ""
		(format "%S" (symbol-value (oref this symbol))))))))

(defclass data-object-symbol-default (data-object-symbol)
  nil
  "This type of object uses set-default for the given symbol instead
of set as used by `data-object-symbol'")

(defmethod constructor :AFTER ((this data-object-symbol-default) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we are editing"
  (dlg-init-symbol this)
  (oset this value (default-value (oref this symbol))))

(defclass data-object-symbol-feature (data-object-symbol)
  ((unload-commands :initarg :unload-commands
		    :initform nil
		    :docstring "Some packages may need additional unloading commands run.
Initialize this to be a string with the necessary commands needed to
turn the feature off before it is unloaded."
		    :protection private))
  "This type of object uses require / unload-feature for the given
symbol.  Some features turn themselves on automatically, which is why
:unload-commands are needed to turn them off.")

(defmethod constructor :AFTER ((this data-object-symbol-feature) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we are editing"
  (dlg-init-symbol this)
  (oset this value (featurep (oref this symbol))))

(defclass data-object-symbol-hook (data-object-symbol)
  ((command :initarg :command
	    :initform nil
	    :docstring "A string representing a command to install in a hook.
The hook value us interpreted by `read' before installation."
	    :protection private))
  "This type of object uses add/remove-hook for the given symbol")

(defmethod constructor :AFTER ((this data-object-symbol-hook) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we want to add a hook to."
  (dlg-init-symbol this)
  (if (not (boundp (oref this symbol)))	;make sure the hook exists first
      (set (oref this symbol) nil))
  (oset this value (member (read (oref this command))
			   (symbol-value (oref this symbol)))))

(defclass data-object-symbol-disabled (data-object-symbol)
  nil
  "This type of object uses (put ... 'disabled ...) for the given
symbol so that emacs will warn the user before they use it.")

(defmethod constructor :AFTER ((this data-object-symbol-disabled) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we want to disable"
  (dlg-init-symbol this)
  (oset this value (get (oref this symbol) 'disabled)))

(defclass data-object-command-option (data-object)
  ((command :initarg :command
	    :initform nil
	    :docstring "A string representing a command to execute in a .emacs file.
This command is interpreted by `read', then `eval'uated in the running
environment."
	    :protection private)
   (disable-command :initarg :disable-command
		    :initform nil
		    :docstring "A string which allows `command' to be undone."
		    :protection private)
   (protect :initarg :protect
	    :initform nil
	    :docstring "Some symbols you never want to write to a file."
	    :protection private))
  "This type of object will optionally add a command to a .emacs
file.  It will also run the command to turn a given feature on or off.")

(defmethod dlg-init-command ((this data-object-command-option))
  "Initialize the `command' field from name if applicable"
  (if (not (oref this command))
      (oset this command (object-name-string this))))

(defmethod constructor :AFTER ((this data-object-command-option) &rest fields)
  "This method is called during construction to initialize the value field
based upon the symbol we are editing"
  (dlg-init-command this)
  (if (not (oref this value))  ;; Allow caller to override this one.
      (oset this value (dlg-quick-find (oref this command) dlg-config-file))))

;; face specific data objects
;;
(defclass data-face-object (data-object)
  ((face :initarg :face
	 :initform 'default
	 :docstring "The face this data object maintains"
	 :protection private))
  "Takes a standard `data-object', and modifies it to be able to
maintain a face.  Has nothing special about it, and should not be
instantiated.  Use children of this class to modify specific features
of a face.")

(defclass data-face-foreground-object (data-face-object)
  nil
  "`data-face-object' which maintains the foreground")

(defclass data-face-background-object (data-face-object)
  nil
  "`data-face-object' which maintains the background")

(defclass data-face-underline-object (data-face-object)
  nil
  "`data-face-object' which maintains current underline state")

(defclass data-face-emphasis-object (data-face-object)
  nil
  "`data-face-object' which maintains current emphasis state. (bold & italic combos)")

;;;
;;; Implementation of above classes.
;;;

;; SYMBOL
(defmethod set-value :AFTER ((this data-object-symbol) value &optional setter)
  "When this data object's value is set, also set the value of it's
  symbol"
  (if (and (stringp value) (string= value "")) (setq value nil))
  ;; We only have to check again here just in case
  (if (not (equal value (symbol-value (oref this symbol))))
      (progn
	(if dlg-modify-running-environment (set (oref this symbol) value))
	(dlg-edit-config-file this))))

(defmethod dlg-edit-config-file-object ((this data-object-symbol))
  "Reads the currently stored config-file, and starts saving
the variables we are editing."
  (let ((val (oref this value)))
    (if (and (stringp val) (string= val ""))
	(setq val nil))
    (if (or (re-search-forward (concat 
				"(setq[ \t\n]+"
				(symbol-name (oref this symbol))
				"[ \t\n]+\\([A-Za-z0-9_]+\\)") nil t)
	    (re-search-forward (concat 
				"(setq[ \t\n]+"
				(symbol-name (oref this symbol))
				"[ \t\n]+\\(\"[^\"]*\"\\)") nil t))
	(progn
	  (goto-char (match-beginning 1))
	  (delete-region (point) (match-end 1))
	  (insert (format "%S" val)))
      (goto-char (point-max))
      (insert (format "\n(setq %s %S)"
		      (symbol-name (oref this symbol))
		      val))))
  (beginning-of-line)
  (point))

;; SYMBOL-STRING-TO-INT
(defmethod set-value :AFTER ((this data-object-symbol-string-to-int) value &optional setter)
  "When this data object's value is set, also set the value of it's
  symbol"
  (if (and dlg-modify-running-environment (stringp value))
      (let ((sv (string-to-int value)))
	(if (or (integerp sv) (oref this float-p))
	    (progn
	      (set (oref this symbol) (string-to-int value))
	      (dlg-edit-config-file this))
	  (ding t)
	  (message "Illegal value for symbol!")))))

(defmethod dlg-edit-config-file-object ((this data-object-symbol-string-to-int))
  "Reads the currently stored config-file, and starts saving
the variables we are editing."
  (if  (re-search-forward (concat 
			   "(setq[ \t\n]+"
			   (symbol-name (oref this symbol))
			   "[ \t\n]+\\(-?[.A-Za-z0-9_]+\\)") nil t)
      (progn
	(goto-char (match-beginning 1))
	(delete-region (point) (match-end 1))
	(insert (format "%S" (string-to-number (oref this value)))))
    (goto-char (point-max))
    (insert (format "\n(setq %s %S)"
		    (symbol-name (oref this symbol))
		    (string-to-int (oref this value)))))
  (beginning-of-line)
  (point))

;; SYMBOL-LIST-INDEX
(defmethod set-value :AFTER ((this data-object-symbol-list-index) value &optional setter)
  "When this data object's value is set, also set the value of it's
  symbol"
  (if (and dlg-modify-running-environment (numberp value))
      (set (oref this symbol) (eval (read (nth value (oref this string-list))))))
  (dlg-edit-config-file this))

(defmethod dlg-edit-config-file-object ((this data-object-symbol-list-index))
  "Reads the currently stored config-file, and starts saving
the variables we are editing."
  (if (or (re-search-forward (concat 
			      "(setq[ \t\n]+"
			      (symbol-name (oref this symbol))
			      "[ \t\n]+\\(['A-Za-z0-9_-]+\\)") nil t)
	  (re-search-forward (concat 
			      "(setq[ \t\n]+"
			      (symbol-name (oref this symbol))
			      "[ \t\n]+\\(\"[^\"]*\"\\)") nil t))
      (progn
	(goto-char (match-beginning 1))
	(delete-region (point) (match-end 1))
	(insert (format "%s" (nth (oref this value) (oref this string-list)))))
    (goto-char (point-max))
    (insert (format "\n(setq %s %s)"
		    (symbol-name (oref this symbol))
		    (nth (oref this value) (oref this string-list)))))
  (beginning-of-line)
  (point))

;; LISP-EXPRESSION
(defmethod set-value :AFTER ((this data-object-symbol-lisp-expression) value &optional setter)
  "When this data object's value is set, also set the value of it's
  symbol"
  (let ((ed t) (ex nil))
    (if (and dlg-modify-running-environment (stringp value))
	(progn
	  (condition-case nil
	      (setq ex (if (string= value "") nil (read value)))
	    (error (message "Invalid expression!")
		   (setq ed nil)))
	  (if ed (set (oref this symbol) ex))))
    (if ed (dlg-edit-config-file this))))

(defmethod dlg-edit-config-file-object ((this data-object-symbol-lisp-expression))
  "Reads the currently stored config-file, and starts saving
the variables we are editing."
  (let ((val (if (not (symbol-value (oref this symbol)))
		 "nil"
	       (concat 
		(if (listp (symbol-value (oref this symbol))) "'" "")
		(format "%s" (oref this value))))))
    (if (re-search-forward (concat 
			    "(setq[ \t\n]+"
			    (symbol-name (oref this symbol))
			    "\\([ \t\n]+\\)") nil t)
	(progn
	  (goto-char (match-end 1))
	  (delete-region (point)
			 (save-excursion (goto-char (match-beginning 0))
					 (forward-sexp 1) (forward-char -1)
					 (point)))
	  (insert val))
      (goto-char (point-max))
      (insert (format "\n(setq %s %s)"
		      (symbol-name (oref this symbol))
		      val)))
    (beginning-of-line)
    (point)))

;; SYMBOL-DEFAULT
(defmethod set-value :AFTER ((this data-object-symbol-default) value &optional setter)
  "When this data object value is set, set this as the new default."
  (set-default (oref this symbol) value)
  (dlg-edit-config-file this))

(defmethod dlg-edit-config-file-object ((this data-object-symbol-default))
  "Reads the currently stored config-file, and starts saving
the variables we are editing."
  (if (or (re-search-forward (concat 
			      "(setq-default[ \t\n]+"
			      (symbol-name (oref this symbol))
			      "[ \t\n]+\\([A-Za-z0-9_]+\\)") nil t)
	  (re-search-forward (concat 
			      "(setq-default[ \t\n]+"
			      (symbol-name (oref this symbol))
			      "[ \t\n]+\\(\"[^\"]*\"\\)") nil t))
      (progn
	(goto-char (match-beginning 1))
	(delete-region (point) (match-end 1))
	(insert (format "%S" (oref this value))))
    (goto-char (point-max))
    (insert (format "\n(setq-default %s %S)"
		    (symbol-name (oref this symbol))
		    (oref this value))))
  (beginning-of-line)
  (point))

;; SYMBOL-FEATURE
(defmethod set-value :AFTER ((this data-object-symbol-feature) value &optional setter)
  "When this data object value is set, set this as the new default."
  (if value
      (require (oref this symbol))
    (if (oref this unload-commands)
	(let* ((file (feature-file (oref this symbol)))
	       (dependents (delete file (copy-sequence (file-dependents file)))))
	  (eval (oref this unload-commands))
	  (if dependents
	      (message "cannot unload: %s depends on that feature" dependents)
	    (unload-feature (oref this symbol))))
      (message "You shouldn't unload this feature")))
  (dlg-edit-config-file this))

(defmethod dlg-edit-config-file-object ((this data-object-symbol-feature))
  "Reads the currently stored config-file, and starts saving
the features we are editing."
  (if  (re-search-forward (concat 
			   "\\(;*\\)(require[ \t\n]+'"
			   (symbol-name (oref this symbol))) nil t)
      (progn
	(goto-char (match-beginning 1))
	(replace-match (if (oref this value) "" ";;") nil nil nil 1))
    (goto-char (point-max))
    (if (oref this value)
	(insert "\n(require '" (symbol-name (oref this symbol)) ")")))
  (beginning-of-line)
  (point))

;; SYMBOL-HOOK
(defmethod set-value :AFTER ((this data-object-symbol-hook) value &optional setter)
  "When this data object value is set, set this as the new default."
  (if value
      (add-hook (oref this symbol) (read (oref this command)))
    (remove-hook (oref this symbol) (read (oref this command))))
  (dlg-edit-config-file this))

(defmethod dlg-edit-config-file-object ((this data-object-symbol-hook))
  "Reads the currently stored config-file, and starts saving
the hooks we are editing."
  (if  (re-search-forward (concat 
			   "\\(;*\\)(add-hook[ \t\n]+'"
			   (symbol-name (oref this symbol))
			   "\\s-+'"
			   (regexp-quote (oref this command))) nil t)
      (progn
	(goto-char (match-beginning 1))
	(replace-match (if (oref this value) "" ";;") nil nil nil 1))
    (goto-char (point-max))
    (if (oref this value)
	(insert "\n(add-hook '" (symbol-name (oref this symbol))
		" '" (oref this command) ")")))
  (beginning-of-line)
  (point))

;; SYMBOL-DISABLED
(defmethod set-value :AFTER ((this data-object-symbol-disabled) value &optional setter)
  "When this data object value is set, set this as the new default."
  (if dlg-modify-running-environment (put (oref this symbol) 'disabled value))
  (dlg-edit-config-file this))

(defmethod dlg-edit-config-file-object ((this data-object-symbol-disabled))
  "Reads the currently stored config-file, and starts saving
the variables we are editing."
  (if (re-search-forward (concat 
			  "(put[ \t\n]+'"
			  (symbol-name (oref this symbol))
			  "[ \t\n]+'disabled[ \t\n]+\\([A-Za-z0-9_]+\\)")
			 nil t)
      (progn
	(goto-char (match-beginning 1))
	(delete-region (point) (match-end 1))
	(insert (format "%S" (oref this value))))
    (goto-char (point-max))
    (insert (format "\n(put '%s 'disabled %S)"
		    (symbol-name (oref this symbol))
		    (oref this value))))
  (beginning-of-line)
  (point))

;; COMMAND-OPTION
(defmethod set-value :AFTER ((this data-object-command-option) value &optional setter)
  "When this data object value is set, set this as the new default."
  (if (oref this disable-command)
      (cond (value (eval (read (oref this command))))
	     (t (eval (read (oref this disable-command)))))
    (cond (value
	   (message "I can't disable this, so I won't enable it either"))
	  (t (message "I can't disable this command."))))
  (dlg-edit-config-file this))

(defmethod dlg-edit-config-file-object ((this data-object-command-option))
  "Reads the currently stored config-file, and enters the command here"
  (if (re-search-forward (concat "^\\(;*\\)\\("
				 (oref this command)
				 "\\)")
			 nil t)
      (progn
	(goto-char (match-beginning 1))
	(delete-region (point) (match-end 1))
	(insert (if (oref this value) "" ";;")))
    (goto-char (point-max))
    (if (oref this value)
	(insert "\n" (oref this command))))
  (beginning-of-line)
  (point))

;; FACE-FOREGROUND
(defmethod set-value :BEFORE ((this data-face-foreground-object) value &optional setter)
  "Set the value of a `data-face-foreground-object' and modifies said face."
  (if (and (stringp value) (stringp (get-value this)) 
	   (not (string= value (get-value this)))
	   (x-color-defined-p value))
      (set-face-foreground (oref this face) value)
    (if (string= value "")
	(set-face-foreground (oref this face) nil)))
  (if (stringp value)
      (dlg-edit-xdefaults this "attributeForeground" value)))

;; FACE-BACKGROUND
(defmethod set-value :BEFORE ((this data-face-background-object) value &optional setter)
  "Set the value of a `data-face-foreground-object' and modifies said face."
  (if (and (stringp value) (stringp (get-value this)) 
	   (not (string= value (get-value this)))
	   (x-color-defined-p value))
      (set-face-background (oref this face) value)
    (if (string= value "")
	(set-face-background (oref this face) nil)))
  (if (stringp value)
      (dlg-edit-xdefaults this "attributeBackground" value)))

;; FACE-UNDERLINE
(defmethod set-value :BEFORE ((this data-face-underline-object) value &optional setter)
  "Sets the underline attribute of a face"
  (if (and (or (eq value nil) (eq value t))
	   (or (eq (get-value this) nil) (eq (get-value this) t))
	   (not (eq value (get-value this))))
      (progn
	(set-face-underline-p (oref this face) (not (get-value this)))
	(dlg-edit-xdefaults this "attributeUnderline" 
			    (if value "true" "false")))))

;; FACE-EMPHISIS
(defmethod set-value :BEFORE ((this data-face-emphasis-object) value &optional setter)
  "Set the value of `data-face-foreground-object' and modify said face."
  (if (numberp value)
      (let ((f (oref this face)))
	(cond ((= value 0)
	       (make-face-unbold f)
	       (make-face-unitalic f)
	       (dlg-edit-xdefaults this "attributeFont"
				   "-*-*-medium-r-*-*-*-*-*-*-*-*-*-*"))
	      ((= value 1)
	       (make-face-bold f)
	       (make-face-unitalic f)
	       (dlg-edit-xdefaults this "attributeFont"
				   "-*-*-bold-r-*-*-*-*-*-*-*-*-*-*"))
	      ((= value 2)
	       (make-face-unbold f)
	       (make-face-italic f)
	       (dlg-edit-xdefaults this "attributeFont"
				   "-*-*-medium-o-*-*-*-*-*-*-*-*-*-*"))
	      ((= value 3)
	       (make-face-bold f)
	       (make-face-italic f)
	       (dlg-edit-xdefaults this "attributeFont"
				   "-*-*-bold-o-*-*-*-*-*-*-*-*-*-*"))))))

;; XDEFAULT-EDIT (for above 3)
(defmethod dlg-edit-xdefaults ((this data-face-object) token val)
  "Open and edit the chosen Xdefaults file and store this face
information there so that faces aren't automatically created at
startup (thus creating a real slow load)"
  (if (and dlg-auto-edit dlg-xdefaults-file)
      (let ((ob (current-buffer))
	    nb pnt)
	(set-buffer (find-file-noselect dlg-xdefaults-file))
	(setq nb (current-buffer))
	(goto-char (point-min))
	(if (re-search-forward (concat 
				"emacs.*" 
				(symbol-name (oref this face))
				"." token ":"
				"\\([ \t]+\\)\\([^\n]+\\)?$") nil t)
	    (progn
	      (goto-char (match-end 1))
	      (if (match-beginning 2)
		  (delete-region (point) (match-end 2)))
	      (insert val))
	  (goto-char (point-max))
	  (insert "\nemacs*" (symbol-name (oref this face))
		  "." token ":\t" val))
	(beginning-of-line)
	(setq pnt (point))
	(set-buffer ob)
	(dlg-show-an-edit nb pnt))))

;;; end of lisp
(provide 'dlg-class)