;;; hanzo.el --- Hanzo AI integration for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Hanzo AI Inc

;; Author: Hanzo AI Inc <dev@hanzo.ai>
;; URL: https://github.com/hanzoai/hanzo.el
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (request "0.3.0") (markdown-mode "2.5"))
;; Keywords: ai, tools, convenience

;; This file is not part of GNU Emacs.

;; MIT License

;;; Commentary:

;; Hanzo AI integration for Emacs.  Provides AI-powered code completion,
;; explanation, refactoring, and more using Claude, GPT-4, Gemini, Ollama,
;; and any OpenAI-compatible API.
;;
;; Features:
;; - Multiple LLM providers (Claude, GPT-4, Gemini, Ollama)
;; - LLM Gateway support for unified access to 100+ providers
;; - AI-powered commands (completion, explanation, refactoring, tests, docs)
;; - WebSocket bridge for AI agent control (MCP/ZAP)
;; - REPL integration via Jupyter kernels
;;
;; Installation:
;;
;;   (use-package hanzo
;;     :straight (:host github :repo "hanzoai/hanzo.el")
;;     :config
;;     (setq hanzo-model "claude-sonnet-4-20250514")
;;     (setq hanzo-api-key (getenv "ANTHROPIC_API_KEY")))
;;
;; Usage:
;;
;;   M-x hanzo-chat      - Chat with AI
;;   M-x hanzo-complete  - Complete code at point
;;   M-x hanzo-explain   - Explain selected region
;;   M-x hanzo-refactor  - Refactor selected region
;;   M-x hanzo-fix       - Fix bugs in selection
;;   M-x hanzo-tests     - Generate tests for selection
;;   M-x hanzo-docs      - Add documentation to selection
;;   M-x hanzo-review    - Review code for issues

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'url)

(defgroup hanzo nil
  "Hanzo AI integration for Emacs."
  :group 'tools
  :prefix "hanzo-")

;;; Custom Variables

