package Treex::Block::My::RemoveCoreferenceLoops;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;

    my @antes = $tnode->get_coref_nodes();
    my @looped = grep {$_ == $tnode} @antes;

    $tnode->remove_coref_nodes(@looped);
}

1;
