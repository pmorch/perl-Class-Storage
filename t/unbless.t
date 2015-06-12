use strict;

use Test::More;

use lib '../lib';

use Class::Unbless qw(unbless rebless);
use Clone 'clone';

## Create a few Classes for testing purposes

package HasConverters;

# This is just a simple class with TO_UNBLESSED and TO_BLESSED functions.
# Assume the class in memory has a 'val' member, but in JSON it must have a VAL
# member.

sub new {
    my ($class, $val) = @_;
    return bless { val => $val }, $class;
}

sub TO_UNBLESSED {
    my ($self) = @_;
    return { VAL => $self->{val} };
}

sub TO_BLESSED {
    my ($class, $unblessed) = @_;
    return bless({ val => $unblessed->{VAL} }, $class);
}

package HasConverters::SubClass;

use base qw(HasConverters);

package HasToFromJSON::Array;

sub new {
    my ($class, $val) = @_;
    return bless [ $val ], $class;
}

sub TO_JSON {
    my ($self) = @_;
    return [ "FOOBAR", $self->[0] ];
}

sub FROM_JSON {
    my ($class, $unblessed) = @_;
    $unblessed->[0] eq 'FOOBAR'
        or die "Expected FOOBAR";
    return bless([ $unblessed->[1] ], $class);
}

package main;

## Actually perform the tests

foreach my $set (
    {
        name => 'simpleClasses',
        blessed => {
            'a' => bless( { 'b' => bless( {}, "c" ), }, "d" ),
            'e' => [ bless( [], "f" ), bless( [], "g" ), ]
        },
        unblessed => {
          'a' => {
            '__class__' => 'd',
            'b' => {
              '__class__' => 'c'
            }
          },
          'e' => [
            [
              '__class__',
              'f'
            ],
            [
              '__class__',
              'g'
            ]
          ]
        }
    },
    {
        name => 'magic string option',
        blessed => {
            'a' => bless( { 'b' => bless( {}, "c" ), }, "d" ),
        },
        unblessed => {
          'a' => {
            'MAGIC' => 'd',
            'b' => {
              'MAGIC' => 'c'
            }
          },
        },
        options => {
            magicString => 'MAGIC'
        }
    },
    {
        name => 'HasConverters',
        blessed => HasConverters->new(47),
        unblessed => {
            VAL => 47,
            __class__ => 'HasConverters'
        }
    },
    {
        name => 'HasConverters::SubClass',
        blessed => HasConverters::SubClass->new(29),
        unblessed => {
            VAL => 29,
            __class__ => 'HasConverters::SubClass'
        }
    },
    {
        name => 'HasToFromJSON::Array (uses method name options)',
        blessed => HasToFromJSON::Array->new(11),
        unblessed => [ '__class__', 'HasToFromJSON::Array', 'FOOBAR', 11 ],
        options => {
            toUnblessedMethodName => 'TO_JSON',
            toBlessedMethodName => 'FROM_JSON',
        }
    },
) {
    subtest $set->{name} => sub {

        my %options = $set->{options} ? ( %{ $set->{options} } ) : ();
        my $blessedCopy = clone ($set->{blessed});
        my $unblessed = unbless($blessedCopy, %options);
        is_deeply(
            $unblessed, $set->{unblessed},
            "Unblessed as expected"
        ) or diag explain $unblessed;
        my $reblessed = rebless($unblessed, %options);
        is_deeply(
            $reblessed, $set->{blessed},
            "Reblessed as expected"
        ) or diag explain $unblessed;
    };
}

subtest "False magicString" => sub {
    my $blessed = {
        'a' => bless( { 'b' => bless( {}, "c" ), }, "d" ),
        'e' => [ bless( [], "f" ), bless( [], "g" ), ]
    };
    my $expected = {
      'a' => {
        'b' => {}
      },
      'e' => [
        [],
        []
      ]
    };
    my $unblessed = unbless($blessed, magicString => undef);
    is_deeply(
        $unblessed, $expected,
        "Unbless without magic string as expected"
    ) or diag explain $unblessed;
};

done_testing;