(defcustom hanzo-model "claude-sonnet-4-20250514"
  "Default model to use for AI requests."
  :type 'string
  :group 'hanzo)

(defcustom hanzo-provider "anthropic"
  "LLM provider (anthropic, openai, google, ollama)."
  :type '(choice (const "anthropic")
                 (const "openai")
                 (const "google")
                 (const "ollama"))
  :group 'hanzo)

(defcustom hanzo-mode "api"
  "Connection mode (api, mcp, ollama)."
  :type '(choice (const "api")
                 (const "mcp")
                 (const "ollama"))
  :group 'hanzo)

(defcustom hanzo-api-key nil
  "API key for the LLM provider.
If nil, uses environment variables: ANTHROPIC_API_KEY, OPENAI_API_KEY, etc."
  :type '(choice (const nil) string)
  :group 'hanzo)

(defcustom hanzo-llm-gateway "http://localhost:4000"
  "URL for Hanzo LLM Gateway."
  :type 'string
  :group 'hanzo)

(defcustom hanzo-ollama-url "http://localhost:11434"
  "URL for local Ollama instance."
  :type 'string
  :group 'hanzo)

(defcustom hanzo-temperature 0.2
  "Temperature for AI responses (0.0 - 1.0)."
  :type 'float
  :group 'hanzo)

(defcustom hanzo-max-tokens 4096
  "Maximum tokens for AI responses."
  :type 'integer
  :group 'hanzo)

(defcustom hanzo-bridge-port 9230
  "WebSocket bridge port for AI agent control."
  :type 'integer
  :group 'hanzo)

(defcustom hanzo-system-prompt
  "You are an expert programmer assistant integrated into Emacs.
Provide concise, accurate code and explanations.
When writing code, match the existing style in the file.
Focus on the specific task requested."
  "System prompt for AI interactions."
  :type 'string
  :group 'hanzo)

;;; Internal Variables

(defvar hanzo--output-buffer "*Hanzo*"
  "Buffer for Hanzo output.")

(defvar hanzo--bridge-process nil
  "Bridge process for AI agent control.")

(defvar hanzo--request-callback nil
  "Callback for current request.")

;;; Utilities

(defun hanzo--get-api-key ()
  "Get API key from config or environment."
  (or hanzo-api-key
      (getenv "HANZO_API_KEY")
      (getenv "ANTHROPIC_API_KEY")
      (getenv "OPENAI_API_KEY")
      (getenv "GOOGLE_API_KEY")))

(defun hanzo--get-url ()
  "Get API URL based on mode and provider."
  (cond
   ((string= hanzo-mode "ollama") hanzo-ollama-url)
   ((string= hanzo-mode "mcp") nil)
   (t hanzo-llm-gateway)))

(defun hanzo--region-or-buffer ()
  "Get selected region or entire buffer."
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun hanzo--current-mode-name ()
  "Get human-readable name of current major mode."
  (replace-regexp-in-string "-mode$" "" (symbol-name major-mode)))

(defun hanzo--ensure-output-buffer ()
  "Ensure output buffer exists and is displayed."
  (let ((buf (get-buffer-create hanzo--output-buffer)))
    (with-current-buffer buf
      (when (fboundp 'markdown-mode)
        (markdown-mode))
      (setq-local buffer-read-only nil))
    (display-buffer buf)
    buf))

(defun hanzo--insert-streaming (text)
  "Insert TEXT into output buffer."
  (with-current-buffer (hanzo--ensure-output-buffer)
    (goto-char (point-max))
    (insert text)))

;;; API Calls

(defun hanzo--build-messages (prompt)
  "Build messages array for API request with PROMPT."
  (let ((messages '()))
    (when (and hanzo-system-prompt (not (string-empty-p hanzo-system-prompt)))
      (push `((role . "system") (content . ,hanzo-system-prompt)) messages))
    (push `((role . "user") (content . ,prompt)) messages)
    (nreverse messages)))

(defun hanzo--request-openai-compatible (prompt callback)
  "Make OpenAI-compatible API request with PROMPT, calling CALLBACK with result."
  (let* ((url-request-method "POST")
         (url-request-extra-headers
          `(("Content-Type" . "application/json")
            ,@(when-let ((key (hanzo--get-api-key)))
                (if (string= hanzo-provider "anthropic")
                    `(("x-api-key" . ,key)
                      ("anthropic-version" . "2023-06-01"))
                  `(("Authorization" . ,(format "Bearer %s" key)))))))
         (url-request-data
          (encode-coding-string
           (json-encode
            `((model . ,hanzo-model)
              (messages . ,(vconcat (hanzo--build-messages prompt)))
              (temperature . ,hanzo-temperature)
              (max_tokens . ,hanzo-max-tokens)
              (stream . :json-false)))
           'utf-8))
         (endpoint (format "%s/v1/chat/completions" (hanzo--get-url))))
    (url-retrieve
     endpoint
     (lambda (status)
       (if-let ((err (plist-get status :error)))
           (funcall callback nil (format "Request error: %s" err))
         (goto-char url-http-end-of-headers)
         (let* ((response (json-read))
                (content (alist-get 'content
                                    (alist-get 'message
                                               (aref (alist-get 'choices response) 0)))))
           (funcall callback content nil))))
     nil t)))

(defun hanzo--request-ollama (prompt callback)
  "Make Ollama API request with PROMPT, calling CALLBACK with result."
  (let* ((url-request-method "POST")
         (url-request-extra-headers '(("Content-Type" . "application/json")))
         (url-request-data
          (encode-coding-string
           (json-encode
            `((model . ,hanzo-model)
              (messages . ,(vconcat (hanzo--build-messages prompt)))
              (stream . :json-false)
              (options . ((temperature . ,hanzo-temperature)
                          (num_predict . ,hanzo-max-tokens)))))
           'utf-8))
         (endpoint (format "%s/api/chat" hanzo-ollama-url)))
    (url-retrieve
     endpoint
     (lambda (status)
       (if-let ((err (plist-get status :error)))
           (funcall callback nil (format "Request error: %s" err))
         (goto-char url-http-end-of-headers)
         (let* ((response (json-read))
                (content (alist-get 'content (alist-get 'message response))))
           (funcall callback content nil))))
     nil t)))

(defun hanzo--request (prompt callback)
  "Make AI request with PROMPT, calling CALLBACK with (result error)."
  (cond
   ((string= hanzo-mode "ollama")
    (hanzo--request-ollama prompt callback))
   (t
    (hanzo--request-openai-compatible prompt callback))))

;;; Interactive Commands

;;;###autoload
(defun hanzo-chat (prompt)
  "Chat with AI using PROMPT."
  (interactive "sHanzo> ")
  (when (string-empty-p prompt)
    (user-error "Empty prompt"))
  (let ((buf (hanzo--ensure-output-buffer)))
    (with-current-buffer buf
      (erase-buffer)
      (insert (format "## Prompt\n\n%s\n\n## Response\n\n" prompt)))
    (hanzo--request
     prompt
     (lambda (result error)
       (with-current-buffer buf
         (goto-char (point-max))
         (if error
             (insert (format "Error: %s" error))
           (insert result))
         (insert "\n"))))))

;;;###autoload
(defun hanzo-complete ()
  "Complete code at point using AI."
  (interactive)
  (let* ((context-start (max (point-min) (- (point) 2000)))
         (context-end (min (point-max) (+ (point) 500)))
         (context (buffer-substring-no-properties context-start context-end))
         (lang (hanzo--current-mode-name))
         (prompt (format "Complete the code at the cursor position (marked with |CURSOR|).
Context:\n\n```%s\n%s|CURSOR|%s\n```\n\nProvide only the completion, no explanation."
                         lang
                         (buffer-substring-no-properties context-start (point))
                         (buffer-substring-no-properties (point) context-end))))
    (hanzo--request
     prompt
     (lambda (result error)
       (if error
           (message "Hanzo error: %s" error)
         (insert result))))))

;;;###autoload
(defun hanzo-explain ()
  "Explain selected region using AI."
  (interactive)
  (let* ((code (hanzo--region-or-buffer))
         (lang (hanzo--current-mode-name))
         (prompt (format "Explain this %s code:\n\n```%s\n%s\n```" lang lang code)))
    (let ((buf (hanzo--ensure-output-buffer)))
      (with-current-buffer buf
        (erase-buffer)
        (insert "## Explanation\n\n"))
      (hanzo--request
       prompt
       (lambda (result error)
         (with-current-buffer buf
           (goto-char (point-max))
           (insert (or error result))))))))

;;;###autoload
(defun hanzo-refactor (instruction)
  "Refactor selected region according to INSTRUCTION."
  (interactive "sRefactor instruction: ")
  (let* ((code (hanzo--region-or-buffer))
         (lang (hanzo--current-mode-name))
         (prompt (format "Refactor this %s code according to: %s\n\n```%s\n%s\n```\n\nProvide only the refactored code."
                         lang instruction lang code)))
    (let ((buf (hanzo--ensure-output-buffer)))
      (with-current-buffer buf
        (erase-buffer)
        (insert "## Refactored Code\n\n"))
      (hanzo--request
       prompt
       (lambda (result error)
         (with-current-buffer buf
           (goto-char (point-max))
           (insert (or error result))))))))

;;;###autoload
(defun hanzo-fix ()
  "Fix bugs in selected region using AI."
  (interactive)
  (let* ((code (hanzo--region-or-buffer))
         (lang (hanzo--current-mode-name))
         (prompt (format "Fix any bugs or issues in this %s code:\n\n```%s\n%s\n```\n\nProvide only the fixed code."
                         lang lang code)))
    (let ((buf (hanzo--ensure-output-buffer)))
      (with-current-buffer buf
        (erase-buffer)
        (insert "## Fixed Code\n\n"))
      (hanzo--request
       prompt
       (lambda (result error)
         (with-current-buffer buf
           (goto-char (point-max))
           (insert (or error result))))))))

;;;###autoload
(defun hanzo-tests ()
  "Generate tests for selected region using AI."
  (interactive)
  (let* ((code (hanzo--region-or-buffer))
         (lang (hanzo--current-mode-name))
         (prompt (format "Write comprehensive tests for this %s code:\n\n```%s\n%s\n```"
                         lang lang code)))
    (let ((buf (hanzo--ensure-output-buffer)))
      (with-current-buffer buf
        (erase-buffer)
        (insert "## Generated Tests\n\n"))
      (hanzo--request
       prompt
       (lambda (result error)
         (with-current-buffer buf
           (goto-char (point-max))
           (insert (or error result))))))))

;;;###autoload
(defun hanzo-docs ()
  "Add documentation to selected region using AI."
  (interactive)
  (let* ((code (hanzo--region-or-buffer))
         (lang (hanzo--current-mode-name))
         (prompt (format "Add documentation/comments to this %s code:\n\n```%s\n%s\n```\n\nProvide the code with documentation added."
                         lang lang code)))
    (let ((buf (hanzo--ensure-output-buffer)))
      (with-current-buffer buf
        (erase-buffer)
        (insert "## Documented Code\n\n"))
      (hanzo--request
       prompt
       (lambda (result error)
         (with-current-buffer buf
           (goto-char (point-max))
           (insert (or error result))))))))

;;;###autoload
(defun hanzo-review ()
  "Review selected region for bugs and improvements."
  (interactive)
  (let* ((code (hanzo--region-or-buffer))
         (lang (hanzo--current-mode-name))
         (prompt (format "Review this %s code for bugs, performance issues, and improvements:\n\n```%s\n%s\n```"
                         lang lang code)))
    (let ((buf (hanzo--ensure-output-buffer)))
      (with-current-buffer buf
        (erase-buffer)
        (insert "## Code Review\n\n"))
      (hanzo--request
       prompt
       (lambda (result error)
         (with-current-buffer buf
           (goto-char (point-max))
           (insert (or error result))))))))

;;; Model Selection

;;;###autoload
(defun hanzo-set-model (model)
  "Set the AI MODEL to use."
  (interactive
   (list (completing-read "Model: "
                          '("claude-sonnet-4-20250514"
                            "claude-opus-4-20250514"
                            "claude-3-5-sonnet-20241022"
                            "gpt-4-turbo"
                            "gpt-4o"
                            "gemini-1.5-pro"
                            "ollama:llama3.2"
                            "ollama:codellama")
                          nil nil nil nil hanzo-model)))
  (setq hanzo-model model)
  (message "Hanzo model set to: %s" model))

;;;###autoload
(defun hanzo-set-mode (mode)
  "Set the connection MODE (api, mcp, ollama)."
  (interactive
   (list (completing-read "Mode: " '("api" "mcp" "ollama") nil t)))
  (setq hanzo-mode mode)
  (message "Hanzo mode set to: %s" mode))

;;;###autoload
(defun hanzo-version ()
  "Display Hanzo version and configuration."
  (interactive)
  (message "hanzo.el v0.1.0 | Model: %s | Mode: %s | Provider: %s"
           hanzo-model hanzo-mode hanzo-provider))

;;; Keymap

(defvar hanzo-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "h") #'hanzo-chat)
    (define-key map (kbd "c") #'hanzo-complete)
    (define-key map (kbd "e") #'hanzo-explain)
    (define-key map (kbd "r") #'hanzo-refactor)
    (define-key map (kbd "f") #'hanzo-fix)
    (define-key map (kbd "t") #'hanzo-tests)
    (define-key map (kbd "d") #'hanzo-docs)
    (define-key map (kbd "v") #'hanzo-review)
    (define-key map (kbd "m") #'hanzo-set-model)
    map)
  "Keymap for Hanzo commands.")

;;;###autoload
(defun hanzo-setup-keybindings (&optional prefix)
  "Set up Hanzo keybindings with optional PREFIX (default C-c h)."
  (interactive)
  (global-set-key (kbd (or prefix "C-c h")) hanzo-command-map))

(provide 'hanzo)

;;; hanzo.el ends here
