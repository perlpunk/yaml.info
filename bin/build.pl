#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;
no warnings qw(experimental::signatures);
use feature 'signatures';
use autodie qw/ open /;

use FindBin '$Bin';
use lib "$Bin/../lib";
use YAMLInfo qw/
  tohtml make_topnav make_sidenav highlight code make_library_tables
  make_index
/;
use YAML::PP;
use YAML::PP::Highlight;
use Data::Dumper;
use HTML::Entities qw/ encode_entities /;
use File::Path qw/ make_path /;
use File::Basename qw/ dirname /;
$Data::Dumper::Sortkeys = 1;

my $datadir = "$Bin/../data";
my $content_dir = "$Bin/../content";
my $out_dir = "$Bin/../gh-pages";
my $yp = YAML::PP->new;
my $sitemap = $yp->load_file("$Bin/../sitemap.yaml");
my $libraries = $yp->load_file("$Bin/../libraries.yaml");

my @pages = qw(
  index learn/index learn/quote learn/bestpractices
  libraries/index libraries/dev libraries/repology
  topics
);
#my @pages = qw(index);

my ($tables, $repology) = make_library_tables($libraries);
my %tables = (
    1 => $tables,
);

my $header = $sitemap->{header};
my $footer = $sitemap->{footer};

my $links = $sitemap->{top};

my @topnav;
my %index;
my %sidenav;
for my $link (@$links) {
    my ($top) = keys %$link;
    my $value = $link->{ $top };
    if (ref $value) {
        for my $item (@$value) {
            my ($name) = keys %$item;
            my $value = $item->{ $name };
            my %info = (
                title => $value,
                path => [$top, $name],
            );
            if ($name eq 'index') {
                push @topnav, \%info;
            }
            push @{ $sidenav{ $top } }, \%info;
        }
    }
    else {
        my %info = (
            title => $value,
            path => [$top],
        );
        push @topnav, \%info;
    }
}
$topnav[0]->{home} = 1;
#warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\@topnav], ['topnav']);
#warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\%sidenav], ['sidenav']);


for my $page (@pages) {
    say "Creating $page";
    my $content = $yp->load_file("$content_dir/$page.yaml");
    my $out = "$out_dir/$page.html";
    make_path(dirname($out));
    my $topnav = make_topnav(\@topnav, $page);
    my $sidenav = make_sidenav(\%sidenav, $page, $content);
    my $sidenavclass = '';
    if (my $config = $content->{sidenav}) {
        $sidenavclass = $config->{class} // '';
    }
    my $main;
    my %topics;
    for my $item (@{ $content->{source} }) {
        if (ref $item) {
            if (my $yaml = $item->{yaml}) {
                $main .= highlight($yaml);
            }
            elsif (my $createindex = $item->{index}) {
                my $indexhtml = make_index(\%index);
                $main .= $indexhtml;
            }
            elsif (my $section = $item->{section}) {
                my $name = $section->{name};
                my $title = $section->{title};
                $main .= qq{<div class="section" id="$name">\n};
                $main .= qq{<h2>$title</h2>\n};
                for my $item (@{ $section->{content} }) {
                    if (ref $item) {
                        if (my $yaml = $item->{yaml}) {
                            $main .= highlight($yaml);
                        }
                        elsif (my $code = $item->{code}) {
                            $main .= code($code);
                        }
                        elsif (my $htmlfile = $item->{terminal}) {
                            open my $fh, '<', "$datadir/$htmlfile";
                            my $html = do { local $/; <$fh> };
                            close $fh;
                            chomp $html;
                            $main .= qq{<pre class="terminal">$html</pre>\n};
                        }
                        elsif (my $table = $item->{table}) {
                            $main .= $tables{ $table };
                        }
                        elsif (my $repo = $item->{repology}) {
                            $main .= $repology;
                        }
                    }
                    else {
                        $main .= "<p>" . tohtml($item, \%topics) . "</p>";
                    }
                }
                $main .= qq{</div>\n};
            }
        }
        else {
            $main .= "<p>" . tohtml($item, \%topics) . "</p>";
        }
    }
    my $basepath = $page =~ m{/} ? '..' : '.';
    $index{ $page } = \%topics;

    my $header = $header;
    $header =~ s/\$\{TITLE\}/$content->{title}/;
    $header =~ s/\$\{BASE\}/$basepath/g;
    my $footer = $footer;
    $footer =~ s/\$\{BASE\}/$basepath/g;

    my $html = <<"EOM";
$header
<div id="topnav">
$topnav
<a class="source" href="https://github.com/perlpunk/yaml.info">Contribute <img src="$basepath/img/GitHub-Mark-Light-32px.png"></a>
</div>
<div id="sidenav" class="$sidenavclass"><p class="spacer"></p>
$sidenav
</div>
<div class="main main-$sidenavclass">
$main
<p class="source">
<a href="https://github.com/perlpunk/yaml.info/blob/master/content/$page.yaml">Page Source</a>
</p>
</div>
$footer
EOM
    open my $fh, '>:encoding(UTF-8)', $out;
    print $fh $html;
    close $out;
}



