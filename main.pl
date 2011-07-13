#! /usr/bin/perl -w
use locale;

$errorlog = "errorlog.txt"; # файл, в который будут записываться сообщения об ошибках
$usage = "elbis \[-p\|-t\|-c\|-pa\|-r\|-f\|-y\] filein \[fileout\]"; # подсказка

# Обработка неразрешённых аргументов командной строки
if ((scalar @ARGV == 0) or (scalar @ARGV >= 4))
	{ die "Error 01\. Command line arguments are invalid\. Usage\: $usage\.\n"; }
# Чтение аргументов
elsif (scalar @ARGV == 1) { $filein = $ARGV[0]; } # один параметр: входной файл
elsif ((scalar @ARGV == 2) and ($ARGV[0] =~ /\./)) { ($filein, $fileout) = @ARGV; } # два параметра: входной и выходной файлы
elsif ((scalar @ARGV == 2) and ($ARGV[0] !~ /\./)) { ($flags, $filein) = @ARGV; } # два параметра: флаг и входной файл
elsif (scalar @ARGV == 3) { ($flags, $filein, $fileout) = @ARGV; } # заданы все три параметра

# Отсечение пути к файлу
# $filein = s/(([^\\\/]+(\\|\/))+)(.+)$/$4/igsx;
# Не реализовано, потому что вызывало проблемы

# Умолчания
unless ($flags) { $flags = "-p"; } # флаг
unless ($fileout) # выходной файл
	{
	$fileout = $filein;
	$fileout =~ s/([^.]+)(\.(txt|csv))/$1/igsx;
	$fileout .= "_res" . $flags . ".txt"; # к имени входного файла прибавляются постфикс _res и флаг
	}

# Все разрешённые флаги
$flagstemplate = "\-(p|t|c{1,2}|r|f|y)";

# Обработка неразрешённых флагов
unless ($flags =~ /$flagstemplate/igsx)
	{ die "Error 02\: The flags seem to be invalid\.\nUsage\: $usage\.\n"; }
# Обработка нечитаемого входного файла
open (FILEIN, "<$filein")
	or die "Error 03\: The specified input file could not be opened\.\n";

# Чтение из входного файла
my %answers = (); # ключи этого хэша – идентификаторы команд или игроков, а значения – двоичные строки ответов
while (<FILEIN>)
	{
	chomp;
	@splitted = split (/\t/, $_);
	# Обработка неправильного форматирования входного файла
	unless (scalar @splitted == 2) { error($_, '04'); }
	$id = $splitted[0];
	# Обработка неуникальных идентификаторов
	if ($answers{$id}) { error($id, '05'); }
	$answers{$id} = $splitted[1];
	}
close (FILEIN);

@players = sort keys %answers; # множество идентификаторов

# Замер длины последней строки файла
$thelength = length($splitted[1]);
foreach (@players)
	{
	# Обработка строк разной длины
	unless (length($answers{$_}) == $thelength) { error($_, '06'); }
	# Обработка строк с неразрешёнными символами
	if ($answers{$_} =~ /[^01\-\+]/igsx) { error($_, '07'); }
	$answers{$_} =~ s/\-/0/igsx;
	$answers{$_} =~ s/\+/1/igsx;
	}

# ОСНОВНАЯ ЧАСТЬ
open (FILEOUT, ">$fileout");

