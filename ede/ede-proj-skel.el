;;; ede-proj-%NAME%.el --- EDE Generic Project ...

;;;  Copyright (C) 1999, 2000  Eric M. Ludlam

;; Author: Eric M. Ludlam <zappo@gnu.org>
;; Keywords: project, make
;; RCS: $Id$

;; This file is NOT part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; Handles ...
;; in an EDE Project file.

;; To use this skeleton file, replace all occurances of words in %PERCENT%
;; with the proper named you wish to use.
;;
;; If a function is commented out, then you probably don't need to
;; override it.  If it is not commented out, you probably need it, but
;; there is no requirement that you impelement it.

;;; Code:
(defclass ede-proj-target-%NAME% (ede-proj-target-%PARENT%)
  (;; Use these two items to modify the target specificy menu.
   ;;(menu :initform nil)
   ;;(keybindings :initform nil)
   ;; Add your specialized fields here
   )
  "Class for ....")

;;; EIEIO maintenance methods
;;

;; The chances of needing to implement this are near zero, but if
;; you need to perform some action when the user hits "apply", this
;; is the way to do it.
;;(defmethod eieio-done-customizing ((target ede-proj-target-%NAME%))
;;  "Called when a user finishes customizing this target."
;;  (call-next-method)
;;  (%do-my-stuff%))

;;; EDE target smarts methods
;;

;; This function lets you define what types of files you want to claim.
;; Defining this provides a convenience for uses by not offering your
;; target type for files you don't care about.
(defmethod ede-want-file-p ((obj ede-proj-target-%NAME%) file)
  "Return t if OBJ wants to own FILE."
  (string match "\\.%MYEXTENSION%$" file))

;; This function lets you take files being added to your target and
;; stick them into different slots.  This is useful if you have
;; compilable sources and auxiliary files related to compilation that
;; do not directly get compiled.  (Although in that case, you probably
;; want to extend `ede-proj-target-makefile-objectcode'
;;(defmethod project-add-file ((this ede-proj-target-%NAME%) file)
;;  "Add to target THIS the current buffer represented as FILE."
;;  (if (not (%do-something-special%))
;;	(call-next-method)
;;    (%do-my-special-stuff%)))

;; Reverse tactic as above.
;;(defmethod project-remove-file  ((target ede-proj-target-makefile-objectcode)
;;				  file)
;;  "For TARGET, remove FILE."
;;  (if (not (%do-something-special%))
;;	(call-next-method)
;;    (%do-my-special-stuff%)))

;; Provides a simple hook to do cleanup work if this target is deleted
;; from a project.
;;(defmethod project-delete-target ((this ede-proj-target-%NAME%))
;;  "Delete THIS target from its parent project."
;;  (%cleanup%)
;;  (call-next-method))

;;; EDE target do user stuff methods
;;

;; This method lets you control what commands are run when a user
;; wants to compile your target.  If you inherit from a makefile
;; target, then you can use "call-next-method" with a new
;; command if needed, or just comment this out.
;;(defmethod project-compile-target ((obj ede-proj-target-%NAME%)
;;				     &optional command)
;;  "Compile the current target OBJ.
;;Argument COMMAND is the command to use for compiling the target
;;if the user, or child class wishes to modify it."
;;  (or (call-next-method %"new command string"%)
;;      (project-compile-project (ede-current-project) %"some command"%)
;;	(%do-stuff%)))

;; This method lets you define how the target reacts to a debug
;; command.  Comment this out if you do not support a debugger.
;; If you don't support debugging, don't forget to also remove
;; any specialized keybindings and menu items in the class definition.
(defmethod project-debug-target ((obj ede-proj-target-%NAME%))
  "Run the current target OBJ in an debugger."
  (%do-stuff%))

;;; EDE project makefile code generation methods
;;

;; The name of the variable used in a Makefile for your main sources.
;; Attempt to use automake conventions so that your target is easy to
;; port when/if automake is supported by ede-proj.
(defmethod ede-proj-makefile-sourcevar ((this ede-proj-target-%NAME%))
  "Return the variable name for THIS's sources."
  (concat (ede-pmake-varname this) "_%MAKEVARIABLECONVENTION%"))

;; Your main target in the Makefile may depend on additional source
;; dependencies.  Use this to add more stuff.
;;(defmethod ede-proj-makefile-dependency-files ((this ede-proj-target-%NAME%))
;;  "Return a list of source files to convert to dependencies.
;;Argument THIS is the target to get sources from."
;;  (append (call-next-method) (%get-more-dependencies%)))

;; This is a clever way of packing more files into your main source
;; variable.  Only works if your "next" method is ede-proj-target.
;;(defmethod ede-proj-makefile-insert-variables ((this ede-proj-target-%NAME%))
;;  "Insert variables needed by target THIS."
;;  (call-next-method this (oref this headers))

;; This method adds a list of new shell file patterns to a clean rule
;; which deletes object and temp files.
(defmethod ede-proj-makefile-garbage-patterns ((this ede-proj-target-%NAME%))
  "Return a list of patterns that are considered garbage by THIS."
  '("*.%foo%"))

;; This is one of the most important methods which defines rules to
;; place into a makefile for building.  If you inherit from
;; `ede-proj-target-makefile', then this is the primary build
;; mechanism.  If you have an emacs-centric build method, then this
;; is a secondary build method (for a distribution, for example.)
;; It could also contain auxiliary make commands in addition to
;; the main rules needed.
(defmethod ede-proj-makefile-insert-rules ((this ede-proj-target-%NAME%))
  "Insert rules needed by THIS target."
  (call-next-method) ;; catch user-rules case.
  (insert ... ;; Code to create a rule for THIS.
	  ))

;; This function us used to find a header file in which prototypes from
;; BUFFER go.  This is used by advanced features for which this type
;; of behavior is useful.  This feature is used mainly by tools
;; using the SEMANTIC BOVINATOR http://www.ultranet.com/~zappo/semantic.shtml
;; to perform advanced language specific actions.
(defmethod ede-buffer-header-file((this ede-proj-target-%NAME%) buffer)
  "Return the name of a file in which prototypes go."
  (oref this ...))

;;; EDE speedbar browsing enhancements
;;
;; In general, none of these need to be defined unless your have slots
;; for auxiliary source files.

;; This lets you add buttons of things your target contains which may
;; not be shown be default.
;;
;; You will need to tweek the functions used when clicking on the
;; expand icon (maybe) and the item name (maybe). Leave those alone
;; if they are simple source files.
;;(defmethod eieio-speedbar-child-make-tag-lines ((this ede-proj-target-%NAME%))
;;  "Create buttons for items belonging to THIS."
;;  (call-next-method) ;; get the default buttons inserted.
;;  (with-slots (%SOME-SLOTS%) this
;;    (mapcar (lambda (car)
;;		(speedbar-make-tag-line 'bracket ?+
;;					'ede-tag-file
;;					(concat (oref this :path) car)
;;					car
;;					'ede-file-find
;;					(concat (oref this :path) car)
;;					'speedbar-file-face depth))
;;	      %A-SLOT%)))

(provide 'ede-proj-%NAME%)

;;; ede-proj-%NAME%.el ends here
