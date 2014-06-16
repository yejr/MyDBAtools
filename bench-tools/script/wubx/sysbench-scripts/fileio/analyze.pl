#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my @cols = qw(
      size type num_threads bytes_sec req_sec pct_95 maxt);

my @results;
my %hash;

while ( <> ) {
   /PARAMS (\S+) (\S+) (\d+)/ && do {
      if ( %hash ) {
         push @results, {%hash};
         %hash = ();
      }
      $hash{size} = $1;
      $hash{type} = $2;
      $hash{num_threads} = $3;
      next;
   };
   /Total transferred/ && do {
      ($hash{bytes_sec}) = m{\(([^/]+)};
      next;
   };
   /approx.  95 percentile:\D+(\d.+)ms/ && do {
      $hash{pct_95} = $1;
      next;
   };
   /max:\D+(\d.+)ms/ && do {
      $hash{maxt} = $1;
      next;
   };
   /([0-9.]+)\s+Requests.sec executed/ && do {
      $hash{req_sec} = $1;
      next;
   };
}

$hash{pct_95} ||= '0.0000'; # Sometimes sysbench has errors...
push @results, {%hash} if %hash;

printf("^%5s^%3s^%9s^%8s^%6s^\n",
   qw(size type thr bytes/sec req/sec 95pct max_time));

# sort the results by type, threads, size
@results = sort {
      ($a->{type} cmp $b->{type})
   ||   ($a->{size} cmp $b->{size})
   || ($a->{num_threads} <=> $b->{num_threads})
     } @results;

foreach my $hash ( @results ) {
   printf("| %5s | %5s |  %3d|  %9s|  %1.2f|  %1.2f|  %1.2f|\n",
      @{$hash}{@cols});
}
