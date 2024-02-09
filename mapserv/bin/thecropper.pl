#! /usr/bin/perl
use strict;
use warnings;

use Geo::GDAL;
use lib '/home/mapserv/perl';
use Spork;
$|=1;

my $mem="128";
$ENV{'GDAL_CACHEMAX'} = $mem;

my @gdalopts = ("-co","COMPRESS=DEFLATE","-co","PREDICTOR=2","-co","TILED=YES" );
my $tempfile = "/tmp/temp1.$$.tif";

Spork::setup(3);

my $hasalpha=0;

$SIG{INT} = sub  {
local $SIG{HUP} = "IGNORE";
kill "HUP" , -$$;
die;
};

# print the command, run the command
sub print_system {
    print join(" ",@_)."\n";
    
    return (system @_);
};

sub xy_gt {
  my ($x,$y,@gt) = @_;
  if (!defined $x || !defined $y ) {
      die "xy_gt got undefined input";
  };

return( $gt[0] + $x*$gt[1] + $y*$gt[2] ,
	$gt[3] + $x*$gt[4] + $y*$gt[5] );

};

sub get_res {
    my ($sr,$cksrs,$width,$height,$minx,$miny,$maxx,$maxy, @gt) = @_;
    my $srck = Geo::OSR::SpatialReference->new('EPSG' => $cksrs) ; 
    my $diag = sqrt($width ** 2 + $height ** 2) ;
    my $ckproj = new Geo::OSR::CoordinateTransformation($sr,$srck);
     my  ( $x1, $y1 ) = @{$ckproj->TransformPoint($minx,$miny)};
     my  ( $x2, $y2 ) = @{$ckproj->TransformPoint($maxx,$maxy)};
     my  ( $x3, $y3 ) = @{$ckproj->TransformPoint($minx,$maxy)};
     my  ( $x4, $y4 ) = @{$ckproj->TransformPoint($maxx,$miny)};

    my $d_x = $x1-$x2;
    my $d_y = $y1-$y2;
      my $res1 = sqrt($d_x ** 2 + $d_y ** 2) / $diag ;

    $d_x = $x1-$x3;
    $d_y = $y1-$y3;
      my $res2 = sqrt($d_x ** 2 + $d_y ** 2) / $height ;

    $d_x = $x2-$x4;
    $d_y = $y2-$y4;
      my $res3 = sqrt($d_x ** 2 + $d_y ** 2) / $height ;


    $d_x = $x1-$x4;
    $d_y = $y1-$y4;
      my $res4 = sqrt($d_x ** 2 + $d_y ** 2) / $width ;

    $d_x = $x2-$x3;
    $d_y = $y2-$y3;
      my $res5 = sqrt($d_x ** 2 + $d_y ** 2) / $width ;

    return ((sort {$a <=> $b}  ($res1 , $res2, $res3 , $res4, $res5))[0] );


};


sub inv_gt {
  my @gt_in = @_;
  my @gt_out;
   my  $det = $gt_in[1] * $gt_in[5] - $gt_in[2] * $gt_in[4];

  if( abs($det) < 0.000000000000001 ) {
        return undef;
      };
  my $inv_det = 1.0 / $det;

    # compute adjoint, and devide by determinate 

    $gt_out[1] =  $gt_in[5] * $inv_det;
    $gt_out[4] = -$gt_in[4] * $inv_det;

    $gt_out[2] = -$gt_in[2] * $inv_det;
    $gt_out[5] =  $gt_in[1] * $inv_det;

    $gt_out[0] = ( $gt_in[2] * $gt_in[3] - $gt_in[0] * $gt_in[5]) * $inv_det;
    $gt_out[3] = (-$gt_in[1] * $gt_in[3] + $gt_in[0] * $gt_in[4]) * $inv_det;


   return @gt_out;
};



