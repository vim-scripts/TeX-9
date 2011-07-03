if !has('python') || !has('syntax')
    echoerr "Error: TeX 9 requires Vim compiled with +python and +syntax"
    finish
endif

" ******************************************
"          TeX 9 function library
"               GPL Licensed 
"                    by
"              Elias Toivanen
"
"      TODO: 
"            -More omnicompletions
"            -Format expression
" ******************************************

" ******************************************
"             Python Module
" ******************************************
if !exists("*tex_nine#DefPython")
function tex_nine#DefPython()
python << PYTHONEOF

import vim, re, subprocess
import os, sys, time
import itertools

from string import Template
from getpass import getuser
from operator import methodcaller

class TeXNineDocument(object):

    def set_header(self, vimbuffer):
        label='%  Last Change:'
        timestring = '%Y %b %d'
        date = time.strftime(timestring)
        if len(vimbuffer) >= 10 and vim.eval('&modifiable'):
            for i in range(10):
                if label in str(vimbuffer[i]) and date not in str(vimbuffer[i]):
                    vimbuffer[i] = '{0} {1}'.format(label, date)
                    return

    def insert_skeleton(self, fname, vimbuffer):
        timestring = '%Y %b %d'
        with open(fname) as skeleton:
            template = Template(skeleton.read())

            skeleton = template.safe_substitute(_file=os.path.basename(vimbuffer.name),
                                    _date_created=time.strftime(timestring),
                                    _author=getuser())

            vimbuffer[:] = skeleton.splitlines(True)

    def sanitize_quickfixlist(self):
        """
        Filters invalid and irrelevant error messages
        """
        ignored = ['Underfull','Overfull'] # More to come

        # Too bad LaTeX spits out hard wrapped output. This
        # causes problems with long error messages.
        qf = vim.eval('getqflist()')

        qf = filter(lambda x: int(x['valid'])
                    and all( i not in x['text'] for i in ignored ), qf)
                        

        vim.command('call setqflist({0})'.format(qf))

    def query_bibfiles(self):
        """
        Jumps to a BibTeX file containing the
        citekey under the cursor and show a quickfix
        window with the first item set to the LaTeX
        manuscript.
        """
        try:
            citekey = vim.eval("expand('<cword>')")
            citekey = "/^@\S\+"+citekey+"/"
            bibpaths = " ".join([ x.replace(' ', '\ ') for x in omni.bibpaths ])

            vim.command('cgetexpr expand("%") . ":" . line(".") .  ":" . getline(".")[:20] ."..."')
            vim.command('vimgrepadd {0} {1}'.format(citekey, bibpaths))

            # Dunno why vimgrep doesn't jump and we have to do it explicitly
            vim.command('cnext')
            vim.command('cwindow')
        except:
            errormsg = "echoerr 'Cannot jump to a BibTeX file: None defined or no matches.'"
            vim.command(errormsg)
            return

    def compile(self, vimbuffer):
        """
        Compiles the manuscript and updates bibtex
        references. Because Vim's make command
        calls additional post processing function and might
        be hooked to SyncTex, intermediate passes are called
        via subprocess to avoid overhead.

        Quicklist is not popped up automatically. Rather,
        user is informed about a clean compilation and
        potenital errors.
        """
        absname = vimbuffer.name
        basename = os.path.basename(absname)[:-len('.tex')]
        cwd = os.path.dirname(absname)

        subprocess.call([vim.eval('g:tex_flavor'), '-output-directory='+cwd,
                        '-interaction=batchmode', absname], stdout=subprocess.PIPE)


        bibtex_call = subprocess.Popen(['bibtex', basename+'.aux'],
                                        stdout=subprocess.PIPE,
                                        cwd=cwd)

        output = bibtex_call.communicate()[0]

        matches = re.findall('I didn.t find a database entry for .(\S+).', output)

        subprocess.call([vim.eval('g:tex_flavor'), '-output-directory='+cwd,
                        '-interaction=batchmode', absname], stdout=subprocess.PIPE)

        # Create quickfix list
        vim.command('silent make!')
        
        # Add some BibTeX errors that aren't
        # included by default.
        if matches:
            for m in matches:
                searchpat = "/"+m+"/j"
                vim.command("vimgrepadd {0} %".format(searchpat))

