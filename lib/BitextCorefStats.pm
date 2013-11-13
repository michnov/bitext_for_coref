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

sub is_relat {
    my ($tnode) = @_;
    my $indeftype = $tnode->gram_indeftype;
    return (defined $indeftype && $indeftype eq "relat") ? 1 : 0;
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

sub print_info {
    my ($self, $tnode, $name, $method) = @_;

    my $result = $self->$method($tnode);
    
    print {$self->_file_handle} "$name\t";
    print {$self->_file_handle} $result;
    print {$self->_file_handle} "\t" . $tnode->get_address;
    print {$self->_file_handle} "\n";
}

sub print_cs_relpron_stats {
    my ($self, $tnode) = @_;
    
    # searching for Czech relative pronouns
    return if (!is_relat($tnode));

    $self->print_info($tnode, "cs_relpron_tlemma", \&print_cs_relpron_tlemma);
    $self->print_info($tnode, "cs_relpron_scores", \&print_cs_relpron_scores);
    $self->print_info($tnode, "cs_relpron_en_counterparts", \&print_cs_relpron_en_counterparts);
}

sub print_cs_relpron_tlemma {
    my ($self, $tnode) = @_;
    my ($cs_ref_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%CS_REF_FILTER]);
    return "NO_CS_REF_TNODE" if (!defined $cs_ref_tnode);
    my ($ante) = $cs_ref_tnode->get_coref_gram_nodes();
    return (defined $ante ? "COREF:" : "NONCOREF:") . $tnode->t_lemma;
}

# printing counts to compute pointwise scores (accuracy and precision, recall, F-score)
# for relative pronoun coreference resolution in Czech
sub print_cs_relpron_scores {
    my ($self, $tnode) = @_;
    
    # true antecedents
    my @cs_ref_tnodes = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%CS_REF_FILTER]);
    my @cs_ref_antes = unique( [map {$_->get_coref_gram_nodes} @cs_ref_tnodes] );
    my @cs_ref_src_antes = unique( [Treex::Tool::Align::Utils::aligned_transitively( \@cs_ref_antes, [\%CS_SRC_FILTER] )]);
    if (!@cs_ref_src_antes) {
        @cs_ref_src_antes = @cs_ref_antes;
    }

    # predicted antecedents
    my @cs_src_antes = $tnode->get_coref_gram_nodes;

    my @prf_counts = get_prf_counts(\@cs_ref_src_antes, \@cs_src_antes);
    return join " ", @prf_counts;
}

sub _get_en_ref_relpron {
    my ($cs_ref_tnode, $errors) = @_;
    my ($en_ref_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$cs_ref_tnode], [\%EN_REF_FILTER]);
    if (!defined $en_ref_tnode) {
        push @$errors, "NO_EN_REF_TNODE";
        return;
    }
    if (!is_relat($en_ref_tnode)) {
        push @$errors, "NORELAT_EN_REF_TNODE";
        return;
    }
    return $en_ref_tnode->t_lemma;
}

sub _get_en_ref_coref_child_tlemma {
    my ($en_ref_par, $errors) = @_;
    my @en_ref_coref_children = grep {scalar($_->get_coref_nodes) > 0} $en_ref_par->get_echildren({or_topological => 1});
    if (@en_ref_coref_children == 0) {
        push @$errors, "NO_EN_REF_COREF_CHILDREN";
        return;
    }
    if (@en_ref_coref_children > 1) {
        push @$errors, "MANY_EN_REF_COREF_CHILDREN";
        return;
    }
    return $en_ref_coref_children[0]->t_lemma;
}

sub _get_en_ref_functor_tnode {
    my ($cs_ref_tnode, $errors) = @_;
    my ($cs_ref_par) = $cs_ref_tnode->get_eparents({or_topological => 1});
    my ($en_ref_par) = Treex::Tool::Align::Utils::aligned_transitively([$cs_ref_par], [\%EN_REF_FILTER]);
    if (!defined $en_ref_par) {
        push @$errors, "NO_EN_REF_PAR";
        return;
    }
    
    my ($en_ref_functor_tnode) = grep {$_->functor eq $cs_ref_tnode->functor} $en_ref_par->get_echildren({or_topological => 1});
    if (!defined $en_ref_functor_tnode) {
        push @$errors, "NO_EN_REF_FUNCTOR_TNODE";
        return _get_en_ref_coref_child_tlemma($en_ref_par, $errors);
    }
    my $tlemma = $en_ref_functor_tnode->t_lemma;
    if (!is_relat($en_ref_functor_tnode) && $tlemma ne "#Cor" && $tlemma ne "#PersPron") {
        push @$errors, "BAD_EN_REF_FUNCTOR_TNODE";
        return _get_en_ref_coref_child_tlemma($en_ref_par, $errors);
    }
    #print {$self->_file_handle} (join " ", map {$_->t_lemma} @en_ref_tnodes);
    return $en_ref_functor_tnode->t_lemma;
}

