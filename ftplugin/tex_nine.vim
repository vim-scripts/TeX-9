" LaTeX filetype plugin: common settings
" Languages:    LaTeX, BibTeX
" Maintainer:   Elias Toivanen
" Version:      1.1.5
" Last Change:  July 3, 2011
" License:      GPL

if !has('python') || !has('syntax')
    echoerr "Error: TeX 9 requires Vim compiled with +python and +syntax"
    finish
endif

if !has('gui_running')
    echoerr "Warning: TeX 9 is not meant to be used in console..."
endif

" ******************************************
"           Load clips once
" ******************************************
if exists('b:init_tex_nine') | finish | endif
let b:init_tex_nine = 1

" ******************************************
"              Cock it
" ******************************************
let s:path = fnameescape(expand('<sfile>:h') . '/TeX_9')
let &dictionary=fnameescape(s:path . '/dictionaries' . '/tex_dictionary.txt')

" Edit this to change the prefix to TeX 9 mappings
let maplocalleader = ";"

" ******************************************
"               Spray
" ******************************************
if &ft == 'tex'
    let b:skeleton = fnameescape(s:path . '/skeleton' . '/tex_skeleton.tex')
    let b:pymodules = fnameescape(s:path . '/pymodules')
    let s:snipfile = fnameescape(s:path . '/snippets' . '/tex_snippets.snippets')
    ru ftplugin/TeX_9/tex.vim

elseif &ft == 'bib'
    let s:snipfile = fnameescape(s:path . '/snippets' . '/bib_snippets.snippets')
    ru ftplugin/TeX_9/bib.vim

endif

call tex_nine#SetupSnippets(s:snipfile)
unlet s:path

