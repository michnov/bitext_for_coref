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
    my ($self, $src_tnode) = @_;
    log_fatal "Language must be 'en'" if ($self->language ne 'en');
    log_fatal "Selector must be 'src'" if ($self->selector ne 'src');
    
    return if (!is_perspron($tnode, 0, 1));
    
    my $address = $src_tnode->get_address;
    my ($result, $errors);
    
    ($result, $errors) = $self->print_en_perspron_cs_counterparts($src_tnode);
    $self->print_info("en_perspron_cs_src_counterparts", $address, $result, $errors);
    
    my ($ref_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$src_tnode], [$EN_REF_FILTER]);
    
    ($result, $errors) = $self->print_en_perspron_cs_counterparts($ref_tnode);
    $self->print_info("en_perspron_cs_ref_counterparts", $address, $result, $errors);
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

    return (undef, ["NO_EN_TNODE"]) if (!defined $tnode);
    
    my @cs_tnodes = Treex::Tool::Align::Utils::aligned_transitively([$cs_tnode], [$EN_ROBUST_FILTER]);
    
    my $result = "";

    my $robust_align_err = $tnode->wild->{align_robust_err};
    if (defined $robust_align_err) {
        if (grep {$_ eq "BENEF_FOUND"} @$robust_align_err) {
            $result = "BENEF:";
        }
    }

    if (!@cs_tnodes) {
        my $anode = $tnode->get_lex_anode();
        return (undef, $errors) if (!defined $anode);
        return "EN_ONLY:" . $anode->tag;
    }
    #$result .= join ",", map {
    #    my $result_anode = $_->get_lex_anode();
    #    defined $result_anode ? substr($result_anode->tag, 0, 2) : "GENERATED";
    #} @$result_nodes;
    my $result_anode = $cs_tnodes[0]->get_lex_anode();
    if (!defined $result_anode) {
        return "GENERATED";
    }
    return $result . substr($result_anode->tag, 0, 2);
}


1;
