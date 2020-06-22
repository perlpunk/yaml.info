#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
use HTML::FromANSI::Tiny;
my $h = HTML::FromANSI::Tiny->new(
    auto_reverse => 1,
#    background => 'white',
#    foreground => 'black',
    background => 'black',
    foreground => 'white',
);

binmode STDIN, "encoding(utf-8)";
my $ansi = do { local $/; <STDIN> };

#say $h->style_tag();
say $h->html($ansi);
