;;; speedbar --- quick access to files and tags -*-byte-compile-warnings:nil;-*-

;; Copyright (C) 1996, 1997 Eric M. Ludlam
;;
;; Author: Eric M. Ludlam <zappo@gnu.ai.mit.edu>
;; Version: 0.5.1
;; Keywords: file, tags, tools
;; X-RCS: $Id$
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
;; Please send bug reports, etc. to zappo@gnu.ai.mit.edu.
;;

;;; Commentary:
;;
;;   The speedbar provides a frame in which files, and locations in
;; files are displayed.  These items can be clicked on with mouse-2
;; in order to make the last active frame display that file location.
;;
;;   To use speedbar, add this to your .emacs file:
;;
;;   (autoload 'speedbar-frame-mode "speedbar" "Popup a speedbar frame" t)
;;   (autoload 'speedbar-get-focus "speedbar" "Jump to speedbar frame" t)
;;
;;   If you want to choose it from a menu or something, do this:
;;
;;   (define-key-after (lookup-key global-map [menu-bar tools])
;;      [speedbar] '("Speedbar" . speedbar-frame-mode) [calendar])
;;
;;   If you want to access speedbar using only the keyboard, do this:
;;
;;   (define-key global-map [f4] 'speedbar-get-focus)
;;
;;   This will let you hit f4 (or whatever key you choose) to jump
;; focus to the speedbar frame.  Pressing RET or e to jump to a file
;; or tag will move you back to the attached frame.  The command
;; `speedbar-get-fucus' will also create a speedbar frame if it does
;; not exist.
;;
;;   Once a speedbar frame is active, it takes advantage of idle time
;; to keep it's contents updated.  The contents is usually a list of
;; files in the directory of the currently active buffer.  When
;; applicable, tags in the active file can be expanded.
;;
;;   To add new supported files types into speedbar, use the function
;; `speedbar-add-supported-extension' If speedbar complains that the
;; file type is not supported, that means there is no built in
;; support from imenu, and the etags part wasn't set up correctly.  You
;; may add elements to `speedbar-supported-extension-expressions' as long
;; as it is done before speedbar is loaded.
;;
;;   To prevent speedbar from following you into certain directories
;; use the function `speedbar-add-ignored-path-regexp' too add a new
;; regular expression matching a type of path.  You may add list
;; elements to `speedbar-ignored-path-expressions' as long as it is
;; done before speedbar is loaded.
;;
;;   To add new file types to imenu, see the documentation in the
;; file imenu.el that comes with emacs.  To add new file types which
;; etags supports, you need to modify the variable
;; `speedbar-fetch-etags-parse-list'.
;;
;;    If the updates are going too slow for you, modify the variable
;; `speedbar-update-speed' to a longer idle time before updates.
;;
;;    If you navigate directories, you will probably notice that you
;; will navigate to a directory which is eventually replaced after
;; you go back to editing a file (unless you pull up a new file.)
;; The delay time before this happens is in
;; `speedbar-navigating-speed', and defaults to 10 seconds.
;;
;;    XEmacs users may want to change the default timeouts for
;; `speedbar-update-speed' to something longer as XEmacs doesn't have
;; idle timers, the speedbar timer keeps going off arbitrarily while
;; you're typing.  It's quite pesky.
;;
;;    Users of emacs previous to to v 19.31 (when idle timers
;; where introduced) will not have speedbar updating automatically.
;; Use "r" to refresh the display after changing directories.
;; Remember, do not interrupt the stealthy updates or you display may
;; not be completely refreshed.
;;
;;    See optional file `speedbspec.el' for additional configurations
;; which allow speedbar to create specialized lists for special modes
;; that are not file-related.
;;
;;    See optional file `speedbcfg.el' for interactive buffers
;; allowing simple configuration of colors and features of speedbar.
;;
;;    AUC-TEX users: The imenu tags for AUC-TEX mode don't work very
;; well.  Use the imenu keywords from tex-mode.el for better results.
;;
;; This file requires the library package assoc (association lists)

;;; Speedbar updates can be found at:
;; ftp://ftp.ultranet.com/pub/zappo/speedbar*.tar.gz
;;

;;; Change log:
;; 0.1   Initial Revision
;; 0.2   Fixed problem with x-pointer-shape causing future frames not
;;         to be created.
;;       Fixed annoying habit of `speedbar-update-contents' to make
;;         it possible to accidentally kill the speedbar buffer.
;;       Clicking directory names now only changes the contents of
;;         the speedbar, and does not cause a dired mode to appear.
;;         Clicking the <+> next to the directory does cause dired to
;;         be run.
;;       Added XEmacs support, which means timer support moved to a
;;         platform independant call.
;;       Added imenu support.  Now modes are supported by imenu
;;         first, and etags only if the imenu call doesn't work.
;;         Imenu is a little faster than etags, and is more emacs
;;         friendly.
;;       Added more user control variables described in the commentary.
;;       Added smart recentering when nodes are opened and closed.
;; 0.3   x-pointer-shape fixed for emacs 19.35, so I put that check in.
;;       Added invisible codes to the beginning of each line.
;;       Added list aproach to node expansion for easier addition of new
;;         types of things to expand by
;;       Added multi-level path name support
;;       Added multi-level tag name support.
;;       Only mouse-2 is now used for node expansion
;;       Added keys e + - to edit expand, and contract node lines
;;       Added longer legal file regexp for all those modes which support
;;         imenu. (pascal, fortran90, ada, pearl)
;;       Added pascal support to etags from Dave Penkler <dave_penkler@grenoble.hp.com>
;;       Fixed centering algorithm
;;       Tried to choose background independent colors.  Made more robust.
;;       Rearranged code into a more logical order
;; 0.3.1 Fixed doc & broken keybindings
;;       Added mode hooks.
;;       Improved color selection to be background mode smart
;;       `nil' passed to `speedbar-frame-mode' now toggles the frame as
;;         advertised in the doc string
;; 0.4a  Added modified patch from Dan Schmidt <dfan@lglass.com> allowing a
;;         directory cache to be maintained speeding up revisiting of files.
;;       Default raise-lower behavior is now off by default.
;;       Added some menu items for edit expand and contract.
;;       Pre 19.31 emacsen can run without idle timers.
;;       Added some patch information from Farzin Guilak <farzin@protocol.com>
;;         adding xemacs specifics, and some etags upgrades.
;;       Added ability to set a faces symbol-value to a string
;;         representing the desired foreground color.  (idea from
;;         Farzin Guilak, but implemented differently)
;;       Fixed problem with 1 character buttons.
;;       Added support for new Imenu marker technique.
;;       Added `speedbar-load-hooks' for things to run only once on
;;         load such as updating one of the many lists.
;;       Added `speedbar-supported-extension-expressions' which is a
;;         list of extensions that speedbar will tag.  This variable
;;         should only be updated with `speedbar-add-supported-extension'
;;       Moved configure dialog support to a separate file so
;;         speedbar is not dependant on eieio to run
;;       Fixed list-contraction problem when the item was at the end
;;         of a sublist.
;;       Fixed XEmacs multi-frame timer selecting bug problem.
;;       Added `speedbar-ignored-modes' which is a list of major modes
;;         speedbar will not follow when it is displayed in the selected frame
;; 0.4   When the file being edited is not in the list, and is a file
;;         that should be in the list, the speedbar cache is replaced.
;;       Temp buffers are now shown in the attached frame not the
;;         speedbar frame
;;       New variables `speedbar-vc-*' and `speedbar-stealthy-function-list'
;;         added.  `speedbar-update-current-file' is now a member of
;;         the stealthy list.  New function `speedbar-check-vc' will
;;         examine each file and mark it if it is checked out.  To
;;         add new version control types, override the function
;;         `speedbar-this-file-in-vc' and `speedbar-vc-check-dir-p'.
;;         The stealth list is interruptible so that long operations
;;         do not interrupt someones editing flow.  Other long
;;         speedbar updates will be added to the stealthy list in the
;;         future should interesting ones be needed.
;;       Added many new functions including:
;;         `speedbar-item-byte-compile' `speedbar-item-load'
;;         `speedbar-item-copy' `speedbar-item-rename' `speedbar-item-delete'
;;         and `speedbar-item-info'
;;       If the user kills the speedbar buffer in some way, the frame will
;;         be removed.
;; 0.4.1 Bug fixes
;;       <mark.jeffries@nomura.co.uk> added `speedbar-update-flag',
;;         XEmacs fixes for menus, and tag sorting, and quit key.
;;       Modeline now updates itself based on window-width.
;;       Frame is cached when closed to make pulling it up again faster.
;;       Speedbars window is now marked as dedicated.
;;       Added bindings: <grossjoh@charly.informatik.uni-dortmund.de>
;;       Long directories are now span multiple lines autmoatically
;;       Added `speedbar-directory-button-trim-method' to specify how to
;;         sorten the directory button to fit on the screen.
;; 0.4.2 Add one level of full-text cache.
;;       Add `speedbar-get-focus' to switchto/raise the speedbar frame.
;;       Editing thing-on-line will auto-raise the attached frame.
;;       Bound `U' to `speedbar-up-directory' command.
;;       Refresh will now maintain all subdirectories that were open
;;        when the refresh was requested.  (This does not include the
;;        tags, only the directories)
;; 0.4.3 Bug fixes
;; 0.4.4 Added `speedbar-ignored-path-expressions' and friends.
;;       Configuration menu items not displayed if dialog-mode not present
;;       Speedbar buffer now starts with a space, and is not deleted
;;        ewhen the speedbar frame is closed.  This prevents the invisible
;;        frame from preventing buffer switches with other buffers.
;;       Fixed very bad bug in the -add-[extension|path] functions.
;;       Added `speedbar-find-file-in-frame' which will always pop up a frame
;;        that is already display a buffer selected in the speedbar buffer.
;;       Added S-mouse2 as "power click" for always poping up a new frame.
;;        and always rescanning with imenu (ditching the imenu cache), and
;;        always rescanning directories.
;; 0.4.5 XEmacs bugfixes and enhancements.
;;       Window Title simplified.
;; 0.4.6 Fixed problems w/ dedicated minibuffer frame.
;;       Fixed errors reported by checkdoc.
;; 0.5   Mode-specific contents added.  Controlled w/ the variable
;;         `speedbar-mode-specific-contents-flag'.  See speedbspec
;;         for info on enabling this feature.
;;       `speedbar-load-hook' name change and pointer check against
;;         major-mode.  Suggested by Sam Steingold <sds@ptc.com>
;;       Quit auto-selects the attached frame.
;;       Ranamed `speedbar-do-updates' to `speedbar-update-flag'
;;       Passes checkdoc.
;; 0.5.1 Advice from ptype@dra.hmg.gb:
;;          Use `post-command-idle-hook' in older emacsen
;;         `speedbar-sort-tags' now works with imenu.
;;          Unknown files (marked w/ ?) can now be operated on w/
;;            file commands.
;;       `speedbar-vc-*-hook's for easilly adding new version control systems.
;;       Checkin/out w/ vc will reset the scanners and update the * marker.
;;       Fixed ange-ftp require compile time problem.
;;       Fixed XEmacs menu bar bug.
;;       Added `speedbar-activity-change-focus-flag' to control if the
;;         focus changes w/ mouse events.
;;       Added `speedbar-sort-tags' toggle to the menubar.
;;       Added `speedbar-smart-directory-expand-flag' to toggle how
;;         new directories might be inserted into the speedbar hierarchy.
;;       Added `speedbar-visiting-[tag|file]hook' which is called whenever
;;         speedbar pulls up a file or tag in the attached frame.  Setting
;;         this to `reposition-window' will do nice things to function tags.
;;       Fixed text-cache default-directory bug.

;;; TODO:
;; - More functions to create buttons and options
;; - filtering algoritms to reduce the number of tags/files displayed.
;; - Timeout directories we haven't visited in a while.
;; - Remeber tags when refreshing the display.  (Refresh tags too?)
;; - More 'special mode support.
;; - C- Mouse 3 menu too much indirection

(require 'assoc)
(require 'easymenu)

;;; Code:
(defvar speedbar-xemacsp (string-match "XEmacs" emacs-version)
  "Non-nil if we are running in the XEmacs environment.")

(defvar speedbar-initial-expansion-list
  '(speedbar-directory-buttons speedbar-default-directory-list)
  "List of functions to call to fill in the speedbar buffer.
Whenever a top level update is issued all functions in this list are
run.  These functions will always get the default directory to use
passed in as the first parameter, and a 0 as the second parameter.
The 0 indicates the uppermost indentation level.  They must assume
that the cursor is at the position where they start inserting
buttons.")

(defvar speedbar-stealthy-function-list
  '(speedbar-update-current-file speedbar-check-vc)
  "List of functions to periodically call stealthily.
Each function must return nil if interrupted, or t if completed.
Stealthy functions which have a single operation should always return
t.  Functions which take a long time should maintain a state (where
they are in their speedbar related calculations) and permit
interruption.  See `speedbar-check-vc' as a good example.")

(defvar speedbar-mode-specific-contents-flag t
  "*Non-nil means speedbar will show specail-mode contents.
This permits some modes to create customized contents for the speedbar
frame.")

(defvar speedbar-special-mode-expansion-list nil
  "Mode specific list of functions to call to fill in speedbar.
Some modes, such as Info or RMAIL, do not relate quite as easily into
a simple list of files.  When this variable is non-nil and buffer-local,
then these functions are used, creating specialized contents.  These
functions are called each time the speedbar timer is called.  This
allows a mode to update it's contents regularly.

  Each function is called with the default and frame belonging to
speedbar, and with one parameter; the buffer requesting
the speedbar display.")

(defvar speedbar-visiting-file-hook nil
  "Hooks run when speedbar visits a file in the selected frame.")

(defvar speedbar-visiting-tag-hook nil
  "Hooks run when speedbar visits a tag in the selected frame.")

(defvar speedbar-load-hook nil
  "Hooks run when speedbar is loaded.")

(defvar speedbar-desired-buffer nil
  "Non-nil when speedbar is showing buttons specific a special mode.
In this case it is the originating buffer.")

(defvar speedbar-show-unknown-files nil
  "*Non-nil show files we can't expand with a ? in the expand button.
nil means don't show the file in the list.")

;; Xemacs timers aren't based on idleness.  Therefore tune it down a little
;; or suffer mightilly!
(defvar speedbar-update-speed (if speedbar-xemacsp 5 1)
  "*Idle time in seconds needed before speedbar will update itself.
Updates occur to allow speedbar to display directory information
relevant to the buffer you are currently editing.")
(defvar speedbar-navigating-speed 10
  "*Idle time to wait after navigation commands in speedbar are executed.
Navigation commands included expanding/contracting nodes, and moving
between different directories.")

(defvar speedbar-frame-parameters (list
				   ;; Xemacs fails to delete speedbar
				   ;; if minibuffer is off.
				   ;(cons 'minibuffer
				   ; (if speedbar-xemacsp t nil))
				   ;; The above behavior seems to have fixed
				   ;; itself somewhere along the line.
				   ;; let me know if any problems arise.
				   '(minibuffer . nil)
				   '(width . 20)
				   '(scroll-bar-width . 10)
				   '(border-width . 0)
				   '(unsplittable . t) )
  "*Parameters to use when creating the speedbar frame.
Parameters not listed here which will be added automatically are
`height' which will be initialized to the height of the frame speedbar
is attached to.  To add more frame defaults, `cons' new alist members
onto this variable through the `speedbar-load-hook'")

(defvar speedbar-use-imenu-flag (stringp (locate-library "imenu"))
  "*Non-nil means use imenu for file parsing.  nil to use etags.
XEmacs doesn't support imenu, therefore the default is to use etags
instead.  Etags support is not as robust as imenu support.")

(defvar speedbar-sort-tags nil
  "*If Non-nil, sort tags in the speedbar display.")

(defvar speedbar-activity-change-focus-flag nil
  "*Non-nil means the selected frame will change based on activity.
Thus, if a file is selected for edit, the buffer will appear in the
selected frame and the focus will change to that frame.")

(defvar speedbar-directory-button-trim-method 'span
  "*Indicates how the directory button will be displayed.
Possible values are:
 'span - span large directories over multiple lines.
 'trim - trim large directories to only show the last few.
 nil   - no trimming.")

(defvar speedbar-smart-directory-expand-flag t
  "*Non-nil means speedbar should use smart expansion.
When smart expansion is enabled, then if speedbar is asked to display
a new buffers location which is not in the current directory
hierarchy, but it could be added, then it will be.")

(defvar speedbar-before-popup-hook nil
  "*Hooks called before popping up the speedbar frame.")

(defvar speedbar-before-delete-hook nil
  "*Hooks called before deleting the speedbar frame.")

(defvar speedbar-mode-hook nil
  "*Hooks called after creating a speedbar buffer.")

(defvar speedbar-timer-hook nil
  "*Hooks called after running the speedbar timer function.")

(defvar speedbar-verbosity-level 1
  "*Verbosity level of the speedbar.  0 means say nothing.
1 means medium level verbosity.  2 and higher are higher levels of
verbosity.")

(defvar speedbar-vc-indicator " *"
  "*Text used to mark files which are currently checked out.
Currently only RCS is supported.  Other version control systems can be
added by examining the function `speedbar-this-file-in-vc' and
`speedbar-vc-check-dir-p'")

(defvar speedbar-vc-do-check t
  "*Non-nil check all files in speedbar to see if they have been checked out.
Any file checked out is marked with `speedbar-vc-indicator'")

(defvar speedbar-vc-path-enable-hook nil
  "*Return non-nil if the current path should be checked for Version Control.
Functions in this hook must accept one paramter which is the path
being checked.")

(defvar speedbar-scanner-reset-hook nil
  "*Hook called whenever generic scanners are reset.
Set this to implement your own scanning / rescan safe functions with
state data.")

(defvar speedbar-vc-in-control-hook nil
  "*Return non-nil if the specified file is under Version Control.
Functions in this hook must accept two paramters.  The PATH of the
current file, and the FILENAME of the file being checked.")

(defvar speedbar-vc-to-do-point nil
  "Local variable maintaining the current version control check position.")

(defvar speedbar-ignored-modes nil
  "*List of major modes which speedbar will not switch directories for.")

(defvar speedbar-ignored-path-expressions
  '("/log/$")
  "*List of regular expressions matching directories speedbar will ignore.
They should included paths to directories which are notoriously very
large and take a long time to load in.  Use the function
`speedbar-add-ignored-path-regexp' to add new items to this list after
speedbar is loaded.  You may place anything you like in this list
before speedbar has been loaded.")

(defvar speedbar-file-unshown-regexp
  (let ((nstr "") (noext completion-ignored-extensions))
    (while noext
      (setq nstr (concat nstr (regexp-quote (car noext)) "$"
			 (if (cdr noext) "\\|" ""))
	    noext (cdr noext)))
    (concat nstr "\\|#[^#]+#$\\|\\.\\.?$"))
  "*Regexp matching files we don't want displayed in a speedbar buffer.
It is generated from the variable `completion-ignored-extensions'")

(defvar speedbar-supported-extension-expressions
  (append '(".[CcHh]\\(++\\|pp\\|c\\|h\\)?" ".tex\\(i\\(nfo\\)?\\)?"
	    ".el" ".emacs" ".p" ".java")
	  (if speedbar-use-imenu-flag
	      '(".f90" ".ada" ".pl" ".tcl" ".m"
		"Makefile\\(\\.in\\)?")))
  "*List of regular expressions which will match files supported by tagging.
Do not prefix the `.' char with a double \\ to quote it, as the period
will be stripped by a simplified optimizer when compiled into a
singular expression.  This variable will be turned into
`speedbar-file-regexp' for use with speedbar.  You should use the
function `speedbar-add-supported-extension' to add a new extension at
runtime, or use the configuration dialog to set it in your .emacs
file.")

(defun speedbar-extension-list-to-regex (extlist)
  "Takes EXTLIST, a list of extensions and transforms it into regexp.
All the preceding . are stripped for an optimized expression starting
with . followed by extensions, followed by full-filenames."
  (let ((regex1 nil) (regex2 nil))
    (while extlist
      (if (= (string-to-char (car extlist)) ?.)
	  (setq regex1 (concat regex1 (if regex1 "\\|" "")
			       (substring (car extlist) 1)))
	(setq regex2 (concat regex2 (if regex2 "\\|" "") (car extlist))))
      (setq extlist (cdr extlist)))
    ;; concat all the sub-exressions together, making sure all types
    ;; of parts exist during concatination.
    (concat "\\("
	    (if regex1 (concat "\\(\\.\\(" regex1 "\\)\\)") "")
	    (if (and regex1 regex2) "\\|" "")
	    (if regex2 (concat "\\(" regex2 "\\)") "")
	    "\\)$")))

(defvar speedbar-ignored-path-regexp
  (speedbar-extension-list-to-regex speedbar-ignored-path-expressions)
  "Regular expression matching paths speedbar will not switch to.
Created from `speedbar-ignored-path-expressions' with the function
`speedbar-extension-list-to-regex' (A misnamed function in this case.)
Use the function `speedbar-add-ignored-path-regexp' to modify this
variable.")

(defvar speedbar-file-regexp
  (speedbar-extension-list-to-regex speedbar-supported-extension-expressions)
  "Regular expression matching files we know how to expand.
Created from `speedbar-supported-extension-expression' with the
function `speedbar-extension-list-to-regex'")

(defun speedbar-add-supported-extension (extension)
  "Add EXTENSION as a new supported extension for speedbar tagging.
This should start with a `.' if it is not a complete file name, and
the dot should NOT be quoted in with \\.  Other regular expression
matchers are allowed however.  EXTENSION may be a single string or a
list of strings."
  (if (not (listp extension)) (setq extension (list extension)))
  (while extension
    (if (member (car extension) speedbar-supported-extension-expressions)
	nil
      (setq speedbar-supported-extension-expressions
	    (cons (car extension) speedbar-supported-extension-expressions)))
    (setq extension (cdr extension)))
  (setq speedbar-file-regexp (speedbar-extension-list-to-regex
			      speedbar-supported-extension-expressions)))

(defun speedbar-add-ignored-path-regexp (path-expression)
  "Add PATH-EXPRESSION as a new ignored path for speedbar tracking.
This function will modify `speedbar-ignored-path-regexp' and add
PATH-EXPRESSION to `speedbar-ignored-path-expressions'."
  (if (not (listp path-expression))
      (setq path-expression (list path-expression)))
  (while path-expression
    (if (member (car path-expression) speedbar-ignored-path-expressions)
	nil
      (setq speedbar-ignored-path-expressions
	    (cons (car path-expression) speedbar-ignored-path-expressions)))
    (setq path-expression (cdr path-expression)))
  (setq speedbar-ignored-path-regexp (speedbar-extension-list-to-regex
				      speedbar-ignored-path-expressions)))

(defvar speedbar-update-flag (or (fboundp 'run-with-idle-timer)
				 (fboundp 'start-itimer)
				 (boundp 'post-command-idle-hook))
  "*Non-nil means to automatically update the display.
When this is nil then speedbar will not follow the attached frame's path.
When speedbar is active, use:

\\<speedbar-key-map> `\\[speedbar-toggle-updates]'

to toggle this value.")

(defvar speedbar-syntax-table nil
  "Syntax-table used on the speedbar.")

(if speedbar-syntax-table
    nil
  (setq speedbar-syntax-table (make-syntax-table))
  ;; turn off paren matching around here.
  (modify-syntax-entry ?\' " " speedbar-syntax-table)
  (modify-syntax-entry ?\" " " speedbar-syntax-table)
  (modify-syntax-entry ?( " " speedbar-syntax-table)
  (modify-syntax-entry ?) " " speedbar-syntax-table)
  (modify-syntax-entry ?[ " " speedbar-syntax-table)
  (modify-syntax-entry ?] " " speedbar-syntax-table))


(defvar speedbar-key-map nil
  "Keymap used in speedbar buffer.")

(autoload 'speedbar-configure-options "speedbcfg" "Configure speedbar variables" t)
(autoload 'speedbar-configure-faces "speedbcfg" "Configure speedbar faces" t)

(if speedbar-key-map
    nil
  (setq speedbar-key-map (make-keymap))
  (suppress-keymap speedbar-key-map t)

  ;; control
  (define-key speedbar-key-map "e" 'speedbar-edit-line)
  (define-key speedbar-key-map "\C-m" 'speedbar-edit-line)
  (define-key speedbar-key-map "+" 'speedbar-expand-line)
  (define-key speedbar-key-map "-" 'speedbar-contract-line)
  (define-key speedbar-key-map "g" 'speedbar-refresh)
  (define-key speedbar-key-map "t" 'speedbar-toggle-updates)
  (define-key speedbar-key-map "q" 'speedbar-close-frame)
  (define-key speedbar-key-map "U" 'speedbar-up-directory)

  ;; navigation
  (define-key speedbar-key-map "n" 'speedbar-next)
  (define-key speedbar-key-map "p" 'speedbar-prev)
  (define-key speedbar-key-map " " 'speedbar-scroll-up)
  (define-key speedbar-key-map "\C-?" 'speedbar-scroll-down)

  ;; After much use, I suddenly desired in my heart to perform dired
  ;; style operations since the directory was RIGHT THERE!
  (define-key speedbar-key-map "I" 'speedbar-item-info)
  (define-key speedbar-key-map "B" 'speedbar-item-byte-compile)
  (define-key speedbar-key-map "L" 'speedbar-item-load)
  (define-key speedbar-key-map "C" 'speedbar-item-copy)
  (define-key speedbar-key-map "D" 'speedbar-item-delete)
  (define-key speedbar-key-map "R" 'speedbar-item-rename)

  (if (string-match "XEmacs" emacs-version)
      (progn
	;; bind mouse bindings so we can manipulate the items on each line
	(define-key speedbar-key-map 'button2 'speedbar-click)
	(define-key speedbar-key-map '(shift button2) 'speedbar-power-click)
	(define-key speedbar-key-map '(meta button3) 'speedbar-mouse-item-info)

	;; Setup XEmacs Menubar w/ etags specific items
	(defvar speedbar-menu
	  '("Speed Bar"
	    ["Run Speedbar" (speedbar-frame-mode 1) t]
	    ["Refresh" speedbar-refresh t]
	    ["Allow Auto Updates"
	     speedbar-toggle-updates
	     :style toggle
	     :selected speedbar-update-flag]
	    "-----"
	    ["Sort etags in Speedbar"
	     (speedbar-toggle-etags "sort")
	     :style toggle
	     :selected speedbar-sort-tags]
	    ["Show unknown files"
	     (speedbar-toggle-etags "show")
	     :style toggle
	     :selected speedbar-show-unknown-files]
	    "-----"
	    ["Use C++ Tagging"
	     (speedbar-toggle-etags "-C")
	     :style toggle
	     :selected (member "-C" speedbar-fetch-etags-arguments)]
	    ["Tag preprocessor defs"
	     (speedbar-toggle-etags "-D")
	     :style toggle
	     :selected (not (member "-D" speedbar-fetch-etags-arguments))]
	    ["Use indentation"
	     (speedbar-toggle-etags "-S")
	     :style toggle
	     :selected (not (member "-S" speedbar-fetch-etags-arguments))]))

	(add-submenu '("Tools") speedbar-menu nil)

	)
    ;; bind mouse bindings so we can manipulate the items on each line
    (define-key speedbar-key-map [mouse-2] 'speedbar-click)
    ;; This is the power click for poping up new frames
    (define-key speedbar-key-map [S-mouse-2] 'speedbar-power-click)
    ;; This adds a small unecessary visual effect
    ;;(define-key speedbar-key-map [down-mouse-2] 'speedbar-quick-mouse)
    (define-key speedbar-key-map [M-mouse-2] 'speedbar-mouse-item-info)

    ;; disable all menus - we don't have a lot of space to play with
    ;; in such a skinny frame.  This will cleverly find and nuke some
    ;; user-defined menus as well if they are there.  Too bad it
    ;; rely's on the structure of a keymap to work.
    (let ((k (lookup-key global-map [menu-bar])))
      (while k
	(if (and (listp (car k)) (listp (cdr (car k))))
	    (define-key speedbar-key-map (vector 'menu-bar (car (car k)))
	      'undefined))
	(setq k (cdr k))))

    ;; This lets the user scroll as if we had a scrollbar... well maybe not
    (define-key speedbar-key-map [mode-line mouse-2] 'speedbar-mouse-hscroll)
    ))

(defvar speedbar-easymenu-definition-base
  '("Speedbar"
    ["Update" speedbar-refresh t]
    ["Auto Update" speedbar-toggle-updates
     :style toggle :selected speedbar-update-flag]
    )
  "Base part of the speedbar menu.")

(defvar speedbar-easymenu-definition-special
  '(["Edit Item On Line" speedbar-edit-line t]
    ["Show All Files" speedbar-toggle-show-all-files
     :style toggle :selected speedbar-show-unknown-files]
    ["Expand Item" speedbar-expand-line
     (save-excursion (beginning-of-line)
		     (looking-at "[0-9]+: *.\\+. "))]
    ["Contract Item" speedbar-contract-line
     (save-excursion (beginning-of-line)
		     (looking-at "[0-9]+: *.-. "))]
    ["Sort Tags" speedbar-toggle-sorting
     :style toggle :selected speedbar-sort-tags]
    "----"
    ["Item Information" speedbar-item-info t]
    ["Load Lisp File" speedbar-item-load
     (save-excursion
       (beginning-of-line)
       (looking-at "[0-9]+: *\\[[+-]\\] .+\\(\\.el\\)\\( \\*\\)?$"))]
    ["Byte Compile File" speedbar-item-byte-compile
     (save-excursion
       (beginning-of-line)
       (looking-at "[0-9]+: *\\[[+-]\\] .+\\(\\.el\\)\\( \\*\\)?$"))]
    ["Copy Item" speedbar-item-copy
     (save-excursion (beginning-of-line) (looking-at "[0-9]+: *\\["))]
    ["Rename Item" speedbar-item-rename
     (save-excursion (beginning-of-line) (looking-at "[0-9]+: *[[<]"))]
    ["Delete Item" speedbar-item-delete
     (save-excursion (beginning-of-line) (looking-at "[0-9]+: *[[<]"))])
  "Additional menu items while in file-mode.")
 
(defvar speedbar-easymenu-definition-trailer
  '("----"
    ["Close" speedbar-close-frame t])
  "Menu items appearing at the end of the speedbar menu.")

(defvar speedbar-buffer nil
  "The buffer displaying the speedbar.")
(defvar speedbar-frame nil
  "The frame displaying speedbar.")
(defvar speedbar-cached-frame nil
  "The frame that was last created, then removed from the display.")
(defvar speedbar-full-text-cache nil
  "The last open directory is saved in it's entirety for ultra-fast switching.")
(defvar speedbar-timer nil
  "The speedbar timer used for updating the buffer.")
(defvar speedbar-attached-frame nil
  "The frame which started speedbar mode.
This is the frame from which all data displayed in the speedbar is
gathered, and in which files and such are displayed.")

(defvar speedbar-last-selected-file nil
  "The last file which was selected in speedbar buffer.")

(defvar speedbar-shown-directories nil
  "Maintain list of directories simultaneously open in the current speedbar.")

(defvar speedbar-directory-contents-alist nil
  "An association list of directories and their contents.
Each sublist was returned by `speedbar-file-lists'.  This list is
maintained to speed up the refresh rate when switching between
directories.")

(defvar speedbar-power-click nil
  "Never set this by hand.  Value is t when S-mouse activity occurs.")


;;; Mode definitions/ user commands
;;
;;###autoload
(defalias 'speedbar 'speedbar-frame-mode)
(defun speedbar-frame-mode (&optional arg)
  "Enable or disable speedbar.  Positive ARG means turn on, negative turn off.
nil means toggle.  Once the speedbar frame is activated, a buffer in
`speedbar-mode' will be displayed.  Currently, only one speedbar is
supported at a time.
`speedbar-before-popup-hook' is called before popping up the speedbar frame.
`speedbar-before-delete-hook' is called before the frame is deleted."
  (interactive "P")
  (if (not window-system)
      (error "Speedbar is not useful outside of a windowing environment"))
  ;; toggle frame on and off.
  (if (not arg) (if speedbar-frame (setq arg -1) (setq arg 1)))
  ;; turn the frame off on neg number
  (if (and (numberp arg) (< arg 0))
      (progn
	(run-hooks 'speedbar-before-delete-hook)
	(if (and speedbar-frame (frame-live-p speedbar-frame))
	    (if speedbar-xemacsp
		(delete-frame speedbar-frame)
	      (setq speedbar-cached-frame speedbar-frame)
	      (modify-frame-parameters speedbar-frame '((visibility . nil)))))
	(setq speedbar-frame nil)
	(speedbar-set-timer nil)
	;; Used to delete the buffer.  This has the annoying affect of
	;; preventing whatever took it's place from ever appearing
	;; as the default after a C-x b was typed
	;;(if (bufferp speedbar-buffer)
	;;    (kill-buffer speedbar-buffer))
	)
    ;; Set this as our currently attached frame
    (setq speedbar-attached-frame (selected-frame))
    (run-hooks 'speedbar-before-popup-hook)
    ;; Get the frame to work in
    (if (frame-live-p speedbar-cached-frame)
	(progn
	  (setq speedbar-frame speedbar-cached-frame)
	  (modify-frame-parameters speedbar-frame '((visibility . t)))
	  ;; Get the buffer to play with
	  (speedbar-mode)
	  (select-frame speedbar-frame)
	  (if (not (eq (current-buffer) speedbar-buffer))
	      (switch-to-buffer speedbar-buffer))
	  (set-window-dedicated-p (selected-window) t)
	  (raise-frame speedbar-frame)
	  (speedbar-set-timer speedbar-update-speed)
	  )
      (if (frame-live-p speedbar-frame)
	  (raise-frame speedbar-frame)
	(let ((params (cons (cons 'height (frame-height))
			    speedbar-frame-parameters)))
	  (setq speedbar-frame
		(if (< emacs-major-version 20) ;a bug is fixed in v20 & later
		    (make-frame params)
		  (let ((x-pointer-shape x-pointer-top-left-arrow)
			(x-sensitive-text-pointer-shape x-pointer-hand2))
		    (make-frame params)))))
	;; reset the selection variable
	(setq speedbar-last-selected-file nil)
	;; Put the buffer into the frame
	(save-window-excursion
	  ;; Get the buffer to play with
	  (speedbar-mode)
	  (select-frame speedbar-frame)
	  (switch-to-buffer speedbar-buffer)
	  (set-window-dedicated-p (selected-window) t)
	  ;; Turn off toolbar and menubar under XEmacs
	  (if speedbar-xemacsp
	      (progn
		(set-specifier default-toolbar-visible-p
			       (cons (selected-frame) nil))
		;; These lines make the menu-bar go away nicely, but
		;; they also cause xemacs much heartache.
		;;(set-specifier menubar-visible-p (cons (selected-frame) nil))
		;;(make-local-variable 'current-menubar)
		;;(setq current-menubar speedbar-menu)
		;;(add-submenu nil speedbar-menu nil)
		)))
	(speedbar-set-timer speedbar-update-speed)
	))))

(defun speedbar-close-frame ()
  "Turn off a currently active speedbar."
  (interactive)
  (speedbar-frame-mode -1)
  (select-frame speedbar-attached-frame)
  (other-frame 0))

(defun speedbar-frame-width ()
  "Return the width of the speedbar frame in characters.
nil if it doesn't exist."
  (and speedbar-frame (cdr (assoc 'width (frame-parameters speedbar-frame)))))

(defun speedbar-mode ()
  "Major mode for managing a display of directories and tags.
\\<speedbar-key-map>
The first line represents the default path of the speedbar frame.
Each directory segment is a button which jumps speedbar's default
directory to that path.  Buttons are activated by clicking `\\[speedbar-click]'.
In some situations using `\\[speedbar-power-click]' is a `power click' which will
rescan cached items, or pop up new frames.

Each line starting with <+> represents a directory.  Click on the <+>
to insert the directory listing into the current tree.  Click on the
<-> to retract that list.  Click on the directory name to go to that
directory as the default.

Each line starting with [+] is a file.  If the variable
`speedbar-show-unknown-files' is t, the lines starting with [?] are
files which don't have imenu support, but are not expressly ignored.
Files are completely ignored if they match `speedbar-file-unshown-regexp'
which is generated from `completion-ignored-extensions'.

Files with a `*' character after their name are files checked out of a
version control system.  (currently only RCS is supported.)  New
version control systems can be added by examining the documentation
for `speedbar-this-file-in-vc' and `speedbar-vc-check-dir-p'

Click on the [+] to display a list of tags from that file.  Click on
the [-] to retract the list.  Click on the file name to edit the file
in the attached frame.

If you open tags, you might find a node starting with {+}, which is a
category of tags.  Click the {+} to expand the category.  Jump-able
tags start with >.  Click the name of the tag to go to that position
in the selected file.

\\{speedbar-key-map}"
  ;; NOT interactive
  (save-excursion
    (setq speedbar-buffer (set-buffer (get-buffer-create " SPEEDBAR")))
    (kill-all-local-variables)
    (setq major-mode 'speedbar-mode)
    (setq mode-name "Speedbar")
    (use-local-map speedbar-key-map)
    (set-syntax-table speedbar-syntax-table)
    (setq font-lock-keywords nil) ;; no font-locking please
    (setq truncate-lines t)
    (make-local-variable 'frame-title-format)
    (setq frame-title-format "Speedbar")
    ;; Set this up special just for the speedbar buffer
    (if (null default-minibuffer-frame)
	(progn
	  (make-local-variable 'default-minibuffer-frame)
	  (setq default-minibuffer-frame speedbar-attached-frame)))
    (make-local-variable 'temp-buffer-show-function)
    (setq temp-buffer-show-function 'speedbar-temp-buffer-show-function)
    (setq kill-buffer-hook '(lambda () (let ((skilling (boundp 'skilling)))
					 (if skilling
					     nil
					   (if (eq (current-buffer)
						   speedbar-buffer)
					       (speedbar-frame-mode -1))))))
    (speedbar-set-mode-line-format)
    (if (not speedbar-xemacsp)
	(setq auto-show-mode nil))	;no auto-show for Emacs
    (run-hooks 'speedbar-mode-hook))
  (speedbar-update-contents)
  speedbar-buffer)

(defun speedbar-set-mode-line-format ()
  "Set the format of the mode line based on the current speedbar environment.
This gives visual indications of what is up.  It EXPECTS the speedbar
frame and window to be the currently active frame and window."
  (if (frame-live-p speedbar-frame)
      (save-excursion
	(set-buffer speedbar-buffer)
	(let* ((w (or (speedbar-frame-width) 20))
	       (p1 "<<")
	       (p5 ">>")
	       (p3 (if speedbar-update-flag "SPEEDBAR" "SLOWBAR"))
	       (blank (- w (length p1) (length p3) (length p5)
			 (if line-number-mode 4 0)))
	       (p2 (if (> blank 0)
		       (make-string (/ blank 2) ? )
		     ""))
	       (p4 (if (> blank 0)
		       (make-string (+ (/ blank 2) (% blank 2)) ? )
		     ""))
	       (tf
		(if line-number-mode
		    (list (concat p1 p2 p3) '(line-number-mode " %3l")
			  (concat p4 p5))
		  (list (concat p1 p2 p3 p4 p5)))))
	  (if (not (equal mode-line-format tf))
	      (progn
		(setq mode-line-format tf)
		(force-mode-line-update)))))))

(defun speedbar-temp-buffer-show-function (buffer)
  "Placed in the variable `temp-buffer-show-function' in `speedbar-mode'.
If a user requests help using \\[help-command] <Key> the temp BUFFER will be
redirected into a window on the attached frame."
  (if speedbar-attached-frame (select-frame speedbar-attached-frame))
  (pop-to-buffer buffer nil)
  (other-window -1)
  (run-hooks 'temp-buffer-show-hook))

(defun speedbar-reconfigure-menubar ()
  "Reconfigure the menu-bar in a speedbar frame.
Different menu items are displayed depending on the current display mode
and the existence of packages."
  (let ((cf (selected-frame))
	(md (append speedbar-easymenu-definition-base
		    (if speedbar-shown-directories
			;; file display mode version
			speedbar-easymenu-definition-special
		      (save-excursion
			(select-frame speedbar-attached-frame)
			(if (local-variable-p
			     'speedbar-easymenu-definition-special)
			    ;; If bound locally, we can use it
			    speedbar-easymenu-definition-special)))
		    ;; The trailer
		    speedbar-easymenu-definition-trailer)))
    (easy-menu-define speedbar-menu-map speedbar-key-map "Speedbar menu" md)
    (if speedbar-xemacsp
	(save-excursion
	  (set-buffer speedbar-buffer)
	  (set-buffer-menubar (list md))))))


;;; User Input stuff
;;
(defun speedbar-mouse-hscroll (e)
  "Read a mouse event E from the mode line, and horizontally scroll.
If the mouse is being clicked on the far left, or far right of the
mode-line.  This is only useful for non-XEmacs"
  (interactive "e")
  (let* ((xp (car (nth 2 (car (cdr e)))))
	 (cpw (/ (frame-pixel-width)
		 (frame-width)))
	 (oc (1+ (/ xp cpw)))
	 )
    (cond ((< oc 3)
	   (scroll-left 2))
	  ((> oc (- (window-width) 3))
	   (scroll-right 2))
	  (t (message "Click on the edge of the modeline to scroll left/right")))
    ;;(message "X: Pixel %d Char Pixels %d On char %d" xp cpw oc)
    ))

(defun speedbar-get-focus ()
  "Change frame focus to or from the speedbar frame.
If the selected frame is not speedbar, then speedbar frame is
selected.  If the speedbar frame is active, then select the attached frame."
  (interactive)
  (if (eq (selected-frame) speedbar-frame)
      (if (frame-live-p speedbar-attached-frame)
	  (select-frame speedbar-attached-frame))
    ;; make sure we have a frame
    (if (not (frame-live-p speedbar-frame)) (speedbar-frame-mode 1))
    ;; go there
    (select-frame speedbar-frame))
  (other-frame 0))

(defun speedbar-next (arg)
  "Move to the next ARGth line in a speedbar buffer."
  (interactive "p")
  (forward-line (or arg 1))
  (speedbar-item-info)
  (speedbar-position-cursor-on-line))

(defun speedbar-prev (arg)
  "Move to the previous ARGth line in a speedbar buffer."
  (interactive "p")
  (speedbar-next (if arg (- arg) -1)))

(defun speedbar-scroll-up (&optional arg)
  "Page down one screen-full of the speedbar, or ARG lines."
  (interactive "P")
  (scroll-up arg)
  (speedbar-position-cursor-on-line))

(defun speedbar-scroll-down (&optional arg)
  "Page up one screen-full of the speedbar, or ARG lines."
  (interactive "P")
  (scroll-down arg)
  (speedbar-position-cursor-on-line))

(defun speedbar-up-directory ()
  "Keyboard accelerator for moving the default directory up one.
Assumes that the current buffer is the speedbar buffer"
  (interactive)
  (setq default-directory (expand-file-name (concat default-directory "../")))
  (speedbar-update-contents))

;;; Speedbar file activity
;;
(defun speedbar-refresh ()
  "Refresh the current speedbar display, disposing of any cached data."
  (interactive)
  (let ((dl speedbar-shown-directories))
    (while dl
      (adelete 'speedbar-directory-contents-alist (car dl))
      (setq dl (cdr dl))))
  (if (<= 1 speedbar-verbosity-level) (message "Refreshing speedbar..."))
  (speedbar-update-contents)
  (speedbar-stealthy-updates)
  ;; Reset the timer in case it got really hosed for some reason...
  (speedbar-set-timer speedbar-update-speed)
  (if (<= 1 speedbar-verbosity-level) (message "Refreshing speedbar...done")))

(defun speedbar-item-load ()
  "Byte compile the item under the cursor or mouse if it is a lisp file."
  (interactive)
  (let ((f (speedbar-line-file)))
    (if (and (file-exists-p f) (string-match "\\.el$" f))
	(if (and (file-exists-p (concat f "c"))
		 (y-or-n-p (format "Load %sc? " f)))
	    ;; If the compiled version exists, load that instead...
	    (load-file (concat f "c"))
	  (load-file f))
      (error "Not a loadable file..."))))

(defun speedbar-item-byte-compile ()
  "Byte compile the item under the cursor or mouse if it is a lisp file."
  (interactive)
  (let ((f (speedbar-line-file))
	(sf (selected-frame)))
    (if (and (file-exists-p f) (string-match "\\.el$" f))
	(progn
	  (select-frame speedbar-attached-frame)
	  (byte-compile-file f nil)
	  (select-frame sf)))
    ))

(defun speedbar-mouse-item-info (event)
  "Provide information about what the user clicked on.
This should be bound to a mouse EVENT."
  (interactive "e")
  (mouse-set-point event)
  (speedbar-item-info))

(defun speedbar-item-info ()
  "Display info in the mini-buffer about the button the mouse is over."
  (interactive)
  (if (not speedbar-shown-directories)
      nil
    (let* ((item (speedbar-line-file))
	   (attr (if item (file-attributes item) nil)))
      (if item (message "%s %d %s" (nth 8 attr) (nth 7 attr) item)
	(save-excursion
	  (beginning-of-line)
	  (looking-at "\\([0-9]+\\):")
	  (setq item (speedbar-line-path (string-to-int (match-string 1))))
	  (if (re-search-forward "> \\([^ ]+\\)$"
				 (save-excursion(end-of-line)(point)) t)
	      (progn
		(setq attr (get-text-property (match-beginning 1)
					      'speedbar-token))
		(message "Tag %s in %s at position %s"
			 (match-string 1) item (if attr attr 0)))
	    (message "No special info for this line.")))
	))))

(defun speedbar-item-copy ()
  "Copy the item under the cursor.
Files can be copied to new names or places."
  (interactive)
  (let ((f (speedbar-line-file)))
    (if (not f)	(error "Not a file."))
    (if (file-directory-p f)
	(error "Cannot copy directory.")
      (let* ((rt (read-file-name (format "Copy %s to: "
					 (file-name-nondirectory f))
				 (file-name-directory f)))
	     (refresh (member (expand-file-name (file-name-directory rt))
			      speedbar-shown-directories)))
	;; Create the right file name part
	(if (file-directory-p rt)
	    (setq rt
		  (concat (expand-file-name rt)
			  (if (string-match "/$" rt) "" "/")
			  (file-name-nondirectory f))))
	(if (or (not (file-exists-p rt))
		(y-or-n-p (format "Overwrite %s with %s? " rt f)))
	    (progn
	      (copy-file f rt t t)
	      ;; refresh display if the new place is currently displayed.
	      (if refresh
		  (progn
		    (speedbar-refresh)
		    (if (not (speedbar-goto-this-file rt))
			(speedbar-goto-this-file f))))
	      ))))))

(defun speedbar-item-rename ()
  "Rename the item under the cursor or mouse.
Files can be renamed to new names or moved to new directories."
  (interactive)
  (let ((f (speedbar-line-file)))
    (if f
	(let* ((rt (read-file-name (format "Rename %s to: "
					   (file-name-nondirectory f))
				   (file-name-directory f)))
	       (refresh (member (expand-file-name (file-name-directory rt))
				speedbar-shown-directories)))
	  ;; Create the right file name part
	  (if (file-directory-p rt)
	      (setq rt
		    (concat (expand-file-name rt)
			    (if (string-match "/$" rt) "" "/")
			    (file-name-nondirectory f))))
	  (if (or (not (file-exists-p rt))
		  (y-or-n-p (format "Overwrite %s with %s? " rt f)))
	      (progn
		(rename-file f rt t)
		;; refresh display if the new place is currently displayed.
		(if refresh
		    (progn
		      (speedbar-refresh)
		      (speedbar-goto-this-file rt)
		      )))))
      (error "Not a file."))))

(defun speedbar-item-delete ()
  "Delete the item under the cursor.  Files are removed from disk."
  (interactive)
  (let ((f (speedbar-line-file)))
    (if (not f) (error "Not a file."))
    (if (y-or-n-p (format "Delete %s? " f))
	(progn
	  (if (file-directory-p f)
	      (delete-directory f)
	    (delete-file f))
	  (message "Okie dokie..")
	  (let ((p (point)))
	    (speedbar-refresh)
	    (goto-char p))
	  ))
    ))

(defun speedbar-enable-update ()
  "Enable automatic updating in speedbar via timers."
  (interactive)
  (setq speedbar-update-flag t)
  (speedbar-set-mode-line-format)
  (speedbar-set-timer speedbar-update-speed))

(defun speedbar-disable-update ()
  "Disable automatic updating and stop consuming resources."
  (interactive)
  (setq speedbar-update-flag nil)
  (speedbar-set-mode-line-format)
  (speedbar-set-timer nil))

(defun speedbar-toggle-updates ()
  "Toggle automatic update for the speedbar frame."
  (interactive)
  (if speedbar-update-flag
      (speedbar-disable-update)
    (speedbar-enable-update)))

(defun speedbar-toggle-sorting ()
  "Toggle automatic update for the speedbar frame."
  (interactive)
  (setq speedbar-sort-tags (not speedbar-sort-tags)))

(defun speedbar-toggle-show-all-files ()
  "Toggle display of files speedbar can not tag."
  (interactive)
  (setq speedbar-show-unknown-files (not speedbar-show-unknown-files))
  (speedbar-refresh))

;;; Utility functions
;;
(defun speedbar-set-timer (timeout)
  "Apply a timer with TIMEOUT, or remove a timer if TIMOUT is nil.
TIMEOUT is the number of seconds until the speedbar timer is called
again.  When TIMEOUT is nil, turn off all timeouts.
This function will also enable or disable the `vc-checkin-hook' used
to track file check ins, and will change the mode line to match
`speedbar-update-flag'."
  (cond
   ;; Xemacs
   (speedbar-xemacsp
    (if speedbar-timer
	(progn (delete-itimer speedbar-timer)
	       (setq speedbar-timer nil)))
    (if timeout
	(setq speedbar-timer (start-itimer "speedbar"
					   'speedbar-timer-fn
					   timeout
					   nil))))
   ;; Post 19.31 Emacs
   ((fboundp 'run-with-idle-timer)
    (if speedbar-timer
	(progn (cancel-timer speedbar-timer)
	       (setq speedbar-timer nil)))
    (if timeout
	(setq speedbar-timer
	      (run-with-idle-timer timeout nil 'speedbar-timer-fn))))
   ;; Emacs 19.30 (Thanks twice: ptype@dra.hmg.gb)
   ((fboundp 'post-command-idle-hook)
    (if timeout
	(add-hook 'post-command-idle-hook 'speedbar-timer-fn)
      (remove-hook 'post-command-idle-hook 'speedbar-timer-fn)))
   ;; Older or other Emacsen with no timers.  Set up so that it's
   ;; obvious this emacs can't handle the updates
   (t
    (setq speedbar-update-flag nil)))
  ;; Apply a revert hook that will reset the scanners.  We attach to revert
  ;; because most reverts occur during VC state change, and this lets our
  ;; VC scanner fix itself.
  (if timeout
      (add-hook 'after-revert-hook 'speedbar-reset-scanners)
    (remove-hook 'after-revert-hook 'speedbar-reset-scanners)
    )
  ;; change this if it changed for some reason
  (speedbar-set-mode-line-format))

(defmacro speedbar-with-writable (&rest forms)
  "Allow the buffer to be writable and evaluate FORMS.
Turn read only back on when done."
  (list 'let '((speedbar-with-writable-buff (current-buffer)))
	'(toggle-read-only -1)
	(cons 'progn forms)
	'(save-excursion (set-buffer speedbar-with-writable-buff)
			 (toggle-read-only 1))))
(put 'speedbar-with-writable 'lisp-indent-function 0)

(defun speedbar-select-window (buffer)
  "Select a window in which BUFFER is show.
If it is not shown, force it to appear in the default window."
  (let ((win (get-buffer-window buffer speedbar-attached-frame)))
    (if win
	(select-window win)
      (show-buffer (selected-window) buffer))))

(defmacro speedbar-with-attached-buffer (&rest forms)
  "Execute FORMS in the attached frame's special buffer.
Optionally select that frame if necessary."
  ;; Reset the timer with a new timeout when cliking a file
  ;; in case the user was navigating directories, we can cancel
  ;; that other timer.
  (list
   'progn
   '(speedbar-set-timer speedbar-update-speed)
   (list
    'let '((cf (selected-frame)))
    '(select-frame speedbar-attached-frame)
    '(speedbar-select-window speedbar-desired-buffer)
    (cons 'progn forms)
    '(select-frame cf)
    '(speedbar-maybee-jump-to-attached-frame)
    )))

(defun speedbar-insert-button (text face mouse function
				    &optional token prevline)
  "Insert TEXT as the next logical speedbar button.
FACE is the face to put on the button, MOUSE is the highlight face to use.
When the user clicks on TEXT, FUNCTION is called with the TOKEN parameter.
This function assumes that the current buffer is the speedbar buffer.
If PREVLINE, then put this button on the previous line.

This is a convenience function for special mode that create their own
specialized speedbar displays."
  (goto-char (point-max))
  (if (/= (current-column) 0) (insert "\n"))
  (if prevline (progn (delete-char -1) (insert " "))) ;back up if desired...
  (let ((start (point)))
    (insert text)
    (speedbar-make-button start (point) face mouse function token))
  (let ((start (point)))
    (insert "\n")
    (put-text-property start (point) 'face nil)
    (put-text-property start (point) 'mouse-face nil)))

(defun speedbar-make-button (start end face mouse function &optional token)
  "Create a button from START to END, with FACE as the display face.
MOUSE is the mouse face.  When this button is clicked on FUNCTION
will be run with the TOKEN parameter (any lisp object)"
  (put-text-property start end 'face face)
  (put-text-property start end 'mouse-face mouse)
  (put-text-property start end 'invisible nil)
  (if function (put-text-property start end 'speedbar-function function))
  (if token (put-text-property start end 'speedbar-token token))
  )

;;; File button management
;;
(defun speedbar-file-lists (directory)
  "Create file lists for DIRECTORY.
The car is the list of directories, the cdr is list of files not
matching ignored headers.  Cache any directory files found in
`speedbar-directory-contents-alist' and use that cache before scanning
the file-system"
  (setq directory (expand-file-name directory))
  ;; If in powerclick mode, then the directory we are getting
  ;; should be rescanned.
  (if speedbar-power-click
      (adelete 'speedbar-directory-contents-alist directory))
  ;; find the directory, either in the cache, or build it.
  (or (cdr-safe (assoc directory speedbar-directory-contents-alist))
      (let ((default-directory directory)
	    (dir (directory-files directory nil))
	    (dirs nil)
	    (files nil))
	(while dir
	  (if (not (string-match speedbar-file-unshown-regexp (car dir)))
	      (if (file-directory-p (car dir))
		  (setq dirs (cons (car dir) dirs))
		(setq files (cons (car dir) files))))
	  (setq dir (cdr dir)))
	(let ((nl (cons (nreverse dirs) (list (nreverse files)))))
	  (aput 'speedbar-directory-contents-alist directory nl)
	  nl))
      ))

(defun speedbar-directory-buttons (directory index)
  "Insert a single button group at point for DIRECTORY.
Each directory path part is a different button.  If part of the path
matches the user directory ~, then it is replaced with a ~.
INDEX is not used, but is required by the caller."
  (let* ((tilde (expand-file-name "~"))
	 (dd (expand-file-name directory))
	 (junk (string-match (regexp-quote tilde) dd))
	 (displayme (if junk
			(concat "~" (substring dd (match-end 0)))
		      dd))
	 (p (point)))
    (if (string-match "^~/?$" displayme) (setq displayme (concat tilde "/")))
    (insert displayme)
    (save-excursion
      (goto-char p)
      (while (re-search-forward "\\([^/]+\\)/" nil t)
	(speedbar-make-button (match-beginning 1) (match-end 1)
			      'speedbar-directory-face
			      'speedbar-highlight-face
			      'speedbar-directory-buttons-follow
			      (if (= (match-beginning 1) p)
				  (expand-file-name "~/")  ;the tilde
				(buffer-substring-no-properties
				 p (match-end 0)))))
      ;; Nuke the beginning of the directory if it's too long...
      (cond ((eq speedbar-directory-button-trim-method 'span)
	     (beginning-of-line)
	     (let ((ww (or (speedbar-frame-width) 20)))
	       (move-to-column ww nil)
	       (while (>= (current-column) ww)
		 (re-search-backward "/" nil t)
		 (if (<= (current-column) 2)
		     (progn
		       (re-search-forward "/" nil t)
		       (if (< (current-column) 4)
			   (re-search-forward "/" nil t))
		       (forward-char -1)))
		 (if (looking-at "/?$")
		     (beginning-of-line)
		   (insert "/...\n ")
		   (move-to-column ww nil)))))
	    ((eq speedbar-directory-button-trim-method 'trim)
	     (end-of-line)
	     (let ((ww (or (speedbar-frame-width) 20))
		   (tl (current-column)))
	       (if (< ww tl)
		   (progn
		     (move-to-column (- tl ww))
		     (if (re-search-backward "/" nil t)
			 (progn
			   (delete-region (point-min) (point))
			   (insert "$")
			   )))))))
      )
    (if (string-match "^/[^/]+/$" displayme)
	(progn
	  (insert "  ")
	  (let ((p (point)))
	    (insert "<root>")
	    (speedbar-make-button p (point)
				  'speedbar-directory-face
				  'speedbar-highlight-face
				  'speedbar-directory-buttons-follow
				  "/"))))
    (end-of-line)
    (insert-char ?\n 1 nil)))

(defun speedbar-make-tag-line (exp-button-type
			       exp-button-char exp-button-function
			       exp-button-data
			       tag-button tag-button-function tag-button-data
			       tag-button-face depth)
  "Create a tag line with EXP-BUTTON-TYPE for the small expansion button.
This is the button that expands or contracts a node (if applicable),
and EXP-BUTTON-CHAR the character in it (+, -, ?, etc).  EXP-BUTTON-FUNCTION
is the function to call if it's clicked on.  Button types are
'bracket, 'angle, 'curly, or nil.  EXP-BUTTON-DATA is extra data
attached to the text forming the expansion button.

Next, TAG-BUTTON is the text of the tag.  TAG-BUTTON-FUNCTION is the
function to call if clicked on, and TAG-BUTTON-DATA is the data to
attach to the text field (such a tag positioning, etc).
TAG-BUTTON-FACE is a face used for this type of tag.

Lastly, DEPTH shows the depth of expansion.

This function assumes that the cursor is in the speedbar window at the
position to insert a new item, and that the new item will end with a CR"
  (let ((start (point))
	(end (progn
	       (insert (int-to-string depth) ":")
	       (point))))
    (put-text-property start end 'invisible t)
    )
  (insert-char ?  depth nil)
  (put-text-property (- (point) depth) (point) 'invisible nil)
  (let* ((exp-button (cond ((eq exp-button-type 'bracket) "[%c]")
			   ((eq exp-button-type 'angle) "<%c>")
			   ((eq exp-button-type 'curly) "{%c}")
			   (t ">")))
	 (buttxt (format exp-button exp-button-char))
	 (start (point))
	 (end (progn (insert buttxt) (point)))
	 (bf (if exp-button-type 'speedbar-button-face nil))
	 (mf (if exp-button-function 'speedbar-highlight-face nil))
	 )
    (speedbar-make-button start end bf mf exp-button-function exp-button-data)
    )
  (insert-char ?  1 nil)
  (put-text-property (1- (point)) (point) 'invisible nil)
  (let ((start (point))
	(end (progn (insert tag-button) (point))))
    (insert-char ?\n 1 nil)
    (put-text-property (1- (point)) (point) 'invisible nil)
    (speedbar-make-button start end tag-button-face
			  (if tag-button-function 'speedbar-highlight-face nil)
			  tag-button-function tag-button-data))
)

(defun speedbar-change-expand-button-char (char)
  "Change the expansion button character to CHAR for the current line."
  (save-excursion
    (beginning-of-line)
    (if (re-search-forward ":\\s-*.\\([-+?]\\)" (save-excursion (end-of-line)
								(point)) t)
	(speedbar-with-writable
	  (goto-char (match-beginning 1))
	  (delete-char 1)
	  (insert-char char 1 t)))))


;;; Build button lists
;;
(defun speedbar-insert-files-at-point (files level)
  "Insert list of FILES starting at point, and indenting all files to LEVEL.
Tag expandable items with a +, otherwise a ?.  Don't highlight ? as we
don't know how to manage them.  The input parameter FILES is a cons
cell of the form ( 'DIRLIST . 'FILELIST )"
  ;; Start inserting all the directories
  (let ((dirs (car files)))
    (while dirs
      (speedbar-make-tag-line 'angle ?+ 'speedbar-dired (car dirs)
			      (car dirs) 'speedbar-dir-follow nil
			      'speedbar-directory-face level)
      (setq dirs (cdr dirs))))
  (let ((lst (car (cdr files))))
    (while lst
      (let* ((known (string-match speedbar-file-regexp (car lst)))
	     (expchar (if known ?+ ??))
	     (fn (if known 'speedbar-tag-file nil)))
	(if (or speedbar-show-unknown-files (/= expchar ??))
	    (speedbar-make-tag-line 'bracket expchar fn (car lst)
				    (car lst) 'speedbar-find-file nil
				    'speedbar-file-face level)))
      (setq lst (cdr lst)))))

(defun speedbar-default-directory-list (directory index)
  "Insert files for DIRECTORY with level INDEX at point."
  (speedbar-insert-files-at-point
   (speedbar-file-lists directory) index)
  (speedbar-reset-scanners)
  (if (= index 0)
      ;; If the shown files variable has extra directories, then
      ;; it is our responsibility to redraw them all
      ;; Luckilly, the nature of inserting items into this list means
      ;; that by reversing it, we can easilly go in the right order
      (let ((sf (cdr (reverse speedbar-shown-directories))))
	(setq speedbar-shown-directories
	      (list (expand-file-name default-directory)))
	;; exand them all as we find them
	(while sf
	  (if (speedbar-goto-this-file (car sf))
	      (progn
		(beginning-of-line)
		(if (looking-at "[0-9]+:[ ]*<")
		    (progn
		      (goto-char (match-end 0))
		  (speedbar-do-function-pointer)))
		(setq sf (cdr sf)))))
	)))

(defun speedbar-insert-generic-list (level lst expand-fun find-fun)
  "At LEVEL, insert a generic multi-level alist LST.
Associations with lists get {+} tags (to expand into more nodes) and
those with positions just get a > as the indicator.  {+} buttons will
have the function EXPAND-FUN and the token is the CDR list.  The token
name will have the function FIND-FUN and not token."
  ;; Remove imenu rescan button
  (if (string= (car (car lst)) "*Rescan*")
      (setq lst (cdr lst)))
  ;; insert the parts
  (while lst
    (cond ((null (car-safe lst)) nil)	;this would be a separator
	  ((or (numberp (cdr-safe (car-safe lst)))
	       (markerp (cdr-safe (car-safe lst))))
	   (speedbar-make-tag-line nil nil nil nil ;no expand button data
				   (car (car lst)) ;button name
				   find-fun        ;function
				   (cdr (car lst)) ;token is position
				   'speedbar-tag-face
				   (1+ level)))
	  ((listp (cdr-safe (car-safe lst)))
	   (speedbar-make-tag-line 'curly ?+ expand-fun (cdr (car lst))
				   (car (car lst)) ;button name
				   nil nil 'speedbar-tag-face
				   (1+ level)))
	  (t (message "Ooops!")))
    (setq lst (cdr lst))))

;;; Timed functions
;;
(defun speedbar-update-contents ()
  "Generically update the contents of the speedbar buffer."
  (interactive)
  ;; Set the current special buffer
  (setq speedbar-desired-buffer nil)
  (if (and speedbar-mode-specific-contents-flag
	   speedbar-special-mode-expansion-list
	   (local-variable-p
	    'speedbar-special-mode-expansion-list))
	   ;(eq (get major-mode 'mode-class 'special)))
      (speedbar-update-special-contents)
    (speedbar-update-directory-contents)))

(defun speedbar-update-directory-contents ()
  "Update the contents of the speedbar buffer based on the current directory."
  (let ((cbd (expand-file-name default-directory))
	cbd-parent
	(funclst speedbar-initial-expansion-list)
	(cache speedbar-full-text-cache)
	;; disable stealth during update
	(speedbar-stealthy-function-list nil)
	(use-cache nil)
	(expand-local nil)
	;; Because there is a bug I can't find just yet
	(inhibit-quit nil))
    (save-excursion
      (set-buffer speedbar-buffer)
      ;; If we are updating contents to where we are, then this is
      ;; really a request to update existing contents, so we must be
      ;; careful with our text cache!
      (if (member cbd speedbar-shown-directories)
	  (setq cache nil)

	;; Build cbd-parent, and see if THAT is in the current shown
	;; directories.  First, go through pains to get the parent directory
	(if (and speedbar-smart-directory-expand-flag
		 (save-match-data
		   (setq cbd-parent cbd)
		   (if (string-match "/$" cbd-parent)
		       (setq cbd-parent (substring cbd-parent 0 (match-beginning 0))))
		   (setq cbd-parent (file-name-directory cbd-parent)))
		 (member cbd-parent speedbar-shown-directories))
	    (setq expand-local t)

	  ;; If this directory is NOT in the current list of available
	  ;; paths, then use the cache, and set the cache to our new
	  ;; value.  Make sure to unhighlight the current file, or if we
	  ;; come back to this directory, it might be a different file
	  ;; and then we get a mess!
	  (if (> (point-max) 1)
	      (progn
		(speedbar-clear-current-file)
		(setq speedbar-full-text-cache
		      (cons speedbar-shown-directories (buffer-string)))))

	  ;; Check if our new directory is in the list of directories
	  ;; shown in the text-cache
	  (if (member cbd (car cache))
	      (setq speedbar-shown-directories (car cache)
		    use-cache t)
	    ;; default the shown directories to this list...
	    (setq speedbar-shown-directories (list cbd)))
	  ))
      (setq speedbar-last-selected-file nil)
      (speedbar-with-writable
	(if (and expand-local
		 ;; Find this directory as a speedbar node.
		 (speedbar-path-line cbd))
	    ;; Open it.
	    (speedbar-expand-line)
	  (erase-buffer)
	  (cond (use-cache
		 (setq default-directory
		       (nth (1- (length speedbar-shown-directories))
			    speedbar-shown-directories))
		 (insert (cdr cache)))
		(t
		 (while funclst
		   (setq default-directory cbd)
		   (funcall (car funclst) cbd 0)
		   (setq funclst (cdr funclst))))))
	(goto-char (point-min)))))
  (speedbar-reconfigure-menubar))

(defun speedbar-update-special-contents ()
  "Used the mode-specific variable to fill in the speedbar buffer.
This should only be used by modes classified as special."
  (let ((funclst speedbar-special-mode-expansion-list)
	(specialbuff (current-buffer)))
    (save-excursion
      (setq speedbar-desired-buffer specialbuff)
      (set-buffer speedbar-buffer)
      ;; If we are leaving a directory, cache it.
      (if (not speedbar-shown-directories)
	  ;; Do nothing
	  nil
	;; Clean up directory maintenance stuff
	(speedbar-clear-current-file)
	(setq speedbar-full-text-cache
	      (cons speedbar-shown-directories (buffer-string))
	      speedbar-shown-directories nil))
      ;; Now fill in the buffer with our newly found specialized list.
      (speedbar-with-writable
	(while funclst
	  ;; We do not erase the buffer because these functions may
	  ;; decide NOT to update themselves.
	  (funcall (car funclst) specialbuff)
	  (setq funclst (cdr funclst))))
      (goto-char (point-min))))
  (speedbar-reconfigure-menubar))

(defun speedbar-timer-fn ()
  "Run whenever emacs is idle to update the speedbar item."
  (if (not (and (frame-live-p speedbar-frame)
		(frame-live-p speedbar-attached-frame)))
      (speedbar-set-timer nil)
    (condition-case nil
	;; Save all the match data so that we don't mess up executing fns
	(save-match-data
	  (if (and (frame-visible-p speedbar-frame) speedbar-update-flag)
	      (let ((af (selected-frame)))
		(save-window-excursion
		  (select-frame speedbar-attached-frame)
		  ;; make sure we at least choose a window to
		  ;; get a good directory from
		  (if (string-match "\\*Minibuf-[0-9]+\\*" (buffer-name))
		      (other-window 1))
		  ;; Update for special mode all the time!
		  (if (and speedbar-mode-specific-contents-flag
			   speedbar-special-mode-expansion-list
			   (local-variable-p
			    'speedbar-special-mode-expansion-list))
					;(eq (get major-mode 'mode-class 'special)))
		      (speedbar-update-special-contents)
		    ;; Update all the contents if directories change!
		    (if (or (member (expand-file-name default-directory)
				    speedbar-shown-directories)
			    (string-match speedbar-ignored-path-regexp
					  (expand-file-name default-directory))
			    (member major-mode speedbar-ignored-modes)
			    (eq af speedbar-frame)
			    (not (buffer-file-name)))
			nil
		      (if (<= 1 speedbar-verbosity-level)
			  (message "Updating speedbar to: %s..."
				   default-directory))
		      (speedbar-update-directory-contents)
		      (if (<= 1 speedbar-verbosity-level)
			  (message "Updating speedbar to: %s...done"
				   default-directory))))
		  (select-frame af))
		;; Now run stealthy updates of time-consuming items
		(speedbar-stealthy-updates))))
      ;; errors that might occur
      (error (message "Speedbar error!")))
    ;; Reset the timer
    (speedbar-set-timer speedbar-update-speed))
  (run-hooks 'speedbar-timer-hook)
  )


;;; Stealthy activities
;;
(defun speedbar-stealthy-updates ()
  "For a given speedbar, run all items in the stealthy function list.
Each item returns t if it completes successfully, or nil if
interrupted by the user."
  (let ((l speedbar-stealthy-function-list))
    (unwind-protect
	(while (and l (funcall (car l)))
	  (sit-for 0)
	  (setq l (cdr l)))
      ;(message "Exit with %S" (car l))
      )))

(defun speedbar-reset-scanners ()
  "Reset any variables used by functions in the stealthy list as state.
If new functions are added, their state needs to be updated here."
  (setq speedbar-vc-to-do-point t)
  (run-hooks 'speedbar-scanner-reset-hook)
  )

(defun speedbar-clear-current-file ()
  "Locate the file thought to be current, and unhighlight it."
  (save-excursion
    (set-buffer speedbar-buffer)
    (if speedbar-last-selected-file
	(speedbar-with-writable
	  (goto-char (point-min))
	  (if (and
	       speedbar-last-selected-file
	       (re-search-forward
		(concat " \\(" (regexp-quote speedbar-last-selected-file)
			"\\)\\(" (regexp-quote speedbar-vc-indicator)
			"\\)?\n")
		nil t))
	      (put-text-property (match-beginning 1)
				 (match-end 1)
				 'face
				 'speedbar-file-face))))))

(defun speedbar-update-current-file ()
  "Find the current file, and update our visuals to indicate its name.
This is specific to file names.  If the file name doesn't show up, but
it should be in the list, then the directory cache needs to be
updated."
  (let* ((lastf (selected-frame))
	 (newcfd (save-excursion
		   (select-frame speedbar-attached-frame)
		   (let ((rf (if (buffer-file-name)
				 (buffer-file-name)
			       nil)))
		     (select-frame lastf)
		     rf)))
	 (newcf (if newcfd (file-name-nondirectory newcfd)))
	 (lastb (current-buffer))
	 (sucf-recursive (boundp 'sucf-recursive)))
    (if (and newcf
	     ;; check here, that way we won't refresh to newcf until
	     ;; its been written, thus saving ourselves some time
	     (file-exists-p newcf)
	     (not (string= newcf speedbar-last-selected-file)))
	(progn
	  ;; It is important to select the frame, otherwise the window
	  ;; we want the cursor to move in will not be updated by the
	  ;; search-forward command.
	  (select-frame speedbar-frame)
	  ;; Remove the old file...
	  (speedbar-clear-current-file)
	  ;; now highlight the new one.
	  (set-buffer speedbar-buffer)
	  (speedbar-with-writable
	    (goto-char (point-min))
	    (if (re-search-forward
		 (concat " \\(" (regexp-quote newcf) "\\)\\("
			 (regexp-quote speedbar-vc-indicator)
			 "\\)?\n") nil t)
		  ;; put the property on it
		  (put-text-property (match-beginning 1)
				     (match-end 1)
				     'face
				     'speedbar-selected-face)
	      ;; Oops, it's not in the list.  Should it be?
	      (if (and (string-match speedbar-file-regexp newcf)
		       (string= (file-name-directory newcfd)
				(expand-file-name default-directory)))
		  ;; yes, it is (we will ignore unknowns for now...)
		  (progn
		    (speedbar-refresh)
		    (if (re-search-forward
			 (concat " \\(" (regexp-quote newcf) "\\)\n") nil t)
			;; put the property on it
			(put-text-property (match-beginning 1)
					   (match-end 1)
					   'face
					   'speedbar-selected-face)))
		;; if it's not in there now, whatever...
		))
	    (setq speedbar-last-selected-file newcf))
	  (if (not sucf-recursive)
	      (progn
		(forward-line -1)
		(speedbar-position-cursor-on-line)))
	  (set-buffer lastb)
	  (select-frame lastf)
	  )))
  ;; return that we are done with this activity.
  t)

;; Load ange-ftp only if compiling to remove errors.
;; Steven L Baur <steve@xemacs.org> said this was important:
(eval-when-compile (or (featurep 'xemacs) (require 'ange-ftp)))

(defun speedbar-check-vc ()
  "Scan all files in a directory, and for each see if it's checked out.
See `speedbar-this-file-in-vc' and `speedbar-vc-check-dir-p' for how
to add more types of version control systems."
  ;; Check for to-do to be reset.  If reset but no RCS is available
  ;; then set to nil (do nothing) otherwise, start at the beginning
  (save-excursion
    (set-buffer speedbar-buffer)
    (if (and speedbar-vc-do-check (eq speedbar-vc-to-do-point t)
	     (speedbar-vc-check-dir-p default-directory)
	     (not (and (featurep 'ange-ftp)
		       (string-match (car
				      (if speedbar-xemacsp
					  ange-ftp-path-format
					ange-ftp-name-format))
				     (expand-file-name default-directory)))))
	(setq speedbar-vc-to-do-point 0))
    (if (numberp speedbar-vc-to-do-point)
	(progn
	  (goto-char speedbar-vc-to-do-point)
	  (while (and (not (input-pending-p))
		      (re-search-forward "^\\([0-9]+\\):\\s-*\\[[+-]\\] "
					 nil t))
	    (setq speedbar-vc-to-do-point (point))
	    (if (speedbar-check-vc-this-line (match-string 1))
		(if (not (looking-at (regexp-quote speedbar-vc-indicator)))
		    (speedbar-with-writable (insert speedbar-vc-indicator)))
	      (if (looking-at (regexp-quote speedbar-vc-indicator))
		  (speedbar-with-writable
		    (delete-region (match-beginning 0) (match-end 0))))))
	  (if (input-pending-p)
	      ;; return that we are incomplete
	      nil
	    ;; we are done, set to-do to nil
	    (setq speedbar-vc-to-do-point nil)
	    ;; and return t
	    t))
      t)))

(defun speedbar-check-vc-this-line (depth)
  "Return t if the file on this line is check of of a version control system.
Parameter DEPTH is a string with the current depth of indentation of
the file being checked."
  (let* ((d (string-to-int depth))
	 (f (speedbar-line-path d))
	 (fn (buffer-substring-no-properties
	      ;; Skip-chars: thanks ptype@dra.hmg.gb
	      (point) (progn
			(skip-chars-forward "^ "
					    (save-excursion (end-of-line)
							    (point)))
			(point))))
	 (fulln (concat f fn)))
    (if (<= 2 speedbar-verbosity-level)
	(message "Speedbar vc check...%s" fulln))
    (and (file-writable-p fulln)
	 (speedbar-this-file-in-vc f fn))))

(defun speedbar-vc-check-dir-p (path)
  "Return t if we should bother checking PATH for version control files.
This can be overloaded to add new types of version control systems."
  (or
   ;; Local RCS
   (file-exists-p (concat path "RCS/"))
   ;; Local SCCS
   (file-exists-p (concat path "SCCS/"))
   ;; Remote SCCS project
   (let ((proj-dir (getenv "PROJECTDIR")))
     (if proj-dir
	 (file-exists-p (concat proj-dir "/SCCS"))
       nil))
   ;; User extension
   (run-hook-with-args 'speedbar-vc-path-enable-hook path)
   ))

(defun speedbar-this-file-in-vc (path name)
  "Check to see if the file in PATH with NAME is in a version control system.
You can add new VC systems by overriding this function.  You can
optimize this function by overriding it and only doing those checks
that will occur on your system."
  (or
   ;; RCS file name
   (file-exists-p (concat path "RCS/" name ",v"))
   ;; Local SCCS file name
   (file-exists-p (concat path "SCCS/p." fn))
   ;; Remote SCCS file name
   (let ((proj-dir (getenv "PROJECTDIR")))
     (if proj-dir
         (file-exists-p (concat proj-dir "/SCCS/p." fn))
       nil))
   ;; User extension
   (run-hook-with-args 'speedbar-vc-in-control-hook path name)
   ))

;;; Clicking Activity
;;
(defun speedbar-quick-mouse (e)
  "Since mouse events are strange, this will keep the mouse nicely positioned.
This should be bound to mouse event E."
  (interactive "e")
  (mouse-set-point e)
  (speedbar-position-cursor-on-line)
  )

(defun speedbar-position-cursor-on-line ()
  "Position the cursor on a line."
  (let ((oldpos (point)))
    (beginning-of-line)
    (if (looking-at "[0-9]+:\\s-*..?.? ")
	(goto-char (1- (match-end 0)))
      (goto-char oldpos))))

(defun speedbar-power-click (e)
  "Activate any speedbar button as a power click.
This should be bound to mouse event E."
  (interactive "e")
  (let ((speedbar-power-click t))
    (speedbar-click e)))

(defun speedbar-click (e)
  "Activate any speedbar buttons where the mouse is clicked.
This must be bound to a mouse event.  A button is any location of text
with a mouse face that has a text property called `speedbar-function'.
This should be bound to mouse event E."
  (interactive "e")
  (mouse-set-point e)
  (speedbar-do-function-pointer)
  (speedbar-quick-mouse e))

(defun speedbar-do-function-pointer ()
  "Look under the cursor and examine the text properties.
From this extract the file/tag name, token, indentation level and call
a function if appropriate"
  (let* ((fn (get-text-property (point) 'speedbar-function))
	 (tok (get-text-property (point) 'speedbar-token))
	 ;; The 1-,+ is safe because scaning starts AFTER the point
	 ;; specified.  This lets the search include the character the
	 ;; cursor is on.
	 (tp (previous-single-property-change
	      (1+ (point)) 'speedbar-function))
	 (np (next-single-property-change
	      (point) 'speedbar-function))
	 (txt (buffer-substring-no-properties (or tp (point-min))
					      (or np (point-max))))
	 (dent (save-excursion (beginning-of-line)
			       (string-to-number
				(if (looking-at "[0-9]+")
				    (buffer-substring-no-properties
				    (match-beginning 0) (match-end 0))
				  "0")))))
    ;;(message "%S:%S:%S:%s" fn tok txt dent)
    (and fn (funcall fn txt tok dent)))
  (speedbar-position-cursor-on-line))

;;; Reading info from the speedbar buffer
;;
(defun speedbar-line-file (&optional p)
  "Retrieve the file or whatever from the line at P point.
The return value is a string representing the file.  If it is a
directory, then it is the directory name."
  (save-excursion
    (save-match-data
      (beginning-of-line)
      (if (looking-at (concat
		       "\\([0-9]+\\): *[[<][-+?][]>] \\([^ \n]+\\)\\("
		       (regexp-quote speedbar-vc-indicator)
		       "\\)?"))
	  (let* ((depth (string-to-int (match-string 1)))
		 (path (speedbar-line-path depth))
		 (f (match-string 2)))
	    (concat path f))
	nil))))

(defun speedbar-goto-this-file (file)
  "If FILE is displayed, goto this line and return t.
Otherwise do not move and return nil."
  (let ((path (substring (file-name-directory (expand-file-name file))
			 (length (expand-file-name default-directory))))
	(dest (point)))
    (save-match-data
      (goto-char (point-min))
      ;; scan all the directories
      (while (and path (not (eq path t)))
	(if (string-match "^/?\\([^/]+\\)" path)
	    (let ((pp (match-string 1 path)))
	      (if (save-match-data
		    (re-search-forward (concat "> " (regexp-quote pp) "$")
				       nil t))
		  (setq path (substring path (match-end 1)))
		(setq path nil)))
	  (setq path t)))
      ;; find the file part
      (if (or (not path) (string= (file-name-nondirectory file) ""))
	  ;; only had a dir part
	  (if path
	      (progn
		(speedbar-position-cursor-on-line)
		t)
	    (goto-char dest) nil)
	;; find the file part
	(let ((nd (file-name-nondirectory file)))
	  (if (re-search-forward
	       (concat "] \\(" (regexp-quote nd)
		       "\\)\\(" (regexp-quote speedbar-vc-indicator) "\\)?$")
	       nil t)
	      (progn
		(speedbar-position-cursor-on-line)
		t)
	    (goto-char dest)
	    nil))))))

(defun speedbar-line-path (depth)
  "Retrieve the pathname associated with the current line.
This may require traversing backwards from DEPTH and combining the default
directory with these items."
  (save-excursion
    (save-match-data
      (let ((path nil))
	(setq depth (1- depth))
	(while (/= depth -1)
	  (if (not (re-search-backward (format "^%d:" depth) nil t))
	      (error "Error building path of tag")
	    (cond ((looking-at "[0-9]+:\\s-*<->\\s-+\\([^\n]+\\)$")
		   (setq path (concat (buffer-substring-no-properties
				       (match-beginning 1) (match-end 1))
				      "/"
				      path)))
		  ((looking-at "[0-9]+:\\s-*[-]\\s-+\\([^\n]+\\)$")
		   ;; This is the start of our path.
		   (setq path (buffer-substring-no-properties
			       (match-beginning 1) (match-end 1))))))
	  (setq depth (1- depth)))
	(if (and path
		 (string-match (concat (regexp-quote speedbar-vc-indicator) "$")
			       path))
	    (setq path (substring path 0 (match-beginning 0))))
	(concat default-directory path)))))

(defun speedbar-path-line (path)
  "Position the cursor on the line specified by PATH."
  (save-match-data
    (if (string-match "/$" path)
	(setq path (substring path 0 (match-beginning 0))))
    (let ((nomatch t) (depth 0)
	  (fname (file-name-nondirectory path))
	  (pname (file-name-directory path)))
      (if (not (member pname speedbar-shown-directories))
	  (error "Internal Error: File %s not shown in speedbar." path))
      (goto-char (point-min))
      (while (and nomatch
		  (re-search-forward
		   (concat "[]>] \\(" (regexp-quote fname)
			   "\\)\\(" (regexp-quote speedbar-vc-indicator) "\\)?$")
		   nil t))
	(beginning-of-line)
	(looking-at "\\([0-9]+\\):")
	(setq depth (string-to-int (match-string 0))
	      nomatch (not (string= pname (speedbar-line-path depth))))
	(end-of-line))
      (beginning-of-line)
      (not nomatch))))

(defun speedbar-edit-line ()
  "Edit whatever tag or file is on the current speedbar line."
  (interactive)
  (save-excursion
    (beginning-of-line)
    ;; If this fails, then it is a non-standard click, and as such,
    ;; perfectly allowed.
    (re-search-forward "[]>}] [a-zA-Z0-9]"
		       (save-excursion (end-of-line) (point)) t)
    (speedbar-do-function-pointer)))

(defun speedbar-expand-line ()
  "Expand the line under the cursor."
  (interactive)
  (beginning-of-line)
  (re-search-forward ":\\s-*.\\+. " (save-excursion (end-of-line) (point)))
  (forward-char -2)
  (speedbar-do-function-pointer))

(defun speedbar-contract-line ()
  "Contract the line under the cursor."
  (interactive)
  (beginning-of-line)
  (re-search-forward ":\\s-*.-. " (save-excursion (end-of-line) (point)))
  (forward-char -2)
  (speedbar-do-function-pointer))

(if speedbar-xemacsp
    (defalias 'speedbar-mouse-event-p 'button-press-event-p)
  (defun speedbar-mouse-event-p (event)
    "Return t if the event is a mouse related event"
    ;; And Emacs does it this way
    (if (and (listp event)
	     (member (event-basic-type event)
		     '(mouse-1 mouse-2 mouse-3)))
	t
      nil)))

(defun speedbar-maybee-jump-to-attached-frame ()
  "Jump to the attached frame ONLY if this was not a mouse event."
  (if (or (not (speedbar-mouse-event-p last-input-event))
	  speedbar-activity-change-focus-flag)
      (progn
	(select-frame speedbar-attached-frame)
	(other-frame 0))))

(defun speedbar-find-file (text token indent)
  "Speedbar click handler for filenames.
TEXT, the file will be displayed in the attached frame.
TOKEN is unused, but required by the click handler.  INDENT is the
current indentation level."
  (let ((cdd (speedbar-line-path indent)))
    (speedbar-find-file-in-frame (concat cdd text))
    (speedbar-stealthy-updates)
    (run-hooks 'speedbar-visiting-file-hook)
    ;; Reset the timer with a new timeout when cliking a file
    ;; in case the user was navigating directories, we can cancel
    ;; that other timer.
    (speedbar-set-timer speedbar-update-speed))
  (speedbar-maybee-jump-to-attached-frame))

(defun speedbar-dir-follow (text token indent)
  "Speedbar click handler for directory names.
Clicking a directory will cause the speedbar to list files in the
the subdirectory TEXT.  TOKEN is an unused requirement.  The
subdirectory chosen will be at INDENT level."
  (setq default-directory
	(concat (expand-file-name (concat (speedbar-line-path indent) text))
		"/"))
  ;; Because we leave speedbar as the current buffer,
  ;; update contents will change directory without
  ;; having to touch the attached frame.
  (speedbar-update-contents)
  (speedbar-set-timer speedbar-navigating-speed)
  (setq speedbar-last-selected-file nil)
  (speedbar-stealthy-updates))

(defun speedbar-delete-subblock (indent)
  "Delete text from point to indentation level INDENT or greater.
Handles end-of-sublist smartly."
  (speedbar-with-writable
    (save-excursion
      (end-of-line) (forward-char 1)
      (while (and (not (save-excursion
			 (re-search-forward (format "^%d:" indent)
					    nil t)))
		  (>= indent 0))
	(setq indent (1- indent)))
      (delete-region (point) (if (>= indent 0)
				 (match-beginning 0)
			       (point-max))))))

(defun speedbar-dired (text token indent)
  "Speedbar click handler for directory expand button.
Clicking this button expands or contracts a directory.  TEXT is the
button clicked which has either a + or -.  TOKEN is the directory to be
expanded.  INDENT is the current indentation level."
  (cond ((string-match "+" text)	;we have to expand this dir
	 (setq speedbar-shown-directories
	       (cons (expand-file-name
		      (concat (speedbar-line-path indent) token "/"))
		     speedbar-shown-directories))
	 (speedbar-change-expand-button-char ?-)
	 (speedbar-reset-scanners)
	 (save-excursion
	   (end-of-line) (forward-char 1)
	   (speedbar-with-writable
	     (speedbar-default-directory-list
	      (concat (speedbar-line-path indent) token "/")
	      (1+ indent)))))
	((string-match "-" text)	;we have to contract this node
	 (speedbar-reset-scanners)
	 (let ((oldl speedbar-shown-directories)
	       (newl nil)
	       (td (expand-file-name
		    (concat (speedbar-line-path indent) token))))
	   (while oldl
	     (if (not (string-match (concat "^" (regexp-quote td)) (car oldl)))
		 (setq newl (cons (car oldl) newl)))
	     (setq oldl (cdr oldl)))
	   (setq speedbar-shown-directories newl))
	 (speedbar-change-expand-button-char ?+)
	 (speedbar-delete-subblock indent)
	 )
	(t (error "Ooops... not sure what to do.")))
  (speedbar-center-buffer-smartly)
  (setq speedbar-last-selected-file nil)
  (save-excursion (speedbar-stealthy-updates)))

(defun speedbar-directory-buttons-follow (text token indent)
  "Speedbar click handler for default directory buttons.
TEXT is the button clicked on.  TOKEN is the directory to follow.
INDENT is the current indentation level and is unused."
  (setq default-directory token)
  ;; Because we leave speedbar as the current buffer,
  ;; update contents will change directory without
  ;; having to touch the attached frame.
  (speedbar-update-contents)
  (speedbar-set-timer speedbar-navigating-speed))

(defun speedbar-tag-file (text token indent)
  "The cursor is on a selected line.  Expand the tags in the specified file.
The parameter TEXT and TOKEN are required, where TEXT is the button
clicked, and TOKEN is the file to expand.  INDENT is the current
indentation level."
  (cond ((string-match "+" text)	;we have to expand this file
	 (let* ((fn (expand-file-name (concat (speedbar-line-path indent)
					      token)))
		(lst (if speedbar-use-imenu-flag
			(let ((tim (speedbar-fetch-dynamic-imenu fn)))
			  (if (eq tim t)
			      (speedbar-fetch-dynamic-etags fn)
			    tim))
		      (speedbar-fetch-dynamic-etags fn))))
	   ;; if no list, then remove expando button
	   (if (not lst)
	       (speedbar-change-expand-button-char ??)
	     (speedbar-change-expand-button-char ?-)
	     (speedbar-with-writable
	       (save-excursion
		 (end-of-line) (forward-char 1)
		 (speedbar-insert-generic-list indent
					       lst 'speedbar-tag-expand
					       'speedbar-tag-find))))))
	((string-match "-" text)	;we have to contract this node
	 (speedbar-change-expand-button-char ?+)
	 (speedbar-delete-subblock indent))
	(t (error "Ooops... not sure what to do.")))
  (speedbar-center-buffer-smartly))

(defun speedbar-tag-find (text token indent)
  "For the tag TEXT in a file TOKEN, goto that position.
INDENT is the current indentation level."
  (let ((file (speedbar-line-path indent)))
    (speedbar-find-file-in-frame file)
    (save-excursion (speedbar-stealthy-updates))
    ;; Reset the timer with a new timeout when cliking a file
    ;; in case the user was navigating directories, we can cancel
    ;; that other timer.
    (speedbar-set-timer speedbar-update-speed)
    (goto-char token)
    (run-hooks 'speedbar-visiting-tag-hook)
    ;;(recenter)
    (speedbar-maybee-jump-to-attached-frame)
    ))

(defun speedbar-tag-expand (text token indent)
  "Expand a tag sublist.  Imenu will return sub-lists of specialized tag types.
Etags does not support this feature.  TEXT will be the button
string.  TOKEN will be the list, and INDENT is the current indentation
level."
  (cond ((string-match "+" text)	;we have to expand this file
	 (speedbar-change-expand-button-char ?-)
	 (speedbar-with-writable
	   (save-excursion
	     (end-of-line) (forward-char 1)
	     (speedbar-insert-generic-list indent
					   token 'speedbar-tag-expand
					   'speedbar-tag-find))))
	((string-match "-" text)	;we have to contract this node
	 (speedbar-change-expand-button-char ?+)
	 (speedbar-delete-subblock indent))
	(t (error "Ooops... not sure what to do.")))
  (speedbar-center-buffer-smartly))

;;; Loading files into the attached frame.
;;
(defun speedbar-find-file-in-frame (file)
  "This will load FILE into the speedbar attached frame.
If the file is being displayed in a different frame already, then raise that
frame instead."
  (let* ((buff (find-file-noselect file))
	 (bwin (get-buffer-window buff 0)))
    (if bwin
	(progn
	  (select-window bwin)
	  (raise-frame (window-frame bwin)))
      (if speedbar-power-click
	  (let ((pop-up-frames t)) (select-window (display-buffer buff)))
	(select-frame speedbar-attached-frame)
	(switch-to-buffer buff))))
  )

;;; Centering Utility
;;
(defun speedbar-center-buffer-smartly ()
  "Recenter a speedbar buffer so the current indentation level is all visible.
This assumes that the cursor is on a file, or tag of a file which the user is
interested in."
  (if (<= (count-lines (point-min) (point-max))
	  (window-height (selected-window)))
      ;; whole buffer fits
      (let ((cp (point)))
	(goto-char (point-min))
	(recenter 0)
	(goto-char cp))
    ;; too big
    (let (depth start end exp p)
      (save-excursion
	(beginning-of-line)
	(setq depth (if (looking-at "[0-9]+")
			(string-to-int (buffer-substring-no-properties
					(match-beginning 0) (match-end 0)))
		      0))
	(setq exp (format "^%d:\\s-*[[{<]\\([?+-]\\)[]>}]" depth)))
      (save-excursion
	(end-of-line)
	(if (re-search-backward exp nil t)
	    (setq start (point))
	  (error "Center error"))
	(save-excursion			;Not sure about this part.
	  (end-of-line)
	  (setq p (point))
	  (while (and (not (re-search-forward exp nil t))
		      (>= depth 0))
	    (setq depth (1- depth))
	    (setq exp (format "^%d:\\s-*[[{<]\\([?+-]\\)[]>}]" depth)))
	  (if (/= (point) p)
	      (setq end (point))
	    (setq end (point-max)))))
      ;; Now work out the details of centering
      (let ((nl (count-lines start end))
	    (cp (point)))
	(if (> nl (window-height (selected-window)))
	    ;; We can't fit it all, so just center on cursor
	    (progn (goto-char start)
		   (recenter 1))
	  ;; we can fit everything on the screen, but...
	  (if (and (pos-visible-in-window-p start (selected-window))
		   (pos-visible-in-window-p end (selected-window)))
	      ;; we are all set!
	      nil
	    ;; we need to do something...
	    (goto-char start)
	    (let ((newcent (/ (- (window-height (selected-window)) nl) 2))
		  (lte (count-lines start (point-max))))
	      (if (and (< (+ newcent lte) (window-height (selected-window)))
		       (> (- (window-height (selected-window)) lte 1)
			  newcent))
		  (setq newcent (- (window-height (selected-window))
				   lte 1)))
	      (recenter newcent))))
	(goto-char cp)))))


;;; Tag Management -- Imenu
;;
(if (not speedbar-use-imenu-flag)

    nil

(eval-when-compile (if (locate-library "imenu") (require 'imenu)))

(defun speedbar-fetch-dynamic-imenu (file)
  "Load FILE into a buffer, and generate tags using Imenu.
Returns the tag list, or t for an error."
  ;; Load this AND compile it in
  (require 'imenu)
  (save-excursion
    (set-buffer (find-file-noselect file))
    (if speedbar-power-click (setq imenu--index-alist nil))
    (condition-case nil
	(let ((index-alist (imenu--make-index-alist t)))
	  (if speedbar-sort-tags
	      (sort (copy-alist index-alist)
		    (lambda (a b) (string< (car a) (car b))))
	    index-alist))
      (error t))))
)

;;; Tag Management -- etags  (XEmacs compatibility part)
;;
(defvar speedbar-fetch-etags-parse-list
  '(;; Note that java has the same parse-group as c
    ("\\.\\([cChH]\\|c++\\|cpp\\|cc\\|hh\\|java\\)$" . speedbar-parse-c-or-c++tag)
    ("\\.el\\|\\.emacs" . "defun\\s-+\\(\\(\\w\\|[-_]\\)+\\)\\s-*\C-?")
    ("\\.tex$" . speedbar-parse-tex-string)
    ("\\.p" .
     "\\(\\(FUNCTION\\|function\\|PROCEDURE\\|procedure\\)\\s-+\\([a-zA-Z0-9_.:]+\\)\\)\\s-*(?^?")

    )
  "Associations of file extensions and expressions for extracting tags.
To add a new file type, you would want to add a new association to the
list, where the car is the file match, and the cdr is the way to
extract an element from the tags output.  If the output is complex,
use a function symbol instead of regexp.  The function should expect
to be at the beginning of a line in the etags buffer.

This variable is ignored if `speedbar-use-imenu-flag' is t")

(defvar speedbar-fetch-etags-command "etags"
  "*Command used to create an etags file.

This variable is ignored if `speedbar-use-imenu-flag' is t")

(defvar speedbar-fetch-etags-arguments '("-D" "-I" "-o" "-")
  "*List of arguments to use with `speedbar-fetch-etags-command'.
This creates an etags output buffer.  Use `speedbar-toggle-etags' to
modify this list conveniently.

This variable is ignored if `speedbar-use-imenu-flag' is t")

(defun speedbar-toggle-etags (flag)
  "Toggle FLAG in `speedbar-fetch-etags-arguments'.
FLAG then becomes a member of etags command line arguments.  If flag
is \"sort\", then toggle the value of `speedbar-sort-tags'.  If it's
value is \"show\" then toggle the value of
`speedbar-show-unknown-files'.

  This function is a convenience function for XEmacs menu created by
Farzin Guilak <farzin@protocol.com>"
  (interactive)
  (cond
   ((equal flag "sort")
    (setq speedbar-sort-tags (not speedbar-sort-tags)))
   ((equal flag "show")
    (setq speedbar-show-unknown-files (not speedbar-show-unknown-files)))
   ((or (equal flag "-C")
	(equal flag "-S")
	(equal flag "-D"))
    (if (member flag speedbar-fetch-etags-arguments)
	(setq speedbar-fetch-etags-arguments
	      (delete flag speedbar-fetch-etags-arguments))
      (add-to-list 'speedbar-fetch-etags-arguments flag)))
   (t nil)))

(defun speedbar-fetch-dynamic-etags (file)
  "For FILE, run etags and create a list of symbols extracted.
Each symbol will be associated with it's line position in FILE."
  (let ((newlist nil))
    (unwind-protect
	(save-excursion
	  (if (get-buffer "*etags tmp*")
	      (kill-buffer "*etags tmp*"))	;kill to clean it up
	  (if (<= 1 speedbar-verbosity-level) (message "Fetching etags..."))
	  (set-buffer (get-buffer-create "*etags tmp*"))
	  (apply 'call-process speedbar-fetch-etags-command nil
		 (current-buffer) nil
		 (append speedbar-fetch-etags-arguments (list file)))
	  (goto-char (point-min))
	  (if (<= 1 speedbar-verbosity-level) (message "Fetching etags..."))
	  (let ((expr
		 (let ((exprlst speedbar-fetch-etags-parse-list)
		       (ans nil))
		   (while (and (not ans) exprlst)
		     (if (string-match (car (car exprlst)) file)
			 (setq ans (car exprlst)))
		     (setq exprlst (cdr exprlst)))
		   (cdr ans))))
	    (if expr
		(let (tnl)
		  (while (not (save-excursion (end-of-line) (eobp)))
		    (save-excursion
		      (setq tnl (speedbar-extract-one-symbol expr)))
		    (if tnl (setq newlist (cons tnl newlist)))
		    (forward-line 1)))
	      (message "Sorry, no support for a file of that extension"))))
      )
    (if speedbar-sort-tags
	(sort newlist (lambda (a b) (string< (car a) (car b))))
      (reverse newlist))))

;; This bit donated by Farzin Guilak <farzin@protocol.com> but I'm not
;; sure it's needed with the different sorting method.
;;
;(defun speedbar-clean-etags()
;  "Removes spaces before the ^? character, and removes `#define',
;return types, etc. preceding tags.  This ensures that the sort operation
;works on the tags, not the return types."
;  (save-excursion
;    (goto-char (point-min))
;    (while
;	(re-search-forward "(?[ \t](?\C-?" nil t)
;      (replace-match "\C-?" nil nil))
;    (goto-char (point-min))
;    (while
;	(re-search-forward "\\(.*[ \t]+\\)\\([^ \t\n]+.*\C-?\\)" nil t)
;      (delete-region (match-beginning 1) (match-end 1)))))

(defun speedbar-extract-one-symbol (expr)
  "At point, return nil, or one alist in the form: ( symbol . position )
The line should contain output from etags.  Parse the output using the
regular expression EXPR"
  (let* ((sym (if (stringp expr)
		  (if (save-excursion
			(re-search-forward expr (save-excursion
						  (end-of-line)
						  (point)) t))
		      (buffer-substring-no-properties (match-beginning 1)
						      (match-end 1)))
		(funcall expr)))
	 (pos (let ((j (re-search-forward "[\C-?\C-a]\\([0-9]+\\),\\([0-9]+\\)"
					  (save-excursion
					    (end-of-line)
					    (point))
					  t)))
		(if (and j sym)
		    (1+ (string-to-int (buffer-substring-no-properties
					(match-beginning 2)
					(match-end 2))))
		  0))))
    (if (/= pos 0)
	(cons sym pos)
      nil)))

(defun speedbar-parse-c-or-c++tag ()
  "Parse a c or c++ tag, which tends to be a little complex."
  (save-excursion
    (let ((bound (save-excursion (end-of-line) (point))))
      (cond ((re-search-forward "\C-?\\([^\C-a]+\\)\C-a" bound t)
	     (buffer-substring-no-properties (match-beginning 1)
					     (match-end 1)))
	    ((re-search-forward "\\<\\([^ \t]+\\)\\s-+new(" bound t)
	     (buffer-substring-no-properties (match-beginning 1)
					     (match-end 1)))
	    ((re-search-forward "\\<\\([^ \t(]+\\)\\s-*(\C-?" bound t)
	     (buffer-substring-no-properties (match-beginning 1)
					     (match-end 1)))
	    (t nil))
      )))

(defun speedbar-parse-tex-string ()
  "Parse a Tex string.  Only find data which is relevant."
  (save-excursion
    (let ((bound (save-excursion (end-of-line) (point))))
      (cond ((re-search-forward "\\(\\(sub\\)*section\\|chapter\\|cite\\)\\s-*{[^\C-?}]*}?" bound t)
	     (buffer-substring-no-properties (match-beginning 0)
					     (match-end 0)))
	    (t nil)))))


;;; Color loading section  This is messy *Blech!*
;;
(defun speedbar-load-color (sym l-fg l-bg d-fg d-bg &optional bold italic underline)
  "Create a color for SYM with a L-FG and L-BG color, or D-FG and D-BG.
Optionally make BOLD, ITALIC, or UNDERLINE if applicable.  If the background
attribute of the current frame is determined to be light (white, for example)
then L-FG and L-BG is used.  If not, then D-FG and D-BG is used.  This will
allocate the colors in the best possible manor.  This will allow me to store
multiple defaults and dynamically determine which colors to use."
  (let* ((params (frame-parameters))
	 (disp-res (if (fboundp 'x-get-resource)
		       (if speedbar-xemacsp
			   (x-get-resource ".displayType" "DisplayType" 'string)
			 (x-get-resource ".displayType" "DisplayType"))
		     nil))
	 (display-type
	  (cond (disp-res (intern (downcase disp-res)))
		((and (fboundp 'x-display-color-p) (x-display-color-p)) 'color)
		(t 'mono)))
	 (bg-res (if (fboundp 'x-get-resource)
		     (if speedbar-xemacsp
			 (x-get-resource ".backgroundMode" "BackgroundMode" 'string)
		       (x-get-resource ".backgroundMode" "BackgroundMode"))
		   nil))
	 (bgmode
	  (cond (bg-res (intern (downcase bg-res)))
		((let* ((bgc (or (cdr (assq 'background-color params))
				 (if speedbar-xemacsp
				     (x-get-resource ".background"
						     "Background" 'string)
				   (x-get-resource ".background"
						   "Background"))
				 ;; if no other options, default is white
				 "white"))
			(bgcr (if speedbar-xemacsp
				  (color-instance-rgb-components
				   (make-color-instance bgc))
				(x-color-values bgc)))
			(wcr (if speedbar-xemacsp
				 (color-instance-rgb-components
				  (make-color-instance "white"))
			       (x-color-values "white"))))
		   (< (apply '+ bgcr) (/ (apply '+ wcr) 3)))
		 'dark)
		(t 'light)))		;our default
	 (set-p (function (lambda (face-name resource)
			    (if speedbar-xemacsp
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
	    (set-face-foreground newface nfg))
	(if (and nbg (not (funcall set-p (symbol-name sym) "Background")))
	    (set-face-background newface nbg))

	(if bold (condition-case nil
		     (make-face-bold newface)
		   (error (message "Cannot make face %s bold!"
				       (symbol-name sym)))))
	(if italic (condition-case nil
		       (make-face-italic newface)
		     (error (message "Cannot make face %s italic!"
				     (symbol-name newface)))))
	(set-face-underline-p newface underline)
	))))

(if (x-display-color-p)
    (progn
      (speedbar-load-color 'speedbar-button-face "green4" nil "green3" nil nil nil nil)
      (speedbar-load-color 'speedbar-file-face "cyan4" nil "cyan" nil nil nil nil)
      (speedbar-load-color 'speedbar-directory-face "blue4" nil "light blue" nil nil nil nil)
      (speedbar-load-color 'speedbar-tag-face "brown" nil "yellow" nil nil nil nil)
      (speedbar-load-color 'speedbar-selected-face "red" nil "red" nil nil nil t)
      (speedbar-load-color 'speedbar-highlight-face nil "green" nil "sea green" nil nil nil)
      ) ; color
  (make-face 'speedbar-button-face)
  ;;(make-face 'speedbar-file-face)
  (copy-face 'bold 'speedbar-file-face)
  (make-face 'speedbar-directory-face)
  (make-face 'speedbar-tag-face)
  ;;(make-face 'speedbar-selected-face)
  (copy-face 'underline 'speedbar-selected-face)
  ;;(make-face 'speedbar-highlight-face)
  (copy-face 'highlight 'speedbar-highlight-face)

  ) ;; monochrome

;; some edebug hooks
(add-hook 'edebug-setup-hook
	  (lambda ()
	    (def-edebug-spec speedbar-with-writable def-body)))

(provide 'speedbar)
;;; speedbar ends here

;; run load-time hooks
(run-hooks 'speedbar-load-hook)
