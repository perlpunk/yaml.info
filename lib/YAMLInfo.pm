package YAMLInfo;
use strict;
use warnings;
use 5.022;

no warnings qw(experimental::signatures);
use feature 'signatures';
use autodie qw/ open /;
use Encode;
use HTML::Entities qw/ encode_entities /;

use base 'Exporter';

our @EXPORT_OK = qw(
    tohtml make_topnav make_sidenav highlight code make_library_tables
    make_index
);

# we use a veeery simple markup converter for now
sub tohtml($page, $input, $topics, $topiclinks) {
    my $basepath = $page =~ m{/} ? '../' : '';
    $input =~ s{`(.+?)`}{'<span class="code">'.encode_entities($1).'</span>'}eg;
    $input =~ s{```}{<span class="code"></span>}g;
    $input =~ s{\[(.*?)\]\((#topic:)([^\)]+)\)}{
        $topics->{ $3 }++;
        my $link = $topiclinks->{ $3 };
        unless ($link) {
            say "no link for $3";
        }
        my $href = $link ? qq{href="$basepath$link.html"} : '';
        qq{<a class="topic" $href>}.encode_entities($1).'</a>'
    }seg;
    $input =~ s{\[(.*?)\]\(([^\)]+)\)}{qq{<a href="$2">}.encode_entities($1).'</a>'}seg;
    return $input;
}

sub make_topnav($topnav, $page) {
    my $html;
    my $basepath = $page =~ m{/} ? '../' : '';
    for my $item (@$topnav) {
        my $title = $item->{title};
        my $paths = $item->{path};
        my $path = join '/', @$paths;
        my @class;
        if ($item->{home}) {
            push @class, 'home';
        }
        if ($page =~ m/^$paths->[0]/) {
            push @class, 'active';
        }
        my $class = @class ? qq{class="@class"} : '';
        $html .= qq{<a $class href="$basepath$path.html">$title</a>\n};
    }
    return $html;
}

sub make_sidenav($sidenav, $page, $content) {
    my @paths = split m{/}, $page;
    my $info = $sidenav->{ $paths[0] } || [];
    my $html;
    my $basepath = $page =~ m{/} ? '../' : '';
    my $sections = make_sections($content->{links});
    unless (@$info) {
        $html .= $sections;
    }
    else {
        for my $item (@$info) {
            my $sectionshtml = '';
            my $title = $item->{title};
            my $paths = $item->{path};
            my $path = join '/', @$paths;
            my @class = qw/ top /;
            if ($page eq $path) {
                push @class, 'active';
                $sectionshtml = $sections;
            }
            my $class = @class ? qq{class="@class"} : '';
            $html .= qq{<a $class href="$basepath$path.html">$title</a>\n};
            $html .= $sectionshtml;
        }
    }
    return $html;
}

sub make_sections($sections) {
    return '' unless $sections;
    my $html = '<ul>';
    for my $section (@$sections) {
        my ($name) = keys %$section;
        my $value = $section->{ $name };
        if (ref $value) {
            my $title = $value->{title};
            my $children = $value->{children};
            my $sub = make_sections($children);
            $html .= qq{<li><a id="link_$name" href="#$name">$title</a></li>\n};
            $html .= $sub;
        }
        else {
            $html .= qq{<li><a id="link_$name" href="#$name">$value</a></li>\n};
        }
    }
    $html .= '</ul>';
}

sub highlight($yaml) {
    my ($error, $tokens) = YAML::PP::Parser->yaml_to_tokens( string => $yaml );

    my $high = YAML::PP::Highlight->htmlcolored($tokens);
    return qq{<div class="yaml codebox"><pre>$high</pre></div>};
}

sub code {
    my ($code) = @_;
    my $content = encode_entities($code);
    return qq{<div class="codebox"><pre>$content</pre></div>\n};
}

sub make_library_tables($libraries) {
    my $repo = qq{<div id="repology">};
    my $html = <<'EOM';
<table class="libcompare">
<tr>
<th rowspan="2">Language</th>
<th rowspan="2">Library</th>
<th colspan="2">Syntax</th>
<th rowspan="2">Uses YAML<br>Test Suite</th>
<th rowspan="2">YAML<br>Runtimes</th>
</tr>

<tr>
<th>1.2</th><th>1.1</th>
</tr>
EOM
    my $checkmark = decode_utf8 "✓";
    my @keys = sort {
        $libraries->{ $a }->{language} cmp $libraries->{ $b }->{language}
        || $libraries->{ $a }->{name} cmp $libraries->{ $b }->{name}
    } keys %$libraries;
    for my $key (@keys) {
        my $info = $libraries->{ $key };
        my $repology = $info->{repology};
        my $syntax = $info->{syntax};
        my $schema = $info->{schema};
        my @row = (
            $info->{language},
            qq{<a href="$info->{homepage}">$info->{name}</a>},
            $syntax->{1.2}, $syntax->{1.1},
#            $schema->{'1.2 Core'}, $schema->{'1.2 JSON'},
#            $schema->{'1.2 Failsafe'}, $schema->{'1.1'},
            $info->{'yaml-test-suite'},
            $info->{'yaml-runtimes'},
        );
        for my $col (@row) {
            $col //= '<span class="na">n/a</span>';
            $col =~ s{$checkmark}{<span class="checkmark">$checkmark</span>};
            $col =~ s{~}{<span class="mostly">~</span>};
            $col =~ s{x}{<span class="no">x</span>};
        }
        $html .= "<tr>" . join ('', map { "<td>$_</td>" } @row) . '</tr>';
        $repology and $repo .= <<"EOM";
<div class="badge">
<b>$info->{language} $info->{name}</b><br>
<img src="https://repology.org/badge/tiny-repos/$repology.svg" alt="Packaging status"><br>
<div class="repos">
<a href="https://repology.org/project/$repology/versions">
<img src="https://repology.org/badge/vertical-allrepos/$repology.svg" alt="Packaging status">
</a>
</div>
</div>
EOM
    }
    $html .= "</table>";
    $repo .= '</div>';
    return ($html, $repo);
}

sub make_index($index) {
    my %topics;
    for my $page (keys %$index) {
        my $top = $index->{ $page };
        for my $key (keys %$top) {
            $topics{ $key }->{ $page }++;
        }
    }
    my $lists;
    for my $topic (sort keys %topics) {
        my $pages = $topics{ $topic };
        my $links;
        for my $page (sort keys %$pages) {
            my $link = qq{<li><a href="$page.html">$page</a></li>\n};
            $links .= $link;
        }
        my $ul = qq{<li>$topic<ul>$links</ul></li>\n};
        $lists .= $ul;
    }
    my $html = qq{<ul>$lists</ul>\n};
    return $html;
}

1;
