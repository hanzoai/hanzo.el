---
title: hanzo.el
description: Hanzo AI package for Emacs
---

# hanzo.el

Hanzo AI package for Emacs with support for Claude, GPT-4, Gemini, Ollama, and more.

## Installation

### straight.el

```elisp
(straight-use-package
 '(hanzo :type git :host github :repo "hanzoai/hanzo.el"))
```

### use-package

```elisp
(use-package hanzo
  :straight (:host github :repo "hanzoai/hanzo.el")
  :config
  (setq hanzo-model "claude-sonnet-4-20250514")
  (setq hanzo-provider "anthropic"))
```

### Doom Emacs

```elisp
;; In packages.el
(package! hanzo :recipe (:host github :repo "hanzoai/hanzo.el"))

;; In config.el
(use-package! hanzo
  :config
  (setq hanzo-model "claude-sonnet-4-20250514"))
```

## Quick Start

```elisp
;; Set your model
(setq hanzo-model "claude-sonnet-4-20250514")
(setq hanzo-provider "anthropic")

;; Use M-x hanzo-chat to chat
M-x hanzo-chat
```

## Features

- **Multi-Provider**: Claude, GPT-4, Gemini, Ollama
- **MCP/ZAP Bridge**: AI agent control
- **Region Operations**: Explain, Refactor, Fix, Tests, Docs
- **Streaming**: Real-time response streaming

## Commands

| Command | Description |
|---------|-------------|
| `hanzo-chat` | Send prompt to AI |
| `hanzo-complete` | Complete code at point |
| `hanzo-explain` | Explain region |
| `hanzo-refactor` | Refactor region |
| `hanzo-fix` | Fix issues in region |
| `hanzo-tests` | Generate tests |
| `hanzo-docs` | Generate documentation |
| `hanzo-review` | Code review |

## Configuration

See [README](https://github.com/hanzoai/hanzo.el) for full configuration options.
