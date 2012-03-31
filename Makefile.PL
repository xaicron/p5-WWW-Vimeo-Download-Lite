use inc::Module::Install;
use Module::Install::AuthorTests;

name 'WWW-Vimeo-Download-Lite';
all_from 'lib/WWW/Vimeo/Download/Lite.pm';

requires 'parent';
requires 'WWW::Mechanize';
requires 'File::Basename';
requires 'Carp';
requires 'JSON';
requires 'Encode';
requires 'File::Spec';

test_requires 'Test::More', 0.98;

tests join q{ }, map { sprintf 't%s.t', '/*' x $_ } 1..3;
author_tests 'xt';

install_script 'bin/vimeo-download';

repository 'http://github.com/xaicron/p5-WWW-Vimeo-Download-Lite/';
bugtracker 'http://github.com/xaicron/p5-WWW-Vimeo-Download-Lite/issues';

WriteAll;
