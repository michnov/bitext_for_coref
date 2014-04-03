package Treex::Block::My::LoadAlignment;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'from' => (is => 'ro', isa => 'Str', required => 1);

has 'align_language' => (is => 'ro', isa => 'Str', required => 1);
has 'align_selector' => (is => 'ro', isa => 'Str', required => 1);

has '_align_records' => (is => 'ro', isa => 'HashRef', builder => '_build_align_records');

sub BUILD {
    my ($self) = @_;
    $self->_align_records;
}

sub _build_align_records {
    my ($self) = @_;

    my $align_rec = {};

    open my $f, "<:utf8", $self->from;
    while (my $line = <$f>) {
        # read the ID line
        chomp $line;
        my ($src_id) = ($line =~ /^.*\.([^.]*)$/);
        # read surface form lines
        $line = <$f>;
        $line = <$f>;
        # read the source linearized t-tree
        $line = <$f>;
        # read the annotated target linearized t-tree
        $line = <$f>;
        chomp $line;
        my @word_nodes = split / /, $line;
        my @annotated_nodes_idx = grep {$word_nodes[$_] =~ /^<.*>$/} 0 .. $#word_nodes;
        # read the additional annotation info
        my $info = <$f>;
        chomp $info;
        $info =~ s/^ERR://;
        # read the empty line
        $line = <$f>;
        log_warn "The every 7th line of the input annotation file is not empty" if ($line !~ /^\s*$/);

        $align_rec->{$src_id}{trg_idx} = \@annotated_nodes_idx;
        $align_rec->{$src_id}{info} = $info;
    }
    close $f;
    return $align_rec;
}

before 'process_bundle' => sub {
    my ($self, $bundle) = @_;
    
    my $trg_zone = $bundle->get_zone($self->align_language, $self->align_selector);
    my $trg_ttree = $trg_zone->get_ttree();

    # TODO get ordered descendatsn and store a hash of ids    
};

sub process_tnode {
    my ($self, $tnode) = @_;

    my $rec = $self->_align_records->{$tnode->id};
    return if (!defined $rec);

    $tnode->add_aligned_node()
}

1;
