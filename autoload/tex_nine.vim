"************************************************************************
"
"                             TeX 9 library
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
"    Copyright Elias Toivanen, 2011
"************************************************************************

"************************************************************************
"{{{ TODO:
" SyncTeX for Evince (>= 3.2)
" FormatExpr
"}}}
"************************************************************************

if !has('python')
    echoerr "Error: TeX 9 requires Vim compiled with +python."
    finish
endif

"************************************************************************
"                Vimscript functions and wrappers {{{1

function! tex_nine#Add_buffer()
    python document = TeXNineDocument(vim.current.buffer, vim.eval('g:tex_flavor'))
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
    unsilent echo "Compiling..."
    python document.compile(vim.current.buffer.name)
endfunction

function! tex_nine#Quickcompile()
    unsilent echo "Compiling...\r"
    exe "silent" "make!" fnameescape(expand('%:t'))
endfunction

function! tex_nine#Premake()
    lcd %:h
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

function! tex_nine#View_document(viewer)
    exe "!".a:viewer.app fnameescape(expand('%<')).'.'.a:viewer.target.' &'
endfunction

function! tex_nine#Setup_omni(bibfiles, update)
    python omni = TeXNineOmni()
    if a:update == 0
        python omni.setup_bibtex_entries(vim.eval('a:bibfiles'))
    else
        python omni.setup_bibtex_entries(vim.eval('a:bibfiles'), True)
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

function! tex_nine#Cycle(delim)
    python chars = document.yield_delimiters(vim.eval('a:delim'))
    python vim.command('return "{0}"'.format(chars))
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

        if line =~ pattern && line[pos-1:] =~ ',\|{\|}'
                return ""
        else
                return a:keyword.""
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

function! tex_nine#Setup_snippets(snipfile)
    python ft = vim.eval('&ft')
    python document.setup_snippets(vim.eval('a:snipfile'), ft)
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

" Text object for inline equations delimited by '$'
function! tex_nine#EquationObject(mode)
        let line = getline('.')
        let pos = col('.')-1
        let textextzone = '\(Sub\)\{0,1\}Section\|Doc\|Para'

        let inner = ["\<Esc>lT\$vt\$","\<Esc>hT\$vt\$","\<Esc>T\$vt\$","\<Esc>"]
        let outer = ["\<Esc>lF\$vf\$","\<Esc>hF\$vf\$","\<Esc>F\$vf\$","\<Esc>"]

        exe 'let strokes = '.a:mode

        if (line[pos] == '$' && synIDattr(synID(line("."), col('.')-1, 1), "name") =~ textextzone)
                                \|| col('.')-1 == 0
                " We're on the leftmost $
                return strokes[0]
        elseif (line[pos] == '$' && synIDattr(synID(line("."), col('.')+1, 1), "name") =~ textextzone)
                                \|| col('.')+1 =~ col('$')
                " We're on the rightmost $
                return strokes[1]
        elseif line[pos] != '$' && synIDattr(synID(line("."), pos, 1), "name") !~ textextzone
                " We're inside the equation
                return strokes[2]
        else
                " Give up
                return strokes[3]
        endif
endfunction

" Text object for math environments
function! tex_nine#TeXParagraph(mode)
        let ismath = synIDattr(synID(line("."), 1, 1), "name") 
        let line = getline('.')
        let stroke = "V%"
        let opts = ["jOk","kOj"]

        if getline('.')[col('.')-1] =~ '[{}]'
                let stroke = "0".stroke
        endif

        if ( ismath =~ "Math" || line =~ '\\\(begin\|end\)' ) 

                if line !~ '\\\(begin\|end\)' || col('.') == col('$')
                        let stroke = "/\\\\end\<CR>".stroke
                endif

                if a:mode == 'inner'
                        if line =~ '\\begin'
                                let stroke .= opts[1]
                        else
                                let stroke .= opts[0]
                        endif
                endif

                return "\<Esc>".stroke
        else
                if a:mode == 'inner'
                        return "ip"
                elseif a:mode == 'outer'
                        return "ap"
                endif
        endif
endfunction
"}}}
"************************************************************************

"************************************************************************
"                           Python module {{{1

if !exists("*s:DefineTeXNine")
function s:DefineTeXNine()
python << EOF
import vim
import re
import subprocess
import os
import sys
import time
import operator

from getpass import getuser
from itertools import groupby
from string import Template