# Snippets
class TeXNineSnippets(object):
    """
    Snippet engine for TeX 9

    Call `setup_snippets(fname)' to build up a list of
    snippets. Each entry is a dictionary with entries
    `abbr' and `word' in accordance with Vim's data model for
    completions. Insert snippets to Vim buffers by calling the
    class instance with keyword string, e.g. `equation'.

    """
    def __init__(self):
        
        self._snippets = []
        self.lstripper = methodcaller('lstrip', ' ')
        self.commentstripper = lambda x: '#' not in x

    def _parser(self, string):
        lines = string.splitlines(True)

        # Format the snippet 
        lines = filter(self.commentstripper,
                map(self.lstripper, lines))

        if lines:
            word = "".join(lines[1:]).rstrip('\n')
            return {'abbr':str(lines[0].rstrip('\n')),
                    'word':word}

    def setup_snippets(self, fname):
        """
        Extracts snippets out of a file whose syntax resembles
        that of Michael Sander's snipMate plugin. Snippets are
        delimited by the keyword `snippet'
        """
        with open(fname) as snipfile:
            snippets = snipfile.read().rstrip('\n').split('snippet')
            snippets = map(self._parser, snippets)

            # Remove comments
            snippets = filter(None, snippets)
            self._snippets = snippets
    
    def __call__(self, label):
        """
        Inserts snippets into the current Vim buffer.
        """
        win = vim.current.window
        row, col = win.cursor

        snip = filter(lambda x: x['abbr'] == label, self._snippets)

        # We can't insert text to the buffer via buf.append :-(
        # if we want indentation to work.
        try:
            snip = snip[0]
            # Jump back to starting position
            snip['word'] += ""+str(row)+"Gi"
            vim.command("return '{0}'".format(snip['word']))
        except IndexError:
            # snip was the empty list
            self._insert_generic_snippet(label, row)

    def _insert_generic_snippet(self, label, row):
        if vim.eval('&ft') == 'tex':

            generic_snippet = "\\begin{"+label+"}\n\\end{"+label+"}"+""+str(row)+"Gi"
            vim.command("return '{0!s}'".format(generic_snippet))

        elif vim.eval('&ft') == 'bib':
            vim.command('echoerr "No such BibTeX entry type: {0}"'.format(label))


# Omnicompletion
class TeXNineOmni(object):
    """
    Omni-completion handler for TeX 9

    Currently, citation, label references and system fonts are completed.
    Call `setup_citekeys(filelist)' to build a list of citation
    entries from filelist. Labels are searched only from the current
    buffer.

    """
    def __init__(self):
        self.keyword = None
        self.bibcompletions = []
        self.bibpaths = []
        self.errormsg = "echoerr 'The BibTeX file you defined was invalid: {0}.'"
        self.updatemsg = "echomsg 'Updating BibTeX entries...'"

    def _bibparser(self, fname):
        try:
            with open(fname.encode('string-escape')) as f:
                return re.findall('^@\w+{(\S+) *,', f.read(), re.M)

        except IOError:
            vim.command(self.errormsg.format(fname))
            return []

    def setup_citekeys(self, filelist, update=False):
        """
        Takes a list of BiBTeX databases and extracts all
        entry keywords from them. Each item in the list can be
        just the filename, e.g. 'data.bib', or a path to the
        file, e.g. '~/data.bib'.  In case only the filename is
        specified, setup_citekeys assumes that the bibfile
        is located in a texmf tree.
        """

        if update:
            self.bibpaths = []
            vim.command(self.updatemsg)
        elif self.bibcompletions:
            # Return early if we already have
            # what we want.
            return

        bibfiles = vim.eval(filelist)
        self.bibcompletions = []

        for bibfile in bibfiles:

            # Check first if the user gave just the filename
            # for a bibfile in the compilation folder.
            # This check also gives precedence to bibfiles
            # that are located there so that system files may 
            # be overridden.

            fname = os.path.dirname(vim.current.buffer.name)
            bibtemp = os.path.join(fname, bibfile).encode('string-escape')

            if os.path.exists(bibtemp):
                bibfile = bibtemp

            proc = subprocess.Popen(['kpsewhich','-must-exist', bibfile],
                                    stdout=subprocess.PIPE)
            bibpath = proc.communicate()[0].strip('\n')


            # kpsewhich returns the empty string
            # in all such cases where the file couldn't be found
            # irrespective of $TEXMFHOME
            if bibpath:
                self.bibpaths += [bibpath]
                citekeys = self._bibparser(bibpath)
            else:
                vim.command(self.errormsg.format(bibfile))
                continue

            # Appending an empty list is a NOP
            self.bibcompletions += citekeys

    # Utitility methods
    def _labels(self):
        vim.command('update')
        pat = re.compile('\\\\label{([\w:.]+)}')
        return pat.findall("\n".join(vim.current.buffer[:]))

    def _fonts(self):
        proc = subprocess.Popen('fc-list',
                                stdout=subprocess.PIPE)
        output = proc.communicate()[0].splitlines()
        output.sort()
        output = [ i for i,j in itertools.groupby(output, lambda x: re.split('[:,]', x)[0]) ]
        return output

    def _pics(self):
        extensions = [ '.PDF', '.PNG', '.JPG', '.JPEG', '.EPS', 
                       '.pdf', '.png', '.jpg', '.jpeg', '.eps' ]

        proc = subprocess.Popen(['ls', '-1', os.path.dirname(vim.current.buffer.name)],
               stdout=subprocess.PIPE)

        output = proc.communicate()[0].splitlines()
        pics = [ pic for pic in output if pic[pic.rfind('.'):] in extensions  ]
        return pics

    def findstart(self):

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
            # Return -1 if no match or the position next
            # to comma/brace/backslash
            start = ( start+1 if start != -1 else -1 )
            vim.command('return {0}'.format(start))

    def completions(self):

        compl = []

        # Natbib has \Cite.* type of of commands
        if self.keyword:
            if ( 'cite' in self.keyword or 'Cite' in self.keyword ) and self.bibcompletions: 
                compl = str(self.bibcompletions).decode('string-escape')
            elif 'ref' in self.keyword:
                compl = str(self._labels()).decode('string-escape')
            elif 'font' in self.keyword or 'setmath' in self.keyword:
                compl = str(self._fonts()).decode('string-escape')
            elif 'includegraphics' in self.keyword:
                compl = str(self._pics()).decode('string-escape')

        vim.command('return {0}'.format(compl))

