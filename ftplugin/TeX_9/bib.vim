" LaTeX filetype plugin: BibTeX settings
" Language:     BibTeX (ft=bib)
" Maintainer:   Elias Toivanen
" Version:	1.2
" Last Change:	Jan 16, 2011
" Lisence:      Public Domain

" ******************************************
"               Variables
" ******************************************
setl tw=0 sts=2 sw=2 tabstop=8

" Interactive snippet insertion
inoremap <buffer><expr> <LocalLeader>B tex_nine#InsertEnvironment()

noremap <buffer><silent> <C-B> ?^@<CR>
noremap <buffer><silent> <C-F> /^@<CR>
