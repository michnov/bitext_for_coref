package Treex::Block::My::BitextCorefStats::AddRobustAlignmentPerspron;

use Moose;
use Treex::Tool::Align::Utils;
use Treex::Core::Common;

use Treex::Block::My::BitextCorefStats;

extends 'Treex::Core::Block';

has 'align_lang' => (is => 'ro', isa => 'Treex::Type::LangCode', required => 1);
has 'align_selector' => (is => 'ro', isa => 'Treex::Type::Selector', required => 1);

has '_align_zone' => (is => 'ro', isa => 'HashRef[Str]', builder => '_build_align_zone', lazy => 1);

has 'type' => (is => 'ro', isa => 'Str', default => 'robust');

sub BUILD {
    my ($self) = @_;
    $self->_align_zone;
}

sub _build_align_zone {
    my ($self) = @_;
    return {language => $self->align_lang, selector => $self->align_selector};
}

sub process_tnode {
    my ($self, $tnode) = @_;

    # only for 3rd person non-reflexive personal pronouns
    return if (!is_perspron($tnode, 0, 1));
    
    my $sieves = [ 'self', 'eparents', 'siblings', \&access_via_ancestor ];
    my $filters = [ \&filter_self, \&filter_eparents, \&filter_siblings, \&filter_ancestor ];

    my ($result_nodes, $errors) = Treex::Tool::Align::Utils::aligned_robust($tnode, [ $self->_align_zone ], $sieves, $filters);
    if (defined $result_nodes) {
        foreach (@$result_nodes) {
            Treex::Tool::Align::Utils::add_aligned($tnode, $_, $self->type);
        }
    }
}

sub is_perspron {
    my ($tnode, $is_reflex, $is_3rd_person) = @_;
    my $tnode_3rd_person = defined $tnode->gram_person && ($tnode->gram_person eq "3");
    return 
        ($tnode->t_lemma eq "#PersPron") &&
        ($tnode->get_attr('is_reflexive') xor !$is_reflex) &&
        ($tnode_3rd_person xor !$is_3rd_person)
            ? 1 : 0;
}


sub access_via_ancestor {
    my ($tnode, $align_filters, $errors) = @_;

    my $verb_par = $tnode->get_parent();
    while (defined $verb_par && (!defined $verb_par->formeme || $verb_par->formeme !~ /^v/)) {
        $verb_par = $verb_par->get_parent();
    }
    if (!defined $verb_par) {
        push @$errors, "NO_EN_REF_VERB_ANCESTOR";
        return;
    }

    my @aligned_verb_par = Treex::Tool::Align::Utils::aligned_transitively([$verb_par], $align_filters);
    if (!@aligned_verb_par) {
        push @$errors, "NO_CS_REF_VERB_PAR";
        return;
    }

    my @aligned_kids = map {$_->get_echildren({or_topological => 1})} @aligned_verb_par;
    return @aligned_kids;
}

sub filter_self {
    my ($aligned, $tnode, $errors) = @_;

    my @filtered = grep {
        my $anode = $_->get_lex_anode();
        defined $anode && $anode->tag !~ /^P[8SDP5]/
    } @$aligned;
    if (!@filtered) {
        push @$errors, "NOPRON_CS_REF_TNODE";
        return;
    }
    return @filtered;
}

sub filter_eparents {
    my ($aligned, $tnode, $errors) = @_;
    my @filtered = Treex::Block::My::BitextCorefStats::filter_by_functor($aligned, $tnode->functor, $errors);
    return @filtered;
}

sub filter_siblings {
    my ($aligned, $tnode, $errors) = @_;
    my $par = Treex::Block::My::BitextCorefStats::eparents_of_aligned_siblings($aligned, $errors);
    return if (!$par);
    my @kids = $par->get_echildren({or_topological => 1});
    my @filtered = Treex::Block::My::BitextCorefStats::filter_by_functor(\@kids, $tnode->functor, $errors);
    return @filtered;
}

sub filter_ancestor {
    my ($aligned, $tnode, $errors) = @_;

    my @aligned_dative_childs = grep {
        my $anode = $_->get_lex_anode; 
        if (defined $anode) {$anode->tag =~ /^P...3/}
    } @$aligned;
    
    if (!@aligned_dative_childs) {
        push @$errors, "NO_CS_REF_DATIVE_CHILD";
        return;
    }
    push @$errors, "BENEF_FOUND";
    return @aligned_dative_childs;
}

1;
