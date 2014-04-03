package Treex::Block::My::BitextCorefStats::CsRelpron;

use Moose;
use Treex::Tool::Align::Utils;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
use Treex::Tool::Coreference::NodeFilter::RelPron;

# TODO: refactor this to comply with BitextCorefStats and using Treex::Tool::Align::Utils::aligned_robust
extends 'Treex::Block::My::BitextCorefStats';

my $EN_ROBUST_FILTER = { language => 'en', rel_types => ['robust','.*'] };
my $CS_ROBUST_FILTER = { language => 'cs', rel_types => ['robust','.*'] };
my $CS_SRC_FILTER = { language => 'cs', selector => 'src' };
my $EN_SRC_FILTER = { language => 'en', selector => 'src' };
my $CS_REF_FILTER = { language => 'cs', selector => 'ref' };
my $EN_REF_FILTER = { language => 'en', selector => 'ref' };

sub process_tnode {
    my ($self, $tnode) = @_;
    log_fatal "Language must be 'cs'" if ($self->language ne 'cs');
    
    return if (!Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($tnode));

    my $address = $tnode->get_address;
    my ($result, $errors);

    ($result, $errors) = $self->print_coref_cover($tnode);
    $self->print_info("coref_cover", $address, $result, $errors);

    # starting point is cs_src
    #($result, $errors) = $self->print_cs_relpron_scores($tnode);
    #$self->print_info("cs_relpron_scores", $address, $result, $errors);
    
    #my ($ref_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$src_tnode], [$CS_REF_FILTER]);
    
    # starting point is cs_ref
    #($result, $errors) = $self->print_cs_relpron_tlemma($tnode);
    #$self->print_info("cs_relpron_tlemma", $address, $result, $errors);
    
    my @en_tnodes = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [$EN_ROBUST_FILTER]);
    my $en_class;
    ($en_class, $errors) = $self->print_en_counterparts($tnode, @en_tnodes);
    $self->print_info("en_counterparts", $address, $en_class, $errors);
    
    ($result, $errors) = $self->print_ante_agree($tnode, $en_class, @en_tnodes);
    $self->print_info("ante_agree", $address, $result, $errors);

    #my $err_msg;
    
    #$err_msg = $self->print_svuj_en_counterpart($tnode);
    #log_info $tnode->get_address . "\t" . $err_msg if (defined $err_msg);
    
    #$err_msg = $self->print_cs_relpron_en_partic($tnode);
    #log_info $tnode->get_address . "\t" . $err_msg if (defined $err_msg);
}

sub print_coref_cover {
    my ($self, $cs_tnode) = @_;
    return ($cs_tnode->get_coref_nodes() ? "COREF" : "NONCOREF");
}

#sub print_cs_relpron_tlemma {
#    my ($self, $cs_tnode) = @_;
#    #return (undef, ["NO_CS_REF_TNODE"]) if (!defined $cs_ref_tnode);
#    my ($ante) = $cs_tnode->get_coref_gram_nodes();
#    return (defined $ante ? "COREF:" : "NONCOREF:") . $cs_ref_tnode->t_lemma;
#}

# printing counts to compute pointwise scores (accuracy and precision, recall, F-score)
# for relative pronoun coreference resolution in Czech
sub print_cs_relpron_scores {
    my ($self, $cs_src_tnode) = @_;
    
    # true antecedents
    my @cs_ref_tnodes = Treex::Tool::Align::Utils::aligned_transitively([$cs_src_tnode], [$CS_REF_FILTER]);
    my @cs_ref_antes = Treex::Block::My::BitextCorefStats::unique( [map {$_->get_coref_gram_nodes} @cs_ref_tnodes] );
    my @cs_ref_src_antes = Treex::Block::My::BitextCorefStats::unique( [Treex::Tool::Align::Utils::aligned_transitively( \@cs_ref_antes, [$CS_SRC_FILTER] )]);
    if (!@cs_ref_src_antes) {
        @cs_ref_src_antes = @cs_ref_antes;
    }

    # predicted antecedents
    my @cs_src_antes = $cs_src_tnode->get_coref_gram_nodes;

    my @prf_counts = Treex::Block::My::BitextCorefStats::get_prf_counts(\@cs_ref_src_antes, \@cs_src_antes);
    return join " ", @prf_counts;
}