class TeXNineBase(object):
    """Singleton class with reporting methods."""

    _instance = None

    messages = {

        'NO_BIBTEX' : 'No BibTeX databases present...',
        'INVALID_BIBFILE' : 'Invalid BibTeX file: "{0}".',
        'INVALID_BIBENTRY_TYPE' : 'No such BibTeX entry type: "{0}"',
        'INVALID_BIBENTRY' : 'No BibTeX entry found for "{0}"', 
        'UPDATING_ENTRIES' : 'Updating BibTeX entries...'
    }

    def __new__(self, *args, **kwargs):
        if self._instance is None:
            self.buffers = {}
            self._instance = object.__new__(self)
        return self._instance

    def echoerr(self, errorstr):
        vim.command("echoerr '{0}'".format(errorstr))

    def echomsg(self, msgstr):
        vim.command("echomsg '{0}'".format(msgstr))

class TeXNineBibTeX(TeXNineBase):
    """A class to gather BibTeX entries in a list."""

    _bibcompletions = []
    _bibpaths = []

    def __init__(self):
        return

    def _bibparser(self, fname):
        """Opens a file and extracts all BibTeX entries in it."""

        try:
            with open(fname) as f:
                return re.findall('^@\w+{(\S+) *,', f.read(), re.M)

        except IOError:
            self.echoerr(self.messages["INVALID_BIBFILE"].format(fname))
            return []

    def setup_bibtex_entries(self, bibfiles, update=False):
        """Builds a list of BibTeX entries.

        Takes a list of BiBTeX databases and extracts all entry keywords
        from them. Each item in the list can be just the filename, e.g.
        'data.bib', or a path to the file, e.g. '~/data.bib'.  In case
        only the filename is specified, setup_bibtex_entries assumes
        that the bibfile is located in a valid TDS[1] tree or in the
        compilation folder. Bibfile validation relies on ``kpsewhich''
        that is shipped at least with the standard TeXLive distribution.

        [1] http://www.tug.org/tds/tds.html#BibTeX
        """

        if update:
            self.echomsg(self.messages["UPDATING_ENTRIES"])
            self._bibpaths = []
            self._bibcompletions = []

        if self._bibcompletions and self._bibpaths: 
            # Return early since we alread got a non-empty list
            return

        for bibfile in bibfiles:
            # Give precedence to bibfiles that are located in
            # the compilation folder.
            dirname = os.path.dirname(vim.current.buffer.name)
            bibtemp = os.path.join(dirname, bibfile)

            bibfile = ( bibtemp if os.path.exists(bibtemp) else bibfile )

            proc = subprocess.Popen(['kpsewhich','-must-exist', bibfile],
                                    stdout=subprocess.PIPE)
            bibpath = proc.communicate()[0].strip('\n')

            # kpsewhich returns the complete path or the empty string
            # and we rely on this.
            if bibpath:
                self._bibpaths += [bibpath]
                self._bibcompletions += self._bibparser(bibpath)
            else:
                self.echoerr(self.messages["INVALID_BIBFILE"].format(bibfile))

    def get_bibpaths(self):
        return self._bibpaths

class TeXNineOmni(TeXNineBibTeX):
    """Vim's omni completion for a LaTeX document.
    
    Following items are completed via omni completion

    *   BibTeX entries
    *   Labels for cross-references
    *   Font names when using `fontspec'
    *   Picture names when using `graphicx' (EPS, PNG, JPG, PDF)
    
    """

    def __init__(self):
        TeXNineBibTeX.__init__(self)
        self.keyword = None

    def _labels(self):
        """Labels for references."""
        vim.command('update')
        pat = re.compile('\\\\label{([\w:.-]+)}')
        return pat.findall("\n".join(vim.current.buffer[:]))

    def _fonts(self):
        """Installed fonts."""
        proc = subprocess.Popen('fc-list',
                                stdout=subprocess.PIPE)
        output = proc.communicate()[0].splitlines()
        output.sort()
        output = [ i for i,j in groupby(output, lambda x: re.split('[:,]', x)[0]) ]
        return output

    def _pics(self):
        """Pictures in compilation folder."""
        extensions = [ '.PDF', '.PNG', '.JPG', '.JPEG', '.EPS', 
                       '.pdf', '.png', '.jpg', '.jpeg', '.eps' ]

        files = os.listdir(os.path.dirname(vim.current.buffer.name))
        pics = [ pic for pic in files if pic[pic.rfind('.'):] in extensions ]
        return pics

    def findstart(self):
        """Finds the cursor position where completion starts."""

        win = vim.current.window
        line = vim.current.line[:win.cursor[1]]

        start = max((line.rfind('{'),
                     line.rfind(',')))
        try:
            keyword = re.findall('\\\\(\w+)([(].+[)])?([[].+[]])?{', line)[-1]
            self.keyword = keyword[0]
        except IndexError:
            self.keyword = None

        finally:
            # Vim requires this function to return -1 if there were no
            # matches
            start = ( start+1 if start != -1 else -1 )
            vim.command('return {0}'.format(start))

    def completions(self):
        """Selects what type of omni completion should occur."""

        compl = []

        # Natbib has \Cite.* type of of commands
        if self.keyword:
            if ( 'cite' in self.keyword or 'Cite' in self.keyword ) and self._bibcompletions: 
                compl = self._bibcompletions
            elif 'ref' in self.keyword:
                compl = self._labels()
            elif 'font' in self.keyword or 'setmath' in self.keyword:
                compl = self._fonts()
            elif 'includegraphics' in self.keyword:
                compl = self._pics()

        vim.command('return {0}'.format(str(compl).decode('string-escape')))

