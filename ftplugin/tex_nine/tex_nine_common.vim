" LaTeX filetype plugin: Common settings
" Language:     LaTeX (ft=tex), BibTeX (ft=bib)
" Maintainer:   Elias Toivanen
" Version:	1.3.1
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
"    Copyright Elias Toivanen, 2011, 2012, 2013
"************************************************************************

let s:path = fnameescape(expand('<sfile>:h'))
let b:tex_nine_skeleton = fnameescape(s:path.'/skeleton/tex_skeleton.tex')
let b:tex_nine_snippets = fnameescape(s:path.'/snippets/tex_snippets.snippets')
let b:bib_nine_snippets = fnameescape(s:path.'/snippets/bib_snippets.snippets')
let &dictionary = fnameescape(s:path.'/tex_dictionary.txt')

" Defaults
let b:tex_nine_config = { 
            \    'compiler' : '', 
            \    'verbose' : 0, 
            \    'leader' : '', 
            \    'viewer' : {'app': 'xdg-open', 'target': 'pdf'}, 
            \    'disable' : 0, 
            \    'debug': 0,
            \    'synctex' : 0
            \}

" Override values with user preferences
if exists('g:tex_nine_config')
    call extend(b:tex_nine_config, g:tex_nine_config)
    "unlet g:tex_nine_config
endif

" Configure the leader
if b:tex_nine_config.leader == ''
    if exists('g:maplocalleader')
        let b:tex_nine_config.leader = g:maplocalleader
    elseif exists('g:mapleader')
        let b:tex_nine_config.leader = g:mapleader
    else
        let b:tex_nine_config.leader = ';'
    endif
endif

" Define Python environment once per Vim session
if !exists('g:tex_nine_did_python') 
    let g:tex_nine_did_python = 1
    let b:tex_nine_config._pypath = s:path
    exe "pyfile" fnameescape(b:tex_nine_config._pypath.'/__init__.py')
endif