sub print_en_counterparts {
    my ($self, $cs_tnode, @en_tnodes) = @_;
    
    #return (undef, ["NO_CS_TNODE"]) if (!defined $cs_tnode);
    
    my $robust_align_err = $cs_tnode->wild->{align_robust_err};
    #log_info "ERROR_READ: " . $cs_tnode->id . " " . (defined $robust_align_err ? "1" : "0");
    if (defined $robust_align_err) {
        my ($assoc_anode_str) = grep {$_ =~ /^WH_PRON_ANODE/} @$robust_align_err;
        if ($assoc_anode_str) {
            $assoc_anode_str =~ s/^WH_PRON_ANODE=//;
            my @assoc_anodes = map {$cs_tnode->get_document->get_node_by_id($_)} split /,/, $assoc_anode_str;
            #return "ANODE:" . join ",", (map {$_->lemma} @assoc_anodes);
            return @assoc_anodes[0]->lemma;
        }
        return "V" if any {$_ =~ /^V /} @$robust_align_err;
        return "N" if any {$_ =~ /^N /} @$robust_align_err;
        return "APPOS" if any {$_ =~ /^APPOS/} @$robust_align_err;
    }
    if (@en_tnodes) {
        if (Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($en_tnodes[0])) {
            return "RELPRON";
        }
        return $en_tnodes[0]->t_lemma;
    }
    else {
        return "UNKNOWN";
        #return join ",", @$robust_align_err;
    }
}

sub print_ante_agree {
    my ($self, $cs_tnode, $en_class, @en_tnodes) = @_;

    my @cs_ante = $cs_tnode->get_coref_nodes;

    return "NONCOREF" if (!@cs_ante);

    my $category = 
        (any {$en_class eq $_} qw/V N/) ? "DEP" :
        ($en_class eq "APPOS") ? "APPOS" :
        ($en_class eq "UNKNOWN") ? "UNK" : 
                                 "COREF";

    my @en_ante;
    if ($category eq "COREF") {
        @en_ante = map {$_->get_coref_nodes} @en_tnodes;
    }
    elsif ($category eq "DEP") {
        @en_ante = @en_tnodes;
    }
    elsif ($category eq "APPOS") {
        @en_ante = map {$_->get_children} @en_tnodes;
    }
    my @cs_en_ante = Treex::Tool::Align::Utils::aligned_transitively(\@en_ante, [$CS_ROBUST_FILTER]);
    my @eq_ante = Treex::Block::My::BitextCorefStats::intersect(\@cs_ante, \@cs_en_ante);
    
    my $ante_eq_category =
        !@en_ante ? "NONANTE" :
        !@eq_ante ? "ANTE<>" :
                    "ANTE==";

    return $category . " " . $ante_eq_category;
}

########################### OLD STUFF - TO BE REFACTORED #########################################3

#sub print_cs_relpron_en_partic {
#    my ($self, $tnode) = @_;
#
#    # searching for Czhech relative pronouns
#    return if (!is_relat($tnode));
#
#    # must not be aligned to anything
#    # TODO: or aligned to something not relevant
#    my @en_src = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%EN_SRC_FILTER]);
#    return "relpron aligned with: " . (join ",", map {$_->t_lemma} @en_src) if (@en_src);
#
#    # an English counterpart of the Czech verb must be a past participle or a gerund
#    my ($cs_verb_par) = grep {$_->formeme =~ /^v/} $tnode->get_eparents();
#    return "cs parent is not a verb" if (!defined $cs_verb_par);
#    my ($par_en_src) = Treex::Tool::Align::Utils::aligned_transitively([$cs_verb_par], [\%EN_SRC_FILTER]);
#    return "no en node aligned with a cs parent" if (!defined $par_en_src);
#    my $par_en_src_alex = $par_en_src->get_lex_anode;
#    return "en par-align undefined or not a participle" if (!defined $par_en_src_alex || ($par_en_src_alex->tag ne 'VBG' && $par_en_src_alex->tag ne 'VBN'));
#
#    # possible antecedents via relpron->participle projection
#    my @en_rel_partic_antes = $par_en_src->get_eparents;
#
#    # possible antecedents via alignment with the Czech estimated antecedent
#    my @cs_antes = $tnode->get_coref_gram_nodes;
#    my @en_antes = Treex::Tool::Align::Utils::aligned_transitively(\@cs_antes, [\%EN_SRC_FILTER]);
#
#    my @en_antes_both = intersect(\@en_rel_partic_antes, \@en_antes);
#    
#
#    print {$self->_file_handle} "cs_relpron_en_partic\t";
#    print {$self->_file_handle} join ",", (map {$_->t_lemma} @en_rel_partic_antes);
#    print {$self->_file_handle} "\t";
#    print {$self->_file_handle} "(" . (join ", ", map {$_->get_address} @en_rel_partic_antes) . ")";
#    print {$self->_file_handle} "\n";
#}
#
#sub print_svuj_en_counterpart {
#    my ($self, $tnode) = @_;
#
#    my $anode = $tnode->get_lex_anode();
#    return if (!defined $anode || $anode->lemma !~ /^svůj/);
#
#    my @en_src = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%EN_SRC_FILTER]);
#    print {$self->_file_handle} "svuj_en_counterpart\t";
#    print {$self->_file_handle} join ",", (map {$_->t_lemma} @en_src);
#    print {$self->_file_handle} "\t";
#    print {$self->_file_handle} "(" . (join ", ", map {$_->get_address} @en_src) . ")";
#    print {$self->_file_handle} "\n";
#}


1;
