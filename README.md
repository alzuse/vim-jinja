# Jinja for Vim

Jinja bundle for vim.


## Feature

1. full syntax support
2. great indent support
3. folding support
4. `%` (matchit) block matching
5. configurable delimiters
6. colors follow your colorscheme


## Jinja tag modification

    <$ var $>    # instead of {{ var }}
    <% if ... %> # instead of {% if ... %}
    <% for ... %> # instead of {% for ... %}
    <# comment #> # instead of {# comment #}


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

All delimiters can be changed in your vimrc. Set them before opening a Jinja
file (the defaults are shown below):

    let g:jinja_block_start_string    = '<%'
    let g:jinja_block_end_string      = '%>'
    let g:jinja_variable_start_string = '<$'
    let g:jinja_variable_end_string   = '$>'
    let g:jinja_comment_start_string  = '<#'
    let g:jinja_comment_end_string    = '#>'

Folding is enabled by default. To keep your own `foldmethod`:

    let g:jinja_folding = 0

`foldmethod=expr` with absolute levels is used, and the levels are cached per
buffer, so typing, undoing and reindenting stay fast even in very large files;
only an edit that changes the block tags triggers a rebuild.

## Requirements

Vim 7.3.694 or newer. With `matchbufline()` (Vim 9.1.0009 or newer) folding
uses the fast cached levels; older versions fall back to a simpler expression
that folds correctly but is slower on large files.

## Matching

`%` jumps between matching Jinja blocks using `b:match_words`, which is
understood by [matchit](https://github.com/chrisbra/matchit) and
[vim-matchup](https://github.com/andymass/vim-matchup). Enable one of them,
for example:

    packadd matchit

HTML tags are matched too, unless one of your delimiters starts with `<`.
With the default `<%`, matchit would mistake the `<` for an HTML tag opener.

## Colors

No colorscheme is forced and no colors are hard-coded: the Jinja groups are
linked to the standard `PreProc`, `Statement`, `Function`, `Type`,
`Identifier`, `Constant`, `Comment`, `Todo` and `Error` groups, so they follow
whatever colorscheme is active.

If you want different colors, override the links in your vimrc:

    hi link jinjaTagBlock  MyTagColor
    hi link jinjaVarBlock  MyVarColor

## Bug report

Report a bug on [GitHub Issues](https://github.com/alzuse/vim-jinja/issues).
