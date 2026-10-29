" Language: Jinja template
" Maintainer: Al Z <alzuse@126.com>
" Last Change: Oct 27, 2026
"
augroup jinja_ftdetect
  autocmd!
  " "set ft" instead of "setfiletype": files starting with "<%" are
  " content-detected as Mason by Vim, and that must not win for .jinja files.
  " The test avoids a second FileType event when Vim already detected Jinja:
  " every event makes the ftplugin machinery run b:undo_ftplugin and source
  " the filetype plugin again, which would throw away a fold cache built for
  " the first event.
  autocmd BufNewFile,BufRead *.jinja2,*.j2,*.jinja,*.tmpl,*.tpl
        \ if &filetype !=# 'jinja' | set ft=jinja | endif
  autocmd BufNewFile,BufRead *.jpp set ft=python
augroup END
