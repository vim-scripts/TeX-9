"************************************************************************
"
"                   TeX 9 library: Vimscript wrappers
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
"    Copyright Elias Toivanen, 2011, 2012
"************************************************************************

if !has('python')
    echoerr "TeX 9 Error: a Vim installation with +python is required."
    finish
endif

"************************************************************************
"                Vimscript wrappers {{{1

function! tex_nine#Forward_search()
    python document.forward_search(vim.current.buffer.name, vim.current)
endfunction

function! tex_nine#Update_header()
    python document.update_header(vim.current.buffer)
endfunction

function! tex_nine#Insert_skeleton(skeleton)
   python document.insert_skeleton(vim.eval('a:skeleton'), vim.current.buffer)
   update
   edit
endfunction

function! tex_nine#Deepcompile()
    unsilent echo "Compiling...\r"
    python document.compile(vim.current.buffer.name)
endfunction

function! tex_nine#Quickcompile()
    unsilent echo "Compiling...\r"
    python document.compile(vim.current.buffer.name, quick=True)
endfunction

function! tex_nine#Premake()
    python master_folder = os.path.dirname(document.get_master_file(vim.current.buffer)) 
    python vim.command('exe "lcd" fnameescape("{0}")'.format(master_folder))
endfunction

function! tex_nine#Postmake()
    python document.postmake()
    lcd -
    if (!has("gui_running"))
        redraw!
    endif
    let numerrors = len(filter(getqflist(), 'v:val.valid==1'))
    unsilent echo "Found ".numerrors." Error(s)."
endfunction

function! tex_nine#View_document()
    echo "Viewing the document...\r"
    python document.view(vim.current.buffer.name)
endfunction

function! tex_nine#Setup_omni(bibfiles, update)
    python omni = TeXNineOmni()
    if a:update == 0
        python omni.setup_bibtex_entries(vim.eval('a:bibfiles'))
    else
        python omni.setup_bibtex_entries(vim.eval('a:bibfiles'), update=True)
    endif
endfunction

function! tex_nine#Omni_completion(findstart, base)
    if a:findstart
        python omni.findstart()
    else
        python omni.completions()
    endif
endfunction

function! tex_nine#Bibquery(cword)
    python document.bibquery(vim.eval('a:cword'), omni.get_bibpaths())
endfunction

function! tex_nine#IsLeft(lchar)
        let left = getline('.')[col('.')-2]
        return left == a:lchar ? 1 : 0
endfunction

function! tex_nine#Smart_insert(keyword, ...)
        " Inserts a LaTeX statement and starts omni completion.  If the
        " line already contains the statement and the statement is still
        " incomplete, i.e. missing the closing delimiter, only omni
        " completion is started.

        let pattern = exists('a:1') ? '\'.a:1 : '\'.a:keyword
        let line = getline('.')
        let pos = col('.')

        if line[:pos] =~ pattern && line[pos-1:] =~ ',\|{\|}'
                return ""
        else
                return a:keyword."}\<Esc>ha"
        endif
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

function! tex_nine#Insert_snippet(...)

        if exists('a:1')
            let s:envkey = a:1
        else
            let s:envkey = input('Environment: ', '', 'custom,ListEnvCompletions')
        endif

        if s:envkey != "" 
            python document.insert_snippet(vim.eval('s:envkey'), vim.eval('&ft'))
        else
            return "\<Esc>"
        endif
endfunction

function! tex_nine#Environment_operator(mode)
    python env = utils.get_latex_environment(vim.current.window)
    python begin, end = env['range']
    python if not begin and not end: vim.command('return "\<Esc>"')
    if a:mode == 'inner'
        python begin += 1
        python end -= 1
    endif
    python vim.command('return "\<Esc>:{0}\<Enter>V{1}jO"'.format(begin, end-begin))
endfunction

"}}}
"************************************************************************

" vim: nowrap fdm=marker tw=72 fo=tcq
