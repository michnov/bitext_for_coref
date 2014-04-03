#!/usr/bin/env perl

#######################################################
###### TODO: rewrite this using EvalTriples ###########
#######################################################

use strict;
use warnings;

use List::Util qw/max/;

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
    return (map {$_ > 0} ($true, $pred), 0);
    #if ($true == 0) {
    #    return (0, 1, 0);
    #}
    #return (1, 0, 0);
}

sub prf_lenient {
    my ($true, $pred, $both) = @_;
    return (1, 1, 1) if ($both > 0);
    return (map {$_ > 0} ($true, $pred), 0);
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

sub get_count_offset {
    my (@counts) = @_;
    my $max = 0;
    foreach my $count (@counts) {
        $max = max(values %$count, $max);
    }
    my $offset = 10 + 2*length($max);
    return $offset;
}

sub print_header {
    my ($offset) = @_;
    print " "x3;
    printf "\t%*s", -$offset, "STRICT";
    printf "\t%*s", -$offset, "LENIENT";
    printf "\t%*s", -$offset, "WEIGHTED";
    print "\n";
}

sub print_acc {
    my ($offset, $acc_strict_counts, $acc_lenient_counts, $acc_weighted_counts) = @_;
    my $acc;
    my $col_str;
    print "ACC";
    
    $acc = acc($acc_strict_counts->{ok}, $acc_strict_counts->{all});
    $col_str = sprintf "%.2f%% (%d/%d)", $acc * 100, $acc_strict_counts->{ok}, $acc_strict_counts->{all};
    printf "\t%*s", -$offset, $col_str;
    $acc = acc($acc_lenient_counts->{ok}, $acc_lenient_counts->{all});
    $col_str = sprintf "%.2f%% (%d/%d)", $acc * 100, $acc_lenient_counts->{ok}, $acc_lenient_counts->{all};
    printf "\t%*s", -$offset, $col_str;
    $acc = acc($acc_weighted_counts->{ok}, $acc_weighted_counts->{all});
    $col_str = sprintf "%.2f%% (%d/%d)", $acc * 100, $acc_weighted_counts->{ok}, $acc_weighted_counts->{all};
    printf "\t%*s", -$offset, $col_str;
    print "\n";
}

sub print_prf {
    my ($offset, $prf_strict_counts, $prf_lenient_counts, $prf_weighted_counts) = @_;

    my $col_str;
    
    my ($ps, $rs, $fs) = prf($prf_strict_counts->{true}, $prf_strict_counts->{pred}, $prf_strict_counts->{both});
    my ($pl, $rl, $fl) = prf($prf_lenient_counts->{true}, $prf_lenient_counts->{pred}, $prf_lenient_counts->{both});
    my ($pw, $rw, $fw) = prf($prf_weighted_counts->{true}, $prf_weighted_counts->{pred}, $prf_weighted_counts->{both});
    
    print "PRE";
    $col_str = sprintf "%.2f%% (%d/%d)", $ps * 100, $prf_strict_counts->{both}, $prf_strict_counts->{pred};
    printf "\t%*s", -$offset, $col_str;
    $col_str = sprintf "%.2f%% (%d/%d)", $pl * 100, $prf_lenient_counts->{both}, $prf_lenient_counts->{pred};
    printf "\t%*s", -$offset, $col_str;
    $col_str = sprintf "%.2f%% (%d/%d)", $pw * 100, $prf_weighted_counts->{both}, $prf_weighted_counts->{pred};
    printf "\t%*s", -$offset, $col_str;
    print "\n";
    
    print "REC";
    $col_str = sprintf "%.2f%% (%d/%d)", $rs * 100, $prf_strict_counts->{both}, $prf_strict_counts->{true};
    printf "\t%*s", -$offset, $col_str;
    $col_str = sprintf "%.2f%% (%d/%d)", $rl * 100, $prf_lenient_counts->{both}, $prf_lenient_counts->{true};
    printf "\t%*s", -$offset, $col_str;
    $col_str = sprintf "%.2f%% (%d/%d)", $rw * 100, $prf_weighted_counts->{both}, $prf_weighted_counts->{true};
    printf "\t%*s", -$offset, $col_str;
    $col_str = sprintf "%.2f%% (%d/%d)", $rw * 100, $prf_weighted_counts->{both}, $prf_weighted_counts->{true};
    print "\n";
    
    print "F-M";
    $col_str = sprintf "%.2f%%", $fs * 100;
    printf "\t%*s", -$offset, $col_str;
    $col_str = sprintf "%.2f%%", $fl * 100;
    printf "\t%*s", -$offset, $col_str;
    $col_str = sprintf "%.2f%%", $fw * 100;
    printf "\t%*s", -$offset, $col_str;
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

my $offset = get_count_offset(\%acc_lenient_counts, \%prf_lenient_counts);


print_header($offset);
print_acc($offset, \%acc_strict_counts, \%acc_lenient_counts, \%acc_weighted_counts);
print_prf($offset, \%prf_strict_counts, \%prf_lenient_counts, \%prf_weighted_counts);
