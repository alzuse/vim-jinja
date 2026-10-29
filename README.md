# Jinja for Vim

Jinja bundle for vim.


## Feature

1. full syntax support
2. great indent support, with closing tags and else/elif lined up with their
   opener
3. folding support
4. `%` block matching, including tags that span lines
5. background highlight of the block under the cursor, with the tag under the
   cursor standing out
6. configurable delimiters
7. colors follow your colorscheme


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

When a line becomes nothing but a block closing tag or an `else`/`elif` — the
`%>` typed last, or `endif`/`else` filled into a `<% %>` typed first — the line
is lined up with the tag that opened the block, so it does not stay one level
too deep under an indented body. To disable it:

    let g:jinja_close_indent = 0

## Block highlight

When the cursor is on a block statement tag (`<% for ... %>`, `<% if ... %>`,
`<% else %>`, `<% endfor %>`, ...), the opener and the closer of that block get
a background, so the extent of the block is visible. Only the tags are shaded:
the text between them is rendered content and is left alone, and nothing is
highlighted while the cursor is on that text. A tag that neither opens nor
closes a block (`<% else %>`, `<% elif %>`) selects the `if` block around it.

A tag may span lines (`<% if a` on one line, `and b %>` on the next); the
whole tag is shaded across all the lines it covers.

Each part borrows its background from a standard highlight group, so the three
shades stay apart and remain readable when Vim switches between the default
light and dark themes:

- the opener and the closer use the `ColorColumn` background;
- the other `else`/`elif` tags of the block use `CursorColumn`;
- the tag under the cursor uses `MatchParen`, so it stands out.

Only backgrounds are set, so the syntax colors of the tag text remain. The
colors follow the colorscheme and 'background', and are applied again after a
`:colorscheme` reload or a `:set background=...`.

To use other colors, set `g:jinja_block_highlight_colors` in your vimrc. A
value is either the name of a group whose background is copied, or `hi`
arguments for the group itself:

    let g:jinja_block_highlight_colors = {
          \ 'cur': 'Search',
          \ 'mid': 'ctermbg=240 guibg=#3a3a3a',
          \ 'pair': 'Visual',
          \ }

The keys are `cur` (group `jinjaBlockHighlightCur`), `mid`
(`jinjaBlockHighlightMid`) and `pair` (`jinjaBlockHighlight`); omit a key to
keep its default. To apply a change without reloading the buffer:

    :call jinja#block_colors()

To disable it:

    let g:jinja_block_highlight = 0

The tag under the cursor is found by scanning backward for the block start;
the matching tag is found by walking the tags around it with `searchpos()`
once, then cached until the buffer changes or the cursor moves to another
tag. Text that only looks like a tag, inside raw blocks, comments and
strings, is ignored.

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

A tag that spans lines (`<% if a` on one line, `and b %>` on the next) is
matched as well: on any line of such a tag `%` jumps to the matching tag.

Everywhere else `%` keeps its previous behavior, so matchit, vim-matchup or
Vim's builtin matching still handle HTML tags and parentheses. To turn the
mapping off:

    let g:jinja_percent_mapping = 0

`b:match_words` is set for matchit and vim-matchup as well.

HTML tags are matched by matchit/matchup too, unless one of your delimiters
starts with `<`. With the default `<%`, matchit would mistake the `<` for an
HTML tag opener.

## Colors

No colorscheme is forced and no colors are hard-coded: the Jinja syntax
groups are linked to the standard `PreProc`, `Statement`, `Function`, `Type`,
`Identifier`, `Constant`, `Comment`, `Todo` and `Error` groups, so they follow
whatever colorscheme is active.

If you want different colors, override the links in your vimrc:

    hi link jinjaTagBlock  MyTagColor
    hi link jinjaVarBlock  MyVarColor

## Bug report

Report a bug on [GitHub Issues](https://github.com/alzuse/vim-jinja/issues).
