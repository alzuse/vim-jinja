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
let s:bc = '\%([^\n]\{-}[-+]\?' . s:be . '\)\?'

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
" The expression returns an absolute fold level (a Number), not "="/"a1"/"s1".
" With relative levels Vim re-evaluates the whole buffer after every change
" (measured: four passes over all lines for one inserted character). Absolute
" levels make Vim re-evaluate only the lines around the change.
"
" The level of every line is stored in one flat List, so a lookup is a single
" index operation. matchbufline() (Vim 9.1.0009 or newer) collects the tags in
" C; walking them line by line in Vim script cost hundreds of milliseconds on a
" 25k line file. Tags inside {% raw %} are skipped while building the list.
"
" A rebuild costs a few milliseconds, but Vim evaluates folds before buffered
" listeners run, so checking b:changedtick there would rebuild on every
" keystroke. Instead an unbuffered listener records which lines changed without
" scanning the buffer, and the expression validates just those lines first: an
" edit that leaves the block tags alone (typing text, reindenting) keeps the
" cached levels.
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
        \ 'open': s:tag_start . '\%(' . join(s:fold_names + ['raw'], '\|') . '\)\>',
        \ 'close': s:tag_start . 'end\w\+\>',
        \ }
  let b:jinja_fold_cache = {
        \ 'tick': -1, 'levels': [], 'tail': 0, 'sig': {}, 'fake': {},
        \ 'chg_any': 0, 'chg_added': 0, 'chg_lo': 0, 'chg_hi': 0,
        \ }

  if !exists('*JinjaFoldLevel')
    function! JinjaFoldLevel(lnum) abort
      let l:c = b:jinja_fold_cache
      if l:c.tick != b:changedtick
        call s:FoldRefresh(l:c)
      endif
      return get(l:c.levels, a:lnum - 1, l:c.tail)
    endfunction

    " Fallback for Vim without matchbufline(): relative levels, stateless.
    " This is correct but makes Vim re-evaluate the buffer after each change.
    function! JinjaFoldLevelRel(lnum) abort
      let l:line = getline(a:lnum)
      let l:pats = b:jinja_fold_pats
      if stridx(l:line, l:pats.bs) < 0 || l:line !~# l:pats.tag
        return '='
      endif
      if exists('b:current_syntax')
        let l:col = match(l:line, l:pats.tag)
        if l:col >= 0 && synIDattr(synID(a:lnum, l:col + 1, 1), 'name') ==# 'jinjaRaw'
          return '='
        endif
      endif
      let l:open = l:line =~# l:pats.open
      let l:close = l:line =~# l:pats.close
      if l:open && !l:close
        return 'a1'
      elseif l:close && !l:open
        return 's1'
      endif
      return '='
    endfunction

    " Records where a tag-looking match inside raw or a comment starts. The
    " fold match starts at the name; back up to the block start delimiter.
    function! s:FakeTag(fake, lnum, byteidx, name) abort
      if a:name ==# b:jinja_fold_pats.comment_start
            \ || a:name ==# b:jinja_fold_pats.comment_end
        return
      endif
      let l:pos = strridx(getline(a:lnum), b:jinja_fold_pats.bs, a:byteidx)
      if l:pos >= 0
        if has_key(a:fake, a:lnum)
          call add(a:fake[a:lnum], l:pos)
        else
          let a:fake[a:lnum] = [l:pos]
        endif
      endif
    endfunction

    " Every match inside raw or a comment, by line. Without syntax
    " highlighting this is the only way to tell such text from a real tag, so
    " it is only collected when the syntax is off: the pass is not cheap, and
    " normally comments and raw bodies are recognized from the syntax.
    function! s:FakeTags(matches) abort
      let l:fake = {}
      let l:raw = 0
      let l:comment = 0
      for l:m in a:matches
        let l:name = l:m.text
        if l:raw
          if l:name ==# 'endraw'
            let l:raw = 0
          else
            call s:FakeTag(l:fake, l:m.lnum, l:m.byteidx, l:name)
          endif
        elseif l:comment
          if l:name ==# b:jinja_fold_pats.comment_end
            let l:comment = 0
          else
            call s:FakeTag(l:fake, l:m.lnum, l:m.byteidx, l:name)
          endif
        elseif l:name ==# b:jinja_fold_pats.comment_start
          let l:comment = 1
        elseif l:name ==# 'raw'
          let l:raw = 1
        endif
      endfor
      return l:fake
    endfunction

    function! s:FoldLevels() abort
      let l:matches = matchbufline(bufnr('%'), b:jinja_fold_pats.find, 1, '$')
      let l:deltas = {}
      let l:sig = {}
      " Tag-looking text inside raw and comments, by line, for highlighting:
      " it is not a real tag and must not be matched as one.
      let l:fake = {}
      let l:raw = 0
      let l:comment = 0
      let l:i = 0
      let l:n = len(l:matches)
      while l:i < l:n
        let l:lnum = l:matches[l:i].lnum
        let l:names = []
        let l:opens = 0
        let l:closes = 0
        while l:i < l:n && l:matches[l:i].lnum == l:lnum
          let l:name = l:matches[l:i].text
          call add(l:names, l:name)
          let l:i += 1
          if l:raw
            if l:name ==# 'endraw'
              let l:raw = 0
              let l:closes += 1
            endif
          elseif l:comment
            if l:name ==# b:jinja_fold_pats.comment_end
              let l:comment = 0
            endif
          elseif l:name ==# b:jinja_fold_pats.comment_start
            let l:comment = 1
          elseif l:name ==# 'raw'
            let l:raw = 1
            let l:opens += 1
          elseif has_key(s:fold_open, l:name)
            let l:opens += 1
          elseif has_key(s:fold_close, l:name)
            let l:closes += 1
          endif
        endwhile
        " The joined names let the listener below detect edits that do not
        " change what the line contributes to the fold structure.
        let l:sig[l:lnum] = join(l:names, ',')
        if l:opens > 0 && l:closes > 0
          " A line opening and closing a block does not start a fold.
          let l:opens = 0
          let l:closes = 0
        endif
        if l:opens > 0
          let l:deltas[l:lnum] = get(l:deltas, l:lnum, 0) + l:opens
        elseif l:closes > 0
          " The line with the end tag still belongs to the fold.
          let l:deltas[l:lnum + 1] = get(l:deltas, l:lnum + 1, 0) - l:closes
        endif
      endwhile
      if get(g:, 'jinja_block_highlight', 1) && !exists('b:current_syntax')
        let l:fake = s:FakeTags(l:matches)
      endif

      " Expand the deltas to one level per line. repeat() and extend() run in C.
      let l:levels = []
      let l:lvl = 0
      let l:prev = 1
      for l:lnum in sort(map(keys(l:deltas), 'str2nr(v:val)'), 'n')
        if l:lnum > l:prev
          call extend(l:levels, repeat([l:lvl], l:lnum - l:prev))
        endif
        let l:lvl += l:deltas[l:lnum]
        if l:lvl < 0
          let l:lvl = 0
        endif
        let l:prev = l:lnum
      endfor
      let l:last = line('$')
      if l:last >= l:prev
        call extend(l:levels, repeat([l:lvl], l:last - l:prev + 1))
      endif

      let l:c = b:jinja_fold_cache
      let l:c.tick = b:changedtick
      let l:c.levels = l:levels
      let l:c.tail = empty(l:levels) ? l:lvl : l:levels[-1]
      let l:c.sig = l:sig
      let l:c.fake = l:fake
      let l:c.chg_any = 0
      let l:c.chg_added = 0
      let l:c.chg_lo = 0
      let l:c.chg_hi = 0
    endfunction

    " Runs when b:changedtick moved. Only the lines reported by the listener
    " below are checked; everything else is trusted to be unchanged.
    function! s:FoldRefresh(c) abort
      if !a:c.chg_any || a:c.chg_added || len(a:c.levels) != line('$')
        call s:FoldLevels()
      elseif s:FoldSigSame(a:c, a:c.chg_lo, a:c.chg_hi)
        let a:c.tick = b:changedtick
        let a:c.chg_any = 0
        let a:c.chg_lo = 0
        let a:c.chg_hi = 0
      else
        call s:FoldLevels()
        " Vim only re-evaluates the changed lines and stops as soon as their
        " level is unchanged; assigning 'foldexpr' makes it recompute them all.
        let &l:foldexpr = &l:foldexpr
      endif
    endfunction

    " Unbuffered listener: called for every change, before folds are evaluated.
    " It only records where the change is; scanning the buffer here would cost
    " much more than keeping the levels and checking the changed lines later.
    function! s:FoldListen(bufnr, start, end, added, changes) abort
      let l:c = a:bufnr == bufnr('%') ? get(b:, 'jinja_fold_cache', {})
            \ : getbufvar(a:bufnr, 'jinja_fold_cache', {})
      if empty(l:c)
        return
      endif
      if a:added != 0
        let l:c.chg_added = 1
      else
        if !l:c.chg_any || a:start < l:c.chg_lo
          let l:c.chg_lo = a:start
        endif
        " s:FoldSigSame() clamps to the buffer it is evaluating, which is not
        " necessarily the one that was changed here.
        if a:end - 1 > l:c.chg_hi
          let l:c.chg_hi = a:end - 1
        endif
      endif
      let l:c.chg_any = 1
    endfunction

    function! s:FoldSigSame(cache, lo, hi) abort
      let l:last = line('$')
      let l:lo = a:lo < 1 ? 1 : a:lo
      let l:hi = a:hi > l:last ? l:last : a:hi
      if l:lo > l:hi
        return 1
      endif
      let l:seen = {}
      for l:m in matchbufline(bufnr('%'), b:jinja_fold_pats.find, l:lo, l:hi)
        let l:ln = l:m.lnum
        if has_key(l:seen, l:ln)
          let l:seen[l:ln] .= ',' . l:m.text
        else
          let l:seen[l:ln] = l:m.text
        endif
      endfor
      for [l:ln, l:names] in items(l:seen)
        if get(a:cache.sig, l:ln, '') !=# l:names
          return 0
        endif
      endfor
      " A line that had tags before and has none now is not in seen.
      for l:ln in keys(a:cache.sig)
        let l:n = str2nr(l:ln)
        if l:n >= l:lo && l:n <= l:hi && !has_key(l:seen, l:ln)
          return 0
        endif
      endfor
      return 1
    endfunction
  endif

  setlocal foldmethod=expr
  if exists('*matchbufline')
    setlocal foldexpr=JinjaFoldLevel(v:lnum)
    if exists('*listener_add')
      let s:fold_listener = listener_add(function('s:FoldListen'), bufnr('%'), v:true)
      let s:undo .= '|call listener_remove(' . s:fold_listener . ')'
    endif
  else
    setlocal foldexpr=JinjaFoldLevelRel(v:lnum)
  endif
  let s:undo .= '|setlocal foldmethod< foldexpr<|unlet! b:jinja_fold_pats b:jinja_fold_cache'
