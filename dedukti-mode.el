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

(defcustom dedukti-command "/usr/bin/dkcheck"
  "Path to the Dedukti type-checker."
  :group 'dedukti
  :type '(file :must-match t))

(defcustom dedukti-compile-options '("-nc" "-e")
  "Options to pass to `dedukti-command' to compile files."
  :group 'dedukti
  :type '(list string))

(defcustom dedukti-check-options '("-nc")
  "Options to pass to `dedukti-command' to typecheck files."
  :group 'dedukti
  :type '(list string))

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
              ,dedukti-command
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

(defun dedukti-smie-forward-debug ()
  "Print the current value of `dedukti-smie-forward-token'."
  (interactive)
  (let ((v (dedukti-smie-forward-token)))
    (if v (princ v) (forward-sexp))))

(defun dedukti-forward ()
  "Move forward by one token or by a sexp."
  (interactive)
  (or (dedukti-smie-forward-token) (forward-sexp)))

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

(defun dedukti-smie-backward-debug ()
  "Print the current value of `dedukti-smie-backward-token'."
  (interactive)
  (let ((v (dedukti-smie-backward-token)))
    (if v (princ v) (backward-sexp))))

(defun dedukti-backward ()
  "Move backward by one token or by a sexp."
  (interactive)
  (or (dedukti-smie-backward-token) (backward-sexp)))

(add-hook 'dedukti-mode-hook
          (lambda () (local-set-key (kbd "<C-right>")
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

(provide 'dedukti-mode)

;;; dedukti-mode.el ends here
