## A very general db interface based on DBIx::Class
package Plugin::DatabaseInterface;

use strict;
use YAML qw/DumpFile LoadFile/;
use File::Basename;

( my $p = __PACKAGE__ ) =~ s|::|/|g;
$p .= ".pm";
my $d = $INC{$p} or die "failed finding my own directory?!\n";
my $own_dir = dirname( $d );
my $setup_file = $own_dir . "/.db_setup.yml";

my $setup = LoadFile $setup_file;

{ package Rbot::DB;
  
  use base qw/DBIx::Class::Schema::Loader/;
  
  __PACKAGE__->loader_options
    (
     relationships           => 1,
     debug                   => 0,
    );
  
  
  __PACKAGE__->connection
    ( "dbi:Pg:dbname=".$setup->{database}, $setup->{username} , $setup->{password}, );
  
}

## intended for manual setup
sub setup {
  
  my $host_default = ref $setup eq "HASH" ? $setup->{hostname} || "localhost" : "localhost";
  print "Postgresql connection setup\n";
  print " - hostname: [$host_default] ";
  chomp(my $hostname=<STDIN>);
  $hostname ||= $host_default;
  
  my $user_default = ref $setup eq "HASH" ? $setup->{username} || "rbot" : "rbot";
  print " - username: [$user_default] ";
  chomp(my $username=<STDIN>);
  $username ||= $user_default;
  
  my $pass_default = ref $setup eq "HASH" && $setup->{password} ? "*****" : "";
  print " - password: [$pass_default] ";
  chomp(my $password=<STDIN>);
  $password ||= ref $setup eq "HASH" ? $setup->{password} : "";
  
  my $database_default = ref $setup eq "HASH" ? $setup->{database} || "rbot" : "rbot";
  print " - database: [$database_default] ";
  chomp(my $database=<STDIN>);
  $database ||= $database_default;
  
  DumpFile $setup_file,
    { hostname => $hostname, username => $username, password => $password, database => $database };
  
}

1;
