package Plugin::Rexec;

use strict;

# needs some constants
use POE::Session;

use File::Temp qw/tempfile/;
use File::Basename qw/dirname/;
use Time::HiRes qw/tv_interval gettimeofday/;
use IPC::Open3;

my $time_limit = 5;  # time limit in seconds
my $max_lines = 5;   # max no lines allowed in output
my $max_length = 40; # max char length per line

( my $p = __PACKAGE__ ) =~ s|::|/|g;
$p .= ".pm";

#my $temp_dir = dirname( $INC{$p} ) . "/tmp/rbot_tmpfiles/";
my $temp_dir = "/tmp/rbot_tmpfiles/";

sub make_temp_file {
  
  my ($fh, $filename) = tempfile( DIR => $temp_dir, UNLINK => 1, );
  
}

sub on_public {
  
  shift;
  
  my ( $self, $kernel, $who, $where, $msg ) =
    @_[ OBJECT, KERNEL, ARG0 .. $#_ ];
  
  #my $msg = shift;
  
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];
  my $time    = sprintf( "%02d:%02d", ( localtime( time() ) )[ 2, 1 ] );
  
  my $own_nick = $self->{'Nick'};
  
  if ($msg=~/^\s*!run:?\s*(.*)$/ or $msg =~ /^eval:(.*)/) {
    
    (my $code = $1) =~ s/^\s*//;
    $code =~ s/\s*$//;
    
    my($o,$e);
    eval{ ($o,$e) = run_code($code); 1; };
    
    @$o=q(code ok but no output) unless @$o or @$e;
    
    if( $@ ){
      ## error
      push @$e, $@;
    }
    
    $_ = "$nick: " . $_ for(@$o,@$e);
    
    return ($o,$e);
    
  } 
  else {
    return undef;
  }
}

sub run_code {
  
  my $code = shift or return (["no code?"],[]);
  
  my($fh,$filename) = make_temp_file;
  
  print $fh "setwd('/tmp/rbot_tmpfiles')\n";
  print $fh $code;
  close $fh;
  
  my($wtr, $rdr, $err);
  
  #my $p = open my $rdr, '-|';
  
  my $p = open3
    ( $wtr, $rdr, $err,
      "TMP=/tmp/rbot_tmpfiles nice -n 19 ./R.run --slave --vanilla --no-readline < $filename" );
  
  return ( [], ["error: Failed fork"]) unless defined $p;
  
  if ($p) {
    my $rin = '';
    vec($rin,fileno($rdr),1) = 1;
    my ($nfound,$timeleft) = select($rin, undef, undef, $time_limit);
    
    if ($nfound) {
      
      my @output = <$rdr>;
      my @error = <$err>;
      
      @output = grep !/^Execution halted\n?/, @output;
      
      waitpid $p, 0;
      unlink $filename if -e $filename;
      return ( [@output], [@error] );
      
    }
    else {
      kill KILL => $p;
      waitpid $p, 0;
      unlink $filename if -e $filename;
      return ([], [sprintf "Process timed out. (max %d sec)", $time_limit] );
    }
    
    waitpid $p, 0;
    
  }
  else {
    
  }
  
  return (["what do you mean 'run'?"],[]);
  
}

1;
