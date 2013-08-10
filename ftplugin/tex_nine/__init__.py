# -*- coding: utf-8 -*-
#************************************************************************
#
#                     TeX-9 library: Python module
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
#    Copyright Elias Toivanen, 2011, 2012, 2013
#
#************************************************************************

# Short summary of the module:
#
# Defines two main objects TeXNineDocument and TeXNineOmni that are
# meant to handle editing and completion tasks. Both of these classes
# are singletons. 

# System modules
import vim
import sys
import re
import subprocess
import os
import os.path as path
import logging

from getpass import getuser
from time import strftime
from itertools import groupby
from string import Template

#Local modules
# config = vim.bindeval('b:tex_nine_config')
# TODO: Remove vim.eval() in favor of vim.bindeval() 
# TODO: Separate python module from b:tex_nine_config
# Older Vim's do not have bindeval
config = vim.eval('b:tex_nine_config')
config['disable'] = int(config['disable'])
config['debug'] = int(config['debug'])
config['synctex'] = int(config['synctex'])
config['verbose'] = int(config['verbose'])

sys.path.extend([config['_pypath']])
from tex_nine_symbols import tex_nine_maths_cache
from tex_nine_utils import *

# Control debugging
if config['debug']:
    logging.basicConfig(level=logging.DEBUG, stream=sys.stdout)
else:
    logging.basicConfig(level=logging.ERROR)

# Control SyncTeX
# TODO: Python 3 support
if config['synctex']:
    if int(vim.eval("has('gui_running')")):
        if not int(vim.eval("has('python3')")): 
            logging.debug("TeX-9: Importing tex_nine_synctex") 
            # NB: Important side effect: Vim will be hooked to the DBus session daemon
            import tex_nine_synctex
        else:
            echoerr("Must not have +python3 when using SyncTeX.")
    else:
        echomsg("SyncTeX not available in terminal.")

# Miscellaneous extra settings
config['_datelabel'] = '%  Last Change:'
config['_timestr'] = '%Y %b %d'

# Start of the main module
logging.debug("TeX-9: Entering the Python module.")

messages = {
        'NO_BIBTEX': 'No BibTeX databases present...',
        'INVALID_BIBFILE': 'Invalid BibTeX file: `{0}\'',
        'INVALID_BIBENTRY_TYPE': 'No such BibTeX entry type: `{0}\'',
        'INVALID_BIBENTRY': 'Following BibTeX entry is invalid: {0}', 
        'INVALID_MODELINE': 'Cannot find master file `{0}\'',
        'NO_MODELINE':  'Cannot find master file: no modeline or \documentclass statement',
        'MASTER_NOT_ACTIVE': 'Please have the master file `{0}\' open in Vim.',
        'NO_OUTPUT':  'Output file `{0}\' does not exist.',
        'INVALID_HEADER': r'Missing information in header.',
        'NO_BIBSTYLE': r'No bibliography style found in the document.',
        'NO_COMPILER': r'Compiler unknown.'
}

