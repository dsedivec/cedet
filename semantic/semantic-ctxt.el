;;; semantic-ctxt.el --- Context calculations for Semantic tools.

;;; Copyright (C) 1999, 2000, 2001 Eric M. Ludlam

;; Author: Eric M. Ludlam <zappo@gnu.org>
;; Keywords: syntax
;; X-RCS: $Id$

;; This file is not part of GNU Emacs.

;; Semantic is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This software is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; Semantic, as a tool, provides a nice list of searchable tokens.
;; That information can provide some very accurate answers if the current
;; context of a position is known.
;;
;; This library provides the hooks needed for a language to specify how
;; the current context is calculated.
;;
(require 'semantic)
(eval-when-compile (require 'semanticdb))

;;; Code:
;;
(defvar semantic-command-separation-character
 ";"
  "String which indicates the end of a command.
Used for identifying the end of a single command.")
(make-variable-buffer-local 'semantic-command-separation-character)

(defvar semantic-function-argument-separation-character
 ","
  "String which indicates the end of a command.
Used for identifying the end of a single command.")
(make-variable-buffer-local 'semantic-function-argument-separation-character)

;;; Local variable parsing.
;;
(defun semantic-up-context (&optional point)
  "Move point up one context from POINT.
Return non-nil if there are no more context levels.
Overloaded functions using `up-context' take no parameters."
  (if point (goto-char (point)))
  (let ((s (semantic-fetch-overload 'up-context)))
    (if s (funcall s)
      (semantic-up-context-default)
      )))

(defun semantic-up-context-default ()
  "Move the point up and out one context level.
Works with languages that use parenthetical grouping."
  ;; By default, assume that the language uses some form of parenthetical
  ;; do dads for their context.
  (condition-case nil
      (progn
	(up-list -1)
	nil)
    (error t)))

(defun semantic-beginning-of-context (&optional point)
  "Move POINT to the beginning of the current context.
Return non-nil if there is no upper context.
The default behavior uses `semantic-up-context'.  It can
be overridden with `beginning-of-context'."
  (if point (goto-char (point)))
  (let ((s (semantic-fetch-overload 'beginning-of-context)))
    (if s (funcall s)
      (semantic-beginning-of-context-default)
      )))

(defun semantic-beginning-of-context-default ()
  "Move point to the beginning of the current context via parenthisis.
Return non-nil if there is no upper context."
  (if (semantic-up-context)
      t
    (forward-char 1)
    nil))

(defun semantic-end-of-context (&optional point)
  "Move POINT to the end of the current context.
Return non-nil if there is no upper context.
Be default, this uses `semantic-up-context', and assumes parenthetical
block delimiters.  This can be overridden with `end-of-context'."
  (if point (goto-char (point)))
  (let ((s (semantic-fetch-overload 'end-of-context)))
    (if s (funcall s)
      (semantic-end-of-context-default)
      )))

(defun semantic-end-of-context-default ()
  "Move point to the end of the current context via parenthisis.
Return non-nil if there is no upper context."
  (if (semantic-up-context)
      t
    ;; Go over the list, and back over the end parenthisis.
    (forward-sexp 1)
    (forward-char -1)
    nil))

(defun semantic-get-local-variables (&optional point)
  "Get the local variables based on POINT's context.
Local variables are returned in Semantic token format.
Be default, this calculates the current bounds using context blocks
navigation, then uses the parser with `bovine-inner-scope' to
parse tokens at the beginning of the context.
This can be overriden with `get-local-variables'."
  (save-excursion
    (if point (goto-char (point)))
    (let ((s (semantic-fetch-overload 'get-local-variables))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-get-local-variables-default)
	))))

(defun semantic-get-local-variables-default ()
  "Get local values from a specific context.
Uses the bovinator with the special top-symbol `bovine-inner-scope'
to collect tokens, such as local variables or prototypes."
  (working-status-forms "Local" "done"
    (let ((semantic-bovination-working-type nil))
      (semantic-bovinate-region-until-error
       (point) (save-excursion (semantic-end-of-context) (point))
       'bovine-inner-scope))))

(defun semantic-get-local-arguments (&optional point)
  "Get arguments (variables) from the current context at POINT.
Parameters are available if the point is in a function or method.
This function returns a list of tokens.  If the local token returns
just a list of strings, then this function will convert them to tokens.
Part of this behavior can be overridden with `get-local-arguments'."
  (if point (goto-char (point)))
  (let* ((s (semantic-fetch-overload 'get-local-arguments))
	 (case-fold-search semantic-case-fold)
	 (params (if s (funcall s)
		   (semantic-get-local-arguments-default)))
	 (rparams nil))
    ;; convert unsafe params to the right thing.
    (while params
      (setq rparams
	    (cons (cond ((semantic-token-p (car params))
			 (car params))
			((stringp (car params))
			 (list (car params) 'variable))
			(t (error "Unknown parameter element")))
		  rparams)
	    params (cdr params)))
    (nreverse rparams)))

(defun semantic-get-local-arguments-default ()
  "Get arguments (variables) from the current context.
Parameters are available if the point is in a function or method."
  (let ((tok (semantic-current-nonterminal)))
    (if (and tok (eq (semantic-token-token tok) 'function))
	(semantic-token-function-args tok))))

(defun semantic-get-all-local-variables (&optional point)
  "Get all local variables for this context, and parent contexts.
Local variables are returned in Semantic token format.
Be default, this gets local variables, and local arguments.
This can be overridden with `get-all-local-variables'.
Optional argument POINT is the location to start getting the variables from."
  (save-excursion
    (if point (goto-char (point)))
    (let ((s (semantic-fetch-overload 'get-all-local-variables))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-get-all-local-variables-default)
	))))

(defun semantic-get-all-local-variables-default ()
  "Get all local variables for this context, and parent contexts.
Local variables are returned in Semantic token format.
Uses `semantic-beginning-of-context', `semantic-end-of-context',
`semantic-up-context', and `semantic-get-local-variables' to collect
this information."
  (let ((varlist nil)
	(sublist nil))
    (save-excursion
      (while (not (semantic-beginning-of-context))
	;; Get the local variables
	(setq sublist (semantic-get-local-variables))
	(if sublist
	    (setq varlist (cons sublist varlist)))
	;; Move out of this context to the next.
	(semantic-up-context)))
    ;; arguments to some local function
    (setq sublist (semantic-get-local-arguments))
    (if sublist (setq varlist (cons sublist varlist)))
    ;; fix er up.
    (nreverse varlist)))

;;; Local context parsing
;;
;; Context parsing assumes a series of language independent commonalities.
;; These terms are used to describe those contexts:
;;
;; command      - One command in the language.
;; symbol       - The symbol the cursor is on.
;;                This would include a series of type/field when applicable.
;; assignment   - The variable currently being assigned to
;; function     - The function call the cursor is on/in
;; argument     - The index to the argument the cursor is on.
;;
;;
(defun semantic-end-of-command ()
  "Move to the end of the current command.
Be default, uses `semantic-command-separation-character'.
Override with `end-of-command'."
    (let ((s (semantic-fetch-overload 'end-of-command))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-end-of-command-default)
	)))

(defun semantic-end-of-command-default ()
  "Move to the beginning of the current command.
Depends on `semantic-command-separation-character' to find the
beginning and end of a command."
  (let ((nt (semantic-current-nonterminal)))
    (if (re-search-forward (regexp-quote semantic-command-separation-character)
			   (if nt (semantic-token-end nt))
			   t)
	(forward-char -1))))

(defun semantic-beginning-of-command ()
  "Move to the beginning of the current command.
Be default, users `semantic-command-separation-character'.
Override with `beginning-of-command'."
    (let ((s (semantic-fetch-overload 'beginning-of-command))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-beginning-of-command-default)
	)))

(defun semantic-beginning-of-command-default ()
  "Move to the beginning of the current command.
Depends on `semantic-command-separation-character' to find the
beginning and end of a command."
  (let ((nt (semantic-current-nonterminal)))
    (if (or
	 (and nt
	      (re-search-backward (regexp-quote semantic-command-separation-character)
				  (semantic-token-start nt)
				  t))
	 (re-search-backward (regexp-quote semantic-command-separation-character)
			     nil
			     t))
	(progn
	  ;; Here is a speedy way to skip over junk between the end of
	  ;; the last command, and the beginning of the next.
	  (forward-word 1)
	  (forward-word -1)))))

(defun semantic-ctxt-current-symbol (&optional point)
  "Return the current symbol the cursor is on at POINT in a list.
This will include a list of type/field names when applicable.
This can be overridden using `ctxt-current-symbol'."
    (if point (goto-char (point)))
    (let ((s (semantic-fetch-overload 'ctxt-current-symbol))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-ctxt-current-symbol-default)
	)))

(defun semantic-ctxt-current-symbol-default ()
  "Return the current symbol the cursor is on at POINT in a list.
This will include a list of type/field names when applicable.
Depends on `semantic-type-relation-separator-character'."
  (let* ((fieldsep1 (mapconcat (lambda (a) (regexp-quote a))
			       semantic-type-relation-separator-character
			       "\\|"))
	 (fieldsep (concat "\\(" fieldsep1 "\\)\\(\\w\\|\\s_\\)"))
	 (symlist nil)
	 end begin)
    (save-excursion
      (if (looking-at "\\w\\|\\s_")
	  (forward-sexp 1)
	;; Not on a sym, are we at a separator char with no field
	;; specified yet?
	(when (or (looking-at fieldsep1)
		  (save-excursion
		    (and (condition-case nil
			     (progn (forward-sexp -1)
				    (forward-sexp 1)
				    t)
			   (error nil))
			 (looking-at fieldsep1))))
	  (setq symlist (list ""))
	  (forward-sexp -1)
	  (forward-sexp 1)))
      (setq end (point))
      (condition-case nil
	  (while (save-excursion
		   (forward-char -1)
		   (looking-at "\\w\\|\\s_"))
	    ;; We have a symbol.. Do symbol things
	    (forward-sexp -1)
	    (setq symlist (cons (buffer-substring-no-properties (point) end)
				symlist))
	    ;; Skip the next syntactic expression backwards, then go forwards.
	    (forward-sexp -1)
	    (forward-sexp 1)
	    (if (looking-at fieldsep)
		(setq end (point))
	      (error nil))
	    )
	(error nil)))
    symlist))

(defun semantic-ctxt-current-assignment (&optional point)
  "Return the current assignment near the cursor at POINT.
Return a list as per `semantic-ctxt-current-symbol'.
Return nil if there is nothing relevant.
Override with `ctxt-current-assignment'."
    (if point (goto-char (point)))
    (let ((s (semantic-fetch-overload 'ctxt-current-assignment))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-ctxt-current-assignment-default)
	)))

(defun semantic-ctxt-current-assignment-default ()
  "Return the current assignment near the cursor at POINT.
By default, assume that \"=\" indicates an assignment."
  (condition-case nil
      (let* ((begin (save-excursion (semantic-beginning-of-command) (point)))
	     (upc (save-excursion (semantic-up-context) (point)))
	     (nearest (if (< begin upc) upc begin)))
	(save-excursion
	  ;; TODO: Skip a regexp backwards with whitespace from the
	  ;; syntax table.
	  (skip-chars-backward " \t\n")
	  ;; Lets wander backwards till we find an assignment.
	  (while (and (not (= (preceding-char) ?=))
		      (> (point) nearest))
	    (forward-sexp -1)
	    (skip-chars-backward " \t\n")
	    )
	  ;; We are at an equals sign.  Go backwards a sexp, and
	  ;; we'll have the variable
	  (forward-sexp -1)
	  (semantic-ctxt-current-symbol)))
    (error nil)))

(defun semantic-ctxt-current-function (&optional point)
  "Return the current function the cursor is in at POINT.
The function returned is the one accepting the arguments that
the cursor is currently in.
This can be overridden with `ctxt-current-function'."
    (if point (goto-char (point)))
    (let ((s (semantic-fetch-overload 'ctxt-current-function))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-ctxt-current-function-default)
	)))

(defun semantic-ctxt-current-function-default ()
  "Return the current symbol the cursor is on at POINT in a list."
  (save-excursion
    (semantic-up-context)
    (when (looking-at "(")
      (semantic-ctxt-current-symbol)))
  )

(defun semantic-ctxt-current-argument (&optional point)
  "Return the current symbol the cursor is on at POINT.
Override with `ctxt-current-argument'."
    (if point (goto-char (point)))
    (let ((s (semantic-fetch-overload 'ctxt-current-argument))
	  (case-fold-search semantic-case-fold))
      (if s (funcall s)
	(semantic-ctxt-current-argument-default)
	)))

 (defun semantic-ctxt-current-argument-default ()
  "Return the current symbol the cursor is on at POINT in a list.
Depends on `semantic-function-argument-separation-character'."
  (when (semantic-ctxt-current-function)
    (save-excursion
      ;; Only get the current arg index if we are in function args.
      (let ((p (point))
	    (idx 1))
	(semantic-up-context)
	(while (re-search-forward
		(regexp-quote semantic-function-argument-separation-character)
		p t)
	  (setq idx (1+ idx)))
	idx))))

;;; Context analysis routines
;;
;; These routines use the override methods to provides high level
;; predicates, and to come up with intelligent suggestions about
;; the current context.
(defun semantic-suggest-lookup-item (name  &optional tokentype returntype)
  "Find a token definition matching NAME with TOKENTYPE.
Optional RETURNTYPE is a return value to match against also."
  (let* ((locals (semantic-get-all-local-variables))
	 (case-fold-search semantic-case-fold)
	 (option
	  (or (let ((found nil))
		(while (and locals (not found))
		  (setq found (semantic-find-nonterminal-by-name
			       name (car locals) t)
			locals (cdr locals)))
		found)
	      (semantic-find-nonterminal-by-name
	       name (current-buffer) t)
	      (and (featurep 'semanticdb)
		   (semanticdb-minor-mode-p)
		   (semanticdb-find-nonterminal-by-name name nil t nil t)))))
    ;; This part is lame right now.  It needs to eventually
    ;; do the tokentype and returntype filters across all databases.
    ;; Some of the above return one token, instead of a list.  Deal with
    ;; that too.
    (if (listp option)
	(if (semantic-token-p option)
	    option
          ;; `semanticdb-find-nonterminal-by-name' returns a list
          ;; ((DB-TABLE . TOKEN) ...)
	  (setq option (cdr (car option))))
      (if (stringp option)
	  (list option 'variable)
	))))

(defun semantic-suggest-variable-token-hierarchy ()
  "Analyze the current line, and return a series of tokens.
The tokens represent a hierarchy of dereferences.  For example, a
variable name will return a list with one token representing that
variable's declaration.  If that variable is being dereferenced, then
return a list starting with the variable declaration, followed by all
fields being extracted.

For example, in c, \"foo->bar\" would return a list (VARTOKEN FIELDTOKEN)
where VARTOKEN is a semantic token of the variable foo's declaration.
FIELDTOKEN is either a string, or a semantic token representing
the field in foo's type."
  (let ((v (semantic-ctxt-current-symbol))
	(case-fold-search semantic-case-fold)
	(name nil)
	(tok nil)
	(chil nil)
	(toktype nil))
    ;; First, take the first element of V, and find its type.
    (setq tok (semantic-suggest-lookup-item (car v) 'variable))
    ;; Now refer to it's type.
    (setq toktype (semantic-token-type tok))
    (if (and (semantic-token-p toktype)
	     (not (semantic-token-type-parts toktype)))
	(setq toktype (semantic-suggest-lookup-item
		       (if (semantic-token-p toktype)
			   (semantic-token-name toktype)
			 (if (stringp toktype)
			     toktype
			   (error "Unknown token type")))
		       'type)))
    (if toktype
	(cond ((and (semantic-token-p toktype)
		    (setq chil (semantic-nonterminal-children toktype)))
	       ;; We now have the type of the start variable.  Now we
	       ;; have to match the list of additional fields with the
	       ;; children of the type we found.
	       (let ((chosenfields (cdr tok))
		     (returnlist (list toktype)))
		 (while chosenfields
		   ;; Find this field in the current toktype
		   
		   (setq chosenfields (cdr chosenfields)))
		 (nreverse returnlist))
	       )
	      ((semantic-token-p toktype)
	       (list toktype))
	      ((stringp toktype)
	       (list (list toktype 'type)))
	      (t nil)))))

(defun semantic-suggest-current-type ()
  "Return the recommended type at the current location."
  (let ((recommendation (semantic-suggest-variable-token-hierarchy)))
    (car (nreverse recommendation))))

(provide 'semantic-ctxt)

;;; semantic-ctxt.el ends here
