;;; working --- Display a "working" message in the minibuffer.

;;;  Copyright (C) 1997, 1998  Free Software Foundation

;; Author: Eric M. Ludlam <zappo@gnu.org>
;; Version: 1.0
;; Keywords: status

;; This program is free software; you can redistribute it and/or modify
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
;;  Working is an attempt to unify the many locations that display a
;;  "working" message in the minibuffer, and permits cool
;;  customizations which would then affect all other packages that use
;;  this code.
;;

;;; History:
;; 
;; 1.0 First Version

(require 'custom)

;;; Code:
(defgroup working nil
  "Working messages display."
  :prefix "working"
  :group 'lisp
;  :version "20.3"
  )

;;; User configurable variables
;;
(defcustom working-status-type 'working-bar-percent-display
  "Function used to display the percent status.
Functions provide in `working' are:
  `working-percent-display'
  `working-bar-display'
  `working-bar-percent-display'
  `working-percent-bar-display'"
  :group 'working
  :type 'sexp)

;;; Programmer functions
;;
(defmacro working-status-forms (message donestr &rest forms)
  "Contain a block of code during which a working status is shown.
MESSAGE is the message string to use and DONESTR is the completed text
to use when the functions `working-status' is called from FORMS."
  (list 'let (list (list 'msg message)
		   (list 'dstr donestr)
		   '(ref1 0))
	(cons 'progn forms)))
(put 'working-status-forms 'lisp-indent-function 2)

(defun working-status (&optional percent &rest args)
  "Called within the macro `working-status-forms', show the status.
If PERCENT is nil, then calculate PERCENT from the value of `point' in
the current buffer.  If it is a number or float, use it as the raw
percentile.  If it is a string, then consider the job done, and
display this string where numbers would appear.
Additional ARGS are passed to fill on % elements of MESSAGE from the
macro `working-status-forms'."
  (let* ((p (or percent (floor (* 100.0 (/ (float (point)) (point-max))))))
	 (m1 (apply 'format msg args))
	 (m2 (funcall working-status-type (length m1) p)))
    (message (concat m1 m2))))

;;; Percentage display types.
;;
(defun working-percent-display (length percent)
  "Return the percentage of the buffer that is done.
LENGTH is the amount of display that has been used.  PERCENT
is t to display the done string, or the precentage to display."
  (cond ((eq percent t) (concat "... " dstr))
	;; All the % signs because it then gets passed to message.
	(t (format "... %3d%%%%" percent))))

(defun working-bar-display (length percent)
  "Return a string with a bar-graph showing percent.
LENGTH is the amount of display that has been used.  PERCENT
is t to display the done string, or the precentage to display."
  (let ((bs (- (frame-width) length 4)))
    (cond ((eq percent t)
	   (concat ": [" (make-string bs ?#) "] " dstr))
	  (t (let ((bsl (floor (* (/ percent 100.0) bs))))
	       (concat ": ["
		       (make-string bsl ?#)
		       (make-string (- bs bsl) ?.)
		       "]"))))))

(defun working-bar-percent-display (length percent)
  "Return a string with a bar-graph showing percent.
LENGTH is the amount of display that has been used.  PERCENT
is t to display the done string, or the precentage to display."
  (let* ((ps (if (eq percent t)
		 (concat "... " dstr)
	       (working-percent-display length percent)))
	 (psl (+ 1 length (if (eq percent t) ref1 (length ps)))))
    (cond ((eq percent t)
	   (concat (working-bar-display psl 100) " " ps))
	  (t
	   (setq ref1 (length ps))
	   (concat (working-bar-display psl percent) " " ps)))))

(defun working-percent-bar-display (length percent)
  "Return a string with a bar-graph showing percent.
LENGTH is the amount of display that has been used.  PERCENT
is t to display the done string, or the precentage to display."
  (let* ((ps (if (eq percent t)
		 (concat "... " dstr)
	       (working-percent-display length percent)))
	 (psl (+ 1 length (if (eq percent t) ref1 (length ps)))))
    (cond ((eq percent t)
	   (concat ps " " (working-bar-display psl 100)))
	  (t
	   (setq ref1 (length ps))
	   (concat ps " " (working-bar-display psl percent))))))

;;; Example function using `working'
;;
(defun working-verify-parenthisis ()
  "Verify all the parenthisis in an elisp program buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (working-status-forms "Scanning" "done"
      (while (not (eobp))
	;; Use default buffer position.
	(working-status)
	(forward-sexp 1)
	(sleep-for 0.05)
	)
      (working-status t))))

(provide 'working)

;;; working.el ends here
