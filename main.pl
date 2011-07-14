#! /usr/bin/perl -w
use strict;
use locale;
use Switch;

our $errorlog = "error.log";
my $usage = "elbis \[-p\|-t\|-c\|-pa\|-r\|-f\|-y\] filein \[fileout\]";
my ($flags, $filein, $fileout);

# Handle invalid command line arguments
if ((scalar @ARGV == 0) or (scalar @ARGV >= 4))
	{ die "Error 01\. Command line arguments are invalid\. Usage\: $usage\.\n"; }
# Read arguments into variables
# single parameter is the input file
elsif (scalar @ARGV == 1) { $filein = $ARGV[0]; }
# two parameters with the first one containing a dot represent input & output filehandles
elsif ((scalar @ARGV == 2) and ($ARGV[0] =~ /\./)) { ($filein, $fileout) = @ARGV; }
# otherwise these are flag & input file
elsif ((scalar @ARGV == 2) and ($ARGV[0] !~ /\./)) { ($flags, $filein) = @ARGV; }
# all three may be specified as well
elsif (scalar @ARGV == 3) { ($flags, $filein, $fileout) = @ARGV; }

# Truncate the path
# $filein = s/^(([^\\\/]+(\\|\/))+)(.+)$/$4/igsx;
# This implementation is problematic due to some unnoticed bug

# Defaults
unless ($flags) { $flags = "-p"; } # pairwise is the default mode
unless ($fileout)
	{
	$fileout = $filein;
	$fileout =~ s/([^.]+)(\.(txt|csv))/$1/igsx;
	$fileout .= "_res" . $flags . ".txt"; # $filein with _res postfix and a flag is the default output filehandle
	}

# These are valid flags
my $flagstemplate = "\-(p(a){0,1}|t|c|r|f|y)";
# The options are not intended for simultaneous usage; e.g. -ptc wouldn't work

# Handle invalid flags
unless ($flags =~ /$flagstemplate/igsx)
	{ die "Error 02\: The flags seem to be invalid\.\nUsage\: $usage\.\n"; }
# Handle strange input file
open (FILEIN, "<$filein")
	or die "Error 03\: The specified input file could not be opened\.\n";

# Load input dataset into a hash
# with identifiers as keys and binary strings as values
our %answers;
my (@splitted, $id);
while (<FILEIN>)
	{
	chomp;
	# Handle extra tabs
	@splitted = split (/\t/, $_);
	unless (scalar @splitted == 2) { error($_, '04'); }
	# Handle non-unique identifiers
	$id = $splitted[0];
	if ($answers{$id}) { error($id, '05'); }
	# Otherwise proceed normally
	$answers{$id} = $splitted[1];
	}
close (FILEIN);

# List of all identifiers
our @players = sort keys %answers;
# Length of the binary string associated with the first identifier
our $thelength = length($answers{$players[0]});
foreach (@players)
	{
	# Handle strings of different length
	unless (length($answers{$_}) == $thelength) { error($_, '06'); }
	# Handle invalid symbols inside strings
	if ($answers{$_} =~ /[^01\-\+]/igsx) { error($_, '07'); }
	# '+' => '1', '-' => '0'
	$answers{$_} =~ s/\-/0/igsx;
	$answers{$_} =~ s/\+/1/igsx;
	}

### MAIN ###

open (our $HANDLE, ">$fileout");
switch ($flags)
	{
	case "-p"  { pairwise(); }
	case "-t"  { triplewise(); }
	case "-c"  { concise(); }
	case "-pa" { pairwise_average(); }
	case "-r"  { random(); }
	case "-f"  { formatting(); }
	case "-y"  { young(); }
	}
close ($HANDLE);

### SUBROUTINES ###

