" LaTeX filetype plugin
" Languages:    LaTeX
" Maintainer:   Elias Toivanen
" Version:      1.2.1
" Last Change:  
" License:      GPL

" LICENCE DISCLAIMER {{{1
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
"*********************************************************************}}}

if !has('python') 
    echoerr "TeX 9 Error: a Vim installation with +python is required"
    finish
endif

if exists('b:init_tex_nine')
    finish
endif
let b:init_tex_nine = 1

" Paths & Python environment
ru ftplugin/TeX_9/tex_nine_common.vim

" Local settings & autocmds {{{1
setlocal completeopt=longest,menuone 
setlocal fo=tcq
setlocal tw=72 sw=2
setlocal tabstop=8 
setlocal notimeout 
"setlocal whichwrap=b,s " For matching inline maths
setlocal omnifunc=tex_nine#Omni_completion

augroup tex_nine
    au BufWritePre *.tex call tex_nine#Update_header()
    au QuickFixCmdPre <buffer> call tex_nine#Premake()
    au QuickFixCmdPost <buffer> call tex_nine#Postmake()
augroup END
" }}}

" User preferences {{{1

if exists('g:tex_verbose') && g:tex_verbose == 1
    au! tex_nine QuickFixCmdPost 
    function! PostMake()
        if (!has("gui_running"))
            redraw!
        endif
        lcd -
        let numerrors = len(filter(getqflist(), 'v:val.valid==1'))
        unsilent echo "Found ".numerrors." Error(s)."
    endfunction
    au QuickFixCmdPost <buffer> call PostMake()
endif

if exists('g:tex_flavor')
    compiler tex_nine
    noremap <buffer><silent> <LocalLeader>k :call tex_nine#Quickcompile()<CR>
    noremap <buffer><silent> <LocalLeader>K :call tex_nine#Deepcompile()<CR>
else
    echoerr "LaTeX compiler not set: please define `g:tex_flavor' in .vimrc."
    finish
endif

if !exists('g:tex_viewer')
    let g:tex_viewer = {'app': 'xdg-open', 'target': 'pdf'}
endif

if !exists('g:tex_bibfiles')
    let g:tex_bibfiles = []
endif

python << EOF
omni = TeXNineOmni(vim.eval('g:tex_bibfiles'))
document = TeXNineDocument(vim.current.buffer,
                           compiler=vim.eval('g:tex_flavor'),
                           viewer=vim.eval('g:tex_viewer'))
document.setup_snippets(vim.eval('b:tex_snippets'),
                        vim.eval('&ft'))
EOF

if exists('g:tex_synctex') && g:tex_synctex == 1
   if !has('python3') 
python << EOF
target = document.viewer['target']
evince_proxy = tex_nine_synctex.TeXNineSyncTeX(vim.current, target) 
document.set_forward_search(vim.current.buffer, evince_proxy)
EOF
    noremap <buffer><silent> <C-LeftMouse> :call tex_nine#Forward_search()<CR>
   endif
endif

"}}}

" Mappings {{{1
" ******************************************
"          Normal mode mappings
" ******************************************
noremap <buffer><silent> <F1> :call tex_nine#Insert_skeleton(b:tex_skeleton)<CR>
noremap <buffer><silent> <LocalLeader>V :call tex_nine#View_document()<CR>
noremap <buffer><silent> <LocalLeader>U :call tex_nine#Setup_omni(g:tex_bibfiles, 1)<CR>
noremap <buffer><silent> <LocalLeader>Q :copen<CR>
noremap <buffer><silent> <C-B> ?\\begin\\|\\end<CR>
noremap <buffer><silent> <C-F> /\\end\\|\\begin<CR>
noremap <buffer><silent> gd yiB/\\label{<C-R>0}<CR>
noremap <buffer><silent> gb :call tex_nine#Bibquery(expand('<cword>'))<CR>


" ******************************************
"          Insert mode mappings
" ******************************************

inoremap <buffer> <LocalLeader><LocalLeader> <LocalLeader>
inoremap <buffer> <LocalLeader>K 
inoremap <buffer> <LocalLeader>M \
inoremap <buffer><expr> <LocalLeader>B tex_nine#Insert_snippet()
imap <buffer><expr> <LocalLeader>R tex_nine#Smart_insert('\ref{')
imap <buffer><expr> <LocalLeader>C tex_nine#Smart_insert('\cite{', '\[cC]ite')

