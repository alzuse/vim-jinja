vim9script

# Fold level cache for Vim with matchbufline() (9.1.0009 or newer).
#
# This file is sourced by ftplugin/jinja.vim, not autoloaded: a Vim9 script
# cannot define the jinja_fold#...() functions legacy script would call, so the
# functions below are global instead.
#
# The cache lives in b:jinja_fold_cache. b:jinja_fold_pats holds the patterns
# and the tag name tables the ftplugin built for this buffer.
#
# This is the hot path of the filetype plugin: a 25k line template has around
# 20k tags, and the legacy Vim script loop over them made a rebuild take about
# a second. Compiled Vim9 makes it roughly ten times faster, both for the
# rebuild and for the one lookup Vim does per line while evaluating folds.

# Records where a tag-looking match inside raw or a comment starts. The fold
# match starts at the name; back up to the block start delimiter.
def FakeTag(fake: dict<list<number>>, lnum: number, byteidx: number, name: string)
  if name == b:jinja_fold_pats.cstart || name == b:jinja_fold_pats.cend
    return
  endif
  var pos = strridx(getline(lnum), b:jinja_fold_pats.bs, byteidx)
  if pos >= 0
    if has_key(fake, lnum)
      fake[lnum]->add(pos)
    else
      fake[lnum] = [pos]
    endif
  endif
enddef

# Builds one entry per line: a Number with the fold level, or ">N"/"<N" on a
# line where a fold must start/end. Neighbouring blocks of the same level have
# no level change between them, so without the markers Vim would fold them as a
# single block.
#
# matchbufline() returns the tag names in buffer order, so one pass over them
# fills the levels: lines without tags repeat the current level, and the level
# only changes on a tag line. No per-line tag table and no second pass.
def Build(cache: dict<any>)
  var pats = b:jinja_fold_pats
  var last = line('$')
  var matches = matchbufline(bufnr(), pats.find, 1, '$')
  var levels: list<any> = []
  var sig: list<string> = repeat([''], last)
  var fake: dict<list<number>> = {}
  # Tag-looking text inside raw and comments, by line, for highlighting: it is
  # not a real tag and must not be matched as one. The syntax knows this
  # already when it is loaded.
  var collect_fake = get(g:, 'jinja_block_highlight', 1) != 0
        && !exists('b:current_syntax')
  var open: dict<number> = pats.open_names
  var close: dict<number> = pats.close_names
  var raw = false
  var comment = false
  var lvl = 0
  var filled = 1
  var i = 0
  var n = len(matches)
  while i < n
    var lnum: number = matches[i].lnum
    var names: list<string> = []
    var opens = 0
    var closes = 0
    while i < n && matches[i].lnum == lnum
      var name: string = matches[i].text
      var byteidx: number = matches[i].byteidx
      names->add(name)
      i += 1
      if raw
        if name == 'endraw'
          raw = false
          closes += 1
        elseif collect_fake
          FakeTag(fake, lnum, byteidx, name)
        endif
      elseif comment
        if name == pats.cend
          comment = false
        elseif collect_fake
          FakeTag(fake, lnum, byteidx, name)
        endif
      elseif name == pats.cstart
        comment = true
      elseif name == 'raw'
        raw = true
        opens += 1
      elseif has_key(open, name)
        opens += 1
      elseif has_key(close, name)
        closes += 1
      endif
    endwhile
    # The joined names let the listener below detect edits that do not change
    # what the line contributes to the fold structure.
    sig[lnum - 1] = join(names, ',')
    if lnum > filled
      levels->extend(repeat([lvl], lnum - filled))
    endif
    var net = opens - closes
    if net > 0
      lvl += net
      # Only the outermost new fold can be marked; a fold opened by a second
      # tag on the same line starts on the next line, where the level rises
      # further.
      levels->add('>' .. (lvl - net + 1))
    elseif net < 0
      # The line with the end tag still belongs to the fold.
      levels->add(lvl > 0 ? '<' .. lvl : 0)
      lvl += net
      if lvl < 0
        lvl = 0
      endif
    else
      # A line opening and closing a block does not start a fold.
      levels->add(lvl)
    endif
    filled = lnum + 1
  endwhile
  if last >= filled
    levels->extend(repeat([lvl], last - filled + 1))
  endif
  cache.tick = b:changedtick
  cache.levels = levels
  cache.tail = lvl
  cache.sig = sig
  cache.fake = fake
  cache.chg_n = 0
  cache.chg_added = 0
  cache.chg_lo = 0
  cache.chg_hi = 0
enddef

# Level in effect just before old line lnum, read from that line's entry: a
# tag-free line holds the level, ">N" starts a fold after a state of N-1, and
# "<N" ends one that was N before the line.
def BeforeLevel(v: any): number
  if type(v) != v:t_string
    return v
  endif
  var n = str2nr(v[1 :])
  return v[0] == '>' ? n - 1 : n
enddef

