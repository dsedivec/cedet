;;; dialog.el - Code for starting, and managing dialogs buffers
;;;
;;; Copyright (C) 1995, 1996 Eric M. Ludlam
;;;
;;; Author: <zappo@gnu.ai.mit.edu>
;;; Version: 0.4
;;; RCS: $Id$
;;; Keywords: OO widget dialog
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

;;;
;;; Commentary:
;;;   Dialog mode requires the use of widget-d and widget-i.  It
;;; supplies mundane functions (basic drawing routines w/ faces) and
;;; also the framework in which the widgets work (The buffer, mode,
;;; keymap, etc).  Using `dialog-mode' lets you create a dialog in
;;; which you can place buttons and text fields within a top-level
;;; shell.  This mode manages the keymap, and the input is distributed
;;; to the correct active widget.
;;;
;;; To create a new dialog, you must follow these basic steps:
;;; 1) Create a new blank buffer
;;; 2) run `dialog-mode' on it
;;; 3) use `create-widget' to make widgets to make your dialog useful
;;;    (create-widget name class parent &rest resources)
;;;    - widget-label          - static text
;;;    - widget-button         - push it to make something happen
;;;    - widget-toggle-button  - push it to change a value
;;;    - widget-text-field     - a place to edit simple text
;;;    - widget-frame          - make a box around other widgets
;;;    Resources are :keys which specify how your widget behaves
;;; 4) call `dialog-refresh'
;;;
;;; Making widgets talk to eachother:
;;; Asside from `widget-core' there is also a `data-object' which
;;; provides a method for widgets to talk to eachother (ala
;;; fresco/interviews style)  A widget will create a data object if
;;; one is not given to it.  A widget always register's itself with
;;; the data object, and these objects alert viewers if they are
;;; changed.  In this way, a toggle button will automatically update
;;; itself if it's data has changed.
;;;
;;; For examples of how to make widgets interact, examine the function
;;; `dialog-test'

(require 'widget-i)

(defvar dialog-xemacs-p (string-match "XEmacs" emacs-version)
  "Are we running in Xemacs?")

;;;
;;; Widget definitions using eieio
;;; 
         
(defvar widget-toplevel-shell nil
  "Buffer local variable containing the definition of the toplevel
shell active in the current buffer.  There can be only one toplevel
shell definition in a given buffer.")
(make-variable-buffer-local 'widget-toplevel-shell)

(defvar dialog-current-parent nil
  "Defined while building buffers.  This represents the parent of
newly created widgets.")

;;;
;;; Dialog mode variables
;;;
(defun dialog-superbind-alpha (keymap fn)
  "In KEYMAP bind all occurances of alphanumeric keys to FN.  An alphanumeric
key is any value between 0 and 128"
  (let ((key "\00"))
    (aset key 0 0)
    (while (< (aref key 0) 128)
      (define-key keymap key fn)
      (aset key 0 (1+ (aref key 0))))))

(defvar dialog-mode-map nil 
  "Keymap used in dialog mode.")

(defvar dialog-meta-map nil
  "Keymap used to trap meta-keys")

(if dialog-mode-map () 
  ;; create and fill up the keymap with our event handler
  (setq dialog-mode-map (make-keymap))
  (dialog-superbind-alpha dialog-mode-map 'dialog-handle-kbd)
  (setq dialog-meta-map (make-keymap))
  (dialog-superbind-alpha dialog-meta-map 'dialog-handle-meta-kbd)
  ;; some keys we don't want to override
  (define-key dialog-mode-map "\e" dialog-meta-map)
  (define-key dialog-mode-map "\C-x" nil)
  (define-key dialog-mode-map "\C-z" nil)
  (define-key dialog-mode-map "\C-c" nil)
  (define-key dialog-mode-map "\C-h" nil)
  (define-key dialog-mode-map "\C-l" nil)
  (define-key dialog-mode-map "\C-g" nil)
  (define-key dialog-mode-map "\C-u" nil)
  ;; Some keys to capture only sometimes
  (define-key dialog-mode-map "\C-n" 'dialog-handle-kbd-maybe)
  (define-key dialog-mode-map "\C-p" 'dialog-handle-kbd-maybe)
  (define-key dialog-mode-map "\C-f" 'dialog-handle-kbd-maybe)
  (define-key dialog-mode-map "\C-b" 'dialog-handle-kbd-maybe)
  ;; Some keys in meta mat should not be overridden
  (define-key dialog-meta-map "x" nil)
  (define-key dialog-meta-map ":" nil)
  ;; Some keys have special meaning that we can grab at this level
  (define-key dialog-mode-map "\C-\M-n" 'dialog-next-widget)
  (define-key dialog-mode-map "\C-\M-p" 'dialog-prev-widget)
  (define-key dialog-mode-map "\C-i" 'dialog-next-widget)
  (define-key dialog-mode-map "\M-\t" 'dialog-prev-widget)
  (define-key dialog-mode-map "\C-r" 'dialog-refresh)

  ;; Differences between Xemacs and Emacs keyboard
  (if (string-match "XEmacs" emacs-version)
      (progn
	;; some translations into text
	(define-key dialog-mode-map 'tab 'dialog-next-widget)
	(define-key dialog-mode-map 'up 'dialog-handle-kbd-maybe)
	(define-key dialog-mode-map 'down 'dialog-handle-kbd-maybe)
	(define-key dialog-mode-map 'right 'dialog-handle-kbd-maybe)
	(define-key dialog-mode-map 'left 'dialog-handle-kbd-maybe)
	(define-key dialog-mode-map 'next 'dialog-handle-kbd-maybe)
	(define-key dialog-mode-map 'prev 'dialog-handle-kbd-maybe)

	;; Now some mouse events
	(define-key dialog-mode-map 'button2 'dialog-handle-mouse)
	)
    ;; some translations into text
    (define-key dialog-mode-map [tab] 'dialog-next-widget)
    (define-key dialog-mode-map [up] 'dialog-handle-kbd-maybe)
    (define-key dialog-mode-map [down] 'dialog-handle-kbd-maybe)
    (define-key dialog-mode-map [right] 'dialog-handle-kbd-maybe)
    (define-key dialog-mode-map [left] 'dialog-handle-kbd-maybe)
    (define-key dialog-mode-map [next] 'dialog-handle-kbd-maybe)
    (define-key dialog-mode-map [prev] 'dialog-handle-kbd-maybe)
    ;; Now some mouse events
    (define-key dialog-mode-map [mouse-2] 'dialog-handle-mouse)
    (define-key dialog-mode-map [down-mouse-2] 'dialog-handle-mouse)
    (define-key dialog-mode-map [drag-mouse-2] 'dialog-handle-mouse)
    ))
  
(defun dialog-load-color (sym l-fg l-bg d-fg d-bg &optional bold italic underline)
  "Create a color for SYM with a L-FG and L-BG color, or D-FG and
D-BG. Optionally make BOLD, ITALIC, or UNDERLINED if applicable.  If
the background attribute of the current frame is determined to be
light (white, for example) then L-FG and L-BG is used.  If not, then
D-FG and D-BG is used.  This will allocate the colors in the best
possible mannor.  This will allow me to store multiple defaults and
dynamically determine which colors to use."
  (let* ((params (frame-parameters))
	 (disp-res (if (fboundp 'x-get-resource)
		       (if dialog-xemacs-p
			   (x-get-resource ".displayType" "DisplayType" 'string)
			 (x-get-resource ".displayType" "DisplayType"))
		     nil))
	 (display-type
	  (cond (disp-res (intern (downcase disp-res)))
		((and (fboundp 'x-display-color-p) (x-display-color-p)) 'color)
		(t 'mono)))
	 (bg-res (if (fboundp 'x-get-resource)
		     (if dialog-xemacs-p
			 (x-get-resource ".backgroundMode" "BackgroundMode" 'string)
		       (x-get-resource ".backgroundMode" "BackgroundMode"))
		   nil))
	 (bgmode
	  (cond (bg-res (intern (downcase bg-res)))
		((and params 
		      (fboundp 'x-color-values)
		      (< (apply '+ (x-color-values
				    (cdr (assq 'background-color params))))
			 (/ (apply '+ (x-color-values "white")) 3)))
		 'dark)
		(t 'light)))		;our default
	 (set-p (function (lambda (face-name resource)
			    (if dialog-xemacs-p
				(x-get-resource 
				 (concat face-name ".attribute" resource)
				 (concat "Face.Attribute" resource)
				 'string)
			      (x-get-resource 
			       (concat face-name ".attribute" resource)
			       (concat "Face.Attribute" resource)))
			    )))
	 (nbg (cond ((eq bgmode 'dark) d-bg) 
		    (t l-bg)))
	 (nfg (cond ((eq bgmode 'dark) d-fg)
		    (t l-fg))))

    (if (not (eq display-type 'color))
	;; we need a face of some sort, so just make due with default
	(progn
	  (copy-face 'default sym)
	  (if bold (condition-case nil
		       (make-face-bold sym)
		     (error (message "Cannot make face %s bold!" 
				     (symbol-name sym)))))
	  (if italic (condition-case nil
			 (make-face-italic sym)
		       (error (message "Cannot make face %s italic!"
				       (symbol-name sym)))))
	  (set-face-underline-p sym underline)
	  )
      ;; make a colorized version of a face.  Be sure to check Xdefaults
      ;; for possible overrides first!
      (let ((newface (make-face sym)))
	;; For each attribute, check if it might already be set by Xdefaults
	(if (and nfg (not (funcall set-p (symbol-name sym) "Foreground")))
	    (set-face-foreground sym nfg))
	(if (and nbg (not (funcall set-p (symbol-name sym) "Background")))
	    (set-face-background sym nbg))
	
	(if bold (condition-case nil
		     (make-face-bold sym)
		   (error (message "Cannot make face %s bold!"
				       (symbol-name sym)))))
	(if italic (condition-case nil
		       (make-face-italic sym)
		     (error (message "Cannot make face %s italic!"
				     (symbol-name sym)))))
	(set-face-underline-p sym underline)
	))))

(dialog-load-color 'widget-default-face nil nil nil nil)
(dialog-load-color 'widget-box-face "gray30" nil "gray" nil)
(dialog-load-color 'widget-frame-label-face "red3" nil "#FFFFAA" nil nil t nil)
(dialog-load-color 'widget-focus-face "green4" nil "light green" nil t)
(dialog-load-color 'widget-arm-face nil "cyan" nil "cyan4")
(dialog-load-color 'widget-indicator-face "blue4" nil "cyan" nil t)
(dialog-load-color 'widget-text-face nil nil nil nil nil nil t)
(dialog-load-color 'widget-text-focus-face nil nil nil nil t nil t)
(dialog-load-color 'widget-text-button-face "black" "cyan" nil "blue3")

(defun dialog-mode ()
  "Major mode for interaction with widgets.  A widget is any of a number of
rectangular regions on the screen with certain visual effects, and user
actions.

All keystrokes are interpreted by the widget upon which the cursor
resides.  Thus SPC on a button activates it, but in a text field, it
will insert a space into the character string.

\\<dialog-mode-map>
Navigation commands:
  \\[dialog-next-widget]   - Move to next interactive widget
  \\[dialog-prev-widget] - Move to previous interactive widget
"
  (kill-all-local-variables)
  (setq mode-name "Dialog")
  (setq major-mode 'dialog-mode)
  (use-local-map dialog-mode-map)
  (setq widget-toplevel-shell 
	(widget-toplevel "topLevel" :parent t :rx 0 :x 0 :ry 1 :y 1))
  (message "Constructing Dialog...")
  (verify widget-toplevel-shell t)
  (run-hooks 'dialog-mode-hooks))

(defmacro dialog-with-writeable (&rest forms)
  "Allow the buffer to be writable and evaluate forms.  Turn read-only back
on when done."
  (list 'let '((dialog-with-writeable-buff (current-buffer)))
	'(toggle-read-only -1)
	(cons 'progn forms)
	'(save-excursion (set-buffer dialog-with-writeable-buff)
			 (toggle-read-only 1))))
(put 'dialog-with-writeable 'lisp-indent-function 0)

(defun dialog-refresh () "Refresh all visible widgets in this buffer"
  (interactive)
  (dialog-with-writeable
    (erase-buffer)
    (message "Geometry Management...")
    (verify-size widget-toplevel-shell)
    (message "Rendering Dialog...")
    (draw widget-toplevel-shell)))

(defun dialog-quit () "Quits a dialog."
  (bury-buffer))

(defun dialog-lookup-key (keymap coe)
  "Translate event COE into the command keybinding which sometimes
requires translation into arrays and things."
  (let ((cc (cond ((numberp coe)
		   (char-to-string coe))
		  ((stringp coe)
		   coe)
		  (t
		   (or (lookup-key function-key-map (make-vector 1 coe))
		       (make-vector 1 coe))))))
    (lookup-key keymap cc t)))

(defvar dialog-last-maybe-command nil
  "The last command run by `dialog-handle-kbd*' for tracking
