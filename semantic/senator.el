;;; senator.el --- SEmantic NAvigaTOR

;; Copyright (C) 2000 by David Ponce

;; Author: David Ponce <david@dponce.com>
;; Maintainer: David Ponce <david@dponce.com>
;; Created: 10 Nov 2000
;; Version: 2.0
;; Keywords: tools, syntax
;; VC: $Id$

;; This file is not part of Emacs

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; This library defines commands and a minor mode to navigate between
;; language semantic tokens in current buffer.  It uses Eric Ludlam's
;; semantic bovinator tool to parse the buffer and find the language
;; tokens.

;; The commands `senator-next-token' and `senator-previous-token'
;; navigate respectively to the token after or before the point.

;; Also, for each built-in search command `search-forward',
;; `search-backward', `re-search-forward', `re-search-backward',
;; `word-search-forward' and `word-search-backward', an equivalent
;; `senator-<search-command>' is defined which search only in semantic
;; token names.

;; The command `senator-isearch-toggle-semantic-mode' toggles semantic
;; search in isearch mode.  When semantic search is enabled, isearch
;; is restricted to token names.

;; Finally, the library provides a `senator-minor-mode' to easily
;; enable or disable the SEmantic NAvigaTOR stuff for the current
;; buffer.

;; The best way to use navigation commands is to bind them to keyword
;; shortcuts.  In senator minor mode `senator-next-token' and
;; `senator-previous-token' are respectively binded to C-,n and C-,p.
;; And C-,i is binded to `senator-isearch-toggle-semantic-mode'.
;;
;; To install, put this file on your Emacs-Lisp load path and add
;; (require 'senator) into your ~/.emacs startup file.  To enable
;; senator stuff in the current buffer use (senator-minor-mode 1).

;; You can customize the `senator-step-at-token-ids' and
;; `senator-step-at-start-end-token-ids' options to navigate (and
;; search) only between particular tokens and to step at start and end
;; of some of them.  To have a mode specific customization, do
;; something like this in a hook:
;;
;; (add-hook 'mode-hook
;;           (lambda ()
;;             (setq senator-step-at-token-ids '(function variable))
;;             (setq senator-step-at-start-end-token-ids '(function))
;;             ))
;;
;; The above example specifies to navigate (and search) only between
;; functions and variables, and to step at start and end of functions
;; only.
;;
;; Any comments, suggestions, bug reports or upgrade requests are
;; welcome.  Please send them to David Ponce at <david@dponce.com>

;;; History:

;; $Log$
;; Revision 1.7  2000/12/05 11:13:19  david_ponce
;; New major version 2.0 with [i]search feature and a senator minor mode.
;; Added compatibility code between GNU Emacs 20.7 and 21.
;;
;; Revision 1.6  2000/11/28 12:44:47  david_ponce
;; More performance improvements.
;; New option `senator-highlight-found' to customize token highlighting.
;;
;; Revision 1.5  2000/11/27 13:24:17  david_ponce
;; Fixed a serious performance problem in `senator-next-token' and
;; `senator-previous-token'.
;;
;; Before searching for a next or previous token the point was just moved
;; to respectively the next or previous character. Thus, during
;; navigation, the buffer was explored character by character :-(.  Now
;; `senator-next-token' and `senator-previous-token' skip whole tokens
;; (unless they are 'type tokens which may include sub tokens).
;;
;; Revision 1.4  2000/11/14 17:23:21  david_ponce
;; Minor change to `senator-next-token' and `senator-previous-token' to
;; return the token at point.  Useful when calling these commands
;; non-interactively.
;;
;; Revision 1.3  2000/11/14 13:04:26  david_ponce
;; Improved navigation in semantic token where to step at start and end.
;;
;; - `senator-next-token' move the point to the end of token if it was at
;;   beginning or in the middle of the token.
;;
;; - `senator-previous-token' move the point to the beginning of token if
;;   it was at end or in the middle of the token.
;;
;; Revision 1.2  2000/11/10 17:11:15  david_ponce
;; Fixed a little bug in `senator-previous-token' navigation.
;;
;; Revision 1.1  2000/11/10 16:04:20  david_ponce
;; Initial revision.
;;

;;; Code:
(require 'semantic)
(require 'senator-isearch)       ; Needed isearch advices

(defgroup senator nil
  "SEmantic NAvigaTOR."
  :group 'semantic)

(defcustom senator-step-at-token-ids nil
  "*List of token identifiers where to step.
Token identifier is symbol 'variable, 'function, 'type, or other.  If
nil navigation steps at any token found.  This is a buffer local
variable.  It can be set in a mode hook to get a specific langage
navigation."
  :group 'senator
  :type '(repeat (symbol)))
(make-variable-buffer-local 'senator-step-at-token-ids)

(defcustom senator-step-at-start-end-token-ids '(function)
  "*List of token identifiers where to step at start and end.
Token identifier is symbol 'variable, 'function, 'type, or other.  If
nil navigation only step at beginning of tokens.  This is a buffer
local variable.  It can be set in a mode hook to get a specific
langage navigation."
  :group 'senator
  :type '(repeat (symbol)))
(make-variable-buffer-local 'senator-step-at-start-end-token-ids)

(defcustom senator-highlight-found t
  "*If non-nil highlight tokens found.
This option requires semantic 1.3 and above.  This is a buffer
local variable.  It can be set in a mode hook to get a specific
langage behaviour."
  :group 'senator
  :type 'boolean)
(make-variable-buffer-local 'senator-highlight-found)

;;; Compatibility
(cond ((fboundp 'semantic-momentary-highlight-token)
       ;; semantic 1.3
       (defun senator-parse ()
         "Parse the current buffer and return the tokens where to navigate."
         (semantic-bovinate-toplevel t))
       )
      (t
       ;; semantic before 1.3
       (defun semantic-momentary-highlight-token (token)
         "Highlight TOKEN, not implemented in this version of semantic."
         ;; Does nothing
         )
       (defun senator-parse ()
         "Parse the current buffer and return the tokens where to navigate."
         (semantic-bovinate-toplevel nil nil t))
       ))

;;;;
;;;; Common functions
;;;;

(defun senator-momentary-highlight-token (token)
  "Momentary highlight TOKEN.
Does nothing if `senator-highlight-found' is nil or semantic version
is bellow 1.3."
  (and senator-highlight-found
       (semantic-momentary-highlight-token token)))

(defun senator-message (&rest args)
  "Call function `message' with ARGS without logging."
  (let (message-log-max)
    (apply 'message args)))

(defun senator-step-at-start-end-p (token)
  "Return non-nil if must step at start and end of TOKEN."
  (if token
      (let ((categ (semantic-token-token token)))
        (and (not (eq categ 'type))
             (memq categ senator-step-at-start-end-token-ids)))))

(defun senator-skip-p (token)
  "Return non-nil if must skip TOKEN."
  (and token
       senator-step-at-token-ids
       (not (memq (semantic-token-token token)
                  senator-step-at-token-ids))))

(defun senator-find-previous-token-aux (tokens pos &optional prev)
  "Visit TOKENS and return the token just before POS.
Optional PREV is the previous visited token.  This is an helper
function for `senator-find-previous-token'."
  (let (token)
    (while tokens
      (setq token (car tokens))
      (if (>= (semantic-token-start token) pos)
          (throw 'found prev))
      (or (senator-skip-p token)
          (setq prev token))
      (if (eq (semantic-token-token token) 'type)
          (setq prev (senator-find-previous-token-aux
                      (semantic-token-type-parts token) pos prev)))
      (setq tokens (cdr tokens)))
    prev))

(defun senator-find-previous-token (tokens pos)
  "Visit TOKENS and return the token just before POS."
  (catch 'found (senator-find-previous-token-aux tokens pos)))

(defun senator-find-next-token (tokens pos)
  "Visit TOKENS and return the token at or just after POS."
  (let (token found)
    (while (and tokens (not found))
      (setq token (car tokens))
      (if (and (not (senator-skip-p token))
               (or (and (senator-step-at-start-end-p token)
                        (> (semantic-token-end token) pos))
                   (>= (semantic-token-start token) pos)))
          (setq found token)
        (if (eq (semantic-token-token token) 'type)
            (setq found (senator-find-next-token
                         (semantic-token-type-parts token) pos))))
      (setq tokens (cdr tokens)))
    found))

(defun senator-middle-of-token-p (pos token)
  "Return non-nil if POS is between start and end of TOKEN."
  (and (> pos (semantic-token-start token))
       (< pos (semantic-token-end   token))))

;;;;
;;;; Search functions
;;;;

(defun senator-search-token-name (token)
  "Search the TOKEN name in TOKEN bounds.
Set point to the end of the name, and return point.  To get the
beginning of the name use (match-beginning 0)."
  (let ((name (semantic-token-name token)))
    (goto-char (semantic-token-start token))
    (re-search-forward (concat
                        "\\b"
                        (regexp-quote
                         (if (string-match "\\`\\([^[]+\\)[[]" name)
                             (match-string 1 name)
                           name)))
                       (semantic-token-end token))))

(defun senator-search-previous-token ()
  "Return the semantic token before the point or nil if not found."
  (let ((tokens (senator-parse)))
    (senator-find-previous-token tokens (point))))

(defun senator-search-next-token (&optional from-previous)
  "Return the semantic token after the point or nil if not found.
If optional FROM-PREVIOUS is non-nil start searching from token before
the point."
  (let ((tokens (senator-parse)))
    (if from-previous
        (let ((found (senator-find-previous-token tokens (point))))
          (if found
              (goto-char (semantic-token-start found))
            (goto-char (point-min)))))
    (senator-find-next-token tokens (point))))

(defun senator-search-forward-raw (searcher what &optional bound noerror count)
  "Use SEARCHER to search WHAT in semantic tokens after point.
See `search-forward' for the meaning of BOUND NOERROR and COUNT.
BOUND and COUNT are just ignored in the current implementation."
  (if (equal what "")
      (setq what (car search-ring))
    (isearch-update-ring what nil))
  (let ((origin (point))
        (senator-step-at-start-end-token-ids nil)
        token pos start limit)
    (save-excursion
      (setq token (senator-search-next-token t))
      (while (and token (not pos))
        (setq limit (senator-search-token-name token))
        (setq start (match-beginning 0))
        (if (and (> origin start) (< origin limit))
            (setq start origin))
        (goto-char start)
        (setq pos (funcall searcher what limit t))
        (if (and pos (>= (match-beginning 0) origin))
            nil
          (setq pos nil)
          (forward-char)
          (setq token (senator-search-next-token)))))
    (if pos
        (goto-char start)
      (setq limit (point)))
    (funcall searcher what limit noerror)))

(defun senator-search-backward-raw (searcher what &optional bound noerror count)
  "Use SEARCHER to search WHAT in semantic tokens before point.
See `search-backward' for the meaning of BOUND NOERROR and
COUNT.  BOUND and COUNT are just ignored in the current
implementation."
  (if (equal what "")
      (setq what (car search-ring))
    (isearch-update-ring what nil))
  (let ((origin (point))
        (senator-step-at-start-end-token-ids nil)
        token pos start limit)
    (save-excursion
      (setq token (senator-search-previous-token))
      (while (and token (not pos))
        (setq start (senator-search-token-name token))
        (setq limit (match-beginning 0))
        (if (and (< origin start) (> origin limit))
            (setq start origin))
        (goto-char start)
        (setq pos (funcall searcher what limit t))
        (if (and pos (<= (match-end 0) origin))
            nil
          (setq pos nil)
          (goto-char (semantic-token-start token))
          (setq token (senator-search-previous-token)))))
    (if pos
        (goto-char start)
      (setq limit (point)))
    (funcall searcher what limit noerror)))

;;;;
;;;; Navigation commands
;;;;

;;;###autoload
(defun senator-next-token ()
  "Navigate to the next semantic token.
Return the semantic token or nil if at end of buffer."
  (interactive)
  (let ((pos    (point))
        (tokens (senator-parse))
        found where)
    (if (memq real-last-command
              '(senator-previous-token senator-next-token))
        (forward-char))
    (setq found (senator-find-next-token tokens (point)))
    (if (not found)
        (progn
          (goto-char (point-max))
          (senator-message "End of buffer"))
      (cond ((and (senator-step-at-start-end-p found)
                  (or (= pos (semantic-token-start found))
                      (senator-middle-of-token-p pos found)))
             (setq where "end")
             (goto-char (semantic-token-end found)))
            (t
             (setq where "start")
             (goto-char (semantic-token-start found))))
      (senator-momentary-highlight-token found)
      (senator-message "%S: %s (%s)"
                       (semantic-token-token found)
                       (semantic-token-name  found)
                       where))
    found))

;;;###autoload
(defun senator-previous-token ()
  "Navigate to the previous semantic token.
Return the semantic token or nil if at beginning of buffer."
  (interactive)
  (let ((pos    (point))
        (tokens (senator-parse))
        found where)
    (if (eq real-last-command 'senator-previous-token)
        (backward-char))
    (setq found (senator-find-previous-token tokens (point)))
    (if (not found)
        (progn
          (goto-char (point-min))
          (senator-message "Beginning of buffer"))
      (cond ((or (not (senator-step-at-start-end-p found))
                 (= pos (semantic-token-end found))
                 (senator-middle-of-token-p pos found))
             (setq where "start")
             (goto-char (semantic-token-start found)))
            (t
             (setq where "end")
             (goto-char (semantic-token-end found))))
      (senator-momentary-highlight-token found)
      (senator-message "%S: %s (%s)"
                       (semantic-token-token found)
                       (semantic-token-name  found)
                       where))
    found))

;;;;
;;;; Search commands
;;;;

;;;###autoload
(defun senator-search-forward (what &optional bound noerror count)
  "Search semantic tokens forward from point for string WHAT.
Set point to the end of the occurrence found, and return point.  See
`search-forward' for details and the meaning of BOUND NOERROR and
COUNT.  BOUND and COUNT are just ignored in the current
implementation."
  (interactive "sSemantic search: ")
  (senator-search-forward-raw #'search-forward what bound noerror count))

;;;###autoload
(defun senator-re-search-forward (what &optional bound noerror count)
  "Search semantic tokens forward from point for regexp WHAT.
Set point to the end of the occurrence found, and return point.  See
`re-search-forward' for details and the meaning of BOUND NOERROR and
COUNT.  BOUND and COUNT are just ignored in the current
implementation."
  (interactive "sSemantic regexp search: ")
  (senator-search-forward-raw #'re-search-forward what bound noerror count))

;;;###autoload
(defun senator-word-search-forward (what &optional bound noerror count)
  "Search semantic tokens forward from point for word WHAT.
Set point to the end of the occurrence found, and return point.  See
`word-search-forward' for details and the meaning of BOUND NOERROR and
COUNT.  BOUND and COUNT are just ignored in the current
implementation."
  (interactive "sSemantic word search: ")
  (senator-search-forward-raw #'word-search-forward what bound noerror count))

;;;###autoload
(defun senator-search-backward (what &optional bound noerror count)
  "Search semantic tokens backward from point for string WHAT.
Set point to the beginning of the occurrence found, and return point.
See `search-backward' for details and the meaning of BOUND NOERROR and
COUNT.  BOUND and COUNT are just ignored in the current
implementation."
  (interactive "sSemantic backward search: ")
  (senator-search-backward-raw #'search-backward what bound noerror count))

;;;###autoload
(defun senator-re-search-backward (what &optional bound noerror count)
  "Search semantic tokens backward from point for regexp WHAT.
Set point to the beginning of the occurrence found, and return point.
See `re-search-backward' for details and the meaning of BOUND NOERROR
and COUNT.  BOUND and COUNT are just ignored in the current
implementation."
  (interactive "sSemantic backward regexp search: ")
  (senator-search-backward-raw #'re-search-backward what bound noerror count))

;;;###autoload
(defun senator-word-search-backward (what &optional bound noerror count)
  "Search semantic tokens backward from point for word WHAT.
Set point to the beginning of the occurrence found, and return point.
See `word-search-backward' for details and the meaning of BOUND
NOERROR and COUNT.  BOUND and COUNT are just ignored in the current
implementation."
  (interactive "sSemantic backward word search: ")
  (senator-search-backward-raw #'word-search-backward what bound noerror count))

;;;;
;;;; Senator minor mode
;;;;

(require 'easy-mmode)

(defvar senator-isearch-semantic-mode nil
  "Non-nil if isearch does semantic search.
This is a buffer local variable.")
(make-variable-buffer-local 'senator-isearch-semantic-mode)

(defvar senator-prefix-map nil
  "Keymap containing bindings to senator functions.")

(if senator-prefix-map
    nil
  (define-prefix-command 'senator-prefix-map)
  (define-key senator-prefix-map "i" 'senator-isearch-toggle-semantic-mode)
  (define-key senator-prefix-map "p" 'senator-previous-token)
  (define-key senator-prefix-map "n" 'senator-next-token))

(defvar senator-mode-map
  (easy-mmode-define-keymap
   '(([(control ?,)] . senator-prefix-map)))
  "Keymap for senator minor mode.")

(if (fboundp 'define-minor-mode)

;;; Note that `define-minor-mode' actually calls the mode-function if
;;; the associated variable is non-nil, which requires that all needed
;;; functions be already defined.  [This is arguably a bug in d-m-m]
;;;###autoload
    (define-minor-mode senator-minor-mode
      "Toggle senator minor mode.
With prefix argument ARG, turn on if positive, otherwise off.  The
minor mode is turned on only if semantic feature is available and a
`semantic-toplevel-bovine-table' is provided.  Returns non-nil if the
new state is enabled.

\\{senator-mode-map}"
      nil " Senator" senator-mode-map
      :global nil
      :group 'senator
      (if senator-minor-mode
          (if (not (and (featurep 'semantic) semantic-toplevel-bovine-table))
              ;; Disable minor mode if semantic stuff not available
              (senator-minor-mode nil)
            ;; Parse the current buffer if needed
            (senator-parse)
            )
        ;; Disable semantic isearch
        (setq senator-isearch-semantic-mode nil)
        )
      senator-minor-mode)

  ;; If `define-minor-mode' not defined

  (defvar senator-minor-mode nil
    "Non-nil if senator minor mode is on.")
  (make-variable-buffer-local 'senator-minor-mode)
  
  (defvar senator-minor-mode-hook  nil
    "Hook called when senator minor mode is toggled")
  
  (defvar senator-minor-mode-on-hook nil
    "Hook called when senator minor mode is turned on")
  
  (defvar senator-minor-mode-off-hook nil
    "Hook called when senator minor mode is turned off")
  
;;;###autoload
  (defun senator-minor-mode (&optional arg)
    "Toggle senator minor mode.
With prefix argument ARG, turn on if positive, otherwise off.  The
minor mode is turned on only if semantic feature is available and a
`semantic-toplevel-bovine-table' is provided.  Returns non-nil if the
new state is enabled.

\\{senator-mode-map}"
    (interactive "P")
    (let ((old-mode senator-minor-mode))
      (setq senator-minor-mode
            (if arg
                (or (listp arg) ;; C-u alone
                    (> (prefix-numeric-value arg) 0))
              (not senator-minor-mode)))
      (and senator-minor-mode-hook
           (not (equal old-mode senator-minor-mode))
           (run-hooks senator-minor-mode-hook))
      (and senator-minor-mode-on-hook
           senator-minor-mode
           (run-hooks senator-minor-mode-on-hook))
      (and senator-minor-mode-off-hook
           (not senator-minor-mode)
           (run-hooks senator-minor-mode-off-hook)))
    (if senator-minor-mode
        (if (not (and (featurep 'semantic) semantic-toplevel-bovine-table))
            ;; Disable minor mode if semantic stuff not available
            (senator-minor-mode nil)
          ;; Parse the current buffer if needed
          (senator-parse)
          )
      ;; Disable semantic isearch
      (setq senator-isearch-semantic-mode nil)
      )
    (senator-message "Senator minor mode %s"
                     (if senator-minor-mode
                         "enabled"
                       "disabled"))
    senator-minor-mode)
  
  (or (assq 'senator-minor-mode minor-mode-alist)
      (setq minor-mode-alist
            (cons (list 'senator-minor-mode " Senator") minor-mode-alist)))
  
  (or (assq 'senator-minor-mode minor-mode-map-alist)
      (setq minor-mode-map-alist
            (cons (cons 'senator-minor-mode senator-mode-map)
                  minor-mode-map-alist)))
  )

;;;;
;;;; Useful advices
;;;;

(defadvice beginning-of-defun (around senator activate)
  "If semantic tokens are available, use them to navigate."
  (if (and senator-minor-mode (interactive-p))
      (let ((senator-step-at-start-end-token-ids nil)
            (senator-step-at-token-ids '(function)))
        (senator-previous-token))
    ad-do-it))

(defadvice end-of-defun (around senator activate)
  "If semantic tokens are available, use them to navigate."
  (if (and senator-minor-mode (interactive-p))
      (let* ((senator-step-at-start-end-token-ids '(function))
             (senator-step-at-token-ids '(function))
             (token (senator-next-token)))
        (when (and token
                   (= (point) (semantic-token-start token)))
          (goto-char (semantic-token-end token))
          (senator-message "%S: %s (end)"
                           (semantic-token-token token)
                           (semantic-token-name  token))))
    ad-do-it))

;;;;
;;;; Using semantic search in isearch mode
;;;;

(defvar senator-isearch-mode-name nil
  "Save current value of the variable `isearch-mode'.
This is a buffer local variable.")
(make-variable-buffer-local 'senator-isearch-mode-name)

(defun senator-isearch-search-handler ()
  "Return the actual search function used by `isearch-search'.
If `senator-isearch-semantic-mode' is nil it delegates to the
function `isearch-default-search-handler'.  Otherwise it returns one
of the functions `senator-search-forward', `senator-search-backward',
`senator-word-search-forward', `senator-word-search-backward',
`senator-re-search-forward' or `senator-re-search-backward' depending
on current values of the variables `isearch-forward', `isearch-regexp'
and `isearch-word'."
  (if senator-isearch-semantic-mode
      (cond (isearch-word
             (if isearch-forward
                 'senator-word-search-forward
               'senator-word-search-backward))
            (isearch-regexp
             (if isearch-forward
                 'senator-re-search-forward
               'senator-re-search-backward))
            (t
             (if isearch-forward
                 'senator-search-forward
               'senator-search-backward)))
    (isearch-default-search-handler)))

(defun senator-isearch-update-modeline ()
  "Update the modeline to show the semantic search state.
If `senator-isearch-semantic-mode' is non-nil append \"/S\" to
the value of the variable `isearch-mode'."
  (if senator-isearch-semantic-mode
      (setq isearch-mode (concat senator-isearch-mode-name "/S"))
    (setq isearch-mode senator-isearch-mode-name))
  (force-mode-line-update))

(defun senator-isearch-toggle-semantic-mode ()
  "Toggle semantic searching on or off in isearch mode.
\\[senator-isearch-toggle-semantic-mode] toggle semantic searching."
  (interactive)
  (when senator-minor-mode
    (setq senator-isearch-semantic-mode
          (not senator-isearch-semantic-mode))
    (when isearch-mode
      (senator-isearch-update-modeline)
      ;; force lazy highlight update
      (isearch-lazy-highlight-cleanup t)
      (setq isearch-lazy-highlight-last-string nil)
      (setq isearch-adjusted t)
      (isearch-update)))
  (senator-message "Isearch semantic mode %s"
                   (if senator-isearch-semantic-mode
                       "enabled"
                     "disabled")))

(defun senator-isearch-mode-hook ()
  "Isearch mode hook to setup semantic searching."
  (or senator-isearch-mode-name
      (setq senator-isearch-mode-name isearch-mode
            isearch-search-handler-provider
            #'senator-isearch-search-handler))
  (or senator-minor-mode
      (setq senator-isearch-semantic-mode nil))
  (senator-isearch-update-modeline)
  (isearch-lazy-highlight-cleanup t))

(add-hook 'isearch-mode-hook 'senator-isearch-mode-hook)

(provide 'senator)

;;; senator.el ends here
