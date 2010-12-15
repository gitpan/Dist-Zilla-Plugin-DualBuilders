#
# This file is part of Dist-Zilla-Plugin-DualBuilders
#
# This software is copyright (c) 2010 by Apocalypse.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict; use warnings;
package Dist::Zilla::Plugin::DualBuilders;
BEGIN {
  $Dist::Zilla::Plugin::DualBuilders::VERSION = '1.001';
}
BEGIN {
  $Dist::Zilla::Plugin::DualBuilders::AUTHORITY = 'cpan:APOCAL';
}

# ABSTRACT: Allows use of Module::Build and ExtUtils::MakeMaker in a dzil dist

use Moose 1.03;

with 'Dist::Zilla::Role::PrereqSource' => { -version => '3.101461' };
with 'Dist::Zilla::Role::InstallTool' => { -version => '3.101461' };
with 'Dist::Zilla::Role::AfterBuild' => { -version => '3.101461' };


{
	use Moose::Util::TypeConstraints 1.01;

	has prefer => (
		is => 'ro',
		isa => enum( [ qw( build make ) ] ),
		default => 'build',
	);

	no Moose::Util::TypeConstraints;
}


has block_test => (
	is => 'ro',
	isa => 'Bool',
	default => 1,
);

has _buildver => (
	is => 'rw',
	isa => 'Str',
);

has _makever => (
	is => 'rw',
	isa => 'Str',
);

sub setup_installer {
	my ($self, $file) = @_;

	# This is to munge the files
	foreach my $file ( @{ $self->zilla->files } ) {
		if ( $file->name eq 'Build.PL' ) {
			if ( $self->prefer eq 'make' ) {
				$self->log_debug( "Munging Build.PL because we preferred ExtUtils::MakeMaker" );
				my $content = $file->content;
				$content =~ s/'ExtUtils::MakeMaker'\s+=>\s+'.+'/'Module::Build' => '${\$self->_buildver}'/g;

				# TODO do we need to add it to build_requires too? Or is config_requires and the use line sufficient?

				$file->content( $content );
			}
		} elsif ( $file->name eq 'Makefile.PL' ) {
			if ( $self->prefer eq 'build' ) {
				$self->log_debug( "Munging Makefile.PL because we preferred Module::Build" );
				my $content = $file->content;
				$content =~ s/'Module::Build'\s+=>\s+'.+'/'ExtUtils::MakeMaker' => '${\$self->_makever}'/g;

				# TODO since MB adds to build_requires, should we remove EUMM from it? I think it's ok to leave it in...

				$file->content( $content );
			}
		}
	}
}

sub register_prereqs {
	## no critic ( ProhibitAccessOfPrivateData )
	my ($self) = @_;

	# Find out if we have both builders loaded?
	my $config_prereq = $self->zilla->prereqs->requirements_for( 'configure', 'requires' );
	my $build_prereq = $self->zilla->prereqs->requirements_for( 'build', 'requires' );
	my $config_hash = defined $config_prereq ? $config_prereq->as_string_hash : {};
	if ( exists $config_hash->{'Module::Build'} and exists $config_hash->{'ExtUtils::MakeMaker'} ) {
		# conflict!
		if ( $self->prefer eq 'build' ) {
			# Get rid of EUMM stuff
			$self->_makever( $config_hash->{'ExtUtils::MakeMaker'} );

			# As of DZIL v2.101170 DZ:P:Makemaker adds to configure only
			$config_prereq->clear_requirement( 'ExtUtils::MakeMaker' );
			$self->log_debug( 'Preferring Module::Build, removing ExtUtils::MakeMaker from prereqs' );
		} elsif ( $self->prefer eq 'make' ) {
			# Get rid of MB stuff
			$self->_buildver( $config_hash->{'Module::Build'} );

			# As of DZIL v2.101170 DZ:P:ModuleBuild adds to configure and build
			$config_prereq->clear_requirement( 'Module::Build' );
			$build_prereq->clear_requirement( 'Module::Build' );
			$self->log_debug( 'Preferring ExtUtils::MakeMaker, removing Module::Build from prereqs' );
		}
	} elsif ( exists $config_hash->{'Module::Build'} and $self->prefer eq 'make' ) {
		$self->log_fatal( 'Detected Module::Build in the config but you preferred ExtUtils::MakeMaker!' );
	} elsif ( exists $config_hash->{'ExtUtils::MakeMaker'} and $self->prefer eq 'build' ) {
		$self->log_fatal( 'Detected ExtUtils::MakeMaker in the config but you preferred Module::Build!' );
	} elsif ( ! exists $config_hash->{'ExtUtils::MakeMaker'} and ! exists $config_hash->{'Module::Build'} ) {
		$self->log_fatal( 'Detected no builders loaded, please check your dist.ini!' );
	} else {
		# Our preference matched the builder loaded
	}
}

