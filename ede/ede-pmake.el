;;; ede-pmake.el --- EDE Generic Project Makefile code generator.

;;;  Copyright (C) 1998, 1999, 2000  Eric M. Ludlam

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
;; Code generator for Makefiles.

(eval-and-compile 
  (require 'ede-proj)
  (require 'ede-proj-obj))

;;; Code:
(defmethod ede-proj-makefile-create ((this ede-proj-project) mfilename)
  "Create a Makefile for all Makefile targets in THIS.
MFILENAME is the makefile to generate."
  (let ((mt nil) tmp
	(isdist (string= mfilename (ede-proj-dist-makefile this)))
	(depth 0)
	(tmp this)
	(have-cfiles
	 (with-slots (targets) this
	   (while (and targets
		       (not
			(obj-of-class-p
			 (car targets)
			 'ede-proj-target-makefile-objectcode)))
	     (setq targets (cdr targets)))
	   targets))
	(have-libtool (object-assoc t 'libtool (oref this targets)))
	)
    ;; Find out how deep this project is.
    (while (ede-parent-project tmp)
      (setq depth (1+ depth)
	    tmp (ede-parent-project tmp)))
    ;; Collect the targets that belong in a makefile.
    (with-slots (targets) this
      (while targets
	(if (and (obj-of-class-p (car targets) 'ede-proj-target-makefile)
		 (string= (oref (car targets) makefile) mfilename))
	    (setq mt (cons (car targets) mt)))
	(setq targets (cdr targets))))
    ;; Fix the order so things compile in the right direction.
    (setq mt (nreverse mt))
    (save-excursion
      (set-buffer (find-file-noselect mfilename))
      (erase-buffer)
      ;; Insert a giant pile of stuff that is common between
      ;; one of our Makefiles, and a Makefile.in
      (insert
       "# Automatically Generated " (file-name-nondirectory mfilename)
       " by EDE.\n"
       "# For use with: "
       (with-slots (makefile-type) this
	 (cond ((eq makefile-type 'Makefile) "make")
	       ((eq makefile-type 'Makefile.in) "autoconf")
	       ((eq makefile-type 'Makefile.am) "automake")
	       (t (error ":makefile-type in project invalid"))))
       "\n#\n"
       "# DO NOT MODIFY THIS FILE OR YOUR CHANGES MAY BE LOST.\n"
       "# EDE is the Emacs Development Environment.\n"
       "# http://www.ultranet.com/~zappo/ede.shtml\n"
       "# \n")
      (ede-proj-makefile-insert-variables this)
      ;; Space
      (insert "\n")
      ;; Distribution variables
      (if isdist
	  (setq tmp (oref this targets))
	(setq tmp mt))
      (while tmp
	(ede-proj-makefile-insert-variables (car tmp))
	(setq tmp (cdr tmp)))
      (cond
       ((eq (oref this makefile-type) 'Makefile)
	(let ((df (apply 'append
			 (mapcar (lambda (tg)
				   (ede-proj-makefile-dependency-files tg))
				 mt))))
	  ;; Only add the distribution stuff in when depth != 0
	  (if (= depth 0)
	      (insert "VERSION=" (oref this version) "\n"
		      "DISTDIR=" (oref this name) "-$(VERSION)\n"))
	  ;; Some built in variables for C code
	  (if df
	      (let ((tc depth))
		(insert "top_builddir = ")
		(while (/= 0 tc)
		  (setq tc (1- tc))
		  (insert "..")
		  (if (/= tc 0) (insert "/")))
		(insert "\n")
		(if have-cfiles
		    (insert
		     ;;"LIBTOOL = $(SHELL) $(top_builddir)/libtool\n"
		     "COMPILE = $(CC) $(DEFS) $(INCLUDES) $(CPPFLAGS) "
		     "$(CFLAGS)\n"
		     "LINK = $(CC) $(CFLAGS) $(LDFLAGS) -o $@\n")
		  (if have-libtool
		      (insert
		       "LIBTOOL = $(SHELL) libtool\n"
		       "LTCOMPILE = $(LIBTOOL) --mode=compile $(CC) $(DEFS) "
		       "$(INCLUDES) $(CPPFLAGS) $(CFLAGS)\n"
		       "LTLINK = $(LIBTOOL) --mode=link $(CC) $(CFLAGS) "
		       "$(LDFLAGS) -o $@\n"))
		  )))
	  (insert "\n")
	  ;; Create a variable with all the dependency files to include
	  ;; These methods borrowed from automake.
	  (if df
	      (progn
		(insert "DEP_FILES="
			(mapconcat (lambda (f)
				     (concat ".deps/"
					     (file-name-nondirectory
					      (file-name-sans-extension
					       f)) ".P"))
				   df " "))))
	  ;; The all target
	  (setq tmp mt)
	  (insert "\n\nall:")
	  (while tmp
	    (if (oref (car tmp) partofall)
		;; Only insert this rule if it is a part of ALL.
		(insert " " (oref (car tmp) name)))
	    (setq tmp (cdr tmp)))
	  (insert "\n\n")
	  ;; Some C inference rules
	  ;; Dependency rules borrowed from automake.
	  (if df
	      (progn
		(if (oref this automatic-dependencies)
		    (insert "DEPS_MAGIC := $(shell mkdir .deps > /dev/null "
			    "2>&1 || :)\n"
			    "-include $(DEP_FILES)\n\n"))
		(insert ;; These C to O rules create dependencies
		 "%.o: %.c\n"
		 "\t@echo '$(COMPILE) -c $<'; \\\n"
		 "\t$(COMPILE)"
		 (if (oref this automatic-dependencies)
		     " -Wp,-MD,.deps/$(*F).P"
		   "")
		 " -c $<\n\n")
		(if have-libtool
		    (insert ;; These C to shared o rules create pic code.
		     "%.lo: %.c\n"
		     "\t@echo '$(LTCOMPILE) -c $<'; \\\n"
		     "\t$(LTCOMPILE) -Wp,-MD,.deps/$(*F).p -c $<\n"
		     "\t@-sed -e 's/^\([^:]*\)\.o:/\1.lo \1.o:/' \\\n"
		     "\t      < .deps/$(*F).p > .deps/$(*F).P\n"
		     "\t@-rm -f .deps/$(*F).p\n\n"))
		))
	  ;; General makefile rules stored in the object
	  (ede-proj-makefile-insert-rules this)
	  (setq tmp mt)
	  (while tmp
	    (ede-proj-makefile-insert-rules (car tmp))
	    (setq tmp (cdr tmp)))
	  (if isdist
	      (let ((junk (ede-proj-makefile-garbage-patterns this)))
		;; Build CLEAN, DIST, TAG, and other rules here.
		(if junk
		    (insert "\nclean:\n"
			    "\trm -f "
			    (mapconcat (lambda (c) c) junk " ")
			    "\n\n"))
		(insert "\ndist:\n"
			"\trm -rf $(DISTDIR)\n"
			"\tmkdir $(DISTDIR)\n")
		(setq tmp (oref this targets))
		(insert "\tcp")
		(while tmp (insert " $(" (ede-proj-makefile-sourcevar (car tmp))
				   ")")
		       (setq tmp (cdr tmp)))
		(insert " $(ede_FILES) $(DISTDIR)\n"
			"\ttar -cvzf $(DISTDIR).tar.gz $(DISTDIR)\n"
			"\trm -rf $(DISTDIR)\n\n")
		(ede-proj-makefile-tags this mt)
		;; Add rules here for subprojects!
		(insert mfilename ": "
			(file-name-nondirectory (oref this file)) "\n"
			"\t@echo Makefile is out of date!  "
			"It needs to be regenerated by EDE.\n"
			"\t@false\n\n"
			"\n\n# End of Makefile\n"))))
	(save-buffer))
       ((eq (oref this makefile-type) 'Makefile.in)
	(error "Makefile.in is not supported"))
       ((eq (oref this makefile-type) 'Makefile.am)
	(require 'ede-pconf)
	;; Suprisingly, an automake file doesn't take much more.  Lets
	;; just slip in the rules the user specifically requested,
	;; and go on our merry way!
	(ede-proj-makefile-insert-user-rules this)
	(insert "\n# End of Makefile.am\n")
	(save-buffer)
	)
       (t (error "Unknown makefile type when generating Makefile")))
      ;; Put the cursor in a nice place
      (goto-char (point-min)))))

;;; SOURCE VARIABLE NAME CONSTRUCTION
;;
(defun ede-pmake-varname (obj)
  "Convert OBJ into a variable name name, which converts .  to _."
  (let ((name (oref obj name)))
    (while (string-match "\\." name)
      (setq name (replace-match "_" nil t name)))
    name))

(defmethod ede-proj-makefile-sourcevar ((this ede-proj-target))
  "Return the variable name for THIS's sources."
  (concat (ede-pmake-varname this) "_YOU_FOUND_A_BUG"))

;;; DEPENDENCY FILE GENERATOR LISTS
;;
(defmethod ede-proj-makefile-dependency-files ((this ede-proj-target))
  "Return a list of source files to convert to dependencies.
Argument THIS is the target to get sources from."
  nil)

;;; GENERIC VARIABLES
;;
(defmethod ede-proj-makefile-configuration-variables ((this ede-proj-project)
						      configuration)
  "Return a list of configuration variables from THIS.
Use CONFIGURATION as the current configuration to query."
  (cdr (assoc configuration (oref this configuration-variables))))

(defmethod ede-proj-makefile-insert-variables ((this ede-proj-project))
  "Insert variables needed by target THIS."
  (let ((conf-table (ede-proj-makefile-configuration-variables
		     this (oref this configuration-default)))
	(conf-done nil))
    ;; Insert all variables, and augment them with details from
    ;; the current configuration.
    (mapcar (lambda (c)
	      (insert (car c) "=")
	      (if (assoc (car c) conf-table)
		  (progn
		    (insert (cdr (assoc (car c) conf-table)) " ")
		    (setq conf-done (cons (car c) conf-done))))
	      (insert (cdr c) "\n"))
	    (oref this variables))
    ;; Add in all variables from the configuration not allready covered.
    (mapcar (lambda (c)
	      (if (member (car c) conf-done)
		  nil
		(insert (car c) "=" (cdr c) "\n")))
	    conf-table))
  (insert "\nede_FILES=" (file-name-nondirectory (oref this file)) " "
	  (ede-proj-dist-makefile this) "\n"))

(defmethod ede-proj-makefile-insert-variables ((this ede-proj-target) &optional
					       moresource)
  "Insert variables needed by target THIS.
Optional argument MORESOURCE is a list of additional sources to add to the
sources variable."
  (insert (ede-proj-makefile-sourcevar this) "="
	  (mapconcat (lambda (a) a) (oref this source) " "))
  (if moresource
      (insert " \\\n   " (mapconcat (lambda (a) a) moresource " ") ""))
  (insert "\n"))

;;; GARBAGE PATTERNS
;;
(defmethod ede-proj-makefile-garbage-patterns ((this ede-proj-project))
  "Return a list of patterns that are considred garbage to THIS.
These are removed with make clean."
  (let ((mc (mapcar (lambda (c) (ede-proj-makefile-garbage-patterns c))
		    (oref this targets)))
	(uniq nil))
    (setq mc (sort (apply 'append mc) 'string<))
    ;; Filter out duplicates from the targets.
    (while mc
      (if (and (car uniq) (string= (car uniq) (car mc)))
	  nil
	(setq uniq (cons (car mc) uniq)))
      (setq mc (cdr mc)))
    (nreverse uniq)))

(defmethod ede-proj-makefile-garbage-patterns ((this ede-proj-target))
  "Return a list of patterns that are considred garbage to THIS.
These are removed with make clean."
  nil)

;;; RULES
;;
(defmethod ede-proj-makefile-insert-rules ((this ede-proj-project))
  "Insert rules needed by THIS target."
  (mapcar 'ede-proj-makefile-insert-rules (oref this inference-rules)))

(defmethod ede-proj-makefile-insert-rules ((this ede-proj-target))
  "Insert rules needed by THIS target."
  (mapcar 'ede-proj-makefile-insert-rules (oref this rules)))

(defmethod ede-proj-makefile-insert-user-rules ((this ede-proj-project))
  "Insert user specified rules needed by THIS target.
This is different from `ede-proj-makefile-insert-rules' in that this
function won't create the building rules which are auto created with
automake."
  (mapcar 'ede-proj-makefile-insert-user-rules (oref this inference-rules)))

(defmethod ede-proj-makefile-insert-user-rules ((this ede-proj-target))
  "Insert user specified rules needed by THIS target."
  (mapcar 'ede-proj-makefile-insert-rules (oref this rules)))

(defmethod ede-proj-makefile-insert-rules ((this ede-makefile-rule))
  "Insert rules needed for THIS rule object."
  (if (oref this phony) (insert ".PHONY: (oref this target)\n"))
  (insert (oref this target) ": " (oref this dependencies) "\n\t"
	  (mapconcat (lambda (c) c) (oref this rules) "\n\t")
	  "\n\n"))

;; Tags
(defmethod ede-proj-makefile-tags ((this ede-proj-project) targets)
  "Insert into the current location rules to make recursive TAGS files.
Argument THIS is the project to create tags for.
Argument TARGETS are the targets we should depend on for TAGS."
  (insert "tags: ")
  (let ((tg targets))
    ;; Loop over all source variables and insert them
    (while tg
      (insert "$(" (ede-proj-makefile-sourcevar (car tg)) ") ")
      (setq tg (cdr tg)))
    (if targets
	(insert "\n\tetags $^\n"))
    ;; Now recurse into all subprojects
    (setq tg (oref this subproj))
    (while tg
      (insert "\tcd " (file-name-directory (oref (car tg) file)) "; make $@\n")
      (setq tg (cdr tg)))
    (insert "\n")))


(provide 'ede-pmake)

;;; ede-pmake.el ends here