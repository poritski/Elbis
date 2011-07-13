#! /usr/bin/perl -w
use locale;

$errorlog = "errorlog.txt"; # ����, � ������� ����� ������������ ��������� �� �������
$usage = "elbis \[-p\|-t\|-c\|-pa\|-r\|-f\|-y\] filein \[fileout\]"; # ���������

# ��������� ������������� ���������� ��������� ������
if ((scalar @ARGV == 0) or (scalar @ARGV >= 4))
	{ die "Error 01\. Command line arguments are invalid\. Usage\: $usage\.\n"; }
# ������ ����������
elsif (scalar @ARGV == 1) { $filein = $ARGV[0]; } # ���� ��������: ������� ����
elsif ((scalar @ARGV == 2) and ($ARGV[0] =~ /\./)) { ($filein, $fileout) = @ARGV; } # ��� ���������: ������� � �������� �����
elsif ((scalar @ARGV == 2) and ($ARGV[0] !~ /\./)) { ($flags, $filein) = @ARGV; } # ��� ���������: ���� � ������� ����
elsif (scalar @ARGV == 3) { ($flags, $filein, $fileout) = @ARGV; } # ������ ��� ��� ���������

# ��������� ���� � �����
# $filein = s/(([^\\\/]+(\\|\/))+)(.+)$/$4/igsx;
# �� �����������, ������ ��� �������� ��������

# ���������
unless ($flags) { $flags = "-p"; } # ����
unless ($fileout) # �������� ����
	{
	$fileout = $filein;
	$fileout =~ s/([^.]+)(\.(txt|csv))/$1/igsx;
	$fileout .= "_res" . $flags . ".txt"; # � ����� �������� ����� ������������ �������� _res � ����
	}

# ��� ����������� �����
$flagstemplate = "\-(p|t|c{1,2}|r|f|y)";

# ��������� ������������� ������
unless ($flags =~ /$flagstemplate/igsx)
	{ die "Error 02\: The flags seem to be invalid\.\nUsage\: $usage\.\n"; }
# ��������� ����������� �������� �����
open (FILEIN, "<$filein")
	or die "Error 03\: The specified input file could not be opened\.\n";

# ������ �� �������� �����
my %answers = (); # ����� ����� ���� � �������������� ������ ��� �������, � �������� � �������� ������ �������
while (<FILEIN>)
	{
	chomp;
	@splitted = split (/\t/, $_);
	# ��������� ������������� �������������� �������� �����
	unless (scalar @splitted == 2) { error($_, '04'); }
	$id = $splitted[0];
	# ��������� ������������ ���������������
	if ($answers{$id}) { error($id, '05'); }
	$answers{$id} = $splitted[1];
	}
close (FILEIN);

@players = sort keys %answers; # ��������� ���������������

# ����� ����� ��������� ������ �����
$thelength = length($splitted[1]);
foreach (@players)
	{
	# ��������� ����� ������ �����
	unless (length($answers{$_}) == $thelength) { error($_, '06'); }
	# ��������� ����� � �������������� ���������
	if ($answers{$_} =~ /[^01\-\+]/igsx) { error($_, '07'); }
	$answers{$_} =~ s/\-/0/igsx;
	$answers{$_} =~ s/\+/1/igsx;
	}

# �������� �����
open (FILEOUT, ">$fileout");

