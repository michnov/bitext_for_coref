##########################################
#### THIS MODULE IS PROBABLY OBSOLETE ####
########### SHOULD BE DELETED ############
##########################################
package Treex::Block::My::EvalCoref;

# TODO: this should probably do the same thing as Treex::Block::Eval::Coref - unify it

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
use Treex::Tool::Context::Sentences;
use Treex::Tool::Coreference::NodeFilter::PersPron;

extends 'Treex::Block::Write::BaseTextWriter';

has 'prev_sents_num' => (is => 'ro', isa => 'Num', required => 1, default => 1);
has '_sent_window' => (is => 'ro', isa => 'Treex::Tool::Context::Sentences', builder => '_build_sent_window');
has '_anaph_cands_filter' => (is => 'ro', isa => 'Treex::Tool::Coreference::NodeFilter::PersPron', builder => '_build_acf');

sub _build_sent_window {
    my ($self) = @_;
    return Treex::Tool::Context::Sentences->new({nodes_within_czeng_blocks => 1});
}

sub _build_acf {
    my ($self) = @_;
# TODO this module can be no longer instantiated
    my $acf = Treex::Tool::Coreference::NodeFilter::PersPron->new({
        args => {
                # including reflexive pronouns
            }
    });
    return $acf;
}

sub _get_coap_members {
    my ($tnode) = @_;
    return $tnode->functor =~ /^(APPS|CONJ|DISJ|GRAD)$/ ? $tnode->children : ();
}

sub _get_ref_antes {
    my ($self, $ref_tnode) = @_;
    return [] if (!defined $ref_tnode);
    my @all_antes = $ref_tnode->get_coref_chain();
    return [] if (!@all_antes);
    my @all_nodes = $self->_sent_window->nodes_in_surroundings( 
        $ref_tnode, -$self->prev_sents_num, 0, {preceding_only => 1}  
    );
    my @antes_window = grep {my $ante = $_; any {$_ == $ante} @all_nodes} @all_antes;
    return undef if (!@antes_window);
    return \@antes_window;
}

# src tnodes are already filtered candidates
sub process_tnode {
    my ($self, $src_tnode) = @_;

    return if ($src_tnode->is_root);

    return if (!$self->_anaph_cands_filter->is_candidate( $src_tnode ));

    my @src_antes = $src_tnode->get_coref_text_nodes();
    push @src_antes, map { _get_coap_members($_) } @src_antes;
    my @ref_src_antes = Treex::Tool::Align::Utils::aligned_transitively(
        \@src_antes,
        [ {selector => "ref", language => $src_tnode->language} ]
    );

    my ($ref_tnode) = Treex::Tool::Align::Utils::aligned_transitively(
        [ $src_tnode ],
        [ {selector => "ref", language => $src_tnode->language} ]
    );
    my $ref_antes = $self->_get_ref_antes($ref_tnode);
    return if (!defined $ref_antes);
    log_info "ADDRESS: ".$src_tnode->get_address;

    my @both_antes = grep {my $ref_ante = $_; any {$_ == $ref_ante} @ref_src_antes} @$ref_antes;

    printf {$self->_file_handle} "%d %d %d\n", scalar @$ref_antes, scalar @src_antes, scalar @both_antes;
}

1;
