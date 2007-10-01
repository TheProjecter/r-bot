package Plugin::Reload;

use strict;
use POE::Session;

sub on_public {

  shift;
  
  my ( $self, $kernel, $who, $where, $msg ) =
    @_[ OBJECT, KERNEL, ARG0 .. $#_ ];
  
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];
  my $time    = sprintf( "%02d:%02d", ( localtime( time() ) )[ 2, 1 ] );
  my $own_nick = $self->{'Nick'};
  
  if( $msg =~ /^$own_nick: !reload$/ ){
    _reload();
  }
  
}

sub _reload {
  
  ## !!warning!! NO auth control for reloading modules. may not be what you want.
  ## return
  
  warn "cannot find plugins\n" and return unless "RBot"->can("plugins");
  
  for(RBot::plugins() ){
    s|::|/|g;
    $_ .= ".pm";
    
    my $ok = do $_;
    
    if(@$ or !$ok){
      warn "$_ has errors, not reloading.\n";
      next;
    }
    else{
      warn "$_ reloaded.\n";
    }
    
    delete $INC{$_};
    require $_;
    
  }
  
  1;
  
}

1;
