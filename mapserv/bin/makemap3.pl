#! /usr/bin/perl
use strict;
use warnings;

use Geo::GDAL;
use IPC::Open3;
use File::Find;
    use Symbol qw(gensym);
use lib '/home/mapserv/perl';
use Spork;
my $thecropper_path = "/home/mapserv/bin/thecropper.pl";
my $thecropper2_path = "/home/mapserv/bin/thecropperblah.pl";


my $mem="768";
$ENV{'GDAL_CACHEMAX'} = $mem;


Spork::setup(1);


$SIG{INT} = sub  {
local $SIG{HUP} = "IGNORE";
kill "HUP" , -$$;

};

# print the command, run the command
sub print_system {
    print join(" ",@_)."\n";
    
    return (system @_);
};

sub get_res {
  my @gt = @_;
  return (sqrt ( $gt[1] ** 2 + $gt[4] ** 2 )  +
    sqrt ( $gt[2] ** 2 + $gt[5] ** 2 ) ) /2 ;
};

sub do_convert {
  my ($file) = @_;

  print_system($thecropper_path,$file);
  if ($? >>8 >0 ) {
  print_system($thecropper2_path,$file);
  }
  return($? >> 8);

};


our @list;


sub getinfo {
    my ($gdal_data) = @_;
# determine the corners
my ($width,$height) = $gdal_data->Size();
my @gt = @{$gdal_data->GetGeoTransform()};



print join(",",@gt)."\n";
my $minx = $gt[0];
my $miny = $gt[3] + $width*$gt[4] + $height*$gt[5];
my $maxx = $gt[0] + $width*$gt[1] + $height*$gt[2];
my $maxy = $gt[3];

# returns, width,height,bbox,gt
    if ($minx > $maxx) { my $swap = $maxx ; $maxx=$minx; $minx=$swap;};
    if ($miny > $maxy) { my $swap = $maxy ; $maxy=$miny; $miny=$swap;};
    return ($width,$height,$minx,$miny,$maxx,$maxy, @gt) ;
};

sub find_wanted {
    my $fn = $File::Find::name;
    if ($fn =~ /.tif(f|)$/i && -s $fn ) {
	print "$fn\n";
	push @list,$fn;
    };
};

##########################
my $test = "";
if (defined $ARGV[0] && $ARGV[0] eq "test" ) {
    shift @ARGV;
    $test = ".t";
};




my $basepath="/home/mapserv/";

my $shapeindex_work=$basepath."charts/work".$test."/";
my $shapeindex_out=$basepath."charts/index".$test."/";

mkdir $shapeindex_work;
mkdir $shapeindex_out;

my $mapfiles_path=$basepath."mapfiles/includes/";

my $charts_path=$basepath."charts/";

if (defined $ARGV[0] && $ARGV[0] eq "stage" ) {
    shift @ARGV;
        $charts_path =~ s/charts/stage/;
};




my @charts_list;
if (@ARGV ) {
    @charts_list = @ARGV;
} else {
#@charts_list = ("secb","tacb","helb");
@charts_list = ("sec","tac","hel","enrl","enrh","enra");

}




