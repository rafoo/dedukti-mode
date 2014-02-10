;;; dedukti-mode.el --- Major mode for Dedukti files

;; Copyright 2013 Raphaël Cauderlier

;; Author: Raphaël Cauderlier
;; Version: 0.1
;; License: CeCILL-B

;;; Commentary:
;; This file defines a major mode for editing Dedukti files.
;; Dedukti is a type checker for the lambda-Pi-calculus modulo.
;; It is a free software under the CeCILL-B license.
;; Dedukti is available at the following url:
;; <https://www.rocq.inria.fr/deducteam/Dedukti/>

;; This major mode is defined using the generic major mode mechanism.

;;; Code:

;; Customization

(defgroup dedukti nil
  "Major mode for Dedukti files."
  :group 'languages)

(defcustom dedukti-path "/usr/bin/dkcheck"
  "Path to the Dedukti type-checker."
  :group 'dedukti
  :type '(file :must-match t))

(defcustom dedukti-compile-options '("-nc" "-e")
  "Options to pass to dedukti to compile files."
  :group 'dedukti
  :type '(list string))

(defcustom dedukti-check-options '("-nc")
  "Options to pass to dedukti to typecheck files."
  :group 'dedukti
  :type '(list string))

(defcustom dedukti-reduction-command ":= %s."
  "Format of the dedukti command used for reduction.
Typical values are \":= %s.\" for head normalisation and
\"#SNF (%s).\" for strong normalisation.")

;; Generic major mode

(require 'generic-x)

(defvar dedukti-id
  "[_a-zA-Z0-9][_a-zA-Z0-9!?']*"
  "Regexp matching Dedukti identifiers.")

(defvar dedukti-qualifier
  "[_a-zA-Z0-9]+"
  "Regexp matching Dedukti qualifiers.")

(defvar dedukti-qid
  (format "\\(\\<%s\\>\\.\\)?\\<%s\\>"
          dedukti-qualifier
          dedukti-id)
  "Regexp matching Dedukti qualified identifiers.")

(defvar dedukti-qid-back
  (format "\\(\\(%s\\)?\\.\\)?%s"
          dedukti-qualifier
          dedukti-id)
  "Regexp matching Dedukti qualified identifiers backward.
Since characters are added one by one,
expressions of the form `.id' are allowed.")

(defvar dedukti-symbolic-keywords
  '(":="        ; Definition
    ":"         ; Declaration, annotated lambdas and pis
    "-->"       ; Rewrite-rule
    "->"        ; Pi (dependant type constructor)
    "=>"        ; Lambda (function constructor)
    "\\[" "\\]" ; Rewrite-rule environment
    "(" ")"     ; Expression grouping
    "{" "}"     ; Dot patterns and opaque definitions
    ","         ; Environment separator
    "."         ; Global context separator
    "~="        ; Converstion test
    )
  "List of non-alphabetical Dedukti keywords.")

;;;###autoload
(define-generic-mode
  dedukti-mode
  '(("(;".";)"))                             ;; comments
  '("Type")                                  ;; keywords
  `(
    (,(format "^ *#\\(IMPORT\\|NAME\\|ASSERT\\)[ \t]+%s" dedukti-qualifier) .
     'font-lock-preprocessor-face)           ;; pragmas
    (,(format "^ *%s *:=?" dedukti-id) .
     'font-lock-function-name-face)          ;; declarations and definitions
    (,(format "%s *:[^=]" dedukti-id) .
     'font-lock-function-name-face)          ;; variable name in lambdas and pis
    (,(format "%s\\.%s" dedukti-qualifier dedukti-id) .
     'font-lock-constant-face)               ;; qualified identifiers
    (,dedukti-id .
     'font-lock-variable-name-face)          ;; identifiers
    (,(regexp-opt dedukti-symbolic-keywords)
     . 'font-lock-keyword-face)
    )
  '(".dk\\'")                                    ;; use this mode for .dk files
  nil
  "Major mode for editing Dedukti source code files.")

;; Error handling

;; Errors from the compilation buffer

(require 'compile)

(add-to-list 'compilation-error-regexp-alist
    `(,(format
        "^ERROR file:\\(%s.dk\\) line:\\([0-9]+\\) column:\\([0-9]+\\)"
        dedukti-qualifier)
      1 2 3 2))

(add-to-list 'compilation-error-regexp-alist
    `(,(format
        "^WARNING file:\\(%s.dk\\) line:\\([0-9]+\\) column:\\([0-9]+\\)"
        dedukti-qualifier)
      1 2 3 1))

;; Calling Dedukti

(defun dedukti-compile-file (&optional file)
  "Compile file FILE with Dedukti.
If no file is given, compile the file associated with the current buffer."
  (interactive)
  (let ((file (or file (buffer-file-name))))
    (when file
      (eval `(start-process
              "Dedukti compiler"
              ,(get-buffer-create "*Dedukti Compiler*")
              ,dedukti-path
              ,@dedukti-compile-options
              ,file)))))

(add-hook 'dedukti-mode-hook
          (lambda () (local-set-key (kbd "C-c c") 'dedukti-compile-file)))
(add-hook 'dedukti-mode-hook
          (lambda () (local-set-key (kbd "C-c C-c") 'compile)))

;; Optional: flycheck integration

(when (require 'flycheck nil t)

  (flycheck-define-checker dedukti
    "Dedukti type checker."
    :command ("dkcheck"
              (eval dedukti-check-options)
              source-inplace)
    :error-patterns
    ((warning
        line-start "WARNING file:" (file-name) " line:" line " column:" column (message) line-end)
     (error
        line-start "ERROR file:"   (file-name) " line:" line " column:" column (message) line-end))
    :modes dedukti-mode)

  (add-to-list 'flycheck-checkers 'dedukti)

  (add-hook 'dedukti-mode-hook 'flycheck-mode)

  )

;; Indentation

(require 'smie)
(defvar dedukti-smie-grammar
  (smie-prec2->grammar
   (smie-bnf->prec2
    '((id)
      (prelude ("#NAME" "NAME")
               ("#IMPORT" "NAME"))
      (line ("NEWID" "TCOLON" term ".")
            ("NEWID" ":=" term ".")
            ("NEWID" "TCOLON" term ":=" term ".")
            ("{" "OPAQUEID" "}" ":=" term ".")
            ("{" "OPAQUEID" "}" "TCOLON" term ":=" term ".")
            ("[" context "]" term "-->" term)
            ("[" context "]" term "-->" term ".")
            ("#ASSERT" term "=~" term "."))
      (decl ("CID" "RCOLON" term))
      (context (decl "," context)
               (decl))
      (tdecl ("ID" "LCOLON" term)
             (term))
      (term ("_")
            (tdecl "->" term)
            (tdecl "=>" term)))
    '((assoc ",")
      (assoc "->" "=>" "LCOLON")
      ))))

(defun dedukti-smie-position ()
  "Tell in what part of a Dedukti file point is.
Return one of:
- 'prelude when point is in a line starting by a `#'
- 'context when point is in a rewrite context
           and not inside a sub-term
- 'opaque when point is inside braces
- 'top when point is before the first `:' or `:=' of the line
- nil otherwise"
  (if (save-excursion
        (back-to-indentation)
        (looking-at "#"))
      'prelude
    (if (looking-back "[[,][^],:]*")
        'context
      (if (looking-back "{[^}]*")
          'opaque
        (if (looking-back "\\(#\\|\\.[^a-zA-Z0-9_]\\)[^.#:]*")
            'top
          nil)))))

(defun dedukti-smie-position-debug ()
  "Print the current value of `dedukti-smie-position'."
  (interactive)
  (prin1 (dedukti-smie-position)))

;; (add-hook 'dedukti-mode-hook
;;           (lambda () (local-set-key (kbd "<f9>") 'dedukti-smie-position-debug)))

(defun dedukti-smie-forward-token ()
  "Forward lexer for Dedukti."
  (forward-comment (point-max))
  (cond
   ((looking-at (regexp-opt
                 '(":="
                   "-->"
                   "->"
                   "=>"
                   ","
                   "."
                   "~="
                   "["
                   "]"
                   "#NAME"
                   "#IMPORT"
                   "#ASSERT")))
    (goto-char (match-end 0))
    (match-string-no-properties 0))
   ((looking-at ":")
    ;; There are three kinds of colons in Dedukti and they can hardly
    ;; be distinguished at parsing time;
    ;; Colons can be used in rewrite contexts (RCOLON),
    ;; in local bindings of -> and => (LCOLON)
    ;; and at toplevel (TCOLON).
    (prog1
        (pcase (dedukti-smie-position)
          (`context "RCOLON")
          (`top "TCOLON")
          (_ "LCOLON"))
      (forward-char)))
   ((looking-at dedukti-qid)
    (goto-char (match-end 0))
    (pcase (dedukti-smie-position)
      (`prelude "NAME")
      (`context "CID")
      (`opaque "OPAQUEID")
      (`top "NEWID")
      (_ "ID")))
   ((looking-at "(") nil)
   (t (buffer-substring-no-properties
       (point)
       (progn (skip-syntax-forward "w_")
              (point))))))

(defun dedukti-forward ()
  "Move forward by one token or by a sexp."
  (interactive)
  (let ((beg (point)))
    (prog1
        (or (dedukti-smie-forward-token)
            (forward-sexp))
      (when (eq beg (point))
        (forward-char)))))

(defun dedukti-smie-forward-debug ()
  "Print the current value of `dedukti-smie-forward-token'."
  (interactive)
  (let ((v (dedukti-forward)))
    (when v (princ v))))

(add-hook 'dedukti-mode-hook
          (lambda () (local-set-key (kbd "<C-right>")
                                    'dedukti-forward)))


(defun dedukti-smie-backward-token ()
  "Backward lexer for Dedukti."
  (forward-comment (- (point)))
  (cond
   ((looking-back (regexp-opt
                 '(":="
                   "-->"
                   "->"
                   "=>"
                   ","
                   "."
                   "~="
                   "["
                   "]"
                   "#NAME"
                   "#IMPORT"
                   "#ASSERT"))
                  (- (point) 7))
    (goto-char (match-beginning 0))
    (match-string-no-properties 0))
   ((looking-back ":")
    (backward-char)
    (pcase (dedukti-smie-position)
      (`context "RCOLON")
      (`top "TCOLON")
      (_ "LCOLON")))
   ((looking-back dedukti-qid-back nil t)
    (goto-char (match-beginning 0))
    (pcase (dedukti-smie-position)
      (`prelude "NAME")
      (`context "CID")
      (`opaque "OPAQUEID")
      (`top "NEWID")
      (_ "ID")))
   ((looking-back ")") nil)
   (t (buffer-substring-no-properties
       (point)
       (progn (skip-syntax-backward "w_")
              (point))))))

(defun dedukti-backward ()
  "Move backward by one token or by a sexp."
  (interactive)
  (let ((beg (point)))
    (prog1
        (or (dedukti-smie-backward-token)
            (backward-sexp))
      (when (eq beg (point))
        (backward-char)))))

(defun dedukti-smie-backward-debug ()
  "Print the current value of `dedukti-smie-backward-token'."
  (interactive)
  (let ((v (dedukti-backward)))
    (when v (princ v))))

(add-hook 'dedukti-mode-hook
          (lambda () (local-set-key (kbd "<C-left>")
                                    'dedukti-backward)))

(defcustom dedukti-indent-basic 2 "Basic indentation for dedukti-mode.")

(defun dedukti-smie-rules (kind token)
  "SMIE indentation rules for Dedukti.
For the format of KIND and TOKEN, see `smie-rules-function'."
  (pcase (cons kind token)
    (`(:elem . basic) 0)
    ;; End of line
    (`(:after . "NAME") '(column . 0))
    (`(:after . ".") '(column . 0))

    ;; Rewrite-rules
    (`(:before . "[") '(column . 0))
    (`(:after . "]") (* 2 dedukti-indent-basic))
    (`(:before . "-->") `(column . ,(* 3 dedukti-indent-basic)))
    (`(:after . "-->") `(column . ,(* 2 dedukti-indent-basic)))
    (`(,_ . ",") (smie-rule-separator kind))

    ;; Toplevel
    (`(:before . "TCOLON") (if (smie-rule-hanging-p)
                               dedukti-indent-basic
                             nil))
    (`(:after . "TCOLON") 0)
    (`(:before . ":=") 0)
    (`(:after . ":=") dedukti-indent-basic)
    ;; Terms
    (`(:after . "->") 0)
    (`(:after . "=>") 0)
    (`(:after . "ID")
     (unless (smie-rule-prev-p "ID") dedukti-indent-basic))
    ))

(defun dedukti-smie-setup ()
  (smie-setup dedukti-smie-grammar
              'dedukti-smie-rules
              :forward-token 'dedukti-smie-forward-token
              :backward-token 'dedukti-smie-backward-token
              ))

(add-hook 'dedukti-mode-hook 'dedukti-smie-setup)

(defun dedukti-phrase-type ()
  "Return the kind of phrase point is in.
A list starting by one of the symbols `comment', `pragma', `rule', `decl',
or `def' followed by two buffer positions for beginning and end of phrase."
  (let ((start (point)) beg end)
    (or
     (save-excursion
       (forward-char 2)
       (when (re-search-backward "(;" nil t)
         (setq beg (point))
         (forward-char 2)
         (re-search-forward ";)")
         (setq end (point))
         (when (>= end start)
           `(comment ,beg ,end))))
     (save-excursion
       (back-to-indentation)
       (when (looking-at "#")
         (setq beg (point))
         (end-of-line)
         `(pragma ,beg ,(point))))
     (save-excursion
       (when (re-search-backward "\\[" nil t)
         (setq beg (point))
         (re-search-forward "-->")
         (forward-sexp)
         (re-search-forward "\\." nil t)
         (setq end (point))
         (when (> end start)
           `(rule ,beg ,end))))
     (save-excursion
       (backward-char)
       (when (re-search-forward "\\.[^a-zA-Z0-9_]" nil t)
         (backward-char)
         (setq end (point))
         (backward-sexp)
         (setq beg (point))
         (if (re-search-forward ":=" end t)
             `(def ,beg ,end)
           `(decl ,beg ,end))))
     )))

(defun dedukti-phrase-type-debug ()
  "Print the current value of `dedukti-phrase-type'."
  (interactive)
  (let* ((type (dedukti-phrase-type))
         (ty (car type))
         (beg (cadr type))
         (end (caddr type)))
    (prin1 ty)
    (setq mark-active t)
    (set-mark beg)
    (goto-char end)))

;; (add-hook 'dedukti-mode-hook
;;           (lambda () (local-set-key (kbd "<f9>") 'dedukti-phrase-type-debug)))



(defun dedukti-beginning-of-phrase ()
  "Go to the beggining of the current phrase."
  (interactive)
  (goto-char (cadr (dedukti-phrase-type))))


(defun dedukti-end-of-phrase ()
  "Go to the end of the current phrase."
  (interactive)
  (goto-char (caddr (dedukti-phrase-type))))

(add-hook 'dedukti-mode-hook
          (lambda () (local-set-key (kbd "C-a") 'dedukti-beginning-of-phrase)))

(add-hook 'dedukti-mode-hook
          (lambda () (local-set-key (kbd "C-e") 'dedukti-end-of-phrase)))



(defun dedukti-rule-context-at-point ()
  "Return the rewrite-rule context of the rule under point."
  (let (var type context)
    (save-excursion
      (dedukti-beginning-of-phrase)
      (re-search-forward "\\[")
      (while (not (looking-back "\\]"))
        (forward-comment (point-max))
        (looking-at dedukti-id)
        (setq var (match-string-no-properties 0))
        (goto-char (match-end 0))
        (forward-comment (point-max))
        (re-search-forward ":")
        (forward-comment (point-max))
        (re-search-forward "\\([^],]*\\)[],]")
        (setq type (match-string-no-properties 1))
        (add-to-list 'context (cons var type) t)))
    context))

(defun dedukti-goto-last-LCOLON ()
  "Go to the last local colon and return the position."
  (while (and
          (> (point) (point-min))
          (not (equal (dedukti-backward) "LCOLON"))))
  (point))

(defun dedukti-context-at-point ()
  "Return the Dedukti context at point.
This is a list of cons cells (id . type)."
  (let ((start (point))
        phrase-beg var type context mid)
    (save-excursion
      (dedukti-beginning-of-phrase)
      (setq phrase-beg (point)))
    (save-excursion
      (while (> (setq start (dedukti-goto-last-LCOLON)) phrase-beg)
        (forward-comment (- (point)))
        (looking-back dedukti-id nil t)
        (setq var (match-string-no-properties 0))
        (goto-char (match-end 0))
        (forward-comment (point-max))
        (re-search-forward ":")
        (forward-comment (point-max))
        (setq mid (point))
        (forward-sexp)
        (setq type (buffer-substring-no-properties mid (point)))
        (add-to-list 'context (cons var type))
        (goto-char start)
        ))
    context))

(defun dedukti-insert-context (context)
  "Insert CONTEXT as dedukti declarations.
CONTEXT is a list of cons cells of strings."
  (dolist (cons context)
    (insert (car cons) " : " (cdr cons) ".\n")))

(defun dedukti-remove-debrujn (s)
  "Return a copy of string S without DeBrujn indices."
  (replace-regexp-in-string "\\[[0-9]+\\]" "" s nil t))

(defun dedukti-remove-newline (s)
  "Return a copy of string S without newlines."
  (replace-regexp-in-string "\n" "" s nil t))

(defun dedukti-eval-term-to-string (beg end &optional reduction-command)
  "Call dedukti to reduce the selected term and return it as a string.
REDUCTION-COMMAND is used to control the reduction strategy,
it defaults to `dedukti-reduction-command'."
  (let* ((phrase-type (dedukti-phrase-type))
         (rulep (eq (car phrase-type) 'rule))
         (phrase-beg (cadr phrase-type))
         (buffer (current-buffer))
         (rule-context (when rulep (dedukti-rule-context-at-point)))
         (context (dedukti-context-at-point))
         (term (buffer-substring-no-properties beg end)))
    (with-temp-file "tmp.dk"
      (erase-buffer)
      (insert-buffer-substring buffer nil phrase-beg)
      (insert "\n")
      (dedukti-insert-context rule-context)
      (dedukti-insert-context context)
      (insert (format (or
                       reduction-command
                       dedukti-reduction-command)
                      term)))
    (goto-char beg)
    (dedukti-remove-newline
     (dedukti-remove-debrujn
      (shell-command-to-string "dkcheck -q -r -nc tmp.dk 2> /dev/null")))))

(defun dedukti-eval (beg end &optional reduction-command)
  "Call dedukti to reduce the selected term and display the result in the echo area.
REDUCTION-COMMAND is used to control the reduction strategy,
it defaults to `dedukti-reduction-command'."
  (interactive "r\nsreduction command: ")
  (message (dedukti-eval-term-to-string beg end reduction-command)))

(defun dedukti-hnf (beg end &optional reduction-command)
  "Call dedukti to reduce the selected term in head normal form and display the result in the echo area."
  (interactive "r")
  (message (dedukti-eval-term-to-string beg end ":= %s.")))

(defun dedukti-wnf (beg end &optional reduction-command)
  "Call dedukti to reduce the selected term in weak normal form and display the result in the echo area."
  (interactive "r")
  (message (dedukti-eval-term-to-string beg end "#WNF %s.")))

(defun dedukti-snf (beg end &optional reduction-command)
  "Call dedukti to reduce the selected term in strong normal form and display the result in the echo area."
  (interactive "r")
  (message (dedukti-eval-term-to-string beg end "#SNF %s.")))

(defun dedukti-reduce (beg end reduction-command)
  "Call dedukti to reduce the selected term and replace it in place.
REDUCTION-COMMAND is used to control the reduction strategy,
see variable `dedukti-reduction-command' for details.
The term is displayed in parens."
  (interactive "r\nsreduction command: ")
  (let ((result (dedukti-eval-term-to-string beg end reduction-command)))
    (delete-region beg end)
    (insert "(" result ")")))

(defun dedukti-reduce-hnf (beg end)
  "Call dedukti to reduce in head normal form the selected term and replace it in place.
The term is displayed in parens."
  (interactive "r")
  (dedukti-reduce beg end ":= %s."))

(defun dedukti-reduce-wnf (beg end)
  "Call dedukti to reduce in weak normal form the selected term and replace it in place.
The term is displayed in parens."
  (interactive "r")
  (dedukti-reduce beg end "#WNF %s."))

(defun dedukti-reduce-snf (beg end)
  "Call dedukti to reduce in strong normal form the selected term and replace it in place.
The term is displayed in parens."
  (interactive "r")
  (dedukti-reduce beg end "#SNF %s."))

(defun dedukti-insert-check ()
  "Insert the error message of dkcheck at point."
  (interactive)
  (let ((s (shell-command-to-string
            (format
             "dkcheck -q -r -nc %s"
             (buffer-file-name)))))
    (setq s (dedukti-remove-debrujn s))
    (setq s (replace-regexp-in-string "\n" ".\n" s nil t))
    (setq s (replace-regexp-in-string "\\(ERROR.*context:.\\)" "(; \\1 ;)" s))
    (setq s (replace-regexp-in-string " type:" "_type :=" s nil t))
    (insert s)))


(provide 'dedukti-mode)

;;; dedukti-mode.el ends here
