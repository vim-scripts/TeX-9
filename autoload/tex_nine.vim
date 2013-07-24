" vim: tw=72 

"***********************************************************************
" General purpose routines
"***********************************************************************

function tex_nine#GetMaster()
python << EOF
try:
    master_file = document.get_master_file(vim.current.buffer)
except TeXNineError, e:
    echoerr(e)
    master_file = ""
EOF
    return pyeval('master_file')
endfunction

function tex_nine#GetOutputFile()
python << EOF
master_output = ""
try:
    master_output = document.get_master_output(vim.current.buffer)
except TeXNineError, e:
    echoerr(e)
    master_output = ""
EOF
    return pyeval('master_output')
endfunction

function tex_nine#GetCompiler(config)
    if a:config.compiler != ""
        let tex_nine_compiler = a:config.compiler
    else
        let tex_nine_compiler = pyeval('document.get_compiler(vim.current.buffer)')
    endif
    if &l:makeprg == "" && tex_nine_compiler != ""
        call tex_nine#ConfigureCompiler(tex_nine_compiler, a:config.synctex)
    endif
    return tex_nine_compiler
endfunction


"***********************************************************************
" Viewing and SyncTeXing
"***********************************************************************

function tex_nine#ViewDocument()
    echo "Viewing the document...\r"
    python document.view(vim.current.buffer)
endfunction

function tex_nine#ForwardSearch()
python << EOF
try:
    document.forward_search(vim.current.buffer, vim.current)
except TeXNineError, e:
    echoerr(e)
EOF
return
endfunction


"***********************************************************************
" Miscellaneous (Omni completion, snippets, headers, bibqueries)
"***********************************************************************

function tex_nine#UpdateHeader()
    python document.update_header(vim.current.buffer)
endfunction

function tex_nine#InsertSkeleton(skeleton)
   python document.insert_skeleton(vim.current.buffer, vim.eval('a:skeleton'))
   update
   edit
   " Enter insert mode for safety
   startinsert
endfunction

function tex_nine#OmniCompletion(findstart, base)
    if a:findstart
        let pos = pyeval('omni.findstart()')
        return pos
    else
        let compl = pyeval('omni.completions()')
        return compl
    endif
endfunction

function tex_nine#MathCompletion(findstart, base)
    if a:findstart
        return col('.')
    else
        let compl = pyeval('tex_nine_maths_cache')
        return compl
    endif
endfunction

function tex_nine#Bibquery(cword)
python << EOF
try:
    document.bibquery(vim.eval('a:cword'), omni.bibpaths)
except TeXNineError, e:
    echoerr(e)
EOF
return
endfunction

function tex_nine#IsLeft(lchar)
    let left = getline('.')[col('.')-2]
    return left == a:lchar ? 1 : 0
endfunction

