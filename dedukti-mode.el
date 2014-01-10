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

(defvar dedukti-symbolic-keywords
  '(":="        ; Definition
    ":"         ; Declaration, annotated lambdas and pis
    "-->"       ; Rewrite-rule
    "->"        ; Pi (dependant type constructor)
    "=>"        ; Lambda (function constructor)
    "\\[" "\\]" ; Rewrite-rule environment
    "(" ")"     ; Expression grouping
    "{" "}"     ; Dot patterns
    ","         ; Environment separator
    "."         ; Global context separator
    )
  "List of non-alphabetical Dedukti keywords.")

;;;###autoload
(define-generic-mode
  dedukti-mode
  '(("(;".";)"))                             ;; comments
  '("Type")                                  ;; keywords
  `(
    (,(format "^ *#\\(IMPORT\\|NAME\\)[ \t]+%s" dedukti-qualifier) .
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

;; (require 'smie)
;; (defvar dedukti-smie-grammar
;;   (smie-prec2->grammar
;;    (smie-bnf->prec2
;;     '((id)
;;       (prelude ("#NAME" id))
;;       (line ("#IMPORT" id)
;;             (term ".")
;;             (term ":=" term ".")
;;             (rule)
;;             (rule ".")
;;             ("#ASSERT" term "=~" term "."))
;;       (rule ("[" context "]" term "-->" term))
;;       (decl (id ":" term))
;;       (context (decl "," context)
;;                (decl))
;;       (term (id)
;;             ("{" id "}")
;;             (decl)
;;             ("_")
;;             (term "->" term)
;;             (decl "=>" term)))
;;     '((assoc ":")
;;       (assoc "->" "=>")))))
;;;; Raise an cl-assertion, TODO report bug 

;; (defun dedukti-smie-setup ()
;;   (smie-setup dedukti-smie-grammar rules-fun))

;; (add-hook 'dedukti-mode-hook 'dedukti-smie-setup)

(provide 'dedukti-mode)

;;; dedukti-mode.el ends here