last-command setting while running interpreted commands.")

(defun dialog-handle-kbd () "Read the last kbd event, and handle it."
  (interactive)
  (dialog-with-writeable
    (let ((dispatch (or (get-text-property (point) 'widget-object)
			widget-toplevel-shell)))
      (input dispatch (if last-input-char last-input-char last-input-event)))))

(defun dialog-handle-kbd-maybe ()
 "Read the last kbd event, and handle it. but only if a widget has
registered with this area of text, otherwise run the default keybinding."
  (interactive)
  (dialog-with-writeable
    (let ((dispatch (get-text-property (point) 'widget-object)))
      (if (and dispatch (oref dispatch handle-motion))
	  (input dispatch (if last-input-char last-input-char
			    last-input-event))
	(let ((command (dialog-lookup-key global-map
					  (if last-input-char last-input-char
					    last-input-event)))
	      (last-command (if (eq last-command 'dialog-handle-kbd-maybe)
				dialog-last-maybe-command)))
	  (command-execute command t)
	  (setq dialog-last-maybe-command command))))))

(defun dialog-handle-meta-kbd () "Read the last kbd event, and handle it as a meta key"
  (interactive)
  (dialog-with-writeable
    (let ((dispatch (or (get-text-property (point) 'widget-object)
			widget-toplevel-shell)))
      (input dispatch (if (numberp last-input-char)
			  (concat "\e" (char-to-string last-input-char))
			last-input-char)))))

(defun dialog-next-widget (arg) "Move cursor to next logical widget"
  (interactive "P")
  (choose-next-widget widget-toplevel-shell 
		      (cond ((null arg) 1)
			    ((listp arg) (car arg))
			    (t arg)))
  )

(defun dialog-prev-widget (arg) "Move cursor to next logical widget"
  (interactive "P")
  (choose-next-widget widget-toplevel-shell 
		      (cond ((null arg) -1)
			    ((listp arg) (- (car arg)))
			    (t (- arg))))

  )

(if (string-match "XEmacs" emacs-version)

    (defun dialog-mouse-event-p (event)
      "Return t if the event is a mouse related event"
      nil
      )

  (defun dialog-mouse-event-p (event)
    "Return t if the event is a mouse related event"
    (if (and (listp event)
	     (member (event-basic-type event)
		     '(mouse-1 mouse-2 mouse-3)))
	t
      nil))

  )

(defun dialog-handle-mouse (event) "Reads last mouse event, and handle it"
  (interactive "e")
  ;; First, check to see where the click is, and go there.  The cursor
  ;; will act as our in the widget fields.
  (mouse-set-point event)
  (dialog-with-writeable
    (let ((dispatch (or (get-text-property (point) 'widget-object)
			widget-toplevel-shell)))
      (input dispatch event))))

;;; Widget creation routines and convenience functions
(defmacro dialog-build-group (widget &rest forms)
  "This is similar to a `progn' where new WIDGET becomes the  default
parent for new widgets created within FORMS"
  (list 'let (list (list 'dialog-current-parent widget))
	(cons 'progn forms)))
(put 'dialog-build-group 'lisp-indent-function 1)

(defun create-widget (name class &rest resources)
  "Creates a dialog widget with name NAME of class CLASS.  The parent
will be defined from the current environment created by
`dialog-build-group'.  RESOURCES is a list to be passed tot he
CLASS routine.

  This function is current BACKWARD COMPATIBLE so that an optional 3rd
argument could be the parent widget, overriding any enviroment from
`dialog-build-group'.  This will be removed in future versions."
  (let* ((parent 
	  (if (and (object-p (car resources)) 
		   (obj-of-class-p (car resources) widget-group))
	      (prog1 (car resources)
		(setq resources (cdr resources)))
	    (or dialog-current-parent widget-toplevel-shell)))
	 (con (class-constructor class))
	 (new (apply con name resources))
	 )
    ;; add this child to the parent, which sets news parent field
    (add-child parent new)
    ;; call the verifier on this new widget.  Verify will transfor
    ;; construction values ('below, 'just-right, nil) into valid
    ;; values in pertinent fields by recursivly dropping from high
    ;; level widget restrictions to low-level widget restrictions
    (verify new t)
    new))

;; Not backward compatible because it didn't exist before
(defun create-widget-first (name class &rest resources)
  "Creates a dialog widget with name NAME of class CLASS.  The parent
will be defined from the current environment, and RESOURCES is a list
to be passed tot he CLASS routine."
  (let* ((con (class-constructor class))
	 (new (apply con name resources))
	 (parent (or dialog-current-parent widget-toplevel-shell)))
    ;; add this child to the parent, which sets news parent field
    (add-child parent new)
    ;; call the verifier on this new widget.  Verify will transfor
    ;; construction values ('below, 'just-right, nil) into valid
    ;; values in pertinent fields by recursivly dropping from high
    ;; level widget restrictions to low-level widget restrictions
    (verify new t)
    new))

(defun create-widget-parent (name class parent &rest resources)
  "Create a dialog widget with name NAME of class CLASS.  PARENT will
be the widget this new widget resides in, and RESOURCES is a list to
be passed to the CLASS routine"
  (let* ((con (class-constructor class))
	 (new (apply con name resources)))
    ;; add this child to the parent, which sets news parent field
    (add-child parent new)
    ;; call the verifier on this new widget.  Verify will transfor
    ;; construction values ('below, 'just-right, nil) into valid
    ;; values in pertinent fields by recursivly dropping from high
    ;; level widget restrictions to low-level widget restrictions
    (verify new t)
    new))

(defun create-widget-parent-first (name class parent &rest resources)
  "Create a dialog with name NAME of class CLASS.  PARENT will be the
widget this new widget resides in, and RESOURCES is a list to be
passed to the CLASS routine"
  ;;(message "Building Dialog... [%s]" name)
  (let* ((con (class-constructor class))
	 (new (apply con name resources)))
    ;; add this child to the parent, which sets news parent field
    (add-child parent new t)
    ;; call the verifier on this new widget.  Verify will transfor
    ;; construction values ('below, 'just-right, nil) into valid
    ;; values in pertinent fields by recursivly dropping from high
    ;; level widget restrictions to low-level widget restrictions
    (verify new t)
    new))

(defun transform-dataobject (thing-or-obj w dval fix)
  "Takes THING-OR-OBJ, and if it's a data-object, returns it,
otherwise create a new data object, and set it's initial value to
THING-OR-OBJ, and set its first watcher to W.  If THING-OR-OBJ is not
an object name id DVAL when created, also, if THING-OR-OBJ is nil,
and not some other value, then set it's value to DVAL instead.  If FIX
is nil, then return nil instead."
  (if (or (not (object-p thing-or-obj))
	  (not (child-of-class-p (object-class thing-or-obj) data-object)))
      (if fix
	  (let ((newo (data-object dval))
		(nl nil))
	    ;; Add this to widget
	    (add-reference newo w)
	    (if thing-or-obj
		(set-value newo thing-or-obj w)
	      (set-value newo dval w))
	    newo)
	nil)
    thing-or-obj))

(defun widget-lock-over (w)
  "Called by a widget which wishes to grab cursor until the 'drag or
'click event is recieved."
  (let ((event nil))
    (track-mouse
      (while (progn (setq event (read-event))
		    (or (mouse-movement-p event)
			(eq (car-safe event) 'switch-frame)))
	(if (eq (car-safe event) 'switch-frame)
	    nil
	  ;; (mouse-set-point event)
	  (motion-input w event)))
      (if event (mouse-set-point event)))))

;;
;; Special menu function designed for lists of various things.
;;
(defun dialog-list-2-menu (event title list &optional max)
  "Take a list and turn it into a pop-up menu.  It returns an index into
said list.  The list may have anything in it, and they need not be of the
same type."

  (let ((menu))
    (setq menu
	  (cons ""			; single frame
		(list
		 (let ((tail list)
		       (head nil)
		       (i 1))
		   (cons title
			 (progn
			   (while (and tail (or (not max) (<= i max)))
			     (setq head (cons
					 (cons
					  (format "%s" 
						  ; go to smallest element
						  (let ((elt (car tail)))
						    (while (listp elt)
						      (setq elt (car elt)))
						    elt))
					  i)
					 head))
			     (setq i (1+ i))
			     (setq tail (cdr tail)))
			   (reverse head)))))))
    (let ((n (x-popup-menu event menu)))
      (if (integerp n)
	  (1- n)			;the nth starts at 0, we must start
					;at 1, or the first elt returns nil
	nil))))

(defun goto-xy (x y)
  "Move cursor to position X Y in buffer, and add spaces and CRs if
needed."
  (if (eq major-mode 'dialog-mode)
      (let ((indent-tabs-mode nil)
	    (num (goto-line y)))
	(if (and (= 0 num) (/= 0 (current-column))) (newline 1))
	(if (eobp) (newline num))
	;; Now, a quicky column moveto/forceto method.
	(if (/= (move-to-column x) x)
	    (let ((pnt (point)) (end nil))
	      (indent-to x)
	      (setq end (point))
	      (if (and (/= pnt end) (fboundp 'put-text-property))
		  (progn
		    (put-text-property pnt end 'face nil)
		    (put-text-property pnt end 'mouse-face nil))))))))
  
(defun insert-overwrite-face (string face &optional focus-face object)
  "Insert STRING into buffer at point, and cover it with FACE.  If
optional FOCUS-FACE, then also put this as the mouse-face.  If
optional OBJECT is included, then put that down as the text property
`widget-object' so that we can do faster lookups while dishing out
keystrokes, etc."
  (if widget-toplevel-shell
      (let* ((pnt (point))
	     (end (+ pnt (length string))))
	(goto-char pnt)
	(insert string)
	(if (eobp) (save-excursion (insert "\n"))) ;always make sure there's a blank line
	(if (> (length string) (- (save-excursion (end-of-line) (point))
				  (point)))
	    (delete-region (point) (save-excursion (end-of-line) (point)))
	  (delete-char (length string)))
	(if (fboundp 'put-text-property)
	    (progn
	      (if face (put-text-property pnt end 'face face))
	      (if focus-face (put-text-property pnt end 'mouse-face focus-face))
	      (if object (put-text-property pnt end 'widget-object object))
	      )))))

(defun dialog-widget-tree-primitive ()
  "Displays the current dialog box's widget tree in another buffer"
  (interactive)
  (if (not widget-toplevel-shell) (error "Can't generate widget tree from this buffer"))
  (let ((mytls widget-toplevel-shell))
    (display-buffer (get-buffer-create "*WIDGET BROWSE*") t)
    (save-excursion
      (set-buffer (get-buffer "*WIDGET BROWSE*"))
      (erase-buffer)
      (goto-char 0)
      (dialog-browse-tree mytls "" "")
      )))

(defun dialog-browse-tree (this-root prefix ch-prefix)
  "Recursive part of browser, draws the children of the given class on
the screen."
  (if (not (object-p this-root)) (signal 'wrong-type-argument (list 'object-p this-root)))
  (let ((myname (object-name this-root))
	(chl (if (obj-of-class-p this-root widget-group)
		 (get-children this-root) 
	       nil))
	(fprefix (concat ch-prefix "  +--"))
	(mprefix (concat ch-prefix "  |  "))
	(lprefix (concat ch-prefix "     ")))
    (insert prefix)
    (if (not (and window-system (fboundp 'make-overlay)))
	(insert myname)
      (let ((no (make-overlay (point) (progn (insert myname) (point)))))
	(overlay-put no 'face 'bold)))
    (if t
	(insert "\n")
      (if chl
	  (if (= (length chl) 1)
	      (insert (format " -- [1 child]\n"))
	    (insert (format " -- [%d children]\n" (length chl))))
	(insert (format " -- [No children]\n"))))
    (while (cdr chl)
      (dialog-browse-tree (car chl) fprefix mprefix)
      (setq chl (cdr chl)))
    (if chl
	(dialog-browse-tree (car chl) fprefix lprefix))
    ))

(defun dialog-test ()
  "Creates a test dialog using as many widget features as currently works."
  (interactive)
  (switch-to-buffer (get-buffer-create "Dialog Test"))
  (toggle-read-only -1)
  (erase-buffer)
  (dialog-mode)
  (let ((mytog (data-object "MyTog" :value t)))

    (create-widget "Fred" widget-label :face 'modeline 
		   :x 10
		   :label-value "This is a label\non several lines separated by \\n\nto make distinctions")

    (dialog-build-group (create-widget "Push Button Frame" widget-frame
				       :frame-label "Push Button Window"
				       ;; :box-sides [ nil t nil t ]
				       :position 'left-bottom)
      (create-widget "Click" widget-push-button
		     :y 1 :label-value "Quit"
		     :box-face 'font-lock-comment-face
		     :activate-hook (lambda (obj reason) "Activate Quit Button"
				      (message "Quit!")
				      (dialog-quit)))
      (create-widget "Clack" widget-push-button
		     :x -10 :y t :label-value "Widget\nTree"
		     :box-face 'font-lock-comment-face
		     :activate-hook (lambda (obj reason) "Draw a widget tree"
				      (dialog-widget-tree-primitive)))
      (create-widget "Cluck" widget-push-button
		     :x -5 :y t :label-value "Class\nTree"
		     :box-face 'font-lock-comment-face
		     :activate-hook (lambda (obj reason) "Draw a widget tree"
				      (eieio-browse)))
      (create-widget "Clunk" widget-push-button
		     :x -5 :y t :label-value "About\nDialog Mode"
		     :box-face 'font-lock-comment-face
		     :activate-hook (lambda (obj reason) "Draw a widget tree"
				      (describe-function
				       'dialog-mode))))
    (dialog-build-group (create-widget "Togg Frame" widget-frame
				       :frame-label "Toggle Tests..."
				       ;;:box-sides [ t nil t nil ]
				       :position 'center-top
				       :box-face 'font-lock-reference-face)
      (create-widget "Togg" widget-toggle-button
		     :label-value "Toggle Me"
		     :face 'underline  :ind-face 'highlight
		     :state mytog
		     :activate-hook (lambda (obj reason) "Switcharoo!"
				      (message "Changed value")))
      (create-widget "Forceon" widget-push-button
		     :x -6 :y t :label-value "Turn On"
		     :activate-hook 
		     (list 'lambda '(obj reason) "Flip Tog"
			   (list 'set-value mytog t)))
      (create-widget "Forceoff" widget-push-button
		     :x -6 :y t :label-value "Turn Off"
		     :face 'underline
		     :activate-hook
		     (list 'lambda '(obj reason) "Flip Tog"
			   (list 'set-value mytog nil))))
      
    (dialog-build-group (create-widget "Radio Frame" widget-radio-frame
				       :frame-label "Radio tests"
				       :position 'right-top)
      
      (create-widget "radio 1" widget-radio-button
		     :label-value "First nifty option")
      
      (create-widget "radio 2" widget-radio-button
		     :label-value "Second nifty option")

      (create-widget "radio 3" widget-radio-button
		     :label-value "Third nifty option")
      )

    (create-widget "some-stuff" widget-option-button
		   :face 'italic
		   :option-list '("Moose" "Dog" "Cat" "Mouse" "Monkey" "Penguin")
		   )
    (create-widget "MyText" widget-text-field
		   :width 20 :value "My First String")
    (create-widget "MyTextGroup" widget-labeled-text
		   :text-length 20 :value "My Composite String"
		   :label "Named String:" :unit "chars")
    )
  (dialog-refresh)
  (goto-char (point-min))
  )

;;; end of lisp
(provide 'dialog)
