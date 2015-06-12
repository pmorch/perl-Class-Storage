# NAME

Class::Unbless - unbless classes so they are rebless-able later.

Handles blessed HASHes and ARRAYs

# VERSION

Version 0.01

**NOTE**: _THE NAME OF THIS CLASS MAY CHANGE. I'M LOOKING FOR OPINIONS ON
THAT._

# SYNOPSIS

This module came into existence out of the need to be able to send _objects_
over JSON. JSON does not allow any blessed references to be sent by default and
if sent, provides no generic way to resurrect these objects again after
decoding. This can now all be done like this:

    use JSON;
    use Class::Unbless qw(unbless rebless);

    my $object = MyModule->new();
    my $jsonString = encode_json(unbless $object);

    print $writeHandle $jsonString, "\n";

    # And on the other "side":

    my $jsonString = <$readHandle>;
    my $object2 = rebless(decode_json($jsonString));

However, there is no JSON-specific functionality in this module whatsoever,
only a way to cleanly "unbless" - remove the bless-ing - in a way that reliably
can be re-introduced later.

# DESCRIPTION

## Using a magic string

As you can see from the ["SYNOPSIS"](#synopsis), we use a magic string ("\_\_class\_\_" by default) to store the class information for HASHes and ARRAYs.

So:

    bless { key => "value" }, "ModuleA";
    bless [ "val1", "val2" ], "ModuleB";

become:

    { __class__ => 'ModuleA', key => "value" }
    [ "__class__", 'ModuleB', "val1", "val2" ]

Any hashes with the magic string as a key and any arrays with the magic string
as the first element will be converted to blessed references

This "magic string" can be given as an option (see ["OPTIONS"](#options)), but if you
cannot live with a magic string, you can also provide
`magicString => undef`

But then you won't be able to rebless that data. If this is your itch, you may
actually want [Data::Structure::Util](https://metacpan.org/pod/Data::Structure::Util) instead.

### Returns unbless-ed/rebless-ed data + modifies input argument

The valid data is returned. However, for speed, we also modify and re-use data
from the input value. So don't rely on being able to reuse the `$data` input
for `bless` and `unbless` after they've been called and don't modify them
either.

If you don't want your input modified:

    use Storable qw(dclone);
    my $pristineData = somesub();
    my $unblessed = ubless(dclone($pristineData));

## Inspiration

Class::Unbless is inspired by [MooseX::Storage](https://metacpan.org/pod/MooseX::Storage) but this is a generic
implementation that works on all plain perl classes that are implemented as
blessed references to HASHes and ARRAYs (**only** hashes and arrays).

    use Class::Unbless qw(unbless rebless);

    my $unblesed = unbless( bless { a => 1 }, 'MyModule' );

    # $unblessed is now { __class__ => 'MyModule', a => 1 }

    my $reblessed = rebless($unblessed);

    # $reblessed is now bless { a => 1 }, 'MyModule'

NOTE: [MooseX::Storage](https://metacpan.org/pod/MooseX::Storage) uses `__CLASS__` as its magic string and we use
`__class__` to make sure they're not the same.

# NOTE ABOUT KINDS OF BLESSED OBJECTS

[perlobj](https://metacpan.org/pod/perlobj) says:

"... it's possible to bless any type of data structure or referent, including
scalars, globs, and subroutines. You may see this sort of thing when looking at
code in the wild."

In particular I've seen several XS modules create instances where the internal
state is not visible to Perl, and hence cannot be handled properly by this
module. Here is an example with JSON:

    use Data::Dumper;
    use JSON;
    print Dumper(JSON->new()->pretty(1));
    # prints
    # $VAR1 = bless( do{\(my $o = '')}, 'JSON' );

Clearly a [JSON](https://metacpan.org/pod/JSON) object has internal state and other data. This is an example
of a blessed reference, but not a blessed HASH or ARRAY that Class::Unbless can
handle. If you try `unbless`-ing such a JSON instance, Class::Unbless will
just leave the JSON object altogether untouched.

# EXPORT

    our @EXPORT_OK = qw(unbless rebless);

# SUBROUTINES/METHODS

Both `unbless` and `bless` share the same `%options`. See ["OPTIONS"](#options)
below.

## unbless

    my $unblessed = unbless($blessed, %options);

## rebless

    my $reblessed = rebless($unbessed, %options);

# OPTIONS

These options are common to `unbless` and `rebless`:

- `toUnblessedMethodName`

    This option lets you change the name of the `TO_UNBLESSED` method to something
    else. Hint: `TO_JSON` could be a good idea here!

- `toBlessedMethodName`

    This option lets you change the name of the `TO_BLESSED` method to something
    else. Hint: `FROM_JSON` could be a good idea here, even though [JSON](https://metacpan.org/pod/JSON)
    doesn't have such a method.

    Which is actually the entire Raison d'Etre of this module!

- `magicString`

    Change the magic string used to store the class name to something else than
    `__class__`.

    If this is false, don't store class information at all, in which case
    `unbless` becomes analogous to [Data::Structure::Util::unbless](https://metacpan.org/pod/Data::Structure::Util::unbless).

# AUTHOR

Peter Valdemar Mørch, `<peter@morch.com>`

# BUGS

Please report any bugs or feature requests to `bug-class-unbless at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Class-Unbless](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Class-Unbless).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Class::Unbless

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Unbless](http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Unbless)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/Class-Unbless](http://annocpan.org/dist/Class-Unbless)

- CPAN Ratings

    [http://cpanratings.perl.org/d/Class-Unbless](http://cpanratings.perl.org/d/Class-Unbless)

- Search CPAN

    [http://search.cpan.org/dist/Class-Unbless/](http://search.cpan.org/dist/Class-Unbless/)

# ACKNOWLEDGEMENTS

This has been inspired by many sources, but checkout:

- How to convert Perl objects into JSON and vice versa - Stack Overflow

    [http://stackoverflow.com/questions/4185482/how-to-convert-perl-objects-into-json-and-vice-versa/4185679](http://stackoverflow.com/questions/4185482/how-to-convert-perl-objects-into-json-and-vice-versa/4185679)

- How do I turn Moose objects into JSON for use in Catalyst?

    [http://stackoverflow.com/questions/3391967/how-do-i-turn-moose-objects-into-json-for-use-in-catalyst](http://stackoverflow.com/questions/3391967/how-do-i-turn-moose-objects-into-json-for-use-in-catalyst)

- MooseX-Storage

    [https://metacpan.org/release/MooseX-Storage](https://metacpan.org/release/MooseX-Storage)

- Brian D Foy's quick hack

    Where he defines a TO\_JSON in UNIVERSAL so it applies to all objects. It makes
    a deep copy, unblesses it, and returns the data structure.

    [http://stackoverflow.com/a/2330077/345716](http://stackoverflow.com/a/2330077/345716)

# LICENSE AND COPYRIGHT

Copyright 2015 Peter Valdemar Mørch.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic\_license\_2\_0](http://www.perlfoundation.org/artistic_license_2_0)

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
