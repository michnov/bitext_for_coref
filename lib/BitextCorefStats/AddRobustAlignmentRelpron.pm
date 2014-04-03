package Treex::Block::My::BitextCorefStats::AddRobustAlignmentRelpron;

use Moose;
use Treex::Tool::Align::Utils;
use Treex::Core::Common;

use Treex::Block::My::BitextCorefStats;
use Treex::Tool::Coreference::CS::RelPronAnaphFilter;

extends 'Treex::Core::Block';

has '_align_zone' => (is => 'ro', isa => 'HashRef[Str]', builder => '_build_align_zone', lazy => 1);

has 'type' => (is => 'ro', isa => 'Str', default => 'robust');

sub BUILD {
    my ($self) = @_;
    $self->_align_zone;
}

sub _build_align_zone {
    my ($self) = @_;
    return {language => 'en', selector => $self->selector};
}


sub process_tnode {
    my ($self, $tnode) = @_;

    # only for 3rd person non-reflexive personal pronouns
    return if (!Treex::Tool::Coreference::CS::RelPronAnaphFilter::is_relat($tnode));
    
    my $sieves = [ 
        'self', 
        \&access_via_alayer, 
        'eparents', 
        'siblings', 
        \&select_via_self_siblings,
    ];
    my $filters = [ 
        \&filter_self,
        \&filter_anodes,
        \&filter_eparents,
        \&filter_siblings,
        \&filter_appos,
    ];

    my ($result_nodes, $errors) = Treex::Tool::Align::Utils::aligned_robust($tnode, [ $self->_align_zone ], $sieves, $filters);
    $tnode->wild->{align_robust_err} = $errors;
    #log_info "ERROR_WRITE: " . $tnode->id . " " . (defined $errors ? "1" : "0");
    if (defined $result_nodes) {
        foreach (@$result_nodes) {
            Treex::Tool::Align::Utils::remove_alignments($tnode, $self->_align_zone);
            Treex::Tool::Align::Utils::add_aligned($tnode, $_, $self->type);
        }
    }
}

sub access_via_alayer {
    my ($tnode, $align_filters, $errors) = @_;
    my $anode = $tnode->get_lex_anode();
    my @aligned_anodes = Treex::Tool::Align::Utils::aligned_transitively([$anode], $align_filters);
    if (!@aligned_anodes) {
        push @$errors, "NO_EN_REF_ANODE";
        return;
    }
    # the node is not t-aligned => it doesn't have a lexical counterpart on the t-layer
    my @aligned_tnodes = map {$_->get_referencing_nodes('a/aux.rf')} @aligned_anodes;
    return @aligned_tnodes;
}

sub filter_anodes {
    my ($aligned, $tnode, $errors) = @_;
    my @filtered_a = ();
    my @filtered_t = ();
    foreach my $ali_t (@$aligned) {
        my @wh_a = grep {$_->tag =~ /^W/} $ali_t->get_aux_anodes();
        if (@wh_a) {
            push @filtered_t, $ali_t;
            push @filtered_a, @wh_a;
        }
    }
    if (!@filtered_a) {
        push @$errors, "NO_WH_PRON_ANODE";
        return;
    }
    my $anodes_str = join ",", (map {$_->id} @filtered_a);
    push @$errors, "WH_PRON_ANODE=$anodes_str";
    return @filtered_t;
}

sub filter_self {
    my ($aligned, $tnode, $errors) = @_;
    my @filtered = grep {Treex::Tool::Coreference::CS::RelPronAnaphFilter::is_relat($_)} @$aligned;
    if (!@filtered) {
        push @$errors, "NORELAT_EN_REF_TNODE";
        return;
    }
    return @filtered;
}

sub filter_eparents {
    my ($aligned, $tnode, $errors) = @_;
    my @functor_tnodes = Treex::Block::My::BitextCorefStats::filter_by_functor($aligned, $tnode->functor, $errors);

    if (!@functor_tnodes) {
        return filter_by_coref($aligned, $errors);
    }
    my @filtered_functor_tnodes = grep {
        Treex::Tool::Coreference::CS::RelPronAnaphFilter::is_relat($_) || 
        $_->t_lemma eq "#Cor" || $_->t_lemma eq "#PersPron"
    } @functor_tnodes;
    if (!@filtered_functor_tnodes) {
        push @$errors, "BAD_EN_REF_FUNCTOR_TNODE";
        return filter_by_coref($aligned, $errors);
    }
    return @filtered_functor_tnodes;
}

sub filter_by_coref {
    my ($nodes, $errors) = @_;
    my @coref_nodes = grep {scalar($_->get_coref_nodes) > 0} @$nodes;
    if (@coref_nodes == 0) {
        push @$errors, "NO_EN_REF_COREF_CHILDREN";
        return;
    }
    if (@coref_nodes > 1) {
        push @$errors, "MANY_EN_REF_COREF_CHILDREN";
        return;
    }
    return $coref_nodes[0];
}

sub filter_siblings {
    my ($aligned, $tnode, $errors) = @_;
    
    my $par = Treex::Block::My::BitextCorefStats::eparents_of_aligned_siblings($aligned, $errors);
    return if (!$par);
    
    my $formeme = $par->formeme;
    if (!defined $formeme) {
        push @$errors, "NOFORMEME_EN_REF_PAR";
        return;
    }
    if ($formeme =~ /^n/) {
        push @$errors, "NOUN_ANTE_ATTR";
        return $par;
    }
    if ($formeme =~ /^v/) {
        my ($relat_child) = grep {Treex::Tool::Coreference::CS::RelPronAnaphFilter::is_relat($_)} $par->get_children();
        if (defined $relat_child) {
            return $relat_child;
        }
        my @cor_children = grep {$_->t_lemma eq "#Cor"} $par->get_children();
        if (@cor_children == 0) {
            push @$errors, "NO_COR_CHILDREN";
            #return "EN_REF_PAR:" . $formeme;
            return;
        }
        if (@cor_children > 1) {
            push @$errors, "MANY_COR_CHILDREN";
            return;
        }
        return $cor_children[0];
    }
    push @$errors, "BADFORMEME_EN_REF_PAR";
    return;
}

sub select_via_self_siblings {
    my ($tnode, $align_filters, $errors) = @_;
    my @self_sibs = ($tnode, $tnode->get_siblings);
    my @aligned = Treex::Tool::Align::Utils::aligned_transitively(\@self_sibs, $align_filters);
    if (!@aligned) {
        push @$errors, "NO_ALIGN_SELF_SIBLING";
        return;
    }
    return @aligned;
}

sub filter_appos {
    my ($aligned, $tnode, $errors) = @_;
    my @pars = map {$_->get_parent} @$aligned;
    my @no_verb_appos = grep {(defined $_->t_lemma && $_->t_lemma eq "#EmpVerb") || (defined $_->functor && $_->functor eq "APPS")} @pars;
    if (!@no_verb_appos) {
        push @$errors, "NO_EMPVERB_APPOS";
        return;
    }
    #my ($cs_ref_par) = $cs_ref_tnode->get_eparents({or_topological => 1});
    #if ($cs_ref_par->t_lemma ne "být") {
    #    return "NO_VERB_APPOS_NOBYT";
    #}
    push @$errors, "EMPVERB_APPOS";
    return $no_verb_appos[0];
}


1;
