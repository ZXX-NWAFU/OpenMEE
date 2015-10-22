# -*- coding: utf-8 -*-

# A simple setup script to create an executable using PyQt4. This also
# demonstrates the method for creating a Windows executable that does not have
# an associated console.
#
# PyQt4app.py is a very simple type of PyQt4 application
#
# Run the build process by running the command 'python setup.py build'
#
# If everything works well you should find a subdirectory in the build
# subdirectory that contains the files needed to run the application

import os

import sys
from cx_Freeze import setup, Executable
from version import BUILDDATE

base = None
if sys.platform == 'win32':
    base = 'Win32GUI'

options = {
    'build_exe': {
        'includes': 'atexit',
        'init_script': os.path.abspath('prelaunch.py'),
        'include_files': [("/opt/local/Library/Frameworks/R.framework/Resources", "R")],
    },
    'bdist_mac': {
        'iconfile': os.path.abspath(os.path.join('images','mac_icon.icns'))
    },
    'bdist_dmg': {
        'volume_label': 'OpenMEE',
        #'applications-shortcut': True,
    }
}

print "Platform: %s" % sys.platform

executables = [
    Executable(
        script='launch.py',
        base=base
    )
]

setup(name='OpenMEE',
      version=BUILDDATE.replace('-',''),
      description='Intuitive open-source meta-analysis for ecology',
      options=options,
      executables=executables
      )