# ��� ����� -p (pairwise)
if ($flags eq "-p")
	{
	print FILEOUT "�������\/����� 1\t�������\/����� 2\tR1\tR2\tCap\tCup\tSum\tJD\tCD\tHD\n";
	for ($i = 0; $i < $#players; $i++) # ��������� ������ �������������
		{
		for ($j = $i+1; $j <= $#players; $j++) # ��������� ������ �������������, ����������� �� ����������� � ������
			{
			# ������
			($first, $second) = ($answers{$players[$i]}, $answers{$players[$j]}); # ������ �������
			$intersection = $first & $second; # ������, � ������� ������� ������������� ��������, ������ ������ ���������
			$conjunction = $first | $second; # ������, � ������� ������� ������������� ��������, ������ ���� �� ����� ��������
			$hamming = $first ^ $second; # ������, � ������� ������� ������������� "����������" ����� ��� ��������
			# ��������
			$scorefirst = $first =~ tr/1/1/; # ������ ���������
			$scoresecond = $second =~ tr/1/1/; # ������ ���������
			$scoreand = $intersection =~ tr/1/1/; # ���������� ������ � $intersection
			$scoreor = $conjunction =~ tr/1/1/; # ���������� ������ � $conjunction
			$scorexor = $hamming =~ tr/\0/\0/c; # ���������� ��������
			$sum = $scorefirst + $scoresecond;
			# ������ � �������
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
			# ����� ���������� ��������
			print FILEOUT "$players[$i]\t$players[$j]\t$scorefirst\t$scoresecond\t$scoreand\t$scoreor\t$sum\t$jaccard\t$cosine\t$scorexor\n";
			}
		}
	}
	
# ��� ����� -t (triplewise)
if ($flags eq "-t")
	{
	print FILEOUT "�������\/����� 1\t�������\/����� 2\t�������\/����� 3\tR1\tR2\tR3\tCup\tSum\n";
	for ($i = 0; $i < $#players-1; $i++)
		{
		for ($j = $i+1; $j < $#players; $j++)
			{
			for ($k = $j+1; $k <= $#players; $k++)
				{
				($first, $second, $third) = ($answers{$players[$i]}, $answers{$players[$j]}, $answers{$players[$k]});
				$conjunction = $first | $second | $third;
				$scorefirst = $first =~ tr/1/1/;
				$scoresecond = $second =~ tr/1/1/;
				$scorethird = $third =~ tr/1/1/;
				$scoreor = $conjunction =~ tr/1/1/;
				$triple = $players[$i] . "\t" . $players[$j] . "\t" . $players[$k] . "\t" . $scorefirst . "\t" . $scoresecond . "\t" . $scorethird;
				$totalscore{$triple} = $scoreor;
				$sum{$triple} = $scorefirst + $scoresecond + $scorethird;
				}
			}
		}
	@triples = sort {$sum{$a} <=> $sum{$b}} keys %totalscore;
	foreach (sort {$totalscore{$b} <=> $totalscore{$a}} @triples) { print FILEOUT "$_\t$totalscore{$_}\t$sum{$_}\n"; }
	}

# ��� ����� -c (concise)
if ($flags eq "-c")
	{
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
	for ($k = 0; $k <= $thelength - 1; $k++) { $meanvalue += 2 * $correct[$k] * ($#players - $correct[$k] + 1)/(($#players + 1)*($#players + 1)); }
	print FILEOUT "$zeros �����, $ones ������, ��������� ������� ������������� ���������� ����� �������� $meanvalue\.\n";
	for ($i = 0; $i < $#players; $i++)
		{
		for ($j = $i+1; $j <= $#players; $j++)
			{
			($first, $second) = ($answers{$players[$i]}, $answers{$players[$j]});
			$hamming = $first ^ $second;
			$scorexor = $hamming =~ tr/\0/\0/c;
			$distribution{$scorexor}++;
			}
		}
	print FILEOUT "\n������������� ������������� ���������� (�������� � ����������)\:\n";
	foreach (sort {$a <=> $b} keys %distribution) { print FILEOUT "$_\t$distribution{$_}\n"; }
	print FILEOUT "\n� �������\t����� ���������� �������\n";
	for ($k = 0; $k <= $thelength - 1; $k++) { print FILEOUT (($k+1) . "\t$correct[$k]\n"); }
	print FILEOUT "\n����� (����� ������� �� �������� ���������� � ��������� ���� ������)\:\n";
	for ($i = 0; $i <= $#players; $i++) { $scores{$i} = $answers{$players[$i]} =~ tr/1/1/; }
	($counter, $upper) = 0;
	foreach (sort {$b <=> $a} values %scores)
		{
		$counter++;
		$upper += $_;
		$upper_average = sprintf "%.4f", $upper / $counter;
		$upper_average =~ s/\./\,/igsx;
		print FILEOUT "$counter\t$upper_average\n";
		}
	}

# ��� ����� -pa (pairwise average)
if ($flags eq "-cc")
	{
	print STDOUT "Unimplemented yet!\n";
	}

# ��� ����� -r (random)
if ($flags eq "-r")
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
		print FILEOUT ("����� " . ($i+1) . "\t");
		$resstring = "";
		for ($k = 0; $k <= $thelength - 1; $k++)
			{
			# ����������������� ���
			if (($correct[$k]/$#players >= 0.2) and (rand(2 * $correct[$k])/$#players >= 0.5)) { $resstring .= "1"; }
			elsif ($correct[$k]/$#players <= 0.2) { $resstring .= sprintf(int(rand(8 * $correct[$k])/$#players)); }
			else { $resstring .= "0"; }
			# ����� ������������������ ����
			}
		print FILEOUT $resstring . "\n";
		}
=cut
	}

# ��� ����� -f (formatting)
if ($flags eq "-f")
	{
	for ($i = 0; $i <= $#players; $i++)
		{
		for ($k = 0; $k <= $thelength - 1; $k++)
			{
			$nano = substr ($answers{$players[$i]}, $k, 1);
			$row[$i] += $nano;
			$column[$k] += $nano;
			}
		}
#	print FILEOUT "������� �������� � ������������� ������� (�� " . $thelength . ") � ����������� ������� (�� " . scalar(@players) . ")\:\n";
	print FILEOUT "������� ����������� � ������������� ������� (�� " . $thelength . ") � ����������� ������� (�� " . scalar(@players) . ")\:\n";
	for ($i = 0; $i <= $#players; $i++)
		{
		print FILEOUT "$players[$i]\t";
#		for ($k = 0; $k <= $thelength - 1; $k++) { print FILEOUT sprintf ("%.4f", ($row[$i] * $column[$k])/($thelength * scalar(@players))) . "\t"; }
		for ($k = 0; $k <= $thelength - 1; $k++) { print FILEOUT substr ($answers{$players[$i]}, $k, 1) . "\t"; }
		print FILEOUT "$row[$i]\n";
		}
	for ($k = 0; $k <= $thelength - 1; $k++) { print FILEOUT "\t$column[$k]"; }
	print FILEOUT "\n";
	}

# ��� ����� -y (Young)
if ($flags eq "-y")
	{
	foreach (@players) { $score{$_} = $answers{$_} =~ tr/1/1/; }
	$i = 0;
	foreach (sort { $score{$b} <=> $score{$a} } keys %score)
		{
		$i++;
		$ones = "1" x $score{$_};
		$zeroscore = $thelength - $score{$_};
		$zeros = "0" x $zeroscore;
		$resstring = $ones . $zeros;
		print FILEOUT "$_\t$i\t$score{$_}\t$resstring\n";
		}
	}

close (FILEOUT);

# ������� ��������� ������, ������� ��������� � �����������
sub error
	{
	# ��������������� ����������
	$closing_remark = "\.\nOffending input has been written on the error log\.\n";
	%log = ('04' => "Error 04\. The following line of your input file is invalid\:\n",
		'05' => "Error 05\. The following identifier in your input file isn't unique\:\n",
		'06' => "Error 06\. The following identifier in your input file references a string of unusual length\:\n",
		'07' => "Error 07\. The following identifier in your input file references a string with impossible symbols in it\:\n");
	%stdout = ('04' => "Error 04\:\nNot all lines of your input file are formatted in the right way",
		'05' => "Error 05\:\nNot all identifiers in your input file are unique",
		'06' => "Error 06\:\nNot all binary strings in your input file have the same length",
		'07' => "Error 07\:\nNot all binary strings in your input file contain just 0, 1, -, or +");
	# �������� ������ �������
	($cause, $code) = @_;
	open (ERRORLOG, ">>$errorlog");
	print ERRORLOG ($log{$code} . $cause . "\n");
	close (ERRORLOG);
	die $stdout{$code} . $closing_remark;
	}