class TeXNineSnippets(object):
    """Snippet engine for TeX 9.

    """
    _snippets = {'tex': {}, 'bib': {}}

    def __init__(self):
        self._lstripper = operator.methodcaller('lstrip', ' ')
        self._commentstripper = lambda x: '#' not in x

    def _parser(self, string):
        lines = string.splitlines(True)

        # Format the snippet 
        lines = filter(self._commentstripper,
                map(self._lstripper, lines))

        if lines:
            snippet = "".join(lines[1:]).rstrip('\n')
            keyword = str(lines[0].rstrip('\n'))
            return (keyword, snippet)
        else:
            return None

    def setup_snippets(self, fname, ft):
        """Builds a dictionary of keyword-snippet pairs.

        Extracts snippets out of ``fname'' whose syntax resembles that
        of Michael Sander's snipMate plugin. Both BibTeX and LaTeX
        buffers get their own dictionary. 
        """

        if self._snippets[ft]:
            # We have the snippets already
            return

        with open(fname) as snipfile:
            # Trailing empty lines
            snippets = snipfile.read().rstrip('\n').split('snippet')
            snippets = map(self._parser, snippets)
            # Remove comments 
            snippets = filter(None, snippets)

            self._snippets[ft] = dict(snippets)

    def insert_snippet(self, keyword, ft):
        """Inserts snippets into the current Vim buffer.
        
        Fetches and returns the code snippet corresponding to key
        ``keyword'' from the snippet dictionary that corresponds to the
        filetype ``ft''.

        If the snippet is not found, generic LaTeX environment is
        inserted in LaTeX files and error is raised in BibTeX files.
        After the snippet is inserted, cursor position is returned
        to the original position with Vim's ``context mark''
        syntax.

        This method is hooked to a <expr> mapping and thus it returns
        a string that Vim then automatically indents.

        """

        try:
            snippet = self._snippets[ft][keyword]
            snippet = "m`i"+snippet+"``"
        except KeyError:
            if ft == 'tex':
               snippet = ( "m`i"+
                           "\\begin{"+keyword+"}\n\\end{"+keyword+"}"+
                           "``" )
            elif ft == 'bib':
                self.echoerr(self.messages["INVALID_BIBENTRY_TYPE"].format(keyword))
                return ""

        vim.command("return '{0}'".format(snippet))

class TeXNineCycler(object):
    """Autoclose delimiters in a smart way.
    
    When inserting the opening delimiter ('(','[','{','$') to a LaTeX
    construct, the closing delimiter is automatically inserted. Pressing
    the delimiter key for the second time undoes the previous action.
    Third key press inserts nested delimiters, whereas fourth key press
    returns to the initial state thus ending the cycle. The cycle is
    reset when the cursor position changes by more than one character
    inside a row, the row changes or when the character under the cursor
    does not match the opening delimiter.
    
    """

    def _cycle(self, delim, iterable):
        saved = iterable[:]
        delimpair, rest = iterable[0], iterable[1:]
        while saved:
            win = vim.current.window
            row, col = win.cursor
            self.pos = (row, col)
            yield delimpair

            for element in rest:
                win = vim.current.window
                row, col = win.cursor
                try:
                    char = vim.current.line[col-1]
                except IndexError:
                    # Empty line
                    char = None

                if self.pos in [(row, col), (row, col-1)] and char == delim:
                    self.pos = (row, col)
                    yield element
                else:
                    # Reset the cycler
                    break

    def __init__(self):
        self.pos = (None,None)
        self.delim_yielder = {}
        self.delimiters = {
                  '$' : [
                  "$$\<Left>",
                  "\<Esc>lcl",
                  "$$$\<Left>\<Left>",
                  "\<Esc>hc4l"
                  ],
                  '(': [
                  "()\<Left>",
                  "\<Esc>lcl",
                  "())\<Left>\<Left>",
                  "\<Esc>hc4l"
                 ],
                  '[': [
                  "[]\<Left>",
                  "\<Esc>lcl",
                  "[]]\<Left>\<Left>",
                  "\<Esc>hc4l"
                 ],
                  '{': [
                  "{}\<Left>",
                  "\<Esc>lcl",
                  "{}}\<Left>\<Left>",
                  "\<Esc>hc4l"
                 ]}

        for i,j in self.delimiters.iteritems():
            self.delim_yielder[i] = self._cycle(i,j)

    def yield_delimiters(self, delim):
        return next(self.delim_yielder[delim])