function tex_nine#SmartInsert(keyword, ...)
    " Inserts a LaTeX statement and starts omni completion.  If the
    " line already contains the statement and the statement is still
    " incomplete, i.e. missing the closing delimiter, only omni
    " completion is started.

    let pattern = exists('a:1') ? '\'.a:1.'{' : '\'.a:keyword
    let line = getline('.')
    let pos = col('.')

    " There's a beginning of a statement on the left
    if line[:pos] =~ pattern
        " Is there closing delimiter on the right and no beginning of a
        " new statement

        " The closing delimiter is closer than \
        let i = pos-1
        while i < col('$')
            if line[i] == '\'
                break
            elseif line[i] == '}'
                return ""
            endif
            let i = i+1
        endwhile
    endif

    return a:keyword."}\<Esc>ha"
endfunction

function! ListEnvCompletions(A,L,P)
    " Breaks if dictionary is a list but we only support one dictionary
    " at the moment
    if filereadable(&dictionary)
        return join(readfile(&dictionary), "\<nl>")
    else
        return []
    endif
endfunction

function tex_nine#InsertSnippet(...)
        if exists('a:1')
            let s:envkey = a:1
        else
            let s:envkey = input('Environment: ', '', 'custom,ListEnvCompletions')
        endif

        if s:envkey != "" 
            python snip = document.insert_snippet(vim.eval('s:envkey'), vim.eval('&ft'))
            return pyeval('snip')
        else
            return "\<Esc>"
        endif
endfunction

function tex_nine#EnvironmentOperator(mode)
    let pos = pyeval('get_latex_environment(vim.current.window)["range"]')
    if !pos[0] && !pos[1]
        return "\<Esc>"
    endif
    if a:mode == 'inner'
        let pos[0] += 1
        let pos[1] -= 1
    endif
    return "\<Esc>:".pos[0]."\<Enter>V".(pos[1] - pos[0])."jO" 
endfunction


"***********************************************************************
" Settings
"***********************************************************************

function tex_nine#AddBuffer(config, snipfile)
python << EOF
omni = TeXNineOmni()
document = TeXNineDocument(vim.current.buffer)
document.setup_snippets(vim.eval('a:snipfile'),
                        vim.eval('&ft'))

EOF
endfunction

function tex_nine#SetAutoCmds(config)

    augroup tex_nine
        au BufWritePre *.tex call tex_nine#UpdateHeader()
    augroup END

    "au QuickFixCmdPre <buffer> call tex_nine#Premake()
    "au! tex_nine QuickFixCmdPost 

    "if a:config.verbose
    "    au tex_nine QuickFixCmdPost <buffer> call tex_nine#PostmakeVanilla()
    "else
    "    au tex_nine QuickFixCmdPost <buffer> call tex_nine#Postmake()
    "endif
endfunction

function tex_nine#Reconfigure(config)
python << EOF
try:
    omni.update()
    paths = map(path.basename, omni.bibpaths)
    echomsg("Updated BibTeX databases...using {0}.".format(", ".join(paths)))
except TeXNineError, e:
    # It may be not an error. The user may not use BibTeX...
    echomsg("Cannot update BibTeX databases: "+str(e))
EOF
    if a:config.compiler == ""
        silent! let tex_nine_compiler = pyeval('document.get_compiler(vim.current.buffer, update=True)')
        let msg = ""
    else
        let tex_nine_compiler = a:config.compiler 
        let msg = " (set in vimrc)"
    endif

    if tex_nine_compiler != ""
        call tex_nine#ConfigureCompiler(tex_nine_compiler, a:config.synctex)
        python echomsg("Updated the compiler...using `{}'.{}".format(vim.eval('tex_nine_compiler'), vim.eval('msg')))
    else
        python echomsg("Cannot determine the compiler: Make sure the header contains the compiler line.")
        echomsg msg
    endif
endfunction

"***********************************************************************
" Compilation
"***********************************************************************


function tex_nine#Compile(deep, config)

    let tex_nine_compiler = tex_nine#GetCompiler(a:config)
    let master = tex_nine#GetMaster()

    if tex_nine_compiler == "" || master == ""
        return
    elseif tex_nine_compiler == "make"
        silent make!
    else
        update " Autowrite is not enough
        exe "lcd" fnameescape(fnamemodify(master, ':h'))
        unsilent echo "Compiling...\r"
        if a:deep == 1 
            python document.compile(vim.current.buffer, vim.eval('tex_nine_compiler'))
        endif
        " Make and do not jump to the first error
        exe 'silent' 'make!' escape(master, ' ')
        lcd -
    endif

    " Post-process errors
    if !a:config.verbose
        call setqflist(pyeval('document.postmake()'))
    endif

    if (!has("gui_running"))
        redraw!
    endif

    let numerrors = len(filter(getqflist(), 'v:val.valid==1'))
    unsilent echo "Found ".numerrors." Error(s)."

endfunction

function tex_nine#ConfigureCompiler(compiler, synctex)
    " Configure the l:makeprg variable according to user's preference

    let &l:makeprg = a:compiler
    if &l:makeprg != 'make'
        let &l:makeprg .= ' -file-line-error -interaction=nonstopmode'
        if a:synctex
            let &l:makeprg .= ' -synctex=1'
        endif
    endif
    let &l:makeprg .= ' $*'

    " TODO: test Makefile
    " This is taken from vim help, see :help errorformat-LaTeX, with
    " addition from Srinath Avadhanula <srinath@fastmail.fm>
    setlocal errorformat=%E!\ LaTeX\ %trror:\ %m,
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

endfunction
