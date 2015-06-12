package Class::Unbless;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Scalar::Util qw(blessed reftype);

use base qw(Exporter);
our @EXPORT_OK = qw(unbless rebless);

use constant DEFAULT_TO_UNBLESSED_METHOD_NAME => "TO_UNBLESSED";
use constant DEFAULT_TO_BLESSED_METHOD_NAME => "TO_BLESSED";

# MooseX::Storage uses __CLASS__ and so it is perhaps a good idea not to choose
# *exactly* the same magic string - then it isn't magic any more! :-)
use constant DEFAULT_MAGIC_STRING => "__class__";

sub unbless {
    my ($data, %options) = @_;

    _setDefaultOptions(\%options);

    my $val = _unbless($data, \%options);
    return $val // $data;
}

sub _unbless {
    my ($data, $options) = @_;

    my $toUnblessedMethodName = $options->{toUnblessedMethodName};

    if (blessed $data && $data->can($toUnblessedMethodName)) {
        my $unblessed = $data->$toUnblessedMethodName();
        bless $unblessed, ref($data);
        $data = $unblessed;
    }

    if (reftype $data) {
        if (reftype $data eq 'HASH') {
            return _unblessHash($data, $options);
        } elsif (reftype $data eq 'ARRAY') {
            return _unblessArray($data, $options);
        }
    }

    return undef;
}

sub _unblessHash {
    my ($hash, $options) = @_;
    # use Dbug; dbugDump(['hash', $hash]);
    foreach my $key (keys %$hash) {
        my $val = $hash->{$key};
        my $newVal = _unbless($val, $options);
        if ($newVal) {
            $hash->{$key} = $newVal;
        }
    }
    if (blessed $hash) {

        $hash = {
            ( $options->{magicString} ?
                ( $options->{magicString} => ref($hash) ) : ()),
            %$hash
        };
    }
    return $hash;
}

sub _unblessArray {
    my ($array, $options) = @_;
    # use Dbug; dbugDump(['array', $array]);
    foreach my $index (0..$#$array) {
        my $val = $array->[$index];
        my $newVal = _unbless($val, $options);
        if ($newVal) {
            $array->[$index] = $newVal;
        }
    }
    if (blessed $array) {
        $array = [
            ( $options->{magicString} ?
                ( $options->{magicString} => ref($array) ) : ()),
            @$array
        ];
    }
    return $array;
}

sub rebless {
    my ($data, %options) = @_;
    _setDefaultOptions(\%options);
    my $val = _rebless($data, \%options);
    return $val // $data;
}

sub _rebless {
    my ($data, $options) = @_;
    if (reftype $data eq 'HASH') {
        return _reblessHash($data, $options);
    } elsif (reftype $data eq 'ARRAY') {
        return _reblessArray($data, $options);
    }
    return undef;
}

sub _reblessHash {
    my ($hash, $options) = @_;
    my $class = delete $hash->{$options->{magicString}};
    if ($class) {
        my $toBlessedMethodName = $options->{toBlessedMethodName};
        if ($class->can($toBlessedMethodName)) {
            return $class->$toBlessedMethodName($hash);
        }
        bless $hash, $class;
    }
    foreach my $key (keys %$hash) {
        my $newVal = _rebless($hash->{$key}, $options);
        $hash->{$key} = $newVal
            if defined $newVal;
    }
    return undef;
}

sub _reblessArray {
    my ($array, $options) = @_;
    if (scalar @$array >= 2 && $array->[0] eq $options->{magicString}) {
        shift @$array;
        my $class = shift @$array;
        my $toBlessedMethodName = $options->{toBlessedMethodName};
        if ($class->can($toBlessedMethodName)) {
            return $class->$toBlessedMethodName($array);
        }
        bless $array, $class;
    }
    foreach my $i (0..$#$array) {
        my $newVal = _rebless($array->[$i], $options);
        $array->[$i] = $newVal
            if defined $newVal;
    }
    return undef;
}

sub _setDefaultOptions {
    my ($options) = @_;
    $options->{toUnblessedMethodName} //= DEFAULT_TO_UNBLESSED_METHOD_NAME;
    $options->{toBlessedMethodName} //= DEFAULT_TO_BLESSED_METHOD_NAME;
    if (! exists $options->{magicString}) {
        $options->{magicString} = DEFAULT_MAGIC_STRING;
    }
}

=head1 NAME

Class::Unbless - unbless classes so they are rebless-able later.

Handles blessed HASHes and ARRAYs

=head1 VERSION

Version 0.01

B<NOTE>: I<THE NAME OF THIS CLASS MAY CHANGE. I'M LOOKING FOR OPINIONS ON
THAT.>

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module came into existence out of the need to be able to send I<objects>
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

