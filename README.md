# hanzo.el

Hanzo AI integration for Emacs. AI-powered code completion, explanation, refactoring, and more using Claude, GPT-4, Gemini, Ollama, and any OpenAI-compatible API.

## Features

- **Multiple LLM Providers**: Claude, GPT-4, Gemini, Ollama, and any OpenAI-compatible API
- **LLM Gateway Support**: Use [Hanzo LLM Gateway](https://github.com/hanzoai/llm) for unified access to 100+ providers
- **AI-Powered Commands**: Completion, explanation, refactoring, tests, documentation, review
- **WebSocket Bridge**: Allow AI agents to control Emacs (MCP/ZAP)

## Requirements

- Emacs 27.1+
- `request.el` (optional, for better HTTP handling)
- `markdown-mode` (optional, for output formatting)

## Installation

### Using [straight.el](https://github.com/radian-software/straight.el):

```elisp
(straight-use-package
 '(hanzo :type git :host github :repo "hanzoai/hanzo.el"))

(require 'hanzo)
(setq hanzo-model "claude-sonnet-4-20250514")
```

### Using [use-package](https://github.com/jwiegley/use-package) with straight:

```elisp
(use-package hanzo
  :straight (:host github :repo "hanzoai/hanzo.el")
  :config
  (setq hanzo-model "claude-sonnet-4-20250514")
  (setq hanzo-api-key (getenv "ANTHROPIC_API_KEY"))
  (hanzo-setup-keybindings))
```

### Manual:

```bash
git clone https://github.com/hanzoai/hanzo.el ~/.emacs.d/site-lisp/hanzo.el
```

```elisp
(add-to-list 'load-path "~/.emacs.d/site-lisp/hanzo.el")
(require 'hanzo)
```

## Configuration

```elisp
;; Model settings
(setq hanzo-model "claude-sonnet-4-20250514")  ; Default model
(setq hanzo-provider "anthropic")  ; anthropic, openai, google, ollama
(setq hanzo-mode "api")  ; api, mcp, ollama

;; API settings
(setq hanzo-api-key (getenv "ANTHROPIC_API_KEY"))
(setq hanzo-llm-gateway "http://localhost:4000")  ; LLM Gateway URL
(setq hanzo-ollama-url "http://localhost:11434")  ; Ollama URL

;; Generation settings
(setq hanzo-temperature 0.2)
(setq hanzo-max-tokens 4096)

;; System prompt
(setq hanzo-system-prompt "You are an expert programmer...")

;; Set up keybindings (optional)
(hanzo-setup-keybindings)  ; Binds to C-c h prefix
```

### Environment Variables

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GOOGLE_API_KEY="..."
```

## Commands

| Command | Description |
|---------|-------------|
| `M-x hanzo-chat` | Chat with AI (prompts for input) |
| `M-x hanzo-complete` | Complete code at point |
| `M-x hanzo-explain` | Explain selected region |
| `M-x hanzo-refactor` | Refactor selection with instruction |
| `M-x hanzo-fix` | Fix bugs in selection |
| `M-x hanzo-tests` | Generate tests for selection |
| `M-x hanzo-docs` | Add documentation to selection |
| `M-x hanzo-review` | Review code for issues |
| `M-x hanzo-set-model` | Change the AI model |
| `M-x hanzo-set-mode` | Change connection mode |
| `M-x hanzo-version` | Show version and config |

## Keybindings

Call `(hanzo-setup-keybindings)` to enable default keybindings:

| Key | Command |
|-----|---------|
| `C-c h h` | `hanzo-chat` |
| `C-c h c` | `hanzo-complete` |
| `C-c h e` | `hanzo-explain` |
| `C-c h r` | `hanzo-refactor` |
| `C-c h f` | `hanzo-fix` |
| `C-c h t` | `hanzo-tests` |
| `C-c h d` | `hanzo-docs` |
| `C-c h v` | `hanzo-review` |
| `C-c h m` | `hanzo-set-model` |

Custom prefix:

```elisp
(hanzo-setup-keybindings "C-c a")  ; Use C-c a prefix instead
```

## Available Models

### Anthropic
- `claude-sonnet-4-20250514` (default)
- `claude-opus-4-20250514`
- `claude-3-5-sonnet-20241022`

### OpenAI
- `gpt-4-turbo`
- `gpt-4o`
- `o1-preview`

### Google
- `gemini-1.5-pro`
- `gemini-1.5-flash`

### Ollama (local)
- `ollama:llama3.2`
- `ollama:codellama`
- `ollama:deepseek-coder`

## Using with LLM Gateway

For unified access to 100+ LLM providers:

```bash
# Start LLM Gateway
docker run -p 4000:4000 hanzoai/llm

# Or install directly
pip install hanzo-llm
hanzo-llm serve
```

Configure Emacs:

```elisp
(setq hanzo-llm-gateway "http://localhost:4000")
(setq hanzo-model "claude-sonnet-4-20250514")
```

## Using with Ollama

For local models:

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull models
ollama pull llama3.2
ollama pull codellama
```

Configure Emacs:

```elisp
(setq hanzo-mode "ollama")
(setq hanzo-model "codellama")
```

## Integration with Doom Emacs

Add to `~/.doom.d/packages.el`:

```elisp
(package! hanzo
  :recipe (:host github :repo "hanzoai/hanzo.el"))
```

Add to `~/.doom.d/config.el`:

```elisp
(use-package! hanzo
  :config
  (setq hanzo-model "claude-sonnet-4-20250514")
  (map! :leader
        (:prefix ("h" . "hanzo")
         :desc "Chat" "h" #'hanzo-chat
         :desc "Complete" "c" #'hanzo-complete
         :desc "Explain" "e" #'hanzo-explain
         :desc "Refactor" "r" #'hanzo-refactor
         :desc "Fix" "f" #'hanzo-fix
         :desc "Tests" "t" #'hanzo-tests
         :desc "Docs" "d" #'hanzo-docs
         :desc "Review" "v" #'hanzo-review)))
```

## Integration with Spacemacs

Add to `dotspacemacs-additional-packages`:

```elisp
(hanzo :location (recipe :fetcher github :repo "hanzoai/hanzo.el"))
```

Configure in `dotspacemacs/user-config`:

```elisp
(use-package hanzo
  :config
  (setq hanzo-model "claude-sonnet-4-20250514")
  (spacemacs/set-leader-keys
    "ah" 'hanzo-chat
    "ac" 'hanzo-complete
    "ae" 'hanzo-explain
    "ar" 'hanzo-refactor
    "af" 'hanzo-fix
    "at" 'hanzo-tests
    "ad" 'hanzo-docs
    "av" 'hanzo-review))
```

## License

MIT - [Hanzo AI Inc](https://hanzo.ai)