class TeXNineBase(object):
    """Singleton base class for TeX-9."""

    _instance = None
    buffers = {}

    def __new__(self, *args, **kwargs):
        if self._instance is None:
            self._instance = object.__new__(self)
        return self._instance

    def add_buffer(self, vimbuffer):
        """Add vimbuffer to buffers.
        
        Does not override existing entries.
        """
        logging.debug("TeX-9: Adding `{0}\' to buffer dict.".format(vimbuffer.name))
        bufinfo = {
            'ft' : vim.eval('&ft'),
            'master': "",
            'buffer': vimbuffer,
            'synctex': None
        }

        self.buffers.setdefault(vimbuffer.name, bufinfo)
        return

    def find_master_file(self, vimbuffer, nlines=3):
        """Finds the filename of the master file in a LaTeX project.

        Checks if `vimbuffer' contains a \documentclass statement and sets
        the master file to `vimbuffer.name'. Otherwise checks the
        `nlines' first and `nlines' last lines for modeline of the form

        % mainfile: <master_file>

        where <master_file> is the path of the master file relative to
        the master file, e.g. ../main.tex.

        Raises `TeXNineError' if master cannot be found.

        """

        # Most often this is the case
        for line in vimbuffer:
            if '\\documentclass' in line: 
                return vimbuffer.name

        # Look for modeline
        for line in vimbuffer[:nlines]+vimbuffer[-nlines:]:
            match = re.search(r'^\s*%\s*mainfile:\s*(\S+)', line)
            if match:
                master_file = path.join(path.dirname(vimbuffer.name),
                                        match.group(1))
                master_file = path.abspath(master_file)

                if path.exists(master_file):
                    return master_file
                else:
                    e = messages['INVALID_MODELINE'].format(match.group(1)) 
                    raise TeXNineError(e)

        # Empty buffer, no match or no read access to master 
        raise TeXNineError(messages['NO_MODELINE'])

    def get_master_file(self, vimbuffer):
        """Returns the filename of the master file."""

        if not self.buffers[vimbuffer.name]['master']:
            master = self.find_master_file(vimbuffer)
            self.buffers[vimbuffer.name]['master'] = master

            # Make sure master knows it's the master
            masterinfo = self.buffers.get(master)
            if masterinfo is not None:
                masterinfo['master'] = master

        return self.buffers[vimbuffer.name]['master']

    @staticmethod
    def multi_file(f):
        """Decorates methods that need to know the actual master file in
        a multi-file project.
        
        The decorator swaps passed vim.buffer object to the vim.buffer object
        of the master file.

        When calling a decorated method, `TeXNineError' has to be caught.

        """
        def new_f(self, vimbuffer, *args, **kwargs):

            master = self.get_master_file(vimbuffer)
            masterbuffer = self.buffers.get(master)
            if masterbuffer is None:
                # Master is not loaded yet
                # NB: badd does not make the master buffer active so 
                # decorated methods are not guaranteed to get read access to
                # the master buffer.
                vim.command('badd {0}'.format(master.replace(' ', '\ ')))
                for b in vim.buffers:
                    if b.name == master:
                        break
                self.add_buffer(b) 
                self.buffers[master]['master'] = master
                masterbuffer = self.buffers[master]

            return f(self, masterbuffer['buffer'], *args, **kwargs)

        return new_f

class TeXNineBibTeX(TeXNineBase):
    """A class to gather BibTeX entries in a list.

    After instantiation, this object tries to figure out
    all BibTeX files in a project by looking at the master file
    containing the \\bibliography{...} statement.

    Alternatively, this behavior may be overridden by providing
    a list of absolute paths to the BibTeX files:

    # Let the object figure out everything
    omni = TeXNineBibTeX()
    entries = omni.bibentries

    # DIY
    omni = TeXNineBibTeX()
    omni.bibpaths = [path1, path2,...]
    entries = omni.bibentries

    # Update entries
    omni.update() #or omni.update(my_new_paths)
    
    """

    _bibcompletions = []
    _bibpaths = set([])

    def _bibparser(self, fname):
        """Opens a file and extracts all BibTeX entries in it."""
        try:
            with open(fname) as f:
                logging.debug("TeX-9: Reading BibTeX entries from `{0}'".format(path.basename(fname)))
                return re.findall('^@\w+ *{\s*([^, ]+) *,', f.read(), re.M)

        except IOError:
            echoerr(messages["INVALID_BIBFILE"].format(fname))
            return []

    @property
    def bibpaths(self):
        return self.get_bibpaths(vim.current.buffer)

    @bibpaths.setter
    def set_bibpaths(self, paths):
        for p in paths: 
            self._bibpaths.add(p)
        self._bibcompletions = []
        return

    @property
    def bibentries(self):
        return self.get_bibentries()

    # Lazy load
    @TeXNineBase.multi_file
    def get_bibpaths(self, vimbuffer, update=False):
        """Returns the BibTeX files in a LaTeX project.

        Reads the master file to find out the names of BibTeX files.
        Files in the compilation folder take precedence over files
        located in a TDS tree[1]. 

        * Requires the program ``kpsewhich''
        that is shipped with the standard TeXLive distribution.

        [1] http://www.tug.org/tds/tds.html#BibTeX
        """

        if not self._bibpaths or update:
            # Find out the bibfiles in use
            master = vimbuffer.name 
            masterbuffer = "\n".join(vimbuffer[:])
            if not masterbuffer:
                e = messages['MASTER_NOT_ACTIVE'].format(path.basename(master))
                raise TeXNineError(e)
            else:
                match = re.search(r'\\bibliography{([^}]+)}',
                                  masterbuffer)
                if not match:
                    e = messages['NO_BIBTEX']
                    raise TeXNineError(e)

                bibfiles = match.group(1).split(',')
                dirname = path.dirname(master)
                # Find the absolute paths of the bibfiles
                for b in bibfiles:
                    b += '.bib'
                    # Check if the bibfile is in the compilation folder
                    bibtemp = path.join(dirname, b)
                    b = ( bibtemp if path.exists(bibtemp) else b )
                    # Get the path with kspewhich
                    proc = subprocess.Popen(['kpsewhich','-must-exist', b],
                                            stdout=subprocess.PIPE)
                    bibpath = proc.communicate()[0].strip('\n')
                    # kpsewhich return either the full path or an empty
                    # string.
                    if bibpath:
                        self._bibpaths.add(bibpath)
                    else:
                        raise TeXNineError(messages["INVALID_BIBFILE"].format(b))

        return list(self._bibpaths)

    def get_bibentries(self):
        """Returns a list of BibTeX entries found in the BibTeX files."""
        if not self._bibcompletions:
            bibpaths = self.get_bibpaths(vim.current.buffer)
            for b in bibpaths:
                self._bibcompletions += self._bibparser(b)
        return self._bibcompletions

    def update(self, bibpaths=[]):
        self._bibcompletions = []
        self._bibpaths.clear()
        if bibpaths:
            for p in bibpaths: 
                self._bibpaths.add(p)
        else:
            self.get_bibpaths(vim.current.buffer, update=True)

