package Treex::Block::My::ProjectCoreference;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'trg_language' => (is => 'ro', isa => 'Str', required => 1);

sub process_tnode {
    my ($self, $src_tnode) = @_;
        
    my ($trg_anaphs, $trg_anaphs_types) = $src_tnode->get_undirected_aligned_nodes({
        language => $self->trg_language,
        selector => $self->selector,
        rel_types => ['supervised', '.*'],
    });
    return if (!@$trg_anaphs);

    my @src_antes = $src_tnode->get_coref_text_nodes;
    my @trg_all_antes = ();
    foreach my $src_ante (@src_antes) {
        my $src_ante_with_align = $src_ante;
        my ($trg_antes, $trg_antes_types) = $src_ante_with_align->get_undirected_aligned_nodes({
            language => $self->trg_language,
            selector => $self->selector,
            rel_types => ['supervised', '.*'],
        });
        while (!@$trg_antes) {
            ($src_ante_with_align) = $src_ante_with_align->get_coref_gram_nodes;
            last if (!defined $src_ante_with_align);
            ($trg_antes, $trg_antes_types) = $src_ante_with_align->get_undirected_aligned_nodes({
                language => $self->trg_language,
                selector => $self->selector,
                rel_types => ['supervised', '.*'],
            });
        }
        push @trg_all_antes, @$trg_antes;
    }
    return if (!@trg_all_antes);

    foreach my $trg_anaph (@$trg_anaphs) {
        $trg_anaph->add_coref_text_nodes(@trg_all_antes);
    }
}

1;
