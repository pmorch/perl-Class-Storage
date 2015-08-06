use strict;

use Test::More;

use lib '../lib';

use Class::Storage qw(packObjects unpackObjects);

my $packed = { __class__ => 'MyModule', a => 1 };

my $unpackedObject = unpackObjects($packed);

isa_ok( $unpackedObject, 'MyModule' );

done_testing;
