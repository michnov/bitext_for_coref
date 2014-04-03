package Treex::Block::My::ProjectCoreference;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

has 'trg_language' => (is => 'ro', isa => 'Str', required => 1);

sub process_tnode {
    my ($self, $src_tnode) = @_;
        
    my ($trg_anaphs, $trg_anaphs_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter(
        $src_tnode,
        {language => $self->trg_language, selector => $self->selector}
    );
    return if (!@$trg_anaphs);

    my @src_antes = $src_tnode->get_coref_text_nodes;
    my @trg_all_antes = ();
    foreach my $src_ante (@src_antes) {
        my $src_ante_with_align = $src_ante;
        my ($trg_antes, $trg_antes_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter(
            $src_ante_with_align,
            {language => $self->trg_language, selector => $self->selector}
        );
        while (!@$trg_antes) {
            ($src_ante_with_align) = $src_ante_with_align->get_coref_gram_nodes;
            last if (!defined $src_ante_with_align);
            ($trg_antes, $trg_antes_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter(
                $src_ante_with_align,
                {language => $self->trg_language, selector => $self->selector}
            );
        }
        push @trg_all_antes, @$trg_antes;
    }
    return if (!@trg_all_antes);

    foreach my $trg_anaph (@$trg_anaphs) {
        $trg_anaph->add_coref_text_nodes(@trg_all_antes);
    }
}

1;