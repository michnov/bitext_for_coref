package Treex::Block::My::AddRobustAlignment;

use Moose;
use Treex::Tool::Align::Utils;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '_align_lang' => (is => 'ro', isa => 'Str', required => 1);
has '_align_zone' => (is => 'ro', isa => 'HashRef[Str]', builder => '_build_align_zone', lazy => 1);

has 'type' => (is => 'ro', isa => 'Str', default => 'robust');

sub BUILD {
    my ($self) = @_;
    $self->_align_zone;
}

sub _build_align_lang {
    my ($self) = @_;

    log_fatal "Treex::Block::My::AddRobustAlignment is an abstract class. The '_align_lang' must be set in the subclass.";
}

sub _build_align_zone {
    my ($self) = @_;
    return {language => $self->_align_lang, selector => $self->selector};
}

after 'process_zone' => sub {
    my ($self, $zone) = @_;

    my $robust_label = $self->type;
    my $align_filter = { %{$self->_align_zone}, rel_types => ["!$robust_label", '.*'] };

    foreach my $tnode ($zone->get_ttree->get_descendants) {
        if (defined $tnode->wild->{align_robust_err}) {
            Treex::Tool::Align::Utils::remove_aligned_nodes_by_filter($tnode, $align_filter);
        }
    }
};

sub _does_apply {
    log_fatal "Treex::Block::My::AddRobustAlignment is an abstract class. The '_does_apply' method must be implemented subclass.";
}
sub _get_align_selectors {
    log_fatal "Treex::Block::My::AddRobustAlignment is an abstract class. The '_get_align_selectors' method must be implemented subclass.";
}
sub _get_align_filters {
    log_fatal "Treex::Block::My::AddRobustAlignment is an abstract class. The '_get_align_filters' method must be implemented subclass.";
}


sub process_tnode {
    my ($self, $tnode) = @_;

    return if (!$self->_does_apply($tnode));
    
    my $sieves = $self->_get_align_selectors();
    my $filters = $self->_get_align_filters();

    my ($result_nodes, $errors) = Treex::Tool::Align::Utils::aligned_robust($tnode, [ $self->_align_zone ], $sieves, $filters);
    $tnode->wild->{align_robust_err} = $errors;
    #log_info "ERROR_WRITE: " . $tnode->id . " " . (defined $errors ? "1" : "0");
    if (defined $result_nodes) {
        foreach (@$result_nodes) {
            Treex::Tool::Align::Utils::add_aligned_node($tnode, $_, $self->type);
        }
    }
}

1;
