package Treex::Block::My::AnnotAlignWrite;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::NodeFilter::RelPron;
use Treex::Tool::Align::Utils;

extends 'Treex::Block::Write::BaseTextWriter';

has 'align_lang' => (is => 'ro', isa => 'Str', required => 1);

has 'robust_align_filter' => (is => 'ro', isa => 'HashRef', builder => '_build_raf');

sub BUILD {
    my ($self) = @_;
    $self->robust_align_filter;
}

sub _build_raf {
    my ($self) = @_;
    return { language => $self->align_lang, rel_types => ['robust','.*'] };
}

sub _linearize_tnode {
    my ($tnode, @highlight) = @_;
   
    my $word = "";
    
    my $anode = $tnode->get_lex_anode;
    if (defined $anode) {
        $word = $anode->form;
    }
    else {
        $word = $tnode->t_lemma .".". $tnode->functor;
    }
    $word =~ s/ /_/g;
    $word =~ s/</&lt;/g;
    $word =~ s/>/&gt;/g;

    if (any {$_ == $tnode} @highlight) {
        $word = "<" . $word . ">";
    }
    return $word;
}

sub _linearize_ttree {
    my ($ttree, @highlight) = @_;

    @highlight = grep {defined $_} @highlight; 

    my @words = map {_linearize_tnode($_, @highlight)} $ttree->get_descendants({ordered => 1});
    return join " ", @words;
}

sub process_tnode {
    my ($self, $l1_tnode) = @_;

    log_fatal "Must be run on 'ref'."
        if ($self->selector ne "ref");

    log_info $l1_tnode->id;
    my ($l2_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$l1_tnode], [$self->robust_align_filter]);

    my $l1_zone = $l1_tnode->get_zone;
    my $l2_zone = $l1_tnode->get_bundle->get_zone($self->align_lang, "ref");

    print {$self->_file_handle} $l1_tnode->get_address . "\n";
    print {$self->_file_handle} $l1_zone->sentence . "\n";
    print {$self->_file_handle} $l2_zone->sentence . "\n";
    print {$self->_file_handle} _linearize_ttree($l1_zone->get_ttree, $l1_tnode) . "\n";
    print {$self->_file_handle} _linearize_ttree($l2_zone->get_ttree, $l2_tnode) . "\n";
    print {$self->_file_handle} "ERR:\n";
    print {$self->_file_handle} "\n";
}


1;
