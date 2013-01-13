" LaTeX filetype plugin: BibTeX settings
" Language:     BibTeX (ft=bib)
" Maintainer:   Elias Toivanen
" Version:	1.2.1
" Last Change:	
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
"    Copyright Elias Toivanen, 2012
"************************************************************************

" Paths & Python environment
ru ftplugin/TeX_9/tex_nine_common.vim

" ******************************************
"               Variables
" ******************************************
setlocal tw=0
setlocal sts=2
setlocal sw=2
setlocal tabstop=8

if !exists('g:tex_bibfiles')
    let g:tex_bibfiles = []
endif

python << EOF
document = TeXNineDocument(vim.current.buffer)
document.setup_snippets(vim.eval('b:bib_snippets'),
                        vim.eval('&ft'))
EOF

inoremap <buffer><expr> <LocalLeader>B tex_nine#Insert_snippet()
noremap <buffer><silent> <LocalLeader>U :call tex_nine#Setup_omni(g:tex_bibfiles, 1)<CR>

"noremap <buffer><silent> <C-B> ?^@<CR>
"noremap <buffer><silent> <C-F> /^@<CR>
