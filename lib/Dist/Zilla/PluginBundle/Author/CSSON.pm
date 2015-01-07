use 5.10.1;
use strict;
use warnings;

package Dist::Zilla::PluginBundle::Author::CSSON;

our $VERSION = '0.1102'; # VERSION

use Moose;
use MooseX::AttributeShortcuts;
use Types::Standard qw/Str Int/;
with 'Dist::Zilla::Role::PluginBundle::Easy';
with 'Dist::Zilla::Role::PluginBundle::PluginRemover';
with 'Dist::Zilla::Role::PluginBundle::Config::Slicer';

use namespace::autoclean;
use List::AllUtils 'none';
use Config::INI;

has installer => (
    is => 'rw',
    isa => Str,
    lazy => 1,
    default => sub { shift->payload->{'installer'} || 'ModuleBuildTiny' },
);
has is_private => (
    is => 'rw',
    isa => Int,
    lazy => 1,
    default => sub { shift->payload->{'is_private'} || 0 },
);
has is_task => (
    is => 'rw',
    isa => Int,
    lazy => 1,
    default => sub { shift->payload->{'is_task'} || 0 },
);
has weaver_config => (
    is => 'rw',
    isa => Str,
    lazy => 1,
    default => sub { shift->payload->{'weaver_config'} || '@Author::CSSON' },
);
has homepage => (
    is => 'rw',
    isa => Str,
    lazy => 1,
    builder => 1,
);
has has_travis => (
    is => 'rw',
    isa => Int,
    lazy => 1,
    default => sub { shift->payload->{'has_travis'} || 0 },
);


sub _build_homepage {
    my $distname = Config::INI::Reader->read_file('dist.ini')->{'_'}{'name'};
    return sprintf 'https://metacpan.org/release/' . $distname;
}

sub build_file {
    my $self = shift;

    return $self->installer =~ m/MakeMaker/ ? 'Makefile.PL' : 'Build.PL';
}

sub configure {
    my $self = shift;

    my @possible_installers = qw/MakeMaker MakeMaker::IncShareDir ModuleBuild ModuleBuildTiny/;
    if(none { $self->installer eq $_ } @possible_installers) {
        die sprintf '%s is not one of the possible installers (%s)', $self->installer, join ', ' => @possible_installers;
    }

    $self->add_plugins(
        ['Git::GatherDir', { exclude_filename => [
                                'META.json',
                                'LICENSE',
                                'README.md',
                                $self->build_file,
                            ] },
        ],
        ['CopyFilesFromBuild', { copy => [
                                   'META.json',
                                   'LICENSE',
                                   $self->build_file,
                               ] },
        ],
        ['ReversionOnRelease', { prompt => 1 } ],
        ['OurPkgVersion'],
        ['NextRelease', { format => '%v  %{yyyy-MM-dd HH:mm:ss VVV}d' } ],
        ['PreviousVersion::Changelog'],

        ['NextVersion::Semantic', { major => '',
                                    minor => "API Changes, New Features, Enhancements",
                                    revision => "Revision, Bug Fixes, Documentation, Meta",
                                    format => '%d.%02d%02d',
                                    numify_version => 0,
                                  }
        ],
        (
            $self->is_task ?
            ['TaskWeaver']
            :
            ['PodWeaver', { config_plugin => $self->weaver_config } ]
        ),
        ['Git::Check', { allow_dirty => [
                           'dist.ini',
                           'Changes',
                           'META.json',
                           'README.md',
                           $self->build_file,
                       ] },
        ],
        (
            $self->is_private ?
            ()
            :
            ['GithubMeta', { issues => 1, homepage => $self->homepage } ]
        ),
        ['ReadmeAnyFromPod', { filename => 'README.md',
                               type => 'markdown',
                               location => 'root',
                             }
        ],
        ['MetaNoIndex', { directory => [qw/t xt inc share eg examples/] } ],
        ['Prereqs::FromCPANfile'],
        [ $self->installer ],
        ['MetaJSON'],
        ['ContributorsFromGit'],
        (
            $ENV{'ILLER_AUTHOR_TEST'} ?
            (
            ['Test::Kwalitee::Extra'],
            ['Test::NoTabs'],
            ['Test::EOL'],
            ['Test::EOF'],
            ['PodSyntaxTests'],
            )
            :
            ()
        ),
        ['MetaYAML'],
        ['License'],
        ['ExtraTests'],

        ['ShareDir'],
        ['ExecDir'],
        ['Manifest'],
        ['ManifestSkip'],
        ['CheckChangesHasContent'],
        ['TestRelease'],
        ['ConfirmRelease'],
        [ $ENV{'FAKE_RELEASE'} ? 'FakeRelease' : $self->is_private ? 'UploadToStratopan' : 'UploadToCPAN' ],
        (
            $self->has_travis ?

            ['TravisYML']
            :
            ()
        ),
        ['Git::Tag', { tag_format => '%v',
                       tag_message => ''
                     }
        ],
        ['Git::Push', { remotes_must_exist => 1 } ],
    );
}

