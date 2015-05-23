#!/usr/bin/env python

package_name = 'tic4d'
package_version = '1.0'

import fnmatch, os, sys

# -----------------------------------------------------------------------------
# Determine on which platform we are

platform = sys.platform

# Detect Python for android project (http://github.com/kivy/python-for-android)
ndkplatform = os.environ.get('NDKPLATFORM')
if ndkplatform is not None and os.environ.get('LIBLINK'):
    platform = 'android'
kivy_ios_root = os.environ.get('KIVYIOSROOT', None)
if kivy_ios_root is not None:
    platform = 'ios'
if os.path.exists('/opt/vc/include/bcm_host.h'):
    platform = 'rpi'

# -----------------------------------------------------------------------------
# Cython check
# on python-for-android and kivy-ios, cython usage is external
have_cython = False
if platform in ('ios', 'android'):
    print('\nCython check avoided.')
else:
    try:
        # check for cython
        from Cython.Distutils import build_ext
        have_cython = True
    except ImportError:
        print('\nCython is missing, it is required for compiling!\n\n')
        raise

if not have_cython:
    from distutils.core import setup
    from distutils.extension import Extension
    from distutils.command.build_ext import build_ext
else:
    from setuptools import setup, Extension

# copied from setuptools
from distutils.util import convert_path
def find_packages(where='.', exclude=()):
    """Return a list all Python packages found within directory 'where'

    'where' should be supplied as a "cross-platform" (i.e. URL-style) path; it
    will be converted to the appropriate local path syntax.  'exclude' is a
    sequence of package names to exclude; '*' can be used as a wildcard in the
    names, such that 'foo.*' will exclude all subpackages of 'foo' (but not
    'foo' itself).
    """
    out = []
    stack=[(convert_path(where), '')]
    while stack:
        where,prefix = stack.pop(0)
        for name in os.listdir(where):
            fn = os.path.join(where,name)
            if ('.' not in name and os.path.isdir(fn) and
                os.path.isfile(os.path.join(fn,'__init__.py'))
            ):
                out.append(prefix+name); stack.append((fn,prefix+name+'.'))
    for pat in list(exclude)+['ez_setup', 'distribute_setup']:
        from fnmatch import fnmatchcase
        out = [item for item in out if not fnmatchcase(item,pat)]
    return out

# copied from kivy
class CythonExtension(Extension):
    def __init__(self, *args, **kwargs):
        Extension.__init__(self, *args, **kwargs)
        self.cython_directives = {
            'c_string_encoding': 'utf-8',
            'profile': 'USE_PROFILE' in os.environ,
            'embedsignature': 'USE_EMBEDSIGNATURE' in os.environ}
        # XXX with pip, setuptools is imported before distutils, and change
        # our pyx to c, then, cythonize doesn't happen. So force again our
        # sources
        self.sources = args[1]

packages = [pkg for pkg in find_packages('.') if pkg.startswith(package_name)]

def make_cy_ext(filename):
    modname = filename.replace('.pyx', '').replace('/', '.')
    srcname = filename if have_cython else (filename[:-4] + '.c')
    return CythonExtension(modname, [srcname])

def find_cy_ext(path):
    ext = []
    for root, dirnames, filenames in os.walk(path):
        for filename in fnmatch.filter(filenames, '*.pyx'):
            ext.append(make_cy_ext(os.path.join(root, filename)))
    return ext

cython_ext = find_cy_ext(package_name)

setup_opts = {
    'name': package_name,
    'version': package_version,
    'packages': packages,
    'cmdclass': {
        'build_ext': build_ext,
    },
    'ext_modules': cython_ext,
}

setup(**setup_opts)