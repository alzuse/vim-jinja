" Vim filetype plugin

if exists('b:did_ftplugin')
  finish
endif


setlocal comments=s:<#,ex:#> commentstring=<#%s#>
setlocal formatoptions+=tcqln

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= '|setl cms< com< fo<'
else
  let b:undo_ftplugin = 'setl cms< com< fo<'
endif

" Setup matchit.
if exists('loaded_matchit')
  let b:match_ignorecase = 1
  let b:match_skip = 's:Comment'
  " From ftplugin/html.vim, plus block tag matching.
  " With block tags the following is optional:
  "   - "+": disable the lstrip_blocks (only at start)
  "   - "-": the whitespaces before or after that block will be removed
  let b:match_words = '<:>,' .
        \ '<%[-+]\?\s*if\s*\w\+\>.\{-}%>:<%[-+]\?\s*elif\s*\w\+\>.\{-}%>:<%-\?\s*else\s*%>:<%-\?\s*endif\s*%>,' .
        \ '<%[-+]\?\s*\%(end\)\@!\(\w\+\)\>.\{-}%>:<%-\?\s*end\1\>.\{-}%>,' .
        \ ''
endif

" vim:set sw=4:
