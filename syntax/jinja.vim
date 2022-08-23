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
" Jinja template built-in tags and parameters (without filter, macro, is and raw, they
" have special threatment)
syn keyword jinjaStatement containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained and if else in not or recursive as import

syn keyword jinjaStatement containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained is filter skipwhite nextgroup=jinjaFilter
syn keyword jinjaStatement containedin=jinjaTagBlock contained macro skipwhite nextgroup=jinjaFunction
syn keyword jinjaStatement containedin=jinjaTagBlock contained block skipwhite nextgroup=jinjaBlockName

" Variable Names
syn match jinjaVariable containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained /[a-zA-Z_][a-zA-Z0-9_]*/
syn keyword jinjaSpecial containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained false true none False True None loop super caller varargs kwargs

" Filters
syn match jinjaOperator "|" containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained skipwhite nextgroup=jinjaFilter
syn match jinjaFilter contained /[a-zA-Z_][a-zA-Z0-9_]*/
syn match jinjaFunction contained /[a-zA-Z_][a-zA-Z0-9_]*/
syn match jinjaBlockName contained /[a-zA-Z_][a-zA-Z0-9_]*/

" Jinja template constants
syn region jinjaString containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained start=/"/ skip=/\(\\\)\@<!\(\(\\\\\)\@>\)*\\"/ end=/"/
syn region jinjaString containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained start=/'/ skip=/\(\\\)\@<!\(\(\\\\\)\@>\)*\\'/ end=/'/
syn match jinjaNumber containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained /[0-9]\+\(\.[0-9]\+\)\?/

" Operators
syn match jinjaOperator containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained /[+\-*\/<>=!,:]/
syn match jinjaPunctuation containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained /[()\[\]]/
syn match jinjaOperator containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained /\./ nextgroup=jinjaAttribute
syn match jinjaAttribute contained /[a-zA-Z_][a-zA-Z0-9_]*/

" Jinja template tag and variable blocks
syn region jinjaNested matchgroup=jinjaOperator start="(" end=")" transparent display containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained
syn region jinjaNested matchgroup=jinjaOperator start="\[" end="\]" transparent display containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained
syn region jinjaNested matchgroup=jinjaOperator start="{" end="}" transparent display containedin=jinjaVarBlock,jinjaTagBlock,jinjaNested contained
syn region jinjaTagBlock matchgroup=jinjaTagDelim start=/<%[-+]\?/ end=/[-+]\?%>/ containedin=ALLBUT,jinjaTagBlock,jinjaVarBlock,jinjaRaw,jinjaString,jinjaNested,jinjaComment

syn region jinjaVarBlock matchgroup=jinjaVarDelim start=/<$-\?/ end=/-\?$>/ containedin=ALLBUT,jinjaTagBlock,jinjaVarBlock,jinjaRaw,jinjaString,jinjaNested,jinjaComment

" Jinja template 'raw' tag
syn region jinjaRaw matchgroup=jinjaRawDelim start="<%\s*raw\s*%>" end="<%\s*endraw\s*%>" containedin=ALLBUT,jinjaTagBlock,jinjaVarBlock,jinjaString,jinjaComment

" Jinja comments
syn region jinjaComment matchgroup=jinjaCommentDelim start="<#" end="#>" containedin=ALLBUT,jinjaTagBlock,jinjaVarBlock,jinjaString,jinjaComment

" Block start keywords.  A bit tricker.  We only highlight at the start of a
" tag block and only if the name is not followed by a comma or equals sign
" which usually means that we have to deal with an assignment.
syn match jinjaStatement containedin=jinjaTagBlock contained /\(<%[-+]\?\s*\)\@<=\<[a-zA-Z_][a-zA-Z0-9_]*\>\(\s*[,=]\)\@!/

" and context modifiers
syn match jinjaStatement containedin=jinjaTagBlock contained /\<with\(out\)\?\s\+context\>/



hi def link jinjaPunctuation jinjaOperator
hi def link jinjaAttribute jinjaVariable
hi def link jinjaFunction jinjaFilter
hi def link jinjaTagDelim jinjaTagBlock
hi def link jinjaVarDelim jinjaVarBlock
hi def link jinjaCommentDelim jinjaComment
hi def link jinjaRawDelim jinja
hi def link jinjaSpecial Special
hi def link jinjaOperator Normal
hi def link jinjaRaw Normal
hi def link jinjaTagBlock PreProc
hi def link jinjaVarBlock PreProc
hi def link jinjaStatement Statement
hi def link jinjaFilter Function
hi def link jinjaBlockName Function
hi def link jinjaVariable Identifier
hi def link jinjaString Constant
hi def link jinjaNumber Constant
hi def link jinjaComment Comment



" jinja 'fold' definition

" fold for loops
syn region jinjaFoldFor
      \ start="<%[+-]\? *\<for\>"
      \ end="<%[+-]\? *endfor *%>"
      \ transparent fold
      \ keepend extend
      \ skip=+"\%(\\"\|[^"]\)\{-}\%("\|$\)\|'[^']\{-}'+ "comment to fix highlight on wiki'

" fold if...else...endif constructs
"
syn region jinjaFoldIfContainer
      \ start="<%[+-]\? *\<if\>"
      \ end="<%[+-]\? *endif *%>"
      \ transparent
      \ keepend extend
      \ contains=NONE
      \ skip=+"\%(\\"\|[^"]\)\{-}\%("\|$\)\|'[^']\{-}'+ "comment to fix highlight on wiki'

syn region jinjaFoldIf
      \ start="<%[+-]\? *\<if\>"
      \ end="^<%[+-]\?\s*\\\?\s*elif\>"ms=s-1,me=s-1
      \ fold transparent
      \ keepend
      \ contained containedin=jinjaFoldIfContainer
      \ nextgroup=jinjaFoldElseIf,jinjaFoldElse
      \ contains=TOP
      \ skip=+"\%(\\"\|[^"]\)\{-}\%("\|$\)\|'[^']\{-}'+ "comment to fix highlight on wiki'

syn region jinjaFoldElseIf
      \ start="<%[+-]\?\s*\<elif\>"
      \ end="^<%[+-]\?\s*\\\?\s*elif\>"ms=s-1,me=s-1
      \ fold transparent
      \ keepend
      \ contained containedin=jinjaFoldIfContainer
      \ nextgroup=jinjaFoldElseIf,jinjaFoldElse
      \ contains=TOP
      \ skip=+"\%(\\"\|[^"]\)\{-}\%("\|$\)\|'[^']\{-}'+ "comment to fix highlight on wiki'
syn region jinjaFoldElse
      \ start="<%[+-]\?\s*\<else\>"
      \ end="<%[+-]\?\s*\<endif\>"
      \ fold transparent
      \ keepend
      \ contained containedin=jinjaFoldIfContainer
      \ contains=TOP
      \ skip=+"\%(\\"\|[^"]\)\{-}\%("\|$\)\|'[^']\{-}'+ "comment to fix highlight on wiki'





let b:current_syntax = "jinja"