for my $charttype (@charts_list) {


    my $outmapfile = $mapfiles_path.$charttype.$test.".inc";

    open MAP,">",$outmapfile.".tmp" or die "Could not open $outmapfile for write: $!";

my %dedup;
my %out;
my %outparse;

# find all the possible charts
    undef @list;
    my $currentbase = $charts_path.$charttype."/";
    
    find(\&find_wanted , $currentbase) ;



my $i;
for  $i (sort {$b cmp $a} @list) {
# only take the newest file
# all have a yyyymmdd named directory(by us)


    if ($i =~ /(disable.*|_r.tif|_[tuvw].tif|_[lr][tuvw].tif)$/ ) {
      print "Skip: $i\n";
	next;
    };
  if ($i =~ m!([a-z]+)/(\d+)/([^/]+.tif)$! ) {
      if (!defined $dedup{$1.$3} || $2 > $dedup{$1.$3} ) {
	  $out{$1.$3} = $i;
	  $dedup{$1.$3} = $2;
      }


      } else {
	  
      $out{$i}=$i;
  };
};





for $i (sort values %out) {

  # load the parameters for this file
    if ($i =~ /(-o|-c[a-f]|-c[a-f][x-z]|_[lruvw]+).tif$/  || ! -s $i) {
      
	print "Ignoring rotated or trimmed or tmp or missing file $i \n";
	next;
    };
    print "\nProcessing: $i\n";
  
  my $html =  $i;
  my $basename;
  my $longname;
    my $group = "All";
      $group = uc($charttype);


    my $trimmedgroup=lc($charttype);



    $i =~ m!/([^/]+).tif!i ;
    $basename = $1;
    $longname = $1;
if ($i =~ /FLY/ ) {
	print "Flyway, $i skipping\n";
	 next;
;}
my $data = Geo::GDAL::Open($i,"ReadOnly");
my $wkt = $data->GetProjectionRef();
    if (!defined $wkt || $wkt eq "" ) {
	print "No projection for $i, skipping\n";
	next;
    };
#print $wkt."\n";
my $sr = Geo::OSR::SpatialReference->new('WKT' => $wkt);
my $p4 = $sr->ExportToProj4();
#print $p4."\n";

    my $rotated=0;

    my ($width,$height,$minx,$miny,$maxx,$maxy, @gt) = getinfo($data);
  my %outbbox;
    undef $data;


print "$width $height $minx $miny $maxx $maxy\n";

    my $nocrop=0;


# output this layer
my %in_progress;
  for my $q  (0,1,2) {
      if (defined $ENV{"NOTRIM"} && $q>0) {
	  next;
      };
      my $need_convert = 0;
      my $ckfn = $i;
      $ckfn =~ s/.tif$/.force/ ;
      if (-r $ckfn) {
	  $need_convert=1;
      };

  my $nospacename = $longname;
  $nospacename =~ s/(\s+)/_/g;
  my $nospacebasename = $basename;
  $nospacebasename =~ s/(\s+)/_/g;
  my $outlongname=$longname;
  my $file = $i;
      $file =~ s/.tif$/-o.tif/i;
      my $srs = 0;
      if ($q == 1 ) {
      
	$nospacename.="_Trimmed";
	$nospacebasename = $trimmedgroup;
	$outlongname.=" Trimmed";
	$srs=3857;
	$file =~ s/-o.tif$/-ca.tif/i;
      };
      if ($q == 2 ) {
	
	$nospacename.="_Trimmed_4326";
	$nospacebasename = $trimmedgroup."_4326";
	$outlongname.=" Trimmed 4326";
	$srs = 4326;
	$file =~ s/-o.tif$/-cb.tif/i;
      };
    
      my $outp4=$p4;
      if ($srs != 0 ) {
	  $outp4 = "init=epsg:".$srs;
      };

# check for file
    my $ckname = $file;
    $ckname =~ s!.*/([^/]+/[^/]+$)!$1!;
    $ckname =~ s!\.!\\.!;
      print $ckname."\n";
    if (!grep /$ckname/,@list) {
      if ($ckname =~ m/-c[a-f]\\\.tif/ ) {
	$ckname =~ s/\\\.tif/.\\.tif/ ;
	    if (scalar grep /$ckname/,@list != 2) {
	      $need_convert=1;
	    };
      } else {
	$need_convert=1;
      }
    }
    if ($need_convert && ! defined $in_progress{$i}) {
	$in_progress{$i}=1;

      print "Convert: $i\n";
                    Spork::do_spork(\&do_convert,
                                    $i
                                    );

		  };
	Spork::do_wait();
      $outparse{$i}{$q} = { 
			    'nospacename' => $nospacename,
			    'nospacebasename' => $nospacebasename,
			    'longname' => $longname,
			    'file' => $file,
			    'p4' => $outp4,
			    'res' => get_res(@gt)
			    };


    }
  }

   Spork::do_wait();
 
    my @index_shp;
    my @index_shp_4326;
# phase 2
for $i (sort { $outparse{$b}{0}{'res'} <=> $outparse{$a}{0}{'res'} } keys %outparse) {

  # load the parameters for this file
    if (! defined $outparse{$i} ) {
      
#	print "Ignoring rotated or trimmed or tmp file $i \n";
	next;
    };
    print "\nProcessing2: $i\n";

    for my $q ( 0,1,2 ) {
      my $d = $outparse{$i}{$q};

      my @l = ('');
	if ( ! -s $d->{'file'} ) {
	  @l = ('x','y') ;
	  print "Pony\n";
	};
      for my $letter (@l) {

	my $fileck = $d->{'file'};
	if ($letter ne '' ) {
	  $fileck =~ s/-c([a-f]).tif/-c$1$letter.tif/;
	};
      print "Chk: $fileck\n";

      my $realdata = Geo::GDAL::Open($fileck,"ReadOnly");
      my ($rwidth,$rheight,$rminx,$rminy,$rmaxx,$rmaxy, @rgt) = getinfo($realdata);
      undef $realdata;
      my $extent= "EXTENT ".$rminx." ".$rminy." ".$rmaxx." ".$rmaxy."\n";
      
    
      

      if ($q == 1 ) {
	push @index_shp , $fileck;
      } 

      if ($q == 2 ) {
	push @index_shp_4326 , $fileck;
      } 

  
      my $outstring = "";
  
      $outstring .= "LAYER\n";
      $outstring .= "NAME \"".$d->{'nospacename'}."\"\n";
	  $outstring .= "GROUP \"".$d->{'nospacebasename'}."\"\n";
      $outstring .= "METADATA\n";
      $outstring .= "\"wms_title\" \"".$d->{'longname'}."\"\n";
      $outstring .= "END\n";
      $outstring .= "TYPE RASTER\n";
      $outstring .= "STATUS ON\n";
      $outstring .= "TYPE RASTER\n";
      $outstring .= "PROJECTION\n";
      $outstring .= "   \"".$d->{'p4'}."\"\n";
      $outstring .= "END\n";
      $outstring .= "DATA \"".$fileck."\"\n";
      $outstring .= $extent;

      $outstring .= "END\n\n";
      print MAP $outstring;
      };
    };

};

    close MAP;
# shape index
    print_system "gdaltindex",$shapeindex_work.$charttype."_index.shp",@index_shp;
    print_system "shptree",$shapeindex_work.$charttype."_index.shp";
    for my $moveit (glob($shapeindex_work.$charttype."_index.*" ) ) {
	my $out = $moveit;
	$out =~ s/$shapeindex_work/$shapeindex_out/;
	rename $moveit , $out;
    };


    print_system "gdaltindex",$shapeindex_work.$charttype."_4326_index.shp",@index_shp_4326;
    print_system "shptree",$shapeindex_work.$charttype."_4326_index.shp";
    for my $moveit (glob($shapeindex_work.$charttype."_4326_index.*" ) ) {
	my $out = $moveit;
	$out =~ s/$shapeindex_work/$shapeindex_out/;
	rename $moveit , $out;
    };


    rename $outmapfile.".tmp",$outmapfile;
};
