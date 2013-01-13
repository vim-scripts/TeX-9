# -*- coding: utf-8 -*-
#************************************************************************
#
#                     TeX 9 library: Python module
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program. If not, see <http://www.gnu.org/licenses/>.
#                    
#    Copyright Elias Toivanen, 2011, 2012
#
#************************************************************************

# Short summary of the module:
#
# Defines two main objects TeXNineDocument and TeXNineOmni that are
# meant to handle editing and completion tasks. Both of these classes
# are singletons. 

import vim
import re
import subprocess
import os
import sys
import logging

from getpass import getuser
from time import strftime
from itertools import groupby
from string import Template

# Switch debugging on/off 
#logging.basicConfig(level=logging.DEBUG, stream=sys.stdout)
logging.basicConfig(level=logging.ERROR)

logging.debug("TeX 9: Entering the Python module")
sys.path.extend([vim.eval('b:tex_pymodules')])

from tex_nine_symbols import tex_nine_maths_cache
import tex_nine_utils as utils

class TeXNineBase(object):
    """Singleton base class for TeX 9.
    
    * Handles error reporting 
    * Finds the master file in a multi-file LaTeX project  

    """

    _instance = None

    messages = {

    'NO_BIBTEX': 'No BibTeX databases present...',
    'UPDATING_ENTRIES' : 'Updating BibTeX entries...',
    'INVALID_BIBFILE': 'Invalid BibTeX file: `{0}\'',
    'INVALID_BIBENTRY_TYPE': 'No such BibTeX entry type: `{0}\'',
    'INVALID_BIBENTRY': 'Following BibTeX entries are undefined: {0}', 
    'INVALID_MODELINE': 'Cannot find master file `{0}\'',
    'NO_MODELINE':  r'Cannot find master file: no modeline or \\documentclass statement'

    }

    def __new__(self, *args, **kwargs):
        if self._instance is None:
            self.buffers = {}
            self._instance = object.__new__(self)
        return self._instance

    def echoerr(self, errorstr):
        vim.command('echoerr "{0}"'.format(errorstr))

    def echomsg(self, msgstr):
        vim.command('echomsg "{0}"'.format(msgstr))

    def find_master_file(self, vimbuffer, nlines=3):
        """Finds the filename of the master file in a LaTeX project.

        Checks if `fname' contains a \documentclass statement and sets
        the master file to fname itself. Otherwise checks the
        `nlines' first and `nlines' last lines for modeline of the form

        % mainfile: <master_file>

        where <master_file> is the path of the master file relative to
        `fname', e.g. ../main.tex.

        """
        this_file = vimbuffer[:] 

        if re.search(r'^\\documentclass', "\n".join(this_file), re.M):
            self.buffers[vimbuffer.name]['master'] = vimbuffer.name
            return

        try:
            modeline = "\n".join(this_file[:nlines]+this_file[-nlines:])
            match = re.search(r'^\s*%\s*mainfile:\s*(\S+)', modeline, re.M)
            if match:
                master_file = os.path.join(os.path.dirname(vimbuffer.name),
                                           match.group(1))
                master_file = os.path.abspath(master_file)
                if os.path.exists(master_file):
                    self.buffers[vimbuffer.name]['master'] = master_file
                    return
                else:
                    self.buffers[vimbuffer.name]['master'] = None
                    e = self.messages['INVALID_MODELINE'].format(match.group(1)) 
                    raise utils.TeXNineError(e)

            # There were enough lines but no match
            self.buffers[vimbuffer.name]['master'] = None

        except IndexError:
            # not enough text in the buffer, try searching later
            self.buffers[vimbuffer.name]['master'] = None

    def get_master_file(self, vimbuffer):
        """Fetches the filename of the master file in a LaTeX project."""
        if self.buffers[vimbuffer.name]['master'] is None:
            self.find_master_file(vimbuffer)
        return self.buffers[vimbuffer.name]['master']

    @staticmethod
    def multi_file(f):
        """Decorates methods that need to know the actual master file in
        a multi-file project."""
        def new_f(self, master_file, *args, **kwargs):

            try:

                master_file = self.get_master_file(vim.current.buffer)
                if master_file is None:
                    raise utils.TeXNineError(self.messages['NO_MODELINE'])
                else:
                    return f(self, master_file, *args, **kwargs)

            except utils.TeXNineError, e:
                self.echoerr(e)
                return

        return new_f

