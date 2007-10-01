package RBot;

use strict;
use base qw/IRC::Bot/;

# needs some constants
use POE::Session;

use Module::Pluggable require => 1, search_path => "Plugin";

sub on_public {
  
  my ( $self, $kernel, $who, $where, $msg ) =
    @_[ OBJECT, KERNEL, ARG0 .. $#_ ];
  
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];
  my $time    = sprintf( "%02d:%02d", ( localtime( time() ) )[ 2, 1 ] );
  
  my $own_nick = $self->{'Nick'};
  
  for my $plugin ( $self->plugins ){
    
    next unless $plugin->can("on_public");
    
    my ($out,$err);
    eval{ ($out,$err) = $plugin->on_public( @_ ); 1; };
    
    $out ||= []; $err ||= [];
    
    $out = [ $out ] unless ref $out eq "ARRAY";
    $err = [ $err ] unless ref $err eq "ARRAY";
    
    my @o = @$out;
    my @e = @$err;
    
    my @show;
    
    @o = (@o[0..2],"(3 lines max output)") if @o>3;
    @e = @e[0..1] if @e>2;
    
    @show = (@o,@e);
    
    s/[\x00-\x19]//g for @show;
    
    if( @show ){
      $self->botspeak( $kernel, $channel, $_ ) for @show;
      return;
    }
    
  }
  
  shift;
  $self->SUPER::on_public( @_ );
  

  
  
  
}

1;
