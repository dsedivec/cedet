;;; ede-pconf.el --- configure.in maintenance for EDE


;; This is incomplete and non-function!



;;  Copyright (C) 1998, 1999  Eric M. Ludlam

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
;; Code generator for autoconf configure.in, and support files.

;;; Code:
(defmethod ede-proj-configure-create ((this ede-proj-project))
  "Create or edit a configure script based on project THIS.
Does simple things like maintain the version number, or create one
for users who do not know how to use autoconf."
  ;; We assume that the hueristic of wether to make a configure
  ;; script or not was handled in the top-level makefile.
  (find-file "configure.in")
  ;; Go into creation mode if this file doesn't exist.
  (if (= (point-min) (point-max))
      (progn
	;; Create mode!
	(insert
	 "dnl configure.in --- autoconf program file.\n"
	 "dnl\n"
	 "dnl Automatically generated by EDE.\n"
	 "dnl\n\n"
	 "AC_INIT(" (car (oref (car (oref this targets)) sources)) ")\n"
	 "AM_INIT_AUTOMAKE(" (ede-name this) ", " (oref this version) ")\n")
	;; Figure out what condition this is!
	(if t (insert "AM_CONFIG_HEADER(config.h)\n\n"))
	;; Insert some basic C stuff if we have a C file around.
	;; PUT CHECK HERE!
	(insert
	 "dnl Standard programs and things\n"
	 "dnl AC_PROG_CC\n"
	 "dnl AC_ISC_POSIX\n"
	 "dnl AC_PROG_MAKE_SET\n"
	 "dnl AC_PROG_INSTALL\n"
	 "\n"
	 "dnl AC_ISC_POSIX\n")
	;; Insert the trailer here
	(insert
	 "dnl end and make time-stamp"
	 "AC_OUTPUT(Makefile")
	;; Insert the names of all other files that are build w/ configure.
	(ede-map-subprojects this
			     (lambda (sp)
			       ;; Generate path relative to root, and then
			       ;; stick in the makefile.
			       ))
	;; Finish it off
	(insert ", [date > stamp-h] )\n")
	)
    ;; Edit existing mode!
    )
  )


(provide 'ede-pconf)

;;; ede-pconf.el ends here
