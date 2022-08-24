# Jinja for Vim

Jinja bundle for vim.


## Feature

1. full syntax support
2. great indent support
3. folding support
4. more conspicuous color scheme
5. modified jinja tag support

## Jinja tag modification

    <$ var $>    # instead of  {{ var }}
    <% if ... %> # instead of  {% if ... %}
    <% for ... %> # instead of {% for ... %}

## Installation

### Install with [Vundle](https://github.com/gmarik/vundle)

If you are not using vundle, you really should have a try.
Edit your vimrc:

    Bundle "alzuse/vim-jinja"

And install it:

    :so ~/.vimrc
    :BundleInstall


### Install with [Plug](https://github.com/junegunn/vim-plug)

If you prefer Plug, Edit your vimrc:

    Plug "alzuse/vim-jinja"

And install it:

    :so ~/.vimrc
    :PlugInstall


## Configuration

No configuration is needed

## Bug report

Report a bug on [GitHub Issues](https://github.com/alzuse/vim-jinja/issues).