# -p / pairwise
sub pairwise
	{
	print $HANDLE "Team\/player 1\tTeam\/player 2\tR1\tR2\tCap\tCup\tSum\tJD\tCD\tHD\n";
	for (my $i = 0; $i < $#players; $i++) # first identifier
		{
		my $first = $answers{$players[$i]};
		my $scorefirst = $first =~ tr/1/1/;
		for (my $j = $i+1; $j <= $#players; $j++) # necessarily distinct second identifier
			{
			my $second = $answers{$players[$j]};
			my $scoresecond = $second =~ tr/1/1/;
			# Compute some simple scores
			my $scoreand = ($first & $second) =~ tr/1/1/; # questions answered by both teams
			my $scoreor = ($first | $second) =~ tr/1/1/; # questions answered by at least one team
			my $hamming = ($first ^ $second) =~ tr/\1/\1/; # questions simultaneously (un)answered by both teams
			my $sum = $scorefirst + $scoresecond;
			# Compute jaccard and cosine measures
			my ($jaccard, $cosine);
			if (($scorefirst == 0) and ($scoresecond == 0))
				{ $jaccard = "UNDEF"; $cosine = "UNDEF"; }
			elsif (($scorefirst == 0) or ($scoresecond == 0))
				{ $jaccard = "0"; $cosine = "UNDEF"; }
			else
				{
				$jaccard = sprintf "%.4f", $scoreand / $scoreor;
				$cosine = sprintf "%.4f", $scoreand / sqrt ($scorefirst * $scoresecond);
				}
			$jaccard =~ s/\./\,/igsx;
			$cosine =~ s/\./\,/igsx;
			# Print the resultant tab-delimited string into file
			print $HANDLE ($players[$i] . "\t" . $players[$j] . "\t" . $scorefirst . "\t" . $scoresecond . "\t" . $scoreand . "\t" . $scoreor . "\t" . $sum . "\t" . $jaccard . "\t" . $cosine . "\t" . $hamming . "\n");
			}
		}
	}

# -t / triplewise
sub triplewise
	{
	my (%totalscore, %sum, @triples); #
	print $HANDLE "Team\/player 1\tTeam\/player 2\tTeam\/player 3\tR1\tR2\tR3\tCup\tSum\n";
	# The three identifiers indexed $i, $j, and $k are necessarily distinct here too
	for (my $i = 0; $i < $#players-1; $i++)
		{
		my $first = $answers{$players[$i]};
		my $scorefirst = $first =~ tr/1/1/;
		for (my $j = $i+1; $j < $#players; $j++)
			{
			my $second = $answers{$players[$j]};
			my $scoresecond = $second =~ tr/1/1/;
			for (my $k = $j+1; $k <= $#players; $k++)
				{
				# Retrieve binary strings
				my $third = $answers{$players[$k]};
				my $scorethird = $third =~ tr/1/1/;
				# Compute only Cup
				my $scoreor = ($first | $second | $third) =~ tr/1/1/;
				# Compute Sum and associate Cup and Sum with the current triple using hashes
				my $triple = $players[$i] . "\t" . $players[$j] . "\t" . $players[$k] . "\t" . $scorefirst . "\t" . $scoresecond . "\t" . $scorethird;
				$totalscore{$triple} = $scoreor;
				$sum{$triple} = $scorefirst + $scoresecond + $scorethird;
				}
			}
		}
	# Arrange sums in descending order and print everything to file
	@triples = sort {$sum{$a} <=> $sum{$b}} keys %totalscore;
	foreach (sort {$totalscore{$b} <=> $totalscore{$a}} @triples) { print $HANDLE ($_ . "\t" . $totalscore{$_} . "\t" . $sum{$_} . "\n"); }
	}

# -c / concise
sub concise
	{
	my ($i, $j, $k, $nano, $ones, $zeros, $meanvalue, $first, $second, $hamming, @correct, %distribution, %scores);
	for ($i = 0; $i <= $#players; $i++)
		{
		for ($k = 0; $k <= $thelength - 1; $k++)
			{
			$nano = substr ($answers{$players[$i]}, $k, 1);
			$correct[$k] += $nano;
			if ($nano == 1) { $ones++; }
			else { $zeros++; }
			}
		}
	for ($k = 0; $k <= $thelength - 1; $k++) { $meanvalue += 2 * $correct[$k] * ($#players - $correct[$k] + 1) / (($#players + 1) * ($#players + 1)); }
	print $HANDLE "$zeros zeros, $ones ones, expected HD mean value is $meanvalue\.\n";
	for ($i = 0; $i < $#players; $i++)
		{
		$first = $answers{$players[$i]};
		for ($j = $i+1; $j <= $#players; $j++)
			{
			$second = $answers{$players[$j]};
			$hamming = ($first ^ $second) =~ tr/\1/\1/;
			$distribution{$hamming}++;
			}
		}
	print $HANDLE "\nActually, the distribution of HDs looks like this\:\n";
	foreach (sort {$a <=> $b} keys %distribution) { print $HANDLE ($_ . "\t" . $distribution{$_} . "\n"); }
	print $HANDLE "\nНомер вопроса\tЧисло правильных ответов\n";
	for ($k = 0; $k <= $thelength - 1; $k++) { print $HANDLE (($k+1) . "\t" . $correct[$k] . "\n"); }
	print $HANDLE "\nУклон (номер команды по убыванию результата – суммарная доля взятых)\:\n";
	for ($i = 0; $i <= $#players; $i++) { $scores{$i} = $answers{$players[$i]} =~ tr/1/1/; }
	my ($counter, $upper, $upper_average);
	foreach (sort {$b <=> $a} values %scores)
		{
		$counter++;
		$upper += $_;
		$upper_average = sprintf "%.4f", $upper / $counter;
		$upper_average =~ s/\./\,/igsx;
		print $HANDLE ($counter . "\t" . $upper_average . "\n");
		}
	}

# -pa / pairwise average; most code reused from pairwise
# WRITTEN IN A VERY "CHINESE" FASHION, TO BE IMPROVED
sub pairwise_average
	{
	my (%average_jd, %average_cd, %average_hd);
	print $HANDLE "Team\/player\tR\tAJD\tACD\tAHD\n";
	for (my $i = 0; $i < $#players; $i++)
		{
		my $first = $answers{$players[$i]};
		my $scorefirst = $first =~ tr/1/1/;
		for (my $j = $i+1; $j <= $#players; $j++)
			{
			my $second = $answers{$players[$j]};
			my $scoresecond = $second =~ tr/1/1/;
			my $scoreand = ($first & $second) =~ tr/1/1/;
			my $scoreor = ($first | $second) =~ tr/1/1/;
			my $hamming = ($first ^ $second) =~ tr/\1/\1/;
			my ($jaccard, $cosine);
			if (($scorefirst == 0) and ($scoresecond == 0))
				{ $jaccard = "UNDEF"; $cosine = "UNDEF"; }
			elsif (($scorefirst == 0) or ($scoresecond == 0))
				{ $jaccard = "0"; $cosine = "UNDEF"; }
			else
				{
				$jaccard =  $scoreand / $scoreor;
				$cosine = $scoreand / sqrt ($scorefirst * $scoresecond);
				}
			$average_jd{$players[$i]} += $jaccard;
			$average_jd{$players[$j]} += $jaccard;
			$average_cd{$players[$i]} += $cosine;
			$average_cd{$players[$j]} += $cosine;
			$average_hd{$players[$i]} += $hamming;
			$average_hd{$players[$j]} += $hamming;
			}
		}
	foreach (@players)
		{
		my $res = $answers{$_} =~ tr/1/1/;
		$average_jd{$_} = sprintf "%.4f", $average_jd{$_} / ($#players - 1);
		$average_cd{$_} = sprintf "%.4f", $average_cd{$_} / ($#players - 1);
		$average_hd{$_} = sprintf "%.4f", $average_hd{$_} / ($#players - 1);
		$average_jd{$_} =~ s/\./\,/igsx;
		$average_cd{$_} =~ s/\./\,/igsx;
		$average_hd{$_} =~ s/\./\,/igsx;
		print $HANDLE $_ . "\t" . $res . "\t" . $average_jd{$_} . "\t" . $average_cd{$_} . "\t" . $average_hd{$_} . "\n";
		}
	}

# -r / random
sub random
	{
	print STDOUT "Unimplemented yet!\n";
=pod
	for ($i = 0; $i <= $#players; $i++)
		{
		for ($k = 0; $k <= $thelength - 1; $k++)
			{
			$nano = substr ($answers{$players[$i]}, $k, 1);
			$correct[$k] += $nano;
			}
		}
	for ($i = 0; $i <= $#players; $i++)
		{
		print $HANDLE ("Игрок " . ($i+1) . "\t");
		$resstring = "";
		for ($k = 0; $k <= $thelength - 1; $k++)
			{
			# Experimental code
			if (($correct[$k]/$#players >= 0.2) and (rand(2 * $correct[$k])/$#players >= 0.5)) { $resstring .= "1"; }
			elsif ($correct[$k]/$#players <= 0.2) { $resstring .= sprintf(int(rand(8 * $correct[$k])/$#players)); }
			else { $resstring .= "0"; }
			# End of experimental code
			}
		print $HANDLE $resstring . "\n";
		}
=cut
	}

# -f / formatting
sub formatting
	{
	my ($i, $j, $k, $nano, @row, @column);
	for ($i = 0; $i <= $#players; $i++)
		{
		for ($k = 0; $k <= $thelength - 1; $k++)
			{
			$nano = substr ($answers{$players[$i]}, $k, 1);
			$row[$i] += $nano;
			$column[$k] += $nano;
			}
		}
#	print $HANDLE "Таблица ожиданий с постолбцовыми суммами (из " . $thelength . ") и построчными суммами (из " . scalar(@players) . ")\:\n";
	print $HANDLE "Таблица результатов с постолбцовыми суммами (из " . $thelength . ") и построчными суммами (из " . scalar(@players) . ")\:\n";
	for ($i = 0; $i <= $#players; $i++)
		{
		print $HANDLE "$players[$i]\t";
#		for ($k = 0; $k <= $thelength - 1; $k++) { print $HANDLE sprintf ("%.4f", ($row[$i] * $column[$k])/($thelength * scalar(@players))) . "\t"; }
		for ($k = 0; $k <= $thelength - 1; $k++) { print $HANDLE substr ($answers{$players[$i]}, $k, 1) . "\t"; }
		print $HANDLE "$row[$i]\n";
		}
	for ($k = 0; $k <= $thelength - 1; $k++) { print $HANDLE "\t$column[$k]"; }
	print $HANDLE "\n";
	}

# -y / Young
sub young
	{
	my ($i, $ones, $zeroscore, $zeros, $resstring, %score);
	foreach (@players) { $score{$_} = $answers{$_} =~ tr/1/1/; }
	foreach (sort { $score{$b} <=> $score{$a} } keys %score)
		{
		$i++;
		$ones = "1" x $score{$_};
		$zeroscore = $thelength - $score{$_};
		$zeros = "0" x $zeroscore;
		$resstring = $ones . $zeros;
		print $HANDLE "$_\t$i\t$score{$_}\t$resstring\n";
		}
	}

# This generic function is responsible for error logging
# Note that errors 01..03 are not logged
sub error
	{
	# Prerequisites
	my $closing_remark = "\.\nOffending input has been written on the error log\.\n";
	my %log =
		('04' => "Error 04\. The following line of your input file is invalid\:\n",
		'05' => "Error 05\. The following identifier in your input file isn't unique\:\n",
		'06' => "Error 06\. The following identifier in your input file references a string of unusual length\:\n",
		'07' => "Error 07\. The following identifier in your input file references a string with impossible symbols in it\:\n");
	my %stdout =
		('04' => "Error 04\:\nNot all lines of your input file are formatted in the right way",
		'05' => "Error 05\:\nNot all identifiers in your input file are unique",
		'06' => "Error 06\:\nNot all binary strings in your input file have the same length",
		'07' => "Error 07\:\nNot all binary strings in your input file contain just 0, 1, -, or +");
	# Main
	my ($cause, $errorcode) = @_;
	open (my $EHANDLE, ">>$errorlog");
	print $EHANDLE ($log{$errorcode} . $cause . "\n");
	close ($EHANDLE);
	die $stdout{$errorcode} . $closing_remark;
	}
