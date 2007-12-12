package Plugin::PackageLookup;

$|++;

use strict;
use LWP::Simple qw/get/;
use Compress::Zlib;
use Data::Dumper;
use POE::Session;
use URI;

# SQL table for table packages
#
# CREATE TABLE packages (
#     package character varying(31),
#     url character varying(127),
#     maintainer character varying(255),
#     description text,
#     id serial NOT NULL,
#     repo integer,
#     package_date date,
#     license character varying(32),
#     version character varying(16),
#     updated date,
#     title text,
#     author character varying(64),
#     bundle character varying(128),
#     priority character varying(31)
# );
# 
# ALTER TABLE ONLY packages
#    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);
#
# ALTER TABLE ONLY packages
#    ADD CONSTRAINT packages_repo_fkey FOREIGN KEY (repo) REFERENCES repos(id);
#


sub _db_check {
  "Rbot::DB"->isa("DBIx::Class::Schema");
}

sub on_public {
  
  shift;
  
  return unless _db_check;
  
  my ( $self, $kernel, $who, $where, $msg ) =
    @_[ OBJECT, KERNEL, ARG0 .. $#_ ];
  
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];
  my $time    = sprintf( "%02d:%02d", ( localtime( time() ) )[ 2, 1 ] );
  
  my $own_nick = $self->{'Nick'};
  
  if($msg =~ /$own_nick: (\S+)\?$/) {
    
    my $p = Rbot::DB->resultset("Packages")->search( { package => { like => $1 } } );
    
    
    
    if( $p == 0 ){
      
      warn __PACKAGE__ . " found no package match\n";
      
      return( ["No package found matching '$1'"], [] );
      
    }
    elsif( $p == 1){
      
      warn __PACKAGE__ . " found one package match\n";
      
      $p = $p->single;
      
      my $d = $p->title || $p->description;
      $d =~ s/(.{30}.*?)\b.*/$1 [...]/ if length $d > 35;
      
      my $url = new URI $p->repo->url;
      if( $p->repo->package_url_prefix =~ m|^/| ){
        $url->path( "/" . $p->repo->package_url_prefix . "/" . $p->package . $p->repo->package_url_suffix );
      }
      else{
        $url->path( $url->path . "/" . $p->repo->package_url_prefix . "/" . $p->package . $p->repo->package_url_suffix);
      }
      
      my $n = $p->package;
      
      $n .= sprintf " [%s]", $p->priority if $p->priority;
      
      my $s = sprintf qq{%s - %s %s}, $n, $d, $url;
      return( [$s], [] );
      
    }
    else{
      
      warn __PACKAGE__ . " found more than one package match\n";
      
      my $s = join ", ", map {  sprintf q{%s (%s)},$_->package,$_->repo->name  } $p->all;
      
      return( [$s], [] );
      
    }
    
  }
  
  return ([],[]);
}

## update local package db
sub _update_packages {
  
  return unless _db_check;
  
  my(%dep_info,%suggest_info);
  
  for my $repo ( Rbot::DB->resultset('Repos')->all ) {
    my $zip_data = get( $repo->url . "/src/contrib/PACKAGES.gz" );
    my $package_info = Compress::Zlib::memGunzip($zip_data);
    
    my @chunks = grep {$_} split /Package:/, $package_info;
    
    printf "%s (%d packages). Updating...", $repo->name, scalar @chunks;
    
    for( @chunks ){
      
      $_ = "Package:".$_;
      #print;
      
      my %info = /^(.*?): ?(.*)$/mg;
      
      next unless my $p = $info{Package};
      
      #print Dumper \%info;
      
      $info{Date} =~ s|/|-|g;
      
      my $p = Rbot::DB->resultset("Packages")->find_or_create( { package => $p, repo => $repo->id } );
      $p->update
        ({
          title => $info{Title},
          description => $info{Description},
          version => $info{Version},
          package_date => $info{Date},
          maintainer => $info{Maintainer},
          author => $info{Author},
          priority => $info{Priority},
          bundle => $info{Contains} || $info{Bundle},
          updated => \q{NOW()},
         });
      
      ## what about: Enhances, Imports, 
      
    }
    
    print "done\n";
    
    ## update suggests, depends and perhaps enhances and imports some other time
    
  }
  
}

## also intended for manual use
sub _load_default_repos {
  
  return unless _db_check;
  
  my %repo_data = 
    (
     CRAN => ["http://cran.r-project.org", "/src/contrib/Descriptions", ".html"],
     BioC => ["http://www.bioinformatics.csiro.au/bioconductor/bioc", "html", ".html"],
     Omega => ["http://www.omegahat.org/R", "/", "" ],
    );
  
  while( my($repo,$info) = each %repo_data ){
    my($url) = $info->[0];
    my($pre) = $info->[1];
    my($post) = $info->[2];
    
    my ($r) = Rbot::DB->resultset('Repos')->
      find_or_create( { name => $repo } );
    
    $r->update( {package_url_prefix => $pre, url => $url, package_url_suffix => $post } );
    
  }
  
}






1;