# Cycler interface
class TeXNineCycler(object):
    def __init__(self):
        # Braces
        self.pos = None
        self.iter_obj = {}
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

        for i in self.delimiters.keys():
            self.iter_obj[i] = itertools.cycle(self.delimiters[i])

    def cycle(self, delim):

        win = vim.current.window
        col = win.cursor[1]

        # Empty line
        if not vim.current.line: 
            self.pos = col
            self.iter_obj[delim] = itertools.cycle(self.delimiters[delim])
            return self.iter_obj[delim].next().decode('ascii')

        char = vim.current.line[col-1]

        # Change of position indicates that
        # we need to reset cycler
        if ( col == self.pos or col-1 == self.pos ) and char == delim:
            self.pos = col
            return self.iter_obj[delim].next().decode('ascii')
        else:
            self.pos = col
            self.iter_obj[delim] = itertools.cycle(self.delimiters[delim])
            return self.iter_obj[delim].next().decode('ascii')

# Public classes
document = TeXNineDocument()
cycler = TeXNineCycler()
omni = TeXNineOmni()
snippets = TeXNineSnippets()

PYTHONEOF
        endfunction
call tex_nine#DefPython()
endif


" ******************************************
"          
"            Wrappers for Vim              
"    
" ******************************************

" ******************************************
"     SyncTeX support for Evince 2.32
" ******************************************

if !exists("*tex_nine#SetupSyncTeX")
function! tex_nine#SetupSyncTeX()
python << PYTHONEOF
sys.path.extend([vim.eval('b:pymodules')])
import evince_dbus
import dbus.mainloop.glib

class TeXNineSyncTeX(evince_dbus.EvinceWindowProxy):
    def __init__(self, b, source_handler):
        self.uri = 'file://{0}.pdf'.format(b.buffer.name[:-len('.tex')])
        evince_dbus.EvinceWindowProxy.__init__(self, self.uri, True)
        self.source_handler = source_handler

    def forward_search(self, b):
        self.SyncView(b.buffer.name, b.window.cursor)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

def source_handler(input_file, source_link):
    vim.command('buffer {0}'.format(input_file))
    vim.current.window.cursor = ( int(source_link[0]), 0 )
    vim.command('normal V')

try:
    vimbuffers[vim.current.buffer.name] = TeXNineSyncTeX(vim.current, source_handler)
except NameError:
    vimbuffers = {}
    vimbuffers[vim.current.buffer.name] = TeXNineSyncTeX(vim.current, source_handler)

PYTHONEOF
endfunction
endif

function! tex_nine#SyncView()
    python vimbuffers[vim.current.buffer.name].forward_search(vim.current)
endfunction

" ******************************************
"   Post processing of compilation calls
" ******************************************
function! tex_nine#PostProcess(cwd)
    python document.sanitize_quickfixlist()
    exe 'lcd '.a:cwd
    
    "
    "let qf = filter(getqflist(), 'v:val.valid==1')
    "call setqflist(qf)
