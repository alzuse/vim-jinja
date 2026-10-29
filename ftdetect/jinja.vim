" Language: Jinja template
" Maintainer: Al Z <alzuse@126.com>
" Last Change: Oct 27, 2026
"
augroup jinja_ftdetect
  autocmd!
  " "set ft" instead of "setfiletype": files starting with "<%" are
  " content-detected as Mason by Vim, and that must not win for .jinja files.
  autocmd BufNewFile,BufRead *.jinja2,*.j2,*.jinja,*.tmpl,*.tpl set ft=jinja
  autocmd BufNewFile,BufRead *.jpp set ft=python
augroup END
