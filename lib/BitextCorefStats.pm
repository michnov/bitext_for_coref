package Treex::Block::My::BitextCorefStats;

use utf8;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;
use Readonly;

use Data::Dumper;

extends 'Treex::Block::Write::BaseTextWriter';

Readonly::Hash my %CS_SRC_FILTER => (language => 'cs', selector => 'src');
Readonly::Hash my %EN_SRC_FILTER => (language => 'en', selector => 'src');
Readonly::Hash my %CS_REF_FILTER => (language => 'cs', selector => 'ref');
Readonly::Hash my %EN_REF_FILTER => (language => 'en', selector => 'ref');

sub intersect {
    my ($a, $b) = @_;
#        log_info "A: " . (join " ", map {$_->id} @$a);
#        log_info "B: " . (join " ", map {$_->id} @$b);
    my %a_h = map {$_ => $_} @$a;
    my @inter = grep {defined $a_h{$_}} @$b;
#    if (scalar @inter) {
#        log_info "I: " . (join " ", map {$_->id} @inter);
#    }
    return @inter;
}

sub unique {
    my ($a) = @_;
#        log_info "A: " . (join " ", map {$_->id} @$a);
    my @u = values %{ {map {$_ => $_} @$a} };
#        log_info "A: " . (join " ", map {$_->id} @u);
    return @u;
}

sub get_prf_counts {
    my ($true, $pred) = @_;
    my @inter = intersect($true, $pred);
    return (scalar @$true, scalar @$pred, scalar @inter);
}

sub process_tnode {
    my ($self, $tnode) = @_;

    $self->print_cs_relpron_stats($tnode);
    #my $err_msg;
    
    #$err_msg = $self->print_svuj_en_counterpart($tnode);
    #log_info $tnode->get_address . "\t" . $err_msg if (defined $err_msg);
    
    #$err_msg = $self->print_cs_relpron_en_partic($tnode);
    #log_info $tnode->get_address . "\t" . $err_msg if (defined $err_msg);
}

sub print_svuj_en_counterpart {
    my ($self, $tnode) = @_;

    my $anode = $tnode->get_lex_anode();
    return if (!defined $anode || $anode->lemma !~ /^svůj/);

    my @en_src = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%EN_SRC_FILTER]);
    print {$self->_file_handle} "svuj_en_counterpart\t";
    print {$self->_file_handle} join ",", (map {$_->t_lemma} @en_src);
    print {$self->_file_handle} "\t";
    print {$self->_file_handle} "(" . (join ", ", map {$_->get_address} @en_src) . ")";
    print {$self->_file_handle} "\n";
}

sub print_cs_relpron_stats {
    my ($self, $tnode) = @_;
    
    # searching for Czech relative pronouns
    my $indeftype = $tnode->gram_indeftype;
    return if (!defined $indeftype || $indeftype ne "relat");

    $self->print_cs_relpron_scores($tnode);
}

# printing counts to compute pointwise scores (accuracy and precision, recall, F-score)
# for relative pronoun coreference resolution in Czech
sub print_cs_relpron_scores {
    my ($self, $tnode) = @_;
    
    # true antecedents
    my @cs_ref_tnodes = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%CS_REF_FILTER]);
    my @cs_ref_antes = unique( [Treex::Tool::Align::Utils::aligned_transitively( [map {$_->get_coref_gram_nodes} @cs_ref_tnodes], [\%CS_SRC_FILTER] )]);

    # predicted antecedents
    my @cs_src_antes = $tnode->get_coref_gram_nodes;

    my @prf_counts = get_prf_counts(\@cs_ref_antes, \@cs_src_antes);
    print {$self->_file_handle} "cs_relpron_scores\t";
    print {$self->_file_handle} join " ", @prf_counts;
    print {$self->_file_handle} "\t" . $tnode->get_address;
    print {$self->_file_handle} "\n";
}

sub print_cs_relpron_en_partic {
    my ($self, $tnode) = @_;

    # searching for Czhech relative pronouns
    my $indeftype = $tnode->gram_indeftype;
    return if (!defined $indeftype || $indeftype ne "relat");

    # must not be aligned to anything
    # TODO: or aligned to something not relevant
    my @en_src = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%EN_SRC_FILTER]);
    return "relpron aligned with: " . (join ",", map {$_->t_lemma} @en_src) if (@en_src);

    # an English counterpart of the Czech verb must be a past participle or a gerund
    my ($cs_verb_par) = grep {$_->formeme =~ /^v/} $tnode->get_eparents();
    return "cs parent is not a verb" if (!defined $cs_verb_par);
    my ($par_en_src) = Treex::Tool::Align::Utils::aligned_transitively([$cs_verb_par], [\%EN_SRC_FILTER]);
    return "no en node aligned with a cs parent" if (!defined $par_en_src);
    my $par_en_src_alex = $par_en_src->get_lex_anode;
    return "en par-align undefined or not a participle" if (!defined $par_en_src_alex || ($par_en_src_alex->tag ne 'VBG' && $par_en_src_alex->tag ne 'VBN'));

    # possible antecedents via relpron->participle projection
    my @en_rel_partic_antes = $par_en_src->get_eparents;

    # possible antecedents via alignment with the Czech estimated antecedent
    my @cs_antes = $tnode->get_coref_gram_nodes;
    my @en_antes = Treex::Tool::Align::Utils::aligned_transitively(\@cs_antes, [\%EN_SRC_FILTER]);

    my @en_antes_both = intersect(\@en_rel_partic_antes, \@en_antes);
    

    print {$self->_file_handle} "cs_relpron_en_partic\t";
    print {$self->_file_handle} join ",", (map {$_->t_lemma} @en_rel_partic_antes);
    print {$self->_file_handle} "\t";
    print {$self->_file_handle} "(" . (join ", ", map {$_->get_address} @en_rel_partic_antes) . ")";
    print {$self->_file_handle} "\n";
}


1;
