" Vim autoload file

" All delimiter settings in one place. Scripts call this once at the top and
" keep the result; defaults are not repeated at the places that use them.
" The values are not cached, so a delimiter changed in vimrc is picked up by
" buffers opened later.
function! jinja#delims() abort
  return {
        \ 'block_start':    get(g:, 'jinja_block_start_string', '<%'),
        \ 'block_end':      get(g:, 'jinja_block_end_string', '%>'),
        \ 'variable_start': get(g:, 'jinja_variable_start_string', '<$'),
        \ 'variable_end':   get(g:, 'jinja_variable_end_string', '$>'),
        \ 'comment_start':  get(g:, 'jinja_comment_start_string', '<#'),
        \ 'comment_end':    get(g:, 'jinja_comment_end_string', '#>'),
        \ }
endfunction

" Builds the buffer-local block tag patterns, shared by the block highlight,
" `%` and the indent file. Tags may span lines: the body is matched with
" \_.{-}, so "<% if a" / "and b %>" is a single tag. Idempotent.
function! jinja#block_init() abort
  if exists('b:jinja_block_pats')
    return
  endif
  let l:d = jinja#delims()
  let l:be = escape(l:d.block_end, '\.*$^~[]\')
  let l:bt = escape(l:d.block_start, '\.*$^~[]\') . '[-+]\?\s*'
  let l:names = ['for', 'if', 'block', 'macro', 'filter', 'with',
        \ 'autoescape', 'call', 'trans', 'raw']
  let b:jinja_block_kind = {}
  for l:name in l:names
    let b:jinja_block_kind[l:name] = 'open'
    let b:jinja_block_kind['end' . l:name] = 'close'
  endfor
  let b:jinja_block_kind['else'] = 'mid'
  let b:jinja_block_kind['elif'] = 'mid'
  let b:jinja_block_pats = {
        \ 'start': '\V' . escape(l:d.block_start, '\'),
        \ 'end': '\V' . escape(l:d.block_end, '\'),
        \ 'endlen': strlen(l:d.block_end),
        \ 'name': '\C' . l:bt . '\zs\w\+',
        \ 'all': '\C' . l:bt . '\%(' . join(l:names, '\|') . '\|else\|elif\|'
        \        . join(map(copy(l:names), '"end" . v:val'), '\|') . '\)\>'
        \        . '\%(\_.\)\{-}[-+]\?' . l:be,
        \ }
  let b:jinja_block_skip = 'jinja#tag_skip()'
endfunction

" The tag that starts at a:lnum/a:col (the first byte of the block start
" delimiter), or {} when the text there is not a block statement. The Dict
" holds the byte column of the delimiter start (sl/sc) and the column just
" past the end delimiter (el/ec), the keyword and its kind. A tag may span
" lines: its end is the first end delimiter after the start, which is what
" the matching pattern uses as well.
function! s:TagFromStart(lnum, col) abort
  let l:p = b:jinja_block_pats
  let l:name = matchstr(getline(a:lnum), l:p.name, a:col - 1)
  let l:kind = get(b:jinja_block_kind, l:name, '')
  if l:kind ==# ''
    return {}
  endif
  let l:pos = getcurpos()
  call cursor(a:lnum, a:col)
  let [l:el, l:ec] = searchpos(l:p.end, 'cnW')
  call setpos('.', l:pos)
  if l:el == 0
    return {}
  endif
  return {'sl': a:lnum, 'sc': a:col, 'el': l:el,
        \ 'ec': l:ec + l:p.endlen, 'name': l:name, 'kind': l:kind}
endfunction

" The block tag the cursor is inside, or {}. Scans backward for the nearest
" block start; a tag on an earlier line counts when its end is still after
" the cursor. A start inside raw or a comment is not a tag (the loop keeps
" looking further back); the first real one decides, so text after a tag and
" before the next one yields {}.
function! s:TagAtCursor() abort
  let l:p = b:jinja_block_pats
  let l:pos = getcurpos()
  let l:first = 1
  let l:tag = {}
  while 1
    let [l:sl, l:sc] = searchpos(l:p.start, l:first ? 'cbW' : 'bW')
    let l:first = 0
    if l:sl == 0
      break
    endif
    if s:InSkip(l:sl, l:sc)
      continue
    endif
    let l:t = s:TagFromStart(l:sl, l:sc)
    if !empty(l:t) && (l:t.el > l:pos[1]
          \ || (l:t.el == l:pos[1] && l:t.ec > l:pos[2]))
      let l:tag = l:t
    endif
    break
  endwhile
  call setpos('.', l:pos)
  return l:tag
endfunction

" Scans forward from just past a:tag. Nested blocks are skipped. With a:mids
" the next else/elif at the same depth, or the end of the block, is returned;
" without it only the end of the block.
function! s:ScanForward(tag, mids) abort
  let l:p = b:jinja_block_pats
  let l:skip = b:jinja_block_skip
  let l:pos = getcurpos()
  let l:depth = 0
  let l:found = {}
  call cursor(a:tag.el, a:tag.ec)
  while 1
    let [l:ml, l:mc] = searchpos(l:p.all, 'cnW', 0, 0, l:skip)
    if l:ml == 0
      break
    endif
    let l:t = s:TagFromStart(l:ml, l:mc)
    if empty(l:t)
      call cursor(l:ml, l:mc + 1)
      continue
    endif
    call cursor(l:t.el, l:t.ec)
    if l:t.kind ==# 'open'
      let l:depth += 1
    elseif l:t.kind ==# 'close'
      if l:depth == 0
        let l:found = l:t
        break
      endif
      let l:depth -= 1
    elseif a:mids && l:depth == 0
      let l:found = l:t
      break
    endif
  endwhile
  call setpos('.', l:pos)
  return l:found
endfunction

" The else/elif tags between the opener a:open and the closer a:close, at the
" level of the block (nested blocks are skipped).
function! s:ScanMids(open, close) abort
  let l:p = b:jinja_block_pats
  let l:skip = b:jinja_block_skip
  let l:pos = getcurpos()
  let l:depth = 0
  let l:mids = []
  call cursor(a:open.el, a:open.ec)
  while 1
    let [l:ml, l:mc] = searchpos(l:p.all, 'cnW', 0, 0, l:skip)
    if l:ml == 0
      break
    endif
    let l:t = s:TagFromStart(l:ml, l:mc)
    if empty(l:t)
      call cursor(l:ml, l:mc + 1)
      continue
    endif
    if l:t.sl == a:close.sl && l:t.sc == a:close.sc
      break
    endif
    call cursor(l:t.el, l:t.ec)
    if l:t.kind ==# 'open'
      let l:depth += 1
    elseif l:t.kind ==# 'close'
      let l:depth -= 1
    elseif l:depth == 0
      call add(l:mids, l:t)
    endif
  endwhile
  call setpos('.', l:pos)
  return l:mids
endfunction

" Scans backward from the start of a:tag for the opener of its block.
function! s:FindOpen(tag) abort
  let l:p = b:jinja_block_pats
  let l:skip = b:jinja_block_skip
  let l:pos = getcurpos()
  let l:depth = 0
  let l:found = {}
  call cursor(a:tag.sl, a:tag.sc)
  while 1
    let [l:ml, l:mc] = searchpos(l:p.all, 'bW', 0, 0, l:skip)
    if l:ml == 0
      break
    endif
    let l:t = s:TagFromStart(l:ml, l:mc)
    if empty(l:t)
      continue
    endif
    if l:t.kind ==# 'close'
      let l:depth += 1
    elseif l:t.kind ==# 'open'
      if l:depth == 0
        let l:found = l:t
        break
      endif
      let l:depth -= 1
    endif
  endwhile
  call setpos('.', l:pos)
  return l:found
endfunction

" The tag under the cursor, the opener/closer of its block and the else/elif
" tags between them, as a Dict, or {} when the cursor is not on a block tag.
" An else/elif selects the if block around it; 'tags' is empty when no pair
" was found. Cached until the buffer changes or the cursor moves to another
" tag.
function! s:BlockTags() abort
  let l:cur = s:TagAtCursor()
  if empty(l:cur)
    return {}
  endif
  let l:key = l:cur.sl . ':' . l:cur.sc
  let l:c = get(b:, 'jinja_hl_cache', {})
  if get(l:c, 'tick', -1) == b:changedtick && get(l:c, 'key', '') ==# l:key
    return l:c
  endif
  if l:cur.kind ==# 'close'
    let l:open = s:FindOpen(l:cur)
    let l:close = l:cur
  else
    let l:open = l:cur.kind ==# 'open' ? l:cur : s:FindOpen(l:cur)
    let l:close = s:ScanForward(l:cur, 0)
  endif
  let l:tags = empty(l:open) || empty(l:close) ? [] : [l:open, l:close]
  let l:mids = empty(l:tags) ? [] : s:ScanMids(l:open, l:close)
  let b:jinja_hl_cache = {'tick': b:changedtick, 'key': l:key,
        \ 'cur': l:cur, 'tags': l:tags, 'mids': l:mids}
  return b:jinja_hl_cache
endfunction

" matchadd() patterns covering a:tag. The column atom only constrains where a
" match starts, so the length is spelled out; a tag spanning lines is covered
" by its first line from the start delimiter, the lines between in full, and
" its last line up to the end delimiter.
function! s:TagPats(tag) abort
  if a:tag.sl == a:tag.el
    let l:s = strpart(getline(a:tag.sl), a:tag.sc - 1, a:tag.ec - a:tag.sc)
    return ['\%' . a:tag.sl . 'l\%' . a:tag.sc . 'c.\{' . strchars(l:s) . '}']
  endif
  let l:pats = ['\%' . a:tag.sl . 'l\%' . a:tag.sc . 'c.*']
  if a:tag.el > a:tag.sl + 1
    " \(.\+\|^$\) keeps empty lines in the match.
    call add(l:pats, '\%>' . a:tag.sl . 'l\%<' . a:tag.el . 'l\(.\+\|^$\)')
  endif
  let l:s = strpart(getline(a:tag.el), 0, a:tag.ec - 1)
  call add(l:pats, '\%' . a:tag.el . 'l\%1c.\{' . strchars(l:s) . '}')
  return l:pats
endfunction

" Returns 1 if a:lnum/a:col (1-based) is a comment, a raw block or a string,
" where a tag-looking text does not open a block. Tag lines found by the fold
" cache are known without the syntax, which also covers 'syntax off'.
function! s:InSkip(lnum, col) abort
  let l:fc = get(b:, 'jinja_fold_cache', {})
  if !exists('b:current_syntax') && !empty(l:fc) && l:fc.tick != b:changedtick
        \ && exists('*JinjaFoldLevel')
    " The fake tag map below is built by the fold cache.
    call JinjaFoldLevel(a:lnum)
  endif
  let l:fake = get(get(b:, 'jinja_fold_cache', {}), 'fake', {})
  if index(get(l:fake, a:lnum, []), a:col - 1) >= 0
    return 1
  endif
  if !exists('b:current_syntax')
    return 0
  endif
  return synIDattr(synID(a:lnum, a:col, 1), 'name')
        \ =~? 'jinjaRaw\|jinjaComBlock\|jinjaArgument'
endfunction

" Skip expression for searchpos(): a tag-looking match inside raw, a comment
" or a string does not participate in block matching.
function! jinja#tag_skip() abort
  return s:InSkip(line('.'), col('.'))
endfunction

" `%` on a block tag: the next else/elif or the end of the block, and from a
" closer the opener. matchit and vim-matchup match a delimiter against one
" line and cannot tell that the continuation line of a tag is still the tag.
" Returns 0 when the cursor is not on a block tag, so the caller can fall back
" to the usual `%`.
function! jinja#jump() abort
  if !exists('b:jinja_block_pats')
    return 0
  endif
  let l:cur = s:TagAtCursor()
  if empty(l:cur)
    return 0
  endif
  if l:cur.kind ==# 'close'
    let l:t = s:FindOpen(l:cur)
    if empty(l:t)
      return 1
    endif
    call cursor(l:t.sl, l:t.sc)
  else
    let l:t = s:ScanForward(l:cur, 1)
    if empty(l:t)
      return 1
    endif
    " Forward jumps land on the last character of the tag, like vim-matchup.
    call cursor(l:t.el, l:t.ec - 1)
  endif
  return 1
endfunction

" Called from TextChangedI in the indent file. When the line just became
" nothing but a block closing tag, line it up with the tag that opened the
" block: typing "%>" then undoes the indent the body left on the line. Only a
" tag that starts the line is touched. The name counts as well as the end
" delimiter, so a tag whose delimiters were typed first ("<% %>") is lined up
" as soon as "endif" fills it in. Returns 1 when the line was reindented.
function! jinja#align_close() abort
  if !get(g:, 'jinja_close_indent', 1)
    return 0
  endif
  let l:lnum = line('.')
  let l:line = getline(l:lnum)
  let l:d = jinja#delims()
  if stridx(l:line, l:d.block_start) < 0
    return 0
  endif
  call jinja#block_init()
  let l:p = b:jinja_block_pats
  if l:line !~# '^\s*' . l:p.start
    return 0
  endif
  let l:col = match(l:line, '\S') + 1
  let l:t = s:TagFromStart(l:lnum, l:col)
  if empty(l:t) || l:t.kind !=# 'close' || s:InSkip(l:lnum, l:col)
    return 0
  endif
  " The tag must end on this line and nothing but whitespace may follow it.
  if l:t.el != l:lnum || strpart(l:line, l:t.ec - 1) =~# '\S'
    return 0
  endif
  let l:open = s:FindOpen(l:t)
  if empty(l:open)
    return 0
  endif
  let l:old = matchstr(l:line, '^\s*')
  let l:new = matchstr(getline(l:open.sl), '^\s*')
  if l:new ==# l:old
    return 0
  endif
  let l:pos = getcurpos()
  " The reindent joins the insert so one undo still removes both.
  silent! undojoin
  call setline(l:lnum, l:new . strpart(l:line, strlen(l:old)))
  let l:pos[2] += strlen(l:new) - strlen(l:old)
  call setpos('.', l:pos)
  return 1
endfunction

" The tag under the cursor gets a distinct background (jinjaBlockHighlightCur),
" the opener and closer of its block the usual one (jinjaBlockHighlight), and
" the other else/elif tags of the block a third (jinjaBlockHighlightMid); see
" jinja#block_colors(). Only backgrounds are set, so the syntax colors of the
" tag text stay visible.
function! jinja#block_highlight(...) abort
  if !get(g:, 'jinja_block_highlight', 1) || !exists('b:jinja_block_pats')
    call jinja#block_clear()
    return
  endif
  if a:0 && a:1
    call jinja#block_clear()
  endif
  let l:b = s:BlockTags()
  let l:tags = get(l:b, 'tags', [])
  if empty(l:tags)
    if exists('w:jinja_block_state')
      call jinja#block_clear()
    endif
    return
  endif
  let l:cur = l:b.cur
  let l:mids = get(l:b, 'mids', [])
  " Extents in the window state make CursorMoved cheap: moving inside the same
  " tag, or to a tag of the same block, leaves the matches in place.
  let l:state = [[l:cur.sl, l:cur.sc, l:cur.el, l:cur.ec]]
  for l:t in l:tags + l:mids
    call add(l:state, [l:t.sl, l:t.sc, l:t.el, l:t.ec])
  endfor
  if l:state ==# get(w:, 'jinja_block_state', [])
    return
  endif
  call jinja#block_clear()
  let l:pats = []
  for l:t in l:tags
    if l:t.sl == l:cur.sl && l:t.sc == l:cur.sc
      continue
    endif
    call extend(l:pats, s:TagPats(l:t))
  endfor
  " Priority 1 and 2, not -1: vim-matchup highlights the same tags with
  " matches of priority 0, and a lower priority would hide this background
  " under them. This also covers the else/elif tags, which matchup paints in
  " its own color: here they are grey instead.
  if !empty(l:pats)
    let w:jinja_block_id = matchadd('jinjaBlockHighlight',
          \ join(l:pats, '\|'), 1)
  endif
  let l:pats = []
  for l:t in l:mids
    call extend(l:pats, s:TagPats(l:t))
  endfor
  if !empty(l:pats)
    let w:jinja_block_mid_id = matchadd('jinjaBlockHighlightMid',
          \ join(l:pats, '\|'), 1)
  endif
  let w:jinja_block_cur_id = matchadd('jinjaBlockHighlightCur',
        \ join(s:TagPats(l:cur), '\|'), 2)
  let w:jinja_block_tags = l:tags
  let w:jinja_block_state = l:state
endfunction

function! jinja#block_clear() abort
  if exists('w:jinja_block_id')
    silent! call matchdelete(w:jinja_block_id)
    unlet w:jinja_block_id
  endif
  if exists('w:jinja_block_mid_id')
    silent! call matchdelete(w:jinja_block_mid_id)
    unlet w:jinja_block_mid_id
  endif
  if exists('w:jinja_block_cur_id')
    silent! call matchdelete(w:jinja_block_cur_id)
    unlet w:jinja_block_cur_id
  endif
  if exists('w:jinja_block_tags')
    unlet w:jinja_block_tags
  endif
  if exists('w:jinja_block_state')
    unlet w:jinja_block_state
  endif
endfunction

" Backgrounds only: the syntax colors of the tag text stay visible.
"
" Each background is copied from a standard group that follows the colorscheme
" and 'background': ColorColumn for the opener and closer of the block,
" CursorColumn for the other else/elif tags, MatchParen for the tag under the
" cursor. Set g:jinja_block_highlight_colors to use other colors; a value is
" either a group name (its background is copied) or "hi" arguments for the
" group itself:
"
"   let g:jinja_block_highlight_colors = {
"         \ 'cur': 'Search',
"         \ 'mid': 'ctermbg=240 guibg=#3a3a3a',
"         \ }
function! jinja#block_colors() abort
  if !get(g:, 'jinja_block_highlight', 1)
    return
  endif
  let l:opts = get(g:, 'jinja_block_highlight_colors', {})
  let l:dark = &background ==# 'dark'
  " group, option key, default source group, [dark cterm, dark gui],
  " [light cterm, light gui]. The colors are only used when the source group
  " has no background, e.g. a colorscheme that only sets a foreground.
  let l:groups = [
        \ ['jinjaBlockHighlight', 'pair', 'ColorColumn',
        \  ['1', 'DarkRed'], ['224', 'LightRed']],
        \ ['jinjaBlockHighlightMid', 'mid', 'CursorColumn',
        \  ['242', 'Grey40'], ['7', 'Grey90']],
        \ ['jinjaBlockHighlightCur', 'cur', 'MatchParen',
        \  ['6', 'DarkCyan'], ['14', 'Cyan']],
        \ ]
  for [l:group, l:role, l:def, l:fb_dark, l:fb_light] in l:groups
    let l:val = get(l:opts, l:role, '')
    if l:val =~# '='
      execute 'hi ' . l:group . ' ' . l:val
      continue
    endif
    let l:src = l:val ==# '' ? l:def : l:val
    let l:fb = l:dark ? l:fb_dark : l:fb_light
    let l:attrs = []
    for l:i in [0, 1]
      let l:mode = l:i == 0 ? 'cterm' : 'gui'
      let l:v = synIDattr(synIDtrans(hlID(l:src)), 'bg', l:mode)
      if l:v ==# ''
        let l:v = l:fb[l:i]
      endif
      call add(l:attrs, l:mode . 'bg=' . l:v)
    endfor
    execute 'hi ' . l:group . ' ' . join(l:attrs, ' ')
  endfor
endfunction

" Matches are window-local, so every window showing this buffer is cleared.
function! jinja#block_clear_all() abort
  if !exists('*win_execute')
    call jinja#block_clear()
    return
  endif
  let l:buf = bufnr('%')
  for l:info in getwininfo()
    if l:info.bufnr == l:buf
      call win_execute(l:info.winid, 'call jinja#block_clear()')
    endif
  endfor
endfunction

" The block highlight groups are global. Both a colorscheme reload and a
" change of 'background' reset every highlight group, so the colors have to be
" applied again. A colorscheme fires ColorScheme; 'background' does not, and
" resets the groups before OptionSet runs.
augroup jinja_block_colors
  autocmd!
  autocmd ColorScheme * call jinja#block_colors()
  autocmd OptionSet background call jinja#block_colors()
augroup END

" vim:set sw=4:
