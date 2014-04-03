package Treex::Block::My::ProjectAlignment;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

has 'trg_selector' => (is => 'ro', isa => 'Str', required => 1);
has 'rel_type' => (is => 'ro', isa => 'Str', default => 'gold');

sub _get_projected_nodes {
    my ($self, $z1_src_node) = @_;
    my ($z1_trg_nodes, $z1_trg_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($z1_src_node, {rel_types => [$self->rel_type]});
    #print STDERR Dumper(\@z1_trg_nodes);
    #print STDERR join " ", (map {$_->id} @z1_trg_nodes);
    return if (!@$z1_trg_nodes);

    my ($z2_src_nodes, $z2_src_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter(
        $z1_src_node, 
        {selector => $self->trg_selector, language => $z1_src_node->language}
    );
    my @z2_trg_nodes = map {
        my ($nodes, $types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter(
            $_,
            {selector => $self->trg_selector, language => $_->language}
        );
        log_info "No z2 counterpart: ".$_->id  if (!@$nodes);
        @$nodes
    } @$z1_trg_nodes;
    
    log_info "No z2 counterpart: ".$z1_src_node->id  if (!@$z2_src_nodes);

    return ($z2_src_nodes->[0], \@z2_trg_nodes);
}

sub process_tnode {
    my ($self, $z1_src_tnode) = @_;

    my ($z2_src_tnode, $z2_trg_tnodes) = $self->_get_projected_nodes($z1_src_tnode);
    return if (!defined $z2_src_tnode);


    for my $z2_trg_tnode (@$z2_trg_tnodes) {
        log_info sprintf("Adding alignment between nodes: %s and %s", $z2_src_tnode->id, $z2_trg_tnode->id);
        Treex::Tool::Align::Utils::add_aligned_node($z2_src_tnode, $z2_trg_tnode, $self->rel_type);
    }
}

sub process_anode {
    my ($self, $z1_src_anode) = @_;

    my ($z2_src_anode, $z2_trg_anodes) = $self->_get_projected_nodes($z1_src_anode);
    return if (!defined $z2_src_anode);

    my ($z2_src_tnode) = $z2_src_anode->get_referencing_nodes('a/lex.rf');
    for my $z2_trg_anode (@$z2_trg_anodes) {
        my ($z2_trg_tnode) = $z2_trg_anode->get_referencing_nodes('a/lex.rf');

        if (defined $z2_src_tnode && defined $z2_trg_tnode) {
            log_info sprintf("Adding alignment between nodes: %s and %s", $z2_src_tnode->id, $z2_trg_tnode->id);
            Treex::Tool::Align::Utils::add_aligned_node($z2_src_tnode, $z2_trg_tnode, $self->rel_type);
        }
        else {
            log_info sprintf("Adding alignment between nodes: %s and %s", $z2_src_anode->id, $z2_trg_anode->id);
            Treex::Tool::Align::Utils::add_aligned_node($z2_src_anode, $z2_trg_anode, $self->rel_type);
        }
    }
}

1;