class TeXNineBibTeX(TeXNineBase):
    """A class to gather BibTeX entries in a list."""

    _bibcompletions = []
    _bibpaths = []

    def __init__(self, bibfiles):
        self.bibfiles = bibfiles

    def _bibparser(self, fname):
        """Opens a file and extracts all BibTeX entries in it."""

        try:
            with open(fname) as f:
                logging.debug("TeX 9: Reading BibTeX entries from `{0}'".format(os.path.basename(fname)))
                return re.findall('^@\w+ *{([^, ]+) *,', f.read(), re.M)

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
        that is shipped with the standard TeXLive distribution.

        [1] http://www.tug.org/tds/tds.html#BibTeX
        """

        if update:
            self.echomsg(self.messages["UPDATING_ENTRIES"])
            self._bibpaths = []
            self._bibcompletions = []

        if self._bibcompletions and self._bibpaths: 
            # Return early 
            return

        for b in bibfiles:
            # Give precedence to bibfiles that are in the compilation folder.
            dirname = os.path.dirname(vim.current.buffer.name)
            bibtemp = os.path.join(dirname, b)

            b = ( bibtemp if os.path.exists(bibtemp) else b )
            proc = subprocess.Popen(['kpsewhich','-must-exist', b],
                                    stdout=subprocess.PIPE)
            bibpath = proc.communicate()[0].strip('\n')

            # kpsewhich returns either the complete path or an empty string.
            if bibpath:
                self._bibpaths += [bibpath]
                self._bibcompletions += self._bibparser(bibpath)
            else:
                self.echoerr(self.messages["INVALID_BIBFILE"].format(b))

    # Lazy load
    def get_bibpaths(self):
        if not self._bibpaths:
            self.setup_bibtex_entries(self.bibfiles)
        return self._bibpaths

    def get_bibentries(self):
        if not self._bibcompletions:
            self.setup_bibtex_entries(self.bibfiles)
        return self._bibcompletions

class TeXNineOmni(TeXNineBibTeX):
    """Vim's omni completion for a LaTeX document.

    findstart() finds the position where completion should start and
    stores the relevant `keyword'. An appropiate list is then returned
    based on the keyword.
    
    Following items are completed via omni completion

    *   BibTeX entries
    *   Labels for cross-references
    *   Font names when using `fontspec'
    *   Picture names when using `graphicx' (EPS, PNG, JPG, PDF)
    *   Maths statements
    
    """

    def __init__(self, bibfiles=[]):
        TeXNineBibTeX.__init__(self, bibfiles)
        self.keyword = None

    def _labels(self, text, fname):
        """Labels for references.

        Searches \label{} statements in the current file and files that
        are included with \include{} and \input{} statements. Caveat:
        thanks to TeX's clunky design, included files cannot contain
        "special" characters such as whitespace.
        """

        labels = []
        included = set([])

        vim.command('update')
        cwd, basename = os.path.split(fname)

        pat = re.compile(r'\\label{(?P<label>[^,}]+)}|\\in(?:clude|put){(?P<fname>[^}]+)}')

        for m in pat.finditer(text):
            if m.group('label'):
                labels.append({'word': m.group('label'), 'menu': basename})
                continue

            elif m.group('fname'):
                fname = m.group('fname')
                if not fname.endswith('.tex'):
                    fname += '.tex'
                included.add(os.path.join(cwd, fname))

        for fname in included:
            try:
                logging.debug("TeX 9: Reading `{0}'".format(fname))
                with open(fname, 'r') as f:
                    labels += self._labels(f.read(), fname)
            except IOError, e:
                logging.debug(str(e).decode('string-escape'))

        return labels

    def _fonts(self):
        """Installed fonts.
        
        WARNING: Linux only
        """
        proc = subprocess.Popen('fc-list',
                                stdout=subprocess.PIPE)
        output = proc.communicate()[0].splitlines()
        output.sort()
        output = [ i for i,j in groupby(output, lambda x: re.split('[:,]', x)[0]) ]
        return output

    def _pics(self):
        """Picture completion."
        
        Checks the compilation directory and its subdirectories.
        """
        extensions = [ '.PDF', '.PNG', '.JPG', '.JPEG', '.EPS', 
                       '.pdf', '.png', '.jpg', '.jpeg', '.eps' ]

        path, subdirs, files = next(os.walk(os.path.dirname(vim.current.buffer.name)))
        pics = [ pic for pic in files if pic[pic.rfind('.'):] in extensions ]
        for d in subdirs:
            files = os.listdir(os.path.join(path, d))
            pics += [ os.path.join(d, pic) for pic in files if pic[pic.rfind('.'):] in extensions ] 
        return pics

    def findstart(self):
        """Finds the cursor position where completion starts."""

        row, col = vim.current.window.cursor
        line = vim.current.line[:col]
        pat = re.compile(r'\\(\w+)(?:[(].+[)])?(?:[[].+[]])?{?')

        start = max((line.rfind('{'),
                     line.rfind(','),
                     line.rfind('\\')))
        try:
            # Starting at a backslash and there is no keyword.
            if '\\' in line[col - 1:col]: 
                self.keyword = ""
            else:
                # There can be a keyword: grab it! 
                self.keyword = pat.findall(line)[-1]
        except IndexError:
            self.keyword = None

        finally:

            if start == -1:
                pass
            elif ' ' in line[start:]:
                # Let's not move the cursor too aggresively.
                start = -1
                self.keyword = None
            else:
                start += 1

            vim.command('return {0}'.format(start))

    def completions(self):
        """Selects what type of omni completion should occur."""

        compl = []

        # Select completion based on keyword
        if self.keyword is not None:
            # Natbib has \Cite.* type of of commands
            if 'cite' in self.keyword or 'Cite' in self.keyword: 
                compl = self.get_bibentries()
            elif 'ref' in self.keyword:
                compl = self._labels("\n".join(vim.current.buffer), vim.current.buffer.name)
            elif 'font' in self.keyword or 'setmath' in self.keyword:
                compl = self._fonts()
            elif 'includegraphics' in self.keyword:
                compl = self._pics()
            elif utils.is_latex_math_environment(vim.current.window): 
                logging.debug('TeX 9: Found a LaTeX maths environment')
                if not self.keyword:
                    compl = tex_nine_maths_cache
                else:
                    compl = [ c for c in tex_nine_maths_cache if
                             c['word'].startswith(self.keyword) ]

        vim.command('return {0}'.format(str(compl).decode('string-escape')))

