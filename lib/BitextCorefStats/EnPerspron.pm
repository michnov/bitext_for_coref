package Treex::Block::My::BitextCorefStats::EnPerspron;

use Moose;
use Treex::Tool::Align::Utils;
use Treex::Core::Common;

extends 'Treex::Block::My::BitextCorefStats';

has 'align_filters' => ( is => 'ro', isa => 'ArrayRef[HashRef[Str]]', builder => '_build_align_filters', lazy => 1);

sub BUILD {
    my ($self) = @_;
    $self->align_filters;
}

sub _build_align_filters {
    my ($self) = @_;
    return [{language => 'cs', selector => $self->align_selector}];
}

sub process_tnode {
    my ($self, $tnode) = @_;
    log_fatal if ($self->language ne 'en');
    
    return if (!is_perspron($tnode, 0, 1));
    
    $self->print_info($tnode, "en_perspron_cs_counterparts", \&print_en_perspron_cs_counterparts);
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

sub print_en_perspron_cs_counterparts {
    my ($self, $tnode) = @_;

    my $en_tnode = $tnode;
    if ($self->align_selector eq "ref" && $tnode->selector eq "src") {
        ($en_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [{language => 'en', selector => 'ref'}]);
        return (undef, ["NO_EN_REF_TNODE"]) if (!defined $en_tnode);
    }

    my $sieves = [ 'self', 'eparents', 'siblings', \&access_via_ancestor ];
    my $filters = [ \&filter_self, \&filter_eparents, \&filter_siblings, \&filter_ancestor ];
    my ($result_nodes, $errors) = Treex::Tool::Align::Utils::aligned_robust($en_tnode, $self->align_filters, $sieves, $filters);

    my $result = "";
    if (grep {$_ eq "BENEF_FOUND"} @$errors) {
        $result = "BENEF:";
    }

    if (!defined $result_nodes) {
        my $anode = $tnode->get_lex_anode();
        return (undef, $errors) if (!defined $anode);
        return "EN_ONLY:" . $anode->tag;
    }
    #$Data::Dumper::Maxdepth = 1;
    #print STDERR Dumper($result_nodes);
    $result .= join ",", map {
        my $result_anode = $_->get_lex_anode();
        defined $result_anode ? substr($result_anode->tag, 0, 2) : "GENERATED";
    } @$result_nodes;
    return $result;
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
    return @aligned_verb_par;
}

sub filter_self {
    my ($aligned, $tnode, $errors) = @_;

    my $aligned_first = shift @$aligned;
    my $anode = $aligned_first->get_lex_anode();
    if (!defined $anode || ($anode->tag !~ /^P[8SDP5]/)) {
        push @$errors, "NOPRON_CS_REF_TNODE";
        return;
    }
    return $aligned_first;
}

sub filter_eparents {
    my ($aligned, $tnode, $errors) = @_;
    my $filtered = Treex::Block::My::BitextCorefStats::filter_by_functor($aligned, $tnode->functor, $errors);
    return $filtered;
}

sub filter_siblings {
    my ($aligned, $tnode, $errors) = @_;
    my $par = Treex::Block::My::BitextCorefStats::eparents_of_aligned_siblings($aligned, $errors);
    return if (!$par);
    my @kids = $par->get_echildren({or_topological => 1});
    my $filtered = Treex::Block::My::BitextCorefStats::filter_by_functor(\@kids, $tnode->functor, $errors);
    return $filtered;
}

sub filter_ancestor {
    my ($aligned, $tnode, $errors) = @_;

    my $aligned_first = shift @$aligned;
    my ($aligned_dative_child) = grep {
        my $anode = $_->get_lex_anode; 
        if (defined $anode) {$anode->tag =~ /^P...3/}
    } $aligned_first->get_echildren({or_topological => 1});
    
    if (!defined $aligned_dative_child) {
        push @$errors, "NO_CS_REF_DATIVE_CHILD";
        return;
    }
    push @$errors, "BENEF_FOUND";
    return $aligned_dative_child;
}

1;