class TeXNineDocument(TeXNineBase, TeXNineCycler, TeXNineSnippets):
    """A class to manipulate LaTeX documents in Vim.
    
    TeXNineDocument can

    * Compile a LaTeX document, updating BibTeX references
    * Insert a skeleton file into the current Vim buffer
    * Update the dynamic content in the skeleton header
    * Sanitize Vim's ``quickfixlist''
    * Preview the definition of a BibTeX entry based on its keyword,

    and via inheritance

    * Insert delimiters in a smart way, saving keystrokes
    * Insert LaTeX/BibTeX code snippets
    
    """

    def __init__(self, vim_buffer, compiler,
                 label='%  Last Change:', timestr='%Y %b %d'):

        TeXNineCycler.__init__(self)
        TeXNineSnippets.__init__(self)

        self.label = label
        self.timestr = timestr
        self.compiler = compiler
        self.buffers[vim_buffer] = {'fname': vim_buffer.name, 'ft': vim.eval('&ft')}

    def compile(self, fname):
        """Compiles the current LaTeX manuscript.

        This method attempts to do a deep compile, i.e. update
        cross-references and BibTeX references. Vim's `make' command is
        only called once to avoid overhead that might result from
        SyncTeX and additional processing routines.

        """

        cwd, basename = os.path.split(fname)

        tex_cmd = [self.compiler,
                   '-output-directory='+cwd,
                   '-interaction=batchmode',
                   fname]
        bib_cmd = ['bibtex', basename[:-len('.tex')]+'.aux']
        kwargs = {'stdout': subprocess.PIPE, 'cwd': cwd}

        subprocess.Popen(tex_cmd, **kwargs).wait()
        stdout, stderr = subprocess.Popen(bib_cmd, **kwargs).communicate() 
        matches = re.findall('I didn.t find a database entry for .(\S+).', stdout)
        subprocess.Popen(tex_cmd, **kwargs).wait()

        # Create quickfix list
        vim.command('silent make! {0}'.format(basename.replace(' ','\ ')))
        
        # Add some BibTeX errors that are not included by default.
        for m in matches:
            m = "\\cite{[}]*"+m
            searchpat = "/"+m+"/j"
            vim.command("silent vimgrepadd {0} %:p".format(searchpat))

    def insert_skeleton(self, skeleton_file, vimbuffer):
        """Insert a skeleton of a LaTeX manuscript."""

        with open(skeleton_file) as skeleton:
            template = Template(skeleton.read())
            skeleton = template.safe_substitute(_file = os.path.basename(vimbuffer.name),
                                                _date_created = time.strftime(self.timestr),
                                                _author = getuser())

            vimbuffer[:] = skeleton.splitlines(True)

    def update_header(self, vimbuffer):
        """Updates the date label in the header."""

        date = time.strftime(self.timestr)
        if len(vimbuffer) >= 10 and int(vim.eval('&modifiable')):
            for i in range(10):
                if self.label in str(vimbuffer[i]) and date not in str(vimbuffer[i]):
                    vimbuffer[i] = '{0} {1}'.format(self.label, date)
                    return

    def postmake(self):
        """Filters invalid and irrelevant error messages that LaTeX
        compilers produce. Relies on Vim's Quickfix mechanism."""

        valid = operator.itemgetter('valid')
        qflist = vim.eval('getqflist()')
        qflist.sort(key=valid)

        ignored = ['Overfull', 'Underfull'] # Hack to your taste

        # Invalid errors
        for key, items in groupby(qflist, valid):
            if int(key):
                # Irrelevant errors
                qflist = list(err for err in items
                              if all( i not in err['text'] for i in ignored))
                vim.command('call setqflist({0})'.format(qflist))
                return 

        vim.command('call setqflist({0})'.format([]))

    def bibquery(self, cword, paths):
        """Displays the BibTeX entry under cursor in a preview window."""

        if not paths:
            self.echomsg(self.messages["NO_BIBTEX"])
            return

        for bibfile in paths:
            try:
                with open(bibfile, 'r') as f:
                    txt = f.read()
                    bibfile = bibfile.replace(' ', '\ ')
                # First match wins
                if re.search("^@\S+"+cword, txt, re.M):
                    cword = "^@\\\S\\\+"+cword
                    vim.command("pedit +/{0} {1}".format(cword, bibfile))
                    vim.command("redraw") # Needed after opening a
                                          # preview window.
                    return

            except IOError:
                self.echoerr(self.messages["INVALID_BIBFILE"].format(bibfile))

        # No matches in any of the bibfiles
        self.echomsg(self.messages["INVALID_BIBENTRY"].format(cword))
EOF
endfunction
call s:DefineTeXNine()
endif
"}}}
"************************************************************************

" vim: nowrap fdm=marker tw=72 fo=tcq
