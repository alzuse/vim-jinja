" Vim syntax file
" Language: Jinja template
" Maintainer: Hsiaoming Yang <lepture@me.com>, Al Z <alzuse@126.com>
" Last Change: Oct 27, 2026

" Delimiters are configurable. Put these in your vimrc before opening a
" Jinja file:
"   let g:jinja_block_start_string    = '<%'
"   let g:jinja_block_end_string      = '%>'
"   let g:jinja_variable_start_string = '<$'
"   let g:jinja_variable_end_string   = '$>'
"   let g:jinja_comment_start_string  = '<#'
"   let g:jinja_comment_end_string    = '#>'

if exists("b:current_syntax")
  " Don't clobber another filetype when this file is included from it. If a
  " jinja syntax was already loaded (Vim 9.2 ships one), take over so the
  " configured delimiters below are actually used. This also runs again when
  " Vim reloads syntax, since b:current_syntax is unlet before each reload.
  if b:current_syntax !=# "jinja"
    finish
  endif
  syntax clear
  unlet! b:current_syntax
endif

let s:delims = jinja#delims()

syntax case match
" Tags and comments may span lines; start sync at the top so a region that
" began above the visible window is still highlighted correctly.
syntax sync fromstart

" jinja template built-in tags and parameters
" 'comment' doesn't appear here because it gets special treatment
syn keyword jinjaStatement contained if else elif endif is not
syn keyword jinjaStatement contained for in recursive endfor
syn keyword jinjaStatement contained raw endraw
syn keyword jinjaStatement contained block endblock extends super scoped
syn keyword jinjaStatement contained macro endmacro call endcall
syn keyword jinjaStatement contained from import as do continue break
syn keyword jinjaStatement contained filter endfilter set endset
syn keyword jinjaStatement contained include ignore missing
syn keyword jinjaStatement contained with without context endwith
syn keyword jinjaStatement contained trans endtrans pluralize
syn keyword jinjaStatement contained autoescape endautoescape

" jinja template built-in tests. Defined before the filters: a few names
" (upper, lower, string) are both, and when they start at the same position
" the item defined last wins. Filters are the common case (|upper).
syn keyword jinjaTest contained callable defined divisibleby escaped
syn keyword jinjaTest contained even iterable lower mapping none number
syn keyword jinjaTest contained odd sameas sequence string undefined upper

" jinja templete built-in filters
syn keyword jinjaFilter contained abs attr batch capitalize center default
syn keyword jinjaFilter contained dictsort escape filesizeformat first
syn keyword jinjaFilter contained float forceescape format groupby indent
syn keyword jinjaFilter contained int join last length list lower pprint
syn keyword jinjaFilter contained random replace reverse round safe slice
syn keyword jinjaFilter contained sort string striptags sum
syn keyword jinjaFilter contained title trim truncate upper urlize
syn keyword jinjaFilter contained wordcount wordwrap
syn keyword jinjaFilter contained pround ds_table
syn keyword jinjaFilter contained xto_1xn xto_1xn_k xto_nxn
syn match jinjaFilter contained /to_[0-9]\+x[0-9]\+/

syn keyword jinjaFunction contained range lipsum dict cycler joiner namespace

" Keywords to highlight within comments
syn keyword jinjaTodo contained TODO FIXME XXX

" jinja template constants (always surrounded by double quotes)
syn region jinjaArgument contained start=/"/ skip=/\\"/ end=/"/
syn region jinjaArgument contained start=/'/ skip=/\\'/ end=/'/
syn keyword jinjaArgument contained true false

" Mark illegal delimiters within tag and variable blocks
let s:tag_error = escape(s:delims.comment_end, '/\') . '\|' .
      \ escape(s:delims.variable_start, '/\') . '\|' .
      \ escape(s:delims.variable_end, '/\')
let s:var_error = escape(s:delims.block_start, '/\') . '\|' .
      \ escape(s:delims.block_end, '/\') . '\|' .
      \ escape(s:delims.comment_end, '/\')
execute 'syn match jinjaTagError contained /\V' . s:tag_error . '/'
execute 'syn match jinjaVarError contained /\V' . s:var_error . '/'

syn cluster jinjaBlocks add=jinjaTagBlock,jinjaVarBlock,jinjaComBlock,jinjaRaw

" jinja template tag and variable blocks
execute 'syn region jinjaTagBlock start=/\V' . escape(s:delims.block_start, '/\') .
      \ '/ end=/\V' . escape(s:delims.block_end, '/\') .
      \ '/ contains=jinjaStatement,jinjaFilter,jinjaFunction,jinjaTest,jinjaArgument,jinjaTagError' .
      \ ' display containedin=ALLBUT,@jinjaBlocks'
execute 'syn region jinjaVarBlock start=/\V' . escape(s:delims.variable_start, '/\') .
      \ '/ end=/\V' . escape(s:delims.variable_end, '/\') .
      \ '/ contains=jinjaStatement,jinjaFilter,jinjaFunction,jinjaTest,jinjaArgument,jinjaVarError' .
      \ ' display containedin=ALLBUT,@jinjaBlocks'
execute 'syn region jinjaComBlock start=/\V' . escape(s:delims.comment_start, '/\') .
      \ '/ end=/\V' . escape(s:delims.comment_end, '/\') .
      \ '/ contains=jinjaTodo display containedin=ALLBUT,@jinjaBlocks'

" The body of {% raw %}...{% endraw %} is plain text. Defined last so it
" wins over the tag block starting at the same position. The delimiters keep
" the tag block highlighting; the body gets no highlight attributes.
let s:raw_open  = escape(s:delims.block_start, '\.*$^~[]/') . '[-+]\?\s*raw\s*[-+]\?' .
      \ escape(s:delims.block_end, '\.*$^~[]/')
let s:raw_close = escape(s:delims.block_start, '\.*$^~[]/') . '[-+]\?\s*endraw\s*[-+]\?' .
      \ escape(s:delims.block_end, '\.*$^~[]/')
execute 'syn region jinjaRaw matchgroup=jinjaTagBlock start=/' . s:raw_open .
      \ '/ end=/' . s:raw_close .
      \ '/ contains=NONE display containedin=ALLBUT,@jinjaBlocks'

" Follow the active colorscheme. Links use "hi def link" so a group can be
" overridden from vimrc, e.g.:
"   hi link jinjaTagBlock MyPreProcGroup
hi def link jinjaTagBlock  PreProc
hi def link jinjaVarBlock  PreProc
hi def link jinjaStatement Statement
hi def link jinjaFunction  Function
hi def link jinjaTest      Type
hi def link jinjaFilter    Identifier
hi def link jinjaArgument  Constant
hi def link jinjaTagError  Error
hi def link jinjaVarError  Error
hi def link jinjaComBlock  Comment
hi def link jinjaTodo      Todo

let b:current_syntax = "jinja"
