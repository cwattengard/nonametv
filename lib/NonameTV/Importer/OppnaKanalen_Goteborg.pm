package NonameTV::Importer::OppnaKanalen_Goteborg;

use strict;
use warnings;

=pod

Import data from Y&S

Features:

=cut

use utf8;

use DateTime;
use Spreadsheet::ParseExcel;

use NonameTV qw/norm AddCategory MonthNumber/;
use NonameTV::DataStore::Helper;
use NonameTV::Log qw/progress error/;
use NonameTV::Config qw/ReadConfig/;

use NonameTV::Importer::BaseFile;

use base 'NonameTV::Importer::BaseFile';

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new( @_ );
  bless ($self, $class);

  my $dsh = NonameTV::DataStore::Helper->new( $self->{datastore} );
  $self->{datastorehelper} = $dsh;

  return $self;
}

sub ImportContentFile {
  my $self = shift;
  my( $file, $chd ) = @_;

  $self->{fileerror} = 0;

  if( $file =~ /\.xls$/i ){
    $self->ImportFlatXLS( $file, $chd );
  } else {
    error( "OKGoteborg: Unknown file format: $file" );
  }

  return;
}

sub ImportFlatXLS
{
  my $self = shift;
  my( $file, $chd ) = @_;

  my $dsh = $self->{datastorehelper};
  my $ds = $self->{datastore};

  my %columns = ();
  my $date;
  my $currdate = "x";

  progress( "OKGoteborg: $chd->{xmltvid}: Processing $file" );

  my $oBook = Spreadsheet::ParseExcel::Workbook->Parse( $file );

    my($iR, $oWkS, $oWkC);
	
	  my( $time, $episode );
  my( $program_title , $program_description );
    my @ces;
  
  # main loop
  foreach my $oWkS (@{$oBook->{Worksheet}}) {

    for(my $iR = 1 ; defined $oWkS->{MaxRow} && $iR <= $oWkS->{MaxRow} ; $iR++) {

      # date (column 1)
      $oWkC = $oWkS->{Cells}[$iR][0];
      if($oWkC->Value ne "") {
	  		if(isDate( $oWkC->Value ) ){
					$date = ParseDate( $oWkC->Value );
	  		}
	  	}
	  
	  	if($date ne $currdate ) {
    		if( $currdate ne "x" ) {
					$dsh->EndBatch( 1 );
    		}

        my $batchid = $chd->{xmltvid} . "_" . $date;
        $dsh->StartBatch( $batchid , $chd->{id} );
        $dsh->StartDate( $date , "06:00" );
        $currdate = $date;

        progress("OKGoteborg: Date is: $date");
      }


      $oWkC = $oWkS->{Cells}[$iR][1];
      next if( ! $oWkC );
      my $time = ParseTime( $oWkC->Value );
      next if( ! $time );
      
      $oWkC = $oWkS->{Cells}[$iR][2];
      my $endtime = "";
      if($oWkC->Value ne "") {
      	$endtime = ParseTime( $oWkC->Value );
      }

      $oWkC = $oWkS->{Cells}[$iR][4];
      my $title =  norm( $oWkC->Value );
      
      if( $time and $title ){
	  
	  # empty last day array
      undef @ces;
	  
        progress("$time - $title");

        my $ce = {
          channel_id   => $chd->{id},
          title        => $title,
          start_time   => $time,
        };
		
				$ce->{end_time} = $endtime if $endtime;
		
        $dsh->AddProgramme( $ce );
		
				push( @ces , $ce );
      }

    } # next row
	
  } # next worksheet

  $dsh->EndBatch( 1 );
  
  return;
}

sub isDate {
  my ( $text ) = @_;

  # format '2011-04-13'
  if( $text =~ /^\d{4}\-\d{2}\-\d{2}$/i ){
    return 1;

  # format '2011/05/12'
  } elsif( $text =~ /^\d{4}\/\d{2}\/\d{2}$/i ){
    return 1;
  }
	return 0;
}

sub ParseDate {
  my ( $text ) = @_;

  my( $year, $day, $month );

  # format '2011-04-13'
  if( $text =~ /^\d{4}\-\d{2}\-\d{2}$/i ){
    ( $year, $month, $day ) = ( $text =~ /^(\d{4})\-(\d{2})\-(\d{2})$/i );

  # format '201'
  } elsif( $text =~ /^\d{4}\/\d{2}\/\d{2}$/i ){
    ( $year, $month, $day  ) = ( $text =~ /^(\d{4})\/(\d{2})\/(\d{2})$/i );
  }
  
  #my $dt2 = DateTime->now;
  #$year   = $dt2->year;

  my $dt = DateTime->new(
    year => $year,
    month => $month,
    day => $day
      );
	return $dt->ymd("-");
}

sub ParseTime {
  my( $text ) = @_;
  
	if($text ne "") {
  	my( $hour , $min );

  	if( $text =~ /^\d+:\d+$/ ){
  	  ( $hour , $min ) = ( $text =~ /^(\d+):(\d+)$/ );
  	}

  	return sprintf( "%02d:%02d", $hour, $min );
  } else {
  	return 0;
  }
}

1;
