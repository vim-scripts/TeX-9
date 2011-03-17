if !has('python') || !has('syntax')
    echoerr "Error: TeX_9 requires Vim compiled with +python and +syntax"
    finish
endif

" ******************************************
"          TeX_9 function library
"              in Public Domain
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

# Snippets
class TeXNineSnippets(object):
    """
    Snippet engine for TeX_9

    Call `setup_snippets(fname)' to build up a list of
    snippets. Each entry is a dictionary with entries
    `abbr' and `word' in accordance with Vim's data model for
    completions. Insert snippets to Vim buffers by calling the
    class instance with keyword string, e.g. `equation'.

    """
    def __init__(self):
        self._snippets = []

    def _parser(self, string):
        lines = string.splitlines(True)

        # Format the snippet 
        lines = filter( lambda x: '#' not in x, 
                map(lambda y: y.lstrip(' '), lines) )

        if lines:
            word = "".join(lines[1:]).rstrip('\n')
            return {'abbr':str(lines[0]).rstrip('\n'),
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

            generic_snippet = "\\begin{"+label+"}\\end{"+label+"}"+""+str(row)+"Gi"
            vim.command("return '{0!s}'".format(generic_snippet))

        elif vim.eval('&ft') == 'bib':
            vim.command('echoerr "No such BibTeX entry type: {0}"'.format(label))


# Omnicompletion
class TeXNineOmni(object):
    """
    Omni-completion handler for TeX_9

    Currently, citations and label references are completed.
    Call `setup_citekeys(filelist)' to build a list of citation
    entries from filelist. Labels are searched only from the current
    buffer.

    """
    def __init__(self):
        self.keyword = None
        self.bibcompletions = []
        self.errormsg = "echoerr 'The BibTeX file you defined was invalid: {0}.'"
        self.updatemsg = "echomsg 'Updating BibTeX entries...'"

    def _bibparser(self, fname):
        try:
            pat = re.compile('^@\w+{(\S+),', re.M)
            with open(fname.encode('string-escape')) as f:
                return pat.findall(f.read(), re.M)

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
        bibfiles = vim.eval(filelist)

        if update:
            vim.command(self.updatemsg)
        elif self.bibcompletions:
            return

        self.bibcompletions = []
        for bibfile in bibfiles:
            proc = subprocess.Popen(['kpsewhich','-must-exist', bibfile],
                                    stdout=subprocess.PIPE)
            bibpath = proc.communicate()[0].strip('\n')

            # kpsewhich returns the empty string
            # in all such cases where the file couldn't be found
            # irrespective of $TEXMFHOME
            if bibpath:
                citekeys = self._bibparser(bibpath)
            else:
                vim.command(self.errormsg.format(bibfile))
                continue

            # Appending an empty list is a NOP
            self.bibcompletions += citekeys

    # Labels
    def _labels(self):
        vim.command('update')
        pat = re.compile('\\\\label{(\S+)}')
        return pat.findall("\n".join(vim.current.buffer[:]))

    def findstart(self):

        win = vim.current.window
        line = vim.current.line[:win.cursor[1]]

        start = max((line.rfind('{'),
                     line.rfind(',')))

        try:
            keyword = re.findall('\\\\([\w*]+){', line)[-1]
            self.keyword = keyword
        except IndexError:
            self.keyword = None

        finally:
            # Return -1 if no match or the position next
            # to comma/brace/backslash
            start = ( start+1 if start != -1 else -1 )
            vim.command('return {0}'.format(start))

    def completions(self):

        # Natbib has \Cite.* type of of commands
        if ( 'cite' in self.keyword or 'Cite' in self.keyword ) and self.bibcompletions: 
            compl = str(self.bibcompletions).decode('string-escape')
        elif 'ref' in self.keyword:
            compl = str(self._labels()).decode('string-escape')
        else:
            compl = []

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

def tex_nine_header(label='%  Last Change:',
                    timestring='%Y %b %d'):
    b = vim.current.buffer
    date = time.strftime(timestring)
    if len(b) >= 10 and vim.eval('&modifiable'):
        for i in range(10):
            if label in str(b[i]) and date not in str(b[i]):
                b[i] = '{0} {1}'.format(label, date)
                return

def tex_nine_skeleton(fname,
                      timestring='%Y %b %d'):
    with open(fname) as skeleton:
        b = vim.current.buffer
        template = Template(skeleton.read())

        skeleton = template.safe_substitute(_file=os.path.basename(b.name),
                                _date_created=time.strftime(timestring),
                                _author=getuser())

        b[:] = skeleton.splitlines(True)

def tex_nine_quickfix():
    ignored = ['Underfull','Overfull'] # More to come

    # Too bad LaTeX spits out hard wrapped output. This
    # causes problems with long error messages.
    qf = vim.eval('getqflist()')
    qf = filter(lambda x: int(x['valid'])
                and all( i not in x['text'] for i in ignored ), qf)
    # This is just to sedate Vim not to send the paradoxical 
    # error message `No errors' when there are no errors!
    if not qf:
        qf.append({ 'text':'TeX_9: No errors.' })
                    

    vim.command('call setqflist({0})'.format(qf))

# Public classes
cycler = TeXNineCycler()
omni = TeXNineOmni()
snippets = TeXNineSnippets()

sys.path.extend(['.','..'])
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
"   Post processing of compilation calls
" ******************************************
function! tex_nine#PostProcess(cwd,...)
    python tex_nine_quickfix()
    exe 'lcd '.a:cwd
endfunction

" ******************************************
"            BibTeX support
" ******************************************
function! tex_nine#SetupBibTeX(...)

    if exists('a:1') && a:1 == 'update'
        python omni.setup_citekeys('g:tex_bibfiles', update=True)
        return
    endif

    python omni.setup_citekeys('g:tex_bibfiles')

endfunction!

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
    python tex_nine_header()
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
   python tex_nine_skeleton(vim.eval('a:skeleton'))
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


