#!/usr/bin/env perl

use strict;
use warnings;

sub acc {
    my ($ok, $all) = @_;
    return $all != 0 ? $ok / $all : 0;
}

sub prf {
    my ($true, $pred, $both) = @_;
    my $p = $pred != 0 ? $both / $pred : 0;
    my $r = $true != 0 ? $both / $true : 0;
    my $f = $p + $r != 0 ? 2 * $p * $r / ($p + $r) : 0;
    return ($p, $r, $f);
}

sub acc_strict {
    my ($true, $pred, $both) = @_;
    return 1 if (($true == $pred) && ($true == $both));
    return 0;
}

sub acc_lenient {
    my ($true, $pred, $both) = @_;
    return 1 if ($both > 0);
    return 1 if (($true == $pred) && ($true == 0));
    return 0;
}

sub acc_weighted {
    my ($true, $pred, $both) = @_;
    return 1 if (($true == $pred) && ($true == $both));
    my ($p, $r, $f) = prf($true, $pred, $both);
    return $f;
}

sub prf_strict {
    my ($true, $pred, $both) = @_;
    if (($true == $pred) && ($true == $both)) {
        return (1, 1, 1) if ($true > 0);
        return (0, 0, 0);
    }
    if ($true == 0) {
        if ($true == $pred) {
            return (0, 0, 0);
        }
        return (0, 1, 0);
    }
    return (1, 0, 0);
}

sub prf_lenient {
    my ($true, $pred, $both) = @_;
    return (1, 1, 1) if ($both > 0);
    return (1, 0, 0) if ($true > 0);
    return (0, 1, 0) if ($pred > 0);
    return (0, 0, 0);
}

sub prf_weighted {
    my ($true, $pred, $both) = @_;
    return ($true, $pred, $both);
}

sub update_acc {
    my ($ok, $acc_counts) = @_;
    $acc_counts->{ok} += $ok;
    $acc_counts->{all} += 1;
}

sub update_prf {
    my ($true, $pred, $both, $acc_counts) = @_;
    $acc_counts->{true} += $true;
    $acc_counts->{pred} += $pred;
    $acc_counts->{both} += $both;
}

sub print_header {
    print "   \tSTRICT    \tLENIENT    \tWEIGHTED\n";
}

sub print_acc {
    my ($acc_strict_counts, $acc_lenient_counts, $acc_weighted_counts) = @_;
    my $acc;
    print "ACC\t";
    
    $acc = acc($acc_strict_counts->{ok}, $acc_strict_counts->{all});
    printf "%.2f%% (%d/%d)", $acc * 100, $acc_strict_counts->{ok}, $acc_strict_counts->{all};
    print "\t";
    $acc = acc($acc_lenient_counts->{ok}, $acc_lenient_counts->{all});
    printf "%.2f%% (%d/%d)", $acc * 100, $acc_lenient_counts->{ok}, $acc_lenient_counts->{all};
    print "\t";
    $acc = acc($acc_weighted_counts->{ok}, $acc_weighted_counts->{all});
    printf "%.2f%% (%d/%d)", $acc * 100, $acc_weighted_counts->{ok}, $acc_weighted_counts->{all};
    print "\n";
}

sub print_prf {
    my ($prf_strict_counts, $prf_lenient_counts, $prf_weighted_counts) = @_;
    
    my ($ps, $rs, $fs) = prf($prf_strict_counts->{true}, $prf_strict_counts->{pred}, $prf_strict_counts->{both});
    my ($pl, $rl, $fl) = prf($prf_lenient_counts->{true}, $prf_lenient_counts->{pred}, $prf_lenient_counts->{both});
    my ($pw, $rw, $fw) = prf($prf_weighted_counts->{true}, $prf_weighted_counts->{pred}, $prf_weighted_counts->{both});
    
    print "PRE\t";
    printf "%.2f%% (%d/%d)", $ps * 100, $prf_strict_counts->{both}, $prf_strict_counts->{pred};
    print "\t";
    printf "%.2f%% (%d/%d)", $pl * 100, $prf_lenient_counts->{both}, $prf_lenient_counts->{pred};
    print "\t";
    printf "%.2f%% (%d/%d)", $pw * 100, $prf_weighted_counts->{both}, $prf_weighted_counts->{pred};
    print "\n";
    
    print "REC\t";
    printf "%.2f%% (%d/%d)", $rs * 100, $prf_strict_counts->{both}, $prf_strict_counts->{true};
    print "\t";
    printf "%.2f%% (%d/%d)", $rl * 100, $prf_lenient_counts->{both}, $prf_lenient_counts->{true};
    print "\t";
    printf "%.2f%% (%d/%d)", $rw * 100, $prf_weighted_counts->{both}, $prf_weighted_counts->{true};
    print "\n";
    
    print "F-M\t";
    printf "%.2f%%      ", $fs * 100;
    print "\t";
    printf "%.2f%%      ", $fl * 100;
    print "\t";
    printf "%.2f%%      ", $fw * 100;
    print "\n";
    
    #printf "%.2f%% %.2f%% %.2f%% (%d/%d/%d)", $p * 100, $r * 100, $f * 100, $prf_strict_counts->{true}, $prf_strict_counts->{pred}, $prf_strict_counts->{both};
    #print "\t";
    #printf "%.2f%% %.2f%% %.2f%% (%d/%d/%d)", $p * 100, $r * 100, $f * 100, $prf_lenient_counts->{true}, $prf_lenient_counts->{pred}, $prf_lenient_counts->{both};
    #print "\t";
    #printf "%.2f%% %.2f%% %.2f%% (%d/%d/%d)", $p * 100, $r * 100, $f * 100, $prf_weighted_counts->{true}, $prf_weighted_counts->{pred}, $prf_weighted_counts->{both};
    #print "\n";
}

my %acc_strict_counts = ();
my %acc_lenient_counts = ();
my %acc_weighted_counts = ();
my %prf_strict_counts = ();
my %prf_lenient_counts = ();
my %prf_weighted_counts = ();

while (my $line = <STDIN>) {
    chomp $line;
    my @score_counts = split / /, $line;

    update_acc(acc_strict(@score_counts), \%acc_strict_counts);
    update_acc(acc_lenient(@score_counts), \%acc_lenient_counts);
    update_acc(acc_weighted(@score_counts), \%acc_weighted_counts);
    update_prf(prf_strict(@score_counts), \%prf_strict_counts);
    update_prf(prf_lenient(@score_counts), \%prf_lenient_counts);
    update_prf(prf_weighted(@score_counts), \%prf_weighted_counts);
}


print_header();
print_acc(\%acc_strict_counts, \%acc_lenient_counts, \%acc_weighted_counts);
print_prf(\%prf_strict_counts, \%prf_lenient_counts, \%prf_weighted_counts);
