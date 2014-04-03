package Treex::Block::My::AlignmentEconomic;

use Moose;
use Treex::Core::Common;
    
use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    my ($nodes, $types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($anode, {language => "en", selector => "src"});
    my %id_to_type = ();
    foreach my $i (0 .. $#$nodes) {
        if (!defined $id_to_type{$nodes->[$i]->id}) {
            if ($types->[$i] eq 'intersection') {
                $id_to_type{$nodes->[$i]->id} = 'int';
            }
            if ($types->[$i] eq 'grow-diag-final-and') {
                $id_to_type{$nodes->[$i]->id} = 'gdfa';
            }
        }
        else {
            $id_to_type{$nodes->[$i]->id} = 'int.gdfa';
        }
    }
    my %id_to_node = map {$_->id => $_} @$nodes;
    
    Treex::Tool::Align::Utils::remove_aligned_nodes_by_filter($anode, {language => "en", selector => "src"});

    foreach my $id (keys %id_to_type) {
        my $node = $id_to_node{$id};
        Treex::Tool::Align::Utils::add_aligned_node($anode, $node, $id_to_type{$id});
    }
}

1;
