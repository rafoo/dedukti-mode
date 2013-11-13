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
  "[_a-zA-Z][_a-zA-Z0-9]*"
  "Regexp matching Dedukti identifiers.
An identifier is composed of alphanumerical symbols and underscores
but cannot start with a digit.")

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
  '(("(;".";)"))                                              ;; comments
  '("Type")                                                   ;; keywords
  `(
    (,(format "^ *#\\(IMPORT\\|NAME\\) %s" dedukti-id) .
     'font-lock-preprocessor-face)                            ;; pragmas
    (,(format "^ *%s *:=?" dedukti-id) .
     'font-lock-function-name-face)                           ;; declarations and definitions
    (,(format "%s *:[^=]" dedukti-id) .
     'font-lock-function-name-face)                           ;; variable name in lambdas and pis
    (,(format "%s\\.%s" dedukti-id dedukti-id) .
     'font-lock-constant-face)                                ;; qualified identifiers
    (,dedukti-id .
                 'font-lock-variable-name-face)               ;; identifiers
    (,(regexp-opt dedukti-symbolic-keywords) . 'font-lock-keyword-face)
    ) 
  '(".dk\\'")                                              ;; use this mode for .dk files
  nil
  "Major mode for editing Dedukti source code files.")

;; Error handling

;; Errors from the compilation buffer

(defun dedukti-compilation-error-find-file ()
  "Look backward in the compilation buffer looking for the last Dedukti file."
  (save-excursion
    (re-search-backward "[a-zA-Z_/]+.dk")
    (list (match-string 0))))

(require 'compile)

(add-to-list 'compilation-error-regexp-alist
    '("^ERROR line:\\([0-9]+\\) column:\\([0-9]+\\)"
      nil 2 3 2))

(add-to-list 'compilation-error-regexp-alist
    '("^WARNING line:\\([0-9]+\\) column:\\([0-9]+\\)"
      nil 2 3 1))

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

;; Optional: flycheck integration

(when (require 'flycheck nil t)

  (flycheck-define-checker dedukti
    "Dedukti type checker."
    :command ((eval dedukti-command) (eval dedukti-check-options) source-inplace)
    :error-patterns
    ((warning line-start "WARNING line:" line " column:" column (message) line-end)
     (error   line-start "ERROR line:"   line " column:" column (message) line-end))
    :modes dedukti-mode)

  (add-to-list 'flycheck-checkers 'dedukti)

  (add-hook 'dedukti-mode-hook 'flycheck-mode)

  )

(provide 'dedukti-mode)

;;; dedukti-mode.el ends here
