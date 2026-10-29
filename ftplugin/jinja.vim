" Vim filetype plugin

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Vim 9.2 ships its own ftplugin/jinja.vim. It checks this flag and would
" otherwise overwrite commentstring after this file has run.
let b:did_jinjaplugin = 1

let s:delims = jinja#delims()

let &l:comments = 's:' . s:delims.comment_start . ',ex:' . s:delims.comment_end
let &l:commentstring = s:delims.comment_start . '%s' . s:delims.comment_end
setlocal formatoptions+=tcqln

let s:undo = 'setlocal comments< commentstring< formatoptions<'

" Setup matchit (vim-matchup reads the same b:match_words variables, so set
" them even if matchit is loaded later).
let b:match_ignorecase = 0
let b:match_skip = 's:Comment\|String\|jinjaComBlock\|jinjaArgument\|jinjaRaw'

let s:bs = escape(s:delims.block_start, '\.*$^~[]\')
let s:be = escape(s:delims.block_end, '\.*$^~[]\')
let s:bt = s:bs . '[-+]\?\s*'
" The tag body up to the end delimiter is optional and matched on the same
" line only: a tag like "<% if a" / "and b %>" is then a delimiter for % as
" well, while matchit/matchup still get a single-line match (they match the
" delimiter against one line).
"
" The body cannot contain the end delimiter. A non-greedy body would let
" vim-matchup's cursor lookup, which requires the match to end after the
" cursor, swallow "<% if x %> text <% endif %>" as one tag: the text between
" the tags of a same-line block would then be highlighted.
let s:bc = '\%(\%(\%(' . s:be . '\)\@![^\n]\)*[-+]\?' . s:be . '\)\?'

" Block tags that span lines. Used by folding and by block highlighting.
let s:block_names = ['for', 'if', 'block', 'macro', 'filter', 'with',
      \ 'autoescape', 'call', 'trans']

" Match HTML tags too, unless a Jinja delimiter starts with "<": then the
" "<" of e.g. "<%" would be mistaken for an HTML tag opener by matchit.
if s:delims.block_start =~# '^<'
      \ || s:delims.variable_start =~# '^<'
      \ || s:delims.comment_start =~# '^<'
  let s:html_pair = ''
else
  let s:html_pair =
        \ '<!--:-->,' .
        \ '<:>,' .
        \ '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,' .
        \ '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,' .
        \ '<\@<=\([^/!][^ \t>]*\)\%([ \t]\|>\|$\):<\@<=/\1>,'
endif

" From ftplugin/html.vim, plus block tag matching.
" With block tags the following is optional:
"   - "+": disable the lstrip_blocks (only at start)
"   - "-": the whitespaces before or after that block will be removed
let b:match_words =
      \ s:html_pair .
      \ s:bt . '\%(if\|for\)\>' . s:bc . ':' .
      \ s:bt . '\%(elif\|else\)\>' . s:bc . ':' .
      \ s:bt . '\%(endif\|endfor\)\>' . s:bc . ',' .
      \ s:bt . '\%(end\)\@!\(\w\+\)\>' . s:bc . ':' .
      \ s:bt . 'end\1\>' . s:bc
let s:undo .= '|unlet! b:match_words b:match_skip b:match_ignorecase'

" Folding, enabled by default. Set g:jinja_folding to 0 in vimrc to keep the
" user's own fold settings.
"
" The expression returns the absolute fold level of the line: a Number, or
" ">N"/"<N" on a line where a fold must start/end (neighbouring blocks of the
" same level would otherwise become one fold). Absolute levels keep Vim's
" fold update local: it can read the level of the line above the change and
" only re-evaluates from there. With relative levels ("aN"/"sN"/"=") Vim has
" to walk back to the start of the file to find a known level and then
" re-evaluates almost every line on each change (measured: about 24k of 25k).
"
" The catch is that Vim shifts the fold tree by the line count change and may
" then reuse it with the wrong shape: after undoing a deletion a nested fold
" disappeared. The listener therefore switches 'foldmethod' away and back on
" every line count change, which makes Vim re-evaluate all lines from the
" (correct) cached levels; the fold tree and its open/closed state are kept.
" Text changes do not touch the tree and stay on the fast path.
"
" The level of every line is stored in one flat List, so a lookup is a single
" index operation. matchbufline() (Vim 9.1.0009 or newer) collects the tags in
" C; walking them line by line in Vim script cost hundreds of milliseconds on a
" 25k line file. The cache itself is built in autoload/jinja_fold.vim, which is
" Vim9 script: compiled code cuts the remaining rebuild cost by an order of
" magnitude. Vim without matchbufline() falls back to relative levels. Tags
" inside {% raw %} and comments are skipped while building the list.
"
" Vim evaluates folds before buffered listeners run, so checking
" b:changedtick in the expression would rebuild on every keystroke. Instead an
" unbuffered listener records which lines changed without scanning the buffer,
" and the expression validates just those lines first: an edit that leaves the
" block tags alone (typing text, reindenting) keeps the cached levels. Vim
" before 9.1.1782 only has buffered listeners (the {unbuffered} argument came
" later). Their events only arrive after the fold evaluation: the expression
" runs during the change itself, and listener_flush() there drops the pending
" events (of every listener). So on those Vims the expression rebuilds the
" cache on each change, and a changed line count makes it set a flag that
" FoldFix() turns into the same 'foldmethod' switch on the next autocmd.
if get(g:, 'jinja_folding', 1)
  let s:tag_start = s:bs . '[-+]\?\s*'
  let s:fold_names = s:block_names
  let s:fold_open = {}
  let s:fold_close = {}
  for s:name in s:fold_names
    let s:fold_open[s:name] = 1
    let s:fold_close['end' . s:name] = 1
  endfor
  unlet s:name
  let s:comment_open = escape(s:delims.comment_start, '\.*$^~[]')
  let s:comment_close = escape(s:delims.comment_end, '\.*$^~[]')
  let b:jinja_fold_pats = {
        \ 'bs': s:delims.block_start,
        \ 'comment_start': s:delims.comment_start,
        \ 'comment_end': s:delims.comment_end,
        \ 'find': '\C\%(' . s:comment_open . '\|' . s:comment_close . '\)\|'
        \         . s:tag_start . '\zs\%(' . join(s:fold_names, '\|')
        \         . '\|raw\|end\w\+\)\>',
        \ 'tag': s:tag_start . '\a',
        \ 'name_pat': s:tag_start . '\zs\a\w*',
        \ 'open_names': s:fold_open,
        \ 'close_names': s:fold_close,
        \ 'cstart': s:delims.comment_start,
        \ 'cend': s:delims.comment_end,
        \ }
  " Set when the listener is unusable (Vim before 9.1.1782): the fold
  " expression then rebuilds the cache on every change.
  let b:jinja_fold_rebuild = 0
  let b:jinja_fold_cache = {
        \ 'tick': -1, 'levels': [], 'tail': 0, 'sig': [], 'fake': {},
        \ 'chg_n': 0, 'chg_added': 0, 'chg_lo': 0, 'chg_hi': 0,
        \ }

  let s:fold_fast = 0
  if exists('*matchbufline')
    " The foldexpr and the cache live in autoload/jinja_fold.vim: Vim9
    " compiles the loops over the tags, which take most of the rebuild time.
    " Its functions are global because a Vim9 script cannot define the
    " jinja_fold#...() names legacy script would call.
    if !exists('*JinjaFoldLevel')
      let s:fold_file = expand('<sfile>:p:h:h') . '/autoload/jinja_fold.vim'
      if filereadable(s:fold_file)
        execute 'source' fnameescape(s:fold_file)
      endif
    endif
    if exists('*JinjaFoldLevel')
      let s:fold_fast = 1
      setlocal foldexpr=JinjaFoldLevel(v:lnum)
    endif
  endif
  if !s:fold_fast
    " Fallback for Vim without matchbufline(), or when the autoload file is
    " missing: relative levels, stateless.
    " This is correct but makes Vim re-evaluate the buffer after each change.
    " Whether a tag lies inside {% raw %} or a comment is taken from the
    " syntax; without it there is no way to know in a stateless expression.
    function! JinjaFoldLevelRel(lnum) abort
      let l:line = getline(a:lnum)
      let l:pats = b:jinja_fold_pats
      if stridx(l:line, l:pats.bs) < 0 || l:line !~# l:pats.tag
        return '='
      endif
      let l:check = exists('b:current_syntax')
      let l:opens = 0
      let l:closes = 0
      let l:col = match(l:line, l:pats.tag)
      while l:col >= 0
        let l:at = match(l:line, l:pats.name_pat, l:col)
        let l:name = matchstr(l:line, l:pats.name_pat, l:col)
        let l:group = l:check
              \ ? synIDattr(synID(a:lnum, l:at + 1, 1), 'name')
              \ : ''
        if l:group !=# 'jinjaRaw' && l:group !=# 'jinjaComBlock'
          if l:name ==# 'raw' || has_key(l:pats.open_names, l:name)
            let l:opens += 1
          elseif l:name ==# 'endraw'
                \ || has_key(l:pats.close_names, l:name)
            let l:closes += 1
          endif
        endif
        let l:col = match(l:line, l:pats.tag, l:col + 1)
      endwhile
      let l:net = l:opens - l:closes
      if l:net > 0
        return 'a' . l:net
      elseif l:net < 0
        return 's' . (-l:net)
      endif
      return '='
    endfunction
    setlocal foldexpr=JinjaFoldLevelRel(v:lnum)
  endif

  if s:fold_fast && exists('*listener_add')
    " The {unbuffered} argument was added in Vim 9.1.1782, older Vims throw
    " E118 for it. A buffered listener is no use here (see the comment above),
    " so the cache is rebuilt on each change instead. Since the expression
    " cannot switch 'foldmethod', a line count change only sets a flag; the
    " autocmd below does the rebuild once the fold evaluation is over.
    let s:fold_listener = 0
    try
      let s:fold_listener = listener_add(function('JinjaFoldListen'), bufnr('%'), v:true)
    catch /^Vim\%((\a\+)\)\=:E118:/
      let b:jinja_fold_rebuild = 1
      function! s:FoldFix() abort
        if !get(b:, 'jinja_fold_fix', 0)
          return
        endif
        let b:jinja_fold_fix = 0
        noautocmd setlocal foldmethod=manual
        noautocmd setlocal foldmethod=expr
      endfunction
      augroup jinja_fold
        autocmd! * <buffer>
        autocmd TextChanged,TextChangedI,InsertLeave,BufWinEnter,WinEnter,
              \CursorMoved,CursorMovedI <buffer> call s:FoldFix()
      augroup END
      let s:undo .= '|autocmd! jinja_fold * <buffer>|unlet! b:jinja_fold_fix'
    endtry
    if s:fold_listener
      let s:undo .= '|call listener_remove(' . s:fold_listener . ')'
    endif
  endif

  setlocal foldmethod=expr
  let s:undo .= '|setlocal foldmethod< foldexpr<|unlet! b:jinja_fold_pats b:jinja_fold_cache b:jinja_fold_rebuild'
endif

" Block tag parsing, shared by the block highlight, `%` and the indent file.
call jinja#block_init()
let s:undo .= '|unlet! b:jinja_block_pats b:jinja_block_skip b:jinja_block_kind b:jinja_hl_cache'

" Background highlight of the block tags around the cursor. Set
" g:jinja_block_highlight to 0 in vimrc to disable.
"
" Only block statements are highlighted: when the cursor is on one of their
" tags (for, if, else, endfor, ...), the opener and the closer of that block
" get a background. The tag under the cursor uses another one, so it stands
" out, and the else/elif tags of the block a third. The text between the tags
" is rendered content and is left alone, and the highlight is cleared when the
" cursor is on that text. Tags may span lines; the tag under the cursor is
" found by scanning backward for its block start, and the matching tag is
" found by walking the tags around it with searchpos() once, cached until the
" buffer changes or the cursor moves to another tag.
if get(g:, 'jinja_block_highlight', 1)
  " The groups themselves are global and re-applied on a colorscheme or
  " 'background' change by autoload/jinja.vim; see jinja#block_colors().
  call jinja#block_colors()
  augroup jinja_block_highlight
    autocmd! * <buffer>
    autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI,InsertLeave <buffer> call jinja#block_highlight()
    autocmd BufWinEnter,WinEnter <buffer> call jinja#block_highlight(1)
    autocmd BufLeave,WinLeave <buffer> call jinja#block_clear()
  augroup END
  call jinja#block_highlight(1)
  let s:undo .= '|call jinja#block_clear_all()'
  let s:undo .= '|execute "autocmd! jinja_block_highlight * <buffer>"'
endif

" `%` on a block tag jumps to the next tag of the block, or to the opener
" from a closer. Anywhere else the previous `%` behavior is kept. Set
" g:jinja_percent_mapping to 0 in vimrc to disable.
if get(g:, 'jinja_percent_mapping', 1)
  function! s:PercentJump() abort
    if v:count == 0 && jinja#jump()
      return
    endif
    if exists('*matchup#motion#find_matching_pair')
          \ && get(g:, 'matchup_motion_enabled', 1)
      call matchup#motion#find_matching_pair(0, 1)
    elseif exists('*matchit#Match_wrapper')
      call matchit#Match_wrapper('', 1, 'n')
    elseif v:count > 0
      execute 'normal! ' . v:count . '%'
    else
      normal! %
    endif
  endfunction
  nnoremap <buffer> <silent> % :<C-U>call <SID>PercentJump()<CR>
  let s:undo .= '|silent! nunmap <buffer> %'
endif

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= '|' . s:undo
else
  let b:undo_ftplugin = s:undo
endif

" vim:set sw=4:
