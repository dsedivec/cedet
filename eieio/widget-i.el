;;; widget-i.el - simulate widgets in emacs text window
;;;
;;; Copyright (C) 1995,1996 Eric M. Ludlam
;;;
;;; Author: <zappo@gnu.ai.mit.edu>
;;; Version: 0.4
;;; RCS: $Id$
;;; Keywords: OO widget
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
;;;      
;;; This requires the widget definition file (widget-d) and supplies
;;; the functionality behind all the classes by defining their
;;; methods.  All mundane repetitive work is done in dialog.el. (Such
;;; as creating buffers, modes, and the top-level shell.)
;;;           
         
(require 'eieio)			;objects
(require 'widget-d)			;widget definitions
       
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 
;;; Data-Object method definitions
;;;      
(defmethod add-reference ((this data-object) widget)
  "Adds WIDGET to the list of widgets currently referencing THIS"
  ;; Add to our list
  (if (not (member widget (oref this reference)))
      (oset this reference (cons widget (oref this reference)))))

(defmethod set-value ((this data-object) value &optional setter)
  "Set the value field of ourselves to VALUE"
  (if (not (equal (oref this value) value))
      (let ((refs (oref this reference)))
	(oset this value value)
	;; (message "Value of %s changed to %S" (object-name this) value)
	;; Now update everyone observing us, if setter is an object,
	;; make sure we don't call thier update function.
	(while refs
	  (if (not (equal (car refs) setter))
	      (let ((pnt (point)))
		(update-symbol (car refs) this)
		(goto-char pnt)))
	  (setq refs (cdr refs))))))

(defmethod render ((this data-object))
  "Return a string which represents the RENDERED version of our value.
To render anything in emacs, we have to turn it into a string, so this
is ok."
  (let ((v (oref this value)))
    (cond ((stringp v) v)
	  (t (format "%S" v)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Widget method definitions
;;;

;;
;; Core
;;
(defmethod verify ((this widget-core) fix)
  "Verifies that fields in the CORE part are correct.  If FIX, then
fixable fields are adjusted, otherwise an error occurs."
  (if (and (not (oref this parent)) 
	   (not (equal (oref this parent) t)))
      (error "%s has no parent!" (object-name this)))
  )

(defmethod verify-position ((this widget-core) prev)
  "Sets all the size parameters for THIS to be correct in the rx/ry cache
fields for a visual widget.  No action is take for CORE"
  nil
  )

(defmethod update-symbol ((this widget-core) sym)
  "Backup for update-symbol so we don't get errors if it's not defined for some 
broken reason."
  ;; (message "No symbols used in this widget")
  )


;;
;; visual
;;
(defmethod verify ((this widget-visual) fix)
  "Verifies a visual widget to make sure it's values are allowed.  If
FIX then fix fields which are adjustable.  Call core verify when
done."
  ;; Now make sure core parts are valid
  (call-next-method))

(defmethod verify-position ((this widget-visual) prev)
  "Sets all the size parameters for THIS to be correct in the rx/ry cache
fields for a visual widget.  Uses PREV as the widget just previous to us
in widget order."
  ;; If X or Y is a symbol like AFTER then determine it's value
  ;; Use -2 to find last item because THIS has recently been added.
  ;; Subtract one from new value so -1 means the line directly under
  ;; the last toggle we added.
  
  ;; We will find and install LO, even though it may not always be used
  ;; to speed up dynamically created widgets.
  (let ((px (if prev (oref prev nx) 1))
	(pw (if prev (oref prev width) 0))
	(py (if prev (oref prev ny) 1))
	(ph (if prev (oref prev height) 0))
	(pb (if prev (oref prev boxed) nil))
	(pbs (if prev (oref prev box-sides) [ nil nil nil nil ]))
	(b  (oref this boxed))
	(bs (oref this box-sides))
	(tx (or (oref this x) 1))
	(ty (oref this y)))

    (if (eq tx t)
	(setq tx px)
      (if (listp tx)
	  (setq tx (eval tx))
	(if (> 0 tx)
	    (if prev
		(setq tx (+ px pw -1 (- tx) (if (and b (aref bs 0)) 1 0)
			    (if (and pb (aref pbs 1)) 1 0)))
	      (setq tx 1)))))

    (if (not ty)
	(progn
	  (if prev
	      (if (same-class-p this (object-class prev))
		  (setq ty -1)
		(setq ty -2))
	    (setq ty (if (and (oref this boxed) (aref (oref this box-sides) 2))
			 1 0)))
	  (oset this y ty)))

    (if (eq ty t)
	(setq ty py)
      (if (listp ty)
	  (setq ty (eval ty))
	(if (> 0 ty)
	    (if prev
		(setq ty (+ py ph -1 (- ty) (if (and b (aref bs 2)) 1 0)
			    (if (and pb (aref pbs 3)) 1 0)))
	      (setq ty 1)))))

    ;; Fix up RX and RY with parent coords, and our normalized coordinates
    (if (and (object-p (get-parent this))
	     (object-p (get-parent this))
	     (oref (get-parent this) rx))
	(progn
	  (oset this nx tx)
	  (oset this rx (+ tx (oref (get-parent this) rx)))
	  (oset this ny ty)
	  (oset this ry (+ ty (oref (get-parent this) ry)))
	  )
      (if (object-p (get-parent this))
	  (progn
	    (message "Parent %s rx is %s %s" 
		     (object-name (get-parent this))
		     (oref (get-parent this) rx)
		     (oref (get-parent this) ry))
	    (error "Could not set real XY positions for object %s"
		   (object-name this))))))
    (call-next-method))

(defmethod picked ((this widget-visual) x y)
  "Is this widget picked under X Y"
  nil)


;;
;; square
;;
(defmethod draw ((this widget-square))
  "Draw handles border drawing.  Is just able to draw a box, which
goes OUTSIDE the size specification of the widget itself, and does not
count when being picked."
  ;; Draw a box around ourselves
  (if (oref this boxed)
      (let* ((br (concat (char-to-string (aref (oref this box-char) 0))
			 (make-string (oref this width) (aref (oref this box-char) 4))			 
			 (char-to-string (aref (oref this box-char) 1))))
	     (lr (concat (char-to-string (aref (oref this box-char) 2))
			 (make-string (oref this width) (aref (oref this box-char) 5))
			 (char-to-string (aref (oref this box-char) 3))))
	     (s (oref this box-sides))
	     (yc 0)
	     (x (oref this rx))
	     (y (oref this ry)))
	;; We don't store ourselves on top of the box because we don't want
	;; to recieve input.
	(if (aref s 2) 
	    (progn
	      (goto-xy (1- x) (1- y))
	      (insert-overwrite-face br (oref this box-face))))
	(while (< yc (oref this height))
	  (if (aref s 0)
	      (progn
		(goto-xy (1- x) (+ y yc))
		(insert-overwrite-face (char-to-string (aref (oref this box-char) 6))
				       (oref this box-face))))
	  (if (aref s 1)
	      (progn
		(goto-xy (+ x (oref this width)) (+ y yc))
		(insert-overwrite-face (char-to-string (aref (oref this box-char) 7))
				       (oref this box-face))))
	  (setq yc (1+ yc)))
	(if (aref s 3)
	    (progn
	      (goto-xy (1- x) (+ y (oref this height)))
	      (insert-overwrite-face lr (oref this box-face)))))))

(defmethod move-cursor-to ((this widget-square))
  "Move the cursor so that it sits at a useful location inside this widget"
  (goto-xy (oref this rx)
	   (+ (oref this ry) (if (> (oref this height) 1) 1 0))))

(defmethod picked ((this widget-square) x y)
  "Return t if X,Y lies within a square defined by our attributes"
  (let ((mod 0))
    (if (oref this boxed)
	(setq mod 1))
    (and (oref this handle-io)
	 (>= x (- (oref this rx) mod))
	 (< x (+ (oref this rx) (oref this width) mod))
	 (>= y (- (oref this ry) mod))
	 (< y (+ (oref this ry) (oref this height) mod)))))

(defmethod move ((this widget-square) x y)
  "Move ourselves to position X Y"
  (oset this x x)
  (oset this y y)
  (verify this t)
  (draw this))

(defmethod resize ((this widget-square) width height)
  "Resize ourselves to dimentions width height"
  (oset this width width)
  (oset this height height)
  (verify this t)
  (draw this))


;;
;; group
;;
(defmethod verify ((this widget-group) fix)
  "Verifies that a group widget has valid values in dynamic fields"
  ;; make sure our size is set...
  (if (not (oref this width)) (oset this width 0))
  (if (not (oref this height)) (oset this height 0))
  ;; verify our other parts
  (call-next-method)
  )

(defmethod verify-size ((this widget-group))
  "Verify our current size to make shure that our size is correct
based on the number of children we have."
  (let ((maxw (oref this width))
	(maxh (oref this height))
	(l (oref this child-list))
	(prev nil))
    (while l
      (verify-position (car l) prev)
      (if (obj-of-class-p (car l) widget-group)
	  (verify-size (car l)))
      (let ((tw (+ (oref (car l) nx) (oref (car l) width) 1))
	    (th (+ (oref (car l) ny) (oref (car l) height) 
		   ;; vertical space is valueable. Only give extra space
		   ;; for boxed widgets.
		   (if (and (oref (car l) boxed) (aref (oref (car l) box-sides) 3))
		       1 0))))
	(if (< maxw tw) (setq maxw tw))
	(if (< maxh th) (setq maxh th)))
      (setq prev (car l)
	    l (cdr l)))
    (oset this width maxw)
    (oset this height maxh)))

(defmethod add-child ((this widget-group) child &optional first)
  "Add widget CHILD to our personal list of child widgets"
  ;; Add to our list
  (oset this child-list (if first
			    (cons child (oref this child-list))
			  (append (oref this child-list) (list child))))
  ;; make sure we are marked as that widgets parent.  To do this, we
  ;; must cheat so that THIS is set to child, and then we may set that
  ;; widgets field, and the scoped class to allow us access to private
  ;; field.  *THIS IS A CHEAT - Should implement Friends!*
  (let ((me this) (scoped-class (object-class child)) (this child))
    (oset child parent me))
  ;; We must make sure the toplevel shell can correctly maintain it's
  ;; navigation list
  (clear-navigation-list widget-toplevel-shell)
  )

(defmethod input ((this widget-group) char-or-event)
  "Handles the input event char-or-event by passing it to it's
children.  If it is passed to a child, return t, else return nil"
  ;; New methodology no longer necessitates input dispatch from this level
  )
  ;;(input (selected-widget this) char-or-event))

(defmethod selected-widget ((this widget-group))
  "Return the widget who is currently selected within myself, as well
as the next logical widget after myself"
  (let ((x (current-column))
	(y (count-lines (point-min) (point)))
	(lop (oref this child-list))
	(found nil)
	)
    ;; find the child who has been clicked
    (while (and lop (not found))
      (if (not (picked (car lop) x y))
	  nil
	(setq found (car lop)))
      (setq lop (cdr lop)))
    found))

(defmethod draw ((this widget-group))
  "Draw the basic group widget.  Basically all our children, with
their X,Y offset by our X,Y"
  ;;draw any visuals we have
  (call-next-method)
  ;; draw our children
  (let ((kids (oref this child-list)))
    (while kids
      (if (obj-of-class-p (car kids) widget-visual)
	  (draw (car kids)))
      (sit-for 0)
      (setq kids (cdr kids))
      ))
  ;; (message "Done...")
  )

(defmethod first-io-widget ((this widget-group))
  "Return the first widget which can handle IO in THIS"
  (let ((kids (oref this child-list)))
    (while (and kids (not (oref (car kids) handle-io)))
      (setq kids (cdr kids)))
    (car kids)))
 

(defmethod build-navigation-list ((this widget-group))
  "Called by the toplevel shell to create a navigation list.  It's
recursive so all group members need it.  Returns a logical list of
widgets in the order they should be navigated by.  A navigation list
is always in reverse order for speed."
  (let ((newlist nil)
	(kids (oref this child-list)))
    (while kids
      (if (oref (car kids) handle-io)
	  (if (obj-of-class-p (car kids) widget-group)
	      (setq newlist (append 
			     (build-navigation-list (car kids))
			     newlist))
	    (setq newlist (cons (car kids) newlist))))
      (setq kids (cdr kids)))
    newlist))

;;
;; top level shells
;;
(defmethod clear-navigation-list ((this widget-toplevel))
  "Clear the current navigation list so it will be re-built later."
  (oset this logical-child-list nil)
  )

(defmethod get-navigation-list ((this widget-toplevel))
  "For this object, return the navigation list, or build the
navigation list, and store it in ourselves for future reference as a
vector for fast access if it doesn't exist"
  ;; short curcuit or returns first non-nil member
  (or (oref this logical-child-list)
      (oset this logical-child-list 
	    (let* ((ml (build-navigation-list this))
		   (nl nil)
		   (c (1- (length ml))))
	      ;; this process reverses the navigation list, and
	      ;; associates each object with it's index
	      (while ml
		(setq nl (cons (list (car ml) c) nl)
		      ml (cdr ml)
		      c (1- c)))
	      nl))
      ))

(defmethod choose-next-widget ((this widget-toplevel) &optional arg)
  "There will be a currently selected widget.  This command will cycle
to the ARGth widget in some direction."
  ;; first, find our widget association
  (let ((cw (selected-widget this))
	(navlist (get-navigation-list this)))
    (if (not cw) (setq arg 0
		       cw (car (car navlist))))
    ;; loop down over all groups
    (while (obj-of-class-p cw widget-group)
      (let ((tcw (selected-widget cw)))
	(if tcw 
	    (setq cw tcw)
	  ;; if we get no hits, choose the first in the
	  ;; currently selected group
	  (setq arg 0
		cw (first-io-widget cw)))))
    ;; We have now definitly selected a widget of some sort, so move
    ;; there by overscanning our navigation list.
    (move-cursor-to
     (let* ((al (assoc cw navlist))
	    (len (length navlist))
	    (nai (+ (nth 1 al) arg)))
       (if (not al)
	   (error "Oops!")
	 (if (> 0 nai)
	     (setq nai (+ nai len))
	   (if (<= len nai)
	       (setq nai (- nai len)))))
       (car (nth nai navlist)))))
  )


;;
;; frame
;;
(defmethod verify ((this widget-frame) fix)
  "Verify a frame widget"
  ;; If no frame label is specified, then use this object's name
  (if (eq t (oref this frame-label))	;t means use the object's name
      (oset this frame-label (object-name-string this)))
  ;; call parent's verify first to set our position, etc
  (call-next-method))

(defmethod verify-size ((this widget-frame))
  "Verify the size of the frame.  First we find out how big we are based
on our children, then we create our label widget once this information
is known."
  (call-next-method)			;find out our size
  ;; now fix up our label...
  (let* ((tol (oref this frame-label))
	 (lw (if (and (object-p tol) 
		      (obj-of-class-p tol widget-label))
		 ;; it's already a label of some sort
		 tol
	       (if (and (not (stringp tol)))
		   ;; it's not a string
		   nil
		 ;; Its a string... make a label of some sort
		 (save-match-data
		   (let* ((posstr (symbol-name (oref this position)))
			  (nlw (create-widget-parent-first
				(format "label on %s" (object-name this))
				widget-label this 
				:label-value tol
				:face 'widget-frame-label-face
				:justification
				(cond 
				 ((string-match "center" posstr)
				  'center)
				 ((string-match "right" posstr)
				  'right)
				 (t
				  'left))
				:x (cond 
				    ((string-match "center" posstr)
				     (/ (- (oref this width)
					   (length tol))
					2))
				    ((string-match "right" posstr)
				     (- (oref this width)
					(length tol)
					2))
				    (t
				     2))
				:y (if (string-match "top" posstr)
				       '(- 1)
				     (oref this height)))))
		     (verify-position nlw nil)
		     nlw))))))
    (if (and lw (> (length (render (oref lw label-value))) (oref this width)))
	(oset this width (+ 2 (length tol))))
    (if lw (oset this frame-label lw))))

;;
;; radio frame
;;
(defmethod verify ((this widget-radio-frame) fix)
  "Verify a frame widget"
  ;; call parent's verify first to set our position, etc
  (call-next-method)  
  ;; now make sure our state is really an integer.
  (let ((lv (transform-dataobject (oref this state) this "RadioIndex" fix)))
    (if lv
	(oset this state lv)
      (error "State variable for toggle %s is not a data-object!"
	     (object-name this)))))

(defmethod add-child ((this widget-radio-frame) child &optional first)
  "Add widget CHILD which must be a radio button to ourselves"
  ;; check for radioness.  Labels are ok too.
  (if (not (or (obj-of-class-p child widget-radio-button) first))
      (error "Widget %s is not a radio button!" (object-name child)))
  ;; really do the add
  (call-next-method)
  )


;;
;; widget-labeled-text
;;

(defmethod verify ((this widget-labeled-text) fix)
  "Initilize the `widget-labeled-text' class with the pre-determined widgets
in a standard format."
  (call-next-method)
  (let ((lo (if (oref this label)
		(transform-dataobject (oref this label) this 
				      (concat (object-name this) "-label-data")
				      fix)
	      nil))	    
	(uo (if (oref this unit)
		(transform-dataobject (oref this unit) this 
				      (concat (object-name this) "-unit-data")
				      fix))))
    (if (get-children this)
	nil
      ;; If we have no children ,create some.
      (if lo
	  (create-widget-parent (concat (object-name this) "-label")
				widget-label this
				:x 0 :y 0 :label-value lo))
      (create-widget-parent (concat (object-name this) "-text-field")
			    widget-text-field this
			    :width (oref this text-length)
			    :x (if lo -2 0) :y 0 :value (oref this value))
      (if uo
	  (create-widget-parent (concat (object-name this) "-unit")
				widget-label this
				:x -2 :y 0 :label-value uo))
      )
    (let ((tv (transform-dataobject (oref this value) this 
				    (concat (object-name this) "-text-value")
				    fix)))
      (if tv (oset this value tv)
	(error "Text value not a data object")))
    ))

;;
;; label
;;
(defmethod verify ((this widget-label) fix)
  "Verify the label widget's componants."
  ;; Do we even have a label value?  If not invent one
  (if (not (oref this label-value))
      (oset this label-value (object-name-string this)))
  ;; Make sure the label-value is a data object
  (let ((lv (transform-dataobject  (oref this label-value) this
				   (object-name this) fix)))
    (if lv
	(oset this label-value lv)
      (error "Label value for %s is not a data-object!" (object-name this))))
  ;; Convert our label string into substrings
  (label-break-into-substrings this)
  ;; If no width/height, try to set them
  (if (not (oref this width))
      (if fix
	  (let ((lv (oref this label-list))
		(long 0))
	    (while lv
	      (if (> (length (car lv)) long)
		  (setq long (length (car lv))))
	      (setq lv (cdr lv)))
	    (oset this width (+ long
				(oref this leftmargin)
				(oref this rightmargin))))
	(error "Label %s width is invalid" (object-name this))))
  (if (not (oref this height))
      (if fix
	  (oset this height (+ (length (oref this label-list)) 
			       (oref this topmargin) 
			       (oref this bottommargin)))
	(error "Label %s height is invalid" (object-name this))))
  ;; Now verify the rest
  (call-next-method))

(defmethod label-break-into-substrings ((this widget-label))
  "Takes the label-value from the dataobject, and transforms it into a list
of substrings which was separated by carriage returns."
  (let ((txt (render (oref this label-value)))
	(newlst nil))
    (if (not (stringp txt)) (error "label-widget must have string label"))
    (while txt
      (if (string-match "\n" txt)
	  (setq newlst (cons (substring txt 0 (match-beginning 0))
			     newlst)
		txt (substring txt (match-end 0)))
	(setq newlst (cons txt newlst)
	      txt nil)))
    (oset this label-list (reverse newlst))
    ))

(defmethod draw ((this widget-label))
  "Refresh a label widget.  Calculate centering style, then display the
String to optimally fill that area."
  (let* ((x (+ (oref this rx) (oref this leftmargin)))
	 (tx x)
	 (y (+ (oref this ry) (oref this topmargin)))
	 (w (- (oref this width) (oref this leftmargin) (oref this rightmargin)))
	 (h (- (oref this height) (oref this topmargin) (oref this bottommargin)))
	 (ll (oref this label-list))
	 (ns (length ll))
	 ;; (ds (render (oref this label-value)))
	 (s 0)
	 (j (oref this justification)))
    (setq y (+ y (/ (- h ns) 2)))
;    (if (> s w)
;	(progn
;	  (setq ds (substring ds 0 w))
;	  (setq s (length ds))))
    (while ll
      (setq s (length (car ll)))
      ;; First, clear anything that might be in the way
      (goto-xy x y)
      (insert-overwrite-face (make-string w ? ) nil (oref this focus-face) this)
      ;; Now find the centering mechanism, and draw the string
      (cond ((eq j 'center)
	     (setq tx (+ x (/ (- w s) 2))))
	    ((eq j 'right)
	     (setq tx (+ x (- w s))))
	    ((eq j 'left)
	     )
	    (t (error "Internal label error")))
      (goto-xy tx y)
      (insert-overwrite-face (car ll) (oref this face) (oref this focus-face) this)
      (setq ll (cdr ll)
	    y (1+ y))
      ))
  (call-next-method))

(defmethod input ((this widget-label) coe)
  "Handle IO for a label"  (ding t))


;;
;; button
;;
(defmethod verify ((this widget-button) fix)
  "Verify button parameters"
  ;; Now verify the rest
  (call-next-method))

(defmethod show-arm ((this widget-button) onoff &optional mouse)
  "Show the arming of the widget based on ONOFF"
  (let ((pnt (point)))
    (if onoff
	(let ((oface (oref this face)))
	  (if mouse
	      (oset this focus-face (oref this arm-face))
	    (oset this face (oref this arm-face)))
	  (draw this)
	  (if mouse
	      (oset this focus-face oface)
	    (oset this face oface)))
      (draw this))
    (goto-char pnt)))

(defmethod input ((this widget-button) coe)
  "What to do if clicked upon by the mouse"
  (if (dialog-mouse-event-p coe)
      (let ((omf (oref this focus-face)))
	(unwind-protect
	    (let ((cb (current-buffer)))
	      (show-arm this t t)
	      (widget-lock-over this)	;visually display arming
	      (let ((x (current-column))
		    (y (count-lines (point-min) (point)))
		    (ob (oref this boxed)))
		(unwind-protect
		    (progn
		      (oset this boxed nil)
		      (if (picked this x y)
			  (cond
			   ((member 'down-mouse-1 coe)
			    (active-actions this 'click))
			   ((member 'down-mouse-2 coe)
			    (active-actions this 'click))
			   ((member 'down-mouse-3 coe)
			    (help-actions this 'click)))))
		  (oset this boxed ob)))
	      (oset this focus-face omf)
	      (if (equal (current-buffer) cb)
		  (show-arm this nil t)))))
    (if (member coe '(return ?  ?\n ?\f))
	(progn
	  (show-arm this t)
	  (active-actions this coe)
	  (show-arm this nil))
      (message "RET or SPC to activate button!"))))

(defmethod motion-input ((this widget-button) coe)
  "What do do with motion events from widget-lock-over function"
  ;; buttons don't do anything special
)

(defmethod active-actions ((this widget-button) reason)
  "Called when activated to handle any special cases for child widgets"
  (if (oref this activate-hook)
      (funcall (oref this activate-hook) this reason)))

(defmethod help-actions ((this widget-button) reason)
  "Called when 3rd mouse button is clicked upon a button.  Will display
help about this widget."
  (if (oref this help-hook)
      (funcall (oref this help-hook) this reason)
    (message "Click with mouse-1 to active this button.")))

(defmethod draw ((this widget-button))
  "Draw the button widget to the display"
  ;; now draw the label part
  (call-next-method))

;;;
;;; Push Button
;;;
(defmethod verify ((this widget-push-button) fix)
  "Verify a push button's parameters"
  (call-next-method)
  ;; Now that the size is defined, change the box if we are too big
  (if (and (> (oref this height) 1) fix)
      (progn
	(oset this box-char [?+ ?+ ?+ ?+ ?- ?- ?| ?|])
	(oset this box-sides [ t t t t ]))))


;;
;; Option Button
;;
(defmethod verify ((this widget-option-button) fix)
  "Verify an option button's parameters"
  ;; Verify my state button
  (let ((lv (transform-dataobject (oref this state) this "OptionIndex" fix)))
    (if lv
	(progn
	  (oset this state lv)
	  (add-reference lv this))
      (error "State variable for toggle %s is not a data-object!"
	     (object-name this))))
  ;; Find longest string in option list and fill in the obarray
  (let* ((ol (oref this option-list))
	 (sz 0)
	 (oa (make-vector (length ol) 0)))
    (while ol
      (if (> (length (car ol)) sz) (setq sz (length (car ol))))
      (intern (car ol) oa)
      (setq ol (cdr ol)))
    (oset this option-obarray oa)
    (oset this width (+ sz (length (oref this option-indicator)) 1)))
  ;; create the special left margin
  (oset this leftmargin (1+ (length (oref this option-indicator))))
  ;; Make sure we install the right label string
  (oset this label-value (nth (get-value (oref this state))
			      (oref this option-list)))
  ;; Now verify the rest
  (call-next-method))

(defmethod draw ((this widget-option-button))
  "Draws a option button to the display"
  (if (eq major-mode 'dialog-mode)
      (save-excursion
	;; now draw the indicator
	(goto-xy (oref this rx) (oref this ry))
	(insert-overwrite-face (oref this option-indicator) 
			       (oref this ind-face) 
			       (oref this focus-face)
			       this)
	(insert-overwrite-face " " nil (oref this focus-face) this)
	;; draw the rest
	(call-next-method))))

(defmethod input ((this widget-option-button) coe)
  "What to do if clicked upon by the mouse"
  (if (dialog-mouse-event-p coe)
      (if (or (member 'down-mouse-3 coe)
	      (member 'mouse-3 coe))
	  (help-actions this 'click)
	(let ((rv (dialog-list-2-menu coe "Options" (oref this option-list))))
	  (if rv (set-value (oref this state) rv this))
	  (reset-option-label this)
	  (show-arm this nil)))
    (cond ((member coe '(return ?  ?\n ?\f))
	   (show-arm this t)
	   (let* ((nv (completing-read "Select Value: " 
				       (oref this option-obarray) nil t 
				       (nth (get-value (oref this state))
					    (oref this option-list)))))
	     (set-value (oref this state) 
			(- (length (oref this option-list))
			   (length (member nv (oref this option-list))))
			this)
	     (reset-option-label this))
	   (show-arm this nil))
	  ((member coe '(up down "\M-n" "\C-[n" "\M-p" "\C-[p"))
	   (let ((len (length (oref this option-list)))
		 (nv (get-value (oref this state))))
	     (cond ((member coe '(up "\M-p" "\C-[p"))
		    (setq nv (1- nv)))
		   ((member coe '(down "\M-n" "\C-[n"))
		    (setq nv (1+ nv))))
	     (cond ((< nv 0)
		    (setq nv (1- len)))
		   ((>= nv len)
		    (setq nv 0)))
	     (set-value (oref this state) nv)
	     (reset-option-label this))
	   (show-arm this nil))
	  (t
	   (message "RET or SPC to activate button, UP or DOWN to cycle options")))))

(defmethod reset-option-label ((this widget-option-button))
  "Reset the label on THIS widget."
  (set-value (oref this label-value)
	     (nth (get-value (oref this state)) (oref this option-list))
	     this)
  (label-break-into-substrings this))

(defmethod move-cursor-to ((this widget-option-button))
  "Move the cursor so that it sits at a useful location inside this widget"
  (goto-xy (+ (oref this rx) (length (oref this option-indicator)))
	   (+ (oref this ry) (if (> (oref this height) 1) 1 0))))

(defmethod help-actions ((this widget-option-button) reason)
  "Called when 3rd mouse button is clicked upon a button.  Will display
help about this widget."
  (if (oref this help-hook)
      (funcall (oref this help-hook) this reason)
    (message "Click with mouse-1 and choose menu item to select a new value")))



;;
;; Toggle Button
;;

(defmethod verify ((this widget-toggle-button) fix)
  "Verifies that a toggle button correctly represented."
  ;; Verify my state button
  (let ((lv (transform-dataobject (oref this state) this "Boolean" fix)))
    (if lv
	(progn
	  (oset this state lv)
	  (add-reference lv this))
      (error "State variable for toggle %s is not a data-object!"
	     (object-name this)))
    (if (stringp (get-value lv))
	(if fix (set-value lv nil this))))
  ;; create the special left margin
  (oset this leftmargin (1+ (length (aref (oref this showvec) 0))))
  ;; Verify parent class members
  (call-next-method))

(defmethod update-symbol ((this widget-toggle-button) sym)
  "If sym is STATE field, then update ourselves"
  (save-excursion
    (if (eq sym (oref this state))
	(draw this)
      (call-next-method))))

(defmethod draw ((this widget-toggle-button))
  "Draws a toggle button to the display"
  ;; now draw the indicator
  (let* ((val1 (oref this state))
	 (val2 (get-value val1)))
    (goto-xy (oref this rx) (oref this ry))
    (insert-overwrite-face (aref (oref this showvec) (if val2 1 0))
			   (oref this ind-face) (oref this focus-face) this)
    (insert-overwrite-face " " nil (oref this focus-face) this))
  ;; draw the rest
  (call-next-method))

(defmethod move-cursor-to ((this widget-toggle-button))
  "Move the cursor so that it sits at a useful location inside this widget"
  (goto-xy (+ (oref this rx) (length (aref (oref this showvec) 0)) 1)
	   (+ (oref this ry) (if (> (oref this height) 1) 1 0))))

(defmethod active-actions ((this widget-toggle-button) reason)
  "When the button part is activated, then we must toggle our state"
  ;; Set our state
  (if (get-value (oref this state))
      (set-value (oref this state) nil this)
    (set-value (oref this state) t this))
  ;; do our parents version
  (call-next-method))

(defmethod help-actions ((this widget-toggle-button) reason)
  "Called when 3rd mouse button is clicked upon a button.  Will display
help about this widget."
  (if (oref this help-hook)
      (funcall (oref this help-hook) this reason)
    (message "Click with mouse-1 to change the boolean value of this button.")))

;;
;; radio toggle button
;;
(defmethod verify ((this widget-radio-button) fix)
  "Verifies that a radio toggle button correctly represented."
  ;; find my position in my parent
  (let ((p (oref this parent)))
    (if (obj-of-class-p p widget-radio-frame)
	(oset this radio-index (- (length (get-children p)) 1))
      (error "Object %s must have parent type `widget-radio-frame'"
	     (object-name this))))
  ;; find my parent's state
  (let* ((p (oref this parent))
	 (ps (oref p state)))
    (oset this parent-state ps)
    (if (and fix (= (get-value ps) (oref this radio-index)))
	(if (object-p (oref this state))
	    (set-value (oref this state) t)
	  (oset this state t)))
    (add-reference ps this))
  ;; Verify parent class members (create my own state variable)
  (call-next-method))


(defmethod update-symbol ((this widget-radio-button) sym)
  "If sym is STATE field, then update ourselves"
  (let ((ps (oref this parent-state)))
    (if (eq sym ps)
	(radio-set-display this)
      (call-next-method))))

(defmethod radio-set-display ((this widget-radio-button))
  "Check our parent's display, and set our own state based on this."
  (set-value (oref this state) 
	     (if (= (get-value (oref this parent-state))
		    (oref this radio-index))
		 t nil)))

(defmethod active-actions :AFTER ((this widget-radio-button) reason)
  "After toggling behavior, always reset to whatever our parent state
thinks we should be."
  (if (get-value (oref this state))
      (set-value (oref this parent-state) (oref this radio-index) this)
  (radio-set-display this)))

(defmethod help-actions ((this widget-radio-button) reason)
  "Called when 3rd mouse button is clicked upon a button.  Will display
help about this widget."
  (if (oref this help-hook)
      (funcall (oref this help-hook) this reason)
    (message "Click with mouse-1 to change the state of the radio box.")))


;;
;; Scale
;;
(defmethod verify ((this widget-scale) fix)
  "Verifies the scale widget is ok."
  ;; make sure that the scale state is ok
  (let ((tv (transform-dataobject (oref this state) this "ScaleState" fix)))
    (if tv
	(progn
	  (if (not (numberp (get-value tv)))
	      (set-value tv 0))
	  (oset this state tv)
	  (add-reference tv this))
      (error "Scale value for %s is not a number" (object-name this))))
  ;; make sure that the scale max is ok
  (let ((tv (transform-dataobject (oref this maximum) this "ScaleMax" fix)))
    (if tv
	(progn
	  (oset this maximum tv)
	  (add-reference tv this))
      (error "Scale value for %s is not a number" (object-name this))))
  ;; make sure that the scale min is ok
  (let ((tv (transform-dataobject (oref this minumum) this "ScaleMin" fix)))
    (if tv
	(progn
	  (oset this minimum tv)
	  (add-reference tv this))
      (error "Scale value for %s is not a number" (object-name this))))
  ;; Check sizes
  (let ((length (+ (get-value (oref this maximum)) 
		  (if (oref this end-buttons) 2 0)))
	(w (oref this width))
	(h (oref this height)))
    (cond ((eq (oref this direction) 'horizontal)
	   (if (not w) (oset this width length))
	   (if (not h) (oset this height 1))
	   )
	  ((eq (oref this direction) 'vertical)
	   (if (not w) (oset this width 1))
	   (if (not h) (oset this height length))
	   )
	  (t
	   (error "Value %S for field direction in %s invalid"
		  (oref this direction)
		  (object-name this)))))
  ;; Verify parent parts
  (call-next-method)
  )

(defmethod draw ((this widget-scale))
  "Draws a scale widget"
  )


;;
;; Text
;;

(defmethod verify ((this widget-text-field) fix)
  "Verifies the text widget is ok"
  ;; verify the textual value as a data-object
  (let ((tv (transform-dataobject (oref this value) this "TextPart" fix)))
    (if tv
	(progn
	  (if (not (stringp (get-value tv)))
	      (set-value tv ""))
	  (oset this value tv)
	  (add-reference tv this))
      (error "Text field value for %s is not a data-object."
	     (object-name this))))
  ;; now set the keymap we will use
  (if (not (oref this keymap))
      (if fix
	  (oset this keymap (make-sparse-keymap))))
  ;; Verify parent class members
  (call-next-method))

(defmethod draw ((this widget-text-field))
  "Render's a text widget onto the display"
  (let* ((myto (oref this value))
	 (myts (get-value myto))
	 (tlen (oref this width))
	 (os (substring myts (oref this disppos)))
	 (nflag nil)
	 (sflag nil)
	 )  
    (goto-xy (1- (oref this rx)) (oref this ry))
    ;; check for characters off to the left
    (insert-overwrite-face (if (> (oref this disppos) 0) "<" " ")
			   (oref this spface) this)
    ;; check for newline inside string
    (if (string-match "\\(\n\\)" os)
	(setq nflag t
	      sflag nil
	      os (substring os 0 (match-beginning 1))))
    ;; check for string too long
    (if (> (length os) tlen)
	(setq sflag t
	      os (substring os 0 tlen)))
    ;; see if string is too short
    (if (< (length os) tlen)
	(setq os (concat os (make-string (- tlen (length os)) ? ))))
    ;; insert the string
    (insert-overwrite-face os (oref this face) (oref this focus-face) this)
    ;; show more-characters this way strings
    (if nflag (insert-overwrite-face "v" (oref this spface))
      (if sflag (insert-overwrite-face ">" (oref this spface))
	(insert-overwrite-face " " (oref this spface)))))
  (call-next-method)
  )

(defmethod move-cursor-to ((this widget-text-field))
  "Move the cursor so that it sits at a useful location inside this widget"
  (goto-xy (oref this rx)
	   (oref this ry)))

(defmethod update-symbol ((this widget-text-field) sym)
  "If sym is STATE field, then update ourselves"
  (if (eq sym (oref this value))
      (draw this)
    (call-next-method)))

(defmethod input ((this widget-text-field) coe)
  "Handle user input events in the text field"
  ;; first find out if we will be doing any edits at all
  (let ((com (dialog-lookup-key global-map coe)))
    (if (and com (fboundp com))
	;; In this case, we have a one-keystroke edit
	(let ((cp (- (current-column) (oref this rx)))
	      (mo (oref this value))
	      (mv nil)
	      (rp nil)
	      ;; make sure no new lines are added
	      (next-line-add-newlines nil))
	  ;; do the simulated edit in a seperate buffer
	  (save-window-excursion
	    (switch-to-buffer (get-buffer-create "*Text Widget Scratch*") t)
	    (erase-buffer)
	    (insert (get-value mo))
	    (goto-char (+ cp (oref this disppos) 1))
	    (command-execute com)
	    (setq rp (1- (point)))
	    (setq mv (buffer-string)))
	  ;; reposition disppos based on cursor position
	  (if (and (/= (oref this disppos) 0)
		   (>= (oref this disppos) rp))
	      (let ((newsize (if (< (- rp 1) 0) 0 (- rp 1))))
		(oset this disppos newsize)))
	  (if (>= (1+ rp) (+ (oref this disppos) (oref this width)))
	      (let ((newsize  (- rp (oref this width) -2)))
		(oset this disppos newsize)))
	  ;; Now redraw the text if needed
	  (save-excursion
	    (set-value mo mv this)
	    (draw this))
	  ;; place the cursor
	  (goto-xy (+ (oref this rx) (- rp (oref this disppos)))
		   (oref this ry))
	  ;; make sure the value changed, then call the hook.
	  ))))

;;; end of lisp
(provide 'widget-i)
