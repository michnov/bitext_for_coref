package Treex::Block::My::AnnotAlignWrite;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::NodeFilter::RelPron;
use Treex::Tool::Align::Utils;

extends 'Treex::Block::Write::BaseTextWriter';
    
my $EN_ROBUST_FILTER = { language => 'en', rel_types => ['robust','.*'] };

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
    my ($self, $tnode) = @_;

    log_fatal "Must be run on 'cs_ref' zone."
        if ($self->selector ne "ref" && $self->language ne "cs");

    log_info $tnode->id;
    my ($en_tnode) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [$EN_ROBUST_FILTER]);

    my $cs_zone = $tnode->get_zone;
    my $en_zone = $tnode->get_bundle->get_zone("en","ref");

    print {$self->_file_handle} $tnode->get_address . "\n";
    print {$self->_file_handle} $cs_zone->sentence . "\n";
    print {$self->_file_handle} $en_zone->sentence . "\n";
    print {$self->_file_handle} _linearize_ttree($cs_zone->get_ttree, $tnode) . "\n";
    print {$self->_file_handle} _linearize_ttree($en_zone->get_ttree, $en_tnode) . "\n";
    print {$self->_file_handle} "ERR:\n";
    print {$self->_file_handle} "\n";
}


1;
