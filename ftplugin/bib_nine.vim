" LaTeX filetype plugin: BibTeX settings
" Language:     BibTeX (ft=bib)
" Maintainer:   Elias Toivanen
" Version:	1.1.6
" Last Change:	Tue 13 Dec 2011 
" Licence:      GPL

"************************************************************************
"
"    This program is free software: you can redistribute it and/or modify
"    it under the terms of the GNU General Public License as published by
"    the Free Software Foundation, either version 3 of the License, or
"    (at your option) any later version.
"
"    This program is distributed in the hope that it will be useful,
"    but WITHOUT ANY WARRANTY; without even the implied warranty of
"    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"    GNU General Public License for more details.
"
"    You should have received a copy of the GNU General Public License
"    along with this program. If not, see <http://www.gnu.org/licenses/>.
"                    
"    Copyright Elias Toivanen, 2011
"************************************************************************

" ******************************************
"                 Paths
" ******************************************
let s:path = fnameescape(expand('<sfile>:h').'/TeX_9')
let s:bib_snippets = fnameescape(s:path.'/snippets/bib_snippets.snippets')

exe 'source' s:path.'/tex_nine_common.vim'

" ******************************************
"               Variables
" ******************************************
setlocal tw=0
setlocal sts=2
setlocal sw=2
setlocal tabstop=8
let &dictionary = fnameescape(s:path.'/dictionaries/tex_dictionary.txt')

if !exists('g:tex_bibfiles')
    let g:tex_bibfiles = []
endif

call tex_nine#Add_buffer()
call tex_nine#Setup_snippets(s:bib_snippets)

inoremap <buffer><expr> <LocalLeader>B tex_nine#Insert_snippet()
noremap <buffer><silent> <LocalLeader>U :call tex_nine#Setup_omni(g:tex_bibfiles, 1)<CR>

"noremap <buffer><silent> <C-B> ?^@<CR>
"noremap <buffer><silent> <C-F> /^@<CR>