endfunction

" ******************************************
"           Compilation calls
" ******************************************
function! tex_nine#QuickCompile()
    echo "Compiling...\r"
    exe "silent make!"
    let numerrors = len(filter(getqflist(), 'v:val.valid==1'))
    echo "Compiling...".numerrors." Error(s)."
endfunction

function! tex_nine#DeepCompile()
    echo "Compiling...\r"
    python document.compile(vim.current.buffer)
    let numerrors = len(filter(getqflist(), 'v:val.valid==1'))
    echo "Compiling...".numerrors." Error(s)."
endfunction

" ******************************************
"            BibTeX support
" ******************************************
function! tex_nine#SetupBibTeX(...)

    " Setup_citekeys returns immediately
    " if omni.bibcompletions is not empty.
    " This is to avoid unnecessary work
    " when opening new tabs/buffers.
    "
    " Only in `update' mode is 
    " omni.bibcompletions updated.

    if exists('a:1') && a:1 == 'update'

        if !exists('g:tex_bibfiles')
            echomsg 'Updating BibTeX entries...None present!'
            return
        else
            python omni.setup_citekeys('g:tex_bibfiles', update=True)
            return
        endif

    else

        python omni.setup_citekeys('g:tex_bibfiles')

    endif


endfunction!

" ******************************************
"          Jump to a bibfile
" ******************************************
function tex_nine#BibQuery()
    python document.query_bibfiles()
endfunction

" ******************************************
"             Omnicompletion
" ******************************************
function! tex_nine#TexComplete(findstart, base)
    if a:findstart
        python omni.findstart()
    else
        python omni.completions()
    endif
endfunction

" ******************************************
"             Update Header
" ******************************************
function! tex_nine#UpdateWithLastMod()
    python document.set_header(vim.current.buffer)
endfunction

" ******************************************
"            Set up snippets
" ******************************************
function! tex_nine#SetupSnippets(snipfile)
    python snippets.setup_snippets(vim.eval('a:snipfile'))
endfunction

" ******************************************
"            Insert snippets
" ******************************************
function! ListEnvCompletions(A,L,P)
   " Breaks if dictionary is a list
   " but we only support one dictionary
   " at the moment
   if filereadable(&dictionary)
       return join(readfile(&dictionary), "\<nl>")
   else
       return []
   endif
endfunction

function! tex_nine#InsertEnvironment(...)

        let s:envkey = exists('a:1') ? a:1 : input('Environment: ', '',
                                                \'custom,ListEnvCompletions')
        if s:envkey != "" 
            python snippets(vim.eval('s:envkey'))
        else
            return "\<Esc>"
        endif

endfunction

" ******************************************
"       Insert the skeleton file
" ******************************************
function! tex_nine#InsertTemplate(skeleton)
   python document.insert_skeleton(vim.eval('a:skeleton'), vim.current.buffer)
   update
   edit
endfunction

" ******************************************
"           Cycler interface
" ******************************************
function! tex_nine#Cycle(delim)
    python vim.command('return "{0!s}"'.format(cycler.cycle(vim.eval('a:delim'))))
endfunction

" ******************************************
"   Implentation of omnicompletion calls
" ******************************************
function! tex_nine#SmartInsert(keyword,...)
        " Keyword = TeX statement, e.g. \cite
        " Extra arguments may specify the pattern to be
        " matched, e.g \[cC]ite for natbib compatibility.

        let pattern = exists('a:1') ? '\'.a:1 : '\'.a:keyword
        let line = getline('.')
        let pos = col('.')

        if line =~ pattern && line[pos-1:] =~ ',\|{\|}'
                return ""
        else
                return a:keyword.""
        endif
endfunction
"

" ******************************************
"      Helper function for completions
" ******************************************
function! tex_nine#IsLeft(lchar)

        let left = getline('.')[col('.')-2]

        if left == a:lchar
                return 1
        else
                return 0
        endif

endfunction


" ******************************************
"          Text Object for $$
" ******************************************
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

" ******************************************
"     Text Object for \begin{}...\end{}
"              requires matchit
" ******************************************
function! tex_nine#TeXParagraph(mode)

        let ismath = synIDattr(synID(line("."), 1, 1), "name") 
        let line = getline('.')
        let stroke = "V%"
        let opts = ["jOk","kOj"]

        if getline('.')[col('.')-1] =~ '[{}]'
                let stroke = "0".stroke
        endif

        " Revamp 'paragraph' only if matchit
        " is enabled.

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

" ******************************************
"           Format expression
" ******************************************


" vim:tw=78:ts=8:sw=4:et