# Handles the common edit that only moves lines: a single insertion or
# deletion of lines without tags. The levels of the untouched lines shift as
# they are, and the new lines get the level in effect at that point.
def Splice(cache: dict<any>): bool
  var added: number = cache.chg_added
  var old_count = len(cache.levels)
  var last = line('$')
  if last - old_count != added
    return false
  endif
  var old_lo: number = cache.chg_lo
  var old_hi: number = cache.chg_hi
  var new_lo = old_lo
  var new_hi = old_hi + added
  if old_hi >= old_lo
    for ln in range(old_lo, old_hi)
      if get(cache.sig, ln - 1, '') != ''
        return false
      endif
    endfor
  endif
  if new_lo <= new_hi
        && !empty(matchbufline(bufnr(), b:jinja_fold_pats.find, new_lo, new_hi))
    return false
  endif
  # The old lines around the range are unchanged and the range has no tags, so
  # the state entering it equals the state before the line after it; when the
  # range reaches the end of the buffer, the cached tail is that state.
  var carried: number
  if old_hi < old_count
    carried = BeforeLevel(cache.levels[old_hi])
  else
    carried = cache.tail
  endif
  var prefix_len = new_lo - 1
  var mid_len = new_hi - new_lo + 1
  var levels: list<any> = []
  var sig: list<string> = []
  if prefix_len > 0
    levels = cache.levels[0 : prefix_len - 1]
    sig = cache.sig[0 : prefix_len - 1]
  endif
  if mid_len > 0
    levels->extend(repeat([carried], mid_len))
    sig->extend(repeat([''], mid_len))
  endif
  if old_hi < old_count
    levels->extend(cache.levels[old_hi : old_count - 1])
    sig->extend(cache.sig[old_hi : old_count - 1])
  endif
  if added != 0 && !empty(cache.fake)
    var fake: dict<list<number>> = {}
    for [key, pos] in items(cache.fake)
      var ln = str2nr(key)
      if ln < old_lo
        fake[key] = pos
      elseif ln > old_hi
        fake[string(ln + added)] = pos
      endif
    endfor
    cache.fake = fake
  endif
  cache.levels = levels
  cache.sig = sig
  cache.tick = b:changedtick
  cache.chg_n = 0
  cache.chg_added = 0
  cache.chg_lo = 0
  cache.chg_hi = 0
  return true
enddef

# True when the tag names on lines lo..hi are what the cache already has. A
# line that had tags before and has none now is not in seen, so every line of
# the range is compared instead of only the matches.
def SigSame(cache: dict<any>, lo: number, hi: number): bool
  var last = line('$')
  var l = lo < 1 ? 1 : lo
  var h = hi > last ? last : hi
  if l > h
    return true
  endif
  var seen: dict<string> = {}
  for m in matchbufline(bufnr(), b:jinja_fold_pats.find, l, h)
    var key = string(m.lnum)
    if has_key(seen, key)
      seen[key] ..= ',' .. m.text
    else
      seen[key] = m.text
    endif
  endfor
  for ln in range(l, h)
    if get(cache.sig, ln - 1, '') != get(seen, string(ln), '')
      return false
    endif
  endfor
  return true
enddef

# Runs when b:changedtick moved. Only the lines reported by the listener below
# are checked; everything else is trusted to be unchanged.
def Refresh(cache: dict<any>)
  if cache.chg_n == 0
    Build(cache)
  elseif cache.chg_added != 0
    if cache.chg_n != 1 || !Splice(cache)
      Build(cache)
    endif
  elseif len(cache.levels) == line('$')
        && SigSame(cache, cache.chg_lo, cache.chg_hi)
    cache.tick = b:changedtick
    cache.chg_n = 0
    cache.chg_lo = 0
    cache.chg_hi = 0
  else
    Build(cache)
  endif
enddef

def g:JinjaFoldLevel(lnum: number): any
  var cache = b:jinja_fold_cache
  if cache.tick != b:changedtick
    if b:jinja_fold_rebuild != 0
      # Without a listener neither the changed lines nor how many were added
      # are known, so the cache is rebuilt below. A different line count also
      # means Vim shifted the fold tree and may reuse it with the wrong shape:
      # ask FoldFix() to rebuild it on the next autocmd.
      if line('$') != len(cache.levels)
        b:jinja_fold_fix = 1
      endif
    endif
    Refresh(cache)
  endif
  return get(cache.levels, lnum - 1, cache.tail)
enddef

# Unbuffered listener: called for every change, before folds are evaluated. It
# only records where the change is; scanning the buffer here would cost much
# more than keeping the levels and checking the changed lines later.
def g:JinjaFoldListen(buf: number, start: number, e: number, added: number, changes: list<any>)
  var cache = buf == bufnr() ? get(b:, 'jinja_fold_cache', {})
        : getbufvar(buf, 'jinja_fold_cache', {})
  if empty(cache)
    return
  endif
  cache.chg_n += 1
  if cache.chg_n == 1 || start < cache.chg_lo
    cache.chg_lo = start
  endif
  # SigSame() clamps to the buffer it is evaluating, which is not necessarily
  # the one that was changed here.
  if e - 1 > cache.chg_hi
    cache.chg_hi = e - 1
  endif
  if added != 0
    cache.chg_added = added
    if buf != bufnr()
      return
    endif
    # Vim shifts the fold tree by the line count change and may then reuse it
    # with the wrong shape: a nested fold disappeared when an undo restored
    # lines. Switching the method away and back makes Vim re-evaluate all
    # lines from the cached levels; the tree and its open/closed state are
    # kept. This is safe because the listener runs before folds are evaluated.
    if &l:foldmethod ==# 'expr'
      noautocmd setlocal foldmethod=manual
      noautocmd setlocal foldmethod=expr
    endif
  endif
enddef

# vim:set sw=4:
