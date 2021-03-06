This directory holds the PHP includes and library when it has been built with MSVC.

First download the PHP source code and compile it (follow instructions on their site).

When you are done, copy the generated php5.lib file into the lib/ directory.

Then run the following command from a Cygwin Shell on the PHP source directory:
	find . -not -name '*.h' -delete

This command will remove any file that is not a header file. If you don't have Cygwin, feel free to
cook up your own way of copying all header files while still keeping their directory hierarchy.
Once you have these header files, copy them all (with their hierarchy) to the include/ directory.

For x64, do the same but put the files in the x64/include/ and x64/lib/ directories.

Once the php_adchpp.dll file has been generated after running SCons, you may want to copy it to the
standard PHP extension directory (where php_bz2.dll, etc can also be found) in order to load it
from a PHP script; then reference it in your php.ini file just like any other extension:
	extension=php_adchpp.dll
You will also need to move every other built DLL file (except php_adchpp.dll) to the PHP directory.
After that, all you have to do is require('php_adchpp.php'); from a PHP script and start writng
PHP scripts! The php_adchpp.php should also have been generated by SCons and should be in the build
directory. That file normally tries to load the PHP extension dynamically, but that seems to fail a
lot on Windows, which is why the above way of making the extension part of php.ini is safer.
