# Vimium

Vimium is a browser extension that adds Vim-style keyboard navigation to the web. It lets you move, open links, switch tabs, and run searches without touching the mouse.

Repo: [philc/vimium](https://github.com/philc/vimium)

## What does this config do

This folder provides two Vimium configuration files:

- `keymaps.conf`: custom key mappings that align with HyprVim-style navigation.
- `custom-search-options.conf`: a set of search engine keywords used by the Vimium Vomnibar.

## Installation

1. Install the Vimium extension in your browser.
2. Open Vimium settings:
   - Click the Vimium icon → **Options**
3. Copy/paste the config files into the correct fields:

- **Custom key mappings** → paste the contents of `extras/vimium/keymaps.conf`
- **Custom search engines** → paste the contents of `extras/vimium/custom-search-options.conf`

## Usage

- Use `J`/`K` for tab switching.
- Use `g`-prefixed searches (e.g., `gh` for GitHub, `gy` for YouTube).
- Use `<space>` as a leader for common searches and tab selection.