class TeXNineSnippets(object):
    """Snippet engine for TeX 9.

    """
    _snippets = {'tex': {}, 'bib': {}}

    def _parser(self, string):
        """Returns a 2-tuple with the snippet keyword and corresponding
        snippet content."""

        # String to list, preserving carriage returns
        lines = string.splitlines(True) 

        # Format the snippet 
        lines = [ line.lstrip(' ') for line in lines if
                 '#' not in line ]

        if lines:
            snippet = "".join(lines[1:]).rstrip('\n')
            keyword = str(lines[0].rstrip('\n'))
            return (keyword, snippet)
        else:
            return ()

    def setup_snippets(self, fname, ft):
        """Builds a dictionary of keyword-snippet pairs.

        Extracts snippets out of ``fname'' whose syntax resembles that
        of Michael Sander's snipMate plugin. Both BibTeX and LaTeX
        buffers get their own dictionary.  
        """

        if self._snippets[ft]:
            # We have the snippets already
            return

        logging.debug("TeX 9: Reading snippets from `{0}'".format(os.path.basename(fname)))
        with open(fname) as snipfile:

            # Strip trailing empty lines
            snippets = snipfile.read().rstrip('\n').split('snippet')
            snippets = map(self._parser, snippets)
            snippets = filter(None, snippets) # Remove comments

            self._snippets[ft] = dict(snippets)

    def insert_snippet(self, keyword, ft):
        """Inserts snippets into the current Vim buffer.
        
        Fetches and returns the code snippet corresponding to key
        ``keyword'' from the snippet dictionary that belongs to the
        filetype ``ft''.

        If the snippet is not found, generic environment is inserted in
        LaTeX files and error is raised in BibTeX files.  After the
        snippet is inserted, cursor position is returned to the original
        position with Vim's ``context mark'' syntax.

        This method is hooked to a <expr> mapping and thus it returns a
        string that Vim then automatically indents.

        """

        try:
            snippet = self._snippets[ft][keyword]
            snippet = "m`i"+snippet+"``"
        except KeyError:
            if ft == 'tex':
               snippet = ( "m`i"+
                           "\\begin{"+keyword+"}\n\\end{"+keyword+"}"+
                           "``" 
                         )
            elif ft == 'bib':
                self.echoerr(self.messages["INVALID_BIBENTRY_TYPE"].format(keyword))
                snippet = ""

        vim.command("return '{0}'".format(snippet))

