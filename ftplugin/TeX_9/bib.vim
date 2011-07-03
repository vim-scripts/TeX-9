" LaTeX filetype plugin: BibTeX settings
" Language:     BibTeX (ft=bib)
" Maintainer:   Elias Toivanen
" Version:	1.1.5
" Last Change:	July 3, 2011
" Licence:      GPL

" ******************************************
"               Variables
" ******************************************
setl tw=0 sts=2 sw=2 tabstop=8

" Interactive snippet insertion
inoremap <buffer><expr> <LocalLeader>B tex_nine#InsertEnvironment()
" Update database
noremap <buffer><silent> <LocalLeader>U :call tex_nine#SetupBibTeX('update')<CR>

noremap <buffer><silent> <C-B> ?^@<CR>
noremap <buffer><silent> <C-F> /^@<CR>
