
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'File::Find' => '0',
    'File::Temp' => '0',
    'Module::Build' => '0.3601',
    'Test::More' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Allows use of Module::Build and ExtUtils::MakeMaker in a dzil dist',
  'dist_author' => [
    'Apocalypse <APOCAL@cpan.org>'
  ],
  'dist_name' => 'Dist-Zilla-Plugin-DualBuilders',
  'dist_version' => '1.001',
  'license' => 'perl',
  'module_name' => 'Dist::Zilla::Plugin::DualBuilders',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Dist::Zilla::Role::AfterBuild' => '3.101461',
    'Dist::Zilla::Role::InstallTool' => '3.101461',
    'Dist::Zilla::Role::PrereqSource' => '3.101461',
    'Moose' => '1.03',
    'Moose::Util::TypeConstraints' => '1.01',
    'perl' => '5.006'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