sub getinfo {
    my ($gdal_data) = @_;
# determine the corners
my ($width,$height) = $gdal_data->Size();
my @gt = @{$gdal_data->GetGeoTransform()};



print "GT: ".join(",",@gt)."\n";
my $minx = $gt[0];
my $miny = $gt[3] + $width*$gt[4] + $height*$gt[5];
my $maxx = $gt[0] + $width*$gt[1] + $height*$gt[2];
my $maxy = $gt[3];

# returns, width,height,bbox,gt
    if ($minx > $maxx) { my $swap = $maxx ; $maxx=$minx; $minx=$swap;};
    if ($miny > $maxy) { my $swap = $maxy ; $maxy=$miny; $miny=$swap;};
    return ($width,$height,$minx,$miny,$maxx,$maxy, @gt) ;
};

eval {
my $i=$ARGV[0];
my $infile = $tempfile;

my $basepath="/home/mapserv/";
my $shapeindex_work=$basepath."charts/work/";
my $shapeindex_out=$basepath."charts/index/";

my $mapfiles_path=$basepath."mapfiles/includes/";

my $charts_path=$basepath."charts/";
my $bref_path=$basepath."charts/bref/";

my $inbasename = $i;
$inbasename =~ s!.*/!!;
$inbasename =~ s!\.tif$!!;

my $bref_file = undef;
if ($i =~ /$basepath/ ) {
    if ($inbasename =~ m!^(.+?) (\d+)( North| South| East| West|)$!i ) {

	$inbasename = $1;
	if (defined $3 && $3 ne "" ) {
	    $inbasename .= $3;
	};

    };
    $bref_file = $bref_path.$inbasename.".bref";
    print "Bref_Path: $bref_file\n";
};






my $data = Geo::GDAL::Open($i,"ReadOnly");
my $wkt = $data->Projection();
    if (!defined $wkt || $wkt eq "" ) {
	die "No projection for $infile :: $i\n";
    };
#print $wkt."\n";
my $sr = Geo::OSR::SpatialReference->new('WKT' => $wkt);
my $p4 = $sr->ExportToProj4();
#print $p4."\n";
my $srout = Geo::OSR::SpatialReference->new('EPSG' => 4326) ; 
$srout->SetAxisMappingStrategy($Geo::OSR::OAMS_TRADITIONAL_GIS_ORDER);


my $reproj = new Geo::OSR::CoordinateTransformation($sr,$srout);
my $invreproj = new Geo::OSR::CoordinateTransformation($srout,$sr);

    my $rotated=0;

    my ($width,$height,$minx,$miny,$maxx,$maxy, @gt) = getinfo($data);

    if ($gt[2] != 0 || $gt[4] != 0 ) {
	$rotated=1;
	print "ROTATED\n";
    };

my $rastercount = $data->{'RasterCount'};
print "Raster Count: $rastercount\n";
#my $bands = $data->bands;
if ($rastercount == 1 ) {
print_system("pct2rgb.py",$i,$infile.".1.tif");
if ( -s $infile.".1.tif" ) {
	print_system("gdalwarp","-dstalpha",$infile.".1.tif",$infile);
    if ($?) {
        unlink $infile.".1.tif";
        die "gdal_translate: $?";
    };
	unlink $infile.".1.tif";
} else {	
	 die "pct2rgb: $?";
};
	$hasalpha=1;	
} elsif ($rastercount == 2) {
    $hasalpha = 1;
    print_system("gdal_translate","-expand","rgba",$i,$infile);
    if ($?) { 
	die "gdal_translate: $?";
    }; 

} elsif ($rastercount == 3) {
    $infile = $i;
} elsif ($rastercount == 4 ) {
    $infile = $i;
    $hasalpha=1;
}




# iterate through the possible files.
my @filelist;
my $out_optimized = $i;
$out_optimized =~ s/\.tif$/-o.tif/i;
my $out_cropped = $i;
$out_cropped =~ s/\.tif$/-c/i;


$filelist[0] = {
    'infile' => $infile,
    'outfile' => $out_optimized,
    'straighten' => $rotated,
		'crop' => 0,
		'out_srs' => undef,
		'stage' => 0 ,
};

$filelist[1] = {
    'infile' => $infile,
    'outfile' => $out_cropped."a.tif",
    'straighten' => $rotated,
    'crop' => 1,
    'out_srs' => 3857,
				'stage' => 0 ,

};


$filelist[2] = {
    'infile' => $infile,
    'outfile' => $out_cropped."b.tif",
    'straighten' => $rotated,
    'crop' => 1,
    'out_srs' => 4326,
		'stage' => 0 ,

};

# check for crops

  my @igt = inv_gt(@gt);
  print "$width $height $minx $miny $maxx $maxy\n";
  
  my $nocrop=0;
  
  my @refbox;
  my $refcount=0;
  
  # now check the provided bounding box from  a ref file if there is one
  my $ref =  $i;
  $ref =~ s/\.tif$/.aref/i;
  if (defined $bref_file && ! -s $ref && -s $bref_file ) {
      print "Using Bref: $bref_file\n";
      $ref = $bref_file;
      $bref_file = undef;
  };
  print "REF: $ref\n";


  # grab the ref data
  my $line = "";
  if (open REF,"<",$ref ) {
      if (defined $bref_file) {open BREF,">",$bref_file or $bref_file=undef;};

    while (<REF>) {
      chomp;
      if (/FULL/) {
        $nocrop=1;
        if (defined $bref_file) { print BREF "FULL\n"; };
	last;
      };

      if (/^([a-z]) ([-0-9.]+) ([-0-9.]+) (\w+)/i ) {
	my $type = $1;
	my $x= $2;
	my $y = $3 ;
	my $linetype = $4;
	$refbox[$refcount]->{'linetype'} = $linetype;
	
	# load all 3 locations
	# x_p, y_p; x_m, y_meter; x_geo, y_geo
	if ( $type eq "p" ) {
	  # pixels come in
	  $refbox[$refcount]->{'x_p'}=$x;
	  $refbox[$refcount]->{'y_p'}=$y;
	  
	  # and become meters
	  if (!defined $refbox[$refcount]->{'x_m'} ) {
	    ( $refbox[$refcount]->{'x_m'},
	      $refbox[$refcount]->{'y_m'} )  = xy_gt($x,$y,@gt)
	    }
	  $x= $refbox[$refcount]->{'x_m'};
	  $y= $refbox[$refcount]->{'y_m'};
	  
	  $type = 'm';
	};
	if ( $type eq "m" ) {
	  # meters come in 
	    if (! defined $refbox[$refcount]->{'x_m'} ) {
	  $refbox[$refcount]->{'x_m'}=$x;
	  $refbox[$refcount]->{'y_m'}=$y;
}	  
	  if (!defined $refbox[$refcount]->{'lat'} ) {
	    ( $refbox[$refcount]->{'x_g'},
	      $refbox[$refcount]->{'y_g'} )  =
		@{$reproj->TransformPoint($x,$y)};
	  };
	  $x= $refbox[$refcount]->{'x_g'};
	  $y= $refbox[$refcount]->{'y_g'};
	}
      	if ($type eq "g" ) {
	  # LL come in and become meters and pixels

	    if (! defined $refbox[$refcount]->{'x_g'} ) {
		$refbox[$refcount]->{'x_g'}=$x;
		$refbox[$refcount]->{'y_g'}=$y;
	    }	      

	  if (!defined $refbox[$refcount]->{'x_m'}) {
	    ( $refbox[$refcount]->{'x_m'},
	      $refbox[$refcount]->{'y_m'} )  =
		@{$invreproj->TransformPoint($x,$y)};
	  };
  
	  if (!defined $refbox[$refcount]->{'x_p'}) {
	    ( $refbox[$refcount]->{'x_p'},
	      $refbox[$refcount]->{'y_p'} )  = xy_gt( $refbox[$refcount]->{'x_m'},
						      $refbox[$refcount]->{'y_m'}, @igt );
	  };
	};
	if (defined $bref_file) {
	    print BREF "g ".$refbox[$refcount]->{'x_g'}." ".$refbox[$refcount]->{'y_g'}." ".$linetype."\n";
	};
	
	$refcount++;
      }
    }
      if (defined $bref_file) {close BREF;}
    close REF;
  } else {
      die "Could not open ref file: $ref";
  };

  if (!$nocrop && ! @refbox) {
    die "no aref";
  };


  
for my $file (@filelist) {
  if ($nocrop || ! $file->{'crop'} || $file->{'stage'} > 0 || !defined $file->{'outfile'}) {
	  if ($nocrop) {$file->{'crop'} = 0;};
    next;
  };
$file->{'stage'} =1;

  if (!@refbox) {
      die "FAIL";
  };
  
  ######################################
  my @cutline;

  
  # now we have points, make lines
  for my $cki (0..@refbox - 1 ) {
    my $ckj = $cki+1;
    if (! defined $refbox[$ckj] ) {
      $ckj=0;
    };
    
    my $linetype = $refbox[$cki]->{'linetype'};
    # determine the number of pixels for this line in pixel space
    my $pixlength = int( sqrt(($refbox[$cki]->{'x_p'} - $refbox[$ckj]->{'x_p'} )**2  + 
			      ($refbox[$cki]->{'y_p'} - $refbox[$ckj]->{'y_p'} )**2  ) /6.3 ) ;
    
#    print $pixlength."\n";
    if ($pixlength == 0 ) {
      die "Returned pixlength is 0, duplicate points?";
    };


    
    # now iterate
    # the incoming data has all needed refs, so we just transform to geo as we draw the line
    my $x_0 = $refbox[$cki]->{'x_'.$linetype};
    my $y_0 = $refbox[$cki]->{'y_'.$linetype};
    my $x_1 = $refbox[$ckj]->{'x_'.$linetype};
    my $y_1 = $refbox[$ckj]->{'y_'.$linetype};
    if (!defined $x_0 || !defined $x_1 || !defined $y_0 || !defined $y_1) {
	die "x_# or y_# undefined for $linetype";
    };
    
    my $d_x = $x_1 - $x_0;
    my $d_y = $y_1 - $y_0;
    if ($linetype eq "g" && abs($d_x) > 45) {
      $d_x=-1* (abs($d_x) / $d_x) * (360 - abs($d_x));
      
    };
    
    
    
    #print "***********\n";
    for my $k (0..$pixlength) {
	    if ($k == 0 && $cki != 0 ) {
		    next;
	}
      my $x_n = $x_0 + (($d_x * $k)  / $pixlength) ;
      my $y_n = $y_0 + (($d_y * $k)  / $pixlength) ; 
      if ($linetype eq "g" && abs($x_n) >180) {
	$x_n = (abs($x_n) / $x_n) * (abs($x_n) - 360);
      };
      # transform the point to the desired output format
      #print "- $x_n $y_n\n";
      if ($linetype eq "p" ) {
	# make it meters;
	($x_n,$y_n) = xy_gt($x_n,$y_n,@gt);
      };
      if ($linetype eq "p" || $linetype eq "m" ) {
	# make it latlon
	( $x_n,$y_n ) =  @{$reproj->TransformPoint($x_n,$y_n)};
      };
      #print "$x_n $y_n\n";
      push @cutline,"$x_n $y_n";
      print "$x_n $y_n $k $cki $ckj\n";
    };
  };
  


  # now check the cutline for +- 180;
  my $x_prev;
  my @cutline_out0;
  my @cutline_out1;
  my $cl_out = 0;
  for my $cl (@cutline) {
    my ($x_c, $y_c) = split / /,$cl;
    if (defined $x_prev && abs($x_c - $x_prev ) > 90) {
      $cl_out = 1-$cl_out;
    };
    $x_prev = $x_c;
    if ($cl_out == 0 ) {
      push @cutline_out0,$cl;
    };
    
    if ($cl_out == 1 ) {
      push @cutline_out1,$cl;
    };
  }
  $file->{'cutline'} = \@cutline_out0;
  if (@cutline_out1) {
    push @cutline_out1,$cutline_out1[0];
    my $outfile = $file->{'outfile'};
    $file->{'outfile'} =~ s/\.tif$/x.tif/;
    $file->{'180flag'} = 1;
    my $res = get_res ($sr,$file->{'out_srs'},$width,$height,$minx,$miny,$maxx,$maxy, @gt) ;
    $file->{'res'} = $res;
    $outfile =~ s/\.tif$/y.tif/;
    
    push @filelist , {
		      'infile' => $file->{'infile'},
		      'outfile' => $outfile,
		      'straighten' => $file->{'rotated'},
		      'crop' => 1,
		      'out_srs' => $file->{'out_srs'},
		      'stage' => 1 ,
		      '180flag' => 1,
		      'res' => $res,
		      'cutline' => \@cutline_out1
		     };
  };
  
}

for my $file (@filelist) {
  if ( !$file->{'crop'} ||  !defined $file->{'outfile'}) {
    next;
  };
# generate the crop file
my $csv = $file->{'outfile'};
$csv =~ s/\.tif$/.csv/i;

my $vrt = $file->{'outfile'};
$vrt =~ s/\.tif$/.vrt/i;

my $csvshort = $csv;
$csvshort =~ s!.*/!!;
my $csvbase = $csvshort;
$csvbase =~ s/.csv$//;



open OUT,">",$csv or die;
print OUT "\"ID\",\"THEGEOM\"\n";
print OUT '1,"POLYGON (('.(join ",",@{$file->{'cutline'}}).'))"'."\n";
close OUT;


open OUT,">",$vrt or die;

print OUT <<END;
<OGRVRTDataSource>
    <OGRVRTLayer name="${csvbase}">
        <SrcDataSource relativeToVRT="1">${csvshort}</SrcDataSource>
        <GeometryType>wkbPolygon</GeometryType>
        <FID>ID</FID>
        <GeometryField encoding="WKT" field="THEGEOM" />
        <LayerSRS>epsg:4326</LayerSRS>
    </OGRVRTLayer>
</OGRVRTDataSource>

END

close OUT;
  $file->{'gdalwarp_opts'} = ["-cutline",$vrt, "-crop_to_cutline" ];
  
  if (defined $file->{'180flag'} ) {
    push @{$file->{'gdalwarp_opts'}} , ("-tr",$file->{'res'},$file->{'res'});
  };
};




for my $file (@filelist) {
  if ( !defined $file->{'outfile'}) {
    next;
  };
  $file->{'stage'} = 10;
  if (! $file->{'gdalwarp_opts'} ) {
      $file->{'gdalwarp_opts'} = [];
  };
  if (defined $file->{'out_srs'} ) {push @{$file->{'gdalwarp_opts'}} , ("-t_srs","EPSG:".$file->{'out_srs'}) ;}
  unlink $file->{'outfile'};
  my @da = ("-dstalpha");
  if ($hasalpha) {
      @da = ();
}
# "-wm" $mem
  print_system "gdalwarp","-wm",$mem,"-r","cubic",(@gdalopts, @da),
  @{$file->{'gdalwarp_opts'}},$file->{'infile'},$file->{'outfile'} ;
  if ($?) { 
      die "gdalwarp: $?";
  };
  
  print_system "gdaladdo", "-r" , "gauss" , "--config","COMPRESS_OVERVIEW","DEFLATE","--config","PREDICTOR_OVERVIEW","2", $file->{'outfile'},"2","4","8","16";
  if ($?) { 
      die "gdaladdoq: $?";
  };
  
  
}

} ;

unlink $tempfile;

if ($@ ) {
    die ;
};