class TeXNineOmni(TeXNineBibTeX):
    """Vim's omni completion for a LaTeX document.

    findstart() finds the position where completion should start and
    stores the relevant `keyword'. An appropiate list is then returned
    based on the keyword.
    
    Following items are completed via omni completion

    *   BibTeX entries
    *   Labels for cross-references
    *   Font names when using `fontspec' or 'unicode-math'
    *   Picture names when using `graphicx' (EPS, PNG, JPG, PDF)
    
    """

    def __init__(self, bibfiles=[]):
        self.keyword = None

    @TeXNineBase.multi_file
    def _labels(self, vimbuffer,
                pat=re.compile(r'\\label{(?P<label>[^,}]+)}|\\in(?:clude|put){(?P<fname>[^}]+)}')):
        """Labels for references.

        Searches \label{} statements in the master file and in
        \include'd and \input'd files. 
        
        * Thanks to TeX's clunky design, included files cannot contain
        "special" characters such as whitespace.
        """

        vim.command('update')
        labels = []
        masterbuffer = "\n".join(vimbuffer[:])
        master_folder, basename  = path.split(vimbuffer.name)
        match = pat.findall(masterbuffer)

        if not match:
            if not masterbuffer:
                e = messages['MASTER_NOT_ACTIVE'].format(basename)
                raise TeXNineError(e)
            logging.debug('TeX-9: Found {0} labels'.format(len(labels)))
            return labels

        labels, included = zip(*match)
        labels = filter(None, labels)
        included = filter(None, included)

        labels = [dict(word=i, menu=basename) for i in labels]
        for fname in included:

            logging.debug("TeX-9: Reading from included file `{0}'...".format(fname))

            if not fname.endswith('.tex'):
                fname += '.tex'

            try:
                with open(path.join(master_folder, fname), 'r') as f:
                    inc_labels = re.findall(r'\\label{(?P<label>[^,}]+)}',
                                            f.read()) 
                    inc_labels = [dict(word=i, menu=fname) for i in inc_labels] 
                    labels += inc_labels
            except IOError, e:
                # Do not raise an error because the \include statement might
                # be commented
                logging.debug(str(e).decode('string_escape'))

        logging.debug('TeX-9: Found {0} labels'.format(len(labels)))
        return labels

    def _fonts(self):
        """Installed fonts.

        WARNING: Requires fontconfig.
        """
        proc = subprocess.Popen(['fc-list', ':', 'family'],
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

        p, subdirs, files = next(os.walk(path.dirname(vim.current.buffer.name)))
        pics = [ pic for pic in files if pic[pic.rfind('.'):] in extensions ]
        for d in subdirs:
            files = os.listdir(path.join(p, d))
            pics += [ path.join(d, pic) for pic in files if pic[pic.rfind('.'):] in extensions ] 

        return pics

    def findstart(self, pat=re.compile(r'\\(\w+)(?:[(].+[)])?(?:[[].+[]])?{?')):
        """Finds the cursor position where completion starts."""

        row, col = vim.current.window.cursor
        line = vim.current.line[:col]
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
            elif '}' in line[start:]:
                # Let's not move the cursor too aggresively.
                start = -1
                self.keyword = None
            else:
                start += 1

            return start 

    def completions(self):
        """Selects what type of omni completion should occur."""

        compl = []

        try:
            # Select completion based on keyword
            if self.keyword is not None:
                # Natbib has \Cite.* type of of commands
                if 'cite' in self.keyword or 'Cite' in self.keyword: 
                    compl = self.bibentries
                elif 'ref' in self.keyword:
                    compl = self._labels(vim.current.buffer)
                elif 'font' in self.keyword or 'setmath' in self.keyword:
                    compl = self._fonts()
                elif 'includegraphics' in self.keyword:
                    compl = self._pics()

        except TeXNineError, e:
            echoerr("Omni completion failed: "+str(e))
            compl = []

        return compl

class TeXNineSnippets(object):
    """Snippet engine for TeX-9.

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

        logging.debug("TeX-9: Reading snippets from `{0}'.".format(path.basename(fname)))
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
                echoerr(messages["INVALID_BIBENTRY_TYPE"].format(keyword))
                snippet = ""

        return snippet

class TeXNineDocument(TeXNineBase, TeXNineSnippets):
    """A class to manipulate LaTeX documents in Vim.
    
    TeXNineDocument can

    * Insert a skeleton file into the current Vim buffer
    * Update the dynamic content in the skeleton header
    * Compile a LaTeX document updating the BibTeX references as well
    * Launch a viewer application
    * Preview the definition of a BibTeX entry based on its keyword
    * Insert LaTeX/BibTeX code snippets
    * Send current cursor position to an Evince window for highlighting

    Methods that are decorated with TeXNineBase.multi_file are designed
    to also work in multi-file LaTeX projects.
    
    """
    def __init__(self, vimbuffer,
                 date_label=config['_datelabel'],
                 timestr=config['_timestr']):

        TeXNineBase.add_buffer(self, vimbuffer)
        self.date_label = date_label
        self.timestr = timestr
        self.biberrors = []

    @TeXNineBase.multi_file
    def get_master_output(self, vimbuffer):
        """Get the output file (PDF or DVI) of the LaTeX project"""
        output = vimbuffer.name
        fmt = config['viewer']['target']
        output = "{0}.{1}".format(output[:-len('.tex')], fmt)
        if path.exists(output):
            return output
        else:
            raise TeXNineError(messages['NO_OUTPUT'].format(output))


    @TeXNineBase.multi_file
    def forward_search(self, vimbuffer, vimcurrent):
        """Highligts current cursor position in Evince."""

        if self.buffers[vimbuffer.name]['synctex'] is None:
            try:
                target = document.get_master_output(vimbuffer)
                evince_proxy = tex_nine_synctex.TeXNineSyncTeX(target,
                                                               logging) 
                self.buffers[vimbuffer.name]['synctex'] = evince_proxy
            except TeXNineError, NameError:
                return

        s = self.buffers[vimbuffer.name]['synctex']
        syncstr = "TeX-9: master={0}, row={1[0]}, col={1[1]}" 
        logging.debug(syncstr.format(vimbuffer.name,
                                     vimcurrent.window.cursor))
        s.forward_search(vimcurrent.buffer.name, vimcurrent.window.cursor)
        return

    @TeXNineBase.multi_file
    def compile(self, vimbuffer, compiler):
        """Compiles the current LaTeX manuscript updating the references.

        """

        cwd, basename = os.path.split(vimbuffer.name)

        tex_cmd = [compiler, '-output-directory='+cwd,
                   '-interaction=batchmode', basename]
        bib_cmd = ['bibtex', basename[:-len('.tex')]+'.aux']
        kwargs = {'stdout': subprocess.PIPE, 'cwd': cwd}

        subprocess.Popen(tex_cmd, **kwargs).wait()
        stdout, stderr = subprocess.Popen(bib_cmd, **kwargs).communicate() 

        nobibstyle = re.search("found no \\\\bibstyle command",
                               stdout)
        matches = re.findall('I didn.t find a database entry for .(\S+).',
                             stdout)
        if nobibstyle:
            self.biberrors.append("Cannot update BibTeX references: "+messages['NO_BIBSTYLE'])

        # BibTeX does not report the location where the undefined entries are :-(
        for m in matches:
            self.biberrors.append(messages['INVALID_BIBENTRY'].format(m))

        subprocess.Popen(tex_cmd, **kwargs).wait()

    def get_compiler(self, vimbuffer, update=False):
        """Returns the name of compiler in the current project.

        Agnostic of global configuration.
        """
        try:
            master = self.get_master_file(vimbuffer)
            if self.buffers[master].get('compiler') is None or update:
                compiler = find_compiler(self.buffers[master]['buffer'])
                if compiler:
                    self.buffers[vimbuffer.name]['compiler'] = compiler
                else:
                    raise TeXNineError(messages['NO_COMPILER'])

            return self.buffers[vimbuffer.name]['compiler']

        except TeXNineError, e:
            echoerr(e)
            return ""
        except KeyError:
            echoerr(messages['MASTER_NOT_ACTIVE'].format(master))
            return ""

    def postmake(self, ignored=re.compile('Overfull|Underfull')):
        """Filters invalid and irrelevant error messages that LaTeX
        compilers produce. Adds BibTeX errors. Relies on Vim's Quickfix mechanism.
        """

        valid_entry = lambda x: int(x['valid']) and not ignored.search(x['text'])
        qflist = filter(valid_entry, vim.eval('getqflist()'))

        # Add BibTeX errors
        while self.biberrors:
            qflist.append({'filename': vim.current.buffer.name,
                           'text': self.biberrors.pop(),
                           'lnum': "1"})

        return qflist

    def view(self, vimbuffer):
        """Launches the viewer application.

        The process is started in the background by the system shell.

        WARNING: Requires a *NIX type shell
        """

        try:
            output = self.get_master_output(vimbuffer)
            cmd = '{0} "{1}" &> /dev/null &'.format(config['viewer']['app'], output)
            subprocess.call(cmd, shell=True)
        except TeXNineError, e:
            echoerr("Cannot determine the output file: "+str(e))

    def insert_skeleton(self, vimbuffer, skeleton_file):
        """Insert a skeleton of a LaTeX manuscript."""

        with open(skeleton_file) as skeleton:
            template = Template(skeleton.read())
            skeleton = template.safe_substitute(_file = path.basename(vimbuffer.name),
                                                _date_created = strftime(self.timestr),
                                                _author = getuser())

            vimbuffer[:] = skeleton.splitlines(True)

    def update_header(self, vimbuffer, nlines=10):
        """Updates the date label in the header."""

        date = strftime(self.timestr)
        if len(vimbuffer) >= nlines and int(vim.eval('&modifiable')):
            for i in range(nlines):
                line = str(vimbuffer[i])
                if self.date_label in line and date not in line:
                    vimbuffer[i] = '{0} {1}'.format(self.date_label, date)
                    return

    def bibquery(self, cword, paths):
        """Displays the BibTeX entry under cursor in a preview window."""

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
                e = messages["INVALID_BIBFILE"].format(bibfile)
                echoerr("Cannot lookup `{}': {}".format(cword, e))

        # No matches and paths was not the empty list
        if paths:
            echomsg(messages["INVALID_BIBENTRY"].format(cword))

logging.debug("TeX-9: Done with the Python module.")

# vim: tw=72 fdm=indent fdn=1