" Greek
inoremap <buffer> <LocalLeader>a \alpha
inoremap <buffer> <LocalLeader>b \beta
inoremap <buffer> <LocalLeader>c \chi
inoremap <buffer> <LocalLeader>d \delta
inoremap <buffer> <LocalLeader>e \epsilon
inoremap <buffer> <LocalLeader>f \phi
inoremap <buffer> <LocalLeader>g \gamma
inoremap <buffer> <LocalLeader>h \eta
inoremap <buffer> <LocalLeader>k \kappa
inoremap <buffer> <LocalLeader>l \lambda
inoremap <buffer> <LocalLeader>m \mu
inoremap <buffer> <LocalLeader>n \nu
inoremap <buffer> <LocalLeader>o \omega
inoremap <buffer> <LocalLeader>p \pi
inoremap <buffer> <LocalLeader>q \theta
inoremap <buffer> <LocalLeader>r \rho
inoremap <buffer> <LocalLeader>s \sigma
inoremap <buffer> <LocalLeader>t \tau
inoremap <buffer> <LocalLeader>u \upsilon
inoremap <buffer> <LocalLeader>w \varpi
inoremap <buffer> <LocalLeader>x \xi
inoremap <buffer> <LocalLeader>y \psi
inoremap <buffer> <LocalLeader>z \zeta
inoremap <buffer> <LocalLeader>D \Delta
inoremap <buffer> <LocalLeader>F \Phi
inoremap <buffer> <LocalLeader>G \Gamma
inoremap <buffer> <LocalLeader>L \Lambda
inoremap <buffer> <LocalLeader>O \Omega
inoremap <buffer> <LocalLeader>P \Pi
inoremap <buffer> <LocalLeader>Q \Theta
inoremap <buffer> <LocalLeader>U \Upsilon
inoremap <buffer> <LocalLeader>X \Xi
inoremap <buffer> <LocalLeader>Y \Psi

" Math
inoremap <buffer> <LocalLeader>½ \sqrt{}<Left>
inoremap <buffer> <LocalLeader>N \nabla
inoremap <buffer> <LocalLeader>S \sum_{}^{}<Esc>F}i
inoremap <buffer> <LocalLeader>I \int\limits_{}^{}<Esc>F}i
inoremap <buffer> <LocalLeader>0 \emptyset
inoremap <buffer> <LocalLeader>6 \partial
inoremap <buffer> <LocalLeader>i \infty
inoremap <buffer> <LocalLeader>/ \frac{}{}<Esc>F}i
inoremap <buffer> <LocalLeader>v \vee
inoremap <buffer> <LocalLeader>& \wedge
inoremap <buffer> <LocalLeader>@ \circ
inoremap <buffer> <LocalLeader>\ \setminus
inoremap <buffer> <LocalLeader>= \equiv
inoremap <buffer> <LocalLeader>- \bigcap
inoremap <buffer> <LocalLeader>+ \bigcup
inoremap <buffer> <LocalLeader>< \leq
inoremap <buffer> <LocalLeader>> \geq
inoremap <buffer> <LocalLeader>~ \tilde{}<Left>
inoremap <buffer> <LocalLeader>^ \hat{}<Left>
inoremap <buffer> <LocalLeader>_ \bar{}<Left>
inoremap <buffer> <LocalLeader>. \dot{}<Left>
inoremap <buffer> <LocalLeader><CR> \nonumber\\<CR>

" Enlarged delimiters
inoremap <buffer> <LocalLeader>( \left(\right)<Esc>F(a
inoremap <buffer> <LocalLeader>[ \left[\right]<Esc>F[a
inoremap <buffer> <LocalLeader>{ \left\{ \right\}<Esc>F a

" Neat insertion of various LaTeX constructs by tapping keys
inoremap <buffer><expr> _ tex_nine#IsLeft('_') ? '{}<Left>' : '_'
inoremap <buffer><expr> ^ tex_nine#IsLeft('^') ? '{}<Left>' : '^'
inoremap <buffer><expr> = tex_nine#IsLeft('=') ? '<BS>&=' : '='
inoremap <buffer><expr> ~ tex_nine#IsLeft('~') ? '<BS>\approx' : '~'

" Robust inner/outer environment operators
vmap <buffer><expr> ae tex_nine#Environment_operator('outer')
omap <buffer><silent> ae :normal vae<CR>
vmap <buffer><expr> ie tex_nine#Environment_operator('inner')
omap <buffer><silent> ie :normal vie<CR>

" }}}

"let b:tex_cwd = fnameescape(getcwd())

" vim: ft=vim fdm=marker
