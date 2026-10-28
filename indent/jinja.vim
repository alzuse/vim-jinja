" Vim indent file
" Language: Jinja HTML template
" Maintainer: Evan Hammer <evan@evanhammer.com>
" Last Change: Oct 27, 2026

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

let b:did_indent = 1

setlocal indentexpr=GetJinjaIndent()
setlocal indentkeys=o,O,*<Return>,!^F
let b:undo_indent = 'setlocal indentexpr< indentkeys<|unlet! b:jinja_indent_pats'

let s:delims = jinja#delims()
let s:bs = escape(s:delims.block_start, '\.*$^~[]\')
let s:be = escape(s:delims.block_end, '\.*$^~[]\')
let s:tag_start = s:bs . '[-+]\?\s*'
let s:tag_tail = '.\{-}[-+]\?' . s:be
let s:blocktags = '\%(block\|for\|if\|with\|autoescape\|filter\|call\|macro\|trans\)\>'
let s:midtags = '\%(empty\|else\|elif\|pluralize\)\>'

let b:jinja_indent_pats = {
      \ 'bs': s:delims.block_start,
      \ 'tag': s:tag_start . '\a',
      \ 'raw_open': s:tag_start . 'raw\>' . s:tag_tail,
      \ 'raw_close': s:tag_start . 'endraw\>' . s:tag_tail,
      \ 'block_start': s:tag_start . s:blocktags . s:tag_tail,
      \ 'block_end': s:tag_start . 'end' . s:blocktags . s:tag_tail,
      \ 'block_mid': s:tag_start . s:midtags . s:tag_tail,
      \ }

" Only define the functions once.
if exists("*GetJinjaIndent")
  finish
endif

" True when the first tag on a:line is literal text inside {% raw %}. Syntax
" highlighting knows this; scanning backwards from line one would make every
" indent evaluation linear in the buffer size.
function! s:TagInRaw(lnum, line, pats) abort
  if !exists('b:current_syntax')
    return 0
  endif
  let l:col = match(a:line, a:pats.tag)
  return l:col >= 0 && synIDattr(synID(a:lnum, l:col + 1, 1), 'name') ==# 'jinjaRaw'
endfunction

" Line number of the raw opener enclosing a:lnum, or 0. Only called for an
" endraw line, so the scan is rare.
function! s:RawOpener(lnum, pats) abort
  let l:n = a:lnum
  while l:n > 0
    let l:line = getline(l:n)
    if l:line =~# a:pats.raw_close
      return 0
    endif
    if l:line =~# a:pats.raw_open && !s:TagInRaw(l:n, l:line, a:pats)
      return l:n
    endif
    let l:n -= 1
  endwhile
  return 0
endfunction

function! GetJinjaIndent()
  let l:plnum = prevnonblank(v:lnum - 1)
  if l:plnum == 0
    return 0
  endif

  " Keep the indentation of the previous line, or let cindent decide when
  " the user enabled it.
  let l:ind = &l:cindent ? cindent(v:lnum) : -1
  if l:ind < 0
    let l:ind = indent(l:plnum)
  endif

  let l:pats = b:jinja_indent_pats
  let l:pnb = getline(l:plnum)
  let l:cur = getline(v:lnum)
  " Most lines have no Jinja tag at all; skip the regexps for those.
  let l:pnb_has = stridx(l:pnb, l:pats.bs) >= 0
  let l:cur_has = stridx(l:cur, l:pats.bs) >= 0

  " Everything inside a raw block is literal text: keep the indent, and align
  " the endraw line with its opener.
  if l:cur_has
    if l:cur =~# l:pats.tag && s:TagInRaw(v:lnum, l:cur, l:pats)
      return l:ind
    endif
    if l:cur =~# l:pats.raw_close
      let l:open_lnum = s:RawOpener(l:plnum, l:pats)
      if l:open_lnum > 0
        return indent(l:open_lnum)
      endif
    endif
  endif
  if l:pnb_has
    if l:pnb =~# l:pats.tag && s:TagInRaw(l:plnum, l:pnb, l:pats)
      return l:ind
    endif
    " The line after a raw opener is literal too: don't open a level for it.
    if l:pnb =~# l:pats.raw_open
      return l:ind
    endif
  endif

  let l:pnb_blockstart = l:pnb_has && l:pnb =~# l:pats.block_start
  let l:pnb_blockend   = l:pnb_has && l:pnb =~# l:pats.block_end
  let l:pnb_blockmid   = l:pnb_has && l:pnb =~# l:pats.block_mid

  let l:cur_blockstart = l:cur_has && l:cur =~# l:pats.block_start
  let l:cur_blockend   = l:cur_has && l:cur =~# l:pats.block_end
  let l:cur_blockmid   = l:cur_has && l:cur =~# l:pats.block_mid

  if (l:pnb_blockstart && !l:pnb_blockend) || (l:pnb_blockmid && !l:pnb_blockend)
    let l:ind += shiftwidth()
  endif

  if (l:cur_blockend && !l:cur_blockstart) || l:cur_blockmid
    let l:ind -= shiftwidth()
  endif

  return l:ind < 0 ? 0 : l:ind
endfunction
