#!/usr/bin/perl

#compute (ex+alu+div+fpu)
#mem (mem +io_dmem+io_ptw)
#WB (wb)
#IF (ibuf+bpu+io_imem)
#ID (rf+id)
#Monitor (csr+coreMonitor)

my @unit_list= ("ALU", "FPU", "Mem", "WB", "IF", "ID","Monitor" );
my $macro_data_file = "/tmp/VCD_OUT/cpu2017/bwaves_macro_data.txt";
my %MACRO_HASH = (
$unit_list[0] => ["ex", "alu", "div"], 
$unit_list[1] => ["fpu"], 
$unit_list[2] => ["mem", "io_dmem", "io_ptw"], 
$unit_list[3] => ["wb"], 
$unit_list[4] => ["ibuf", "io_imem", "bpu"], 
$unit_list[5] => ["rf", "id"], 
$unit_list[6] => ["csr", "coreMonitorBundle"],
);

my $UNIT_FILE;
my $PV_OUTDIR = "/tmp/POWER_VIRUS_WTED";

#print("$unit_list[1]: ${ $MACRO_HASH{$unit_list[1]} }[1]\n");
for ($i=0;$i<=$#unit_list; $i++)
{
	$UNIT_FILE="$PV_OUTDIR/${unit_list[$i]}_macros.txt";
	my $x = $MACRO_HASH{$unit_list[$i]};
	system("rm -f $UNIT_FILE");
	foreach my $j (@{ $MACRO_HASH{$unit_list[$i]} })
	{
		`awk -v macro="$j" '{m_str= "^" macro "_"; if((\$1==macro) || (\$1~m_str)) print \$1}' $macro_data_file >> $UNIT_FILE`;
	}
	print("$UNIT_FILE written\n");
}


