use inc::Module::Install;
name 'Ark-View-Email';
all_from 'lib/Ark/View/Email.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
