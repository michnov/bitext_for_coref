package Treex::Block::My::AlignmentLoader;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

has 'from' => (is => 'ro', isa => 'Str', required => 1);

has 'align_language' => (is => 'ro', isa => 'Str', required => 1);

has '_align_records' => (is => 'ro', isa => 'HashRef', builder => '_build_align_records', lazy => 1);

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
        my @annotated_nodes_idx = grep {$word_nodes[$_] =~ /^<.*>$/ && $word_nodes[$_] !~ /^<__A:.*__.*>$/} 0 .. $#word_nodes;
        my @anodes_ids =  grep {defined $_} map {my ($a_id) = ($_ =~ /^<__A:(.*)__.*>$/); $a_id} @word_nodes;
        # read the additional annotation info
        my $info = <$f>;
        chomp $info;
        $info =~ s/^ERR://;
        # read the empty line
        $line = <$f>;
        log_warn "The every 7th line of the input annotation file is not empty" if ($line !~ /^\s*$/);

        $align_rec->{$src_id}{trg_idx} = \@annotated_nodes_idx;
        if (@anodes_ids) {
            $align_rec->{$src_id}{anodes_ids} = \@anodes_ids;
        }
        if ($info !~ /^\s*$/) {
            $align_rec->{$src_id}{info} = $info;
        }
    }
    close $f;
    print STDERR Dumper($align_rec);
    return $align_rec;
}

sub process_tnode {
    my ($self, $tnode) = @_;

    my $rec = $self->_align_records->{$tnode->id};
    return if (!defined $rec);
    
    my $trg_zone = $tnode->get_bundle->get_zone($self->align_language, $self->selector);
    my $trg_ttree = $trg_zone->get_ttree();

    # TODO get ordered descendatsn and store a hash of ids
    my @all_trg_nodes = $trg_ttree->get_descendants({ordered => 1});
    my @ali_trg_nodes = @all_trg_nodes[@{$rec->{trg_idx}}];

    for my $trg_node (@ali_trg_nodes) {
        log_info sprintf("Adding alignment between nodes: %s and %s (tlemma = %s)", $tnode->id, $trg_node->id, $trg_node->t_lemma);
        Treex::Tool::Align::Utils::add_aligned_node($tnode, $trg_node, "gold");
    }
    for my $a_id (@{$rec->{anodes_ids}}) {
        my $anode = $tnode->get_lex_anode();
        if (defined $anode) {
            Treex::Tool::Align::Utils::add_aligned_node($anode, $tnode->get_document->get_node_by_id($a_id), "gold");
        }
    }
    $tnode->wild->{align_info} = $rec->{info} if (defined $rec->{info});
}

1;