=head1 DESCRIPTION

=head2 Using a magic string

As you can see from the L</"SYNOPSIS">, we use a magic string ("__class__" by default) to store the class information for HASHes and ARRAYs.

So:

    bless { key => "value" }, "ModuleA";
    bless [ "val1", "val2" ], "ModuleB";

become:

    { __class__ => 'ModuleA', key => "value" }
    [ "__class__", 'ModuleB', "val1", "val2" ]

Any hashes with the magic string as a key and any arrays with the magic string
as the first element will be converted to blessed references

This "magic string" can be given as an option (see L</"OPTIONS">), but if you
cannot live with a magic string, you can also provide
C<< magicString => undef >>

But then you won't be able to rebless that data. If this is your itch, you may
actually want L<Data::Structure::Util> instead.

=head3 Returns unbless-ed/rebless-ed data + modifies input argument

The valid data is returned. However, for speed, we also modify and re-use data
from the input value. So don't rely on being able to reuse the C<$data> input
for C<bless> and C<unbless> after they've been called and don't modify them
either.

If you don't want your input modified:

    use Storable qw(dclone);
    my $pristineData = somesub();
    my $unblessed = ubless(dclone($pristineData));

=head2 Inspiration

Class::Unbless is inspired by L<MooseX::Storage> but this is a generic
implementation that works on all plain perl classes that are implemented as
blessed references to HASHes and ARRAYs (B<only> hashes and arrays).

    use Class::Unbless qw(unbless rebless);

    my $unblesed = unbless( bless { a => 1 }, 'MyModule' );

    # $unblessed is now { __class__ => 'MyModule', a => 1 }

    my $reblessed = rebless($unblessed);

    # $reblessed is now bless { a => 1 }, 'MyModule'

NOTE: L<MooseX::Storage> uses C<__CLASS__> as its magic string and we use
C<__class__> to make sure they're not the same.

=head1 NOTE ABOUT KINDS OF BLESSED OBJECTS

L<perlobj> says:

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

Clearly a L<JSON> object has internal state and other data. This is an example
of a blessed reference, but not a blessed HASH or ARRAY that Class::Unbless can
handle. If you try C<unbless>-ing such a JSON instance, Class::Unbless will
just leave the JSON object altogether untouched.

=head1 EXPORT

    our @EXPORT_OK = qw(unbless rebless);

=head1 SUBROUTINES/METHODS

Both C<unbless> and C<bless> share the same C<%options>. See L</"OPTIONS">
below.

=head2 unbless

    my $unblessed = unbless($blessed, %options);

=head2 rebless

    my $reblessed = rebless($unbessed, %options);

=head1 OPTIONS

These options are common to C<unbless> and C<rebless>:

=over 4

=item * C<toUnblessedMethodName>

This option lets you change the name of the C<TO_UNBLESSED> method to something
else. Hint: C<TO_JSON> could be a good idea here!

=item * C<toBlessedMethodName>

This option lets you change the name of the C<TO_BLESSED> method to something
else. Hint: C<FROM_JSON> could be a good idea here, even though L<JSON>
doesn't have such a method.

Which is actually the entire Raison d'Etre of this module!

=item * C<magicString>

Change the magic string used to store the class name to something else than
C<__class__>.

If this is false, don't store class information at all, in which case
C<unbless> becomes analogous to L<Data::Structure::Util::unbless>.

=back

=encoding UTF-8

=head1 AUTHOR

Peter Valdemar Mørch, C<< <peter@morch.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-class-unbless at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Class-Unbless>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Class::Unbless

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Class-Unbless>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Class-Unbless>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Class-Unbless>

=item * Search CPAN

L<http://search.cpan.org/dist/Class-Unbless/>

=back

=head1 ACKNOWLEDGEMENTS

This has been inspired by many sources, but checkout:

=over 4

=item * How to convert Perl objects into JSON and vice versa - Stack Overflow

L<http://stackoverflow.com/questions/4185482/how-to-convert-perl-objects-into-json-and-vice-versa/4185679>

=item * How do I turn Moose objects into JSON for use in Catalyst?

L<http://stackoverflow.com/questions/3391967/how-do-i-turn-moose-objects-into-json-for-use-in-catalyst>

=item * MooseX-Storage

L<https://metacpan.org/release/MooseX-Storage>

=item * Brian D Foy's quick hack

Where he defines a TO_JSON in UNIVERSAL so it applies to all objects. It makes
a deep copy, unblesses it, and returns the data structure.

L<http://stackoverflow.com/a/2330077/345716>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Peter Valdemar Mørch.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

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

=cut

1; # End of Class::Unbless