sub after_build {
        my( $self, $root ) = @_;

        return if ! $self->block_test;

	# The builders have done their job, now we block them from running the testsuite twice!
	my $testers = $self->zilla->plugins_with(-TestRunner);
		foreach my $t ( @$testers ) {
		if ( $t =~ /MakeMaker/ and $self->prefer eq 'build' ) {
			$self->log_debug( 'Blocking ExtUtils::MakeMaker from running the testsuite' );
			$self->_remove_tester( $t );
		} elsif ( $t =~ /ModuleBuild/ and $self->prefer eq 'make' ) {
			$self->log_debug( 'Blocking Module::Build from running the testsuite' );
			$self->_remove_tester( $t );
		}
	}
}

sub _remove_tester {
	my( $self, $tester ) = @_;

	# TODO RJBS will kill me! What's a better way to do this?
	my $plugins = $self->zilla->plugins;
	foreach my $i ( 0 .. $#{ $plugins } ) {
		if ( $plugins->[$i] == $tester ) {
			splice( @$plugins, $i, 1 );
			last;
		}
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;


__END__
=pod

=for Pod::Coverage register_prereqs setup_installer after_build

=for stopwords MakeMaker ModuleBuild dist dzil prereq prereqs

=head1 NAME

Dist::Zilla::Plugin::DualBuilders - Allows use of Module::Build and ExtUtils::MakeMaker in a dzil dist

=head1 VERSION

  This document describes v1.001 of Dist::Zilla::Plugin::DualBuilders - released December 15, 2010 as part of Dist-Zilla-Plugin-DualBuilders.

=head1 DESCRIPTION

This plugin allows you to specify ModuleBuild and MakeMaker in your L<Dist::Zilla> F<dist.ini> and select
only one as your prereq. Normally, if this plugin is not loaded you will end up with both in your prereq list
and this is obviously not what you want! Also, this will block both builders from running the testsuite twice.

	# In your dist.ini:
	[ModuleBuild]
	[MakeMaker] ; or [MakeMaker::Awesome], will work too :)
	[DualBuilders] ; needs to be specified *AFTER* the builders

=head1 ATTRIBUTES

=head2 prefer

Sets your preferred builder. This builder will be the one added to the prereqs. Valid options are: "make" or "build".

The default is: build

=head2 block_test

This is a boolean value determining if we will block both testers from running the testsuite. If you have both
builders loaded, you will run the testsuite twice! If you want this behavior, please set this value to false.

The default is: true

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Dist::Zilla>

=back

=for :stopwords CPAN AnnoCPAN RT CPANTS Kwalitee diff IRC

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc Dist::Zilla::Plugin::DualBuilders

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

Search CPAN

L<http://search.cpan.org/dist/Dist-Zilla-Plugin-DualBuilders>

=item *

RT: CPAN's Bug Tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dist-Zilla-Plugin-DualBuilders>

=item *

AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dist-Zilla-Plugin-DualBuilders>

=item *

CPAN Ratings

L<http://cpanratings.perl.org/d/Dist-Zilla-Plugin-DualBuilders>

=item *

CPAN Forum

L<http://cpanforum.com/dist/Dist-Zilla-Plugin-DualBuilders>

=item *

CPANTS Kwalitee

L<http://cpants.perl.org/dist/overview/Dist-Zilla-Plugin-DualBuilders>

=item *

CPAN Testers Results

L<http://cpantesters.org/distro/D/Dist-Zilla-Plugin-DualBuilders.html>

=item *

CPAN Testers Matrix

L<http://matrix.cpantesters.org/?dist=Dist-Zilla-Plugin-DualBuilders>

=back

=head2 Internet Relay Chat

You can get live help by using IRC ( Internet Relay Chat ). If you don't know what IRC is,
please read this excellent guide: L<http://en.wikipedia.org/wiki/Internet_Relay_Chat>. Please
be courteous and patient when talking to us, as we might be busy or sleeping! You can join
those networks/channels and get help:

=over 4

=item *

irc.perl.org

You can connect to the server at 'irc.perl.org' and join this channel: #perl-help then talk to this person for help: Apocalypse.

=item *

irc.freenode.net

You can connect to the server at 'irc.freenode.net' and join this channel: #perl then talk to this person for help: Apocal.

=item *

irc.efnet.org

You can connect to the server at 'irc.efnet.org' and join this channel: #perl then talk to this person for help: Ap0cal.

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-dist-zilla-plugin-dualbuilders at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dist-Zilla-Plugin-DualBuilders>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<http://github.com/apocalypse/perl-dist-zilla-plugin-dualbuilders>

  git clone git://github.com/apocalypse/perl-dist-zilla-plugin-dualbuilders.git

=head1 AUTHOR

Apocalypse <APOCAL@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Apocalypse.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

The full text of the license can be found in the LICENSE file included with this distribution.

=cut

