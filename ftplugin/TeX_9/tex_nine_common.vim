" LaTeX filetype plugin: Common settings
" Language:     LaTeX (ft=tex), BibTeX (ft=bib)
" Maintainer:   Elias Toivanen
" Version:	1.2beta
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

let s:path = fnameescape(expand('<sfile>:h'))
let b:tex_skeleton = fnameescape(s:path.'/skeleton/tex_skeleton.tex')
let b:tex_pymodules = fnameescape(s:path.'/pymodules')
let b:tex_snippets = fnameescape(s:path.'/snippets/tex_snippets.snippets')
let b:bib_snippets = fnameescape(s:path.'/snippets/bib_snippets.snippets')
let &dictionary = fnameescape(s:path.'/dictionaries/tex_dictionary.txt')

if !exists("*DefineTeXNine")
function DefineTeXNine()

    exe "pyfile" fnameescape(b:tex_pymodules.'/tex_nine_module.py')

    if exists('g:tex_synctex') && g:tex_synctex == 1
       if !has('python3') 
           python logging.debug("TeX 9: Importing tex_nine_synctex") 
           " Important side effect: Vim will be hooked to the DBus session daemon
           python import tex_nine_synctex
       else
           echoerr "TeX 9 Error: Must not have +python3 when using SyncTeX"
       endif
    endif
endfunction
call DefineTeXNine()
endif

" Change to your taste
if !exists('maplocalleader')
    let maplocalleader = ";"
endif
