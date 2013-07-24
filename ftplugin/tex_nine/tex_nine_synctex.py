
import evince_dbus
from urllib import pathname2url, url2pathname
import dbus.mainloop.glib
import vim
import time

class TeXNineSyncTeX(evince_dbus.EvinceWindowProxy):
    def __init__(self, target, logger = None):

        self.uri = self._path_to_uri(target)
        evince_dbus.EvinceWindowProxy.__init__(self, self.uri,
                                               spawn = False,
                                               logger = logger)
        self.set_source_handler(self.source_handler_vim) 

    # Forward search: Vim -> Evince
    def forward_search(self, fname, cursor):
        self.SyncView(fname, cursor, int(time.time()))

    # Backward search: Evince -> Vim
    def source_handler_vim(self, input_file, source_link, timestamp):
        input_file = self._uri_to_path(input_file)
        input_file = input_file.replace(' ', '\ ')
        row = source_link[0]
        try:
            vim.command('buffer {0}'.format(input_file))
        except vim.error:
            vim.command('edit {0}'.format(input_file))
        finally:
            vim.current.window.cursor = (row, vim.current.window.cursor[1])
            vim.command('exe "normal" "\\<Esc>V"')

    def _path_to_uri(self, fname):
        uri = "file://"
        uri += pathname2url(fname)
        return uri

    def _uri_to_path(self, uri, enc='latin1'):
        uri = uri[len('file://'):]
        fname = url2pathname(uri).encode(enc)
        return fname

# Hook Vim to DBus
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
