package Treex::Block::My::BitextCorefStats::EnPerspron;

use Moose;
use Treex::Tool::Align::Utils;
use Treex::Core::Common;
use Treex::Block::My::BitextCorefStats::AddRobustAlignmentPerspron;

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

    my $sieves = [ 
        'self', 
        'eparents',
        'siblings',
        \&Treex::Block::My::BitextCorefStats::AddRobustAlignmentPerspron::access_via_ancestor
    ];
    my $filters = [ 
        \&Treex::Block::My::BitextCorefStats::AddRobustAlignmentPerspron::filter_self, 
        \&Treex::Block::My::BitextCorefStats::AddRobustAlignmentPerspron::filter_eparents,
        \&Treex::Block::My::BitextCorefStats::AddRobustAlignmentPerspron::filter_siblings, 
        \&Treex::Block::My::BitextCorefStats::AddRobustAlignmentPerspron::filter_ancestor
    ];
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
    $result .= join ",", map {
        my $result_anode = $_->get_lex_anode();
        defined $result_anode ? substr($result_anode->tag, 0, 2) : "GENERATED";
    } @$result_nodes;
    return $result;
}


1;