# При флаге -p (pairwise)
if ($flags eq "-p")
	{
	print FILEOUT "Команда\/игрок 1\tКоманда\/игрок 2\tR1\tR2\tCap\tCup\tSum\tJD\tCD\tHD\n";
	for ($i = 0; $i < $#players; $i++) # фиксируем первый идентификатор
		{
		for ($j = $i+1; $j <= $#players; $j++) # фиксируем второй идентификатор, обязательно не совпадающий с первым
			{
			# Строки
			($first, $second) = ($answers{$players[$i]}, $answers{$players[$j]}); # строки ответов
			$intersection = $first & $second; # строка, в которой единицы соответствуют вопросам, взятым обеими командами
			$conjunction = $first | $second; # строка, в которой единицы соответствуют вопросам, взятым хотя бы одной командой
			$hamming = $first ^ $second; # строка, в которой единицы соответствуют "совместным" нулям или единицам
			# Величины
			$scorefirst = $first =~ tr/1/1/; # первый результат
			$scoresecond = $second =~ tr/1/1/; # второй результат
			$scoreand = $intersection =~ tr/1/1/; # количество единиц в $intersection
			$scoreor = $conjunction =~ tr/1/1/; # количество единиц в $conjunction
			$scorexor = $hamming =~ tr/\0/\0/c; # расстояние Хемминга
			$sum = $scorefirst + $scoresecond;
			# Жаккар и косинус
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
			# Вывод полученных сведений
			print FILEOUT "$players[$i]\t$players[$j]\t$scorefirst\t$scoresecond\t$scoreand\t$scoreor\t$sum\t$jaccard\t$cosine\t$scorexor\n";
			}
		}
	}
	
# При флаге -t (triplewise)
if ($flags eq "-t")
	{
	print FILEOUT "Команда\/игрок 1\tКоманда\/игрок 2\tКоманда\/игрок 3\tR1\tR2\tR3\tCup\tSum\n";
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

# При флаге -c (concise)
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
	print FILEOUT "$zeros нулей, $ones единиц, ожидаемое среднее хемминговское расстояние между строками $meanvalue\.\n";
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
	print FILEOUT "\nРаспределение хемминговских расстояний (величина – количество)\:\n";
	foreach (sort {$a <=> $b} keys %distribution) { print FILEOUT "$_\t$distribution{$_}\n"; }
	print FILEOUT "\n№ вопроса\tЧисло правильных ответов\n";
	for ($k = 0; $k <= $thelength - 1; $k++) { print FILEOUT (($k+1) . "\t$correct[$k]\n"); }
	print FILEOUT "\nУклон (номер команды по убыванию результата – суммарная доля взятых)\:\n";
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

# При флаге -pa (pairwise average)
if ($flags eq "-cc")
	{
	print STDOUT "Unimplemented yet!\n";
	}

# При флаге -r (random)
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
		print FILEOUT ("Игрок " . ($i+1) . "\t");
		$resstring = "";
		for ($k = 0; $k <= $thelength - 1; $k++)
			{
			# Экспериментальный код
			if (($correct[$k]/$#players >= 0.2) and (rand(2 * $correct[$k])/$#players >= 0.5)) { $resstring .= "1"; }
			elsif ($correct[$k]/$#players <= 0.2) { $resstring .= sprintf(int(rand(8 * $correct[$k])/$#players)); }
			else { $resstring .= "0"; }
			# Конец экспериментального кода
			}
		print FILEOUT $resstring . "\n";
		}
=cut
	}

# При флаге -f (formatting)
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
#	print FILEOUT "Таблица ожиданий с постолбцовыми суммами (из " . $thelength . ") и построчными суммами (из " . scalar(@players) . ")\:\n";
	print FILEOUT "Таблица результатов с постолбцовыми суммами (из " . $thelength . ") и построчными суммами (из " . scalar(@players) . ")\:\n";
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

# При флаге -y (Young)
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

# Функция обработки ошибок, которые нуждаются в логировании
sub error
	{
	# Предварительная информация
	$closing_remark = "\.\nOffending input has been written on the error log\.\n";
	%log = ('04' => "Error 04\. The following line of your input file is invalid\:\n",
		'05' => "Error 05\. The following identifier in your input file isn't unique\:\n",
		'06' => "Error 06\. The following identifier in your input file references a string of unusual length\:\n",
		'07' => "Error 07\. The following identifier in your input file references a string with impossible symbols in it\:\n");
	%stdout = ('04' => "Error 04\:\nNot all lines of your input file are formatted in the right way",
		'05' => "Error 05\:\nNot all identifiers in your input file are unique",
		'06' => "Error 06\:\nNot all binary strings in your input file have the same length",
		'07' => "Error 07\:\nNot all binary strings in your input file contain just 0, 1, -, or +");
	# Основной раздел функции
	($cause, $code) = @_;
	open (ERRORLOG, ">>$errorlog");
	print ERRORLOG ($log{$code} . $cause . "\n");
	close (ERRORLOG);
	die $stdout{$code} . $closing_remark;
	}
