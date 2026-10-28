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

" The opener and closer of the block the cursor is on, or []. An else/elif
" selects the if block around it. Cached until the buffer changes or the
" cursor moves to another tag.
function! s:BlockTags() abort
  let l:cur = s:TagAtCursor()
  if empty(l:cur)
    return []
  endif
  let l:key = l:cur.sl . ':' . l:cur.sc
  let l:c = get(b:, 'jinja_hl_cache', {})
  if get(l:c, 'tick', -1) == b:changedtick && get(l:c, 'key', '') ==# l:key
    return l:c.tags
  endif
  if l:cur.kind ==# 'close'
    let l:open = s:FindOpen(l:cur)
    let l:close = l:cur
  else
    let l:open = l:cur.kind ==# 'open' ? l:cur : s:FindOpen(l:cur)
    let l:close = s:ScanForward(l:cur, 0)
  endif
  let l:tags = empty(l:open) || empty(l:close) ? [] : [l:open, l:close]
  let b:jinja_hl_cache = {'tick': b:changedtick, 'key': l:key, 'tags': l:tags}
  return l:tags
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

function! jinja#block_highlight(...) abort
  if !get(g:, 'jinja_block_highlight', 1) || !exists('b:jinja_block_pats')
    call jinja#block_clear()
    return
  endif
  if a:0 && a:1
    call jinja#block_clear()
  endif
  let l:tags = s:BlockTags()
  if l:tags ==# get(w:, 'jinja_block_tags', [])
    return
  endif
  call jinja#block_clear()
  if empty(l:tags)
    return
  endif
  let l:pats = []
  for l:t in l:tags
    call extend(l:pats, s:TagPats(l:t))
  endfor
  " Priority 1, not -1: vim-matchup highlights the same tags with matches of
  " priority 0, and a lower priority would hide this background under them.
  let w:jinja_block_id = matchadd('jinjaBlockHighlight', join(l:pats, '\|'), 1)
  let w:jinja_block_tags = l:tags
endfunction

function! jinja#block_clear() abort
  if exists('w:jinja_block_id')
    silent! call matchdelete(w:jinja_block_id)
    unlet w:jinja_block_id
  endif
  if exists('w:jinja_block_tags')
    unlet w:jinja_block_tags
  endif
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

" vim:set sw=4:
