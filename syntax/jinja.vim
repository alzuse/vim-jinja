" jinja syntax file
" Language: Jinja HTML template
" Maintainer: Hsiaoming Yang <lepture@me.com>, Al Z <alzuse@126.com>
" Last Change: Oct 23, 2022

" only support 6.x+

if exists("b:current_syntax")
  finish
endif


let g:jinja_block_start_string = get(g:, "jinja_block_start_string", "<%")
let g:jinja_block_end_string   = get(g:, "jinja_block_end_string", "%>")
let g:jinja_variable_start_string = get(g:, "jinja_variable_start_string", "<$")
let g:jinja_variable_end_string   = get(g:, "jinja_variable_end_string", "$>")
let g:jinja_comment_start_string = get(g:, "jinja_comment_start_string", "<#")
let g:jinja_comment_end_string   = get(g:, "jinja_comment_end_string", "#>")

syntax case match

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

" jinja template built-in tests
syn keyword jinjaTest contained callable defined divisibleby escaped
syn keyword jinjaTest contained even iterable lower mapping none number
syn keyword jinjaTest contained odd sameas sequence string undefined upper

syn keyword jinjaFunction contained range lipsum dict cycler joiner


" Keywords to highlight within comments
syn keyword jinjaTodo contained TODO FIXME XXX

" jinja template constants (always surrounded by double quotes)
syn region jinjaArgument contained start=/"/ skip=/\\"/ end=/"/
syn region jinjaArgument contained start=/'/ skip=/\\'/ end=/'/
syn keyword jinjaArgument contained true false

" Mark illegal characters within tag and variables blocks
syn match jinjaTagError contained "#>\|<\$\|[^%]\$>\|[&#]"
syn match jinjaVarError contained "#>\|<%\|%>\|[!&#]"
syn cluster jinjaBlocks add=jinjaTagBlock,jinjaVarBlock,jinjaComBlock,jinjaComment

" jinja template tag and variable blocks
syn region jinjaTagBlock start="<%" end="%>" contains=jinjaStatement,jinjaFilter,jinjaArgument,jinjaFilter,jinjaTest,jinjaTagError display containedin=ALLBUT,@jinjaBlocks
syn region jinjaVarBlock start="<\$" end="\$>" contains=jinjaFilter,jinjaArgument,jinjaVarError display containedin=ALLBUT,@jinjaBlocks
syn region jinjaComBlock start="<#" end="#>" contains=jinjaTodo containedin=ALLBUT,@jinjaBlocks


" syn cluster jinjaTmpl remove=jinjaTagBlock,jinjaVarBlock,jinjaComBlock,jinjaComment

syn region jinjaTmpl start="." end="." skip="<%\|\$\|#.{-}%\|\$\|#>"

""@  hi def link jinjaTagBlock PreProc
""@  hi def link jinjaVarBlock PreProc
""@  hi def link jinjaStatement Statement
""@  hi def link jinjaFunction Function
""@  hi def link jinjaTest Type
""@  hi def link jinjaFilter Identifier
""@  hi def link jinjaArgument Constant
""@  hi def link jinjaTagError Error
""@  hi def link jinjaVarError Error
""@  hi def link jinjaError Error
""@  hi def link jinjaComment Comment
""@  hi def link jinjaComBlock Comment
""@  hi def link jinjaTodo Todo

colo elflord

hi CJinjaToken   guifg=#00C0FF gui=NONE cterm=NONE
hi CJinjaKeyword guifg=#FFFF00 gui=NONE cterm=NONE
hi CJinjaFunc    guifg=#5CCEC0 gui=NONE cterm=NONE
hi CJinjaComment guifg=#808080 gui=NONE cterm=NONE


hi def link jinjaTagBlock  CJinjaToken
hi def link jinjaVarBlock  CJinjaToken
hi def link jinjaStatement CJinjaKeyword
hi def link jinjaFunction  CJinjaFunc
hi def link jinjaTest      CJinjaFunc
hi def link jinjaFilter    CJinjaFunc
hi def link jinjaArgument  CJinjaToken
hi def link jinjaTagError  Error
hi def link jinjaVarError  Error
hi def link jinjaError     Error
hi def link jinjaComment   CJinjaComment
hi def link jinjaComBlock  CJinjaComment
hi def link jinjaTodo      Todo



" hi jinjaTmpl ctermbg=Cyan guibg=Pink cterm=bold gui=bold
" hi jinjaTmpl  cterm=bold gui=bold guibg=#CEFFD7
hi jinjaTmpl  cterm=bold gui=bold guifg=#FFFFFF


function! JinjaFold()
    " Get the line for which Vim wants to know the folding level
    let l:line = getline(v:lnum)

    " <% for xxx ... %>, fold level add 1
    if l:line =~ '<%[-+]\?\s*for'
        return 'a1'
    endif
    if l:line =~ '<%[-+]\?\s*endfor'
        return 's1'
    endif

    " <% if xxx %>, fold level add 1
    if l:line =~ '<%[-+]\?\s*if'
        return 'a1'
    endif
    if l:line =~ '<%[-+]\?\s*endif'
        return 's1'
    endif

    " <% macro ... %> fold level add 1
    if l:line =~ '<%[-+]\?\s*macro'
        return 'a1'
    endif
    if l:line =~ '<%[-+]\?\s*endmacro'
        return 's1'
    endif

    " <% block ... %> fold level add 1
    if l:line =~ '<%[-+]\?\s*block'
        return 'a1'
    endif
    if l:line =~ '<%[-+]\?\s*endblock'
        return 's1'
    endif


    " use the foldlevel of the previous line
    return '='
endfunction

setlocal fdm=expr
setlocal foldexpr=JinjaFold()

let b:current_syntax = "jinja"