sub _get_no_verb_appos {
    my ($cs_ref_tnode, $errors) = @_;   
    my @cs_ref_sibs = $cs_ref_tnode->get_siblings;
    my @en_ref_sibs = Treex::Tool::Align::Utils::aligned_transitively(\@cs_ref_sibs, [\%EN_REF_FILTER]);
    my @en_ref_pars = map {$_->get_parent} @en_ref_sibs;
    my @no_verb_appos = grep {$_->t_lemma eq "#EmpVerb" || $_->functor eq "APPS"} @en_ref_pars;
    if (!@no_verb_appos) {
        push @$errors, "NOEMPVERBAPPS_EN_REF_PARS";
        return;
    }
    #my ($cs_ref_par) = $cs_ref_tnode->get_eparents({or_topological => 1});
    #if ($cs_ref_par->t_lemma ne "být") {
    #    return "<NO_VERB_APPOS_NOBYT>";
    #}
    return "<NO_VERB_APPOS>";
}

sub _get_ante_attribute {
    my ($cs_ref_tnode, $errors) = @_;
    my @cs_ref_antes = $cs_ref_tnode->get_coref_nodes();
    if (!@cs_ref_antes) {
        push @$errors, "NO_CS_REF_ANTE";
        return;
    }
    my @en_ref_antes = Treex::Tool::Align::Utils::aligned_transitively(\@cs_ref_antes, [\%EN_REF_FILTER]);
    my @en_ref_ante_children = map {$_->get_children()} @en_ref_antes;
    return "<ONE_ANTE_ATTR>" if (scalar(@en_ref_ante_children) == 1);
    return "<NO_ANTE_ATTR>" if (scalar(@en_ref_ante_children) == 0);
    return "<MANY_ANTE_ATTR>" if (scalar(@en_ref_ante_children) > 1);
}

sub _get_counterparts_via_siblings {
    my ($cs_ref_tnode, $errors) = @_;
    my @cs_ref_siblings = $cs_ref_tnode->get_siblings();
    if (!@cs_ref_siblings) {
        push @$errors, "NOSIBLINGS_CS_REF_TNODE";
        return;
    }
    my @en_ref_siblings = Treex::Tool::Align::Utils::aligned_transitively(\@cs_ref_siblings, [\%EN_REF_FILTER]);
    if (!@en_ref_siblings) {
        push @$errors, "NOALIGN_CS_REF_SIBLINGS";
        return;
    }
    my ($en_ref_par, @en_ref_pars) = unique([map {$_->get_parent} @en_ref_siblings]);
    if (@en_ref_pars > 0) {
        push @$errors, "MANY_EN_REF_PARS";
        return;
    }
    my $formeme = $en_ref_par->formeme;
    if ($formeme =~ /^n/) {
        return "<NOUN_ANTE_ATTR>";
    }
    if ($formeme =~ /^v/) {
        my ($en_ref_relat_child) = grep {is_relat($_)} $en_ref_par->get_children();
        if (defined $en_ref_relat_child) {
            return $en_ref_relat_child->t_lemma;
        }
        my @en_ref_cor_children = grep {$_->t_lemma eq "#Cor"} $en_ref_par->get_children();
        if (@en_ref_cor_children > 0) {
            if (@en_ref_cor_children == 1) {
                return "#Cor";
            }
            push @$errors, "MANYCOR_EN_REF_PAR";
            return;
        }
        return "<EN_REF_PAR:" . $formeme .">";
    }
    push @$errors, "BADFORMEME_EN_REF_PAR";
    return;
}

sub print_cs_relpron_en_counterparts {
    my ($self, $tnode) = @_;

    my $errors = [];
    
    my ($cs_ref_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [\%CS_REF_FILTER]);
    return "NO_CS_REF_TNODE" if (!defined $cs_ref_tnode);
    my $en_ref_tnode_tlemma = undef;
    $en_ref_tnode_tlemma = _get_counterparts_via_siblings($cs_ref_tnode, $errors) if (!defined $en_ref_tnode_tlemma);
    $en_ref_tnode_tlemma = _get_en_ref_functor_tnode($cs_ref_tnode, $errors) if (!defined $en_ref_tnode_tlemma);
    $en_ref_tnode_tlemma = _get_en_ref_relpron($cs_ref_tnode, $errors) if (!defined $en_ref_tnode_tlemma);
    #$en_ref_tnode_tlemma = _get_no_verb_appos($cs_ref_tnode, $errors) if (!defined $en_ref_tnode_tlemma);
    #$en_ref_tnode_tlemma = _get_ante_attribute($cs_ref_tnode, $errors) if (!defined $en_ref_tnode_tlemma);
    return (join ",", @$errors) if (!defined $en_ref_tnode_tlemma);
    return $en_ref_tnode_tlemma;
}

sub print_cs_relpron_en_partic {
    my ($self, $tnode) = @_;

    # searching for Czhech relative pronouns
    return if (!is_relat($tnode));

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


1;
