;;; lisp-mode.el --- Lisp mode, and its idiosyncratic commands

;; Copyright (C) 1985,86,1999,2000,01,03,2004  Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: lisp, languages

;; This file is part of GNU Emacs.

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

;; The base major mode for editing Lisp code (used also for Emacs Lisp).
;; This mode is documented in the Emacs manual.

;;; Code:

(defvar lisp-mode-abbrev-table nil)

(defvar emacs-lisp-mode-syntax-table
  (let ((table (make-syntax-table)))
    (let ((i 0))
      (while (< i ?0)
	(modify-syntax-entry i "_   " table)
	(setq i (1+ i)))
      (setq i (1+ ?9))
      (while (< i ?A)
	(modify-syntax-entry i "_   " table)
	(setq i (1+ i)))
      (setq i (1+ ?Z))
      (while (< i ?a)
	(modify-syntax-entry i "_   " table)
	(setq i (1+ i)))
      (setq i (1+ ?z))
      (while (< i 128)
	(modify-syntax-entry i "_   " table)
	(setq i (1+ i)))
      (modify-syntax-entry ?  "    " table)
      (modify-syntax-entry ?\t "    " table)
      (modify-syntax-entry ?\f "    " table)
      (modify-syntax-entry ?\n ">   " table)
      ;; Give CR the same syntax as newline, for selective-display.
      (modify-syntax-entry ?\^m ">   " table)
      (modify-syntax-entry ?\; "<   " table)
      (modify-syntax-entry ?` "'   " table)
      (modify-syntax-entry ?' "'   " table)
      (modify-syntax-entry ?, "'   " table)
      (modify-syntax-entry ?@ "'   " table)
      ;; Used to be singlequote; changed for flonums.
      (modify-syntax-entry ?. "_   " table)
      (modify-syntax-entry ?# "'   " table)
      (modify-syntax-entry ?\" "\"    " table)
      (modify-syntax-entry ?\\ "\\   " table)
      (modify-syntax-entry ?\( "()  " table)
      (modify-syntax-entry ?\) ")(  " table)
      (modify-syntax-entry ?\[ "(]  " table)
      (modify-syntax-entry ?\] ")[  " table))
    table))

(defvar lisp-mode-syntax-table
  (let ((table (copy-syntax-table emacs-lisp-mode-syntax-table)))
    (modify-syntax-entry ?\[ "_   " table)
    (modify-syntax-entry ?\] "_   " table)
    (modify-syntax-entry ?# "' 14bn" table)
    (modify-syntax-entry ?| "\" 23b" table)
    table))

(define-abbrev-table 'lisp-mode-abbrev-table ())

(defvar lisp-imenu-generic-expression
  (list
   (list nil
	 (purecopy (concat "^\\s-*("
			   (eval-when-compile
			     (regexp-opt
			      '("defun" "defun*" "defsubst" "defmacro"
				"defadvice" "define-skeleton"
				"define-minor-mode" "define-derived-mode"
				"define-compiler-macro" "define-modify-macro"
				"defsetf" "define-setf-expander"
				"define-method-combination"
				"defgeneric" "defmethod") t))
			   "\\s-+\\(\\sw\\(\\sw\\|\\s_\\)+\\)"))
	 2)
   (list (purecopy "Variables")
	 (purecopy (concat "^\\s-*("
			   (eval-when-compile
			     (regexp-opt
			      '("defvar" "defconst" "defconstant" "defcustom"
				"defparameter" "define-symbol-macro") t))
			   "\\s-+\\(\\sw\\(\\sw\\|\\s_\\)+\\)"))
	 2)
   (list (purecopy "Types")
	 (purecopy (concat "^\\s-*("
			   (eval-when-compile
			     (regexp-opt
			      '("defgroup" "deftheme" "deftype" "defstruct"
				"defclass" "define-condition" "define-widget"
				"defface" "defpackage") t))
			   "\\s-+'?\\(\\sw\\(\\sw\\|\\s_\\)+\\)"))
	 2))

  "Imenu generic expression for Lisp mode.  See `imenu-generic-expression'.")

;; This was originally in autoload.el and is still used there.
(put 'autoload 'doc-string-elt 3)
(put 'defun    'doc-string-elt 3)
(put 'defun*    'doc-string-elt 3)
(put 'defvar   'doc-string-elt 3)
(put 'defcustom 'doc-string-elt 3)
(put 'deftheme 'doc-string-elt 2)
(put 'defconst 'doc-string-elt 3)
(put 'defmacro 'doc-string-elt 3)
(put 'defmacro* 'doc-string-elt 3)
(put 'defsubst 'doc-string-elt 3)
(put 'define-skeleton 'doc-string-elt 2)
(put 'define-derived-mode 'doc-string-elt 4)
(put 'easy-mmode-define-minor-mode 'doc-string-elt 2)
(put 'define-minor-mode 'doc-string-elt 2)
(put 'define-generic-mode 'doc-string-elt 7)
;; define-global-mode has no explicit docstring.
(put 'easy-mmode-define-global-mode 'doc-string-elt 0)
(put 'define-ibuffer-filter 'doc-string-elt 2)
(put 'define-ibuffer-op 'doc-string-elt 3)
(put 'define-ibuffer-sorter 'doc-string-elt 2)

(defun lisp-font-lock-syntactic-face-function (state)
  (if (nth 3 state)
      (if (and (eq (nth 0 state) 1)
	       ;; This might be a docstring.
	       (save-excursion
		 (let ((n 0))
		   (goto-char (nth 8 state))
		   (condition-case nil
		       (while (and (not (bobp))
				   (progn (backward-sexp 1) (setq n (1+ n)))))
		     (scan-error nil))
		   (when (> n 0)
		     (let ((sym (intern-soft
				 (buffer-substring
				  (point) (progn (forward-sexp 1) (point))))))
		       (eq n (or (get sym 'doc-string-elt) 3)))))))
	  font-lock-doc-face
	font-lock-string-face)
    font-lock-comment-face))

;; The LISP-SYNTAX argument is used by code in inf-lisp.el and is
;; (uselessly) passed from pp.el, chistory.el, gnus-kill.el and score-mode.el
(defun lisp-mode-variables (&optional lisp-syntax)
  (when lisp-syntax
    (set-syntax-table lisp-mode-syntax-table))
  (setq local-abbrev-table lisp-mode-abbrev-table)
  (make-local-variable 'paragraph-ignore-fill-prefix)
  (setq paragraph-ignore-fill-prefix t)
  (make-local-variable 'fill-paragraph-function)
  (setq fill-paragraph-function 'lisp-fill-paragraph)
  ;; Adaptive fill mode gets in the way of auto-fill,
  ;; and should make no difference for explicit fill
  ;; because lisp-fill-paragraph should do the job.
  ;;  I believe that newcomment's auto-fill code properly deals with it  -stef
  ;;(set (make-local-variable 'adaptive-fill-mode) nil)
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'lisp-indent-line)
  (make-local-variable 'indent-region-function)
  (setq indent-region-function 'lisp-indent-region)
  (make-local-variable 'parse-sexp-ignore-comments)
  (setq parse-sexp-ignore-comments t)
  (make-local-variable 'outline-regexp)
  (setq outline-regexp ";;;;* [^ \t\n]\\|(")
  (make-local-variable 'outline-level)
  (setq outline-level 'lisp-outline-level)
  (make-local-variable 'comment-start)
  (setq comment-start ";")
  (make-local-variable 'comment-start-skip)
  ;; Look within the line for a ; following an even number of backslashes
  ;; after either a non-backslash or the line beginning.
  (setq comment-start-skip "\\(\\(^\\|[^\\\\\n]\\)\\(\\\\\\\\\\)*\\);+ *")
  (make-local-variable 'comment-add)
  (setq comment-add 1)			;default to `;;' in comment-region
  (make-local-variable 'comment-column)
  (setq comment-column 40)
  ;; Don't get confused by `;' in doc strings when paragraph-filling.
  (set (make-local-variable 'comment-use-global-state) t)
  (make-local-variable 'imenu-generic-expression)
  (setq imenu-generic-expression lisp-imenu-generic-expression)
  (make-local-variable 'multibyte-syntax-as-symbol)
  (setq multibyte-syntax-as-symbol t)
  (set (make-local-variable 'syntax-begin-function) 'beginning-of-defun)
  (setq font-lock-defaults
	'((lisp-font-lock-keywords
	   lisp-font-lock-keywords-1 lisp-font-lock-keywords-2)
	  nil nil (("+-*/.<>=!?$%_&~^:" . "w")) nil
	  (font-lock-mark-block-function . mark-defun)
	  (font-lock-syntactic-face-function
	   . lisp-font-lock-syntactic-face-function))))

(defun lisp-outline-level ()
  "Lisp mode `outline-level' function."
  (if (looking-at "(\\|;;;###autoload")
      1000
    (looking-at outline-regexp)
    (- (match-end 0) (match-beginning 0))))


(defvar lisp-mode-shared-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\t" 'lisp-indent-line)
    (define-key map "\e\C-q" 'indent-sexp)
    (define-key map "\177" 'backward-delete-char-untabify)
    ;; This gets in the way when viewing a Lisp file in view-mode.  As
    ;; long as [backspace] is mapped into DEL via the
    ;; function-key-map, this should remain disabled!!
    ;;;(define-key map [backspace] 'backward-delete-char-untabify)
    map)
  "Keymap for commands shared by all sorts of Lisp modes.")

(defvar emacs-lisp-mode-map ()
  "Keymap for Emacs Lisp mode.
All commands in `lisp-mode-shared-map' are inherited by this map.")

(if emacs-lisp-mode-map
    ()
  (let ((map (make-sparse-keymap "Emacs-Lisp")))
    (setq emacs-lisp-mode-map (make-sparse-keymap))
    (set-keymap-parent emacs-lisp-mode-map lisp-mode-shared-map)
    (define-key emacs-lisp-mode-map "\e\t" 'lisp-complete-symbol)
    (define-key emacs-lisp-mode-map "\e\C-x" 'eval-defun)
    (define-key emacs-lisp-mode-map "\e\C-q" 'indent-pp-sexp)
    (define-key emacs-lisp-mode-map [menu-bar] (make-sparse-keymap))
    (define-key emacs-lisp-mode-map [menu-bar emacs-lisp]
      (cons "Emacs-Lisp" map))
    (define-key map [edebug-defun]
      '("Instrument Function for Debugging" . edebug-defun))
    (define-key map [byte-recompile]
      '("Byte-recompile Directory..." . byte-recompile-directory))
    (define-key map [emacs-byte-compile-and-load]
      '("Byte-compile And Load" . emacs-lisp-byte-compile-and-load))
    (define-key map [byte-compile]
      '("Byte-compile This File" . emacs-lisp-byte-compile))
    (define-key map [separator-eval] '("--"))
    (define-key map [eval-buffer] '("Evaluate Buffer" . eval-current-buffer))
    (define-key map [eval-region] '("Evaluate Region" . eval-region))
    (define-key map [eval-sexp] '("Evaluate Last S-expression" . eval-last-sexp))
    (define-key map [separator-format] '("--"))
    (define-key map [comment-region] '("Comment Out Region" . comment-region))
    (define-key map [indent-region] '("Indent Region" . indent-region))
    (define-key map [indent-line] '("Indent Line" . lisp-indent-line))
    (put 'eval-region 'menu-enable 'mark-active)
    (put 'comment-region 'menu-enable 'mark-active)
    (put 'indent-region 'menu-enable 'mark-active)))

(defun emacs-lisp-byte-compile ()
  "Byte compile the file containing the current buffer."
  (interactive)
  (if buffer-file-name
      (byte-compile-file buffer-file-name)
    (error "The buffer must be saved in a file first")))

(defun emacs-lisp-byte-compile-and-load ()
  "Byte-compile the current file (if it has changed), then load compiled code."
  (interactive)
  (or buffer-file-name
      (error "The buffer must be saved in a file first"))
  (require 'bytecomp)
  ;; Recompile if file or buffer has changed since last compilation.
  (if (and (buffer-modified-p)
	   (y-or-n-p (format "Save buffer %s first? " (buffer-name))))
      (save-buffer))
  (let ((compiled-file-name (byte-compile-dest-file buffer-file-name)))
    (if (file-newer-than-file-p compiled-file-name buffer-file-name)
	(load-file compiled-file-name)
      (byte-compile-file buffer-file-name t))))

(defcustom emacs-lisp-mode-hook nil
  "Hook run when entering Emacs Lisp mode."
  :options '(turn-on-eldoc-mode imenu-add-menubar-index checkdoc-minor-mode)
  :type 'hook
  :group 'lisp)

(defcustom lisp-mode-hook nil
  "Hook run when entering Lisp mode."
  :options '(imenu-add-menubar-index)
  :type 'hook
  :group 'lisp)

(defcustom lisp-interaction-mode-hook nil
  "Hook run when entering Lisp Interaction mode."
  :options '(turn-on-eldoc-mode)
  :type 'hook
  :group 'lisp)

(defun emacs-lisp-mode ()
  "Major mode for editing Lisp code to run in Emacs.
Commands:
Delete converts tabs to spaces as it moves back.
Blank lines separate paragraphs.  Semicolons start comments.
\\{emacs-lisp-mode-map}
Entry to this mode calls the value of `emacs-lisp-mode-hook'
if that value is non-nil."
  (interactive)
  (kill-all-local-variables)
  (use-local-map emacs-lisp-mode-map)
  (set-syntax-table emacs-lisp-mode-syntax-table)
  (setq major-mode 'emacs-lisp-mode)
  (setq mode-name "Emacs-Lisp")
  (lisp-mode-variables)
  (setq imenu-case-fold-search nil)
  (run-mode-hooks 'emacs-lisp-mode-hook))
(put 'emacs-lisp-mode 'custom-mode-group 'lisp)

(defvar lisp-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map lisp-mode-shared-map)
    (define-key map "\e\C-x" 'lisp-eval-defun)
    (define-key map "\C-c\C-z" 'run-lisp)
    map)
  "Keymap for ordinary Lisp mode.
All commands in `lisp-mode-shared-map' are inherited by this map.")

(defun lisp-mode ()
  "Major mode for editing Lisp code for Lisps other than GNU Emacs Lisp.
Commands:
Delete converts tabs to spaces as it moves back.
Blank lines separate paragraphs.  Semicolons start comments.
\\{lisp-mode-map}
Note that `run-lisp' may be used either to start an inferior Lisp job
or to switch back to an existing one.

Entry to this mode calls the value of `lisp-mode-hook'
if that value is non-nil."
  (interactive)
  (kill-all-local-variables)
  (use-local-map lisp-mode-map)
  (setq major-mode 'lisp-mode)
  (setq mode-name "Lisp")
  (lisp-mode-variables)
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip
       "\\(\\(^\\|[^\\\\\n]\\)\\(\\\\\\\\\\)*\\)\\(;+\\|#|\\) *")
  (make-local-variable 'font-lock-keywords-case-fold-search)
  (setq font-lock-keywords-case-fold-search t)
  (setq imenu-case-fold-search t)
  (set-syntax-table lisp-mode-syntax-table)
  (run-mode-hooks 'lisp-mode-hook))
(put 'lisp-mode 'find-tag-default-function 'lisp-find-tag-default)

(defun lisp-find-tag-default ()
  (let ((default (find-tag-default)))
    (when (stringp default)
      (if (string-match ":+" default)
          (substring default (match-end 0))
          default))))

;; Used in old LispM code.
(defalias 'common-lisp-mode 'lisp-mode)

;; This will do unless inf-lisp.el is loaded.
(defun lisp-eval-defun (&optional and-go)
  "Send the current defun to the Lisp process made by \\[run-lisp]."
  (interactive)
  (error "Process lisp does not exist"))

(defvar lisp-interaction-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map lisp-mode-shared-map)
    (define-key map "\e\C-x" 'eval-defun)
    (define-key map "\e\C-q" 'indent-pp-sexp)
    (define-key map "\e\t" 'lisp-complete-symbol)
    (define-key map "\n" 'eval-print-last-sexp)
    map)
  "Keymap for Lisp Interaction mode.
All commands in `lisp-mode-shared-map' are inherited by this map.")

(defvar lisp-interaction-mode-abbrev-table lisp-mode-abbrev-table)
(define-derived-mode lisp-interaction-mode emacs-lisp-mode "Lisp Interaction"
  "Major mode for typing and evaluating Lisp forms.
Like Lisp mode except that \\[eval-print-last-sexp] evals the Lisp expression
before point, and prints its value into the buffer, advancing point.
Note that printing is controlled by `eval-expression-print-length'
and `eval-expression-print-level'.

Commands:
Delete converts tabs to spaces as it moves back.
Paragraphs are separated only by blank lines.
Semicolons start comments.
\\{lisp-interaction-mode-map}
Entry to this mode calls the value of `lisp-interaction-mode-hook'
if that value is non-nil.")

(defun eval-print-last-sexp ()
  "Evaluate sexp before point; print value into current buffer.

Note that printing the result is controlled by the variables
`eval-expression-print-length' and `eval-expression-print-level',
which see."
  (interactive)
  (let ((standard-output (current-buffer)))
    (terpri)
    (eval-last-sexp t)
    (terpri)))


(defun last-sexp-setup-props (beg end value alt1 alt2)
  "Set up text properties for the output of `eval-last-sexp-1'.
BEG and END are the start and end of the output in current-buffer.
VALUE is the Lisp value printed, ALT1 and ALT2 are strings for the
alternative printed representations that can be displayed."
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-m" 'last-sexp-toggle-display)
    (define-key map [down-mouse-2] 'mouse-set-point)
    (define-key map [mouse-2] 'last-sexp-toggle-display)
    (add-text-properties
     beg end
     `(printed-value (,value ,alt1 ,alt2)
		     mouse-face highlight
		     keymap ,map
		     help-echo "RET, mouse-2: toggle abbreviated display"
		     rear-nonsticky (mouse-face keymap help-echo
						printed-value)))))


(defun last-sexp-toggle-display (&optional arg)
  "Toggle between abbreviated and unabbreviated printed representations."
  (interactive "P")
  (save-restriction
    (widen)
    (let ((value (get-text-property (point) 'printed-value)))
      (when value
	(let ((beg (or (previous-single-property-change (min (point-max) (1+ (point)))
							'printed-value)
		       (point)))
	      (end (or (next-single-char-property-change (point) 'printed-value) (point)))
	      (standard-output (current-buffer))
	      (point (point)))
	  (delete-region beg end)
	  (insert (nth 1 value))
	  (last-sexp-setup-props beg (point)
				 (nth 0 value)
				 (nth 2 value)
				 (nth 1 value))
	  (goto-char (min (point-max) point)))))))

(defun prin1-char (char)
  "Return a string representing CHAR as a character rather than as an integer.
If CHAR is not a character, return nil."
  (and (integerp char)
       (eventp char)
       (let ((c (event-basic-type char)))
	 (concat
	  "?"
	  (mapconcat
	   (lambda (modif)
	     (cond ((eq modif 'super) "\\s-")
		   (t (string ?\\ (upcase (aref (symbol-name modif) 0)) ?-))))
	   (event-modifiers char) "")
	  (cond
	   ((memq c '(?\; ?\( ?\) ?\{ ?\} ?\[ ?\] ?\" ?\' ?\\)) (string ?\\ c))
	   ((eq c 127) "\\C-?")
	   (t
	    (condition-case nil
		(string c)
	      (error nil))))))))

(defun eval-last-sexp-1 (eval-last-sexp-arg-internal)
  "Evaluate sexp before point; print value in minibuffer.
With argument, print output into current buffer."
  (let ((standard-output (if eval-last-sexp-arg-internal (current-buffer) t)))
    (let ((value
	   (eval (let ((stab (syntax-table))
		       (opoint (point))
		       ignore-quotes
		       expr)
		   (save-excursion
		     (with-syntax-table emacs-lisp-mode-syntax-table
		       ;; If this sexp appears to be enclosed in `...'
		       ;; then ignore the surrounding quotes.
		       (setq ignore-quotes
			     (or (eq (following-char) ?\')
				 (eq (preceding-char) ?\')))
		       (forward-sexp -1)
		       ;; If we were after `?\e' (or similar case),
		       ;; use the whole thing, not just the `e'.
		       (when (eq (preceding-char) ?\\)
			 (forward-char -1)
			 (when (eq (preceding-char) ??)
			   (forward-char -1)))

		       ;; Skip over `#N='s.
		       (when (eq (preceding-char) ?=)
			 (let (labeled-p)
			   (save-excursion
			     (skip-chars-backward "0-9#=")
			     (setq labeled-p (looking-at "\\(#[0-9]+=\\)+")))
			   (when labeled-p
			     (forward-sexp -1))))

		       (save-restriction
			 ;; vladimir@cs.ualberta.ca 30-Jul-1997: skip ` in
			 ;; `variable' so that the value is returned, not the
			 ;; name
			 (if (and ignore-quotes
				  (eq (following-char) ?`))
			     (forward-char))
			 (narrow-to-region (point-min) opoint)
			 (setq expr (read (current-buffer)))
			 ;; If it's an (interactive ...) form, it's more
			 ;; useful to show how an interactive call would
			 ;; use it.
			 (and (consp expr)
			      (eq (car expr) 'interactive)
			      (setq expr
				    (list 'call-interactively
					  (list 'quote
						(list 'lambda
						      '(&rest args)
						      expr
						      'args)))))
			 expr)))))))
      (eval-last-sexp-print-value value))))

(defun eval-last-sexp-print-value (value)
  (let ((unabbreviated (let ((print-length nil) (print-level nil))
			 (prin1-to-string value)))
	(print-length eval-expression-print-length)
	(print-level eval-expression-print-level)
	(beg (point))
	end)
    (prog1
	(prin1 value)
      (let ((str (eval-expression-print-format value)))
	(if str (princ str)))
      (setq end (point))
      (when (and (bufferp standard-output)
		 (or (not (null print-length))
		     (not (null print-level)))
		 (not (string= unabbreviated
			       (buffer-substring-no-properties beg end))))
	(last-sexp-setup-props beg end value
			       unabbreviated
			       (buffer-substring-no-properties beg end))
	))))


(defvar eval-last-sexp-fake-value (make-symbol "t"))

(defun eval-last-sexp (eval-last-sexp-arg-internal)
  "Evaluate sexp before point; print value in minibuffer.
Interactively, with prefix argument, print output into current buffer."
  (interactive "P")
  (if (null eval-expression-debug-on-error)
      (eval-last-sexp-1 eval-last-sexp-arg-internal)
    (let ((old-value eval-last-sexp-fake-value) new-value value)
      (let ((debug-on-error old-value))
	(setq value (eval-last-sexp-1 eval-last-sexp-arg-internal))
	(setq new-value debug-on-error))
      (unless (eq old-value new-value)
	(setq debug-on-error new-value))
      value)))

(defun eval-defun-1 (form)
  "Treat some expressions specially.
Reset the `defvar' and `defcustom' variables to the initial value.
Reinitialize the face according to the `defface' specification."
  ;; The code in edebug-defun should be consistent with this, but not
  ;; the same, since this gets a macroexpended form.
  (cond ((not (listp form))
	 form)
	((and (eq (car form) 'defvar)
	      (cdr-safe (cdr-safe form))
	      (boundp (cadr form)))
	 ;; Force variable to be re-set.
	 `(progn (defvar ,(nth 1 form) nil ,@(nthcdr 3 form))
		 (setq ,(nth 1 form) ,(nth 2 form))))
	;; `defcustom' is now macroexpanded to
	;; `custom-declare-variable' with a quoted value arg.
	((and (eq (car form) 'custom-declare-variable)
	      (default-boundp (eval (nth 1 form))))
	 ;; Force variable to be bound.
	 (set-default (eval (nth 1 form)) (eval (nth 1 (nth 2 form))))
	 form)
	;; `defface' is macroexpanded to `custom-declare-face'.
	((eq (car form) 'custom-declare-face)
	 ;; Reset the face.
	 (put (eval (nth 1 form)) 'face-defface-spec nil)
	 (setq face-new-frame-defaults
	       (assq-delete-all (eval (nth 1 form)) face-new-frame-defaults))
	 form)
	((eq (car form) 'progn)
	 (cons 'progn (mapcar 'eval-defun-1 (cdr form))))
	(t form)))

(defun eval-defun-2 ()
  "Evaluate defun that point is in or before.
The value is displayed in the minibuffer.
If the current defun is actually a call to `defvar',
then reset the variable using the initial value expression
even if the variable already has some other value.
\(Normally `defvar' does not change the variable's value
if it already has a value.\)

With argument, insert value in current buffer after the defun.
Return the result of evaluation."
  (interactive "P")
  (let ((debug-on-error eval-expression-debug-on-error)
	(print-length eval-expression-print-length)
	(print-level eval-expression-print-level))
    (save-excursion
      ;; Arrange for eval-region to "read" the (possibly) altered form.
      ;; eval-region handles recording which file defines a function or
      ;; variable.  Re-written using `apply' to avoid capturing
      ;; variables like `end'.
      (apply
       #'eval-region
       (let ((standard-output t)
	     beg end form)
	 ;; Read the form from the buffer, and record where it ends.
	 (save-excursion
	   (end-of-defun)
	   (beginning-of-defun)
	   (setq beg (point))
	   (setq form (read (current-buffer)))
	   (setq end (point)))
	 ;; Alter the form if necessary.
	 (setq form (eval-defun-1 (macroexpand form)))
	 (list beg end standard-output
	       `(lambda (ignore)
		 ;; Skipping to the end of the specified region
		 ;; will make eval-region return.
		 (goto-char ,end)
		 ',form))))))
  ;; The result of evaluation has been put onto VALUES.  So return it.
  (car values))

(defun eval-defun (edebug-it)
  "Evaluate the top-level form containing point, or after point.

If the current defun is actually a call to `defvar' or `defcustom',
evaluating it this way resets the variable using its initial value
expression even if the variable already has some other value.
\(Normally `defvar' and `defcustom' do not alter the value if there
already is one.)

With a prefix argument, instrument the code for Edebug.

If acting on a `defun' for FUNCTION, and the function was
instrumented, `Edebug: FUNCTION' is printed in the minibuffer.  If not
instrumented, just FUNCTION is printed.

If not acting on a `defun', the result of evaluation is displayed in
the minibuffer.  This display is controlled by the variables
`eval-expression-print-length' and `eval-expression-print-level',
which see."
  (interactive "P")
  (cond (edebug-it
	 (require 'edebug)
	 (eval-defun (not edebug-all-defs)))
	(t
	 (if (null eval-expression-debug-on-error)
	     (eval-defun-2)
	   (let ((old-value (make-symbol "t")) new-value value)
	     (let ((debug-on-error old-value))
	       (setq value (eval-defun-2))
	       (setq new-value debug-on-error))
	     (unless (eq old-value new-value)
	       (setq debug-on-error new-value))
	     value)))))


(defun lisp-comment-indent ()
  (if (looking-at "\\s<\\s<\\s<")
      (current-column)
    (if (looking-at "\\s<\\s<")
	(let ((tem (or (calculate-lisp-indent) (current-column))))
	  (if (listp tem) (car tem) tem))
      (skip-chars-backward " \t")
      (max (if (bolp) 0 (1+ (current-column)))
	   comment-column))))

;; This function just forces a more costly detection of comments (using
;; parse-partial-sexp from beginning-of-defun).  I.e. It avoids the problem of
;; taking a `;' inside a string started on another line for a comment starter.
;; Note: `newcomment' gets it right now since we set comment-use-global-state
;; so we could get rid of it.   -stef
(defun lisp-mode-auto-fill ()
  (if (> (current-column) (current-fill-column))
      (if (save-excursion
	    (nth 4 (syntax-ppss (point))))
	  (do-auto-fill)
	(unless (and (boundp 'comment-auto-fill-only-comments)
		     comment-auto-fill-only-comments)
	  (let ((comment-start nil) (comment-start-skip nil))
	    (do-auto-fill))))))

(defvar lisp-indent-offset nil
  "If non-nil, indent second line of expressions that many more columns.")
(defvar lisp-indent-function 'lisp-indent-function)

(defun lisp-indent-line (&optional whole-exp)
  "Indent current line as Lisp code.
With argument, indent any additional lines of the same expression
rigidly along with this one."
  (interactive "P")
  (let ((indent (calculate-lisp-indent)) shift-amt end
	(pos (- (point-max) (point)))
	(beg (progn (beginning-of-line) (point))))
    (skip-chars-forward " \t")
    (if (or (null indent) (looking-at "\\s<\\s<\\s<"))
	;; Don't alter indentation of a ;;; comment line
	;; or a line that starts in a string.
	(goto-char (- (point-max) pos))
      (if (and (looking-at "\\s<") (not (looking-at "\\s<\\s<")))
	  ;; Single-semicolon comment lines should be indented
	  ;; as comment lines, not as code.
	  (progn (indent-for-comment) (forward-char -1))
	(if (listp indent) (setq indent (car indent)))
	(setq shift-amt (- indent (current-column)))
	(if (zerop shift-amt)
	    nil
	  (delete-region beg (point))
	  (indent-to indent)))
      ;; If initial point was within line's indentation,
      ;; position after the indentation.  Else stay at same point in text.
      (if (> (- (point-max) pos) (point))
	  (goto-char (- (point-max) pos)))
      ;; If desired, shift remaining lines of expression the same amount.
      (and whole-exp (not (zerop shift-amt))
	   (save-excursion
	     (goto-char beg)
	     (forward-sexp 1)
	     (setq end (point))
	     (goto-char beg)
	     (forward-line 1)
	     (setq beg (point))
	     (> end beg))
	   (indent-code-rigidly beg end shift-amt)))))

(defvar calculate-lisp-indent-last-sexp)

(defun calculate-lisp-indent (&optional parse-start)
  "Return appropriate indentation for current line as Lisp code.
In usual case returns an integer: the column to indent to.
If the value is nil, that means don't change the indentation
because the line starts inside a string.

The value can also be a list of the form (COLUMN CONTAINING-SEXP-START).
This means that following lines at the same level of indentation
should not necessarily be indented the same as this line.
Then COLUMN is the column to indent to, and CONTAINING-SEXP-START
is the buffer position of the start of the containing expression."
  (save-excursion
    (beginning-of-line)
    (let ((indent-point (point))
          state paren-depth
          ;; setting this to a number inhibits calling hook
          (desired-indent nil)
          (retry t)
          calculate-lisp-indent-last-sexp containing-sexp)
      (if parse-start
          (goto-char parse-start)
          (beginning-of-defun))
      ;; Find outermost containing sexp
      (while (< (point) indent-point)
        (setq state (parse-partial-sexp (point) indent-point 0)))
      ;; Find innermost containing sexp
      (while (and retry
		  state
                  (> (setq paren-depth (elt state 0)) 0))
        (setq retry nil)
        (setq calculate-lisp-indent-last-sexp (elt state 2))
        (setq containing-sexp (elt state 1))
        ;; Position following last unclosed open.
        (goto-char (1+ containing-sexp))
        ;; Is there a complete sexp since then?
        (if (and calculate-lisp-indent-last-sexp
		 (> calculate-lisp-indent-last-sexp (point)))
            ;; Yes, but is there a containing sexp after that?
            (let ((peek (parse-partial-sexp calculate-lisp-indent-last-sexp
					    indent-point 0)))
              (if (setq retry (car (cdr peek))) (setq state peek)))))
      (if retry
          nil
        ;; Innermost containing sexp found
        (goto-char (1+ containing-sexp))
        (if (not calculate-lisp-indent-last-sexp)
	    ;; indent-point immediately follows open paren.
	    ;; Don't call hook.
            (setq desired-indent (current-column))
	  ;; Find the start of first element of containing sexp.
	  (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
	  (cond ((looking-at "\\s(")
		 ;; First element of containing sexp is a list.
		 ;; Indent under that list.
		 )
		((> (save-excursion (forward-line 1) (point))
		    calculate-lisp-indent-last-sexp)
		 ;; This is the first line to start within the containing sexp.
		 ;; It's almost certainly a function call.
		 (if (= (point) calculate-lisp-indent-last-sexp)
		     ;; Containing sexp has nothing before this line
		     ;; except the first element.  Indent under that element.
		     nil
		   ;; Skip the first element, find start of second (the first
		   ;; argument of the function call) and indent under.
		   (progn (forward-sexp 1)
			  (parse-partial-sexp (point)
					      calculate-lisp-indent-last-sexp
					      0 t)))
		 (backward-prefix-chars))
		(t
		 ;; Indent beneath first sexp on same line as
		 ;; `calculate-lisp-indent-last-sexp'.  Again, it's
		 ;; almost certainly a function call.
		 (goto-char calculate-lisp-indent-last-sexp)
		 (beginning-of-line)
		 (parse-partial-sexp (point) calculate-lisp-indent-last-sexp
				     0 t)
		 (backward-prefix-chars)))))
      ;; Point is at the point to indent under unless we are inside a string.
      ;; Call indentation hook except when overridden by lisp-indent-offset
      ;; or if the desired indentation has already been computed.
      (let ((normal-indent (current-column)))
        (cond ((elt state 3)
               ;; Inside a string, don't change indentation.
	       nil)
              ((and (integerp lisp-indent-offset) containing-sexp)
               ;; Indent by constant offset
               (goto-char containing-sexp)
               (+ (current-column) lisp-indent-offset))
              (desired-indent)
              ((and (boundp 'lisp-indent-function)
                    lisp-indent-function
                    (not retry))
               (or (funcall lisp-indent-function indent-point state)
                   normal-indent))
              (t
               normal-indent))))))

(defun lisp-indent-function (indent-point state)
  "This function is the normal value of the variable `lisp-indent-function'.
It is used when indenting a line within a function call, to see if the
called function says anything special about how to indent the line.

INDENT-POINT is the position where the user typed TAB, or equivalent.
Point is located at the point to indent under (for default indentation);
STATE is the `parse-partial-sexp' state for that position.

If the current line is in a call to a Lisp function
which has a non-nil property `lisp-indent-function',
that specifies how to do the indentation.  The property value can be
* `defun', meaning indent `defun'-style;
* an integer N, meaning indent the first N arguments specially
like ordinary function arguments and then indent any further
aruments like a body;
* a function to call just as this function was called.
If that function returns nil, that means it doesn't specify
the indentation.

This function also returns nil meaning don't specify the indentation."
  (let ((normal-indent (current-column)))
    (goto-char (1+ (elt state 1)))
    (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
    (if (and (elt state 2)
             (not (looking-at "\\sw\\|\\s_")))
        ;; car of form doesn't seem to be a symbol
        (progn
          (if (not (> (save-excursion (forward-line 1) (point))
                      calculate-lisp-indent-last-sexp))
		(progn (goto-char calculate-lisp-indent-last-sexp)
		       (beginning-of-line)
		       (parse-partial-sexp (point)
					   calculate-lisp-indent-last-sexp 0 t)))
	    ;; Indent under the list or under the first sexp on the same
	    ;; line as calculate-lisp-indent-last-sexp.  Note that first
	    ;; thing on that line has to be complete sexp since we are
          ;; inside the innermost containing sexp.
          (backward-prefix-chars)
          (current-column))
      (let ((function (buffer-substring (point)
					(progn (forward-sexp 1) (point))))
	    method)
	(setq method (or (get (intern-soft function) 'lisp-indent-function)
			 (get (intern-soft function) 'lisp-indent-hook)))
	(cond ((or (eq method 'defun)
		   (and (null method)
			(> (length function) 3)
			(string-match "\\`def" function)))
	       (lisp-indent-defform state indent-point))
	      ((integerp method)
	       (lisp-indent-specform method state
				     indent-point normal-indent))
	      (method
		(funcall method state indent-point)))))))

(defvar lisp-body-indent 2
  "Number of columns to indent the second line of a `(def...)' form.")

(defun lisp-indent-specform (count state indent-point normal-indent)
  (let ((containing-form-start (elt state 1))
        (i count)
        body-indent containing-form-column)
    ;; Move to the start of containing form, calculate indentation
    ;; to use for non-distinguished forms (> count), and move past the
    ;; function symbol.  lisp-indent-function guarantees that there is at
    ;; least one word or symbol character following open paren of containing
    ;; form.
    (goto-char containing-form-start)
    (setq containing-form-column (current-column))
    (setq body-indent (+ lisp-body-indent containing-form-column))
    (forward-char 1)
    (forward-sexp 1)
    ;; Now find the start of the last form.
    (parse-partial-sexp (point) indent-point 1 t)
    (while (and (< (point) indent-point)
                (condition-case ()
                    (progn
                      (setq count (1- count))
                      (forward-sexp 1)
                      (parse-partial-sexp (point) indent-point 1 t))
                  (error nil))))
    ;; Point is sitting on first character of last (or count) sexp.
    (if (> count 0)
        ;; A distinguished form.  If it is the first or second form use double
        ;; lisp-body-indent, else normal indent.  With lisp-body-indent bound
        ;; to 2 (the default), this just happens to work the same with if as
        ;; the older code, but it makes unwind-protect, condition-case,
        ;; with-output-to-temp-buffer, et. al. much more tasteful.  The older,
        ;; less hacked, behavior can be obtained by replacing below with
        ;; (list normal-indent containing-form-start).
        (if (<= (- i count) 1)
            (list (+ containing-form-column (* 2 lisp-body-indent))
                  containing-form-start)
            (list normal-indent containing-form-start))
      ;; A non-distinguished form.  Use body-indent if there are no
      ;; distinguished forms and this is the first undistinguished form,
      ;; or if this is the first undistinguished form and the preceding
      ;; distinguished form has indentation at least as great as body-indent.
      (if (or (and (= i 0) (= count 0))
              (and (= count 0) (<= body-indent normal-indent)))
          body-indent
          normal-indent))))

(defun lisp-indent-defform (state indent-point)
  (goto-char (car (cdr state)))
  (forward-line 1)
  (if (> (point) (car (cdr (cdr state))))
      (progn
	(goto-char (car (cdr state)))
	(+ lisp-body-indent (current-column)))))


;; (put 'progn 'lisp-indent-function 0), say, causes progn to be indented
;; like defun if the first form is placed on the next line, otherwise
;; it is indented like any other form (i.e. forms line up under first).

(put 'lambda 'lisp-indent-function 'defun)
(put 'autoload 'lisp-indent-function 'defun)
(put 'progn 'lisp-indent-function 0)
(put 'prog1 'lisp-indent-function 1)
(put 'prog2 'lisp-indent-function 2)
(put 'save-excursion 'lisp-indent-function 0)
(put 'save-window-excursion 'lisp-indent-function 0)
(put 'save-selected-window 'lisp-indent-function 0)
(put 'save-restriction 'lisp-indent-function 0)
(put 'save-match-data 'lisp-indent-function 0)
(put 'save-current-buffer 'lisp-indent-function 0)
(put 'with-current-buffer 'lisp-indent-function 1)
(put 'combine-after-change-calls 'lisp-indent-function 0)
(put 'with-output-to-string 'lisp-indent-function 0)
(put 'with-temp-file 'lisp-indent-function 1)
(put 'with-temp-buffer 'lisp-indent-function 0)
(put 'with-temp-message 'lisp-indent-function 1)
(put 'with-syntax-table 'lisp-indent-function 1)
(put 'let 'lisp-indent-function 1)
(put 'let* 'lisp-indent-function 1)
(put 'while 'lisp-indent-function 1)
(put 'if 'lisp-indent-function 2)
(put 'read-if 'lisp-indent-function 2)
(put 'catch 'lisp-indent-function 1)
(put 'condition-case 'lisp-indent-function 2)
(put 'unwind-protect 'lisp-indent-function 1)
(put 'with-output-to-temp-buffer 'lisp-indent-function 1)
(put 'eval-after-load 'lisp-indent-function 1)
(put 'dolist 'lisp-indent-function 1)
(put 'dotimes 'lisp-indent-function 1)
(put 'when 'lisp-indent-function 1)
(put 'unless 'lisp-indent-function 1)

(defun indent-sexp (&optional endpos)
  "Indent each line of the list starting just after point.
If optional arg ENDPOS is given, indent each line, stopping when
ENDPOS is encountered."
  (interactive)
  (let ((indent-stack (list nil))
	(next-depth 0)
	;; If ENDPOS is non-nil, use nil as STARTING-POINT
	;; so that calculate-lisp-indent will find the beginning of
	;; the defun we are in.
	;; If ENDPOS is nil, it is safe not to scan before point
	;; since every line we indent is more deeply nested than point is.
	(starting-point (if endpos nil (point)))
	(last-point (point))
	last-depth bol outer-loop-done inner-loop-done state this-indent)
    (or endpos
	;; Get error now if we don't have a complete sexp after point.
	(save-excursion (forward-sexp 1)))
    (save-excursion
      (setq outer-loop-done nil)
      (while (if endpos (< (point) endpos)
	       (not outer-loop-done))
	(setq last-depth next-depth
	      inner-loop-done nil)
	;; Parse this line so we can learn the state
	;; to indent the next line.
	;; This inner loop goes through only once
	;; unless a line ends inside a string.
	(while (and (not inner-loop-done)
		    (not (setq outer-loop-done (eobp))))
	  (setq state (parse-partial-sexp (point) (progn (end-of-line) (point))
					  nil nil state))
	  (setq next-depth (car state))
	  ;; If the line contains a comment other than the sort
	  ;; that is indented like code,
	  ;; indent it now with indent-for-comment.
	  ;; Comments indented like code are right already.
	  ;; In any case clear the in-comment flag in the state
	  ;; because parse-partial-sexp never sees the newlines.
	  (if (car (nthcdr 4 state))
	      (progn (indent-for-comment)
		     (end-of-line)
		     (setcar (nthcdr 4 state) nil)))
	  ;; If this line ends inside a string,
	  ;; go straight to next line, remaining within the inner loop,
	  ;; and turn off the \-flag.
	  (if (car (nthcdr 3 state))
	      (progn
		(forward-line 1)
		(setcar (nthcdr 5 state) nil))
	    (setq inner-loop-done t)))
	(and endpos
	     (<= next-depth 0)
	     (progn
	       (setq indent-stack (nconc indent-stack
					 (make-list (- next-depth) nil))
		     last-depth (- last-depth next-depth)
		     next-depth 0)))
	(or outer-loop-done endpos
	    (setq outer-loop-done (<= next-depth 0)))
	(if outer-loop-done
	    (forward-line 1)
	  (while (> last-depth next-depth)
	    (setq indent-stack (cdr indent-stack)
		  last-depth (1- last-depth)))
	  (while (< last-depth next-depth)
	    (setq indent-stack (cons nil indent-stack)
		  last-depth (1+ last-depth)))
	  ;; Now go to the next line and indent it according
	  ;; to what we learned from parsing the previous one.
	  (forward-line 1)
	  (setq bol (point))
	  (skip-chars-forward " \t")
	  ;; But not if the line is blank, or just a comment
	  ;; (except for double-semi comments; indent them as usual).
	  (if (or (eobp) (looking-at "\\s<\\|\n"))
	      nil
	    (if (and (car indent-stack)
		     (>= (car indent-stack) 0))
		(setq this-indent (car indent-stack))
	      (let ((val (calculate-lisp-indent
			  (if (car indent-stack) (- (car indent-stack))
			    starting-point))))
		(if (null val)
		    (setq this-indent val)
		  (if (integerp val)
		      (setcar indent-stack
			      (setq this-indent val))
		    (setcar indent-stack (- (car (cdr val))))
		    (setq this-indent (car val))))))
	    (if (and this-indent (/= (current-column) this-indent))
		(progn (delete-region bol (point))
		       (indent-to this-indent)))))
	(or outer-loop-done
	    (setq outer-loop-done (= (point) last-point))
	    (setq last-point (point)))))))

(defun lisp-indent-region (start end)
  "Indent every line whose first char is between START and END inclusive."
  (save-excursion
    (let ((endmark (copy-marker end)))
      (goto-char start)
      (and (bolp) (not (eolp))
	   (lisp-indent-line))
      (indent-sexp endmark)
      (set-marker endmark nil))))

(defun indent-pp-sexp (&optional arg)
  "Indent each line of the list or, with prefix ARG, pretty-printify the list."
  (interactive "P")
  (if arg
      (save-excursion
        (save-restriction
          (narrow-to-region (point) (progn (forward-sexp 1) (point)))
          (pp-buffer)
          (goto-char (point-max))
          (if (eq (char-before) ?\n)
              (delete-char -1)))))
  (indent-sexp))

;;;; Lisp paragraph filling commands.

(defcustom emacs-lisp-docstring-fill-column 65
  "Value of `fill-column' to use when filling a docstring.
Any non-integer value means do not use a different value of
`fill-column' when filling docstrings."
  :type '(choice (integer)
                 (const :tag "Use the current `fill-column'" t))
  :group 'lisp)

(defun lisp-fill-paragraph (&optional justify)
  "Like \\[fill-paragraph], but handle Emacs Lisp comments and docstrings.
If any of the current line is a comment, fill the comment or the
paragraph of it that point is in, preserving the comment's indentation
and initial semicolons."
  (interactive "P")
  (or (fill-comment-paragraph justify)
      ;; Point is on a program line (a line no comment); we are interested
      ;; particularly in docstring lines.
      ;;
      ;; We bind `paragraph-start' and `paragraph-separate' temporarily.  They
      ;; are buffer-local, but we avoid changing them so that they can be set
      ;; to make `forward-paragraph' and friends do something the user wants.
      ;;
      ;; `paragraph-start': The `(' in the character alternative and the
      ;; left-singlequote plus `(' sequence after the \\| alternative prevent
      ;; sexps and backquoted sexps that follow a docstring from being filled
      ;; with the docstring.  This setting has the consequence of inhibiting
      ;; filling many program lines that are not docstrings, which is sensible,
      ;; because the user probably asked to fill program lines by accident, or
      ;; expecting indentation (perhaps we should try to do indenting in that
      ;; case).  The `;' and `:' stop the paragraph being filled at following
      ;; comment lines and at keywords (e.g., in `defcustom').  Left parens are
      ;; escaped to keep font-locking, filling, & paren matching in the source
      ;; file happy.
      ;;
      ;; `paragraph-separate': A clever regexp distinguishes the first line of
      ;; a docstring and identifies it as a paragraph separator, so that it
      ;; won't be filled.  (Since the first line of documentation stands alone
      ;; in some contexts, filling should not alter the contents the author has
      ;; chosen.)  Only the first line of a docstring begins with whitespace
      ;; and a quotation mark and ends with a period or (rarely) a comma.
      ;;
      ;; The `fill-column' is temporarily bound to
      ;; `emacs-lisp-docstring-fill-column' if that value is an integer.
      (let ((paragraph-start (concat paragraph-start
				     "\\|\\s-*\\([\(;:\"]\\|`\(\\)"))
	    (paragraph-separate
	     (concat paragraph-separate "\\|\\s-*\".*[,\\.]$"))
            (fill-column (if (integerp emacs-lisp-docstring-fill-column)
                             emacs-lisp-docstring-fill-column
                           fill-column)))
	(fill-paragraph justify))
      ;; Never return nil.
      t))

(defun indent-code-rigidly (start end arg &optional nochange-regexp)
  "Indent all lines of code, starting in the region, sideways by ARG columns.
Does not affect lines starting inside comments or strings, assuming that
the start of the region is not inside them.

Called from a program, takes args START, END, COLUMNS and NOCHANGE-REGEXP.
The last is a regexp which, if matched at the beginning of a line,
means don't indent that line."
  (interactive "r\np")
  (let (state)
    (save-excursion
      (goto-char end)
      (setq end (point-marker))
      (goto-char start)
      (or (bolp)
	  (setq state (parse-partial-sexp (point)
					  (progn
					    (forward-line 1) (point))
					  nil nil state)))
      (while (< (point) end)
	(or (car (nthcdr 3 state))
	    (and nochange-regexp
		 (looking-at nochange-regexp))
	    ;; If line does not start in string, indent it
	    (let ((indent (current-indentation)))
	      (delete-region (point) (progn (skip-chars-forward " \t") (point)))
	      (or (eolp)
		  (indent-to (max 0 (+ indent arg)) 0))))
	(setq state (parse-partial-sexp (point)
					(progn
					  (forward-line 1) (point))
					nil nil state))))))

(provide 'lisp-mode)

;;; arch-tag: 414c7f93-c245-4b77-8ed5-ed05ef7ff1bf
;;; lisp-mode.el ends here
