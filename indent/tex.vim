" Vim indent file
" Language:     LaTeX
" Maintainer:   Johannes Tanzler <jtanzler@yline.com>
" Created:      Sat, 16 Feb 2002 16:50:19 +0100
" Last Change:	Sun, 17 Feb 2002 00:09:11 +0100
" Last Update:  Oct 3, 2011
"               ET: Modified this script for TeX 9. Items are indented
"               automatically.
" Version: 0.02

if exists("b:did_indent") | finish
endif
let b:did_indent = 1

setlocal indentexpr=GetTeXIndent()
setlocal nolisp
setlocal nosmartindent
setlocal autoindent
setlocal indentkeys+=},=\\item,=\\bibitem

" Only define the function once
if exists("*GetTeXIndent") | finish
endif

function GetTeXIndent()

    " Find a non-blank line above the current line.
    let lnum = prevnonblank(v:lnum - 1)

    " At the start of the file use zero indent.
    if lnum == 0 | return 0 
    endif

    let ind = indent(lnum)
    let line = getline(lnum)             " first line in the current range
    let cline = getline(v:lnum)          " current line

    if line =~ '^\s*%'
        return ind " Do not change indentation of commented lines.
    endif

    let openingpat = '\\\(begin\|section\*\=\|paragraph\*\=\){\(.*\)}'  
    let endpat = '\\\(end\|section\*\=\|paragraph\*\=\){\(.*\)}'
    let excluded = 'document\|verbatim'

    " Add/remove a 'shiftwidth' after an environment begins/ends.
    " Add an additional 'shiftwidth' when entering a list and when typing in
    " an item of a list. 
    if line =~ openingpat && line !~ excluded
        let ind += &sw

        " Add another sw for item-environments
        if line =~ 'itemize\|description\|enumerate\|thebibliography'
            let ind += &sw
        endif
    endif

    " Subtract a 'shiftwidth' when an environment ends
    if cline =~ endpat && cline !~ excluded
        let ind -= &sw
        " Remove another sw for item-environments
        if cline =~ 'itemize\|description\|enumerate\|thebibliography' 
            let ind -= &sw
        endif
    endif

    " Special treatment for 'item'
    if cline =~ '^\s*\\\(bib\)\=item' 
        let ind -= &sw
    endif

    if line =~ '^\s*\\\(bib\)\=item' 
        let ind += &sw
    endif

    return ind
endfunction

" vim: fdm=marker
