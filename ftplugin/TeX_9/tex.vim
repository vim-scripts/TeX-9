" LaTeX filetype plugin: LaTeX settings
" Language:     LaTeX (ft=tex)
" Maintainer:   Elias Toivanen
" Version:	1.1.5
" Last Change:	July 3, 2011
" Licence:      GPL

" ******************************************
"               Settings
" ******************************************
setl completeopt=longest,menuone tw=66 sw=2 
setl fo=tcq
setl tabstop=8 notimeout omnifunc=tex_nine#TexComplete
let b:tex_cwd = fnameescape(getcwd())

" ******************************************
"             Autocommands
" ******************************************
augroup tex_nine
au BufWritePre *.tex call tex_nine#UpdateWithLastMod()
au CursorHoldI *.tex python cycler.pos = None
au QuickFixCmdPre make lcd %:h
au QuickFixCmdPost make call tex_nine#PostProcess(b:tex_cwd)
augroup END

" ******************************************
"           User preferences
" ******************************************
if exists('g:tex_verbose') && g:tex_verbose == 1
    au! tex_nine QuickFixCmdPost make 
    au QuickFixCmdPost make exe 'lcd '.b:tex_cwd
endif

if exists('g:tex_flavor')
    compiler tex_nine
    noremap <buffer><silent> <LocalLeader>k :call tex_nine#QuickCompile()<CR>
    noremap <buffer><silent> <LocalLeader>K :call tex_nine#DeepCompile()<CR>
endif

if !exists('g:tex_viewer')
    let g:tex_viewer = {'app': 'xdg-open', 'target': 'pdf'}
endif

function! s:ViewDocument()
    exe "!".g:tex_viewer.app.' '.fnameescape(expand('%<')).'.'.g:tex_viewer.target.' &'
endfunction

noremap <buffer> <LocalLeader>V :call <SID>ViewDocument()<CR><Space>

if exists('g:tex_bibfiles') && type(g:tex_bibfiles) == type([])
    call tex_nine#SetupBibTeX()
elseif exists('g:tex_bibfiles')
    echoerr "`g:tex_bibfiles' must be a Vim list."
endif

if exists('g:tex_synctex') && g:tex_synctex == 1
    call tex_nine#SetupSyncTeX()
    vnoremap <buffer><silent> S <Esc>:call tex_nine#SyncView()<CR> 
endif

" ******************************************
"         Normal mode mappings
" ******************************************
noremap <buffer><silent> <LocalLeader>U :call tex_nine#SetupBibTeX('update')<CR>
noremap <buffer><silent> <LocalLeader>Q :copen<CR>
noremap <buffer><silent> <C-B> ?\\begin\\|\\end<CR>
noremap <buffer><silent> <C-F> /\\end\\|\\begin<CR>
noremap <buffer><silent> gd yiB/\\label{<C-R>0}<CR>
noremap <buffer><silent> gb :call tex_nine#BibQuery()<CR>
noremap <buffer><silent> <F1> :call tex_nine#InsertTemplate(b:skeleton)<CR>

" ******************************************
"          Insert mode mappings
" ******************************************
inoremap <buffer> <LocalLeader><LocalLeader> <LocalLeader>
inoremap <buffer> <LocalLeader>K 
inoremap <buffer><expr> <LocalLeader>B tex_nine#InsertEnvironment()
imap <buffer><expr> <LocalLeader>R tex_nine#SmartInsert('\ref{')
imap <buffer><expr> <LocalLeader>C tex_nine#SmartInsert('\cite{','\[cC]ite')

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
inoremap <buffer> <LocalLeader>r \varrho
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

" Neat insertion of superscripts and subscripts
inoremap <buffer><expr> _ tex_nine#IsLeft('_') ? '{}<Left>' : '_'
inoremap <buffer><expr> ^ tex_nine#IsLeft('^') ? '{}<Left>' : '^'
inoremap <buffer><expr> = tex_nine#IsLeft('=') ? '<BS>&=' : '='
inoremap <buffer><expr> ~ tex_nine#IsLeft('~') ? '<BS>\approx' : '~'

" Cycling delimiters
inoremap <buffer><expr> { tex_nine#Cycle('{')
inoremap <buffer><expr> [ tex_nine#Cycle('[')
inoremap <buffer><expr> ( tex_nine#Cycle('(')
inoremap <buffer><expr> $ tex_nine#Cycle('$') 

" TeX aware text objects
" Inline maths
vnoremap <buffer><expr> i$ tex_nine#EquationObject('inner')
vnoremap <buffer><expr> a$ tex_nine#EquationObject('outer')
omap <buffer><silent> i$ :normal vi$<CR>
omap <buffer><silent> a$ :normal va$<CR>

if exists('loaded_matchit')
    " Paragraph
    vmap <buffer><expr> ip tex_nine#TeXParagraph('inner')
    vmap <buffer><expr> ap tex_nine#TeXParagraph('outer')
    omap <buffer><silent> ip :normal vip<CR>
    omap <buffer><silent> ap :normal vap<CR>

endif


"DISABLED
"inoremap <buffer><expr> { tex_nine#IsLeft('{') ? '<Right><BS>' : '{}<Left>'
"inoremap <buffer><expr> } tex_nine#IsLeft('{') ? '{}<Left>' : '}'

"inoremap <buffer><expr> ( tex_nine#IsLeft('(') ? '<Right><BS>' : '()<Left>'
"inoremap <buffer><expr> ) tex_nine#IsLeft('(') ? '()<Left>' : ')'
"
"inoremap <buffer><expr> [ tex_nine#IsLeft('[') ? '<Right><BS>' : '[]<Left>'
"inoremap <buffer><expr> ] tex_nine#IsLeft('[') ? '[]<Left>' : ']'
