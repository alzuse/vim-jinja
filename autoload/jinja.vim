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

" vim:set sw=4:
