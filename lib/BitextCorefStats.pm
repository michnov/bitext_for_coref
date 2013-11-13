package Treex::Block::My::BitextCorefStats;

use utf8;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;

    print_svuj_english_counterpart($tnode);
}

sub print_svuj_english_counterpart {
    my ($tnode) = @_;

    my $anode = $tnode->get_lex_anode();
    return if (!defined $anode || $anode->lemma !~ /^svůj/);

    my @en_src = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [{language => 'en', selector => 'src'}]);
    print join ",", (map {$_->t_lemma} @en_src);
    print "\t";
    print "(" . (join ", ", map {$_->get_address} @en_src) . ")";
    print "\n";
}


1;
