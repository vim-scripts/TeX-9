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
#    Copyright Elias Toivanen, 2011-2014
#
#************************************************************************

import re
import vim
import sys

# Utility functions

def echoerr(errorstr):
    sys.stderr.write("TeX-9: {0}\n".format(str(errorstr)))

def echomsg(msgstr):
    sys.stdout.write("TeX-9: {0}\n".format(str(msgstr)))

def get_latex_environment(vim_window):
    """Get information about the current LaTeX environment.

    Returns a dictionary with keys
    'environment': the name of the current LaTeX environment
    'range': 2-tuple of the beginning and ending line numbers 

    """

    pat = re.compile(r'^\s*\\(begin|end){([^}]+)}')
    b = list(vim_window.buffer)
    row = vim_window.cursor[0] - 1
    environment = ""
    begin = end = 0

    current_line = b[row]
    head = b[row - 1::-1] # From line above to the start
    tail = b[row + 1:] # From next line to the end

    c = pat.match(current_line)
    if c:
        environment = c.group(2)
        if c.group(1) == 'end':
            end = row + 1
        elif c.group(1) == 'begin':
            begin = row + 1

    if not begin:
        envs = {}
        for i, line in enumerate(head):
            m = pat.match(line)
            if m:
                e = m.group(2)
                envs[m.groups()] = i
                if ('begin', e) in envs and ('end', e) in envs and envs[('end', e)] < envs[('begin', e)]:
                    # Eliminate nested environments
                    del envs[('begin', e)]
                    del envs[('end', e)]
                elif ('end', e) not in envs:
                    begin = row - i
                    environment = e
                    break

    if not end:
        envs = {}
        for i, line in enumerate(tail):
            m = pat.match(line)
            if m:
                envs[m.groups()] = i
                e = m.group(2)
                if ('begin', e) in envs and ('end', e) in envs: 
                    #and envs[('end', e)] > envs[('begin', e)]:
                    # Eliminate nested environments
                    del envs[('begin', e)]
                    del envs[('end', e)]
                elif m.groups() == ('end', environment):
                    end = row + i + 2
                    break

    return {'environment': environment, 'range': (begin, end)}

def is_latex_math_environment(vim_window,
                              environments = re.compile(r"matrix|cases|math|equation|align|array")):
    """Returns True if the cursor is currently on a maths environment."""
    e = get_latex_environment(vim_window)
    return  bool(environments.search(e['environment']))

def find_compiler(vimbuffer, nlines=10):
    """Finds the compiler from the header."""
    lines = "\n".join(vimbuffer[:nlines])
    if lines:
        c = re.search("^%\s*Compiler:\s*(\S+)", lines, re.M)
        if c:
            return c.group(1).strip()
        else:
            return ""

    else:
        #Cannot determine the compiler
        return ""

class TeXNineError(Exception):
    pass
