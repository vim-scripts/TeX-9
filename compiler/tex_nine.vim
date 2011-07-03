" LaTeX filetype plugin: Compiler file
" Compiler:     TeX and friends
" Last Change:  June 22, 2011

let s:cpo_save = &cpo
set cpo-=C

let current_compiler = 'tex_nine'
" This compiler file doesn't differ that much
" from the vanilla system file. We bind all
" sophisticated features to autocommands
" QuickFixCmdPre and QuickFixCmdPost. Namely,
" all invalid errormessages are filtered from
" quickfix list unless `g:tex_verbose' is 1.

" Value errorformat are taken from vim help, see :help errorformat-LaTeX, with
" addition from Srinath Avadhanula <srinath@fastmail.fm>
CompilerSet errorformat=%E!\ LaTeX\ %trror:\ %m,
        \%E%f:%l:\ %m,
	\%E!\ %m,
	\%+WLaTeX\ %.%#Warning:\ %.%#line\ %l%.%#,
	\%+W%.%#\ at\ lines\ %l--%*\\d,
	\%WLaTeX\ %.%#Warning:\ %m,
	\%Cl.%l\ %m,
	\%+C\ \ %m.,
	\%+C%.%#-%.%#,
	\%+C%.%#[]%.%#,
	\%+C[]%.%#,
	\%+C%.%#%[{}\\]%.%#,
	\%+C<%.%#>%.%#,
	\%C\ \ %m,
	\%-GSee\ the\ LaTeX%m,
	\%-GType\ \ H\ <return>%m,
	\%-G\ ...%.%#,
	\%-G%.%#\ (C)\ %.%#,
	\%-G(see\ the\ transcript%.%#),
	\%-G\\s%#,
	\%+O(%*[^()])%r,
	\%+O%*[^()](%*[^()])%r,
	\%+P(%f%r,
	\%+P\ %\\=(%f%r,
	\%+P%*[^()](%f%r,
	\%+P[%\\d%[^()]%#(%f%r,
	\%+Q)%r,
	\%+Q%*[^()])%r,
	\%+Q[%\\d%*[^()])%r

CompilerSet makeprg=
if exists('g:tex_flavor')
    let &makeprg=g:tex_flavor.' -file-line-error -interaction=nonstopmode'
else
    let &makeprg='latex -file-line-error -interaction=nonstopmode'
endif

if exists('g:tex_synctex') && g:tex_synctex
    let &makeprg.=' -synctex=1'
endif

let &makeprg.=' %:t'

let &cpo = s:cpo_save
unlet s:cpo_save