endif

" Block tag parsing, shared by the block highlight and by `%`. Tags may span
" lines: the tag body is matched with \_.{-}, so a tag like
"   <% if a
"      and b %>
" is a single tag.
let s:bopen = join(s:block_names + ['raw'], '\|')
let s:bend = map(copy(s:block_names + ['raw']), '"end" . v:val')
let s:tagbody = '\%(\_.\)\{-}[-+]\?' . s:be
let b:jinja_block_kind = {}
for s:name in s:block_names + ['raw']
  let b:jinja_block_kind[s:name] = 'open'
  let b:jinja_block_kind['end' . s:name] = 'close'
endfor
unlet s:name
let b:jinja_block_kind['else'] = 'mid'
let b:jinja_block_kind['elif'] = 'mid'
let b:jinja_block_pats = {
      \ 'start': '\V' . escape(s:delims.block_start, '\'),
      \ 'end': '\V' . escape(s:delims.block_end, '\'),
      \ 'endlen': strlen(s:delims.block_end),
      \ 'name': '\C' . s:bt . '\zs\w\+',
      \ 'all': '\C' . s:bt . '\%(' . s:bopen . '\|else\|elif\|'
      \        . join(s:bend, '\|') . '\)\>' . s:tagbody,
      \ }
let b:jinja_block_skip = 'jinja#tag_skip()'
let s:undo .= '|unlet! b:jinja_block_pats b:jinja_block_skip b:jinja_block_kind b:jinja_hl_cache'

" Background highlight of the block tags around the cursor. Set
" g:jinja_block_highlight to 0 in vimrc to disable.
"
" Only block statements are highlighted: when the cursor is on one of their
" tags (for, if, else, endfor, ...), the opener and the closer of that block
" get a background. The text between the tags is rendered content and is left
" alone, and the highlight is cleared when the cursor is on that text. Tags
" may span lines; the tag under the cursor is found by scanning backward for
" its block start, and the matching tag is found by walking the tags around it
" with searchpos() once, cached until the buffer changes or the cursor moves
" to another tag.
if get(g:, 'jinja_block_highlight', 1)
  hi def link jinjaBlockHighlight ColorColumn
  augroup jinja_block_highlight
    autocmd! * <buffer>
    " A colorscheme reload clears every highlight group, including this link.
    autocmd ColorScheme <buffer> hi def link jinjaBlockHighlight ColorColumn
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
