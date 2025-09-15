"""
For compiling the Cython code

CFLAGS="-w" python setup.py build_ext --inplace
"""

import os
from setuptools import setup, Extension
from Cython.Build import cythonize

extensions = [
    Extension("cython_module.gps", ["cython_module/gps/gps.pyx"]),
    Extension("cython_module.geo", ["cython_module/geo/geo.pyx"]),
    Extension("cython_module.img", ["cython_module/img/img.pyx"])
]

os.environ['CFLAGS'] = '-w'

setup(
    ext_modules=cythonize(extensions, gdb_debug=True, compiler_directives={'language_level': "3"}),
)