1;

# ABSTRACT: Dist::Zilla like Csson

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::PluginBundle::Author::CSSON - Dist::Zilla like Csson

=head1 VERSION

version 0.1102

=head1 SYNOPSIS

    ; in dist.ini
    [@Author::CSSON]

=head1 DESCRIPTION

It is about the same as a dist.ini with these plugins specified:

    [Git::GatherDir]
    exclude_filename = Build.PL ; or equivalent
    exclude_filename = META.json
    exclude_filename = LICENSE
    exclude_filename = README.md

    [CopyFilesFromBuild]
    copy = META.json
    copy = LICENSE
    copy = Build.PL ; or equivalent

    [ReversionOnRelease]
    prompt = 1

    [OurPkgVersion]

    [NextRelease]
    format = %v  %{yyyy-MM-dd HH:mm:ss VVV}d

    [PreviousVersion::Changelog]
    [NextVersion::Semantic]
    major =
    minor = API Changes, New Features, Enhancements
    revision = Revision, Bug Fixes, Documentation, Meta
    format = %d.%02d%02d
    numify_version = 0

    [Git::Check]
    allow_dirty = dist.ini
    allow_dirty = Changes
    allow_dirty = META.json
    allow_dirty = README.md
    allow_dirty = Build.PL ; or equivalent

    ; if is_private == 0, see below
    [GithubMeta]
    issues = 1
    homepage = http://metacpan.org/release/dist-name

    [PodWeaver]
    config_bundle = @Author::CSSON

    [ReadmeAnyFromPod]
    filename = README.md
    type = markdown
    location = root

    [MetaNoIndex]
    directory = t
    directory = xt
    directory = inc
    directory = share
    directory = eg
    directory = examples

    [Prereqs::FromCPANfile]

    ; settable, see installer below
    [ModuleBuildTiny]

    [MetaJSON]

    [ContributorsFromGit]

    [Test::NoTabs]
    [Test::EOL]
    [Test::EOF]
    [PodSyntaxTests]
    [Test::Kwalitee::Extra]

    [MetaYAML]

    [License]

    [ExtraTests]

    [ShareDir]

    [Manifest]

    [ManifestSkip]

    [CheckChangesHasContent]

    [TestRelease]

    [ConfirmRelease]

    ; depends on is_private, see below
    [UploadToCPAN or UploadToStratopan]

    [Git::Commit]
    commit_msg = %v
    allow_dirty = dist.ini
    allow_dirty = Changes
    allow_dirty = META.json
    allow_dirty = README.md
    allow_dirty = Build.PL

    [Git::Tag]
    tag_format = %v
    tag_message =

    [Git::Push]
    remotes_must_exist = 0

=head1 OPTIONS

=head2 homepage

String. Default is the release's page on metacpan.org. Not set if C<is_private> is true.

=head2 installer

String. Default is L<ModuleBuildTiny|Dist::Zilla::ModuleBuildTiny>.

=head2 is_private

Boolean. Default is B<0>.

If false: Adds github repository to meta, uses github as issue tracker, and includes L<UploadToCPAN|Dist::Zilla::Plugin::UploadToCPAN>.

If true: Adds no github information, and includes L<UploadToStratopan|Dist::Zilla::Plugin::UploadToStratopan>.

To remove L<UploadToStratopan|Dist::Zilla::Plugin::UploadToStratopan>, add this to your dist.ini:

    -remove = UploadToStratopan

To use L<UploadToStratopan|Dist::Zilla::Plugin::UploadToStratopan>, you need to specify C<repo> and C<stack> in dist.ini:

    UploadToStratopan.repo = ...
    UploadToStratopan.stack = ...

=head2 is_task

Boolean. Default is B<0>.

If true, L<Dist::Zilla::Plugin::TaskWeaver> is included instead of L<Dist::Zilla::Plugin::PodWeaver>.

=head2 weaver_config

String. Default is L<@Author::CSSON|Pod::Weaver::PluginBundle::Author::CSSON>.

=head1 SEE ALSO

L<Dist::Zilla>

L<Pod::Weaver::PluginBundle::Author::CSSON>

=head1 AUTHOR

Erik Carlsson <info@code301.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Erik Carlsson <info@code301.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
