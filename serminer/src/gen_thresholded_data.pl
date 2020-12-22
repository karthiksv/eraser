# Copyright 2020 IBM Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/bin/perl
use 5.018;

#use warnings;
no warnings 'experimental';
use strict;
use List::Util qw(max min);

if ($#ARGV != 2) { die "Syntax: perl gen_thresholded_data.pl <METRIC res/cov/wted_sw)><OUT_DIR><RES_TH>>\n"; }
my $metric = $ARGV[0];
my $MACRO_DATA_DIR=$ARGV[1];
my $RES_TH=$ARGV[2];

#my $MACRO_DATA_DIR="/tmp/VCD_OUT/";
#my $MACRO_DATA_DIR="/tmp/STRESSMARK_OUT/stressmarks_stats/";
my @macro_data_list=(`ls $MACRO_DATA_DIR/*macro_data.txt`); chomp(@macro_data_list);
my (@res_arr, @thresholded_res_arr, @thresholded_cov_arr,  @sw_arr, @thresholded_sw_arr, @wted_sw_arr, @thresholded_wted_sw_arr, @macro_array, @bitwidth_array,);
my $max_macro_res=0;
my $max_macro_sw=0;
my $max_macro_wted_sw=0;
my $total_bits=0;
my $total_sw=0;
my $i=0;
my $bitw;

@macro_array=(`awk '(\$1 !~ /#/){print \$1}' $macro_data_list[0]`); chomp(@macro_array);
@bitwidth_array=(`awk '(\$1 !~ /#/){print \$3}' $macro_data_list[0]`); chomp(@bitwidth_array);
foreach my $macro (@macro_array)
{
	$bitw = $bitwidth_array[$i];
	@res_arr=`grep -w $macro $MACRO_DATA_DIR/*macro_data.txt | awk '{print \$NF}'`; chomp(@res_arr);
	@sw_arr=`grep -w $macro $MACRO_DATA_DIR/*macro_data.txt | awk '{print \$4}'`; chomp(@sw_arr);
	@wted_sw_arr=`grep -w $macro $MACRO_DATA_DIR/*macro_data.txt | awk '{print \$3*\$4}'`; chomp(@wted_sw_arr);
	$total_bits=`grep -w $macro $MACRO_DATA_DIR/*macro_data.txt | awk '{sum+= \$3}END{print sum}'`; chomp($total_bits);
	$total_sw=`grep -w $macro $MACRO_DATA_DIR/*macro_data.txt | awk '{sum+= \$3*\$4}END{print sum}'`; chomp($total_sw);

	$max_macro_res=max(@res_arr);
	$max_macro_sw=max(@sw_arr);
	$max_macro_wted_sw=max(@wted_sw_arr);

	#print("$macro, $max_macro_res: $max_macro_sw, $max_macro_wted_sw\n");
	@thresholded_res_arr = map {($_ >= $RES_TH*$max_macro_res)?$_/$max_macro_res:0} @res_arr;
	@thresholded_cov_arr = map {($_ >= $RES_TH*$max_macro_res)?1:0} @res_arr;
	@thresholded_sw_arr = map {($_ >= $RES_TH*$max_macro_sw)?$_:0} @sw_arr;
	#@thresholded_sw_arr = map {($_ >= $RES_TH*$max_macro_sw)?$_/$max_macro_sw:0} @sw_arr;
	#@thresholded_wted_sw_arr = map {($_ >= $RES_TH*$max_macro_wted_sw)?$_/($max_macro_sw*$total_bits):0} @wted_sw_arr;
	@thresholded_wted_sw_arr = map {($_ >= $RES_TH*$max_macro_sw)?$_:0} @wted_sw_arr;

	given ($metric)
	{
		when ('res')	{ print "$macro $bitw @thresholded_res_arr\n"; }
		when ('cov')	{ print("$macro $bitw @thresholded_cov_arr\n"); }
		when ('sw')	{ print("$macro $bitw @thresholded_sw_arr\n"); }
		when ('wted_sw')	{ print("$macro $bitw @thresholded_sw_arr\n"); }
		when ('none')	{  }
		
		default		{ print("Invalid metric - $metric! Exiting..\n"); exit(); }
	}
	$i++;
}

#foreach my $file (@macro_data_list)
#{
#	@res_arr=(`awk '{print \$NF}' $file`);
#	for (my $j=0; j<=$#macro_array; $j++)
#	{
#		push(@{$RES_HASH{$macro_array[$j]}}, $res_arr[$j]);
#	}
#	$i++;
#} 