class TeXNineDocument(TeXNineBase, TeXNineSnippets):
    """A class to manipulate LaTeX documents in Vim.
    
    TeXNineDocument can

    * Insert a skeleton file into the current Vim buffer
    * Update the dynamic content in the skeleton header
    * Compile a LaTeX document (updating the BibTeX references if desired)
    * Launch a viewer application
    * Sanitize Vim's ``quickfixlist''
    * Preview the definition of a BibTeX entry based on its keyword
    * Insert LaTeX/BibTeX code snippets
    * Send current cursor position to an Evince window for highligting

    Methods that are decorated with TeXNineBase.multi_file are designed
    to also work in multi-file LaTeX projects.
    
    """

    def __init__(self, vimbuffer, 
                 compiler="", viewer={}, label='%  Last Change:', timestr='%Y %b %d'):

        TeXNineSnippets.__init__(self)

        if compiler:
            self.compiler = compiler

        if viewer:
            self.viewer = viewer

        self.label = label
        self.timestr = timestr
        self.buffers[vimbuffer.name] = {
            
            # Buffer is not always accessible. Vim bug?
            'buffer': vimbuffer,
            'ft': vim.eval('&ft'),
            'synctex': None,
            'master': None
        }

    def set_forward_search(self, vimbuffer, evince_proxy):
        """Connects vimbuffer to an Evince window via a proxy."""
        self.buffers[vimbuffer.name]['synctex'] = evince_proxy

    @TeXNineBase.multi_file
    def forward_search(self, fname, vimcurrent):
        """Highligts current cursor position in Evince."""

        s = self.buffers[fname]['synctex']
        if s is not None: 
            syncstr = "TeX 9: master={0}, row={1[0]}, col={1[1]}" 
            logging.debug(syncstr.format(fname,
                                         vimcurrent.window.cursor))
            s.forward_search(vimcurrent.buffer.name, vimcurrent.window.cursor)
            return

    @TeXNineBase.multi_file
    def compile(self, fname, quick=False):
        """Compiles the current LaTeX manuscript.

        Vim's `make' command is only called once to avoid overhead that
        might result from additional processing routines.
        """

        cwd, basename = os.path.split(fname)

        if not quick:
            tex_cmd = [self.compiler,
                       '-output-directory='+cwd,
                       '-interaction=batchmode',
                       fname]
            bib_cmd = ['bibtex', basename[:-len('.tex')]+'.aux']
            kwargs = {'stdout': subprocess.PIPE, 'cwd': cwd}

            subprocess.Popen(tex_cmd, **kwargs).wait()
            stdout, stderr = subprocess.Popen(bib_cmd, **kwargs).communicate() 
            matches = re.findall('I didn.t find a database entry for .(\S+).', stdout)

            # BibTeX does not report the location where the undefined entries are :-(
            if matches:
                e = ", ".join(matches)
                e = self.messages['INVALID_BIBENTRY'].format(e)
                raise utils.TeXNineError(e)
            subprocess.Popen(tex_cmd, **kwargs).wait()

        # Create quickfix list 
        # NB: SyncTeX requires full and escaped path
        vim.command('silent make! {0}'.format(fname.replace(' ','\ ')))

    @TeXNineBase.multi_file
    def view(self, fname):
        """Launches the viewer application.

        The process is started in the background by the system shell.

        WARNING: *NIX only
        """

        cmdstr = '{0[app]} "{1}.{0[target]}" &' 
        cmd = cmdstr.format(self.viewer, fname[:-len('.tex')])
        subprocess.call(cmd, shell=True)

    def postmake(self):
        """Filters invalid and irrelevant error messages that LaTeX
        compilers produce. Relies on Vim's Quickfix mechanism."""

        ignored = ['Overfull', 
                   'Underfull'] # Hack to your taste

        # Only valid errors
        qflist = ( entry for entry in vim.eval('getqflist()') if
                  int(entry['valid']) )

        # Remove some irrelevant "errors"
        qflist = [ entry for entry in qflist if 
                  all( i not in entry['text'] for i in ignored) ]

        vim.command('call setqflist({0})'.format(qflist))

    def insert_skeleton(self, skeleton_file, vimbuffer):
        """Insert a skeleton of a LaTeX manuscript."""

        with open(skeleton_file) as skeleton:
            template = Template(skeleton.read())
            skeleton = template.safe_substitute(_file = os.path.basename(vimbuffer.name),
                                                _date_created = strftime(self.timestr),
                                                _author = getuser())

            vimbuffer[:] = skeleton.splitlines(True)

    def update_header(self, vimbuffer):
        """Updates the date label in the header."""

        date = strftime(self.timestr)
        if len(vimbuffer) >= 10 and int(vim.eval('&modifiable')):
            for i in range(10):
                if self.label in str(vimbuffer[i]) and date not in str(vimbuffer[i]):
                    vimbuffer[i] = '{0} {1}'.format(self.label, date)
                    return

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
                    vim.command('windo if &pvw|normal zR|endif') # Unfold
                    vim.command("redraw") # Needed after opening a preview window.
                    return

            except IOError:
                self.echoerr(self.messages["INVALID_BIBFILE"].format(bibfile))

        # No matches in any of the bibfiles
        self.echomsg(self.messages["INVALID_BIBENTRY"].format(cword))

logging.debug("TeX 9: Done with the Python module")

# vim: tw=72 fdm=indent fdn=2
